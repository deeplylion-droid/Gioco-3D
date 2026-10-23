class_name GeyserMesh
extends GeyserFossa
## Il geyser della fossa (tappa 8): la V1, scelta dall'utente il 19 ottobre (proposta nata dopo la v0.3.5:
## "l'effetto geyser che avvolge la medusa fa schifo, è low quality"). Stessa idea scelta dall'utente il 17 ottobre: una colonna d'acqua spara dritta
## intorno a lei, lei ci sparisce dentro, la colonna ricade come pioggia pesante. Acqua bianca di schiuma e
## piena: non si vede attraverso.
## - La massa d'acqua è una simulazione di liquido vera (Mantaflow, assets_src/geyser/simula.py): una mesh per
##   fotogramma (30 al secondo), senza goccioline staccate (le fanno le particelle).
## - Sopra: gocce lucide e allungate nella direzione del moto, di misure diverse, la nebbiolina
##   d'acqua finissima, la pioggia che ricade e gli schizzi a terra, l'anello di schiuma e le onde sull'acqua
##   della fossa.
## Estende GeyserFossa (così LeiSbuca la usa al posto sua): stessa interfaccia, stesse onde sull'acqua
## (_tonfo, _spruzza); copre è il fotogramma della simulazione in cui la copre meglio (tests/sonda_geyser.gd).

const SEQUENZA := "res://assets/geyser/geyser_sequenza.glb"   # caricata la prima volta in _ready (la V2 che estende questa non la usa)
const SHADER_SCHIUMA := preload("res://addons/grafica/acqua_schiuma.gdshader")
const RUMORE := preload("res://assets/geyser/rumore_schiuma.png")
const FPS := 30.0
## La base come nella simulazione, rispetto al punto del geyser: il pelo dell'acqua della fossa, il pavimento
## intorno e il raggio della fossa (vanno allo shader).
const Z_ACQUA := 0.85
const Z_PAVIMENTO := 0.55
const R_FOSSA := 1.35
## Il livello di render dell'acqua del geyser: le macchie di bagnato del getto (Decal) non ci si proiettano (sul
## cartellone della V2 la macchia di dove lei era stata colpita faceva un punto chiaro in mezzo alla colonna).
const LIVELLO_ACQUA := 1 << 19

## Quanto sono piccoli i getti sulle punte dei tentacoli rispetto alla colonna (la stessa simulazione).
const SCALA_GETTI := 0.4
## Le punte di lei più lontane di così dall'asse (m) hanno un getto loro: la colonna non ci arriva.
const RAGGIO_COLONNA := 0.95

## Il fotogramma da cui lei può sparire (copre): misurato con tests/sonda_geyser.gd su lei affacciata, è quello
## in mezzo ai fotogrammi in cui l'acqua la nasconde meglio da ogni lato (18-21: occhio, dita e punte dei
## tentacoli; sui tentacoli vicini al corpo restano pochi spiragli nella parete), così un fotogramma prima o
## dopo non cambia niente. Prima, al fotogramma 9 (la colonna a 2,6 m), le punte stese oltre il bordo erano
## ancora scoperte, e dal 22 al 25 si vede l'occhio.
@export var fotogramma_copre := 19

## Le mesh della simulazione, una per fotogramma: si leggono una volta sola e le usano tutti i geyser
## (quello di LeiSbuca e quello di PreparaEffetti).
static var _sequenza: Array[Mesh] = []
static var _shader_anello: Shader

var _fotogrammi: Array[Mesh] = []
# I getti piccoli sulle punte dei tentacoli stese oltre il bordo: [MeshInstance3D, ShaderMaterial].
var _getti_v1: Array = []
var _a: MeshInstance3D
var _ma: ShaderMaterial
var _fontana: GPUParticles3D
var _corona: GPUParticles3D
var _nebbia: GPUParticles3D
var _anello: MeshInstance3D
var _anello_mat: ShaderMaterial
var _fatti := {}


func _ready() -> void:
	top_level = true
	gocce = 110
	_fotogrammi = sequenza()
	copre = fotogramma_copre / FPS
	_ma = _materiale()
	_a = _istanza("Acqua", _ma)
	_crea_particelle()
	_crea_anello()
	set_process(false)


