@tool
class_name WaterTank
extends Node3D
## Vasca con un livello d'acqua che sale e scende davvero.
## - Si riempie con il getto dello zaino (l'acqua che ci cade dentro) o da sola (fill_sources).
## - Lo zaino ne ASPIRA l'acqua (tasto destro): il livello scende. I litri si conservano:
##   aspirare da una vasca e spruzzare in un'altra sposta la stessa quantità d'acqua.
## - Si svuota con lo scarico (drain_sources). È la base per le piattaforme galleggianti.
## L'origine è al centro del fondo interno; inner_size è lo spazio interno (x, profondità, z).
## L'acqua ha un colore ([member mix], vedi WaterMix): si mescola per litri con quella che arriva
## e passa allo zaino quando la aspira.
## Il livello fa parte dei checkpoint (gruppo "persist").
## La grafica (muri e acqua) è provvisoria: l'acqua vera arriverà dal lavoro su labs/acqua.

signal level_changed(fill: float)
signal filled
signal emptied
## Il colore dell'acqua è cambiato (vedi WaterMix).
signal mix_changed(mix: Dictionary)

@export var inner_size := Vector3(5.0, 3.0, 7.0):
	set(value):
		inner_size = value
		_rebuild()
@export var wall_thickness := 0.5:
	set(value):
		wall_thickness = value
		_rebuild()
## Se falso non costruisce muri e fondo: serve quando la vasca c'è già nella scena
## (per esempio la pozza sul fondo della piscina).
@export var build_walls := true:
	set(value):
		build_walls = value
		_rebuild()
## Materiale dell'acqua (vuoto = segnaposto). Qui va lo shader del laboratorio labs/acqua.
@export var water_material: Material:
	set(value):
		water_material = value
		_own_material = null
		_base_colors = {}
		if _surface:
			_surface.material_override = value if value else Graybox.WATER
			_update_color()
## Riempimento attuale: 0 = vuota, 1 = piena fino al bordo.
@export_range(0.0, 1.0) var fill := 0.0:
	set(value):
		var v := clampf(value, 0.0, 1.0)
		if is_equal_approx(v, fill):
			return
		fill = v
		_update_water()
		level_changed.emit(fill)
## Riempimento massimo (frazione della profondità): l'acqua non arriva mai oltre.
@export_range(0.1, 1.0) var max_fill := 0.94
## Litri "di gioco" che servono per riempirla da vuota a piena (fill = 1).
@export var capacity_liters := 40.0
## Lo zaino può aspirare da questa vasca.
@export var suckable := true
## Se falso l'acqua del getto non entra (trabocca): il livello e il colore non cambiano.
@export var accepts_water := true
## Il pigmento dell'acqua che c'è all'inizio e che entra dai tubi di carico (vuoto = chiara).
@export var fill_pigment := ""
## Riserva che non finisce: aspirando, il livello non scende sotto questa frazione ma l'acqua
## continua a uscire (gli acquari colorati dell'enigma non si devono esaurire).
@export_range(0.0, 1.0) var min_fill := 0.0
## Secondi per riempirla tutta con un tubo di carico acceso (fill_sources).
@export var fill_time := 8.0
## Secondi per svuotarla tutta con lo scarico aperto.
@export var drain_time := 6.0
## Se una di queste sorgenti è accesa lo scarico è aperto. Se la sorgente ha un'energia
## (turbina), lo scarico va più o meno forte in proporzione.
@export var drain_sources: Array[PowerSource] = []
## Se una di queste sorgenti è accesa entra acqua da sola (tubo di carico).
@export var fill_sources: Array[PowerSource] = []
## Perdita continua (frazione al secondo).
@export var leak_rate := 0.0
## Ampiezza delle onde della superficie (m).
@export var wave_amplitude := 0.02

## Il colore dell'acqua dentro (WaterMix): {pigmento: frazione}, vuoto = chiara.
var mix := {}
var _pending_liters := 0.0
var _pending_mix := {}
var _own_material: Material
var _base_colors := {}
var _full_sent := false
var _empty_sent := true
var _time := 0.0
var _vis: Node3D
var _surface: MeshInstance3D
var _volume: WaterVolume
var _volume_shape: CollisionShape3D


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group(&"water_catchers")
	add_to_group(&"persist")
	if suckable:
		add_to_group(&"water_sources")
	if mix.is_empty() and fill > 0.0:
		mix = WaterMix.pura(fill_pigment)
	_update_color()
	_empty_sent = fill <= 0.001
	_full_sent = fill >= max_fill - 0.001


## Profondità dell'acqua in metri.
func get_level() -> float:
	return fill * inner_size.y


## Litri d'acqua contenuti.
func get_liters() -> float:
	return fill * capacity_liters


## Quota globale della superficie dell'acqua.
func get_surface_global_y() -> float:
	return to_global(Vector3(0.0, get_level(), 0.0)).y


