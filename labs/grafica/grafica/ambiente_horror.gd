class_name AmbienteHorror
## Environment di partenza per le zone del gioco: notte, interni bui, AgX,
## nebbia volumetrica che reagisce alle luci, SSR/SSAO/SSIL accesi (l'autoload
## Grafica li spegne secondo le opzioni). Sono i valori della sala di prova.
## Uso:  $WorldEnvironment.environment = AmbienteHorror.crea()
## Oppure come punto di partenza da salvare in un .tres e ritoccare nell'editor.


static func crea(con_cielo_in_tempesta := true) -> Environment:
	var env := Environment.new()
	if con_cielo_in_tempesta:
		var cielo := ShaderMaterial.new()
		cielo.shader = preload("res://grafica/cielo_tempesta.gdshader")
		var sky := Sky.new()
		sky.sky_material = cielo
		sky.radiance_size = Sky.RADIANCE_SIZE_64
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color.BLACK
	# Luce ambiente minima: il buio deve restare buio, ma non nero assoluto.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_energy = 0.6
	# I riflessi vengono dalle ReflectionProbe e da SSR, non dal cielo.
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.4
	env.ssr_enabled = true
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.2
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set("glow_levels/1", 0.0)
	env.set("glow_levels/2", 0.4)
	env.set("glow_levels/3", 1.0)
	env.set("glow_levels/5", 0.6)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.72, 0.76, 0.8)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_detail_spread = 1.6
	env.volumetric_fog_gi_inject = 0.25
	env.volumetric_fog_ambient_inject = 0.02
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.85
	return env
