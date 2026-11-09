shader_type canvas_item;
// La goccia di bava che cade sulla faccia del giocatore nella scena dello squalo all'inizio (dalla 0.3.22, proposta C
// "ti annusa", sì dell'utente). Dalla 0.3.23 è la versione B scelta dall'utente («più bava: meno tonda e lucida, più
// densa e torbida, con un filo che la tiene al muso per un attimo prima di scivolare»; la A della 0.3.22 è in
// assets_src/mascotte/scartati/goccia_schermo_A_0322.gdshader). Resa da liquido (riscontro del coordinatore sui primi
// scatti: sembrava un adesivo piatto e il filo uno stuzzicadenti):
// - la goccia: lattiginosa, bianco-giallastra, che prende il colore della scena dietro; più piena al centro e
//   trasparente sul bordo, dove fa da lente (la scena dietro si vede deformata); il menisco, un bordo un filo più scuro e
//   più spesso; un riflesso piccolo e morbido che segue la forma; dentro due bollicine e qualche striatura; forma
//   irregolare, più pesante in basso;
// - il filo: dalla goccia al muso ([member aggancio], dove sta il mento sullo schermo), cadente per il peso, che ondeggia,
//   più spesso ai capi e sottile in mezzo, traslucido con una linea di riflesso; quando si spezza ([member rottura] da 0
//   a 1) i due capi si ritirano con un piccolo rimbalzo elastico e si assottigliano;
// - la scia: bagnata e semitrasparente, con un poco di lente e il bordo.
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
// il filo: dove si attacca al muso (UV dello schermo), quanto si vede (1 intero, 0 sparito) e la rottura (0 intero,
// 1 i due capi ritirati del tutto)
uniform vec2 aggancio = vec2(0.4, 0.0);
uniform float filo : hint_range(0.0, 1.0) = 0.0;
uniform float rottura : hint_range(0.0, 1.0) = 0.0;
// quanto è tirata verso il filo (0-1): la goccia appesa si allunga un poco verso l'alto
uniform float tirata : hint_range(0.0, 1.0) = 0.0;
// il tempo dalla caduta (s): il filo ondeggia
uniform float tempo = 0.0;

// la distanza dal segmento a-b, e dove (0 in a, 1 in b)
vec2 segmento(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float u = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	return vec2(length(p - (a + ab * u)), u);
}

// la bava che prende il colore di quello che ha dietro: lattiginosa, bianco-giallastra
vec3 bava(vec3 dietro) {
	float l = dot(dietro, vec3(0.3, 0.5, 0.2));
	return mix(vec3(l), dietro, 0.3) * 1.6 * vec3(1.0, 0.98, 0.88) + vec3(0.27, 0.26, 0.2);
}

