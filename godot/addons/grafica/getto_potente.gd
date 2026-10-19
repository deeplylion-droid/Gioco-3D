class_name GettoPotente
extends Node3D
## Getto e aspirazione dello zaino-pompa molto più potenti,
## "come una manichetta dei pompieri potenziata". Si aggancia a un WaterPack già pronto e
## cambia solo la grafica e le sensazioni (rinculo, vibrazione, scossa della camera): la logica
## del gioco (litri, bersagli, pozze) resta quella di WaterPack.
## Due stili, tutti e due molto più forti di oggi:
##  - A "manichetta": nucleo d'acqua pieno e lucido che lontano si apre in spruzzo, ventaglio
##    d'impatto di un metro, rivoli, bagnato che si allarga, rinculo all'avvio e scossa leggera;
##  - B "potenziata": un attimo di carica (la pressione sale), poi un colpo: getto enorme, ventaglio
##    d'impatto di 1,5 m con lame e goccioloni che tornano verso la camera, nebbia che resta,
##    strattoni del tubo e scossa più forte.
## Aspirazione (tutti e due): una colonna d'acqua spessa che si torce dalla superficie all'ugello,
## un gorgo a imbuto profondo, gocce strappate dai bordi che ci volano dentro.
## Nel gioco: un nodo GettoPotente figlio del WaterPack del giocatore (scenes/player/player.tscn).
## Scelto dall'utente il 16 ottobre: stile B ("potenziata"), con i suoni B.

const NUCLEO := preload("res://addons/grafica/getto_nucleo.gdshader")
const COLONNA := preload("res://addons/grafica/colonna_aspirata.gdshader")
const GOCCIA_CHIARA := preload("res://addons/grafica/goccia_chiara.gdshader")

const STILI := {
	"A": {
		"velocita": 21.0, "volo": 1.0,
		"raggio": 0.04, "allarga": 0.6, "sfalda": 0.55, "bianco": 0.0,
		"spruzzo": 300, "nebbia": 30, "nebbia_dim": 0.5,
		"ventaglio": 1.0, "schizzi": 420, "lame": 40, "goccioloni": 80, "rivoli": 60, "impatto_vel": 7.0,
		"nebbia_resta": 40, "bagnato": 1.3,
		"rinculo": 0.05, "rinculo_avvio": 1.0, "vibra": 0.007, "scossa": 0.004, "strattoni": 0.012,
		"carica": 0.0,
		"colonna_base": 0.12, "colonna_cima": 0.04, "vortice": 260, "vortice_r": 0.55, "imbuto": 0.3,
	},
	"B": {
		"velocita": 27.0, "volo": 1.05,
		"raggio": 0.05, "allarga": 0.95, "sfalda": 0.5, "bianco": 0.04,
		"spruzzo": 700, "nebbia": 50, "nebbia_dim": 0.75,
		"ventaglio": 1.5, "schizzi": 800, "lame": 90, "goccioloni": 160, "rivoli": 120, "impatto_vel": 10.0,
		"nebbia_resta": 80, "bagnato": 1.8,
		"rinculo": 0.08, "rinculo_avvio": 1.6, "vibra": 0.012, "scossa": 0.009, "strattoni": 0.028,
		"carica": 0.35,
		"colonna_base": 0.17, "colonna_cima": 0.05, "vortice": 420, "vortice_r": 0.65, "imbuto": 0.5,
	},
}

@export var stile := "B"

