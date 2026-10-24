shader_type spatial;
render_mode unshaded, cull_back;
// Il vetro degli oblò grandi dell'abisso (tunnel sottomarino, ambienti-1): il mare profondo finto dietro il vetro.
// Scelta A (animato = true): una sagoma di pesce grande e lontana passa piano e salgono poche bollicine.
// Scelta B (animato = false): mare scuro fermo, con i puntini del plancton.
// Le coordinate sul disco vengono dalla posizione locale (il disco è il tappo di un CylinderMesh, sul piano xz), non
// dalle UV del cilindro: (0,5; 0,5) al centro, y in giù.

uniform bool animato = true;
uniform vec3 blu_alto : source_color = vec3(0.06, 0.16, 0.32);
uniform vec3 blu_basso : source_color = vec3(0.005, 0.02, 0.06);
uniform float luce = 1.6;
// lo sfasamento di ogni oblò (così i pesci non passano tutti insieme)
uniform float fase = 0.0;
uniform float raggio = 0.78;

varying vec2 sul_disco;

void vertex() {
	sul_disco = VERTEX.xz / (2.0 * raggio) + 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// la sagoma di un pesce (corpo ovale e coda), in coordinate del pesce: 1 dentro, 0 fuori, bordo morbido
float pesce(vec2 q) {
	float corpo = length(q / vec2(0.22, 0.08));
	vec2 c = q - vec2(-0.25, 0.0);
	float coda = max(abs(c.y) - (-c.x) * 0.9, max(c.x, -c.x - 0.12));
	return max(1.0 - smoothstep(0.9, 1.1, corpo), 1.0 - smoothstep(-0.01, 0.01, coda));
}

void fragment() {
	vec2 uv = sul_disco;
	vec3 col = mix(blu_alto, blu_basso, smoothstep(0.0, 1.0, uv.y));
	// un raggio di luce dall'alto, appena
	col += vec3(0.02, 0.05, 0.08) * smoothstep(0.5, 0.0, abs(uv.x - 0.4 - uv.y * 0.15)) * (1.0 - uv.y);
	// il plancton: puntini fermi (B) o che brillano piano (A)
	vec2 g = floor(uv * 46.0);
	float h = hash(g + fase * 7.0);
	float stella = step(0.965, h) * smoothstep(0.35, 0.0, length(fract(uv * 46.0) - 0.5));
	float brillo = animato ? 0.6 + 0.4 * sin(TIME * (0.6 + h * 1.4) + h * 40.0) : 1.0;
	col += vec3(0.35, 0.6, 0.75) * stella * brillo * 0.6;
	if (animato) {
		// il pesce lontano: passa da sinistra a destra in circa 26 s, poi un'attesa
		float t = mod(TIME + fase * 13.0, 38.0) / 26.0;
		if (t < 1.0) {
			vec2 q = (uv - vec2(mix(-0.4, 1.4, t), 0.42 + 0.05 * sin(t * 6.0 + fase))) / 0.9;
			q.y += 0.015 * sin(q.x * 18.0 + TIME * 3.0);
			col = mix(col, blu_basso * 0.4, pesce(q) * 0.85);
		}
		// le bollicine che salgono
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float x = 0.2 + 0.6 * hash(vec2(fi, fase));
			float y = 1.0 - mod(TIME * (0.05 + 0.03 * hash(vec2(fi, 2.0))) + hash(vec2(fi, 3.0)) + fase, 1.2);
			float b = smoothstep(0.012, 0.006, length(uv - vec2(x + 0.01 * sin(TIME + fi), y)));
			col += vec3(0.4, 0.6, 0.7) * b * 0.5;
		}
	}
	ALBEDO = col * luce;
}
