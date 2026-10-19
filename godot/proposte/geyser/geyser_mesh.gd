class_name GeyserMesh
extends GeyserFossa
## Proposta V1 del geyser della fossa (tappa 8), dopo la v0.3.5 ("l'effetto geyser che avvolge la medusa fa
## schifo, è low quality"). Stessa idea scelta dall'utente il 17 ottobre: una colonna d'acqua spara dritta
## intorno a lei, lei ci sparisce dentro, la colonna ricade come pioggia pesante. Acqua bianca di schiuma e
## piena: non si vede attraverso.
## - La massa d'acqua è una simulazione di liquido vera (Mantaflow, assets_src/geyser/simula.py): una mesh per
##   fotogramma (30 al secondo), senza goccioline staccate (le fanno le particelle).
## - Sopra: gocce lucide e allungate nella direzione del moto, di misure diverse, la nebbiolina
##   d'acqua finissima, la pioggia che ricade e gli schizzi a terra, l'anello di schiuma e le onde sull'acqua
##   della fossa.
## Estende GeyserFossa (così LeiSbuca la usa al posto sua): stessa interfaccia, stesse onde sull'acqua
## (_tonfo, _spruzza); copre si calcola dalle mesh.

const SEQUENZA := "res://proposte/geyser/geyser_sequenza.glb"   # caricata in _ready (la V2 che estende questa non la usa)
const SHADER_SCHIUMA := preload("res://proposte/geyser/acqua_schiuma.gdshader")
const RUMORE := preload("res://proposte/geyser/rumore_schiuma.png")
const FPS := 30.0

## La colonna la copre tutta (copre, da qui lei può sparire) la prima volta che supera questa altezza (m).
@export var altezza_copre := 2.6

var _fotogrammi: Array[Mesh] = []
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
	var s := (load(SEQUENZA) as PackedScene).instantiate()
	var figli := s.find_children("f*", "MeshInstance3D", true, false)
	figli.sort_custom(func(x, y): return String(x.name) < String(y.name))
	for mi in figli:
		_fotogrammi.append((mi as MeshInstance3D).mesh)
	s.free()
	for i in _fotogrammi.size():
		if _fotogrammi[i].get_aabb().end.y > altezza_copre:
			copre = i / FPS
			break
	_ma = _materiale()
	_a = _istanza("Acqua", _ma)
	_crea_particelle()
	_crea_anello()
	set_process(false)


func _materiale() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_SCHIUMA
	m.set_shader_parameter(&"rumore", RUMORE)
	return m


func _istanza(nome: String, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 8, 8))
	mi.visible = false
	add_child(mi)
	return mi


## Fa partire il geyser dal punto [param pavimento] (la base, sotto il pelo dell'acqua della fossa).
func scoppia(pavimento: Vector3, acque: Array = [], _punti := PackedVector3Array()) -> void:
	_acque = acque
	_rng.seed = 41
	global_position = pavimento
	_t = 0.0
	_fatti.clear()
	if _a:   # la V2 (GeyserFlipbook) non ha le mesh
		_a.visible = true
	_anello.visible = true
	_aggiorna()
	_spruzza(1.0)
	set_process(true)


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

func _goccia_mesh(raggio: float, lungo: float) -> Mesh:
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
	var sh := Shader.new()
	sh.code = """
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
	_anello_mat.shader = sh
	_anello_mat.set_shader_parameter(&"rumore", RUMORE)
	_anello.material_override = _anello_mat
	_anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anello.position = Vector3(0, 0.87, 0)
	_anello.visible = false
	add_child(_anello)
