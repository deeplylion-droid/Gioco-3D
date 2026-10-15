@tool
class_name WaterBody
extends Node3D
## Massa d'acqua (una vasca o una pozza): superficie, livello che sale e scende, increspature
## interattive, gorghi e aspirazione, riflessi e schizzi.
##
## Il nodo va messo al centro dell'area d'acqua (in pianta); `size` e' il rettangolo che la
## contiene. La superficie e' un piano: dove il fondo e' piu' alto del livello viene coperta dal
## fondo stesso, quindi una pozza su un fondo inclinato si restringe da sola quando si svuota.
## `level` e' la quota del pelo dell'acqua in coordinate del mondo, `bottom` quella del punto
## piu' profondo. Le superfici che usano wet_surface.gdshader (o water_receiver.gdshaderinc)
## ricevono da qui caustiche, banda bagnata e nebbia sott'acqua.

signal level_changed(level: float)
signal emptied
signal filled

## Layer di rendering della superficie dell'acqua (escluso dai riflessi delle ReflectionProbe).
const WATER_LAYER := 1 << 19
## Layer consigliato per l'interno delle vasche (escluso dal riflesso planare).
const POOL_INTERIOR_LAYER := 1 << 18

const SURFACE_SHADER := preload("res://addons/acqua/shaders/water_surface.gdshader")
const NORMAL_A := preload("res://addons/acqua/textures/water_normal_a.png")
const NORMAL_B := preload("res://addons/acqua/textures/water_normal_b.png")
const FOAM_TEX := preload("res://addons/acqua/textures/foam.png")

@export var size := Vector2(12.0, 7.0):
	set(v):
		size = v
		_rebuild_surface()
		_mark_dirty()
## Quota del pelo dell'acqua (mondo).
@export var level := -0.3:
	set(v):
		level = v
		if not _animating:
			target_level = v
		_apply_level()
## Quota del punto piu' profondo del fondo (mondo): sotto questa la vasca e' vuota.
@export var bottom := -2.2:
	set(v):
		bottom = v
		_apply_level()
## Livello massimo (bordo della vasca).
@export var max_level := -0.1
@export var style: WaterStyle:
	set(v):
		if style and style.changed.is_connected(_apply_style):
			style.changed.disconnect(_apply_style)
		style = v
		if style:
			style.changed.connect(_apply_style)
		_apply_style()

@export_group("Livello")
## Velocita' con cui il livello va verso `target_level` (m/s).
@export var fill_speed := 0.12
## Velocita' con cui la banda bagnata sulle pareti si asciuga (m/s).
@export var dry_speed := 0.01

@export_group("Scarico")
## Se vero, quando il livello scende si forma un gorgo sullo scarico.
@export var vortex_on_drain := false
## Posizione dello scarico (coordinate locali del nodo, in pianta).
@export var drain_position := Vector3.ZERO
## Raggio del gorgo (m).
@export var drain_vortex_radius := 1.6
## Verso di rotazione (+1 o -1) e profondita' massima dell'imbuto (m).
@export var drain_swirl := 1.0
@export var drain_funnel_depth := 0.18

@export_group("Increspature")
@export var simulate_ripples := true
## Metri per texel della simulazione per qualita' bassa/media/alta.
@export var ripple_cell_size := Vector3(0.1, 0.05, 0.025)
@export var ripple_max_resolution := 512
@export var ripple_wave_speed := 0.55

@export_group("Riflessi")
## Riflesso planare quando la qualita' e' alta (rende di nuovo la scena a mezza risoluzione:
## conviene attivarlo solo sulla vasca principale, quella vista piu' spesso).
@export var planar_reflection_on_high := false
## Scatola della stanza per i riflessi di riserva (cubemap con proiezione su scatola).
@export var env_box_min := Vector3(-10, -3, -8)
@export var env_box_max := Vector3(10, 6, 8)
## Altezza (rispetto al livello) da cui si cattura la cubemap di riserva.
@export var env_capture_height := 1.6
@export var capture_env_cubemap := true

var target_level := -0.3
var wet_level := -0.3
var material: ShaderMaterial
var ripple_sim: WaterRippleSim

var _surface: MeshInstance3D
var _animating := false
var _planar: Node3D
var _env_capture: Node
var _ripple_res := 0
var _quality := 2
# flussi: [punto (x, z, raggio, intensita'), forma (rotazione, imbuto, richiamo, schiuma)]
var _flows: Array = [[Vector4(0, 0, 1, 0), Vector4(1, 0.3, 0.35, 0.8)], [Vector4(0, 0, 1, 0), Vector4(0.2, 0.08, 1.0, 0.5)]]
var _was_empty := false


