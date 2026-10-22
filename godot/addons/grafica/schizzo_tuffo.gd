class_name SchizzoTuffo
extends Node3D
## Lo schizzo di lei che si tuffa di testa nella fossa (tappa 8, tuffo A del 22 ottobre): fatto su misura per
## una creatura di 4,5 m, perché lo schizzo generico dell'acqua (WaterSplash) è fatto per il giocatore.
## - una corona d'acqua che sale (fino a circa 1,5 m con forza 1) con altezze diverse lungo il giro e si apre
##   subito in fili verticali (intera resta solo in basso), poi ricade: acqua bianca e trasparente, più chiara
##   di taglio e dove fa schiuma, con la luce rosa di lei solo vicino alla base (ritocco del 22 ottobre:
##   "sembra plastica rosa o gelatina");
## - gocce grosse che partono dall'anello verso l'alto e in fuori (chiare, lucide e un po' trasparenti), e uno
##   spruzzo fine più veloce;
## - il rimbalzo: un getto stretto che sale dal centro poco dopo;
## - la schiuma bianca sull'acqua, a chiazze, che si allarga e sparisce in 3 secondi.
## Shader, mesh e materiali sono gli stessi per tutti gli schizzi (statici): niente compilazioni al primo
## tuffo dopo PreparaEffetti. Uso: schizza(punto sul pelo dell'acqua, forza); forza 0,4-0,5 per i tentacoli.

const RUMORE := preload("res://assets/geyser/rumore_schiuma.png")
const DURATA := 3.0

static var _risorse := {}

var forza := 1.0
var _t := -1.0
var _corona: MeshInstance3D
var _corona_mat: ShaderMaterial
var _schiuma: MeshInstance3D
var _schiuma_mat: ShaderMaterial
var _gocce: GPUParticles3D
var _spruzzo: GPUParticles3D
var _rimbalzo: GPUParticles3D


func _ready() -> void:
	_corona_mat = ShaderMaterial.new()
	_corona_mat.shader = _shader("corona", CORONA)
	_corona_mat.set_shader_parameter(&"rumore", RUMORE)
	_corona = MeshInstance3D.new()
	_corona.name = "Corona"
	_corona.mesh = _cilindro()
	_corona.material_override = _corona_mat
	_corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corona.visible = false
	add_child(_corona)
	_schiuma_mat = ShaderMaterial.new()
	_schiuma_mat.shader = _shader("schiuma", SCHIUMA)
	_schiuma_mat.set_shader_parameter(&"rumore", RUMORE)
	_schiuma = MeshInstance3D.new()
	_schiuma.name = "Schiuma"
	_schiuma.mesh = _piano()
	_schiuma.material_override = _schiuma_mat
	_schiuma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_schiuma.position = Vector3(0.0, 0.015, 0.0)
	_schiuma.visible = false
	add_child(_schiuma)
	_gocce = _particelle("Gocce", 120, 1.2, _goccia(0.02, 0.08), 0.95)
	_spruzzo = _particelle("Spruzzo", 280, 0.9, _goccia(0.008, 0.05), 0.97)
	_rimbalzo = _particelle("Rimbalzo", 70, 1.1, _goccia(0.018, 0.1), 0.6)
	set_process(false)


