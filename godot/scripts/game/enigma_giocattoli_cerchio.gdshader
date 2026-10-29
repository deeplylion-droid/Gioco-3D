shader_type spatial;
// Segnaposto del cerchio di mosaico dell'enigma dei giocattoli (EnigmaGiocattoli), finché non c'è quello vero di
// ambienti-1 (assets/models/enigma_giocattoli/cerchio_mosaico.gdshader): tesserine del colore del cerchio, un bordo di
// piastrelle fosforescenti che si accende con bordo_acceso (0..1), più scuro e lucido da bagnato.

uniform vec4 colore : source_color = vec4(1.0, 0.82, 0.12, 1.0);
uniform float bordo_acceso : hint_range(0.0, 1.0) = 0.0;
uniform vec4 colore_bordo : source_color = vec4(0.62, 1.0, 0.45, 1.0);
uniform float energia_bordo = 2.5;
uniform float bagnato : hint_range(0.0, 1.0) = 0.0;
// raggio del disco (m) e larghezza del bordo (m)
uniform float raggio = 0.5;
uniform float larghezza_bordo = 0.06;

varying vec3 pos_locale;
varying vec3 normale_locale;

void vertex() {
	pos_locale = VERTEX;
	normale_locale = NORMAL;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = pos_locale.xz;
	float r = length(p);
	if (r > raggio) {
		discard;
	}
	// tesserine di 4 cm con le fughe
	vec2 cella = floor(p / 0.04);
	vec2 f = fract(p / 0.04);
	float fuga = step(0.12, f.x) * step(0.12, f.y) * step(f.x, 0.94) * step(f.y, 0.94);
	float variazione = 0.82 + 0.3 * hash(cella);
	vec3 tessera = colore.rgb * variazione;
	vec3 malta = vec3(0.32, 0.31, 0.28);
	float e_bordo = step(raggio - larghezza_bordo, r);
	// il bordo: piastrelle chiare (spente) che diventano fosforescenti
	vec3 bordo = mix(vec3(0.72, 0.74, 0.66), colore_bordo.rgb, bordo_acceso * 0.5);
	vec3 alb = mix(tessera, bordo * variazione, e_bordo);
	alb = mix(malta, alb, fuga);
	// i fianchi del disco (normale orizzontale): cemento
	float fianco = 1.0 - smoothstep(0.6, 0.9, abs(normale_locale.y));
	alb = mix(alb, vec3(0.42, 0.41, 0.38), fianco);
	ALBEDO = alb * mix(1.0, 0.6, bagnato);
	ROUGHNESS = mix(0.55, 0.12, bagnato) + (1.0 - fuga) * 0.3;
	EMISSION = colore_bordo.rgb * energia_bordo * bordo_acceso * e_bordo * fuga * (1.0 - fianco);
}
