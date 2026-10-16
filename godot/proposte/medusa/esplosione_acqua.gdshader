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

void fragment() {
	float v = v_su;
	// Lame d'acqua verticali: rumore stirato lungo la colonna che sale veloce.
	float giro = UV.x * 22.0;
	float s1 = noise(vec2(giro, v * 2.5 - TIME * 5.0 + seme));
	float s2 = noise(vec2(giro * 2.3 + 3.0, v * 6.0 - TIME * 8.0));
	float s3 = noise(vec2(UV.x * 60.0, v * 14.0 - TIME * 11.0));
	float lame = s1 * 0.55 + s2 * 0.3 + s3 * 0.15;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	// Bianca dove l'acqua e' rotta (lame chiare, base e cima), trasparente e rifrangente altrove.
	float schiuma = clamp(smoothstep(0.5, 0.8, lame) + (1.0 - smoothstep(0.0, 0.18, v)) * 0.6 + smoothstep(0.7, 1.0, v) * 0.5 + forma * 0.3, 0.0, 1.0);
	vec2 off = NORMAL.xy * 0.06;
	vec3 dietro = texture(schermo, SCREEN_UV + off).rgb;
	ALBEDO = mix(colore.rgb * 0.15, vec3(0.62, 0.68, 0.72), schiuma);
	EMISSION = dietro * colore.rgb * (1.0 - schiuma) * 0.95 + dietro * 0.25 * schiuma;
	ROUGHNESS = mix(0.03, 0.45, schiuma);
	SPECULAR = 1.0;
	// Fra una lama e l'altra si vede attraverso; la cima si sfalda in brandelli; col crollo si
	// aprono buchi sempre piu' grandi.
	float pieno = smoothstep(0.25, 0.55, lame + 0.15 * (1.0 - v));
	float cima = 1.0 - smoothstep(0.7, 1.0, v + (lame - 0.5) * 0.6) * (1.0 - forma * chiusura);
	float buchi = smoothstep(crollo * 1.15 - 0.05, crollo * 1.15 + 0.1, lame * 0.8 + (1.0 - v) * 0.35);
	// La cupola (B) quando si chiude e' un velo pieno: lei dentro non si vede piu'.
	float a = mix(0.35, 0.9, schiuma) * pieno + fres * 0.3 + forma * smoothstep(0.2, 0.7, chiusura) * 0.55;
	ALPHA = clamp(a * opacita * cima * buchi, 0.0, 1.0);
}
