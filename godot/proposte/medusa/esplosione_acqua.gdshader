// PROPOSTA esplosione d'acqua (riscontro 4 della v0.3.2): il muro d'acqua che sale dalla fossa e
// avvolge lei. La mesh e' una griglia cilindrica (UV.x intorno, UV.y dal pelo in su); la forma la
// fa il vertex shader:
//   forma 0 (A, geyser): colonna che si stringe verso l'alto;
//   forma 1 (B, cupola): corona che si allarga e poi si chiude sopra di lei (chiusura 0..1).
// crollo 0..1: l'acqua ricade, si apre e si sfalda in buchi sempre piu' grandi.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform sampler2D schermo : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec4 colore : source_color = vec4(0.72, 0.86, 0.95, 1.0);
uniform float forma = 0.0;
uniform float altezza = 3.0;
uniform float raggio = 1.3;
uniform float chiusura = 0.0;
uniform float crollo = 0.0;
uniform float opacita = 0.9;
uniform float seme = 0.0;

varying float v_su;
varying vec3 v_n;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	float a = UV.x * TAU;
	float v = UV.y;
	// Il bordo dell'acqua ondeggia (la griglia si chiude: il rumore usa l'angolo in modo periodico).
	vec2 giro = vec2(cos(a), sin(a)) * 1.6;
	float n = noise(giro + vec2(seme, v * 3.0 - TIME * 2.5)) - 0.5;
	float r;
	if (forma < 0.5) {
		// Si stringe salendo e in cima si apre a fungo, dove l'acqua si sfalda in spruzzo.
		r = raggio * (1.0 - 0.45 * v + 0.9 * smoothstep(0.72, 1.0, v)) * (1.0 + 0.3 * n);
	} else {
		r = raggio * mix(1.0 + 0.35 * v, sqrt(max(1.0 - v * v, 0.0)), chiusura) * (1.0 + 0.15 * n);
	}
	float y = altezza * v;
	// Ricade: la cima scende piu' in fretta della base e l'acqua si apre verso fuori.
	y = mix(y, y * 0.15 - crollo * 0.4 * v, crollo * crollo);
	r *= 1.0 + crollo * (0.6 + 0.8 * v);
	VERTEX = vec3(cos(a) * r, y, sin(a) * r);
	v_n = normalize(vec3(cos(a), 0.35 * (1.0 - forma) + forma * v, sin(a)));
	NORMAL = v_n;
	v_su = v;
}

float lamina_vis(float l) {
	return smoothstep(0.3, 0.6, l);
}

void fragment() {
	float v = v_su;
	// Lame e veli d'acqua: strisce lungo la colonna. In A l'acqua sale; nella cupola di B, quando si
	// chiude, scorre giu' sulla calotta.
	float flusso = mix(-1.0, 1.0, forma * smoothstep(0.3, 0.8, chiusura));
	float giro = UV.x * 26.0;
	float s1 = noise(vec2(giro, v * 2.2 + TIME * 4.5 * flusso + seme));
	float s2 = noise(vec2(giro * 2.6 + 3.0, v * 5.0 + TIME * 7.0 * flusso));
	float s3 = noise(vec2(UV.x * 70.0, v * 12.0 + TIME * 10.0 * flusso));
	float lame = s1 * 0.55 + s2 * 0.3 + s3 * 0.15;
	// Increspature: la normale segue le strisce, cosi' le luci fanno riflessi lunghi e mossi.
	NORMAL = normalize(NORMAL + vec3((s2 - 0.5) * 0.9, (s1 - 0.5) * 0.5, 0.0) + vec3((s3 - 0.5) * 0.3));
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	// Bianca solo sulle creste delle lame e al piede, dove l'acqua si strappa dal pelo.
	float piede = 1.0 - smoothstep(0.0, 0.12, v);
	float cresta = smoothstep(0.72, 0.86, lame);
	float schiuma = clamp(cresta * 0.8 + piede * 0.5 + smoothstep(0.85, 1.0, v) * 0.4 * (1.0 - forma), 0.0, 1.0);
	// Il resto rifrange quello che c'e' dietro (la colonna e' acqua trasparente, non un muro).
	vec2 off = NORMAL.xy * 0.09 * (1.0 - schiuma);
	vec3 dietro = texture(schermo, SCREEN_UV + off).rgb;
	ALBEDO = mix(vec3(0.02, 0.03, 0.035), vec3(0.55, 0.6, 0.63), schiuma);
	// Il velo rifrange lo sfondo schiarito: al buio si legge come acqua lucida, non come un buco.
	EMISSION = dietro * colore.rgb * (1.0 - schiuma) * 1.35 + colore.rgb * 0.035 * lamina_vis(lame);
	ROUGHNESS = mix(0.015, 0.35, schiuma);
	SPECULAR = 1.0;
	METALLIC = 0.0;
	// Velo sottile fra una lama e l'altra, piu' pieno sulle lame, riflesso ai bordi; la cima si
	// sfalda in brandelli; col crollo si aprono buchi sempre piu' grandi.
	float lamina = smoothstep(0.3, 0.6, lame);
	float cima = 1.0 - smoothstep(0.7, 1.0, v + (lame - 0.5) * 0.6) * (1.0 - forma * chiusura);
	float buchi = smoothstep(crollo * 1.15 - 0.05, crollo * 1.15 + 0.1, lame * 0.8 + (1.0 - v) * 0.35);
	float a = 0.22 + lamina * 0.45 + schiuma * 0.35 + fres * 0.6;
	ALPHA = clamp(a * opacita * cima * buchi, 0.0, 1.0);
}
