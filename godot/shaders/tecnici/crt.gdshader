shader_type spatial;
render_mode unshaded, cull_disabled;
// Schermo del vecchio monitor a tubo della sala pompe (tappa 6): l'immagine della telecamera
// della sala con righe, curvatura, rumore e la barra che scorre; con "neve" solo neve.

uniform sampler2D immagine : source_color, filter_linear, repeat_disable;
uniform float neve : hint_range(0.0, 1.0) = 0.0;
uniform float luminosita = 1.3;
uniform float accensione : hint_range(0.0, 1.0) = 1.0;
uniform vec3 tinta : source_color = vec3(0.82, 1.0, 0.94);
// Il raggio degli angoli tondi del vetro, in UV (0 = rettangolo): fuori non si disegna, e l'orlo si spegne.
uniform vec2 raggio_angoli = vec2(0.0);

float casuale(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 c = UV - 0.5;
	// Vetro curvo: l'immagine si gonfia un poco verso i bordi.
	vec2 uv = 0.5 + c * (1.0 + 0.1 * dot(c, c));
	float t = TIME;
	vec3 img = texture(immagine, uv).rgb;
	float grigio = dot(img, vec3(0.3, 0.59, 0.11));
	vec3 col = mix(vec3(grigio), img, 0.35) * tinta;
	float righe = 0.78 + 0.22 * sin(uv.y * 520.0);
	float barra = 0.88 + 0.12 * smoothstep(0.0, 0.1, abs(fract(uv.y * 0.6 - t * 0.11) - 0.5));
	float grana = casuale(floor(uv * vec2(320.0, 240.0)) + floor(t * 24.0)) - 0.5;
	col = col * righe * barra + grana * 0.07;
	// Neve: puntini che cambiano a ogni frame, con le righe del tubo.
	float n = casuale(floor(uv * vec2(240.0, 180.0)) + vec2(floor(t * 30.0) * 17.0, floor(t * 30.0) * 5.0));
	vec3 neve_col = vec3(n * n * 1.2) * (0.75 + 0.25 * sin(uv.y * 520.0));
	col = mix(col, neve_col, neve);
	// Angoli più scuri del tubo (ora lo schermo sta sul vetro bombato: basta una sfumatura).
	float bordo = smoothstep(0.76, 0.5, length(c * vec2(1.0, 1.25)));
	// Senza luci (unshaded): il colore è già la luce dello schermo, anche oltre 1 per il bagliore.
	float orlo = 1.0;
	if (raggio_angoli.x > 0.0) {
		vec2 q = abs(UV - 0.5) - (vec2(0.5) - raggio_angoli);
		float e = length(max(q, vec2(0.0)) / raggio_angoli);
		if (e > 1.0) {
			discard;
		}
		orlo = smoothstep(1.0, 0.8, e);
	}
	ALBEDO = max(col, vec3(0.0)) * luminosita * bordo * orlo * accensione;
}