## Quota globale del fondo interno.
func get_floor_global_y() -> float:
	return global_position.y


func is_draining() -> bool:
	return get_drain_strength() > 0.0


## Quanto è aperto lo scarico (0..1).
func get_drain_strength() -> float:
	var k := 0.0
	for s in drain_sources:
		if not is_instance_valid(s):
			continue
		if &"energy" in s:
			k = maxf(k, float(s.get(&"energy")) if s.powered else 0.0)
		elif s.powered:
			k = 1.0
	return k


## Il getto chiede se un punto d'impatto cade dentro la vasca.
func catches_point(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) <= inner_size.x * 0.5 + 0.02 and absf(l.z) <= inner_size.z * 0.5 + 0.02 \
		and l.y >= -0.05 and l.y <= inner_size.y + 0.3


## Se il segmento a→b attraversa la superficie dell'acqua scendendo, ritorna la frazione
## del segmento in cui lo fa (0..1); altrimenti -1. Così il getto si ferma sull'acqua.
func surface_hit_fraction(a: Vector3, b: Vector3) -> float:
	var level := get_level()
	if level < 0.02:
		return -1.0
	var la := to_local(a)
	var lb := to_local(b)
	if la.y < level or lb.y >= level:
		return -1.0
	var t := (la.y - level) / (la.y - lb.y)
	var p := la.lerp(lb, t)
	if absf(p.x) <= inner_size.x * 0.5 and absf(p.z) <= inner_size.z * 0.5:
		return t
	return -1.0


## Acqua arrivata col getto (litri), del colore [param water_mix] (vedi WaterMix).
func receive_water(liters: float, _point: Vector3, _direction: Vector3, water_mix := {}) -> void:
	if not accepts_water or liters <= 0.0:
		return
	_pending_mix = WaterMix.mescola(_pending_mix, _pending_liters, water_mix, liters)
	_pending_liters += liters


## Cambia il colore dell'acqua dentro.
func set_mix(m: Dictionary) -> void:
	if m == mix:
		return
	mix = m.duplicate()
	_update_color()
	mix_changed.emit(mix)


# --- Sorgente per l'aspirazione dello zaino -----------------------------------------------

## Basta puntare dentro la vasca (dal bordo in giù) entro la portata dello zaino:
## ritorna la frazione del segmento a→b in cui entra nello spazio interno, o -1.
func suction_hit_fraction(a: Vector3, b: Vector3) -> float:
	var la := to_local(a)
	var d := to_local(b) - la
	var lo := Vector3(-inner_size.x * 0.5, 0.0, -inner_size.z * 0.5)
	var hi := Vector3(inner_size.x * 0.5, inner_size.y + 0.25, inner_size.z * 0.5)
	var t0 := 0.0
	var t1 := 1.0
	for i in 3:
		if absf(d[i]) < 0.000001:
			if la[i] < lo[i] or la[i] > hi[i]:
				return -1.0
		else:
			var ta := (lo[i] - la[i]) / d[i]
			var tb := (hi[i] - la[i]) / d[i]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				return -1.0
	return t0


## Il punto della superficie da cui esce l'acqua aspirata (per la grafica).
func suction_visual_point(aim_point: Vector3) -> Vector3:
	var l := to_local(aim_point)
	l.x = clampf(l.x, -inner_size.x * 0.45, inner_size.x * 0.45)
	l.z = clampf(l.z, -inner_size.z * 0.45, inner_size.z * 0.45)
	l.y = get_level()
	return to_global(l)


func can_give_water() -> bool:
	return suckable and get_liters() > 0.01


## Toglie acqua dalla vasca (il livello scende subito). Ritorna i litri dati davvero.
func take_water(liters: float) -> float:
	if not suckable:
		return 0.0
	var got := minf(liters, get_liters())
	if got > 0.0:
		fill = clampf(fill - got / maxf(capacity_liters, 0.001), minf(min_fill, fill), 1.0)
	return got


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"fill": fill, "mix": mix.duplicate()}


func load_state(data: Dictionary) -> void:
	_pending_liters = 0.0
	_pending_mix = {}
	fill = float(data.get("fill", fill))
	set_mix(data.get("mix", mix))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var df := _pending_liters / maxf(capacity_liters, 0.001)
	var new_mix := mix
	if _pending_liters > 0.0 and fill < max_fill:
		new_mix = WaterMix.mescola(new_mix, get_liters(), _pending_mix, _pending_liters)
	_pending_liters = 0.0
	_pending_mix = {}
	if PowerSource.any_powered(fill_sources):
		df += delta / maxf(fill_time, 0.001)
		new_mix = WaterMix.mescola(new_mix, get_liters(), WaterMix.pura(fill_pigment), capacity_liters * delta / maxf(fill_time, 0.001))
	var drain := get_drain_strength()
	if drain > 0.0:
		df -= drain * delta / maxf(drain_time, 0.001)
	df -= leak_rate * delta
	if df != 0.0:
		fill = clampf(fill + df, 0.0, max_fill)
	_time += delta
	_update_surface_wave()
	if fill >= max_fill - 0.001:
		if not _full_sent:
			_full_sent = true
			filled.emit()
	else:
		_full_sent = false
	if fill <= 0.001:
		new_mix = {}
	set_mix(new_mix)
	if fill <= 0.001:
		if not _empty_sent:
			_empty_sent = true
			emptied.emit()
	else:
		_empty_sent = false


