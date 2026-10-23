shader_type canvas_item;
// Il finale dello spot della crociera (inquadrature 8-9, bozza in docs/proposte/spot/bozza.md): l'occhio di Jilly che
// riempie lo schermo e ipnotizza, "ipnotico aggressivo crescente, molto horror" (l'utente). Va sopra l'immagine
// dell'occhio: su una camera (un ColorRect a tutto schermo, dallo_schermo acceso) o su un video (il materiale sul
// VideoStreamPlayer). I parametri li muove scripts/spot/occhio_ipnotico.gd. Com'è la crescita (intensita da 0 a 1):
//  - all'inizio l'occhio è quello dello spot allegro, quasi carino;
//  - poi si guasta: compaiono le vene sul bianco e si gonfiano, i colori virano a un viola e un rosso cupi e saturi,
//    la vignetta si chiude verso il nero;
//  - a ogni battito la spirale nella pupilla (rosa acceso e nero) gira più forte, lo schermo trema e i colori si
//    separano sempre di più;
//  - il lampo in negativo, lo scatto in avanti e il nero li comanda lo script. Niente sangue.

uniform bool dallo_schermo = false;
uniform sampler2D schermo : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform vec2 centro = vec2(0.5, 0.5);                        // la pupilla sullo schermo (UV)
uniform float raggio_pupilla : hint_range(0.01, 0.5) = 0.1;  // in altezze dello schermo (l'occhio a tutto schermo)
uniform float raggio_iride : hint_range(0.01, 1.0) = 0.36;
uniform float raggio_bulbo : hint_range(0.01, 1.5) = 0.62;   // fin dove arriva il bianco dell'occhio (le vene)
uniform float battito : hint_range(0.0, 1.0) = 0.0;          // il colpo del cuore (0 fra un battito e l'altro, 1 al colpo)
uniform float intensita : hint_range(0.0, 1.0) = 0.0;        // quanto è avanti il guasto (sale nell'inquadratura)
uniform float tempo = 0.0;                                    // il tempo dell'effetto (fermo nei fotogrammi saltati)
uniform float dilata : hint_range(0.0, 1.0) = 0.45;          // quanto si allarga la pupilla a ogni colpo
uniform float separa : hint_range(0.0, 0.08) = 0.035;        // i colori che si separano a ogni colpo (al massimo)
uniform float scossa : hint_range(0.0, 0.1) = 0.03;          // quanto trema lo schermo a ogni colpo (al massimo)
uniform float vene_finte : hint_range(0.0, 1.0) = 1.0;       // le vene disegnate qui (0 se le fa il materiale dell'occhio)
uniform vec3 rosa : source_color = vec3(1.0, 0.16, 0.62);    // il rosa acceso della spirale
uniform vec3 viola_cupo : source_color = vec3(0.12, 0.0, 0.16);
uniform vec3 rosso_cupo : source_color = vec3(0.72, 0.02, 0.1);
uniform float negativo : hint_range(0.0, 1.0) = 0.0;
uniform float avanti : hint_range(0.0, 1.0) = 0.0;           // lo scatto in avanti finale
uniform float nero : hint_range(0.0, 1.0) = 0.0;

float casuale(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float rumore(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(casuale(i), casuale(i + vec2(1, 0)), u.x), mix(casuale(i + vec2(0, 1)), casuale(i + vec2(1, 1)), u.x), u.y);
}

// vene: creste di un rumore a ottave, allungate lungo il raggio (vanno dal bordo dell'iride verso fuori)
float vene(vec2 polare, float spessore) {
	float v = 0.0;
	float a = 1.0;
	vec2 q = vec2(polare.x * 5.0, polare.y * 1.6);
	for (int i = 0; i < 4; i++) {
		float n = rumore(q);
		v = max(v, a * pow(1.0 - abs(2.0 * n - 1.0), mix(28.0, 9.0, spessore)));
		q = q * 2.1 + vec2(3.7, 1.3);
		a *= 0.75;
	}
	return v;
}

// lo schermo o la texture del nodo, dentro i bordi. È una macro e non una funzione: le texture dello schermo e TEXTURE
// non si possono passare come argomento (Godot stampa "custom_samplers.has(...tex_builtin)")
#define LEGGI(uv) (dallo_schermo ? textureLod(schermo, clamp((uv), vec2(0.001), vec2(0.999)), 0.0).rgb : texture(TEXTURE, clamp((uv), vec2(0.001), vec2(0.999))).rgb)