## Fa partire lo schizzo nel punto [param pelo] (sul pelo dell'acqua).
func schizza(pelo: Vector3, f := 1.0) -> void:
	forza = f
	global_position = pelo
	_t = 0.0
	scale = Vector3.ONE
	var k := forza
	var pm := _gocce.process_material as ParticleProcessMaterial
	pm.emission_ring_radius = 0.55 * sqrt(k)
	pm.emission_ring_inner_radius = 0.35 * sqrt(k)
	pm.initial_velocity_min = 3.0 * sqrt(k)
	pm.initial_velocity_max = 6.0 * sqrt(k)
	pm.radial_velocity_min = 0.6 * k
	pm.radial_velocity_max = 1.6 * k
	var ps := _spruzzo.process_material as ParticleProcessMaterial
	ps.emission_ring_radius = 0.6 * sqrt(k)
	ps.emission_ring_inner_radius = 0.3 * sqrt(k)
	ps.initial_velocity_min = 4.0 * sqrt(k)
	ps.initial_velocity_max = 8.0 * sqrt(k)
	ps.radial_velocity_min = 1.0 * k
	ps.radial_velocity_max = 2.5 * k
	var pr := _rimbalzo.process_material as ParticleProcessMaterial
	pr.initial_velocity_min = 2.5 * sqrt(k)
	pr.initial_velocity_max = 4.5 * sqrt(k)
	for p in [_gocce, _spruzzo]:
		(p as GPUParticles3D).amount_ratio = clampf(k, 0.25, 1.0)
		(p as GPUParticles3D).restart()
		(p as GPUParticles3D).emitting = true
	_rimbalzo.amount_ratio = clampf(k, 0.25, 1.0)
	_rimbalzo.emitting = false
	_corona.visible = true
	_schiuma.visible = true
	_aggiorna()
	set_process(true)


## Per PreparaEffetti: tutto acceso subito, anche il rimbalzo.
func prepara() -> void:
	_rimbalzo.restart()
	_rimbalzo.emitting = true


func in_corso() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.32 and not _rimbalzo.emitting and _t < 0.4:
		_rimbalzo.restart()
		_rimbalzo.emitting = true
	_aggiorna()
	if _t > DURATA:
		_t = -1.0
		_corona.visible = false
		_schiuma.visible = false
		set_process(false)


func _aggiorna() -> void:
	var k := forza
	# la corona: sale in 0,25 s, poi si rompe e ricade entro 1 s
	var sale := 1.0 - pow(1.0 - clampf(_t / 0.25, 0.0, 1.0), 3.0)
	var vita := clampf((_t - 0.08) / 0.75, 0.0, 1.0)
	var alta := 1.5 * sqrt(k) * sale * (1.0 - 0.5 * vita * vita)
	var larga := sqrt(k) * (1.0 + 0.5 * sale + 0.6 * vita)
	_corona.visible = _t < 1.0 and alta > 0.02
	_corona.scale = Vector3(larga, maxf(alta, 0.01), larga)
	_corona.position = Vector3(0.0, maxf(alta, 0.01) * 0.5, 0.0)
	_corona_mat.set_shader_parameter(&"vita", vita)
	# la schiuma: si allarga e sparisce
	var s := clampf(_t / DURATA, 0.0, 1.0)
	_schiuma.scale = Vector3.ONE * sqrt(k) * (0.7 + 1.1 * sqrt(s))
	_schiuma_mat.set_shader_parameter(&"vita", s)


# --- risorse condivise -------------------------------------------------------------------------------------

static func _shader(chiave: String, codice: String) -> Shader:
	if not _risorse.has(chiave):
		var sh := Shader.new()
		sh.code = codice
		_risorse[chiave] = sh
	return _risorse[chiave]


static func _cilindro() -> Mesh:
	if not _risorse.has("cilindro"):
		var c := CylinderMesh.new()
		c.top_radius = 0.75
		c.bottom_radius = 0.55
		c.height = 1.0
		c.radial_segments = 40
		c.rings = 6
		c.cap_top = false
		c.cap_bottom = false
		_risorse["cilindro"] = c
	return _risorse["cilindro"]


static func _piano() -> Mesh:
	if not _risorse.has("piano"):
		var p := PlaneMesh.new()
		p.size = Vector2(3.0, 3.0)
		_risorse["piano"] = p
	return _risorse["piano"]


static func _goccia(raggio: float, lungo: float) -> Mesh:
	var chiave := "goccia_%s_%s" % [raggio, lungo]
	if not _risorse.has(chiave):
		var c := CapsuleMesh.new()
		c.radius = raggio
		c.height = lungo
		c.radial_segments = 8
		c.rings = 3
		var m := StandardMaterial3D.new()
		# acqua: chiara, lucidissima e un po' trasparente, con un filo di luce propria bianca (al buio, grigie
		# e opache, sembravano sassolini). Poca luce propria e non troppe: con di più, alla fine sembravano neve.
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.85, 0.9, 0.95, 0.45)
		m.roughness = 0.04
		m.metallic_specular = 1.0
		m.emission_enabled = true
		m.emission = Color(0.75, 0.8, 0.85)
		m.emission_energy_multiplier = 0.1
		m.rim_enabled = true
		m.rim = 0.6
		c.material = m
		_risorse[chiave] = c
	return _risorse[chiave]


