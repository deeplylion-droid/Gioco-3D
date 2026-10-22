shader_type canvas_item;
// Lo spot della crociera Jubilee (GDD, "Lo spot della crociera Jubilee"): il nastro VHS visto su un televisore a tubo.
// Parte dallo schermo del monitor della sala pompe (shaders/tecnici/crt.gdshader). Va bene su due cose:
//  - su un video (VideoStreamPlayer) o un'immagine (TextureRect): il materiale sul nodo, dallo_schermo spento;
//  - sopra una camera: un ColorRect a tutto schermo in un CanvasLayer, dallo_schermo acceso (legge lo schermo).
// "guasto" (0-1) è il nastro che si rovina (inquadratura 7): tracking che salta, colori che colano, righe strappate,
// l'immagine che scorre. "schermo_blu" è il blu del videoregistratore senza segnale (inquadratura 1), "play" la scritta.

uniform bool dallo_schermo = false;
uniform sampler2D schermo : hint_screen_texture, filter_linear_mipmap, repeat_disable;

group_uniforms tubo;
uniform float curvatura : hint_range(0.0, 0.5) = 0.18;     // il vetro bombato
uniform float vignetta : hint_range(0.0, 2.0) = 0.9;
uniform float righe = 240.0;                                // le righe del tubo sullo schermo
uniform float forza_righe : hint_range(0.0, 1.0) = 0.32;
uniform float bagliore : hint_range(0.0, 1.0) = 0.25;       // un poco di alone attorno alle cose chiare
uniform float luminosita = 1.12;

group_uniforms nastro;
uniform float sbavatura : hint_range(0.0, 0.03) = 0.006;    // il colore del VHS è largo e sfocato in orizzontale
uniform float separazione : hint_range(0.0, 0.02) = 0.0025; // rosso e blu sfasati
uniform float saturazione : hint_range(0.0, 2.0) = 1.15;
uniform float rumore : hint_range(0.0, 1.0) = 0.12;
uniform float tremolio : hint_range(0.0, 1.0) = 0.25;       // le righe che tremano in orizzontale
uniform float tracking : hint_range(0.0, 1.0) = 0.15;       // la banda del tracking che passa
uniform float testine : hint_range(0.0, 1.0) = 1.0;         // il cambio testine, in fondo allo schermo
uniform float guasto : hint_range(0.0, 1.0) = 0.0;

group_uniforms videoregistratore;
uniform float schermo_blu : hint_range(0.0, 1.0) = 0.0;
uniform vec3 blu : source_color = vec3(0.05, 0.16, 0.78);
uniform float play : hint_range(0.0, 1.0) = 0.0;            // la scritta PLAY in alto a sinistra
uniform vec3 colore_play : source_color = vec3(0.92, 0.95, 0.9);
uniform vec2 posizione_play = vec2(0.075, 0.09);
uniform float dimensione_play = 0.045;                       // altezza della scritta (frazione dello schermo)
uniform float tempo_spostato = 0.0;                          // per far ripartire o fermare il tempo dal montaggio

float casuale(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float rumore1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(casuale(vec2(i, 0.3)), casuale(vec2(i + 1.0, 0.3)), f * f * (3.0 - 2.0 * f));
}

vec3 leggi(sampler2D tex, vec2 uv) {
	if (dallo_schermo) {
		return textureLod(schermo, uv, 0.0).rgb;
	}
	return texture(tex, uv).rgb;
}

vec3 in_yiq(vec3 c) {
	return vec3(dot(c, vec3(0.299, 0.587, 0.114)), dot(c, vec3(0.596, -0.274, -0.322)), dot(c, vec3(0.211, -0.523, 0.312)));
}

vec3 da_yiq(vec3 y) {
	return vec3(y.x + 0.956 * y.y + 0.621 * y.z, y.x - 0.272 * y.y - 0.647 * y.z, y.x - 1.106 * y.y + 1.703 * y.z);
}

