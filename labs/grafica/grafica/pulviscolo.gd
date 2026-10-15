class_name Pulviscolo
extends GPUParticles3D
## Polvere sospesa nell'aria. Le particelle sono illuminate davvero dalle luci
## della scena: nel buio non si vedono, nel fascio della torcia e sotto i neon sì.

@export var volume := Vector3(10, 4, 10)    # dimensioni della zona
@export var densita := 1.0                  # moltiplica il numero di particelle
@export var colore := Color(0.85, 0.82, 0.75, 0.55)


func _ready() -> void:
	add_to_group("grafica_particelle")
	amount = int(clampf(volume.x * volume.y * volume.z * 1.2 * densita, 50, 6000))
	lifetime = 14.0
	preprocess = 14.0
	visibility_aabb = AABB(-volume / 2 - Vector3.ONE, volume + Vector3.ONE * 2)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = volume / 2
	m.direction = Vector3(0, 1, 0)
	m.spread = 180.0
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 0.03
	m.gravity = Vector3(0, -0.004, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 3.0
	m.turbulence_noise_speed_random = 0.3
	m.turbulence_influence_min = 0.02
	m.turbulence_influence_max = 0.06
	m.scale_min = 0.5
	m.scale_max = 1.4
	var alfa := Curve.new()
	alfa.add_point(Vector2(0, 0))
	alfa.add_point(Vector2(0.15, 1))
	alfa.add_point(Vector2(0.85, 1))
	alfa.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = alfa
	m.alpha_curve = ct
	process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = colore
	mat.albedo_texture = PunteggioMorbido.texture()
	mat.roughness = 1.0
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.backlight_enabled = true      # brilla anche controluce, come la polvere vera
	mat.backlight = Color(0.6, 0.6, 0.6)
	q.material = mat
	draw_pass_1 = q
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
