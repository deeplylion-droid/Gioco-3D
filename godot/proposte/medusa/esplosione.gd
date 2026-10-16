extends Node3D
## PROPOSTA (riscontro 4 della v0.3.2, non usata dal gioco): quando lei scivola nella fossa dell'area
## bimbi non svanisce più e basta: dall'acqua si alza un'esplosione d'acqua che la avvolge tutta, lei
## sparisce lì dentro e l'acqua ricade nella fossa.
## Versioni:
##   A "geyser": una colonna d'acqua spumosa che spara dritta in alto (circa 4 m) intorno a lei, con
##     una fontana di gocce; poi crolla e ricade come una pioggia pesante.
##   B "cupola": una corona d'acqua che si alza, si allarga e si chiude sopra di lei come una
##     campana; poi scoppia verso fuori in spruzzi e ricade.
## Uso: var e := preload(...).new(); e.versione = "A"; add_child(e); e.scoppia(centro, pelo, lei)
## dove centro è il punto sopra la fossa dove sta lei e pelo la quota dell'acqua. Lei (LeiSbuca)
## sparisce quando è coperta del tutto (_fuga: resta la sua luce sott'acqua).

const SHADER := preload("res://proposte/medusa/esplosione_acqua.gdshader")
const GOCCIA := preload("res://proposte/medusa/goccia_chiara.gdshader")

const STILI := {
	"A": {"forma": 0.0, "altezza": 3.8, "raggio": 1.3, "sale": 0.32, "nasconde": 0.38, "crolla": 0.75,
		"crollo_durata": 1.2, "spinta": Vector2(8.0, 12.0), "spread": 14.0, "gocce": 1400, "nebbia": 70},
	"B": {"forma": 1.0, "altezza": 2.9, "raggio": 1.55, "sale": 0.4, "nasconde": 0.5, "crolla": 0.95,
		"crollo_durata": 1.0, "spinta": Vector2(5.0, 8.0), "spread": 40.0, "gocce": 1200, "nebbia": 80},
}

var versione := "A"
var s: Dictionary
var _t := -1.0
var _lei: Node
var _acque: Array = []
var _muro: MeshInstance3D
var _mat: ShaderMaterial
var _gocce: GPUParticles3D
var _goccioloni: GPUParticles3D
var _pioggia: GPUParticles3D
var _nebbia: GPUParticles3D
var _nascosta := false
var _crollata := false


func scoppia(centro: Vector3, pelo: float, lei: Node = null, acque: Array = []) -> void:
	s = STILI[versione]
	_lei = lei
	_acque = acque
	global_position = Vector3(centro.x, pelo - 0.05, centro.z)
	_crea()
	_t = 0.0
	_spruzza(1.6)
	for p in [_gocce, _goccioloni, _nebbia]:
		p.restart()
		p.emitting = true


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var k := clampf(_t / s.sale, 0.0, 1.0)
	var su := 1.0 - pow(1.0 - k, 3.0)
	_mat.set_shader_parameter(&"altezza", s.altezza * su)
	_mat.set_shader_parameter(&"chiusura", smoothstep(0.15, 0.6, _t / s.crolla))
	var c := clampf((_t - s.crolla) / s.crollo_durata, 0.0, 1.0)
	_mat.set_shader_parameter(&"crollo", c)
	_muro.visible = c < 1.0
	if not _nascosta and _t >= s.nasconde:
		_nascosta = true
		if _lei and _lei.has_method(&"_fuga"):
			_lei.call(&"_fuga")
	if not _crollata and _t >= s.crolla:
		_crollata = true
		_pioggia.restart()
		_pioggia.emitting = true
		_spruzza(1.0)
	if _crollata and _t >= s.crolla + s.crollo_durata * 0.7 and _t < s.crolla + s.crollo_durata * 0.7 + delta:
		_spruzza(0.6)
	if _t > 6.0:
		queue_free()


