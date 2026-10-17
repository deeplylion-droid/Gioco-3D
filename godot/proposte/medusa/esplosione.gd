extends Node3D
## PROPOSTA (riscontro 4 della v0.3.2, non usata dal gioco): quando lei scivola nella fossa dell'area
## bimbi non svanisce più e basta: dall'acqua si alza un'esplosione d'acqua che la avvolge tutta, lei
## sparisce lì dentro e l'acqua ricade nella fossa e sul pavimento intorno.
## Versioni:
##   A "geyser": una colonna d'acqua a lame trasparenti spara dritta in alto (circa 3,8 m) intorno a
##     lei, con una fontana di gocce; poi crolla e ricade come pioggia pesante.
##   B "cupola": una corona d'acqua sale e si chiude sopra di lei come una calotta trasparente su cui
##     l'acqua scorre; lei si intravede dentro mentre sparisce; poi scoppia verso fuori e ricade.
## Niente sprite di nebbia: solo veli d'acqua (esplosione_acqua.gdshader), gocce allungate con la
## goccia chiara (riflessi speculari), polvere d'acqua finissima che sparisce in fretta, schizzi sul
## pavimento e onde sull'acqua della fossa. Il suono (esplosione_a/b.ogg) è di
## assets_src/audio/proposte_esplosione/genera_boato.py, coi tempi di STILI.
## Uso: var e := preload(...).new(); e.versione = "A"; add_child(e); e.scoppia(centro, pelo, lei, acque)
## dove centro è il punto sopra la fossa dove sta lei, pelo la quota dell'acqua, lei la LeiSbuca.

const SHADER := preload("res://proposte/medusa/esplosione_acqua.gdshader")
const GOCCIA := preload("res://proposte/medusa/goccia_chiara.gdshader")
const SUONO := {"A": "res://proposte/medusa/esplosione_a.ogg", "B": "res://proposte/medusa/esplosione_b.ogg"}

const STILI := {
	"A": {"forma": 0.0, "altezza": 3.8, "raggio": 1.3, "sale": 0.32, "svanisce": Vector2(0.15, 0.45),
		"crolla": 0.75, "crollo_durata": 1.2, "spinta": Vector2(8.0, 12.0), "spread": 12.0, "gocce": 1600,
		"schizzi_r": Vector2(1.4, 2.4)},
	"B": {"forma": 1.0, "altezza": 2.9, "raggio": 1.55, "sale": 0.4, "svanisce": Vector2(0.3, 0.8),
		"crolla": 0.95, "crollo_durata": 1.0, "spinta": Vector2(5.0, 8.0), "spread": 40.0, "gocce": 1400,
		"schizzi_r": Vector2(1.8, 3.2)},
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
var _polvere: GPUParticles3D
var _schizzi: GPUParticles3D
var _nascosta := false
var _crollata := false
var _schizzata := false
var _prossimo_tonfo := 0.0
var _rng := RandomNumberGenerator.new()


func scoppia(centro: Vector3, pelo: float, lei: Node = null, acque: Array = []) -> void:
	s = STILI[versione]
	_lei = lei
	_acque = acque
	_rng.seed = 41
	global_position = Vector3(centro.x, pelo - 0.05, centro.z)
	_crea()
	_t = 0.0
	_spruzza(0.9)
	for p in [_gocce, _goccioloni, _polvere]:
		p.restart()
		p.emitting = true
	var suono := AudioStreamPlayer.new()
	suono.stream = load(SUONO[versione])
	suono.bus = &"Effetti"
	add_child(suono)
	suono.play()


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
	# Lei svanisce dentro l'acqua (si intravede ancora mentre sparisce), poi resta la sua luce.
	# _process viene dopo il _physics_process di LeiSbuca: questa trasparenza vince sulla sua.
	if not _nascosta and _lei:
		var sv: Vector2 = s.svanisce
		_lei.call(&"_svanisci", smoothstep(sv.x, sv.y, _t))
		if _t >= sv.y:
			_nascosta = true
			if _lei.has_method(&"_fuga"):
				_lei.call(&"_fuga")
	if not _crollata and _t >= s.crolla:
		_crollata = true
		_pioggia.restart()
		_pioggia.emitting = true
		_spruzza(0.6)
	if not _schizzata and _t >= s.crolla + 0.25:
		_schizzata = true
		_schizzi.restart()
		_schizzi.emitting = true
	# La pioggia che ricade fa tante onde piccole sull'acqua della fossa.
	if _crollata and _t < s.crolla + s.crollo_durata + 0.3:
		_prossimo_tonfo -= delta
		if _prossimo_tonfo <= 0.0:
			_prossimo_tonfo = 0.12
			var a := _rng.randf() * TAU
			var r: float = sqrt(_rng.randf()) * s.raggio * 1.3
			_tonfo(global_position + Vector3(cos(a) * r, 0.0, sin(a) * r), _rng.randf_range(0.06, 0.16))
	if _t > 6.0:
		queue_free()


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
	_muro.mesh = st.commit()
	_muro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muro.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 7, 8))
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter(&"forma", s.forma)
	_mat.set_shader_parameter(&"raggio", s.raggio)
	_mat.set_shader_parameter(&"altezza", 0.0)
	_muro.material_override = _mat
	add_child(_muro)
	var chiara := _goccia(0.5, 0.7)
	var fine := _goccia(0.25, 0.5)
	# La fontana: dal bordo del muro verso l'alto (A dritta, B aperta a ventaglio).
	_gocce = WaterParticles.make_droplets(s.gocce, 1.5, Vector2(0.02, 0.11))
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
	_one_shot(_gocce, 0.8, chiara)
	# Goccioloni: pesanti, ricadono prima e più vicino.
	_goccioloni = WaterParticles.make_droplets(int(s.gocce * 0.2), 1.8, Vector2(0.04, 0.17))
	var bm: ParticleProcessMaterial = _goccioloni.process_material
	bm.direction = Vector3.UP
	bm.spread = s.spread + 15.0
	bm.initial_velocity_min = s.spinta.x * 0.5
	bm.initial_velocity_max = s.spinta.y * 0.75
	bm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	bm.emission_sphere_radius = s.raggio
	bm.gravity = Vector3(0, -12.0, 0)
	_one_shot(_goccioloni, 0.7, chiara)
	# Polvere d'acqua: goccioline finissime e leggere, che spariscono in fretta (al posto della nebbia).
	_polvere = WaterParticles.make_droplets(int(s.gocce * 0.6), 0.6, Vector2(0.007, 0.03))
	var dm: ParticleProcessMaterial = _polvere.process_material
	dm.direction = Vector3.UP
	dm.spread = 70.0
	dm.initial_velocity_min = 2.0
	dm.initial_velocity_max = 6.0
	dm.damping_min = 3.0
	dm.damping_max = 6.0
	dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	dm.emission_sphere_radius = s.raggio
	_one_shot(_polvere, 0.6, fine)
	_polvere.position = Vector3(0.0, 0.6, 0.0)
	# La pioggia quando crolla: dalla cima del muro, in giù e un po' verso fuori.
	_pioggia = WaterParticles.make_droplets(s.gocce, 1.3, Vector2(0.015, 0.15))
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
	# Schizzi sul pavimento intorno alla fossa, dove arriva l'acqua che ricade.
	_schizzi = WaterParticles.make_droplets(900, 0.5, Vector2(0.012, 0.05))
	var zm: ParticleProcessMaterial = _schizzi.process_material
	zm.direction = Vector3.UP
	zm.spread = 50.0
	zm.initial_velocity_min = 1.2
	zm.initial_velocity_max = 3.2
	zm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	zm.emission_ring_axis = Vector3.UP
	zm.emission_ring_radius = s.schizzi_r.y
	zm.emission_ring_inner_radius = s.schizzi_r.x
	zm.emission_ring_height = 0.02
	_one_shot(_schizzi, 0.15, chiara)
	_schizzi.position = Vector3(0.0, _sopra_pavimento(), 0.0)