// La scritta PLAY e il triangolo, a quadretti 5x7 come sui videoregistratori: righe dall'alto, 5 bit per riga (il bit 4
// a sinistra). Nell'ordine: P, L, A, Y, il triangolo del play.
const int GLIFI[35] = int[35](
	30, 17, 17, 30, 16, 16, 16,
	16, 16, 16, 16, 16, 16, 31,
	14, 17, 17, 31, 17, 17, 17,
	17, 17, 10, 4, 4, 4, 4,
	16, 24, 28, 30, 28, 24, 16);

float glifo(int g, ivec2 p) {
	if (p.x < 0 || p.x > 4 || p.y < 0 || p.y > 6) {
		return 0.0;
	}
	return float((GLIFI[g * 7 + p.y] >> (4 - p.x)) & 1);
}

float scritta_play(vec2 uv, float aspetto) {
	// in quadretti: altezza 7 quadretti = dimensione_play; i quadretti sono quadrati sullo schermo
	float q = dimensione_play / 7.0;
	vec2 p = (uv - posizione_play) / vec2(q / aspetto, q);
	if (p.y < 0.0 || p.y >= 7.0 || p.x < 0.0) {
		return 0.0;
	}
	// triangolo, spazio, P L A Y: 6 quadretti per lettera
	int cella = int(floor(p.x / 6.0));
	int g = cella == 0 ? 4 : cella - 2;
	if (cella == 1 || cella > 5) {
		return 0.0;
	}
	ivec2 pi = ivec2(int(floor(mod(p.x, 6.0))), int(floor(p.y)));
	return glifo(g, pi);
}

