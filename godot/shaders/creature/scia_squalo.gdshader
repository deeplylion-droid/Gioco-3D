shader_type spatial;
// La scia dello squalo nel fiume lento (SqualoFiume), sul pelo dell'acqua scura:
// - due baffi di schiuma a V che si aprono dietro la pinna (COLOR.r = 0): UV.x lungo la striscia (0 alla pinna),
//   UV.y di traverso. Una schiuma continua, più fitta vicino alla pinna, con la grana che scorre all'indietro;
// - il collare di schiuma intorno alla base della pinna (COLOR.r = 1): UV.x da dentro (0, contro la pinna) a fuori
//   (1), UV.y il giro intorno. Così la pinna scura si legge come una sagoma dentro la V chiara.
// Prende la luce della zona come l'acqua, più un filo di emissione (come i disegni del bambino) perché si veda anche
// nel tratto più buio; la pinna resta com'è.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;

uniform float forza : hint_range(0.0, 2.0) = 1.0;
uniform vec3 colore : source_color = vec3(0.80, 0.86, 0.84);
uniform float emissione : hint_range(0.0, 1.0) = 0.12;
uniform float collare : hint_range(0.0, 1.0) = 1.0;  // 0 quando attacca: la pinna non c'è più

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
	float a;
	if (COLOR.r > 0.5) {
		// il collare: pieno contro la pinna, sfuma verso fuori; la grana gira piano
		float n = rumore(vec2(UV.y * 24.0 - TIME * 1.5, UV.x * 3.0 + TIME * 0.7));
		a = (1.0 - smoothstep(0.15, 1.0, UV.x)) * (0.75 + 0.25 * n) * 0.85 * collare;
	} else {
		float lato = smoothstep(0.0, 0.55, 1.0 - abs(UV.y * 2.0 - 1.0));
		float lungo = pow(1.0 - UV.x, 1.3) * smoothstep(0.0, 0.04, UV.x);
		float n = rumore(vec2(UV.x * 18.0 - TIME * 2.2, UV.y * 4.0)) * 0.6 + rumore(vec2(UV.x * 40.0 - TIME * 3.1, UV.y * 9.0)) * 0.4;
		// una base continua, e la grana sopra
		a = (0.55 + 0.45 * smoothstep(0.25, 0.75, n)) * lato * lungo * 0.8;
	}
	ALBEDO = colore;
	ROUGHNESS = 1.0;
	EMISSION = colore * emissione;
	ALPHA = clamp(a * forza, 0.0, 1.0);
}
