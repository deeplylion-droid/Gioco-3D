// Vetro sporco degli acquari: quasi trasparente, riflesso di Fresnel, calcare a chiazze e colature
// verticali, banda di calcare più fitta alla quota dell'acqua (`waterline_local`, coordinate locali).
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.75, 0.85, 0.82, 0.06);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D streak_tex : filter_linear_mipmap, repeat_enable;
uniform float grime : hint_range(0.0, 1.0) = 0.55;
uniform float waterline_local = 0.0;
uniform vec3 grime_color : source_color = vec3(0.52, 0.5, 0.42);

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 n = abs(NORMAL);
	// coordinate sul piano del vetro: orizzontale + verticale
	vec2 uv = vec2(v_local.x + v_local.z, v_local.y);
	float blot = smoothstep(0.55, 0.85, texture(noise_tex, uv * 0.8).r);
	float streak = texture(streak_tex, vec2(uv.x * 2.5, uv.y * 0.15)).r;
	streak = smoothstep(0.55, 0.9, streak) * smoothstep(-1.0, 0.6, -v_local.y + 0.4);
	float band = exp(-pow((v_local.y - waterline_local) / 0.035, 2.0)) * 0.8;
	float g = clamp((blot * 0.6 + streak * 0.5 + band) * grime, 0.0, 0.85);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(tint.rgb, grime_color, g);
	ALPHA = clamp(tint.a + g * 0.75 + fres * 0.35, 0.0, 0.95);
	ROUGHNESS = mix(0.04, 0.7, g);
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
