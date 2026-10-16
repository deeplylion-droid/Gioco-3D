// Pozzanghera a specchio sul pavimento: acqua ferma, scurissima e liscia, così con i riflessi
// dello spazio schermo (SSR) ci si vede dentro la statua e le luci. Il contorno irregolare viene
// da un rumore (alpha scissor: resta "opaca", quindi riceve i riflessi), con qualche increspatura.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 colore : source_color = vec3(0.012, 0.014, 0.016);
uniform float soglia : hint_range(0.0, 1.0) = 0.5;
uniform float scala_bordo = 2.2;
uniform float seme = 0.0;
uniform float increspature = 0.025;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.07 + vec2(3.1, 1.7); a *= 0.5; }
	return v;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Forma: un'ellisse sfrangiata dal rumore, più larga al centro.
	float r = length(p);
	float n = fbm(UV * scala_bordo * 3.0 + seme);
	float forma = (1.0 - r) + (n - 0.5) * 0.9;
	ALPHA = forma;
	ALPHA_SCISSOR_THRESHOLD = soglia * 0.3;
	// Increspature leggerissime (gocce lontane), più ferme verso il centro.
	float t = TIME * 0.6;
	vec2 g = vec2(noise(UV * 40.0 + vec2(t, 0.0)) - 0.5, noise(UV * 40.0 + vec2(0.0, t) + 7.0) - 0.5);
	vec3 n_tan = normalize(vec3(g.x * increspature, 1.0, g.y * increspature));
	NORMAL = normalize((VIEW_MATRIX * vec4((MODEL_MATRIX * vec4(n_tan, 0.0)).xyz, 0.0)).xyz);
	ALBEDO = colore;
	ROUGHNESS = 0.01;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