func _crea() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var giri := 56
	var piani := 28
	for j in piani:
		for i in giri:
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
				var u := float(q[0]) / giri
				var v := float(q[1]) / piani
				st.set_uv(Vector2(u, v))
				st.add_vertex(Vector3(cos(u * TAU), v, sin(u * TAU)))
	var mesh := st.commit()
	_muro = MeshInstance3D.new()
	_muro.mesh = mesh
	_muro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muro.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 7, 8))
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter(&"forma", s.forma)
	_mat.set_shader_parameter(&"raggio", s.raggio)
	_mat.set_shader_parameter(&"altezza", 0.0)
	_muro.material_override = _mat
	add_child(_muro)
	var chiara := ShaderMaterial.new()
	chiara.shader = GOCCIA
	chiara.set_shader_parameter(&"tint", Color(0.88, 0.94, 1.0))
	chiara.set_shader_parameter(&"opacity", 0.7)
	chiara.set_shader_parameter(&"rim_light", 0.8)
	# La fontana: dal bordo del muro verso l'alto (A dritta, B aperta a ventaglio).
	_gocce = WaterParticles.make_droplets(s.gocce * 2, 1.5, Vector2(0.018, 0.09))
	var gm: ParticleProcessMaterial = _gocce.process_material
	gm.direction = Vector3.UP
	gm.spread = s.spread
	gm.initial_velocity_min = s.spinta.x
	gm.initial_velocity_max = s.spinta.y
	gm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	gm.emission_ring_axis = Vector3.UP
	gm.emission_ring_radius = s.raggio * 0.95
	gm.emission_ring_inner_radius = s.raggio * 0.5
	gm.emission_ring_height = 0.2
	_one_shot(_gocce, 0.85, chiara)
	_goccioloni = WaterParticles.make_droplets(int(s.gocce * 0.3), 1.8, Vector2(0.03, 0.14))
	var bm: ParticleProcessMaterial = _goccioloni.process_material
	bm.direction = Vector3.UP
	bm.spread = s.spread + 15.0
	bm.initial_velocity_min = s.spinta.x * 0.5
	bm.initial_velocity_max = s.spinta.y * 0.75
	bm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	bm.emission_sphere_radius = s.raggio
	bm.gravity = Vector3(0, -12.0, 0)
	_one_shot(_goccioloni, 0.7, chiara)
	# La pioggia quando crolla: dalla cima del muro, in giù e un po' verso fuori.
	_pioggia = WaterParticles.make_droplets(s.gocce * 2, 1.3, Vector2(0.015, 0.14))
	var pm: ParticleProcessMaterial = _pioggia.process_material
	pm.direction = Vector3.DOWN
	pm.spread = 35.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 3.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(s.raggio * 1.2, s.altezza * 0.35, s.raggio * 1.2)
	pm.gravity = Vector3(0, -14.0, 0)
	_one_shot(_pioggia, 0.4, chiara)
	_pioggia.position = Vector3(0.0, s.altezza * 0.55, 0.0)
	# La nebbia d'acqua dentro e intorno: la copre mentre sparisce.
	_nebbia = WaterParticles.make_mist(s.nebbia, 2.2, 1.1)
	var nm: ParticleProcessMaterial = _nebbia.process_material
	nm.direction = Vector3.UP
	nm.spread = 60.0
	nm.initial_velocity_min = 1.0
	nm.initial_velocity_max = 3.5
	nm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	nm.emission_sphere_radius = s.raggio * 0.8
	_one_shot(_nebbia, 0.8, null)
	_nebbia.position = Vector3(0.0, 0.8, 0.0)


func _one_shot(p: GPUParticles3D, esplosivo: float, mat: Material) -> void:
	p.one_shot = true
	p.explosiveness = esplosivo
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-8, -3, -8), Vector3(16, 10, 16))
	if mat:
		(p.draw_pass_1 as QuadMesh).material = mat
	add_child(p)


## Onde sull'acqua delle vasche: un anello di schizzi intorno al muro.
func _spruzza(forza: float) -> void:
	for a in _acque:
		if a and a.has_method(&"splash"):
			a.call(&"splash", global_position, forza)
			for i in 6:
				var ang := TAU * i / 6.0
				a.call(&"splash", global_position + Vector3(cos(ang), 0.0, sin(ang)) * s.raggio, forza * 0.5)
			break