var pack: Node
var s: Dictionary
var _cam: Camera3D
var _fx: Node
var _spruzzi: Array[GPUParticles3D] = []
var _nebbie: Array[GPUParticles3D] = []
var _bocca: GPUParticles3D
var _schizzi: GPUParticles3D
var _lame: GPUParticles3D
var _goccioloni: GPUParticles3D
var _rivoli: GPUParticles3D
var _nebbia_impatto: GPUParticles3D
var _bagnato: Array[Decal] = []
var _bagnato_t := 0.0
var _colonna: MeshInstance3D
var _colonna_mesh := ArrayMesh.new()
var _colonna_mat: ShaderMaterial
var _colore_getto: Variant
var _colore_colonna: Variant
## Schizzi, gocce e nebbia che prendono la tinta del serbatoio: [materiale, colore chiaro].
var _tinte: Array = []
var _vortice: MultiMeshInstance3D
var _vortice_k := 0.0
var _t := 0.0
var _strattone := 0.0
var _strattone_dir := Vector3.ZERO
var _prossimo_strattone := 0.0
var _scossa_k := 0.0
var _avvio := 0.0          # rinculo all'avvio del getto (1 -> 0)
var _spruzzava := false
var _carica := 0.0         # tempo di carica rimasto (stile B)
var _carica_tot := 0.0
var _tex_bagnato: Texture2D
var _tex_bagnato_orm: Texture2D


var _audio: Node
var _risucchio: Node        # AudioLoop
var _serbatoio: Node        # AudioLoop
var _corpi_fatti := {}


func _ready() -> void:
	# Il WaterPack si prepara nel _ready del giocatore (dopo i figli): ci si aggancia dopo.
	var p := get_parent()
	if p and &"stream" in p:
		_aggancia_dopo.call_deferred(p)


func _aggancia_dopo(p: Node) -> void:
	if p.get(&"stream") == null:
		await get_tree().process_frame
	if p.get(&"stream"):
		aggancia(p)


func aggancia(p_pack: Node) -> void:
	pack = p_pack
	s = STILI[stile]
	process_priority = 500   # dopo WaterPack e WaterPackFX: aggiunge rinculo e gorgo
	top_level = true
	global_transform = Transform3D.IDENTITY
	var player = pack.get(&"player")
	_cam = player.camera if player else get_viewport().get_camera_3d()
	pack.set(&"jet_speed", s.velocita)
	pack.set(&"jet_max_time", s.volo)
	pack.set(&"spray_kick", s.rinculo)
	pack.set(&"spray_shake", s.vibra)
	pack.set(&"suck_shake", s.vibra * 0.8)
	pack.call(&"_apply_jet_parameters")
	# Il nucleo: acqua lucida e rifratta, bianca solo dove si sfalda.
	var stream = pack.get(&"stream")
	stream.max_age = s.volo
	stream.radius_start = s.raggio
	stream.radius_growth = s.allarga
	stream.breakup_start = s.sfalda
	var m := ShaderMaterial.new()
	m.shader = NUCLEO
	m.set_shader_parameter(&"bianco_base", s.bianco)
	stream.material_override = m
	# L'aspirazione di oggi (un nastro piatto) lascia il posto alla colonna 3D.
	(pack.get(&"suction_stream") as Node3D).visible = false
	var jet: GPUParticles3D = pack.get(&"jet_particles")
	if jet:
		jet.amount = 500 if stile == "B" else 360
		var jm := jet.process_material as ShaderMaterial
		if jm:
			jm.set_shader_parameter(&"base_size", 0.012)
			jm.set_shader_parameter(&"size_growth", 0.035)
			jm.set_shader_parameter(&"spread_degrees", 3.5 if stile == "B" else 2.6)
			jm.set_shader_parameter(&"color", Color(0.9, 0.96, 1.0, 0.7))
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n is WaterPackFX:
			_fx = n
			# Le gocce e la nebbiolina tonde dell'aspirazione di oggi: le fa la colonna.
			(n.get(&"_suck_drops") as Node3D).visible = false
			(n.get(&"_suck_mist") as Node3D).visible = false
			n.set(&"suction_radius", s.vortice_r)
	pack.set(&"spray_delay", s.carica)
	# Il getto e la colonna hanno il colore dell'acqua del serbatoio (enigma degli acquari).
	if pack.has_signal(&"water_mix_changed"):
		pack.connect(&"water_mix_changed", _colora)
	if pack.has_signal(&"spray_charge_started"):
		pack.connect(&"spray_charge_started", func(): carica(s.carica))
	pack.connect(&"spray_stopped", func(): _suona(&"zaino_gocce"))
	_audio = get_node_or_null(^"/root/Audio")
	if _audio:
		_risucchio = _audio.call(&"crea_loop_2d", &"zaino_risucchio_loop", self, -2.0)
		_serbatoio = _audio.call(&"crea_loop_2d", &"zaino_serbatoio_loop", self, -5.0)
	_crea_particelle()
	# Gli schizzi d'impatto e lo spruzzo con la goccia chiara: quella rifratta contro i muri non si vede.
	var chiara := ShaderMaterial.new()
	chiara.shader = GOCCIA_CHIARA
	chiara.set_shader_parameter(&"tint", Color(0.88, 0.94, 1.0))
	chiara.set_shader_parameter(&"opacity", 0.9)
	chiara.set_shader_parameter(&"rim_light", 0.8)
	for p in _spruzzi + [_schizzi, _lame, _goccioloni, _rivoli, _bocca]:
		(p.draw_pass_1 as QuadMesh).material = chiara
	_tinte.append([chiara, Color(0.88, 0.94, 1.0)])
	# La nebbia ha il suo materiale (quello dell'addon è in comune con le altre nebbie).
	var nebbia := WaterParticles.mist_material().duplicate() as ShaderMaterial
	for nb in _nebbie + [_nebbia_impatto]:
		((nb as GPUParticles3D).draw_pass_1 as QuadMesh).material = nebbia
	var tn = nebbia.get_shader_parameter(&"tint")
	_tinte.append([nebbia, tn if tn is Color else Color(0.8, 0.85, 0.88)])
	_crea_colonna()
	_colore_getto = m.get_shader_parameter(&"colore")
	_colore_colonna = _colonna_mat.get_shader_parameter(&"colore")
	if &"water_mix" in pack:
		_colora(pack.get(&"water_mix"))
	_crea_texture_bagnato()
	# Shader e particelle compilati subito, a schermo ancora nero, invece che al primo uso.
	var prepara := PreparaEffetti.new()
	prepara.pack = pack
	prepara.getto = self
	add_child(prepara)


