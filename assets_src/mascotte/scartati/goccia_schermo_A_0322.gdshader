shader_type canvas_item;
// La goccia di bava che cade sulla faccia del giocatore nella scena dello squalo all'inizio (dalla 0.3.23, proposta C
// "ti annusa", sì dell'utente): sullo schermo una goccia densa che fa da lente (l'immagine dietro sfocata e capovolta un
// poco), col bordo scuro e un riflesso, che scivola giù lasciando una scia. La muove risveglio_squalo.gd.
// Con forza 0 non si vede (si disegna lo stesso qualche fotogramma col livello: shader e pipeline pronti prima).

uniform sampler2D schermo : hint_screen_texture, filter_linear_mipmap;
uniform float forza : hint_range(0.0, 1.0) = 0.0;
// il centro della goccia (UV dello schermo), il raggio (in altezze dello schermo), la scia sopra (in raggi)
uniform vec2 centro = vec2(0.4, 0.3);
uniform float raggio = 0.07;
uniform float scia = 0.0;
// larghezza / altezza dello schermo
uniform float aspetto = 1.7778;

void fragment() {
	vec2 p = (SCREEN_UV - centro) * vec2(aspetto, 1.0) / raggio;
	// più pesante in basso: allungata sotto, stretta sopra
	vec2 q = vec2(p.x * (1.0 + 0.12 * clamp(-p.y, 0.0, 1.0)), p.y > 0.0 ? p.y * 0.82 : p.y);
	float d = length(q);
	float corpo = 1.0 - smoothstep(0.86, 1.0, d);
	// la scia: sopra la goccia, una striscia che si stringe e sbiadisce
	float s = 0.0;
	if (scia > 0.0 && p.y < 0.0) {
		float u = clamp(-p.y / scia, 0.0, 1.0);
		float w = mix(0.5, 0.12, u);
		s = (1.0 - smoothstep(w * 0.6, w, abs(p.x + 0.08 * sin(p.y * 1.7)))) * (1.0 - u * u);
	}
	float a = max(corpo, s * 0.55) * forza;
	if (a <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// la lente: dentro la goccia l'immagine sfocata e capovolta un poco; nella scia solo sfocata
		float z = sqrt(max(1.0 - d * d, 0.0));
		vec2 lente = -q * (0.4 + 0.6 * z) * raggio * 1.1 * corpo / vec2(aspetto, 1.0);
		vec3 col = textureLod(schermo, SCREEN_UV + lente, 1.0 + 2.0 * corpo).rgb * (1.0 + 0.35 * z * corpo);
		// la bava: un velo lattiginoso e un poco giallo, il bordo appena più scuro, il riflesso grande in alto a sinistra
		// e quello piccolo in basso a destra (la luce che la attraversa)
		col = mix(col, vec3(dot(col, vec3(0.33))) * vec3(1.08, 1.04, 0.95) + 0.035, 0.35 * max(corpo, s));
		col *= 1.0 - 0.3 * smoothstep(0.7, 1.0, d) * corpo;
		col += vec3(0.75, 0.72, 0.78) * pow(smoothstep(0.42, 0.0, length(q - vec2(-0.3, -0.35))), 2.0) * corpo;
		col += vec3(0.35, 0.33, 0.38) * smoothstep(0.16, 0.0, length(q - vec2(0.3, 0.45))) * corpo;
		col += vec3(0.25) * smoothstep(0.08, 0.0, abs(p.x + 0.15)) * s;
		COLOR = vec4(col, a);
	}
}
