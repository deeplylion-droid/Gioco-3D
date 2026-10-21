shader_type spatial;
// L'interno della bocca del mostro-squalo (assets_src/mascotte/mostro_bocca.py): carne bagnata, rosa
// scuro vicino ai denti, che scurisce fino al nero verso la gola. UV.y va da 0 (labbra) a 1 (gola).
render_mode cull_disabled;

uniform vec3 carne : source_color = vec3(0.36, 0.07, 0.07);
uniform vec3 gola : source_color = vec3(0.015, 0.0, 0.0);
uniform float lucido : hint_range(0.0, 1.0) = 0.8;

float rumore(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float rumore_liscio(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rumore(i), rumore(i + vec2(1, 0)), f.x), mix(rumore(i + vec2(0, 1)), rumore(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float fondo = smoothstep(0.05, 0.85, UV.y);
	// pieghe e venature della carne
	float n = rumore_liscio(UV * vec2(40.0, 12.0)) * 0.6 + rumore_liscio(UV * vec2(110.0, 30.0)) * 0.4;
	vec3 c = carne * (0.75 + 0.5 * n);
	ALBEDO = mix(c, gola, fondo);
	ROUGHNESS = mix(0.18, 0.5, n) + (1.0 - lucido) * 0.4;
	SPECULAR = 0.6;
}
