extends Node3D
## PROPOSTA (non usata dal gioco): getto e aspirazione dello zaino-pompa molto più potenti,
## "come una manichetta dei pompieri potenziata". Si aggancia a un WaterPack già pronto e
## cambia solo la grafica e le sensazioni (rinculo, vibrazione, scossa della camera): la logica
## del gioco (litri, gittata utile, bersagli, pozze) resta quella di WaterPack.
## Due stili:
##  - A "manichetta": un getto pieno e compatto che lontano si apre in spruzzo, nebbiolina,
##    schiuma e schizzi all'impatto, muri bagnati, rinculo e un po' di scossa;
##  - B "potenziata": tutto più grosso e violento: getto più largo e veloce, onda d'urto
##    all'ugello, ventaglio d'impatto enorme con goccioloni, nebbia che riempie la luce, strattoni
##    del tubo e scossa più forte.
## Uso: var g = load("res://proposte/zaino/getto_potente.gd").new(); g.stile = "B"; add_child(g); g.aggancia(pack)

const STILI := {
	"A": {
		"velocita": 20.0, "volo": 1.0,
		"raggio": 0.045, "allarga": 0.3, "sfalda": 0.55,
		"opacita": [0.62, 0.95], "bianco": 0.65,
		"spruzzo": 260, "nebbia": 40, "nebbia_dim": 0.7,
		"schizzi": 220, "goccioloni": 40, "schiuma": 36, "impatto_vel": 4.5,
		"rinculo": 0.04, "vibra": 0.006, "scossa": 0.0035, "strattoni": 0.0,
		"aspira_base": 0.32, "aspira_cima": 0.035, "vortice": 240, "vortice_r": 0.75,
		"nebbia_vol": 0.35, "bocca": 0,
	},
	"B": {
		"velocita": 26.0, "volo": 1.05,
		"raggio": 0.07, "allarga": 0.45, "sfalda": 0.5,
		"opacita": [0.72, 1.0], "bianco": 0.8,
		"spruzzo": 520, "nebbia": 80, "nebbia_dim": 1.1,
		"schizzi": 480, "goccioloni": 90, "schiuma": 70, "impatto_vel": 6.5,
		"rinculo": 0.07, "vibra": 0.011, "scossa": 0.0075, "strattoni": 0.022,
		"aspira_base": 0.5, "aspira_cima": 0.05, "vortice": 420, "vortice_r": 1.1,
		"nebbia_vol": 0.7, "bocca": 60,
	},
}

@export var stile := "A"

var pack: Node
var s: Dictionary
var _cam: Camera3D
var _fx: WaterPackFX
var _spruzzi: Array[GPUParticles3D] = []
var _nebbie: Array[GPUParticles3D] = []
var _bocca: GPUParticles3D
var _schizzi: GPUParticles3D
var _goccioloni: GPUParticles3D
var _schiuma: GPUParticles3D
var _nebbia_impatto: GPUParticles3D
var _bagnato: Array[Decal] = []
var _bagnato_t := 0.0
var _vortice: MultiMeshInstance3D
var _vortice_k := 0.0
var _vortice_nebbia: GPUParticles3D
var _t := 0.0
var _strattone := 0.0
var _strattone_dir := Vector3.ZERO
var _prossimo_strattone := 0.0
var _scossa_k := 0.0
var _tex_bagnato: Texture2D
var _tex_bagnato_orm: Texture2D


