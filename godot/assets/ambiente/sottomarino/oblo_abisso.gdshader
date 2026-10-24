shader_type spatial;
render_mode unshaded, cull_back;
// Il vetro degli oblò grandi dell'abisso (tunnel sottomarino, ambienti-1, scelta 2A dell'utente): il mare profondo
// finto dietro il vetro. Gli strati stanno "fuori", a qualche metro dietro il vetro: si guardano col raggio dalla
// camera attraverso il vetro (parallasse vera), così spostandosi si vedono scorrere come dietro una finestra e non
// sembrano un adesivo. Una sagoma di pesce grande e lontana passa lenta, poche bollicine salgono, il plancton brilla.
// animato = false: tutto fermo (scelta B, scartata).
// Il disco è il tappo di un CylinderMesh (piano xz locale, +y verso la stanza).

uniform bool animato = true;
uniform vec3 blu_alto : source_color = vec3(0.05, 0.14, 0.28);
uniform vec3 blu_basso : source_color = vec3(0.004, 0.015, 0.05);
uniform float luce = 1.6;
// lo sfasamento di ogni oblò (così il pesce non passa da tutti insieme)
uniform float fase = 0.0;

varying vec3 punto;
varying vec3 occhio;

void vertex() {
	punto = VERTEX;
	occhio = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// dove il raggio dalla camera, passato dal vetro, arriva a [d] metri dietro (coordinate in metri sul piano del vetro:
// x a destra, y in su)
vec2 dietro(float d) {
	vec3 v = punto - occhio;
	vec3 q = punto + v * (d / max(occhio.y, 0.05));
	return vec2(q.x, -q.z);
}

// la sagoma di un pesce lungo 1 (testa verso +x): 1 dentro, 0 fuori, bordo sfumato dall'acqua
float pesce(vec2 q, float sfuma) {
	float corpo = length(q / vec2(0.5, 0.17));
	vec2 c = q - vec2(-0.5, 0.0);
	float coda = max(abs(c.y) - (-c.x) * 1.1, max(c.x, -c.x - 0.22));
	float pinna = length((q - vec2(0.02, 0.15)) / vec2(0.14, 0.07));
	float f = 1.0 - smoothstep(1.0 - sfuma, 1.0 + sfuma, min(corpo, pinna));
	return max(f, 1.0 - smoothstep(-0.03, 0.03, coda));
}

void fragment() {
	// il fondo: più chiaro in alto, verso la superficie lontana (a 12 m)
	vec2 f = dietro(12.0);
	vec3 col = mix(blu_basso, blu_alto, smoothstep(-6.0, 5.0, f.y));
	col += vec3(0.015, 0.04, 0.06) * smoothstep(2.5, 0.0, abs(f.x * 0.5 + 1.0 - f.y * 0.25)) * smoothstep(-4.0, 5.0, f.y);
	// il pesce grande e lontano (a 7 m, lungo 3 m): passa in circa 40 s, poi un'attesa; velato dall'acqua
	if (animato) {
		float t = mod(TIME + fase * 31.0, 64.0) / 40.0;
		if (t < 1.0) {
			vec2 p = dietro(7.0);
			vec2 centro = vec2(mix(-9.0, 9.0, t), 0.6 + 0.4 * sin(t * 5.0 + fase * 3.0));
			vec2 q = (p - centro) / 3.0;
			q.y += 0.02 * sin(q.x * 9.0 + TIME * 1.6);
			col = mix(col, blu_basso * 0.55, pesce(q, 0.12) * 0.7);
		}
	}
	// il plancton, a 3 m: puntini piccoli che brillano piano
	vec2 pl = dietro(3.0) * 6.0;
	vec2 g = floor(pl);
	float h = hash(g + fase * 7.0);
	float stella = step(0.93, h) * smoothstep(0.3, 0.0, length(fract(pl) - 0.5));
	float brillo = animato ? 0.55 + 0.45 * sin(TIME * (0.4 + h) + h * 40.0) : 1.0;
	col += vec3(0.3, 0.55, 0.7) * stella * brillo * 0.45;
	// le bollicine, a 1,5 m: salgono piano
	if (animato) {
		vec2 b = dietro(1.5);
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float x = -0.6 + 1.2 * hash(vec2(fi, fase));
			float y = mod(TIME * (0.12 + 0.08 * hash(vec2(fi, 2.0))) + hash(vec2(fi, 3.0)) * 3.0 + fase, 3.0) - 1.5;
			float r = 0.012 + 0.01 * hash(vec2(fi, 4.0));
			float d = length(b - vec2(x + 0.04 * sin(TIME * 0.8 + fi * 2.0), y));
			col += vec3(0.35, 0.55, 0.65) * (smoothstep(r, r * 0.6, d) - smoothstep(r * 0.6, r * 0.2, d) * 0.6) * 0.5;
		}
	}
	ALBEDO = col * luce;
}
