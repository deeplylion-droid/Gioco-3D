class_name Vapore
extends GPUParticles3D
## Vapore che sale (da griglie, tubi, docce calde). Sbuffi morbidi illuminati
## dalle luci; se la nebbia volumetrica è attiva aggiunge anche un FogVolume
## locale, così il vapore "prende" il fascio della torcia.

@export var portata := 1.0                 # quantità di vapore
@export var altezza := 2.5                 # quanto sale
@export var raggio := 0.3                  # larghezza della sorgente
@export var colore := Color(0.8, 0.82, 0.85, 0.11)
@export var volume_nebbia := true
## Sbuffi a intermittenza invece che continui (es. tubo rotto).
@export var a_sbuffi := false

var _t := 0.0


func _ready() -> void:
	add_to_group("grafica_particelle")
	amount = int(40 * portata)
	lifetime = altezza / 0.5
	preprocess = lifetime
	visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, altezza + 2, 4))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = raggio
	m.direction = Vector3.UP
	m.spread = 12.0
	m.initial_velocity_min = 0.35
	m.initial_velocity_max = 0.7
	m.gravity = Vector3(0, 0.05, 0)
	m.damping_min = 0.05
	m.damping_max = 0.15
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -15.0
	m.angular_velocity_max = 15.0
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.2
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.12
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(1, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	var alfa := Curve.new()
	alfa.add_point(Vector2(0, 0))
	alfa.add_point(Vector2(0.2, 1))
	alfa.add_point(Vector2(1, 0))
	var at := CurveTexture.new()
	at.curve = alfa
	m.alpha_curve = at
	process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 1.4) * maxf(raggio * 2.5, 0.6)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = colore
	mat.albedo_texture = PunteggioMorbido.texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.backlight_enabled = true
	mat.backlight = Color(0.5, 0.5, 0.5)
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.6
	q.material = mat
	draw_pass_1 = q
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if volume_nebbia:
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		fv.size = Vector3(raggio * 4 + 0.8, altezza, raggio * 4 + 0.8)
		fv.position.y = altezza * 0.45
		var fm := FogMaterial.new()
		fm.density = 0.35 * portata
		fm.albedo = Color(0.85, 0.87, 0.9)
		fm.edge_fade = 0.6
		var rumore := FastNoiseLite.new()
		rumore.frequency = 0.08
		var n3 := NoiseTexture3D.new()
		n3.noise = rumore
		n3.width = 32
		n3.height = 32
		n3.depth = 32
		fm.density_texture = n3
		fv.material = fm
		add_child(fv)


func _process(delta: float) -> void:
	if a_sbuffi:
		_t += delta
		var s := sin(_t * 2.1) + sin(_t * 3.7 + 1.0) * 0.5
		amount_ratio = clampf(s, 0.0, 1.0) * float([0.3, 0.6, 1.0][int(Grafica.valore("particelle"))])