func aggancia(p_pack: Node) -> void:
	pack = p_pack
	s = STILI[stile]
	process_priority = 500   # dopo WaterPack: aggiunge rinculo e strattoni alla lancia
	top_level = true
	global_transform = Transform3D.IDENTITY
	var player = pack.get(&"player")
	_cam = player.camera if player else get_viewport().get_camera_3d()
	# Getto: velocità e volo (la gittata cresce un po'), forma e materiale del nastro.
	pack.set(&"jet_speed", s.velocita)
	pack.set(&"jet_max_time", s.volo)
	pack.set(&"spray_kick", s.rinculo)
	pack.set(&"spray_shake", s.vibra)
	pack.set(&"suck_shake", s.vibra * 0.8)
	pack.call(&"_apply_jet_parameters")
	var stream = pack.get(&"stream")
	stream.max_age = s.volo
	stream.radius_start = s.raggio
	stream.radius_growth = s.allarga
	stream.breakup_start = s.sfalda
	var m: ShaderMaterial = stream.material_override
	m.set_shader_parameter(&"color", Color(0.86, 0.94, 1.0).lerp(Color.WHITE, s.bianco * 0.4))
	m.set_shader_parameter(&"opacity_center", s.opacita[0])
	m.set_shader_parameter(&"opacity_edge", s.opacita[1])
	m.set_shader_parameter(&"streak_density", 0.9)
	m.set_shader_parameter(&"streak_strength", 0.7)
	m.set_shader_parameter(&"emission_strength", 0.12)
	m.set_shader_parameter(&"rim_emission", 0.35)
	var suction = pack.get(&"suction_stream")
	suction.radius_base = s.aspira_base
	suction.radius_top = s.aspira_cima
	suction.flow_speed = 7.0
	(suction.material_override as ShaderMaterial).set_shader_parameter(&"flow_speed", 7.0)
	(suction.material_override as ShaderMaterial).set_shader_parameter(&"opacity_center", 0.45)
	# Le goccioline fini intorno al getto (le particelle della lancia): più grandi e più fitte.
	var jet: GPUParticles3D = pack.get(&"jet_particles")
	if jet:
		jet.amount = 600 if stile == "B" else 420
		var jm := jet.process_material as ShaderMaterial
		if jm:
			jm.set_shader_parameter(&"base_size", s.raggio * 0.6)
			jm.set_shader_parameter(&"size_growth", s.allarga * 0.5)
			jm.set_shader_parameter(&"spread_degrees", 3.5 if stile == "B" else 2.6)
			jm.set_shader_parameter(&"color", Color(0.9, 0.96, 1.0, 0.7))
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n is WaterPackFX:
			_fx = n
			_fx.suction_radius = s.vortice_r * 1.8
	_crea_particelle()
	_crea_vortice()
	_crea_texture_bagnato()


func _crea_particelle() -> void:
	# Spruzzo lungo il getto: tre punti nella seconda metà del volo, dove il nucleo si apre.
	for i in 3:
		var p := WaterParticles.make_droplets(int(s.spruzzo / 3), 0.55, Vector2(0.02, 0.06) * (1.4 if stile == "B" else 1.0))
		var pm: ParticleProcessMaterial = p.process_material
		pm.spread = 7.0 + i * 5.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 0.95
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = s.raggio * (2.0 + i * 2.0)
		_aggiungi(p)
		_spruzzi.append(p)
		var nb := WaterParticles.make_mist(int(s.nebbia / 3), 1.2, s.nebbia_dim)
		var nm: ParticleProcessMaterial = nb.process_material
		nm.spread = 25.0
		nm.initial_velocity_min = 0.2
		nm.initial_velocity_max = 0.5
		_aggiungi(nb)
		_nebbie.append(nb)
	# Impatto: ventaglio di schizzi, goccioloni pesanti, schiuma e una nuvola di nebbia.
	_schizzi = WaterParticles.make_droplets(s.schizzi, 0.8, Vector2(0.025, 0.08) * (1.3 if stile == "B" else 1.0))
	var sm: ParticleProcessMaterial = _schizzi.process_material
	sm.spread = 70.0
	sm.initial_velocity_min = s.impatto_vel * 0.4
	sm.initial_velocity_max = s.impatto_vel
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.12
	_aggiungi(_schizzi)
	_goccioloni = WaterParticles.make_droplets(s.goccioloni, 1.4, Vector2(0.05, 0.09) * (1.3 if stile == "B" else 1.0))
	var gm: ParticleProcessMaterial = _goccioloni.process_material
	gm.spread = 50.0
	gm.initial_velocity_min = 1.0
	gm.initial_velocity_max = 3.0
	gm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	gm.emission_sphere_radius = 0.25
	_aggiungi(_goccioloni)
	_schiuma = WaterParticles.make_mist(s.schiuma, 0.9, 0.35 if stile == "A" else 0.55)
	var fm: ParticleProcessMaterial = _schiuma.process_material
	fm.spread = 80.0
	fm.initial_velocity_min = 0.3
	fm.initial_velocity_max = 1.2
	fm.gravity = Vector3(0, -1.5, 0)
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fm.emission_sphere_radius = 0.18
	_schiuma.amount_ratio = 1.0
	(_schiuma.draw_pass_1 as QuadMesh).material = _materiale_schiuma()
	_aggiungi(_schiuma)
	_nebbia_impatto = WaterParticles.make_mist(int(s.nebbia), 1.8, s.nebbia_dim * 1.6)
	var im: ParticleProcessMaterial = _nebbia_impatto.process_material
	im.spread = 85.0
	im.initial_velocity_min = 0.4
	im.initial_velocity_max = 1.6
	_aggiungi(_nebbia_impatto)
	if s.bocca > 0:
		# B: onda d'urto all'ugello, un anello di gocce che si apre di traverso.
		_bocca = WaterParticles.make_droplets(s.bocca, 0.25, Vector2(0.015, 0.05))
		var bm: ParticleProcessMaterial = _bocca.process_material
		bm.spread = 35.0
		bm.initial_velocity_min = 2.0
		bm.initial_velocity_max = 4.0
		bm.gravity = Vector3(0, -4.0, 0)
		_aggiungi(_bocca)