func _particelle(nome: String, quante: int, vita: float, mesh: Mesh, esplosivo: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nome
	p.amount = quante
	p.lifetime = vita
	p.one_shot = true
	p.explosiveness = esplosivo
	p.emitting = false
	p.draw_pass_1 = mesh
	p.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 8, 10))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, -9.8, 0)
	pm.particle_flag_align_y = true
	pm.direction = Vector3.UP
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	if nome == "Rimbalzo":
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.12
		pm.spread = 8.0
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_height = 0.05
		pm.spread = 22.0
	p.process_material = pm
	add_child(p)
	return p


const CORONA := """
shader_type spatial;
// La corona d'acqua del tuffo: acqua bianca e trasparente, più chiara di taglio e dove fa schiuma (non prende
// le luci della sala: la luce rosa di lei la tingerebbe tutta); un filo di rosa solo vicino alla base, la sua
// luce da sotto. Le altezze cambiano lungo il giro e la lamina si apre subito in fili verticali (vita da 0 a
// 1): intera resta solo in basso. Niente coppa liscia.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform sampler2D rumore : filter_linear_mipmap, repeat_enable;
uniform float vita = 0.0;
uniform vec3 base_rosa = vec3(0.55, 0.22, 0.42);
varying float alt;
varying float giro;
void vertex() {
	alt = VERTEX.y + 0.5;
	giro = UV.x;
	// altezze irregolari lungo il giro: fili alti e bassi
	float h = 0.45 + 0.9 * textureLod(rumore, vec2(UV.x * 5.0, 0.37), 0.0).r;
	VERTEX.y = alt * h - 0.5;
	VERTEX.xz *= 1.0 + alt * alt * (0.7 + 0.9 * vita);
}
void fragment() {
	float n = texture(rumore, vec2(giro * 3.0, alt * 0.7 - vita * 0.5)).r;
	float fili = texture(rumore, vec2(giro * 17.0 + 0.37, alt * 0.35 + vita * 0.3)).r;
	// la lamina si rompe in fili subito, sempre di più in alto e col tempo
	float soglia = 0.22 + 0.45 * vita + 0.35 * alt;
	if (fili < soglia) {
		discard;
	}
	float cima = 1.0 - smoothstep(0.75, 1.0, alt + (n - 0.5) * 0.4);
	if (cima < 0.5) {
		discard;
	}
	float schiuma = smoothstep(0.45, 0.8, n);
	float taglio = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	ALBEDO = vec3(0.62, 0.66, 0.7) * (0.55 + 0.45 * schiuma + 0.4 * taglio) + base_rosa * pow(1.0 - alt, 4.0) * 0.35;
	ALPHA = clamp(0.28 + 0.45 * schiuma + 0.35 * taglio, 0.0, 0.92) * (1.0 - 0.6 * vita);
}
"""

const SCHIUMA := """
shader_type spatial;
// La schiuma bianca sull'acqua dopo il tuffo: chiazze che si allargano e si diradano (vita da 0 a 1). Non prende
// le luci (la luce rosa di lei la tingerebbe): bianco smorzato, come la corona.
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D rumore : filter_linear_mipmap, repeat_enable;
uniform float vita = 0.0;
void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float n = texture(rumore, UV * 2.5 + vec2(vita * 0.2, 0.0)).r * 0.6 + texture(rumore, UV * 8.0 - vec2(0.0, vita * 0.3)).r * 0.4;
	float bordo = 1.0 - smoothstep(0.55, 1.0, r);
	float k = bordo * (1.0 - vita);
	if (n * k < 0.28) {
		discard;
	}
	ALBEDO = vec3(0.5, 0.53, 0.55) * (0.7 + 0.3 * n);
}
"""
