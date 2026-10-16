shader_type spatial;
// Vetro sporco degli interni: macchie e colature in coordinate mondo (niente ripetizioni), più opaco dove è
// sporco e sui bordi (fresnel), così si capisce che c'è un vetro anche quando dietro si vede tutto.
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;

uniform sampler2D rumore : repeat_enable, filter_linear_mipmap;
uniform vec4 tinta : source_color = vec4(0.52, 0.6, 0.57, 1.0);
uniform vec4 colore_sporco : source_color = vec4(0.4, 0.38, 0.31, 1.0);
uniform float alfa_pulito = 0.16;
uniform float alfa_sporco = 0.42;
uniform float alfa_bordo = 0.38;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(wn);
	vec2 p = an.x > an.z ? wp.zy : wp.xy;
	float n1 = texture(rumore, p * 0.7).r;
	float n2 = texture(rumore, p * 2.9 + vec2(0.37, 0.11)).r;
	float macchie = smoothstep(0.42, 0.78, n1 * 0.65 + n2 * 0.35);
	float colature = smoothstep(0.58, 0.92, texture(rumore, vec2(p.x * 5.0, p.y * 0.35 + 0.2)).r);
	float s = clamp(macchie * 0.85 + colature * 0.45, 0.0, 1.0);
	ALBEDO = mix(tinta.rgb, colore_sporco.rgb, s);
	ROUGHNESS = mix(0.05, 0.55, s);
	SPECULAR = 0.65;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	ALPHA = clamp(alfa_pulito + s * alfa_sporco + fres * alfa_bordo, 0.0, 0.92);
}