## Stile B: un attimo di carica prima del colpo (la pressione sale nella lancia).
func carica(durata: float) -> void:
	_carica = durata
	_carica_tot = durata
	_suona(&"zaino_carica")


func _crea_particelle() -> void:
	# Spruzzo lungo il getto, dove il nucleo si apre.
	for i in 3:
		var p := WaterParticles.make_droplets(int(s.spruzzo / 3), 0.55, Vector2(0.02, 0.07) * (1.3 if stile == "B" else 1.0))
		var pm: ParticleProcessMaterial = p.process_material
		pm.spread = 6.0 + i * 5.0
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = s.raggio * (1.5 + i * 2.0)
		_aggiungi(p)
		_spruzzi.append(p)
		var nb := WaterParticles.make_mist(int(s.nebbia / 3), 1.2, s.nebbia_dim)
		var nm: ParticleProcessMaterial = nb.process_material
		nm.spread = 25.0
		nm.initial_velocity_min = 0.2
		nm.initial_velocity_max = 0.6
		_aggiungi(nb)
		_nebbie.append(nb)
	# Impatto: ventaglio di schizzi, lame d'acqua, goccioloni che tornano indietro, rivoli che colano.
	_schizzi = WaterParticles.make_droplets(s.schizzi, 0.75, Vector2(0.025, 0.09) * (1.3 if stile == "B" else 1.0))
	var sm: ParticleProcessMaterial = _schizzi.process_material
	sm.spread = 75.0
	sm.initial_velocity_min = s.impatto_vel * 0.35
	sm.initial_velocity_max = s.impatto_vel
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = s.ventaglio * 0.12
	_aggiungi(_schizzi)
	_lame = WaterParticles.make_droplets(s.lame, 0.35, Vector2(0.035, 0.32) * (1.25 if stile == "B" else 1.0))
	var lm: ParticleProcessMaterial = _lame.process_material
	lm.spread = 60.0
	lm.initial_velocity_min = s.impatto_vel * 0.6
	lm.initial_velocity_max = s.impatto_vel * 1.1
	lm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	lm.emission_sphere_radius = s.ventaglio * 0.1
	_aggiungi(_lame)
	# Goccioloni: allungati e pesanti, cadono prima di arrivare alla camera (niente dischi tondi).
	_goccioloni = WaterParticles.make_droplets(s.goccioloni, 1.1, Vector2(0.03, 0.13) * (1.2 if stile == "B" else 1.0))
	var gm: ParticleProcessMaterial = _goccioloni.process_material
	gm.spread = 45.0
	gm.initial_velocity_min = 1.5
	gm.initial_velocity_max = s.impatto_vel * 0.4
	gm.gravity = Vector3(0, -14.0, 0)
	gm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	gm.emission_sphere_radius = s.ventaglio * 0.2
	_aggiungi(_goccioloni)
	_rivoli = WaterParticles.make_droplets(s.rivoli, 1.8, Vector2(0.02, 0.16))
	var rm: ParticleProcessMaterial = _rivoli.process_material
	rm.direction = Vector3.DOWN
	rm.spread = 4.0
	rm.initial_velocity_min = 0.2
	rm.initial_velocity_max = 0.6
	rm.gravity = Vector3(0, -2.5, 0)   # scivolano sul muro, più lente della caduta libera
	rm.damping_min = 1.0
	rm.damping_max = 2.0
	rm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_aggiungi(_rivoli)
	# Nebbia d'impatto: lunga, resta nell'aria dopo lo stop.
	_nebbia_impatto = WaterParticles.make_mist(s.nebbia_resta, 3.5, s.nebbia_dim * 1.8)
	var im: ParticleProcessMaterial = _nebbia_impatto.process_material
	im.spread = 85.0
	im.initial_velocity_min = 0.3
	im.initial_velocity_max = 1.4
	im.damping_min = 0.8
	im.damping_max = 1.6
	_aggiungi(_nebbia_impatto)
	# All'ugello: nebbiolina e gocce (nella carica e quando parte il colpo).
	_bocca = WaterParticles.make_droplets(60 if stile == "B" else 30, 0.3, Vector2(0.015, 0.05))
	var bm: ParticleProcessMaterial = _bocca.process_material
	bm.spread = 35.0
	bm.initial_velocity_min = 1.0
	bm.initial_velocity_max = 3.5
	bm.gravity = Vector3(0, -6.0, 0)
	_aggiungi(_bocca)


