class_name GeyserFossa
extends Node3D
## Quando lei scivola nella fossa dell'area bimbi (tappa 8) non svanisce più e basta: un geyser
## d'acqua si alza dalla fossa e la copre tutta, lei sparisce lì dentro e l'acqua ricade nella fossa e
## sul pavimento intorno (riscontro 4 della v0.3.2; scelta dell'utente del 17 ottobre: A, geyser,
## "l'acqua non deve essere trasparente").
## - La colonna (geyser_acqua.gdshader): acqua bianca di schiuma, piena, che al piede trabocca dal
##   bordo della fossa e copre anche i tentacoli stesi sul pavimento; spara a [member altezza] m in
##   [member sale] s e dopo [member crolla] s ricade in [member crollo_durata] s.
## - Fontana di gocce, goccioloni, polvere d'acqua finissima, pioggia quando crolla, schizzi sul
##   pavimento e onde sull'acqua della fossa (gocce con la goccia chiara: riflessi speculari).
## Lei (LeiSbuca) deve sparire solo quando è coperta: [member copre] è quando la colonna la nasconde
## del tutto. Il suono (lei_esplosione) lo fa partire LeiSbuca.
## Uso: geyser.scoppia(pavimento, acque) con il punto sul pavimento al centro della fossa.

const SHADER := preload("res://addons/grafica/geyser_acqua.gdshader")
const GOCCIA := preload("res://addons/grafica/goccia_chiara.gdshader")

@export var altezza := 4.2
@export var raggio := 1.3
@export var sale := 0.32
## Da quando (s) la colonna la copre tutta: da qui lei può sparire.
@export var copre := 0.3
@export var crolla := 0.85
@export var crollo_durata := 1.2
@export var gocce := 1600

var _t := -1.0
var _acque: Array = []
var _muro: MeshInstance3D
var _mat: ShaderMaterial
var _gocce: GPUParticles3D
var _goccioloni: GPUParticles3D
var _pioggia: GPUParticles3D
var _polvere: GPUParticles3D
var _schizzi: GPUParticles3D
var _crollata := false
var _schizzata := false
var _prossimo_tonfo := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	_crea()
	set_process(false)


## Fa partire il geyser dal punto [param pavimento] (sul pavimento, al centro della fossa).
func scoppia(pavimento: Vector3, acque: Array = []) -> void:
	_acque = acque
	_rng.seed = 41
	global_position = pavimento
	_t = 0.0
	_crollata = false
	_schizzata = false
	_muro.visible = true
	_aggiorna_muro()
	_spruzza(0.9)
	for p in [_gocce, _goccioloni, _polvere]:
		p.restart()
		p.emitting = true
	set_process(true)


func in_corso() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	_t += delta
	_aggiorna_muro()
	if not _crollata and _t >= crolla:
		_crollata = true
		_pioggia.restart()
		_pioggia.emitting = true
		_spruzza(0.6)
	if not _schizzata and _t >= crolla + 0.25:
		_schizzata = true
		_schizzi.restart()
		_schizzi.emitting = true
	# La pioggia che ricade fa tante onde piccole sull'acqua della fossa.
	if _crollata and _t < crolla + crollo_durata + 0.3:
		_prossimo_tonfo -= delta
		if _prossimo_tonfo <= 0.0:
			_prossimo_tonfo = 0.12
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf()) * raggio * 1.3
			_tonfo(global_position + Vector3(cos(a) * r, 0.0, sin(a) * r), _rng.randf_range(0.06, 0.16))
	if _t > crolla + crollo_durata + 2.0:
		_t = -1.0
		set_process(false)


func _aggiorna_muro() -> void:
	var k := clampf(_t / sale, 0.0, 1.0)
	_mat.set_shader_parameter(&"altezza", altezza * (1.0 - pow(1.0 - k, 3.0)))
	var c := clampf((_t - crolla) / crollo_durata, 0.0, 1.0)
	_mat.set_shader_parameter(&"crollo", c)
	_muro.visible = c < 1.0