func _ready() -> void:
	target_level = level
	wet_level = level
	_rebuild_surface()
	_apply_style()
	_apply_level()
	var wm := _wm()
	if wm:
		wm.register_body(self)
	if Engine.is_editor_hint() or wm == null:
		return
	# subito (prima del primo aggiornamento delle sonde) e di nuovo dopo, per quelle create dopo
	_exclude_from_probes()
	_exclude_from_probes.call_deferred()
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	wm.quality_changed.connect(_on_quality_changed)
	_on_quality_changed(wm.quality)
	_was_empty = is_empty()


func _exit_tree() -> void:
	print_verbose("WaterBody uscita: ", name)
	var wm := _wm()
	if wm:
		wm.unregister_body(self)
	if ripple_sim:
		ripple_sim.free_gpu()
		ripple_sim = null
	print_verbose("WaterBody uscita fatta: ", name)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var old := level
	if not is_equal_approx(level, target_level):
		_animating = true
		level = move_toward(level, target_level, fill_speed * delta)
		_animating = false
		level_changed.emit(level)
	# banda bagnata che si asciuga
	if level > wet_level:
		wet_level = level
	else:
		wet_level = maxf(level, wet_level - dry_speed * delta)
	# gorgo sullo scarico mentre si svuota
	if vortex_on_drain:
		var draining := level < old - 1e-6
		var depth_left := clampf((level - bottom) / 0.12, 0.0, 1.0)
		var cur: float = _flows[0][0].w
		var want := (1.0 if draining else 0.0) * depth_left
		var k := move_toward(cur, want, delta * 0.6)
		var dp := global_transform * drain_position
		set_flow(0, dp, drain_vortex_radius, k, drain_swirl, drain_funnel_depth * depth_left, 0.35, 0.9)
		if draining and k > 0.2:
			add_impulse(dp, drain_vortex_radius * 0.15, -0.004 * k, 0.03)
	var empty := is_empty()
	if empty and not _was_empty:
		emptied.emit()
	elif level >= max_level - 1e-3 and old < max_level - 1e-3:
		filled.emit()
	_was_empty = empty
	_mark_dirty()
	if ripple_sim:
		ripple_sim.step(delta)


# --- API -------------------------------------------------------------------------------------

## Porta il livello a `new_level` con la velocita' `fill_speed` (o quella indicata).
func set_target_level(new_level: float, speed := -1.0) -> void:
	target_level = clampf(new_level, bottom, max_level)
	if speed > 0.0:
		fill_speed = speed


func fill(speed := -1.0) -> void:
	set_target_level(max_level, speed)


func drain(speed := -1.0) -> void:
	set_target_level(bottom, speed)


## Toglie (o aggiunge, se negativo) un volume d'acqua in m^3: il livello scende di volume / area.
## Serve allo zaino-pompa che aspira.
func remove_volume(m3: float) -> void:
	var area := maxf(size.x * size.y, 0.01)
	level = clampf(level - m3 / area, bottom, max_level)
	target_level = level


func is_empty() -> bool:
	return level <= bottom + 0.01


func is_filling() -> bool:
	return target_level > level + 1e-4


func is_draining() -> bool:
	return target_level < level - 1e-4


func contains_xz(p: Vector3, margin := 0.0) -> bool:
	var c := global_position
	return absf(p.x - c.x) <= size.x * 0.5 + margin and absf(p.z - c.z) <= size.y * 0.5 + margin


## Quota della superficie in un punto (con un'approssimazione delle onde, per i galleggianti).
func get_surface_height(p: Vector3) -> float:
	var wm := _wm()
	var t: float = wm.time if wm else 0.0
	var w := 0.006 * sin(p.x * 1.7 + t * 1.3) + 0.005 * sin(p.z * 2.3 - t * 1.1)
	return level + w - _flow_dip(Vector2(p.x, p.z))


## Velocita' dell'acqua in superficie (m/s, in pianta) dovuta a gorghi e aspirazione.
func get_flow_velocity(p: Vector3) -> Vector2:
	var v := Vector2.ZERO
	var xz := Vector2(p.x, p.z)
	for f in _flows:
		var fp: Vector4 = f[0]
		var fs: Vector4 = f[1]
		if fp.w <= 0.0:
			continue
		var d := xz - Vector2(fp.x, fp.y)
		var r := d.length() + 1e-4
		var dir := d / r
		var tang := Vector2(-dir.y, dir.x)
		var w := fp.w * (1.0 - smoothstep(fp.z * 0.45, fp.z, r))
		v += (tang * fs.x - dir * fs.z) * w * 0.5 / (r + 0.2)
	return v


