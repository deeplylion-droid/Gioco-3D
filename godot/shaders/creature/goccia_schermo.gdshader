shader_type canvas_item;
// La goccia di bava che cade sulla faccia del giocatore nella scena dello squalo all'inizio (dalla 0.3.22, proposta C
// "ti annusa", sì dell'utente). Dalla 0.3.23 è la versione B scelta dall'utente («più bava: meno tonda e lucida, più
// densa e torbida, con un filo che la tiene al muso per un attimo prima di scivolare»; la A della 0.3.22 è in
// assets_src/mascotte/scartati/goccia_schermo_A_0322.gdshader):
// - densa e torbida: un velo lattiginoso e giallastro che copre buona parte di quello che c'è dietro, la lente appena
//   accennata e un riflesso piccolo e morbido;
// - forma irregolare (il bordo ondeggia, più pesante in basso);
// - un filo di bava dalla goccia al muso ([member aggancio], dove sta il mento sullo schermo), che si accorcia verso il
//   muso quando si spezza ([member filo] da 1 a 0);
// - la scia spessa che lascia scivolando.
// La muove risveglio_squalo.gd. Con forza 0 non si vede (si disegna lo stesso nel riscaldamento: shader e pipeline
// pronti prima).

uniform sampler2D schermo : hint_screen_texture, filter_linear_mipmap;
uniform float forza : hint_range(0.0, 1.0) = 0.0;
// il centro della goccia (UV dello schermo), il raggio (in altezze dello schermo), la scia sopra (in raggi)
uniform vec2 centro = vec2(0.4, 0.3);
uniform float raggio = 0.07;
uniform float scia = 0.0;
// larghezza / altezza dello schermo
uniform float aspetto = 1.7778;
// il filo: dove si attacca al muso (UV dello schermo) e quanto ne resta (1 intero, 0 spezzato e sparito)
uniform vec2 aggancio = vec2(0.4, 0.0);
uniform float filo : hint_range(0.0, 1.0) = 0.0;
// quanto è tirata verso il filo (0-1): la goccia appesa si allunga un poco verso l'alto
uniform float tirata : hint_range(0.0, 1.0) = 0.0;

// la distanza dal segmento a-b, e dove (0 in a, 1 in b)
vec2 segmento(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float u = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	return vec2(length(p - (a + ab * u)), u);
}

void fragment() {
	vec2 p = (SCREEN_UV - centro) * vec2(aspetto, 1.0) / raggio;
	// tirata verso il filo: allungata in su; pesante in basso
	vec2 q = vec2(p.x, p.y < 0.0 ? p.y / (1.0 + 0.45 * tirata) : p.y * 0.86);
	q.x *= 1.0 + 0.1 * clamp(-q.y, 0.0, 1.0);
	// il bordo irregolare: ondeggia con l'angolo
	float ang = atan(q.y, q.x);
	float bordo = 1.0 + 0.10 * sin(3.0 * ang + 1.3) + 0.06 * sin(5.0 * ang + 4.1) + 0.04 * sin(9.0 * ang + 0.7);
	float d = length(q) / bordo;
	float corpo = 1.0 - smoothstep(0.82, 1.0, d);
	// la scia: sopra la goccia, spessa, si stringe e sbiadisce, coi bordi mossi
	float s = 0.0;
	if (scia > 0.0 && p.y < 0.0) {
		float u = clamp(-p.y / scia, 0.0, 1.0);
		float w = mix(0.78, 0.22, u) * (1.0 + 0.15 * sin(p.y * 2.3 + 0.8));
		s = (1.0 - smoothstep(w * 0.55, w, abs(p.x + 0.1 * sin(p.y * 1.5)))) * (1.0 - u * u);
	}
	// il filo: dalla cima della goccia al muso, un poco cadente; resta solo la parte verso il muso, quanta ne dice filo
	float f = 0.0;
	if (filo > 0.0) {
		vec2 pa = SCREEN_UV * vec2(aspetto, 1.0);
		vec2 a = (centro - vec2(0.0, raggio * 0.75)) * vec2(aspetto, 1.0);
		vec2 b = aggancio * vec2(aspetto, 1.0);
		vec2 su = segmento(pa, a, b);
		// cadente: il filo si piega in giù a metà (una parabola lungo il segmento)
		float pancia = 4.0 * su.y * (1.0 - su.y) * 0.018;
		vec2 su2 = segmento(pa - vec2(0.0, pancia), a, b);
		float w = mix(0.012, 0.0045, su2.y);
		f = (1.0 - smoothstep(w * 0.4, w, su2.x)) * step(1.0 - filo, su2.y);
	}
	float a_tot = max(max(corpo, s * 0.7), f * 0.85) * forza;
	if (a_tot <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// dietro: sfocato, appena spostato (la lente quasi non c'è: è densa)
		float z = sqrt(max(1.0 - d * d, 0.0));
		vec2 lente = -q * (0.3 + 0.3 * z) * raggio * 0.6 * corpo / vec2(aspetto, 1.0);
		vec3 dietro = textureLod(schermo, SCREEN_UV + lente, 2.5 + 1.5 * corpo).rgb;
		// la bava: torbida, lattiginosa e un poco giallastra, prende la luce di quello che ha dietro
		float l = dot(dietro, vec3(0.3, 0.5, 0.2));
		vec3 bava = vec3(0.62, 0.58, 0.47) * (0.25 + 0.9 * l) + 0.025;
		float torbida = max(0.52 * corpo, max(0.5 * s, 0.8 * f));
		vec3 col = mix(dietro, bava, torbida);
		// lo spessore: il bordo in alto più chiaro (prende la luce), quello in basso più scuro (la goccia pesa e fa
		// ombra), il filo che luccica appena
		col += vec3(0.16, 0.15, 0.13) * smoothstep(0.68, 0.93, d) * smoothstep(0.1, -0.5, q.y) * corpo;
		col *= 1.0 - 0.3 * smoothstep(0.6, 0.95, d) * smoothstep(-0.1, 0.6, q.y) * corpo;
		col += vec3(0.1, 0.1, 0.09) * f;
		// un riflesso morbido (non più lucida come la A)
		col += vec3(0.3, 0.29, 0.27) * pow(smoothstep(0.26, 0.0, length(q - vec2(-0.3, -0.36))), 2.0) * corpo;
		COLOR = vec4(col, a_tot);
	}
}
