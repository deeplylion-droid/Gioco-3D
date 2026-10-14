@tool
class_name SlideWater
extends Node3D
## Acqua che scorre dentro uno scivolo a tubo o a canale lungo una Curve3D (coordinate locali
## del nodo). Costruisce il nastro d'acqua sul fondo del tubo: nelle curve l'acqua risale sulla
## parete esterna (inclinazione da forza centrifuga, tan = v^2 * curvatura / g) e diventa piu'
## turbolenta, con schiuma e spruzzi. Alla fine dello scivolo l'acqua esce e cade nella vasca
## sotto (WaterInlet sempre acceso: getto, increspature, schiuma).

const FLOW_SHADER := preload("res://water/shaders/water_flow.gdshader")

@export var curve: Curve3D:
	set(v):
		curve = v
		_rebuild()
@export var tube_radius := 0.62:
	set(v):
		tube_radius = v
		_rebuild()
## Velocita' dell'acqua (m/s): decide quanto l'acqua sale nelle curve e quanto scorre in fretta.
@export var flow_speed := 3.5
## Larghezza angolare del nastro sul fondo del tubo (gradi).
@export var water_arc_degrees := 75.0
## Distanza tra le sezioni del nastro (m).
@export var step := 0.15
## Spruzzi nelle curve piu' strette.
@export var curve_spray := true
## Getto all'uscita dello scivolo.
@export var exit_pour := true
@export var rebuild := false:
	set(v):
		rebuild = false
		_rebuild()

var material: ShaderMaterial
var _mesh: MeshInstance3D
var _sprays: Array[Node3D] = []
var _pour: Node3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree() or curve == null or curve.point_count < 2:
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Water"
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh.layers = WaterBody.WATER_LAYER
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
	if material == null:
		material = ShaderMaterial.new()
		material.shader = FLOW_SHADER
		material.set_shader_parameter("normal_a", load("res://water/textures/water_normal_a.png"))
		material.set_shader_parameter("normal_b", load("res://water/textures/water_normal_b.png"))
		material.set_shader_parameter("foam_tex", load("res://water/textures/foam.png"))
	material.set_shader_parameter("flow_speed", flow_speed)
	material.set_shader_parameter("ribbon_width", tube_radius * deg_to_rad(water_arc_degrees))
	_mesh.mesh = _build_ribbon()
	_mesh.material_override = material
	if not Engine.is_editor_hint():
		_build_effects()


## Inclinazione (radianti, verso l'esterno della curva) e turbolenza per ogni sezione.
func _bank_profile(n: int, length: float) -> Array:
	var banks := PackedFloat32Array()
	var turbs := PackedFloat32Array()
	banks.resize(n)
	turbs.resize(n)
	for i in n:
		var o := length * float(i) / float(n - 1)
		var f0 := TubeBuilder.frame_at(curve, o - 0.3)
		var f1 := TubeBuilder.frame_at(curve, o + 0.3)
		var f := TubeBuilder.frame_at(curve, o)
		var dt := (f1.z - f0.z) / 0.6     # variazione della tangente = curvatura * normale
		var lateral := dt.dot(f.x)        # curvatura verso destra (+) o sinistra (-)
		# la forza centrifuga spinge l'acqua verso l'esterno della curva (lato opposto alla svolta)
		var bank := -atan(flow_speed * flow_speed * lateral / 9.8)
		banks[i] = clampf(bank, -1.2, 1.2)
	# addolcisce e calcola la turbolenza (dove l'inclinazione cambia in fretta)
	var smooth := banks.duplicate()
	for it in 3:
		for i in range(1, n - 1):
			smooth[i] = (banks[i - 1] + banks[i] * 2.0 + banks[i + 1]) * 0.25
		banks = smooth.duplicate()
	for i in n:
		var a := banks[maxi(i - 2, 0)]
		var b := banks[mini(i + 2, n - 1)]
		turbs[i] = clampf(absf(b - a) * 2.5 + absf(banks[i]) * 0.35, 0.0, 1.0)
	return [banks, turbs]


