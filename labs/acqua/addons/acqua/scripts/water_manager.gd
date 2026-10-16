@tool
extends Node
## Gestore globale dell'acqua (autoload "WaterManager").
##
## - aggiorna il tempo comune degli shader (`water_time`), cosi' script e shader restano sincronizzati;
## - tiene la tabella delle masse d'acqua (`water_bodies_tex`): ogni WaterBody occupa 4 texel
##   (rettangolo xz, livello, livello bagnato, colori del volume). Tutti i materiali che includono
##   `water_common.gdshaderinc` la usano per caustiche, linea bagnata e sott'acqua;
## - tiene gli impatti delle gocce sui pavimenti (`water_drops_tex`) per i cerchi nelle pozzanghere;
## - gestisce il livello di qualita' (basso/medio/alto) e lo comunica agli altri nodi.

signal quality_changed(quality: int)

enum Quality { LOW, MEDIUM, HIGH }

const MAX_BODIES := 8
const TEXELS_PER_BODY := 4
const MAX_DROPS := 24
const MAX_GLOWS := 4
const TIME_ROLLOVER := 3600.0
## Quanto sotto il fondo di una massa d'acqua (m) un punto conta ancora come "dentro" (get_body_at).
const BELOW_BOTTOM := 0.5

## Livello di qualita' corrente (0 basso, 1 medio, 2 alto).
var quality: int = Quality.HIGH:
	set(value):
		quality = clampi(value, Quality.LOW, Quality.HIGH)
		RenderingServer.global_shader_parameter_set("water_quality", quality)
		quality_changed.emit(quality)

## Tempo comune dell'acqua, in secondi (ricomincia da zero ogni ora).
var time := 0.0
## Se falso il tempo dell'acqua e' fermo (utile per screenshot identici).
var time_running := true

var _bodies: Array[Node] = []
var _body_img: Image
var _body_tex: ImageTexture
var _bodies_dirty := true

var _drop_img: Image
var _drop_tex: ImageTexture
var _drop_next := 0
var _drops_dirty := false

var _glows: Array[Node] = []
var _glow_img: Image
var _glow_tex: ImageTexture


