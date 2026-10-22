// Acqua delle vasche dell'inseguimento (scelta dell'utente del 22 ottobre): meno torbida dell'acqua del
// fondo della piscina, verde-azzurra, e il fondo si intravede. Trasparente in base allo spessore d'acqua
// davanti a quello che c'è sotto (dalla profondità della scena): sottile quasi limpida, profonda piena.
// Le increspature sono quelle di water_murky.gdshader.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, depth_draw_always;

uniform vec4 water_color : source_color = vec4(0.2, 0.5, 0.46, 1.0);
uniform vec4 deep_color : source_color = vec4(0.06, 0.22, 0.21, 1.0);
// Quanto in fretta l'acqua si fa piena (per metro di spessore) e quanto è piena anche sottilissima.
uniform float absorption = 2.0;
uniform float min_alpha = 0.45;
uniform float wave_scale = 1.4;
uniform float wave_speed = 0.3;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.1;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 wave_slope(vec2 p, float t) {
	vec2 s = vec2(0.0);
	s += vec2(cos(p.x * 1.0 + t * 1.3), 0.0) * 0.5;
	s += vec2(0.0, cos(p.y * 1.3 - t * 1.1)) * 0.5;
	s += vec2(cos((p.x + p.y) * 2.1 + t * 1.9), cos((p.x + p.y) * 2.1 + t * 1.9)) * 0.25;
	s += vec2(cos((p.x - p.y) * 3.7 - t * 2.3), -cos((p.x - p.y) * 3.7 - t * 2.3)) * 0.12;
	s += vec2(cos(p.x * 7.1 + p.y * 2.3 + t * 3.1), cos(p.y * 6.3 - p.x * 1.7 - t * 2.7)) * 0.06;
	return s;
}

void fragment() {
	vec2 slope = wave_slope(world_pos.xz * wave_scale, TIME * wave_speed * 6.0) * wave_strength;
	vec3 n_world = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	// lo spessore d'acqua lungo lo sguardo: dalla superficie a quello che c'è dietro
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 dietro = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	dietro.xyz /= dietro.w;
	float spessore = max(length(dietro.xyz) - length(VERTEX), 0.0);
	float pieno = 1.0 - exp(-spessore * absorption);
	ALBEDO = mix(water_color.rgb, deep_color.rgb, pieno);
	ALPHA = clamp(max(pieno, min_alpha), 0.0, 1.0);
	ROUGHNESS = 0.03;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
