// Cielo notturno in tempesta, visto attraverso la cupola: nuvole che scorrono,
// lampi che illuminano le nuvole dall'interno e il fulmine visibile.
// I parametri "lampo*" e "fulmine*" li muove il nodo Tempesta.
shader_type sky;
render_mode use_quarter_res_pass;

uniform vec3 colore_alto : source_color = vec3(0.075, 0.095, 0.15);
uniform vec3 colore_orizzonte : source_color = vec3(0.15, 0.17, 0.23);
uniform vec3 colore_lampo : source_color = vec3(0.72, 0.80, 1.0);
uniform float velocita_nuvole = 0.02;
uniform float lampo = 0.0;            // intensità del lampo in corso
uniform vec3 lampo_dir = vec3(0.0, 1.0, 0.0);
uniform float fulmine = 0.0;          // visibilità del fulmine (0..1)
uniform float fulmine_seme = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = max(d.y, 0.0);
	vec2 p = d.xz / (h + 0.12) * 2.2 + TIME * velocita_nuvole * vec2(1.0, 0.35);
	float n = fbm(p);
	float nuvole = smoothstep(0.25, 0.85, n);
	vec3 col = mix(colore_orizzonte, colore_alto, pow(h, 0.6));
	col *= 0.35 + 1.3 * nuvole;
	// Il lampo illumina le nuvole, di più vicino al punto del fulmine.
	float vicino = pow(max(dot(d, normalize(lampo_dir)), 0.0), 5.0);
	col += colore_lampo * lampo * (0.05 + 1.0 * vicino) * (0.25 + 1.2 * nuvole);
	// Il fulmine: una linea spezzata dal cielo verso l'orizzonte.
	if (fulmine > 0.0 && !AT_CUBEMAP_PASS) {
		vec3 ld = normalize(lampo_dir);
		float az = atan(d.x, d.z) - atan(ld.x, ld.z);
		az = mod(az + PI, TAU) - PI;
		float el = asin(clamp(d.y, -1.0, 1.0));
		float el_top = min(asin(clamp(ld.y, -1.0, 1.0)) + 0.45, 1.5);
		if (el < el_top && el > -0.05) {
			float t = el * 9.0 + fulmine_seme * 13.0;
			float zig = (fbm(vec2(t, fulmine_seme)) - 0.5) * 0.22 + (noise(vec2(el * 60.0, fulmine_seme * 3.0)) - 0.5) * 0.035;
			float x = az * cos(el) - zig;
			float sfuma = smoothstep(el_top, el_top - 0.08, el);
			float nucleo = exp(-abs(x) / 0.0035);
			float alone = exp(-abs(x) / 0.025) * 0.35;
			col += colore_lampo * (nucleo * 14.0 + alone) * fulmine * sfuma;
		}
	}
	COLOR = col;
}