# Variabili globali degli shader usate dall'addon: nome, tipo, valore iniziale.
# Se il progetto non le dichiara in project.godot ([shader_globals]) le registra l'autoload
# all'avvio, prima che si carichi la scena (nel gioco basta l'autoload; per vedere l'acqua anche
# nell'editor conviene dichiararle: vedi README).
const GLOBALS := [
	["water_time", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	["water_body_count", RenderingServer.GLOBAL_VAR_TYPE_INT, 0],
	["water_bodies_tex", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, null],
	["water_caustics_tex", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER3D, "res://addons/acqua/textures/caustics_3d.png"],
	["water_noise_tex", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, "res://addons/acqua/textures/noise_rgba.png"],
	["water_ripple_tex", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, null],
	["water_ripple_rect", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO],
	["water_drops_tex", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, null],
	["water_drop_count", RenderingServer.GLOBAL_VAR_TYPE_INT, 0],
	["water_quality", RenderingServer.GLOBAL_VAR_TYPE_INT, 2],
	["water_glow_tex", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, null],
	["water_glow_count", RenderingServer.GLOBAL_VAR_TYPE_INT, 0],
]


static var _globals_registered := false


static func register_globals() -> void:
	if _globals_registered:
		return
	_globals_registered = true
	for g in GLOBALS:
		var gname: String = g[0]
		if ProjectSettings.has_setting("shader_globals/" + gname):
			continue
		var value = g[2]
		if value is String:
			value = load(value)
		RenderingServer.global_shader_parameter_add(gname, g[1], value)


func _enter_tree() -> void:
	process_priority = -1000
	register_globals()
	_body_img = Image.create_empty(MAX_BODIES * TEXELS_PER_BODY, 1, false, Image.FORMAT_RGBAF)
	_body_tex = ImageTexture.create_from_image(_body_img)
	_drop_img = Image.create_empty(MAX_DROPS, 1, false, Image.FORMAT_RGBAF)
	for i in MAX_DROPS:
		_drop_img.set_pixel(i, 0, Color(0.0, 0.0, -1000.0, 0.0))
	_drop_tex = ImageTexture.create_from_image(_drop_img)
	_glow_img = Image.create_empty(MAX_GLOWS * 2, 1, false, Image.FORMAT_RGBAF)
	_glow_tex = ImageTexture.create_from_image(_glow_img)
	RenderingServer.global_shader_parameter_set("water_glow_tex", _glow_tex)
	RenderingServer.global_shader_parameter_set("water_glow_count", 0)
	RenderingServer.global_shader_parameter_set("water_bodies_tex", _body_tex)
	RenderingServer.global_shader_parameter_set("water_drops_tex", _drop_tex)
	RenderingServer.global_shader_parameter_set("water_drop_count", MAX_DROPS)
	RenderingServer.global_shader_parameter_set("water_body_count", 0)
	RenderingServer.global_shader_parameter_set("water_quality", quality)


func _process(delta: float) -> void:
	if time_running:
		time = fmod(time + delta, TIME_ROLLOVER)
	RenderingServer.global_shader_parameter_set("water_time", time)
	if _bodies_dirty:
		_update_body_table()
	if _drops_dirty:
		_drop_tex.update(_drop_img)
		_drops_dirty = false
	_update_glow_table()
	_update_active_ripples()


# --- masse d'acqua ---------------------------------------------------------------------------

func register_body(body: Node) -> void:
	if body not in _bodies:
		_bodies.append(body)
		_bodies_dirty = true


func unregister_body(body: Node) -> void:
	_bodies.erase(body)
	_bodies_dirty = true


func mark_bodies_dirty() -> void:
	_bodies_dirty = true


func get_bodies() -> Array[Node]:
	return _bodies


## Restituisce la massa d'acqua che contiene il punto (in pianta), o null. Le masse d'acqua con il
## fondo piu' alto del punto (di oltre [constant BELOW_BOTTOM]) non contano: un tunnel o un pozzo
## che passa sotto una vasca non e' dentro la vasca.
func get_body_at(world_pos: Vector3, margin := 0.0) -> Node:
	for b in _bodies:
		if is_instance_valid(b) and b.contains_xz(world_pos, margin) and world_pos.y >= b.bottom - BELOW_BOTTOM:
			return b
	return null


## Vero se il punto e' sotto la superficie di una massa d'acqua (onde comprese).
func is_underwater(world_pos: Vector3) -> bool:
	var b := get_body_at(world_pos)
	return b != null and world_pos.y < b.get_surface_height(world_pos) and world_pos.y > b.bottom - 0.05


func _update_body_table() -> void:
	_bodies_dirty = false
	var count := 0
	for b in _bodies:
		if count >= MAX_BODIES:
			push_warning("WaterManager: troppe masse d'acqua, massimo %d" % MAX_BODIES)
			break
		if not is_instance_valid(b):
			continue
		var rows: Array = b.get_shader_rows()
		for j in TEXELS_PER_BODY:
			_body_img.set_pixel(count * TEXELS_PER_BODY + j, 0, rows[j])
		count += 1
	_body_tex.update(_body_img)
	RenderingServer.global_shader_parameter_set("water_body_count", count)


# --- gocce sui pavimenti ---------------------------------------------------------------------

## Registra l'impatto di una goccia: lo shader delle superfici bagnate disegna un cerchio
## che si allarga dal punto (solo dove c'e' una pozzanghera o il pavimento e' bagnato).
func add_drop_ring(world_pos: Vector3, strength := 1.0) -> void:
	_drop_img.set_pixel(_drop_next, 0, Color(world_pos.x, world_pos.z, time, strength))
	_drop_next = (_drop_next + 1) % MAX_DROPS
	_drops_dirty = true


# --- luci dentro l'acqua (per esempio la campana della medusa) -------------------------------

func register_glow(light: Node) -> void:
	if light not in _glows:
		_glows.append(light)


func unregister_glow(light: Node) -> void:
	_glows.erase(light)


## Registra una luce gia' esistente (per esempio le luci subacquee dei GLB) come luce immersa:
## il volume d'acqua intorno brilla e le superfici non le applicano le caustiche.
func register_underwater_light(light: Light3D, glow_strength := 2.0, glow_radius := 5.0) -> void:
	light.set_meta("water_glow_strength", glow_strength)
	light.set_meta("water_glow_radius", glow_radius)
	register_glow(light)


func _glow_rows_for_light(l: Light3D) -> Array:
	var p := l.global_position
	var c := l.light_color * l.light_energy * float(l.get_meta("water_glow_strength", 2.0))
	var r: float = l.get("omni_range") if "omni_range" in l else 5.0
	return [Color(p.x, p.y, p.z, float(l.get_meta("water_glow_radius", 5.0))), Color(c.r, c.g, c.b, r)]


func _update_glow_table() -> void:
	var count := 0
	for g in _glows:
		if count >= MAX_GLOWS:
			break
		if not is_instance_valid(g) or not g.is_visible_in_tree():
			continue
		var rows: Array = g.get_glow_rows() if g.has_method("get_glow_rows") else _glow_rows_for_light(g)
		_glow_img.set_pixel(count * 2, 0, rows[0])
		_glow_img.set_pixel(count * 2 + 1, 0, rows[1])
		count += 1
	_glow_tex.update(_glow_img)
	RenderingServer.global_shader_parameter_set("water_glow_count", count)


# --- simulazione "attiva" per le caustiche ---------------------------------------------------

var _active_ripple_body: Node = null


## Le caustiche dei materiali delle vasche usano una sola simulazione alla volta: quella della
## vasca che contiene la camera o, se nessuna, della piu' vicina.
func _update_active_ripples() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null or _bodies.is_empty():
		return
	var p := cam.global_position
	var best: Node = null
	var best_d := INF
	for b in _bodies:
		if not is_instance_valid(b) or b.ripple_sim == null:
			continue
		var r: Rect2 = b.get_rect()
		var cx := clampf(p.x, r.position.x, r.end.x)
		var cz := clampf(p.z, r.position.y, r.end.y)
		var d := Vector2(p.x - cx, p.z - cz).length()
		if d < best_d:
			best_d = d
			best = b
	if best != _active_ripple_body or (best and Engine.get_process_frames() % 30 == 0):
		_active_ripple_body = best
		if best:
			var r: Rect2 = best.get_rect()
			RenderingServer.global_shader_parameter_set("water_ripple_tex", best.ripple_sim.texture)
			RenderingServer.global_shader_parameter_set("water_ripple_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
		else:
			RenderingServer.global_shader_parameter_set("water_ripple_rect", Vector4.ZERO)