static func sequenza() -> Array[Mesh]:
	if _sequenza.is_empty():
		var s := (load(SEQUENZA) as PackedScene).instantiate()
		var figli := s.find_children("f*", "MeshInstance3D", true, false)
		figli.sort_custom(func(x, y): return String(x.name) < String(y.name))
		for mi in figli:
			_sequenza.append((mi as MeshInstance3D).mesh)
		s.free()
	return _sequenza


## Vero se l'acqua che si disegna adesso (la colonna e i getti piccoli) nasconde il punto [param w] (globale) da
## tutte le direzioni da cui lo può vedere chi sta in piedi nella sala (gli occhi a 1,7 m, da 2,5 a 10 m:
## da 3 a 30 gradi sopra l'orizzonte), 12 direzioni intorno. Conta solo l'acqua sopra le soglie dello
## shader. Per i test (lei deve sparire solo quando è coperta tutta) e le sonde: è lento.
func nascosto(w: Vector3) -> bool:
	return scoperto_da(w) == 0


## Da quante delle 48 direzioni di nascosto() il punto [param w] si vede.
func scoperto_da(w: Vector3) -> int:
	var liberi := 0
	var acque: Array = []
	for g in [[_a, _ma]] + _getti_v1:
		var mi := g[0] as MeshInstance3D
		if mi and mi.visible and mi.mesh:
			var facce := mi.mesh.get_faces()
			var t := mi.global_transform
			var mondo := PackedVector3Array()
			mondo.resize(facce.size())
			for i in facce.size():
				mondo[i] = t * facce[i]
			acque.append([mondo, g[1]])
	for k in 12:
		var az := TAU * k / 12.0
		for el in [3.0, 12.0, 21.0, 30.0]:
			var e := deg_to_rad(el)
			var d := Vector3(cos(az) * cos(e), sin(e), sin(az) * cos(e))
			var preso := false
			for acqua in acque:
				var f: PackedVector3Array = acqua[0]
				for i in range(0, f.size(), 3):
					var h = Geometry3D.ray_intersects_triangle(w, d, f[i], f[i + 1], f[i + 2])
					if h == null:
						h = Geometry3D.ray_intersects_triangle(w, d, f[i], f[i + 2], f[i + 1])
					if h != null and _si_disegna(h, acqua[1]):
						preso = true
						break
				if preso:
					break
			if not preso:
				liberi += 1
	return liberi


## Come il discard di acqua_schiuma.gdshader: sotto il pelo della fossa e appena sopra il pavimento
## l'acqua non si disegna.
static func _si_disegna(q: Vector3, m: ShaderMaterial) -> bool:
	var c: Vector3 = m.get_shader_parameter(&"centro")
	var rr := Vector2(q.x - c.x, q.z - c.z).length()
	var soglia: float = float(m.get_shader_parameter(&"z_acqua")) + 0.06 if rr < float(m.get_shader_parameter(&"r_fossa")) \
			else float(m.get_shader_parameter(&"z_pavimento")) + 0.16
	return q.y - c.y >= soglia + float(m.get_shader_parameter(&"affonda"))


## Un getto piccolo (la stessa simulazione, più piccola) per ogni gruppo di punte di lei fuori dalla
## colonna: i tentacoli stesi oltre il bordo della fossa (come facevano i getti di GeyserFossa).
## La base del getto è il pavimento sotto la punta; sotto, l'acqua non si disegna.
func _crea_getti_v1(punti: PackedVector3Array) -> void:
	for g in _getti_v1:
		(g[0] as Node).queue_free()
	_getti_v1.clear()
	var centri: Array[Vector3] = []
	for q in punti:
		if Vector2(q.x - global_position.x, q.z - global_position.z).length() < RAGGIO_COLONNA:
			continue
		var vicino := false
		for c in centri:
			if Vector2(c.x - q.x, c.z - q.z).length() < 0.5:
				vicino = true
				break
		if not vicino:
			centri.append(q)
	for c in centri:
		var m := _materiale()
		m.set_shader_parameter(&"r_fossa", 0.0)
		m.set_shader_parameter(&"z_pavimento", -0.16)
		# dal pavimento intorno alla fossa: il tentacolo pende oltre il bordo fino a terra
		var base := Vector3(c.x, global_position.y + Z_PAVIMENTO, c.z)
		m.set_shader_parameter(&"centro", base)
		var mi := _istanza("Getto", m)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * SCALA_GETTI
		# il pelo dell'acqua ferma della simulazione sotto la base: si vede solo il getto che sale
		mi.global_position = base - Vector3(0.0, (Z_ACQUA + 0.06) * SCALA_GETTI, 0.0)
		mi.visible = true
		_getti_v1.append([mi, m])


