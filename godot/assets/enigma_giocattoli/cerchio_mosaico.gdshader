shader_type spatial;
// Cerchio a mosaico sul fondo della piscina a onde (enigma "I giocattoli al loro posto", 28 ottobre).
// Su un piano di 1,1 m (PlaneMesh, UV 0-1, centro in mezzo): un disco di tessere da 2,5 cm del colore
// del giocattolo (diametro 0,9 m), un anello di tessere fosforescenti (fino a 1,04 m) e fuori niente
// (discard). La luce del bordo va da 0 (spento: tessere color crema) a 1 (appena acceso, verdino).
// Sporco e bagnato come il fondo della piscina vuota.

uniform vec3 colore : source_color = vec3(0.86, 0.68, 0.12);
// Quanto è acceso il bordo fosforescente: 0 spento, 1 appena acceso.
uniform float luce_bordo : hint_range(0.0, 1.0) = 0.0;
// Energia dell'emissione a luce_bordo = 1 (appena acceso, non una lampada).
uniform float energia_bordo = 1.2;
uniform vec3 colore_luce : source_color = vec3(0.55, 1.0, 0.62);
uniform float sporco : hint_range(0.0, 1.0) = 0.55;
uniform float bagnato : hint_range(0.0, 1.0) = 0.0;

const float LATO = 1.1;        // metri del piano
const float R_DISCO = 0.45;
const float R_BORDO = 0.52;
const float TESSERA = 0.025;
const float FUGA = 0.0022;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float rumore(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { return rumore(p) * 0.5 + rumore(p * 2.03) * 0.25 + rumore(p * 4.1) * 0.125 + rumore(p * 8.3) * 0.0625; }

void fragment() {
	vec2 p = (UV - 0.5) * LATO;          // metri, centro in mezzo
	float r = length(p);
	if (r > R_BORDO) discard;
	vec3 base;
	vec2 cella;      // id della tessera
	vec2 dist;       // distanza dal bordo della tessera (m), per la fuga e lo smusso
	float fosforo = 0.0;
	if (r < R_DISCO - FUGA) {
		vec2 q = p / TESSERA + 0.5;
		cella = floor(q);
		vec2 f = fract(q) - 0.5;
		dist = (0.5 - abs(f)) * TESSERA;
		// le tessere tagliate dal cerchio: la fuga segue il cerchio
		dist.x = min(dist.x, R_DISCO - FUGA - r);
		base = colore;
	} else if (r > R_DISCO + FUGA * 0.5) {
		// anello: tessere disposte in giro (opus vermiculatum), larghe una tessera
		float a = atan(p.y, p.x);
		float rm = (R_DISCO + R_BORDO) * 0.5;
		float n = floor(6.2831853 * rm / TESSERA);
		float u = (a / 6.2831853 + 0.5) * n;
		float k = floor(u);
		float fr = fract(u) - 0.5;
		float fila = floor((r - R_DISCO) / ((R_BORDO - R_DISCO) / 2.0));   // due file
		float fv = fract((r - R_DISCO) / ((R_BORDO - R_DISCO) / 2.0)) - 0.5;
		k = floor(u + fila * 0.5);
		fr = fract(u + fila * 0.5) - 0.5;
		cella = vec2(k, fila + 100.0);
		dist = vec2((0.5 - abs(fr)) * 6.2831853 * r / n, (0.5 - abs(fv)) * (R_BORDO - R_DISCO) / 2.0);
		dist.y = min(dist.y, R_BORDO - r);
		base = vec3(0.86, 0.87, 0.78);
		fosforo = 1.0;
	} else {
		cella = vec2(-1.0);
		dist = vec2(0.0);
		base = colore;
	}
	float h = h21(cella);
	// tessere di vetro colorato: un po' diverse fra loro, scolorite
	vec3 tes = base * (0.82 + 0.3 * h) * mix(vec3(1.0), vec3(0.97, 1.0, 1.03), h21(cella + 7.0));
	tes = mix(tes, vec3(dot(tes, vec3(0.33))), 0.12);   // scolorito
	float m = min(dist.x, dist.y);
	float in_fuga = 1.0 - smoothstep(FUGA * 0.5, FUGA, m);
	vec3 fuga = vec3(0.42, 0.41, 0.37);
	// sporco: chiazze e fughe annerite
	float s = fbm(p * 6.0) * 0.7 + fbm(p * 23.0) * 0.3;
	float macchia = smoothstep(0.45, 0.85, s) * sporco;
	vec3 col = mix(tes, fuga, in_fuga);
	col *= 1.0 - macchia * 0.45;
	col = mix(col, col * vec3(0.78, 0.74, 0.62), in_fuga * sporco);
	// bagnato: più scuro e lucido
	col *= 1.0 - bagnato * 0.25;
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.32, 0.9, in_fuga) + macchia * 0.3, 0.08, bagnato * (1.0 - in_fuga * 0.5));
	METALLIC = 0.0;
	SPECULAR = 0.5;
	// fosforo: solo le tessere dell'anello, non le fughe, un po' diverso fra tessera e tessera
	EMISSION = colore_luce * fosforo * (1.0 - in_fuga) * luce_bordo * energia_bordo * (0.75 + 0.5 * h) * (1.0 - macchia * 0.6);
}