## Imposta un gorgo o un punto di aspirazione (slot 0 o 1). `strength` 0 lo spegne.
## swirl: rotazione (segno = verso); funnel_depth: profondita' dell'imbuto (m);
## pull: richiamo verso il centro; foam: schiuma a spirale.
func set_flow(slot: int, world_pos: Vector3, radius: float, strength: float, swirl := 1.0,
		funnel_depth := 0.3, pull := 0.35, foam := 0.8) -> void:
	slot = clampi(slot, 0, 1)
	_flows[slot] = [Vector4(world_pos.x, world_pos.z, radius, clampf(strength, 0.0, 1.0)),
			Vector4(swirl, funnel_depth, pull, foam)]
	if material:
		material.set_shader_parameter("flow_point_%d" % slot, _flows[slot][0])
		material.set_shader_parameter("flow_shape_%d" % slot, _flows[slot][1])


func clear_flow(slot: int) -> void:
	set_flow(slot, Vector3.ZERO, 1.0, 0.0)


## Increspatura: `amplitude` in metri, raggio in metri; `foam` 0..1 aggiunge schiuma.
func add_impulse(world_pos: Vector3, radius: float, amplitude: float, foam := 0.0) -> void:
	if ripple_sim and not is_empty():
		ripple_sim.add_impulse(world_pos, radius, amplitude, foam)


## Schizzo completo: increspatura, schiuma e particelle. `strength` circa 0.2 (goccia) .. 2 (tuffo).
func splash(world_pos: Vector3, strength := 1.0) -> void:
	if is_empty():
		return
	var p := Vector3(world_pos.x, level, world_pos.z)
	add_impulse(p, 0.12 + 0.18 * strength, -0.03 * strength, 0.5 * minf(strength, 1.0))
	add_impulse(p, 0.35 + 0.3 * strength, 0.012 * strength, 0.0)
	if is_inside_tree():
		var s := WaterSplash.new()
		get_tree().current_scene.add_child(s)
		s.global_position = p
		s.play(strength)


## Righe per la tabella globale degli shader (4 colori RGBA float).
func get_shader_rows() -> Array:
	var c := global_position
	var st := style if style else WaterStyle.new()
	var fog := st.underwater_fog_color
	return [
		Color(c.x - size.x * 0.5, c.z - size.y * 0.5, c.x + size.x * 0.5, c.z + size.y * 0.5),
		Color(level, wet_level, st.caustics_strength if not is_empty() else 0.0, st.caustics_scale),
		Color(st.absorption.x, st.absorption.y, st.absorption.z, st.turbidity),
		Color(fog.r, fog.g, fog.b, bottom),
	]


func get_rect() -> Rect2:
	var c := global_position
	return Rect2(c.x - size.x * 0.5, c.z - size.y * 0.5, size.x, size.y)


func get_surface() -> MeshInstance3D:
	return _surface


# --- interni ---------------------------------------------------------------------------------

func _wm() -> Node:
	return get_node_or_null("/root/WaterManager") if is_inside_tree() else null


func _mark_dirty() -> void:
	var wm := _wm()
	if wm:
		wm.mark_bodies_dirty()


func _flow_dip(xz: Vector2) -> float:
	var dip := 0.0
	for f in _flows:
		var fp: Vector4 = f[0]
		var fs: Vector4 = f[1]
		if fp.w <= 0.0:
			continue
		var r := xz.distance_to(Vector2(fp.x, fp.y))
		var q := r / maxf(fp.z * 0.14, 0.02)
		dip += fs.y * fp.w / (1.0 + q * q) * (1.0 - smoothstep(fp.z * 0.55, fp.z, r))
	return dip


func _rebuild_surface() -> void:
	if not is_inside_tree():
		return
	if _surface == null:
		_surface = MeshInstance3D.new()
		_surface.name = "Surface"
		_surface.layers = WATER_LAYER
		_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_surface.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(_surface, false, Node.INTERNAL_MODE_FRONT)
	# densita' della griglia: serve per le onde della simulazione e per l'imbuto dei gorghi
	var cell: float = [0.25, 0.1, 0.05][_quality]
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = clampi(int(size.x / cell), 4, 320)
	pm.subdivide_depth = clampi(int(size.y / cell), 4, 320)
	_surface.mesh = pm
	if material == null:
		material = ShaderMaterial.new()
		material.shader = SURFACE_SHADER
		material.set_shader_parameter("normal_a", NORMAL_A)
		material.set_shader_parameter("normal_b", NORMAL_B)
		material.set_shader_parameter("foam_tex", FOAM_TEX)
	_surface.material_override = material
	_surface.extra_cull_margin = 0.5