func _build_ribbon() -> ArrayMesh:
	var length := curve.get_baked_length()
	var n := maxi(2, int(ceil(length / step)) + 1)
	var prof := _bank_profile(n, length)
	var banks: PackedFloat32Array = prof[0]
	var turbs: PackedFloat32Array = prof[1]
	var cols := 9
	var arc := deg_to_rad(water_arc_degrees)
	var r := tube_radius - 0.012
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for i in n:
		var o := length * float(i) / float(n - 1)
		var c := curve.sample_baked(o)
		var f := TubeBuilder.frame_at(curve, o)
		var row := []
		for k in cols:
			var v := float(k) / float(cols - 1)
			var a := banks[i] + (v - 0.5) * arc
			var d := (-f.y * cos(a) + f.x * sin(a)).normalized()
			# superficie dell'acqua leggermente piatta: il centro sta un po' piu' in alto
			var flat := 1.0 - 0.06 * (1.0 - pow(absf(v - 0.5) * 2.0, 2.0))
			row.append([c + d * r * flat, -d, Vector2(o, v), Vector2(turbs[i], 1.0 if k == 0 or k == cols - 1 else 0.0)])
		rows.append(row)
	for i in n - 1:
		for k in cols - 1:
			var a: Array = rows[i][k]
			var b: Array = rows[i][k + 1]
			var c2: Array = rows[i + 1][k + 1]
			var d2: Array = rows[i + 1][k]
			for vtx in [a, d2, c2, a, c2, b]:
				st.set_normal(vtx[1])
				st.set_uv(vtx[2])
				st.set_uv2(vtx[3])
				st.add_vertex(vtx[0])
	st.generate_tangents()
	return st.commit()


func _build_effects() -> void:
	for s in _sprays:
		s.queue_free()
	_sprays.clear()
	if _pour:
		_pour.queue_free()
		_pour = null
	var length := curve.get_baked_length()
	var n := maxi(2, int(ceil(length / 0.5)) + 1)
	var prof := _bank_profile(n, length)
	var turbs: PackedFloat32Array = prof[1]
	var banks: PackedFloat32Array = prof[0]
	if curve_spray:
		for i in range(1, n - 1):
			if turbs[i] < 0.55 or (i > 1 and turbs[i - 1] >= 0.55):
				continue
			var o := length * float(i) / float(n - 1)
			var f := TubeBuilder.frame_at(curve, o)
			var c := curve.sample_baked(o)
			var spray := WaterParticles.make_droplets(70, 0.6, Vector2(0.012, 0.035))
			var pm: ParticleProcessMaterial = spray.process_material
			# gli spruzzi partono dalla parete esterna della curva, in avanti e verso l'interno
			var out_dir := (-f.y * cos(banks[i]) + f.x * sin(banks[i])).normalized()
			spray.position = c + out_dir * (tube_radius * 0.8)
			var dir_world := (f.z * 1.0 - out_dir * 0.5 + Vector3.UP * 0.3).normalized()
			pm.direction = dir_world
			pm.spread = 25.0
			pm.initial_velocity_min = flow_speed * 0.35
			pm.initial_velocity_max = flow_speed * 0.7
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = 0.12
			spray.local_coords = false
			spray.emitting = true
			add_child(spray)
			_sprays.append(spray)
	if exit_pour:
		var end_o := length
		var f := TubeBuilder.frame_at(curve, end_o)
		var inlet := WaterInlet.new()
		inlet.always_on = true
		inlet.exit_speed = flow_speed * 0.8
		inlet.drops_per_second = 260
		inlet.stream_width = tube_radius * 0.35
		add_child(inlet)
		inlet.position = curve.sample_baked(end_o) - f.y * (tube_radius * 0.75)
		# l'asse -Z del getto segue la tangente finale
		inlet.basis = Basis.looking_at(f.z, Vector3.UP)
		_pour = inlet