func _aggiungi(p: GPUParticles3D) -> void:
	p.top_level = true
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	add_child(p)


func _crea_colonna() -> void:
	_colonna = MeshInstance3D.new()
	_colonna.mesh = _colonna_mesh
	_colonna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_colonna_mat = ShaderMaterial.new()
	_colonna_mat.shader = COLONNA
	_colonna.material_override = _colonna_mat
	_colonna.visible = false
	add_child(_colonna)
	# Gocce strappate dai bordi del gorgo che volano dentro la colonna (posizioni calcolate qui).
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = int(s.vortice)
	var q := QuadMesh.new()
	q.size = Vector2(0.016, 0.14) * (1.25 if stile == "B" else 1.0)
	var gocce := WaterParticles.droplet_material().duplicate() as ShaderMaterial
	gocce.set_shader_parameter(&"opacity", 0.9)
	gocce.set_shader_parameter(&"rim_light", 0.7)
	gocce.set_shader_parameter(&"tint", Color(0.85, 0.93, 1.0))
	_tinte.append([gocce, Color(0.85, 0.93, 1.0)])
	q.material = gocce
	mm.mesh = q
	_vortice = MultiMeshInstance3D.new()
	_vortice.multimesh = mm
	_vortice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vortice.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vortice.visible = false
	add_child(_vortice)


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
			orm.set_pixel(x, y, Color(1.0, 0.05, 0.0, a))
	_tex_bagnato = ImageTexture.create_from_image(img)
	_tex_bagnato_orm = ImageTexture.create_from_image(orm)