void fragment() {
	vec2 base = dallo_schermo ? SCREEN_UV : UV;
	vec2 px = dallo_schermo ? SCREEN_PIXEL_SIZE : TEXTURE_PIXEL_SIZE;
	float aspetto = px.y / px.x;                       // larghezza / altezza
	vec2 asp = vec2(aspetto, 1.0);
	float b = battito;
	float k = intensita;
	float k2 = k * k;

	// a ogni colpo lo schermo trema, sempre di più
	vec2 tremo = (vec2(casuale(vec2(floor(tempo * 30.0), 1.3)), casuale(vec2(floor(tempo * 30.0), 7.1))) - 0.5) * scossa * b * (0.15 + 0.85 * k2);
	vec2 d = base + tremo - centro;
	// lo scatto in avanti: tutto corre verso la pupilla; e a ogni colpo l'immagine balza verso chi guarda
	d /= 1.0 + avanti * avanti * 9.0;
	d *= 1.0 - (0.03 + 0.06 * k) * b * k;
	// la pupilla che si allarga a ogni colpo: dentro l'iride si legge più vicino al centro
	float r = length(d * asp);
	float spinta = dilata * b * (0.3 + 0.7 * k) * smoothstep(raggio_iride, 0.0, r);
	d *= 1.0 - spinta * 0.5;
	vec2 uv = centro + d;

	// i colori che si separano (rosso fuori, blu dentro), sempre di più; la scia del colpo verso il centro
	vec2 dir = normalize(d * asp + vec2(1e-5)) / asp;
	float s = separa * (b * (0.08 + 0.92 * k2) + 0.1 * k + avanti * 1.5);
	vec3 col = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float f = float(i) / 5.0;
		vec2 scia = -dir * f * (b * 0.05 * k + avanti * 0.12) * r;
		col.r += LEGGI(uv + scia + dir * s).r;
		col.g += LEGGI(uv + scia).g;
		col.b += LEGGI(uv + scia - dir * s * 1.4).b;
	}
	col /= 6.0;

	// le vene sul bianco dell'occhio: compaiono e si gonfiano, pulsano col cuore
	float a = atan(d.y * asp.y, d.x * asp.x);
	float rr = max(r, 0.002);
	float bianco = smoothstep(raggio_iride * 0.95, raggio_iride * 1.08, rr) * smoothstep(raggio_bulbo, raggio_bulbo * 0.8, rr);
	float gonfie = smoothstep(0.12, 0.75, k) * (0.85 + 0.3 * b);
	float v = vene(vec2(a, rr * 9.0 - tempo * 0.05), gonfie) * bianco * gonfie * vene_finte;
	col = mix(col, vec3(0.45, 0.0, 0.05) * (0.6 + 0.6 * b), clamp(v * 1.6, 0.0, 1.0));

	// i colori virano a un viola e un rosso cupi e saturi
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 cupo = mix(viola_cupo, rosso_cupo, smoothstep(0.12, 0.75, lum)) + rosa * 0.35 * smoothstep(0.75, 1.0, lum);
	col = mix(col, cupo * (0.5 + 0.9 * lum), smoothstep(0.1, 0.75, k));

	// la spirale nella pupilla e nell'iride: bande nette rosa acceso e nero, che girano sempre più veloci
	float giro = sin(a * 3.0 + log(rr) * 10.0 - tempo * (2.5 + 14.0 * k) - b * 3.0 * k);
	float bande = smoothstep(-0.12, 0.12, giro);
	float anelli = smoothstep(0.82, 0.98, sin(rr * (70.0 + 80.0 * k) - tempo * (6.0 + 22.0 * k)));
	vec3 spirale = mix(vec3(0.0), rosa * (1.0 + 0.8 * b), bande) + rosa * anelli * 0.8;
	float dentro = smoothstep(raggio_iride * (0.6 + 0.5 * k), raggio_pupilla * 0.3, rr);
	col = mix(col, spirale, dentro * (0.05 + 0.95 * smoothstep(0.05, 0.55, k)));

	// la vignetta che si chiude verso il nero (e si stringe un poco a ogni colpo)
	float vr = mix(1.3, 0.38, k) - 0.06 * b * k;
	float buio = smoothstep(vr, vr * 0.5, length((base - centro) * asp));
	col *= mix(1.0, buio, 0.25 + 0.75 * k);
	// il colpo: un lampo rosso scuro
	col = mix(col, vec3(0.55, 0.0, 0.06), b * 0.3 * k2);

	// il lampo in negativo (duro), lo scatto finale e il nero
	vec3 neg = vec3(1.0) - clamp(col, 0.0, 1.0);
	col = mix(col, neg * vec3(1.0, 0.85, 1.1), negativo);
	col *= 1.0 - nero;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
