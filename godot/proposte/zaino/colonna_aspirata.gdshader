// PROPOSTA zaino: la colonna d'acqua aspirata, un tubo 3D che si torce dalla superficie all'ugello.
// UV.x gira intorno al tubo (0..1), UV.y va dalla superficie (0) all'ugello (1).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform sampler2D schermo : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec4 colore : source_color = vec4(0.7, 0.85, 0.92, 1.0);
uniform float torsione = 5.0;     // giri della spirale lungo la colonna
uniform float velocita = 3.5;     // quanto in fretta sale l'acqua
uniform float rifrazione = 0.06;
uniform float forza : hint_range(0.0, 1.0) = 1.0;

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
	// Spirale che sale: le striature girano intorno alla colonna e corrono verso l'ugello.
	float giro = UV.x * 6.0 + UV.y * torsione - TIME * velocita * 0.8;
	float sale = UV.y * 9.0 - TIME * velocita * 2.0;
	float s1 = noise(vec2(giro, sale));
	float s2 = noise(vec2(giro * 2.3 + 5.0, sale * 1.7));
	float striature = s1 * 0.65 + s2 * 0.35;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	// Schiuma alla base (dove si strappa dalla superficie) e lungo le striature più chiare.
	float base = 1.0 - smoothstep(0.0, 0.25, UV.y);
	float schiuma = clamp(smoothstep(0.62, 0.9, striature) + base * 0.7, 0.0, 1.0);
	vec2 off = NORMAL.xy * rifrazione;
	vec3 dietro = texture(schermo, SCREEN_UV + off).rgb;
	ALBEDO = mix(colore.rgb * 0.2, vec3(0.9, 0.94, 0.97), schiuma);
	EMISSION = dietro * colore.rgb * (1.0 - schiuma) * 0.85;
	ROUGHNESS = mix(0.03, 0.4, schiuma);
	SPECULAR = 1.0;
	// Si stacca dalla superficie a brandelli e si assottiglia vicino all'ugello.
	float strappo = smoothstep(0.0, 0.12, UV.y + (striature - 0.5) * 0.15);
	float alpha = mix(0.55, 0.95, fres) * strappo * forza;
	alpha *= smoothstep(0.25, 0.6, striature + 0.35);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
