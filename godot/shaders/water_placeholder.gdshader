// Acqua provvisoria per le vasche del graybox: superficie trasparente con piccole onde.
// L'acqua vera (riflessi, caustiche, schizzi) arriverà dal lavoro su labs/acqua.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.16, 0.42, 0.46, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.10, 0.14, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.72;
uniform float wave_scale = 1.6;
uniform float wave_speed = 0.35;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec2 flow = vec2(0.0); // corrente in m/s (x, z del mondo), per l'acqua che scorre

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
	return s;
}

void fragment() {
	vec2 p = (world_pos.xz - flow * TIME) * wave_scale;
	vec2 slope = wave_slope(p, TIME * wave_speed * 6.0) * wave_strength;
	vec3 n_world = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, 0.35 + 0.4 * (1.0 - facing));
	ROUGHNESS = 0.04;
	SPECULAR = 0.65;
	METALLIC = 0.0;
	ALPHA = mix(alpha, 1.0, pow(1.0 - facing, 3.0));
}