func _aggiungi(p: GPUParticles3D) -> void:
	p.top_level = true
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	add_child(p)


func _materiale_schiuma() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
varying float a;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
	a = COLOR.a;
}
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	float bolle = n2(UV * 9.0 + INSTANCE_CUSTOM.x * 13.0) * 0.6 + n2(UV * 23.0) * 0.4;
	float forma = smoothstep(1.0, 0.45, r + (bolle - 0.5) * 0.6);
	ALBEDO = vec3(0.92, 0.96, 1.0) * (0.75 + 0.25 * bolle);
	ALPHA = forma * a * 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _crea_vortice() -> void:
	# Gocce che salgono a spirale dalla pozza all'ugello (posizioni calcolate qui, a ogni frame).
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = int(s.vortice)
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.1) * (1.3 if stile == "B" else 1.0)
	var gocce := WaterParticles.droplet_material().duplicate() as ShaderMaterial
	gocce.set_shader_parameter(&"opacity", 0.95)
	gocce.set_shader_parameter(&"rim_light", 0.8)
	gocce.set_shader_parameter(&"tint", Color(0.85, 0.93, 1.0))
	q.material = gocce
	mm.mesh = q
	_vortice = MultiMeshInstance3D.new()
	_vortice.multimesh = mm
	_vortice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vortice.visible = false
	add_child(_vortice)
	_vortice_nebbia = WaterParticles.make_mist(30 if stile == "A" else 60, 1.0, 0.6 * s.nebbia_dim)
	var vm: ParticleProcessMaterial = _vortice_nebbia.process_material
	vm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	vm.emission_ring_axis = Vector3.UP
	vm.emission_ring_radius = s.vortice_r
	vm.emission_ring_inner_radius = s.vortice_r * 0.3
	vm.emission_ring_height = 0.02
	vm.direction = Vector3.UP
	vm.spread = 15.0
	vm.initial_velocity_min = 0.4
	vm.initial_velocity_max = 1.0
	_aggiungi(_vortice_nebbia)


func _crea_texture_bagnato() -> void:
	# Macchia bagnata: scura al centro, bordo irregolare; ORM con rugosità bassissima (lucido).
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var orm := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rumore := FastNoiseLite.new()
	rumore.frequency = 0.05
	for y in 128:
		for x in 128:
			var d := Vector2(x - 63.5, y - 63.5).length() / 63.5
			var bordo := 0.75 + 0.25 * rumore.get_noise_2d(x, y)
			var a := clampf((bordo - d) / 0.25, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.05, 0.06, 0.07, a * 0.55))
			orm.set_pixel(x, y, Color(1.0, 0.06, 0.0, a))
	_tex_bagnato = ImageTexture.create_from_image(img)
	_tex_bagnato_orm = ImageTexture.create_from_image(orm)


