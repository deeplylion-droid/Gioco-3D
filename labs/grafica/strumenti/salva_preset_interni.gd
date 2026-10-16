extends SceneTree
## Genera grafica/interni/ambiente_interni.tres e attributi_interni.tres (look degli interni).
## Uso: godot --headless --path labs/grafica -s strumenti/salva_preset_interni.gd

func _init() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	# Le ombre non sono nere piene: un minimo di luce fredda verso il blu-verde (concept A).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.17, 0.19)
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED  # riflessi dalle sonde
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_agx_contrast = 1.2
	# Riflessi sul pavimento bagnato.
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 1.5
	env.ssr_depth_tolerance = 0.2
	# Occlusione stretta negli angoli e luce rimbalzata vicina: danno profondità.
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5
	env.ssao_detail = 0.7
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 1.0
	# Glow solo sulle lampade, non sull'immagine intera.
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set("glow_levels/1", 0.0)
	env.set("glow_levels/2", 0.6)
	env.set("glow_levels/3", 1.0)
	env.set("glow_levels/4", 0.4)
	# Nebbia leggerissima: aloni attorno alle lampade, niente velo sull'immagine.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.7, 0.75, 0.78)
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 24.0
	env.volumetric_fog_detail_spread = 1.5
	env.volumetric_fog_gi_inject = 0.1
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.8
	env.adjustment_enabled = true
	print(ResourceSaver.save(env, "res://grafica/interni/ambiente_interni.tres"))
	var cam := CameraAttributesPractical.new()
	cam.auto_exposure_enabled = false
	cam.exposure_multiplier = 1.0
	cam.dof_blur_far_enabled = true
	cam.dof_blur_far_distance = 14.0
	cam.dof_blur_far_transition = 10.0
	cam.dof_blur_amount = 0.04
	print(ResourceSaver.save(cam, "res://grafica/interni/attributi_interni.tres"))
	quit()
