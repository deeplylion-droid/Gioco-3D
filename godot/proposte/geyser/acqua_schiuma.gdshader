shader_type spatial;
// L'acqua del geyser V1: bianca e piena d'aria (non trasparente), ma bagnata e lucida: riflessi netti dove è liscia,
// chiazze di schiuma più opache, striature verticali che corrono verso l'alto col getto e un rilievo fine nelle
// normali (prova del coordinatore: "sembra panna montata", "niente retino"). Un fotogramma della simulazione alla
// volta, senza dissolvenze retinate.
render_mode cull_back, depth_draw_opaque;

uniform sampler2D rumore : filter_linear_mipmap, repeat_enable;
uniform float tempo = 0.0;
uniform vec3 schiuma : source_color = vec3(0.88, 0.91, 0.93);
uniform vec3 acqua : source_color = vec3(0.6, 0.68, 0.73);
// la base del geyser (come nella simulazione): l'acqua ferma della fossa e quella stesa a terra le fa il gioco,
// qui si tiene solo quella che sale e ricade
uniform vec3 centro = vec3(0.0);
uniform float z_acqua = 0.85;
uniform float z_pavimento = 0.55;
uniform float r_fossa = 1.35;
uniform float rilievo = 0.35;
// alla fine l'acqua ricaduta affonda nella fossa e nel pavimento: la soglia sotto cui non si disegna sale (m)
uniform float affonda = 0.0;

varying vec3 mondo;
varying vec3 normale_mondo;

float tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(rumore, p.yz).r * w.x + texture(rumore, p.xz).r * w.y + texture(rumore, p.xy).r * w.z;
}

// striature: rumore stirato in verticale che sale; più grumi fini sopra
float superficie(vec3 p, vec3 n) {
	vec3 s = vec3(p.x * 2.6, p.y * 0.45 - tempo * 1.6, p.z * 2.6);
	float strie = tri(s, n);
	float fine = tri(p * 5.0 + vec3(0.0, -tempo * 2.5, 0.0), n);
	return strie * 0.7 + fine * 0.3;
}

void vertex() {
	mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_mondo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float rr = length(mondo.xz - centro.xz);
	float h = mondo.y - centro.y;
	if (h < (rr < r_fossa ? z_acqua + 0.06 : z_pavimento + 0.16) + affonda) {
		discard;
	}
	vec3 n = normalize(normale_mondo);
	float a = superficie(mondo, n);
	// il rilievo: gradiente del rumore nel mondo, solo la parte tangente alla superficie
	float e = 0.03;
	vec3 g = vec3(superficie(mondo + vec3(e, 0, 0), n), superficie(mondo + vec3(0, e, 0), n), superficie(mondo + vec3(0, 0, e), n)) - a;
	g /= e;
	g -= n * dot(g, n);
	vec3 nm = normalize(n - g * rilievo * 0.05);
	NORMAL = normalize((VIEW_MATRIX * vec4(nm, 0.0)).xyz);
	// schiuma a chiazze (più bianca, opaca) e acqua liscia (un filo grigio-azzurra, lucidissima)
	float chiazze = smoothstep(0.45, 0.7, tri(mondo * 1.3 + vec3(0.0, -tempo * 1.2, 0.0), n));
	float strie = smoothstep(0.35, 0.75, a);
	ALBEDO = mix(acqua, schiuma, clamp(0.3 + chiazze * 0.5 + strie * 0.25, 0.0, 1.0));
	ROUGHNESS = mix(0.05, 0.42, chiazze);
	SPECULAR = 0.6;
	CLEARCOAT = 0.7 * (1.0 - chiazze);
	CLEARCOAT_ROUGHNESS = 0.08;
	// la luce che passa dai bordi sottili (piena d'aria: solo un filo, verso il bianco)
	BACKLIGHT = vec3(0.3, 0.34, 0.36);
	RIM = 0.2;
	RIM_TINT = 0.6;
}