func _materiale() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_SCHIUMA
	m.set_shader_parameter(&"rumore", RUMORE)
	# la base come nella simulazione (anche i test ci leggono dove l'acqua non si disegna)
	m.set_shader_parameter(&"z_acqua", Z_ACQUA)
	m.set_shader_parameter(&"z_pavimento", Z_PAVIMENTO)
	m.set_shader_parameter(&"r_fossa", R_FOSSA)
	m.set_shader_parameter(&"affonda", 0.0)
	return m


func _istanza(nome: String, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.material_override = m
	mi.layers = LIVELLO_ACQUA
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 8, 8))
	mi.visible = false
	add_child(mi)
	return mi


## Fa partire il geyser dal punto [param pavimento] (la base, sotto il pelo dell'acqua della fossa).
func scoppia(pavimento: Vector3, acque: Array = [], punti := PackedVector3Array()) -> void:
	_acque = acque
	_rng.seed = 41
	global_position = pavimento
	_t = 0.0
	_fatti.clear()
	if _a:   # la V2 (GeyserFlipbook) non ha le mesh
		_a.visible = true
		_crea_getti_v1(punti)
	_anello.visible = true
	_aggiorna()
	_spruzza(1.0)
	for d in get_tree().root.find_children("*", "Decal", true, false):
		(d as Decal).cull_mask &= ~LIVELLO_ACQUA
	set_process(true)


## Per PreparaEffetti, dopo scoppia(): accende subito anche le particelle che di solito partono dopo
## (corona, pioggia, schizzi), così nei fotogrammi della preparazione si compilano tutte.
func prepara() -> void:
	for p in [_fontana, _corona, _nebbia, _pioggia, _schizzi]:
		(p as GPUParticles3D).restart()
		(p as GPUParticles3D).emitting = true


func in_corso() -> bool:
	return _t >= 0.0


func durata() -> float:
	return _fotogrammi.size() / FPS


func _process(delta: float) -> void:
	_t += delta
	_aggiorna()
	_eventi()
	if _t > durata() + 2.5:
		_t = -1.0
		set_process(false)


func _aggiorna() -> void:
	# un fotogramma alla volta, il più vicino (a 30 al secondo non scatta; la dissolvenza retinata si vedeva a pois)
	var i := int(round(_t * FPS))
	var dentro := i < _fotogrammi.size()
	_a.visible = dentro
	if dentro:
		_a.mesh = _fotogrammi[i]
		_ma.set_shader_parameter(&"tempo", _t)
		_ma.set_shader_parameter(&"centro", global_position)
		_ma.set_shader_parameter(&"affonda", _affonda() * 0.5)
	for g in _getti_v1:
		var mi := g[0] as MeshInstance3D
		var m := g[1] as ShaderMaterial
		mi.visible = dentro
		if dentro:
			mi.mesh = _fotogrammi[i]
			m.set_shader_parameter(&"tempo", _t)
			m.set_shader_parameter(&"affonda", _affonda() * 0.5 * SCALA_GETTI)
	var k := clampf(_t / 2.6, 0.0, 1.0)
	_anello.scale = Vector3.ONE * (1.0 + 0.9 * sqrt(k))
	_anello_mat.set_shader_parameter(&"vita", k)
	_anello.visible = _t < 2.6


## 0..1 nell'ultimo tratto: l'acqua ricaduta affonda nella fossa invece di restare lì e sparire di colpo.
func _affonda() -> float:
	var k := clampf((_t - (durata() - 1.1)) / 0.9, 0.0, 1.0)
	return k * k


func _una_volta(chiave: String, quando: float) -> bool:
	if _t >= quando and not _fatti.has(chiave):
		_fatti[chiave] = true
		return true
	return false