func _update_water() -> void:
	if _surface == null:
		return
	var level := get_level()
	_surface.visible = level > 0.01
	_update_surface_wave()
	var on := level > 0.02
	_volume_shape.disabled = not on
	if on:
		(_volume_shape.shape as BoxShape3D).size = Vector3(inner_size.x, level, inner_size.z)
		_volume_shape.position = Vector3(0, level * 0.5, 0)


func _update_surface_wave() -> void:
	if _surface == null:
		return
	var level := get_level()
	var w := wave_amplitude * clampf(level / 0.3, 0.0, 1.0)
	_surface.position.y = level + sin(_time * 1.7) * w


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_vis):
		_vis.free()
	_vis = Node3D.new()
	_vis.name = "Graybox"
	add_child(_vis, false, Node.INTERNAL_MODE_FRONT)
	var t := wall_thickness
	var s := inner_size
	if not build_walls:
		_build_water(s)
		return
	var body := StaticBody3D.new()
	body.name = "Muri"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	_vis.add_child(body)
	var parts := [
		[Vector3(s.x + 2.0 * t, t, s.z + 2.0 * t), Vector3(0, -t * 0.5, 0), Graybox.FLOOR],
		[Vector3(t, s.y + t, s.z + 2.0 * t), Vector3(-(s.x + t) * 0.5, (s.y - t) * 0.5, 0), Graybox.WALL],
		[Vector3(t, s.y + t, s.z + 2.0 * t), Vector3((s.x + t) * 0.5, (s.y - t) * 0.5, 0), Graybox.WALL],
		[Vector3(s.x, s.y + t, t), Vector3(0, (s.y - t) * 0.5, -(s.z + t) * 0.5), Graybox.WALL],
		[Vector3(s.x, s.y + t, t), Vector3(0, (s.y - t) * 0.5, (s.z + t) * 0.5), Graybox.WALL],
	]
	for p in parts:
		Graybox.box(body, p[0], p[1], p[2])
		Graybox.box_shape(body, p[0], p[1])
	_build_water(s)


func _build_water(s: Vector3) -> void:
	# Superficie dell'acqua.
	_surface = MeshInstance3D.new()
	_surface.name = "Superficie"
	var plane := PlaneMesh.new()
	plane.size = Vector2(s.x, s.z)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	_surface.mesh = plane
	_surface.material_override = water_material if water_material else Graybox.WATER
	_update_color()
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vis.add_child(_surface)
	# Volume d'acqua per il giocatore (passi nell'acqua, ricarica del serbatoio).
	_volume = WaterVolume.new()
	_volume.name = "Volume"
	_volume.suckable = false
	_vis.add_child(_volume)
	_volume_shape = CollisionShape3D.new()
	_volume_shape.shape = BoxShape3D.new()
	_volume.add_child(_volume_shape)
	_update_water()


## Il colore della superficie segue [member mix]. Del materiale (il segnaposto o uno standard) se ne
## fa una copia tutta sua e ne cambia il colore: albedo_color, o shallow_color e deep_color dello
## shader segnaposto. Con un altro shader lo fa chi ascolta [signal mix_changed].
func _update_color() -> void:
	if _surface == null:
		return
	if _own_material == null:
		var m := _surface.material_override
		if m == null or (mix.is_empty() and fill_pigment == ""):
			return
		_own_material = m.duplicate() as Material
		if _own_material is BaseMaterial3D:
			_base_colors = {&"albedo_color": (_own_material as BaseMaterial3D).albedo_color}
		elif _own_material is ShaderMaterial:
			for k in [&"shallow_color", &"deep_color"]:
				var c = (_own_material as ShaderMaterial).get_shader_parameter(k)
				if c is Color:
					_base_colors[k] = c
		_surface.material_override = _own_material
	for k in _base_colors:
		var base: Color = _base_colors[k]
		var c := WaterMix.colore(mix, base)
		if k == &"deep_color":
			# Il fondo dello stesso colore, più scuro.
			c = base.lerp(WaterMix.tinta(mix) * 0.35, WaterMix.intensita(mix))
			c.a = base.a
		if _own_material is BaseMaterial3D:
			_own_material.set(k, c)
		else:
			(_own_material as ShaderMaterial).set_shader_parameter(k, c)