func _goccia(opacita: float, rim: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GOCCIA
	m.set_shader_parameter(&"tint", Color(0.72, 0.82, 0.9))
	m.set_shader_parameter(&"opacity", opacita)
	m.set_shader_parameter(&"rim_light", rim)
	return m


## Quota locale del pavimento fuori dalla fossa (un raggio verso il basso a lato).
func _sopra_pavimento() -> float:
	var da := global_position + Vector3(s.schizzi_r.y, 1.5, 0.0)
	var r := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 4.0))
	return (r.position.y - global_position.y + 0.02) if not r.is_empty() else 0.0


func _one_shot(p: GPUParticles3D, esplosivo: float, mat: Material) -> void:
	p.one_shot = true
	p.explosiveness = esplosivo
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-8, -3, -8), Vector3(16, 10, 16))
	if mat:
		(p.draw_pass_1 as QuadMesh).material = mat
	add_child(p)


## Onda sull'acqua della fossa. Come WaterBody.splash, ma con pochissima schiuma: la schiuma dello
## splash faceva chiazze bianche tonde sul pelo, che sembravano batuffoli.
func _tonfo(pos: Vector3, forza: float) -> void:
	for a in _acque:
		if a and a.has_method(&"add_impulse"):
			var p := Vector3(pos.x, float(a.get(&"level")), pos.z)
			a.call(&"add_impulse", p, 0.12 + 0.18 * forza, -0.03 * forza, 0.06 * minf(forza, 1.0))
			a.call(&"add_impulse", p, 0.35 + 0.3 * forza, 0.012 * forza, 0.0)
			return


## Onde sull'acqua delle vasche: un anello di schizzi intorno al muro.
func _spruzza(forza: float) -> void:
	_tonfo(global_position, forza)
	for i in 6:
		var ang := TAU * i / 6.0
		_tonfo(global_position + Vector3(cos(ang), 0.0, sin(ang)) * s.raggio, forza * 0.5)
