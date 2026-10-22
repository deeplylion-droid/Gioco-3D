shader_type spatial;
// L'acqua che scorre sul fondo di un tubo dello scivolo, per lo spot VHS (torre_spot.tscn): un nastro lungo il
// fondo, con la schiuma che corre in avanti (UV.y = metri lungo il tubo, UV.x = da un lato all'altro).
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4 colore : source_color = vec4(0.2, 0.62, 0.78, 1.0);
uniform vec4 colore_schiuma : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float velocita = 3.2;
uniform float alfa = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rumore(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 q = vec2(UV.x * 3.0, UV.y * 1.6 - TIME * velocita);
	float n = rumore(q * 2.0) * 0.6 + rumore(q * 5.0 + 7.0) * 0.3 + rumore(q * 11.0) * 0.1;
	// la schiuma ai bordi del nastro (dove l'acqua sale sulla parete) e a strisce che corrono
	float bordo = smoothstep(0.4, 0.5, abs(UV.x - 0.5));
	float schiuma = clamp(smoothstep(0.62, 0.85, n) * 0.8 + bordo * 0.5, 0.0, 1.0);
	ALBEDO = mix(colore.rgb, colore_schiuma.rgb, schiuma);
	ROUGHNESS = mix(0.04, 0.35, schiuma);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = clamp(alfa + schiuma * 0.35, 0.0, 1.0);
	// le increspature: la normale si piega col rumore
	float dx = rumore(q * 3.0 + vec2(0.05, 0.0)) - rumore(q * 3.0 - vec2(0.05, 0.0));
	float dy = rumore(q * 3.0 + vec2(0.0, 0.05)) - rumore(q * 3.0 - vec2(0.0, 0.05));
	NORMAL_MAP = normalize(vec3(dx * 2.0, dy * 2.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
}
