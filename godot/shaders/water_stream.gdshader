// Getto d'acqua (e aspirazione) disegnato come nastro rivolto alla camera: qui il nastro
// viene illuminato come se fosse un cilindro d'acqua, con striature che scorrono, bordi più
// opachi (Fresnel) e la fine che si sfalda in gocce. Vertici da RibbonArrays.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(0.78, 0.9, 1.0, 1.0);
uniform float opacity_center : hint_range(0.0, 1.0) = 0.42;
uniform float opacity_edge : hint_range(0.0, 1.0) = 0.9;
// Striature: quante per metro lungo il getto e quanto si vedono.
uniform float streak_density = 1.6;
uniform float streak_strength : hint_range(0.0, 1.0) = 0.45;
// Scorrimento delle striature (m/s): per l'aspirazione, che è una curva ferma.
uniform float flow_speed = 0.0;
uniform float emission_strength = 0.05;
uniform float rim_emission = 0.22;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float l = UV.y - TIME * flow_speed;
	// Normale del cilindro ricostruita dal nastro piatto.
	vec3 side = normalize(TANGENT);
	vec3 n = normalize(side * x + VIEW * sqrt(max(1.0 - x * x, 0.0)));
	NORMAL = n;
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.5);
	// Striature lunghe nel senso del getto, più fitte di traverso.
	float s1 = noise(vec2(x * 2.5 + 3.0, l * streak_density));
	float s2 = noise(vec2(x * 6.0 - 11.0, l * streak_density * 3.1 + 5.0));
	float streak = mix(s1, s2, 0.4);
	// Verso la fine il getto si sfalda: la visibilità (COLOR.a) mangia il nastro a chiazze.
	float vis = COLOR.a;
	float blobs = noise(vec2(x * 3.0, l * 7.0)) * 0.7 + noise(vec2(x * 7.0 + 2.0, l * 19.0)) * 0.3;
	float erosion = smoothstep(0.0, 0.18, blobs - (1.0 - vis) * 1.05);
	float edge = smoothstep(1.0, 0.72, abs(x));
	ALBEDO = color.rgb * (0.55 + 0.25 * streak);
	ROUGHNESS = 0.05 + 0.1 * streak;
	SPECULAR = 0.85;
	METALLIC = 0.0;
	EMISSION = color.rgb * (emission_strength + rim_emission * fres) * (0.6 + 0.6 * streak);
	ALPHA = clamp(mix(opacity_center, opacity_edge, fres) * (1.0 - streak_strength * 0.5 + streak_strength * streak), 0.0, 1.0)
		* erosion * edge * min(vis * 3.0, 1.0);
}