void fragment() {
	float t = TIME + tempo_spostato;
	vec2 base = dallo_schermo ? SCREEN_UV : UV;
	float aspetto = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	if (!dallo_schermo) {
		aspetto = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
	}
	float g = guasto;
	// il vetro bombato
	vec2 c = base - 0.5;
	vec2 uv = 0.5 + c * (1.0 + curvatura * dot(c * vec2(1.0, 0.85), c * vec2(1.0, 0.85)));
	float fuori = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);

	// il nastro: l'immagine che scorre in verticale col guasto (rolling), e salta ogni tanto
	float salto = step(1.0 - 0.06 * g, casuale(vec2(floor(t * 8.0), 7.0))) * (casuale(vec2(floor(t * 8.0), 3.0)) - 0.5) * 0.2;
	float scorre = g * g * (t * 0.35 + rumore1(t * 0.7) * 0.4);
	vec2 nastro = vec2(uv.x, fract(uv.y + scorre + salto * g));
	float riga = floor(nastro.y * righe * 2.0);
	// righe che tremano (errore della base dei tempi)
	float trema = (casuale(vec2(riga, floor(t * 30.0))) - 0.5) * 0.0016 * tremolio * (1.0 + 4.0 * g);
	// la banda del tracking: scende piano lungo lo schermo, spinge le righe di lato e porta rumore
	float y_banda = fract(t * (0.06 + 0.25 * g) + 0.37);
	float banda = smoothstep(0.06 + 0.12 * g, 0.0, abs(nastro.y - y_banda)) * (tracking + 1.5 * g);
	float spinta = banda * (rumore1(nastro.y * 90.0 + t * 25.0) - 0.4) * 0.05;
	// il cambio testine: le ultime righe in fondo, storte e piene di rumore
	float testina = smoothstep(0.955, 0.985, nastro.y) * testine;
	spinta += testina * (0.02 + 0.03 * rumore1(nastro.y * 300.0 + t * 40.0));
	// strappi orizzontali col guasto: interi blocchi di righe spostati
	float blocco = floor(nastro.y * 18.0);
	float strappo = step(1.0 - 0.35 * g, casuale(vec2(blocco, floor(t * 12.0)))) * (casuale(vec2(blocco, floor(t * 12.0) + 1.0)) - 0.5) * 0.12 * g;
	float dx = trema + spinta + strappo;

	// luminanza nitida, colore largo e spostato (il VHS ha poca banda per il colore)
	vec2 p = vec2(nastro.x + dx, nastro.y);
	float largo = sbavatura * (1.0 + 3.0 * g);
	float sep = separazione * (1.0 + 6.0 * g) + banda * 0.006;
	float Y = in_yiq(leggi(TEXTURE, p)).x * 0.6 + in_yiq(leggi(TEXTURE, p - vec2(0.0012, 0.0))).x * 0.2 + in_yiq(leggi(TEXTURE, p + vec2(0.0012, 0.0))).x * 0.2;
	vec2 iq = vec2(0.0);
	for (int k = 0; k < 7; k++) {
		float o = (float(k) - 2.0) / 4.0 * largo;   // la sbavatura va più a destra che a sinistra
		iq += in_yiq(leggi(TEXTURE, p + vec2(o + largo * 0.5, 0.0))).yz;
	}
	iq /= 7.0;
	vec3 col = da_yiq(vec3(Y, iq * saturazione * (1.0 - 0.45 * g)));
	// rosso e blu sfasati
	col.r = mix(col.r, da_yiq(vec3(in_yiq(leggi(TEXTURE, p + vec2(sep, 0.0))).x, iq)).r, 0.6);
	col.b = mix(col.b, da_yiq(vec3(in_yiq(leggi(TEXTURE, p - vec2(sep, 0.0))).x, iq)).b, 0.6);
	// un poco di alone attorno alle cose chiare
	vec3 alone = (leggi(TEXTURE, p + vec2(0.004, 0.0)) + leggi(TEXTURE, p - vec2(0.004, 0.0)) + leggi(TEXTURE, p + vec2(0.0, 0.004)) + leggi(TEXTURE, p - vec2(0.0, 0.004))) * 0.25;
	col += max(alone - 0.55, vec3(0.0)) * bagliore * 1.6;

	// lo schermo blu del videoregistratore
	col = mix(col, blu * (0.95 + 0.05 * sin(nastro.y * 3.0 + t)), schermo_blu);

	// rumore: grana, puntini bianchi (dropout) e la neve del tracking
	float grana = casuale(floor(nastro * vec2(640.0, righe * 2.0)) + floor(t * 30.0) * 1.7) - 0.5;
	col += grana * (rumore * 0.12 + banda * 0.25 + testina * 0.3 + g * 0.12);
	float dropout = step(0.9985 - 0.004 * g - banda * 0.01, casuale(vec2(riga, floor(t * 30.0) + floor(nastro.x * 12.0) * 0.01)));
	col = mix(col, vec3(0.9), dropout * step(0.5, rumore1(nastro.x * 40.0 + riga)));
	// col guasto il colore si perde e l'immagine trema di luminosità
	col *= 1.0 - g * 0.25 * rumore1(t * 18.0);

	// la scritta PLAY (lampeggia piano, come sul videoregistratore, e prende anche lei il tremolio)
	float s = scritta_play(vec2(base.x + trema * 0.5, base.y), aspetto) * play;
	col = mix(col, colore_play, s);

	// le righe del tubo e la vignetta
	float linee = 1.0 - forza_righe * (0.5 + 0.5 * sin(uv.y * righe * 6.2831853));
	col *= linee;
	float v = 1.0 - vignetta * pow(length(c * vec2(1.0, 1.15)), 2.4) * 1.3;
	col *= clamp(v, 0.0, 1.0);
	// il bordo del tubo: fuori nero, l'orlo appena sfumato
	float orlo = smoothstep(0.0, 0.012, uv.x) * smoothstep(1.0, 0.988, uv.x) * smoothstep(0.0, 0.012, uv.y) * smoothstep(1.0, 0.988, uv.y);
	COLOR = vec4(max(col, vec3(0.0)) * luminosita * orlo * fuori, 1.0);
}