func _apply_level() -> void:
	if _surface:
		_surface.position = Vector3(0.0, level - global_position.y if is_inside_tree() else level, 0.0)
		_surface.visible = level > bottom + 0.005
	_mark_dirty()


func _apply_style() -> void:
	if material == null:
		return
	var st := style if style else WaterStyle.new()
	material.set_shader_parameter("absorption", st.absorption)
	material.set_shader_parameter("turbidity", st.turbidity)
	material.set_shader_parameter("scatter_color", st.scatter_color)
	material.set_shader_parameter("scatter_ambient", st.scatter_ambient)
	material.set_shader_parameter("glow_scatter", st.glow_scatter)
	material.set_shader_parameter("roughness", st.roughness)
	material.set_shader_parameter("wave_strength_a", st.wave_strength_a)
	material.set_shader_parameter("wave_strength_b", st.wave_strength_b)
	material.set_shader_parameter("wave_speed", st.wave_speed)
	material.set_shader_parameter("refraction_strength", st.refraction_strength)
	material.set_shader_parameter("reflection_strength", st.reflection_strength)
	material.set_shader_parameter("reflection_stretch", st.reflection_stretch)
	material.set_shader_parameter("foam_color", st.foam_color)
	material.set_shader_parameter("foam_shore_amount", st.foam_shore_amount)
	material.set_shader_parameter("foam_shore_width", st.foam_shore_width)
	material.set_shader_parameter("foam_ripple_amount", st.foam_ripple_amount)
	material.set_shader_parameter("scum_amount", st.scum_amount)
	material.set_shader_parameter("scum_color", st.scum_color)
	material.set_shader_parameter("env_box_min", env_box_min)
	material.set_shader_parameter("env_box_max", env_box_max)
	for i in 2:
		material.set_shader_parameter("flow_point_%d" % i, _flows[i][0])
		material.set_shader_parameter("flow_shape_%d" % i, _flows[i][1])
	_mark_dirty()


func _on_quality_changed(q: int) -> void:
	_quality = q
	_rebuild_surface()
	# riflessi
	var mode := 1
	if q == 0:
		mode = 0
	elif q == 2 and planar_reflection_on_high:
		mode = 2
	material.set_shader_parameter("ssr_steps", [12, 24, 40][q])
	_set_planar(mode == 2)
	material.set_shader_parameter("reflection_mode", mode)
	# increspature (si ricrea la simulazione solo se cambia la risoluzione)
	var cell: float = [ripple_cell_size.x, ripple_cell_size.y, ripple_cell_size.z][q]
	var res: int = clampi(int(maxf(size.x, size.y) / cell), 32, ripple_max_resolution)
	if ripple_sim and (not simulate_ripples or res != _ripple_res):
		ripple_sim.free_gpu()
		ripple_sim = null
	if simulate_ripples and ripple_sim == null:
		_ripple_res = res
		ripple_sim = WaterRippleSim.new()
		ripple_sim.wave_speed = ripple_wave_speed
		ripple_sim.setup(get_rect(), res)
	var r := get_rect()
	material.set_shader_parameter("ripple_tex", ripple_sim.texture if ripple_sim else null)
	material.set_shader_parameter("ripple_rect",
			Vector4(r.position.x, r.position.y, r.size.x, r.size.y) if ripple_sim else Vector4.ZERO)
	if capture_env_cubemap and _env_capture == null:
		_start_env_capture.call_deferred()


func _set_planar(enabled: bool) -> void:
	if enabled and _planar == null:
		_planar = WaterPlanarReflection.new()
		_planar.name = "PlanarReflection"
		add_child(_planar, false, Node.INTERNAL_MODE_BACK)
		_planar.setup(self)
	elif not enabled and _planar != null:
		_planar.queue_free()
		_planar = null


func _start_env_capture() -> void:
	_env_capture = WaterEnvCapture.new()
	_env_capture.name = "EnvCapture"
	add_child(_env_capture, false, Node.INTERNAL_MODE_BACK)
	_env_capture.capture(self)


func _on_node_added(n: Node) -> void:
	if n is ReflectionProbe:
		n.reflection_mask &= ~WATER_LAYER
		n.cull_mask &= ~WATER_LAYER


## Le ReflectionProbe non devono ne' riflettersi sull'acqua (i riflessi li calcola lo shader) ne'
## catturarla (lo shader dell'acqua legge lo schermo, che dentro una cattura non e' valido).
func _exclude_from_probes() -> void:
	for probe in get_tree().root.find_children("*", "ReflectionProbe", true, false):
		probe.reflection_mask &= ~WATER_LAYER
		probe.cull_mask &= ~WATER_LAYER
