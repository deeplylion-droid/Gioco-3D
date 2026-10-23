shader_type spatial;
// I denti in più del mostro-squalo (assets_src/mascotte/mostro_bocca.py, _dente_squalo): avorio sporco come i denti
// del modello, la punta più chiara, la base scura e rosata dentro la gengiva, e le file più dentro la bocca sempre
// più in ombra (UV.x: 0 davanti, 1 in gola), così si perdono nella gola invece di saltare fuori bianche sul nero.
// UV.y: 0 la base, 1 la punta. Lo sporco è un rumore fisso nello spazio dell'oggetto.

uniform vec3 base_gengiva : source_color = vec3(0.30, 0.10, 0.09);
uniform vec3 avorio : source_color = vec3(0.44, 0.37, 0.29);
uniform vec3 punta : source_color = vec3(0.62, 0.56, 0.46);

varying vec3 pos_oggetto;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float rumore(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	pos_oggetto = VERTEX;
}

void fragment() {
	float u = UV.y;
	vec3 c = mix(base_gengiva, avorio, smoothstep(0.0, 0.38, u));
	c = mix(c, punta, smoothstep(0.45, 1.0, u));
	// lo sporco: macchie scure lungo il dente, più fitte verso la base
	float sporco = rumore(pos_oggetto * 90.0) * 0.6 + rumore(pos_oggetto * 260.0) * 0.4;
	c *= mix(1.0, 0.72, smoothstep(0.45, 0.85, sporco) * (1.0 - 0.6 * u));
	// le file più dentro in ombra (occlusione)
	float ombra = mix(1.0, 0.42, clamp(UV.x, 0.0, 1.0));
	ALBEDO = c * ombra;
	AO = ombra;
	ROUGHNESS = mix(0.5, 0.3, u);
	SPECULAR = 0.45 * ombra;
}