func _process(delta: float) -> void:
	if pack == null:
		return
	_t += delta
	var spruzza := bool(pack.get(&"is_spraying"))
	var aspira := bool(pack.get(&"is_sucking"))
	if spruzza and not _spruzzava:
		_avvio = 1.0
	_spruzzava = spruzza
	_avvio = move_toward(_avvio, 0.0, delta / 0.3)
	_carica = maxf(_carica - delta, 0.0)
	var stream = pack.get(&"stream")
	_aggiorna_getto(stream, spruzza)
	_aggiorna_impatto(spruzza and bool(pack.get(&"has_hit")), delta)
	_aggiorna_aspirazione(aspira, delta)
	_aggiorna_sensazioni(spruzza, aspira, delta)
	if _risucchio:
		_risucchio.set(&"volume", _vortice_k)
	if _serbatoio:
		var pieno := float(pack.get(&"tank_amount")) / maxf(float(pack.get(&"tank_capacity")), 0.001)
		_serbatoio.set(&"volume", (0.4 + 0.6 * pieno) if aspira else 0.0)


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
	var muzzle: Node3D = pack.get(&"muzzle")
	_bocca.emitting = (spruzza and _avvio > 0.5) or _carica > 0.0
	if muzzle:
		_bocca.global_position = muzzle.global_position
		(_bocca.process_material as ParticleProcessMaterial).direction = -muzzle.global_basis.z


func _aggiorna_impatto(colpisce: bool, delta: float) -> void:
	for p in [_schizzi, _lame, _goccioloni, _rivoli, _nebbia_impatto]:
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
	# Il ventaglio rimbalza fra la normale e la direzione riflessa del getto: torna verso chi spara.
	var rif := dentro.bounce(normale).normalized() if dentro != Vector3.ZERO else normale
	var dir := (normale * 0.6 + rif).normalized()
	for p in [_schizzi, _lame, _goccioloni, _nebbia_impatto]:
		(p as GPUParticles3D).global_position = punto + normale * 0.05
		((p as GPUParticles3D).process_material as ParticleProcessMaterial).direction = dir
	# Rivoli: colano sul muro sotto il punto colpito (solo su superfici verticali).
	_rivoli.emitting = absf(normale.y) < 0.6
	_rivoli.global_position = punto + normale * 0.03 + Vector3.DOWN * 0.1
	(_rivoli.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(0.35, 0.15, 0.35) * s.ventaglio
	# Bagnato lucido che si allarga sul muro colpito e sul pavimento sotto.
	_bagnato_t -= delta
	if _bagnato_t <= 0.0:
		_bagnato_t = 0.1
		_macchia(punto, normale)
		var sotto := _pavimento_sotto(punto)
		if not sotto.is_empty():
			_macchia(sotto[0], sotto[1])
	for d in _bagnato:
		var vicino := d.global_position.distance_to(punto) < 0.8
		var sotto_punto := Vector2(d.global_position.x - punto.x, d.global_position.z - punto.z).length() < 1.2
		if vicino or sotto_punto:
			d.size.x = minf(d.size.x + delta * 1.2, s.bagnato)
			d.size.z = d.size.x
			d.modulate.a = minf(d.modulate.a + delta * 2.0, 1.0)


func _pavimento_sotto(punto: Vector3) -> Array:
	var q := PhysicsRayQueryParameters3D.create(punto + Vector3.UP * 0.1, punto + Vector3.DOWN * 4.0, 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return []
	return [r.position, r.normal]


func _macchia(punto: Vector3, normale: Vector3) -> void:
	for d in _bagnato:
		if d.global_position.distance_to(punto) < 0.3:
			return
	var d := Decal.new()
	d.texture_albedo = _tex_bagnato
	d.texture_orm = _tex_bagnato_orm
	d.size = Vector3(0.5, 0.5, 0.5)
	d.modulate = Color(1, 1, 1, 0.25)
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	add_child(d)
	d.global_position = punto
	# Il Decal proietta lungo il suo -Y: lo si gira verso la superficie colpita.
	var y := normale.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	d.global_basis = Basis(x, y, x.cross(y)).orthonormalized()
	d.rotate_object_local(Vector3.UP, randf() * TAU)
	_bagnato.append(d)
	if _bagnato.size() > 80:
		_bagnato.pop_front().queue_free()


func _asciuga(delta: float) -> void:
	for d in _bagnato:
		d.modulate.a = maxf(d.modulate.a - delta * 0.03, 0.0)


func _aggiorna_aspirazione(aspira: bool, delta: float) -> void:
	_vortice_k = move_toward(_vortice_k, 1.0 if aspira else 0.0, delta * (4.0 if aspira else 2.5))
	_colonna.visible = _vortice_k > 0.01
	_vortice.visible = _colonna.visible
	if not _colonna.visible:
		return
	var muzzle: Node3D = pack.get(&"muzzle")
	var base: Vector3 = pack.get(&"suck_point")
	var cima: Vector3 = muzzle.global_position if muzzle else base + Vector3.UP
	# Gorgo a imbuto profondo sulla superficie (l'acqua dell'addon): sostituisce quello di WaterPackFX.
	if _fx:
		var corpo = _fx.get(&"_suck_body")
		if corpo and is_instance_valid(corpo) and aspira:
			_meno_schiuma(corpo)
			corpo.set_flow(1, base, s.vortice_r, _vortice_k, 1.6, s.imbuto, 1.6, 0.0)
	_costruisci_colonna(base, cima)
	_colonna_mat.set_shader_parameter(&"forza", _vortice_k)
	var mm := _vortice.multimesh
	var n := mm.instance_count
	var cam_pos := _cam.global_position if _cam else Vector3.ZERO
	for i in n:
		# Ogni goccia parte dal bordo del gorgo e gira verso la colonna, poi sale fino all'ugello.
		var fase := fmod(float(i) * 0.61803 + _t * (0.7 + 0.5 * fmod(i * 0.37, 1.0)), 1.0)
		var u := fase * fase
		var r: float = lerpf(float(s.vortice_r) * (0.75 + 0.25 * fmod(i * 0.71, 1.0)), float(s.colonna_base) * 0.8, minf(u * 3.0, 1.0))
		r = lerpf(r, 0.02, smoothstep(0.35, 1.0, u))
		var ang := float(i) * 2.399 + _t * (5.0 + 12.0 * u) * (1.0 if stile == "A" else 1.3)
		var centro := _curva(base, cima, smoothstep(0.25, 1.0, u)) + Vector3.UP * minf(u * 3.0, 1.0) * 0.04
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * r
		var vel := (cima - p).normalized() if u > 0.3 else (Vector3(-sin(ang), 0.15, cos(ang))).normalized()
		var to_cam := (cam_pos - p).normalized()
		var x := vel.cross(to_cam).normalized()
		var z := x.cross(vel).normalized()
		var scala := _vortice_k * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.85, 1.0, u)) * (0.6 + 0.8 * fmod(i * 0.43, 1.0))
		mm.set_instance_transform(i, Transform3D(Basis(x * scala, vel * scala, z * scala), p))