func _eventi() -> void:
	if _una_volta("fontana", 0.0):
		_fontana.restart(); _fontana.emitting = true
	if _una_volta("nebbia", 0.05):
		_nebbia.restart(); _nebbia.emitting = true
	if _una_volta("corona", 0.35):
		_corona.restart(); _corona.emitting = true
	if _una_volta("pioggia", 0.85):
		_pioggia.restart(); _pioggia.emitting = true
		_spruzza(0.7)
	if _una_volta("schizzi", 1.25):
		_schizzi.restart(); _schizzi.emitting = true
	# la pioggia che ricade fa tante onde piccole sull'acqua della fossa
	if _t > 0.9 and _t < 2.6:
		_prossimo_tonfo -= get_process_delta_time()
		if _prossimo_tonfo <= 0.0:
			_prossimo_tonfo = 0.1
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf()) * 1.25
			_tonfo(global_position + Vector3(cos(a) * r, 0.0, sin(a) * r), _rng.randf_range(0.06, 0.16))


# --- particelle -----------------------------------------------------------------------------------------

## Le mesh delle gocce e della nebbiolina sono le stesse per tutti i geyser: con mesh e materiali nuovi a ogni
## istanza, quello di LeiSbuca ricompilava le loro pipeline al primo uso anche dopo PreparaEffetti.
static var _mesh_particelle := {}


func _goccia_mesh(raggio: float, lungo: float) -> Mesh:
	var chiave := "goccia_%s_%s" % [raggio, lungo]
	if _mesh_particelle.has(chiave):
		return _mesh_particelle[chiave]
	var c := CapsuleMesh.new()
	c.radius = raggio
	c.height = lungo
	c.radial_segments = 8
	c.rings = 3
	# gocce d'acqua bagnate: lucide, col riflesso, allungate nella direzione del moto (align_y)
	# quasi nere e lucidissime: si vedono solo col lampo dove le colpisce una luce, non come fiocchi bianchi
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.11, 0.12)
	m.roughness = 0.03
	m.metallic_specular = 1.0
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.02
	m.vertex_color_use_as_albedo = false
	c.material = m
	_mesh_particelle[chiave] = c
	return c


func _particelle(nome: String, quante: int, vita: float, mesh: Mesh, esplosivo: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nome
	p.amount = quante
	p.lifetime = vita
	p.one_shot = true
	p.explosiveness = esplosivo
	p.emitting = false
	p.draw_pass_1 = mesh
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 10, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, -9.8, 0)
	pm.particle_flag_align_y = true   # la goccia allungata segue la velocità
	pm.scale_min = 0.35   # misure molto diverse: qualche goccia grossa, tante piccole
	pm.scale_max = 1.5
	p.process_material = pm
	add_child(p)
	return p