void fragment() {
	vec2 p = (SCREEN_UV - centro) * vec2(aspetto, 1.0) / raggio;
	// tirata verso il filo: allungata in su; pesante in basso
	vec2 q = vec2(p.x, p.y < 0.0 ? p.y / (1.0 + 0.45 * tirata) : p.y * 0.86);
	q.x *= 1.0 + 0.1 * clamp(-q.y, 0.0, 1.0);
	// il bordo irregolare: ondeggia con l'angolo
	float ang = atan(q.y, q.x);
	float bordo = 1.0 + 0.09 * sin(3.0 * ang + 1.3) + 0.05 * sin(5.0 * ang + 4.1) + 0.03 * sin(9.0 * ang + 0.7);
	float d = length(q) / bordo;
	float corpo = 1.0 - smoothstep(0.95, 1.0, d);
	// l'altezza della goccia (0 sul bordo, 1 al centro) e la sua normale
	float z = sqrt(max(1.0 - d * d, 0.0));
	vec3 nrm = normalize(vec3(q / max(bordo, 0.5) * 1.1, z + 0.15));

	// la scia: sopra la goccia, spessa e bagnata, si stringe e sbiadisce, coi bordi mossi
	float s = 0.0;
	float s_bordo = 0.0;
	if (scia > 0.0 && p.y < 0.0) {
		float u = clamp(-p.y / scia, 0.0, 1.0);
		float w = mix(0.78, 0.22, u) * (1.0 + 0.15 * sin(p.y * 2.3 + 0.8));
		float x = abs(p.x + 0.1 * sin(p.y * 1.5)) / max(w, 0.01);
		s = (1.0 - smoothstep(0.6, 1.0, x)) * (1.0 - u * u);
		s_bordo = smoothstep(0.45, 0.85, x) * s;
	}

	// il filo: dalla cima della goccia al muso, cadente e ondeggiante
	float f = 0.0;
	float f_luce = 0.0;
	if (filo > 0.0) {
		vec2 pa = SCREEN_UV * vec2(aspetto, 1.0);
		vec2 a = (centro - vec2(0.0, raggio * 0.75)) * vec2(aspetto, 1.0);
		vec2 b = aggancio * vec2(aspetto, 1.0);
		float lungo = length(b - a);
		vec2 su = segmento(pa, a, b);
		// pende per il peso (più quando è lungo) e ondeggia piano; spezzato, i capi pendono un poco di più
		float pancia = 4.0 * su.y * (1.0 - su.y) * (0.1 * lungo + 0.02) * (1.0 + 0.4 * rottura);
		pancia += sin(tempo * 6.5 + su.y * 3.0) * 0.006 * sin(3.14159 * su.y);
		vec2 su2 = segmento(pa - vec2(0.0, pancia), a, b);
		float u = su2.y;
		// più spesso ai capi (sulla goccia e sul mento), sottile in mezzo
		float w = mix(0.0045, 0.015, pow(abs(2.0 * u - 1.0), 1.6));
		// spezzato: i due capi si ritirano, il basso verso la goccia e l'alto verso il muso, con un piccolo rimbalzo
		// elastico, e si assottigliano verso la punta
		float vis = 1.0;
		if (rottura > 0.0) {
			float e = clamp(rottura + 0.18 * sin(rottura * 6.2832) * (1.0 - rottura), 0.0, 1.0);
			float basso = 0.48 * (1.0 - e);
			float alto = 0.52 + 0.48 * e;
			if (u < 0.5) {
				vis = step(u, basso);
				w *= mix(0.35, 1.0, smoothstep(0.0, 0.12, basso - u));
			} else {
				vis = step(alto, u);
				w *= mix(0.35, 1.0, smoothstep(0.0, 0.12, u - alto));
			}
		}
		float x = su2.x / max(w, 1e-4);
		f = (1.0 - smoothstep(0.55, 1.0, x)) * vis;
		// la linea di riflesso sottile, un poco sopra il centro del filo
		f_luce = (1.0 - smoothstep(0.0, 0.22, abs(x - 0.25))) * vis * f;
	}

	// quanto copre: la goccia più piena al centro e trasparente sul bordo (col menisco un filo più pieno), il filo
	// traslucido, la scia semitrasparente
	float menisco = smoothstep(0.84, 0.95, d) * corpo;
	float a_goccia = corpo * (0.35 + 0.55 * z) + 0.3 * menisco;
	float a_tot = max(max(a_goccia, s * 0.55), f * 0.8) * forza;
	if (a_tot <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// dietro: la lente, forte sul bordo (dove la goccia è inclinata) e quasi niente al centro
		vec2 lente = -nrm.xy * (1.0 - z) * raggio * 1.3 * corpo / vec2(aspetto, 1.0);
		lente += -vec2(p.x, 0.0) * s_bordo * raggio * 0.15 / aspetto;
		vec3 dietro = textureLod(schermo, SCREEN_UV + lente, 1.0 + 1.5 * z * corpo).rgb;
		vec3 col = dietro;
		// la goccia: lattiginosa più al centro, trasparente sul bordo
		// (lattiginosa al centro, quasi limpida sul bordo)
		float latte = corpo * (0.1 + 0.75 * pow(z, 1.4));
		// dentro: striature lente e due bollicine
		float strie = sin(q.x * 7.0 + q.y * 3.0 + 1.7) * sin(q.y * 5.0 - 0.9);
		latte *= 1.0 + 0.18 * strie;
		col = mix(col, bava(dietro), clamp(latte, 0.0, 1.0));
		for (int i = 0; i < 2; i++) {
			vec2 c = i == 0 ? vec2(0.22, 0.18) : vec2(-0.12, 0.38);
			float rb = i == 0 ? 0.11 : 0.07;
			float db = length(q - c) / rb;
			col += vec3(0.11, 0.11, 0.1) * smoothstep(1.0, 0.75, db) * smoothstep(0.45, 0.8, db) * corpo;
			col += vec3(0.16, 0.16, 0.15) * smoothstep(0.35, 0.0, length(q - c + vec2(0.3, 0.3) * rb) / rb) * corpo;
		}
		// il menisco: il bordo un filo più scuro e più spesso
		col *= 1.0 - 0.38 * menisco;
		// e appena dentro il menisco una riga più chiara, dove il bordo prende la luce
		col += vec3(0.09, 0.09, 0.08) * smoothstep(0.66, 0.76, d) * smoothstep(0.88, 0.78, d) * smoothstep(0.3, -0.4, q.y) * corpo;
		// il riflesso: piccolo e morbido, segue la forma (la luce da sopra a sinistra), bagnato ma non lucido come la A
		vec3 luce = normalize(vec3(-0.45, -0.6, 0.66));
		float spec = pow(max(dot(nrm, luce), 0.0), 34.0);
		col += vec3(0.7, 0.68, 0.63) * spec * corpo;
		// e la luce che passa dentro e si raccoglie in basso, dalla parte opposta al riflesso (un liquido, non un adesivo)
		col += vec3(0.16, 0.155, 0.13) * smoothstep(0.45, 0.0, length(q - vec2(0.22, 0.5))) * corpo;
		col += vec3(0.08, 0.08, 0.07) * smoothstep(0.82, 0.95, d) * smoothstep(0.0, 0.8, q.y + q.x * 0.5) * corpo;
		// la scia: bagnata, appena lattiginosa, col bordo più scuro e una riga di luce
		col = mix(col, bava(dietro), 0.3 * s * (1.0 - corpo));
		col *= 1.0 - 0.22 * s_bordo * (1.0 - corpo);
		// il filo: traslucido, lattiginoso, con la linea di riflesso
		col = mix(col, bava(dietro), 0.7 * f * (1.0 - corpo));
		col += vec3(0.3, 0.29, 0.26) * f_luce * (1.0 - corpo);
		COLOR = vec4(col, a_tot);
	}
}