## Niente schiuma "a pelliccia" sull'acqua aspirata: lo stile di quell'acqua con meno schiuma.
func _meno_schiuma(corpo: Node) -> void:
	if _corpi_fatti.has(corpo) or not (&"style" in corpo) or corpo.get(&"style") == null:
		return
	_corpi_fatti[corpo] = true
	var st: Resource = (corpo.get(&"style") as Resource).duplicate()
	st.set(&"foam_ripple_amount", 0.15)
	corpo.set(&"style", st)


func _suona(nome: StringName) -> void:
	if _audio:
		_audio.call(&"suona", nome)


## La colonna si piega: sale dritta dalla superficie e poi curva verso l'ugello.
func _curva(base: Vector3, cima: Vector3, t: float) -> Vector3:
	var c1 := base + Vector3.UP * base.distance_to(cima) * 0.45
	return base.lerp(c1, t).lerp(c1.lerp(cima, t), t)


func _costruisci_colonna(base: Vector3, cima: Vector3) -> void:
	_colonna_mesh.clear_surfaces()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anelli := 28
	var lati := 18
	var prec: Array = []
	for i in anelli + 1:
		var t := float(i) / anelli
		var p := _curva(base, cima, t)
		var d := (_curva(base, cima, minf(t + 0.02, 1.0)) - _curva(base, cima, maxf(t - 0.02, 0.0))).normalized()
		var x := d.cross(Vector3.FORWARD if absf(d.z) < 0.9 else Vector3.RIGHT).normalized()
		var y := d.cross(x).normalized()
		# Larga alla base (si strappa dalla superficie), poi stretta come l'ugello; si torce e pulsa.
		var r: float = lerpf(float(s.colonna_base), float(s.colonna_cima), smoothstep(0.0, 0.7, t))
		r *= 1.0 + 0.12 * sin(t * 18.0 - _t * 14.0) * (1.0 - t)
		r *= _vortice_k
		var anello := []
		for k in lati + 1:
			var ang := TAU * k / lati + t * 4.0
			var off := (x * cos(ang) + y * sin(ang))
			anello.append([p + off * r, off, Vector2(float(k) / lati, t)])
		if i > 0:
			for k in lati:
				for v in [prec[k], anello[k], anello[k + 1], prec[k], anello[k + 1], prec[k + 1]]:
					st.set_normal(v[1])
					st.set_uv(v[2])
					st.add_vertex(v[0])
		prec = anello
	st.commit(_colonna_mesh)


