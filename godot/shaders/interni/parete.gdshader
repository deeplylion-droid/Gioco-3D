shader_type spatial;
// Pareti e soffitti degli interni (corridoio, spogliatoi, stanzino): vernice INTERA quasi ovunque,
// con la variante scrostata solo in basso, vicino al soffitto (tubi) e in poche chiazze sparse.
// Tutte le variazioni sono in spazio mondo, così la texture non si vede ripetere:
// macro-variazione del colore, colature scure dall'alto, sporco vicino al pavimento.
// Le UV dei modelli sono già in metri (proiezione a scatola, scala_uv metri per ripetizione).

uniform vec3 colore_vernice : source_color = vec3(0.72, 0.68, 0.58);
uniform float lucidita_vernice : hint_range(0.0, 1.0) = 0.45;
uniform sampler2D scrostata_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scrostata_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scrostata_rough : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lamiera_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D colature : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D rumore : hint_default_white, filter_linear_mipmap, repeat_enable;
// quanta parete è scrostata (0 = mai, 1 = ovunque)
uniform float scrostatura : hint_range(0.0, 1.0) = 0.2;
// fascia in basso e in alto dove la vernice si stacca (m)
uniform float fascia_bassa = 0.45;
uniform float quota_tubi = 2.25;
uniform float intensita_colature : hint_range(0.0, 1.0) = 0.7;
uniform float sporco_basso : hint_range(0.0, 1.0) = 0.45;
uniform float passo_pannelli = 1.25;
uniform float quota_giunto = 1.85;
// sposta le UV di ogni oggetto (per esempio ogni anta di armadietto) per non avere copie identiche
uniform vec2 sposta_uv = vec2(0.0);

varying vec3 pos_mondo;
varying vec3 norm_mondo;

void vertex() {
	pos_mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	norm_mondo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float rum(vec2 p) {
	return texture(rumore, p).r;
}

// rumore 3D economico: due campioni proiettati
float rum3(vec3 p) {
	return 0.5 * (rum(p.xz + p.y * 0.37) + rum(p.zy * 1.13 + p.x * 0.29));
}

void fragment() {
	vec2 uv = UV + sposta_uv;
	vec3 p = pos_mondo;
	float altezza = p.y;
	// --- dove si scrosta
	float n_det = rum3(p * 0.9);
	float n_big = rum3(p * 0.18 + 13.1);
	float basso = 1.0 - smoothstep(0.0, fascia_bassa, altezza);
	float alto = smoothstep(quota_tubi, quota_tubi + 0.35, altezza);
	float zona = max(basso, alto * 0.8);
	float chiazze = smoothstep(1.0 - scrostatura * 0.5, 1.03 - scrostatura * 0.5, n_big);
	float m = clamp(zona * smoothstep(0.35, 0.55, n_det) + chiazze * smoothstep(0.3, 0.6, n_det), 0.0, 1.0);
	m = smoothstep(0.35, 0.65, m);
	// --- vernice intera con macro-variazione
	float macro = rum3(p * 0.07 + 3.0);
	float micro = rum(uv * 0.45 + 7.0);
	vec3 vernice = colore_vernice * mix(0.7, 1.12, macro) * mix(0.88, 1.04, micro);
	vec3 alb = mix(vernice, texture(scrostata_albedo, uv).rgb, m);
	float rgh = mix(lucidita_vernice + (macro - 0.5) * 0.15, texture(scrostata_rough, uv).g, m);
	// --- colature scure che scendono dall'alto (non su pavimenti e soffitti)
	float verticale = 1.0 - abs(norm_mondo.y);
	float c = texture(colature, vec2((p.x + p.z) * 0.22, altezza * 0.18)).r;
	float giu = smoothstep(0.2, 2.4, altezza) * smoothstep(0.2, 0.6, rum3(p * vec3(0.6, 0.05, 0.6) + 5.0));
	alb *= 1.0 - c * giu * intensita_colature * verticale;
	// --- pannelli della nave: giunti verticali ogni 1,25 m e orizzontale a metà, con rivetti
	float lungo = abs(norm_mondo.x) > abs(norm_mondo.z) ? p.z : p.x;
	float gx = abs(fract(lungo / passo_pannelli + 0.5) - 0.5) * passo_pannelli;
	float gy = abs(altezza - quota_giunto);
	float giunto = (1.0 - smoothstep(0.004, 0.012, gx)) * verticale;
	giunto = max(giunto, (1.0 - smoothstep(0.004, 0.012, gy)) * verticale);
	float rx = abs(fract(lungo / passo_pannelli + 0.5) - 0.5) * passo_pannelli - 0.035;
	float ry = abs(fract(altezza / 0.18) - 0.5) * 0.18;
	float rivetto = (1.0 - smoothstep(0.006, 0.009, length(vec2(rx, ry)))) * verticale * step(0.3, altezza);
	alb *= 1.0 - giunto * 0.55;
	alb = mix(alb, alb * 1.15, rivetto * 0.6);
	// --- sporco e umidità vicino al pavimento
	float s = (1.0 - smoothstep(0.0, 0.5, altezza)) * mix(0.6, 1.0, n_det) * verticale;
	alb = mix(alb, alb * vec3(0.45, 0.42, 0.36), s * sporco_basso);
	rgh = mix(rgh, 0.35, s * sporco_basso * 0.6);
	ALBEDO = alb;
	ROUGHNESS = clamp(rgh, 0.05, 1.0);
	METALLIC = mix(0.15, 0.3, m);
	vec3 nm = mix(texture(lamiera_normal, uv * 0.5).rgb, texture(scrostata_normal, uv).rgb, m);
	nm.xy += vec2(dFdx(giunto), dFdy(giunto)) * 2.0;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = mix(0.5, 1.0, m);
}
