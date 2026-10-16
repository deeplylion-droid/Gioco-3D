// Acqua torbida (la pozza sul fondo della piscina): opaca, scura e lucidissima, così prende i
// riflessi dello spazio schermo (SSR) delle luci rosse e dei neon. Piccole increspature che si
// muovono, più forti dove il getto la colpisce o dove si aspira (impact_point / suck_point).
// Provvisoria: l'acqua vera arriverà dall'addon dell'acqua.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 shallow_color : source_color = vec4(0.2, 0.25, 0.17, 1.0);
uniform vec4 deep_color : source_color = vec4(0.035, 0.05, 0.035, 1.0);
uniform float wave_scale = 1.4;
uniform float wave_speed = 0.3;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.12;
uniform vec2 flow = vec2(0.0);
// Punto dove si aspira (xyz) e forza (w): anelli che corrono verso il centro.
uniform vec4 suck_point = vec4(0.0, -1000.0, 0.0, 0.0);
// Compatibilità con il materiale trasparente (non usato).
uniform float alpha = 1.0;

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
	vec2 p = (world_pos.xz - flow * TIME) * wave_scale;
	vec2 slope = wave_slope(p, TIME * wave_speed * 6.0) * wave_strength;
	// Anelli dell'aspirazione.
	vec2 d = world_pos.xz - suck_point.xz;
	float r = length(d);
	if (suck_point.w > 0.0 && r < 2.0) {
		float ring = cos(r * 22.0 + TIME * 12.0) * exp(-r * 1.6) * suck_point.w;
		slope += (d / max(r, 0.001)) * ring * 0.5;
	}
	vec3 n_world = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, 0.25 + 0.35 * (1.0 - facing));
	ROUGHNESS = 0.025;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