func _aggiorna_sensazioni(spruzza: bool, aspira: bool, delta: float) -> void:
	var vm: Node3D = pack.get(&"view_model")
	var caricando := _carica > 0.0
	_scossa_k = move_toward(_scossa_k, 1.0 if spruzza else (0.5 if aspira or caricando else 0.0), delta * 6.0)
	if _cam:
		var a: float = s.scossa * (_scossa_k + _avvio * 2.0)
		if caricando:
			a = s.scossa * 1.5 * (1.0 - _carica / maxf(_carica_tot, 0.01))
		_cam.h_offset = (sin(_t * 61.0) * 0.6 + sin(_t * 37.0 + 1.0) * 0.4) * a
		_cam.v_offset = (sin(_t * 53.0 + 2.0) * 0.6 + sin(_t * 29.0) * 0.4) * a + _avvio * _avvio * s.scossa * 3.0
	if vm == null:
		return
	# Rinculo all'avvio: la lancia scatta indietro e in su, poi torna.
	var k := _avvio * _avvio * float(s.rinculo_avvio)
	vm.position += Vector3(0.0, 0.03, 0.09) * k
	vm.rotate_object_local(Vector3.RIGHT, 0.14 * k)
	# Carica (B): la lancia trema sempre di più mentre sale la pressione.
	if caricando:
		var c := 1.0 - _carica / maxf(_carica_tot, 0.01)
		vm.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * 0.006 * c
	if s.strattoni <= 0.0:
		return
	if spruzza:
		_prossimo_strattone -= delta
		if _prossimo_strattone <= 0.0:
			_prossimo_strattone = randf_range(0.35, 0.8)
			_strattone = 1.0
			_suona(&"zaino_strattone")
			_strattone_dir = Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.4), randf_range(0.2, 1.0)).normalized()
	_strattone = move_toward(_strattone, 0.0, delta * 5.0)
	vm.position += _strattone_dir * s.strattoni * _strattone * _strattone


## Getto, colonna dell'aspirazione, schizzi, gocce e nebbia del colore dell'acqua nel serbatoio
## (WaterMix).
func _colora(m: Dictionary) -> void:
	for t in _tinte:
		(t[0] as ShaderMaterial).set_shader_parameter(&"tint", WaterMix.colore(m, t[1]))
	var stream = pack.get(&"stream")
	var mat := stream.material_override as ShaderMaterial if stream else null
	if mat:
		var base: Color = _colore_getto if _colore_getto is Color else Color(0.72, 0.86, 0.95)
		mat.set_shader_parameter(&"colore", WaterMix.colore(m, base))
	if _colonna_mat:
		var base: Color = _colore_colonna if _colore_colonna is Color else Color(0.7, 0.85, 0.92)
		_colonna_mat.set_shader_parameter(&"colore", WaterMix.colore(m, base))
