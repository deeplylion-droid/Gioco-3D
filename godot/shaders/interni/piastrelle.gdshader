shader_type spatial;
// Piastrelle degli interni (pavimenti, docce, vasca lava-piedi). Contro la ripetizione:
// - ogni piastrella ha tinta, ruvidità e sporco suoi (hash della cella della griglia);
// - macro-variazione e chiazze bagnate in spazio mondo (sul pavimento: quasi a specchio);
// - fughe in rilievo con il parallasse della mappa d'altezza.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D altezza_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D rumore : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 tinta : source_color = vec3(1.0);
// piastrelle per ripetizione della texture (0 = niente variazione per piastrella)
uniform float piastrelle_per_lato = 8.0;
uniform float variazione_piastrelle : hint_range(0.0, 0.5) = 0.12;
uniform float profondita_fughe : hint_range(0.0, 0.05) = 0.012;
uniform float bagnato : hint_range(0.0, 1.0) = 0.45;
uniform float sporco : hint_range(0.0, 1.0) = 0.4;

varying vec3 pos_mondo;
varying vec3 norm_mondo;

void vertex() {
	pos_mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	norm_mondo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rum3(vec3 p) {
	return 0.5 * (texture(rumore, p.xz + p.y * 0.37).r + texture(rumore, p.zy * 1.13 + p.x * 0.29).r);
}

void fragment() {
	// parallasse semplice: le fughe affondano
	vec3 v = normalize(vec3(dot(VIEW, TANGENT), dot(VIEW, -BINORMAL), dot(VIEW, NORMAL)));
	float h = texture(altezza_tex, UV).r;
	vec2 uv = UV - v.xy / max(v.z, 0.25) * (1.0 - h) * profondita_fughe;
	vec3 alb = texture(albedo_tex, uv).rgb * tinta;
	float rgh = texture(rough_tex, uv).g;
	vec3 p = pos_mondo;
	// variazione per piastrella
	if (piastrelle_per_lato > 0.0) {
		vec2 cella = floor(uv * piastrelle_per_lato);
		float a = hash(cella);
		float b = hash(cella + 17.3);
		alb *= mix(1.0 - variazione_piastrelle, 1.0 + variazione_piastrelle * 0.6, a);
		alb = mix(alb, alb * vec3(0.92, 0.95, 0.9), step(0.82, b) * 0.6);
		rgh += (b - 0.5) * 0.15;
	}
	// macro-variazione e sporco in spazio mondo
	float macro = rum3(p * 0.09 + 2.0);
	alb *= mix(0.78, 1.08, macro);
	float s = smoothstep(0.45, 0.8, rum3(p * 0.35 + 9.0)) * sporco;
	alb = mix(alb, alb * vec3(0.5, 0.47, 0.4), s);
	// chiazze bagnate (solo sulle superfici orizzontali): più scure e a specchio
	float orizz = smoothstep(0.7, 0.95, norm_mondo.y);
	float w = smoothstep(0.52, 0.6, rum3(p * 0.22 + 4.0) + (bagnato - 0.5) * 0.4) * orizz;
	float umido = smoothstep(0.42, 0.6, rum3(p * 0.22 + 4.0) + (bagnato - 0.5) * 0.4) * orizz;
	alb *= 1.0 - umido * 0.3;
	rgh = mix(rgh, 0.25, umido);
	rgh = mix(rgh, 0.03, w);
	ALBEDO = alb;
	ROUGHNESS = clamp(rgh, 0.02, 1.0);
	SPECULAR = 0.5;
	NORMAL_MAP = mix(texture(normal_tex, uv).rgb, vec3(0.5, 0.5, 1.0), w * 0.9);
}