func _process(delta: float) -> void:
	if pack == null:
		return
	_t += delta
	var spruzza := bool(pack.get(&"is_spraying"))
	var aspira := bool(pack.get(&"is_sucking"))
	var stream = pack.get(&"stream")
	_aggiorna_getto(stream, spruzza)
	_aggiorna_impatto(spruzza and bool(pack.get(&"has_hit")), delta)
	_aggiorna_vortice(aspira, delta)
	_aggiorna_sensazioni(spruzza, aspira, delta)


## Punto del getto in volo a una certa frazione dell'età massima: [posizione, velocità].
func _punto_getto(stream, frazione: float) -> Array:
	var eta: PackedFloat32Array = stream._age
	var pos: PackedVector3Array = stream._pos
	var vel: PackedVector3Array = stream._vel
	if pos.is_empty():
		return []
	var cerca := frazione * float(stream.max_age)
	var migliore := -1
	var dist := 1e9
	for i in pos.size():
		if stream._state[i] != 0:
			continue
		var dd := absf(eta[i] - cerca)
		if dd < dist:
			dist = dd
			migliore = i
	if migliore < 0 or dist > 0.15:
		return []
	return [pos[migliore], vel[migliore]]


func _aggiorna_getto(stream, spruzza: bool) -> void:
	var frazioni := [0.35, 0.55, 0.78]
	for i in 3:
		var pv := _punto_getto(stream, frazioni[i]) if spruzza else []
		var on := not pv.is_empty()
		_spruzzi[i].emitting = on
		_nebbie[i].emitting = on and i > 0
		if on:
			var v: Vector3 = pv[1]
			_spruzzi[i].global_position = pv[0]
			_nebbie[i].global_position = pv[0]
			var pm: ParticleProcessMaterial = _spruzzi[i].process_material
			pm.direction = v.normalized()
			pm.initial_velocity_min = v.length() * 0.55
			pm.initial_velocity_max = v.length() * 0.95
	if _bocca:
		var muzzle: Node3D = pack.get(&"muzzle")
		_bocca.emitting = spruzza
		if muzzle:
			_bocca.global_position = muzzle.global_position
			(_bocca.process_material as ParticleProcessMaterial).direction = -muzzle.global_basis.z


func _aggiorna_impatto(colpisce: bool, delta: float) -> void:
	for p in [_schizzi, _goccioloni, _schiuma, _nebbia_impatto]:
		(p as GPUParticles3D).emitting = colpisce
	if not colpisce:
		_bagnato_t = 0.0
		_asciuga(delta)
		return
	var punto: Vector3 = pack.get(&"hit_point")
	var normale: Vector3 = (pack.get(&"hit_normal") as Vector3).normalized()
	var stream = pack.get(&"stream")
	var arrivo := _punto_getto(stream, 0.95)
	var dentro := Vector3.ZERO
	if not arrivo.is_empty():
		dentro = (arrivo[1] as Vector3).normalized()
	# Gli schizzi rimbalzano: fra la normale e la direzione riflessa del getto.
	var rif := dentro.bounce(normale).normalized() if dentro != Vector3.ZERO else normale
	var dir := (normale + rif).normalized()
	for p in [_schizzi, _goccioloni, _schiuma, _nebbia_impatto]:
		(p as GPUParticles3D).global_position = punto + normale * 0.05
		((p as GPUParticles3D).process_material as ParticleProcessMaterial).direction = dir
	# Macchie di bagnato lucido che si allargano dove colpisce.
	_bagnato_t -= delta
	if _bagnato_t <= 0.0:
		_bagnato_t = 0.12
		_macchia(punto, normale)
	for d in _bagnato:
		if d.global_position.distance_to(punto) < 0.6:
			d.size.x = minf(d.size.x + delta * 0.8, 1.6 if stile == "B" else 1.1)
			d.size.z = d.size.x
			d.modulate.a = minf(d.modulate.a + delta * 2.0, 1.0)


