// Il geyser della fossa (GeyserFossa): la colonna d'acqua che si alza intorno a lei quando sparisce.
// Scelta dell'utente del 17 ottobre (A, geyser): "L'acqua non deve essere trasparente, altrimenti si
// vede lo stesso lei scomparire." Quindi acqua piena, bianca di schiuma, mossa, coprente fino a
// [code]coprente[/code] della sua altezza; sopra si sfalda in brandelli.
// La mesh e' una griglia cilindrica (UV.x intorno, UV.y dal pavimento in su); la forma la fa il vertex
// shader: al piede si allarga (l'acqua che trabocca dal bordo e copre i tentacoli sul pavimento),
// poi si stringe salendo e in cima si apre a fungo. crollo 0..1: l'acqua ricade e si apre in buchi.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

uniform float altezza = 4.0;
uniform float raggio = 1.3;
// Di quanto si allarga al piede (moltiplica il raggio) e fin dove (frazione dell'altezza).
uniform float piede = 1.45;
uniform float piede_alto = 0.1;
// Fin dove e' piena (frazione dell'altezza): sopra si sfalda.
uniform float coprente = 0.8;
uniform float crollo = 0.0;
uniform float seme = 0.0;

varying float v_su;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	float a = UV.x * TAU;
	float v = UV.y;
	// Il bordo dell'acqua ribolle (il rumore usa l'angolo in modo periodico: la griglia si chiude).
	vec2 giro = vec2(cos(a), sin(a)) * 1.6;
	float n = noise(giro + vec2(seme, v * 3.0 - TIME * 2.5)) - 0.5;
	float allarga = mix(piede, 1.0, smoothstep(0.0, piede_alto, v));
	float r = raggio * allarga * (1.0 - 0.4 * v + 0.9 * smoothstep(0.75, 1.0, v)) * (1.0 + 0.25 * n);
	float y = altezza * v;
	// Ricade: la cima scende piu' in fretta della base e l'acqua si apre verso fuori.
	y = mix(y, y * 0.15, crollo * crollo);
	r *= 1.0 + crollo * (0.6 + 0.8 * v);
	VERTEX = vec3(cos(a) * r, y, sin(a) * r);
	NORMAL = normalize(vec3(cos(a), 0.3, sin(a)));
	v_su = v;
}

void fragment() {
	float v = v_su;
	// Getti a strisce che salgono veloci, con creste di schiuma e solchi d'acqua piu' scura.
	float giro = UV.x * 24.0;
	float s1 = noise(vec2(giro, v * 2.4 - TIME * 5.0 + seme));
	float s2 = noise(vec2(giro * 2.6 + 3.0, v * 5.5 - TIME * 8.0));
	float s3 = noise(vec2(UV.x * 80.0, v * 14.0 - TIME * 11.0));
	float lame = s1 * 0.55 + s2 * 0.3 + s3 * 0.15;
	// Superficie mossa: la normale segue i getti, le luci ci fanno riflessi lunghi.
	NORMAL = normalize(NORMAL + vec3((s2 - 0.5) * 0.9, (s1 - 0.5) * 0.5, 0.0) + vec3((s3 - 0.5) * 0.35));
	// Schiuma a strisce con solchi d'acqua piu' scura e grana fine: si legge come acqua che corre,
	// non come un tronco liscio.
	float grana = noise(vec2(UV.x * 160.0, v * 40.0 - TIME * 14.0));
	float schiuma = clamp(0.3 + smoothstep(0.3, 0.75, lame) * 0.6 + (grana - 0.5) * 0.35
			+ (1.0 - smoothstep(0.0, 0.2, v)) * 0.3, 0.0, 1.0);
	ALBEDO = mix(vec3(0.16, 0.22, 0.26), vec3(0.9, 0.93, 0.96), schiuma);
	// Un filo di luce propria: al buio la schiuma resta bianca e non diventa un muro grigio.
	EMISSION = vec3(0.05, 0.06, 0.07) * schiuma;
	ROUGHNESS = mix(0.03, 0.45, schiuma);
	SPECULAR = 0.9;
	// Piena fino a "coprente"; sopra si strappa in brandelli; col crollo si aprono buchi.
	float cima = 1.0 - smoothstep(coprente, 1.0, v + (lame - 0.5) * 0.35 * smoothstep(coprente - 0.1, coprente, v));
	float buchi = smoothstep(crollo * 1.15 - 0.05, crollo * 1.15 + 0.1, lame * 0.8 + (1.0 - v) * 0.35);
	ALPHA = clamp(cima * buchi, 0.0, 1.0);
}
