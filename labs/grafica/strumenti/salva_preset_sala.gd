extends SceneTree
## Genera le risorse del look della sala: grafica/sala/ambiente_sala.tres e
## grafica/sala/attributi_camera_sala.tres. Uso:
##   godot --headless --path labs/grafica -s strumenti/salva_preset_sala.gd
## Dopo averle generate si possono ritoccare a mano nell'editor.

func _init() -> void:
	var env := Environment.new()
	# Cielo in tempesta visto dalla cupola.
	var cielo := ShaderMaterial.new()
	cielo.shader = load("res://grafica/cielo_tempesta.gdshader")
	var sky := Sky.new()
	sky.sky_material = cielo
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Luce ambiente minima, fredda: le ombre tendono al blu-verde come nel concept A.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.1, 0.11)
	env.ambient_light_energy = 0.3
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# AgX: rossi saturi senza bruciarli, neon che sfumano bene nel bianco.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_agx_contrast = 1.3
	# Riflessi sul pavimento bagnato e nelle pozzanghere.
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.08
	env.ssr_fade_out = 1.6
	env.ssr_depth_tolerance = 0.25
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.4
	env.ssao_power = 1.7
	env.ssao_detail = 0.6
	env.ssil_enabled = true
	env.ssil_radius = 5.0
	env.ssil_intensity = 1.0
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.12
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	# Glow: aloni sui neon e sulle luci rosse.
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.85
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set("glow_levels/1", 0.0)
	env.set("glow_levels/2", 0.5)
	env.set("glow_levels/3", 1.0)
	env.set("glow_levels/4", 0.6)
	env.set("glow_levels/5", 0.5)
	# Nebbia volumetrica: i fasci di luce si vedono, il fondo della sala si perde.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.011
	env.volumetric_fog_albedo = Color(0.7, 0.78, 0.8)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 56.0
	env.volumetric_fog_detail_spread = 1.6
	env.volumetric_fog_gi_inject = 0.08
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.85
	env.adjustment_enabled = true
	print(ResourceSaver.save(env, "res://grafica/sala/ambiente_sala.tres"))
	# Nota: Godot scrive i parametri dello shader come "null"; si tolgono a mano
	# (sed -i '/^shader_parameter\/.* = null$/d' grafica/sala/ambiente_sala.tres).

	var cam := CameraAttributesPractical.new()
	# Esposizione fissa: la sala deve restare buia, niente adattamento automatico che schiarisce.
	cam.exposure_multiplier = 1.0
	cam.auto_exposure_enabled = false
	cam.dof_blur_far_enabled = false
	cam.dof_blur_near_enabled = false
	print(ResourceSaver.save(cam, "res://grafica/sala/attributi_camera_sala.tres"))
	quit()