func _macchia(punto: Vector3, normale: Vector3) -> void:
	for d in _bagnato:
		if d.global_position.distance_to(punto) < 0.25:
			return
	var d := Decal.new()
	d.texture_albedo = _tex_bagnato
	d.texture_orm = _tex_bagnato_orm
	d.size = Vector3(0.4, 0.5, 0.4)
	d.modulate = Color(1, 1, 1, 0.2)
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	add_child(d)
	d.global_position = punto
	# Il Decal proietta lungo il suo -Y: lo si gira verso la superficie colpita.
	var y := normale
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	d.global_basis = Basis(x, y, x.cross(y)).orthonormalized()
	d.rotate_object_local(Vector3.UP, randf() * TAU)
	_bagnato.append(d)
	if _bagnato.size() > 60:
		_bagnato.pop_front().queue_free()


func _asciuga(delta: float) -> void:
	for d in _bagnato:
		d.modulate.a = maxf(d.modulate.a - delta * 0.04, 0.0)


func _aggiorna_vortice(aspira: bool, delta: float) -> void:
	_vortice_k = move_toward(_vortice_k, 1.0 if aspira else 0.0, delta * 3.0)
	_vortice.visible = _vortice_k > 0.01
	_vortice_nebbia.emitting = aspira
	if not _vortice.visible:
		return
	var muzzle: Node3D = pack.get(&"muzzle")
	var base: Vector3 = pack.get(&"suck_point")
	var cima: Vector3 = muzzle.global_position if muzzle else base + Vector3.UP
	_vortice_nebbia.global_position = base + Vector3.UP * 0.03
	var mm := _vortice.multimesh
	var n := mm.instance_count
	var cam_pos := _cam.global_position if _cam else Vector3.ZERO
	for i in n:
		# Ogni goccia ha la sua fase: sale lungo un cono che si stringe verso l'ugello girando.
		var fase := fmod(float(i) * 0.61803 + _t * (0.9 + 0.5 * fmod(i * 0.37, 1.0)), 1.0)
		var u := fase * fase
		var r: float = lerpf(float(s.vortice_r) * (0.6 + 0.4 * fmod(i * 0.71, 1.0)), 0.02, u)
		var ang := float(i) * 2.399 + _t * (4.0 + 10.0 * u) * (1.0 if stile == "A" else 1.4)
		var centro := base.lerp(cima, u) + Vector3.UP * sin(u * PI) * 0.15
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * r
		var vel := (cima - p).normalized()
		var to_cam := (cam_pos - p).normalized()
		var x := vel.cross(to_cam).normalized()
		var z := x.cross(vel).normalized()
		var scala := _vortice_k * (1.0 - smoothstep(0.85, 1.0, u)) * (0.6 + 0.8 * fmod(i * 0.43, 1.0))
		mm.set_instance_transform(i, Transform3D(Basis(x * scala, vel * scala * 1.4, z), p))


func _aggiorna_sensazioni(spruzza: bool, aspira: bool, delta: float) -> void:
	# Scossa della camera (offset dell'obiettivo, non tocca la mira) e strattoni del tubo.
	_scossa_k = move_toward(_scossa_k, 1.0 if spruzza else (0.4 if aspira else 0.0), delta * 6.0)
	if _cam:
		var a: float = s.scossa * _scossa_k
		_cam.h_offset = (sin(_t * 61.0) * 0.6 + sin(_t * 37.0 + 1.0) * 0.4) * a
		_cam.v_offset = (sin(_t * 53.0 + 2.0) * 0.6 + sin(_t * 29.0) * 0.4) * a
	var vm: Node3D = pack.get(&"view_model")
	if vm == null or s.strattoni <= 0.0:
		return
	if spruzza:
		_prossimo_strattone -= delta
		if _prossimo_strattone <= 0.0:
			_prossimo_strattone = randf_range(0.35, 0.8)
			_strattone = 1.0
			_strattone_dir = Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.4), randf_range(0.2, 1.0)).normalized()
	_strattone = move_toward(_strattone, 0.0, delta * 5.0)
	vm.position += _strattone_dir * s.strattoni * _strattone * _strattone
