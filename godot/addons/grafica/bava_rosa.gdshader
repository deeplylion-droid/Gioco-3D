shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform vec4 colore : source_color = vec4(1.0, 0.16, 0.68, 1.0);
uniform float emissione = 1.5;
uniform float opacita = 0.75;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float lungo = UV.x;
	float trasv = abs(UV.y * 2.0 - 1.0);
	// Bordo irregolare e chiazze: dove la bava è più densa brilla di più.
	float bordo = 0.72 + 0.28 * n2(vec2(lungo * 6.0, UV.y * 3.0));
	float forma = 1.0 - smoothstep(bordo - 0.25, bordo, trasv);
	float dense = 0.55 + 0.45 * n2(vec2(lungo * 1.7, 3.0));
	float filamenti = smoothstep(0.55, 0.9, n2(vec2(lungo * 9.0, UV.y * 7.0)));
	float alpha = forma * (0.55 + 0.45 * dense);
	// Respiro lento della luce lungo la scia.
	float respiro = 0.8 + 0.2 * sin(TIME * 1.3 - lungo * 0.8);
	ALBEDO = colore.rgb * 0.25;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	EMISSION = colore.rgb * emissione * opacita * (0.5 + 0.7 * dense + 0.6 * filamenti) * respiro * forma;
	ALPHA = clamp(alpha, 0.0, 1.0) * opacita;
}