func _crea() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var giri := 64
	var piani := 32
	for j in piani:
		for i in giri:
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
				var u := float(q[0]) / giri
				var v := float(q[1]) / piani
				st.set_uv(Vector2(u, v))
				st.add_vertex(Vector3(cos(u * TAU), v, sin(u * TAU)))
	_muro = MeshInstance3D.new()
	_muro.name = "Colonna"
	_muro.mesh = st.commit()
	_muro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muro.custom_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 8, 10))
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter(&"raggio", raggio)
	_mat.set_shader_parameter(&"altezza", 0.0)
	_muro.material_override = _mat
	_muro.visible = false
	add_child(_muro)
	var chiara := _goccia(0.5, 0.7)
	var fine := _goccia(0.25, 0.5)
	# La fontana: dal bordo della colonna verso l'alto.
	_gocce = WaterParticles.make_droplets(gocce, 1.5, Vector2(0.02, 0.11))
	var gm: ParticleProcessMaterial = _gocce.process_material
	gm.direction = Vector3.UP
	gm.spread = 12.0
	gm.initial_velocity_min = 8.0
	gm.initial_velocity_max = 12.0
	gm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	gm.emission_ring_axis = Vector3.UP
	gm.emission_ring_radius = raggio * 0.95
	gm.emission_ring_inner_radius = raggio * 0.5
	gm.emission_ring_height = 0.2
	_one_shot(_gocce, 0.8, chiara)
	_gocce.position = Vector3(0.0, 0.45, 0.0)
	# Goccioloni: pesanti, ricadono prima e più vicino.
	_goccioloni = WaterParticles.make_droplets(int(gocce * 0.2), 1.8, Vector2(0.04, 0.17))
	var bm: ParticleProcessMaterial = _goccioloni.process_material
	bm.direction = Vector3.UP
	bm.spread = 27.0
	bm.initial_velocity_min = 4.0
	bm.initial_velocity_max = 9.0
	bm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	bm.emission_sphere_radius = raggio
	bm.gravity = Vector3(0, -12.0, 0)
	_one_shot(_goccioloni, 0.7, chiara)
	_goccioloni.position = Vector3(0.0, 0.45, 0.0)
	# Polvere d'acqua: goccioline finissime e leggere che spariscono in fretta (niente nebbia a palle).
	_polvere = WaterParticles.make_droplets(int(gocce * 0.6), 0.6, Vector2(0.007, 0.03))
	var dm: ParticleProcessMaterial = _polvere.process_material
	dm.direction = Vector3.UP
	dm.spread = 70.0
	dm.initial_velocity_min = 2.0
	dm.initial_velocity_max = 6.0
	dm.damping_min = 3.0
	dm.damping_max = 6.0
	dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	dm.emission_sphere_radius = raggio
	_one_shot(_polvere, 0.6, fine)
	_polvere.position = Vector3(0.0, 1.0, 0.0)
	# La pioggia quando crolla: dalla cima, in giù e un po' verso fuori.
	_pioggia = WaterParticles.make_droplets(gocce, 1.3, Vector2(0.015, 0.15))
	var pm: ParticleProcessMaterial = _pioggia.process_material
	pm.direction = Vector3.DOWN
	pm.spread = 35.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 3.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(raggio * 1.2, altezza * 0.35, raggio * 1.2)
	pm.gravity = Vector3(0, -14.0, 0)
	_one_shot(_pioggia, 0.4, chiara)
	_pioggia.position = Vector3(0.0, altezza * 0.6, 0.0)
	# Schizzi sul pavimento intorno alla fossa, dove arriva l'acqua che ricade.
	_schizzi = WaterParticles.make_droplets(900, 0.5, Vector2(0.012, 0.05))
	var zm: ParticleProcessMaterial = _schizzi.process_material
	zm.direction = Vector3.UP
	zm.spread = 50.0
	zm.initial_velocity_min = 1.2
	zm.initial_velocity_max = 3.2
	zm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	zm.emission_ring_axis = Vector3.UP
	zm.emission_ring_radius = 2.4
	zm.emission_ring_inner_radius = 1.4
	zm.emission_ring_height = 0.02
	_one_shot(_schizzi, 0.15, chiara)
	_schizzi.position = Vector3(0.0, 0.02, 0.0)


func _goccia(opacita: float, rim: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GOCCIA
	m.set_shader_parameter(&"tint", Color(0.72, 0.82, 0.9))
	m.set_shader_parameter(&"opacity", opacita)
	m.set_shader_parameter(&"rim_light", rim)
	return m


func _one_shot(p: GPUParticles3D, esplosivo: float, mat: Material) -> void:
	p.one_shot = true
	p.explosiveness = esplosivo
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-8, -3, -8), Vector3(16, 10, 16))
	if mat:
		(p.draw_pass_1 as QuadMesh).material = mat
	add_child(p)


## Onda sull'acqua della fossa. Come WaterBody.splash, ma con pochissima schiuma: quella dello
## splash fa chiazze bianche tonde sul pelo.
func _tonfo(pos: Vector3, forza: float) -> void:
	for a in _acque:
		if a and a.has_method(&"add_impulse"):
			var p := Vector3(pos.x, float(a.get(&"level")), pos.z)
			a.call(&"add_impulse", p, 0.12 + 0.18 * forza, -0.03 * forza, 0.06 * minf(forza, 1.0))
			a.call(&"add_impulse", p, 0.35 + 0.3 * forza, 0.012 * forza, 0.0)
			return


## Un anello di onde intorno alla colonna.
func _spruzza(forza: float) -> void:
	_tonfo(global_position, forza)
	for i in 6:
		var ang := TAU * i / 6.0
		_tonfo(global_position + Vector3(cos(ang), 0.0, sin(ang)) * raggio, forza * 0.5)
