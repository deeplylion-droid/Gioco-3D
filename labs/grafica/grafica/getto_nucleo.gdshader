// Il nucleo del getto come acqua vera, non un nastro bianco. Vertici da RibbonArrays
// (nastro rivolto alla camera, illuminato come un cilindro): acqua lucida che rifrange quello che
// ha dietro, riflessi forti, turbolenza che scorre col getto; diventa bianca solo dove si sfalda
// (COLOR.a scende verso la fine del volo).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform sampler2D schermo : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec4 colore : source_color = vec4(0.72, 0.86, 0.95, 1.0);
uniform float rifrazione = 0.05;
uniform float turbolenza = 1.0;
// Quanto è bianco già all'uscita (0 = trasparente lucido, 1 = tutto schiuma).
uniform float bianco_base : hint_range(0.0, 1.0) = 0.12;
uniform float opacita : hint_range(0.0, 1.0) = 0.9;

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

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float l = UV.y;   // scorre con l'acqua (nascita del pezzetto)
	// Turbolenza: la superficie del getto si increspa e ondeggia.
	float t1 = noise(vec2(x * 2.0 + 7.0, l * 1.3 + TIME * 0.7));
	float t2 = noise(vec2(x * 5.0 - 3.0, l * 4.1 - TIME * 1.3));
	float turb = (t1 * 0.6 + t2 * 0.4 - 0.5) * turbolenza;
	float xr = clamp(x + turb * 0.35, -1.0, 1.0);
	vec3 side = normalize(TANGENT);
	vec3 n = normalize(side * xr + VIEW * sqrt(max(1.0 - xr * xr, 0.0)) + side * turb * 0.4);
	NORMAL = n;
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	// Dove si sfalda: schiuma bianca a chiazze.
	float vis = COLOR.a;
	float rotto = clamp(1.0 - vis, 0.0, 1.0);
	float chiazze = noise(vec2(x * 3.0, l * 6.0)) * 0.6 + noise(vec2(x * 9.0 + 4.0, l * 17.0)) * 0.4;
	float schiuma = clamp(smoothstep(0.6, 0.9, chiazze + rotto * 0.9 + bianco_base) + fres * 0.08, 0.0, 1.0);
	// Il centro rifrange lo sfondo (come un cilindro d'acqua), i bordi lo riflettono.
	vec2 off = (n.xy) * rifrazione * (1.0 - abs(xr));
	vec3 dietro = texture(schermo, SCREEN_UV + off).rgb;
	ALBEDO = mix(colore.rgb * 0.18, vec3(0.88, 0.93, 0.97), schiuma);
	EMISSION = dietro * colore.rgb * (1.0 - schiuma) * 0.9;
	ROUGHNESS = mix(0.02, 0.45, schiuma);
	SPECULAR = 1.0;
	METALLIC = 0.0;
	// Erosione alla fine del volo e alle estremità.
	float erosione = smoothstep(0.0, 0.2, chiazze - rotto * 1.05 + 0.1);
	float bordo = smoothstep(1.0, 0.8, abs(x));
	ALPHA = clamp(mix(opacita, 1.0, fres) * bordo * erosione * min(vis * 3.0, 1.0), 0.0, 1.0);
}