func _crea_particelle() -> void:
	# la fontana: dal piede della colonna, verso l'alto e un po' verso fuori
	_fontana = _particelle("Fontana", gocce, 1.6, _goccia_mesh(0.005, 0.14), 0.85)
	var fm := _fontana.process_material as ParticleProcessMaterial
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	fm.emission_ring_axis = Vector3.UP
	fm.emission_ring_radius = 1.15
	fm.emission_ring_inner_radius = 0.6
	fm.emission_ring_height = 0.1
	fm.direction = Vector3.UP
	fm.spread = 18.0
	fm.initial_velocity_min = 5.0
	fm.initial_velocity_max = 11.0
	_fontana.position = Vector3(0, 0.9, 0)
	# la corona: dalla cima della colonna, gocce grosse che si aprono in fuori
	_corona = _particelle("Corona", int(gocce * 0.4), 1.8, _goccia_mesh(0.007, 0.16), 0.6)
	var cm := _corona.process_material as ParticleProcessMaterial
	cm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	cm.emission_sphere_radius = 0.8
	cm.direction = Vector3.UP
	cm.spread = 70.0
	cm.initial_velocity_min = 1.5
	cm.initial_velocity_max = 4.5
	_corona.position = Vector3(0, 3.8, 0)
	# la pioggia pesante che ricade
	_pioggia = _particelle("Pioggia", gocce, 1.1, _goccia_mesh(0.004, 0.2), 0.35)
	var pm := _pioggia.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.5, 1.2, 1.5)
	pm.direction = Vector3.DOWN
	pm.spread = 25.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, -12.0, 0)
	_pioggia.position = Vector3(0, 3.4, 0)
	# gli schizzi a terra intorno alla vasca, dove arriva la pioggia
	_schizzi = _particelle("Schizzi", 80, 0.5, _goccia_mesh(0.004, 0.07), 0.2)
	var zm := _schizzi.process_material as ParticleProcessMaterial
	zm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	zm.emission_ring_axis = Vector3.UP
	zm.emission_ring_radius = 2.8
	zm.emission_ring_inner_radius = 1.6
	zm.emission_ring_height = 0.02
	zm.direction = Vector3.UP
	zm.spread = 45.0
	zm.initial_velocity_min = 1.0
	zm.initial_velocity_max = 2.6
	_schizzi.position = Vector3(0, 0.57, 0)
	# la nebbiolina: particelle morbide, grandi, chiare, che salgono piano e si allargano
	var q: QuadMesh = _mesh_particelle.get("nebbia", null)
	if q == null:
		q = _quad_nebbia()
		_mesh_particelle["nebbia"] = q
	_nebbia = _particelle("Nebbia", 30, 1.8, q, 0.5)
	_nebbia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var em := _nebbia.process_material as ParticleProcessMaterial
	em.particle_flag_align_y = false
	em.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	em.emission_sphere_radius = 1.4
	em.direction = Vector3.UP
	em.spread = 60.0
	em.initial_velocity_min = 0.3
	em.initial_velocity_max = 1.4
	em.gravity = Vector3(0, -0.2, 0)
	em.damping_min = 0.4
	em.damping_max = 0.8
	em.scale_min = 0.6
	em.scale_max = 1.4
	var cresce := Curve.new()
	cresce.add_point(Vector2(0, 0.5)); cresce.add_point(Vector2(1, 1.3))
	var ct := CurveTexture.new(); ct.curve = cresce
	em.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.15, Color(1, 1, 1, 0.09))
	g.add_point(0.6, Color(1, 1, 1, 0.05))
	var gt := GradientTexture1D.new(); gt.gradient = g
	em.color_ramp = gt
	_nebbia.position = Vector3(0, 1.6, 0)


func _quad_nebbia() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var nm := StandardMaterial3D.new()
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX   # la luce mediata sul quadratino: per pixel vicino alla luce di lei faceva un punto bianco
	nm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	nm.vertex_color_use_as_albedo = true
	nm.albedo_color = Color(0.55, 0.57, 0.6, 1.0)   # presa dalle luci della sala (per pixel)
	nm.albedo_texture = _morbida()
	nm.proximity_fade_enabled = true
	nm.proximity_fade_distance = 0.8
	nm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = nm
	return q


func _morbida() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


# --- l'anello di schiuma sull'acqua della fossa ------------------------------------------------------------

func _crea_anello() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.8, 2.8)
	_anello = MeshInstance3D.new()
	_anello.name = "AnelloSchiuma"
	_anello.mesh = pm
	_anello_mat = ShaderMaterial.new()
	# uno shader solo per tutti i geyser: con uno nuovo per istanza quello di LeiSbuca si ricompilava al primo
	# uso, anche dopo PreparaEffetti
	if _shader_anello == null:
		_shader_anello = Shader.new()
		_shader_anello.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D rumore : filter_linear_mipmap, repeat_enable;
uniform float vita = 0.0;
void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float n = texture(rumore, UV * 3.0 + vec2(vita * 0.3, 0.0)).r * 0.6 + texture(rumore, UV * 9.0 - vec2(0.0, vita * 0.5)).r * 0.4;
	float anello = smoothstep(0.35, 0.6, r) * (1.0 - smoothstep(0.75, 1.0, r));
	float k = anello * (1.0 - vita * 0.85) + (1.0 - smoothstep(0.0, 0.6, r)) * 0.9 * (1.0 - smoothstep(0.0, 0.5, vita));
	// chiazze di schiuma opache, niente velo trasparente: si scarta dove non c'è schiuma
	if (n * k < 0.3) { discard; }
	ALBEDO = vec3(0.5, 0.53, 0.55);
	ROUGHNESS = 0.5;
}
"""
	_anello_mat.shader = _shader_anello
	_anello_mat.set_shader_parameter(&"rumore", RUMORE)
	_anello.material_override = _anello_mat
	_anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anello.position = Vector3(0, 0.87, 0)
	_anello.visible = false
	add_child(_anello)
