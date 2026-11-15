shader_type spatial;
// La scia dello squalo nel fiume lento (SqualoFiume): due baffi di schiuma a V dietro la pinna, sul pelo dell'acqua
// scura. UV.x lungo la striscia (0 alla pinna), UV.y di traverso. Schiuma grigio-verde che scorre all'indietro, più fitta
// vicino alla pinna e sfumata ai lati e in fondo.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float forza : hint_range(0.0, 2.0) = 1.0;
uniform vec3 colore : source_color = vec3(0.62, 0.72, 0.70);

float rumore(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	float lato = 1.0 - abs(UV.y * 2.0 - 1.0);
	float lungo = (1.0 - UV.x) * smoothstep(0.0, 0.06, UV.x);
	float n = rumore(vec2(UV.x * 18.0 - TIME * 2.2, UV.y * 4.0)) * 0.6 + rumore(vec2(UV.x * 40.0 - TIME * 3.1, UV.y * 9.0)) * 0.4;
	float a = smoothstep(0.35, 0.8, n) * lato * lato * lungo * 0.55 * forza;
	ALBEDO = colore;
	ALPHA = clamp(a, 0.0, 1.0);
}
