// Superficie "bagnabile" (Splash Lagoon): piastrelle e muri delle vasche, pavimenti con
// pozzanghere, oggetti immersi.
// - texture in triplanare con coordinate del mondo (niente UV necessarie) oppure UV normali;
// - zone umide e pozzanghere riflettenti con i cerchi delle gocce (WaterManager.add_drop_ring);
// - banda bagnata sopra il pelo dell'acqua che si asciuga quando il livello scende;
// - sott'acqua: caustiche animate e luce che si colora e si attenua con la profondita',
//   calcolate per ogni luce nella funzione light().
shader_type spatial;
render_mode diffuse_burley;

#include "res://addons/acqua/shaders/water_receiver.gdshaderinc"

group_uniforms materiale;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 albedo_tint : source_color = vec3(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
/** R = occlusione, G = rugosita', B = altezza (per le pozzanghere nelle fughe). */
uniform sampler2D orh_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float roughness_scale : hint_range(0.0, 2.0) = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
/** Se vero usa le coordinate del mondo (triplanare), altrimenti le UV della mesh. */
uniform bool use_triplanar = true;
/** Ripetizioni della texture per metro (triplanare) o scala delle UV. */
uniform float uv_scale = 1.0;
uniform vec2 uv_offset = vec2(0.0);
uniform float triplanar_sharpness = 6.0;
/** Solo con le UV: scala e spostamento come uv1 di StandardMaterial3D. */
uniform vec2 uv1_scale = vec2(1.0);
uniform vec2 uv1_offset = vec2(0.0);
/** Moltiplica l'albedo per il colore dei vertici (sporco e umidita' dei modelli della sala). */
uniform bool use_vertex_color = false;
/** La terza texture e' una ORM (occlusione, rugosita', metallo) invece di occlusione, rugosita', altezza. */
uniform bool orm_mode = false;

group_uniforms bagnato;
/** Umidita' generale della superficie (0 asciutto, 1 bagnato fradicio). */
uniform float base_wetness : hint_range(0.0, 1.0) = 0.0;
/** Variazione dell'umidita' con un rumore largo (macchie). */
uniform float wetness_variation : hint_range(0.0, 1.0) = 0.5;
/** Quantita' di pozzanghere sui piani orizzontali. */
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.0;
/** Scala del rumore delle pozzanghere (piu' piccolo = pozze piu' grandi). */
uniform float puddle_scale = 0.09;
uniform vec3 puddle_tint : source_color = vec3(0.9, 0.92, 0.9);
uniform float wet_darkening : hint_range(0.0, 1.0) = 0.5;
uniform float drop_ring_strength : hint_range(0.0, 3.0) = 1.0;
/** Bordo bagnato subito sopra il pelo dell'acqua delle vasche: altezza (m) e quanto scurisce. */
uniform float shoreline_height : hint_range(0.0, 0.3) = 0.05;
uniform float shoreline_darkening : hint_range(0.0, 1.0) = 0.6;

group_uniforms acqua;
uniform bool receive_caustics = true;
uniform float caustics_strength : hint_range(0.0, 3.0) = 1.0;
/** Moltiplicatore dell'assorbimento della luce che scende nell'acqua. */
uniform float light_absorption_scale : hint_range(0.0, 3.0) = 1.0;

varying vec3 v_wpos;
varying vec3 v_wnormal;
varying float v_depth_below;
varying vec3 v_absorption;
varying float v_turbidity;
varying float v_caustics;
varying float v_caustics_scale;
varying float v_caustics_lod;
varying float v_f0;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 wp = v_wpos;
	vec3 ng = normalize(v_wnormal);

	// --- materiale di base ---
	vec4 alb;
	vec4 orh;
	vec3 n_world;
	if (use_triplanar) {
		vec3 w = triplanar_weights(ng, triplanar_sharpness);
		alb = triplanar_sample(albedo_tex, wp, w, uv_scale, uv_offset);
		orh = triplanar_sample(orh_tex, wp, w, uv_scale, uv_offset);
		n_world = triplanar_normal(normal_tex, wp, ng, w, uv_scale, uv_offset, normal_strength);
	} else {
		vec2 uv = (UV * uv1_scale + uv1_offset) * uv_scale + uv_offset;
		alb = texture(albedo_tex, uv);
		orh = texture(orh_tex, uv);
		vec3 tn = decode_normal_map(texture(normal_tex, uv), normal_strength);
		vec3 tw = normalize((INV_VIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
		vec3 bw = normalize((INV_VIEW_MATRIX * vec4(BINORMAL, 0.0)).xyz);
		n_world = normalize(tw * tn.x - bw * tn.y + ng * tn.z);
	}
	vec3 albedo = alb.rgb * albedo_tint;
	if (use_vertex_color) {
		albedo *= COLOR.rgb;
	}
	float ao = mix(1.0, orh.r, ao_strength);
	float rough = clamp(orh.g * roughness_scale, 0.02, 1.0);
	float height01 = orm_mode ? 0.5 : orh.b;
	float metal = orm_mode ? metallic * orh.b : metallic;
	float spec = specular_amount;

	// --- acqua delle vasche ---
	WaterBody wb = water_body_at(wp, 0.08);
	float depth_below = wb.found ? (wb.level - wp.y) : -1.0;
	bool submerged = depth_below > 0.0;

	// --- umidita' ---
	float up = ng.y;
	float wet_noise = texture(water_noise_tex, wp.xz * 0.05 + wp.y * 0.03).r;
	float wet = base_wetness * mix(1.0, smoothstep(0.25, 0.75, wet_noise), wetness_variation);
	wet = max(wet, water_wet_band(wb, wp.y));
	float puddle = puddle_mask(wp, height01, puddle_amount, puddle_scale, up);
	if (submerged) {
		wet = 1.0;
		puddle = 0.0;
	}
	// i materiali porosi si scuriscono di piu'; anche le piastrelle lucide, bagnate, si scuriscono
	// un po' (velo d'acqua) e diventano molto piu' lucide
	float porosity = clamp(rough * 1.2, 0.2, 1.0);
	albedo *= 1.0 - wet * wet_darkening * mix(0.5, 1.0, porosity);
	rough = mix(rough, mix(0.06, 0.2, rough), wet);
	// bordo dell'acqua: velo d'acqua appena sopra il pelo, piu' scuro e lucido (si legge la riva)
	if (wb.found && !submerged && shoreline_height > 0.0) {
		float film = 1.0 - smoothstep(0.0, shoreline_height, wp.y - wb.level);
		film *= 0.85 + 0.3 * texture(water_noise_tex, wp.xz * 1.7).g;
		// sfuma vicino ai bordi del rettangolo della vasca (niente taglio dritto)
		float rect_d = min(min(wp.x - wb.rect.x, wb.rect.z - wp.x), min(wp.z - wb.rect.y, wb.rect.w - wp.z));
		film *= smoothstep(-0.05, 0.45, rect_d);
		film = clamp(film, 0.0, 1.0);
		albedo *= 1.0 - film * shoreline_darkening;
		rough = mix(rough, 0.05, film);
	}
	// le pozzanghere: specchio d'acqua piatto sopra il materiale
	vec3 rings = water_drop_rings(wp.xz);
	float ring_mask = max(puddle, wet * 0.35) * drop_ring_strength;
	vec3 n_water = normalize(vec3(-rings.x * ring_mask, 1.0, -rings.y * ring_mask));
	n_world = normalize(mix(n_world, n_water, puddle * 0.95));
	if (puddle < 0.5) {
		n_world = normalize(n_world + vec3(-rings.x, 0.0, -rings.y) * ring_mask * 0.6);
	}
	albedo = mix(albedo, albedo * puddle_tint * 0.7, puddle);
	rough = mix(rough, 0.02, puddle);
	ao = mix(ao, 1.0, puddle * 0.5);
	if (submerged) {
		// sott'acqua il riflesso speculare quasi sparisce (interfaccia acqua-materiale)
		spec *= 0.25;
		rough = max(rough, 0.3);
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
	SPECULAR = spec;
	METALLIC = metal * (1.0 - puddle);
	if (any(isnan(n_world)) || any(isinf(n_world))) {
		n_world = ng;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// --- dati per la funzione di luce ---
	v_depth_below = depth_below;
	v_absorption = wb.absorption * light_absorption_scale;
	v_turbidity = wb.turbidity * light_absorption_scale;
	v_caustics = (receive_caustics && wb.found) ? wb.caustics * caustics_strength : 0.0;
	v_caustics_scale = wb.caustics_scale;
	float footprint = max(length(dFdx(wp)), length(dFdy(wp)));
	v_caustics_lod = max(log2(footprint * 256.0 / max(wb.caustics_scale, 0.05)), 0.0);
	v_f0 = 0.16 * spec * spec;

	// passata del riflesso planare: niente sotto il pelo dell'acqua (alla fine, dopo le derivate)
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA = water_reflection_clip(wp, CAMERA_VISIBLE_LAYERS, CAMERA_POSITION_WORLD) ? 0.0 : 1.0;
}

void light() {
	vec3 light_world = (INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz;
	vec3 lmod = water_light_modulation(light_world, v_wpos, v_depth_below, v_absorption, v_turbidity,
			v_caustics, v_caustics_scale, v_caustics_lod);
	vec3 lc = LIGHT_COLOR * ATTENUATION * lmod;
	if (LIGHT_IS_AREA) {
		DIFFUSE_LIGHT += LIGHT_AREA_DIFFUSE_MULTIPLIER * lc;
		SPECULAR_LIGHT += LIGHT_AREA_SPECULAR_MULTIPLIER * lc * SPECULAR_AMOUNT;
	} else {
		float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
		float ndv = max(dot(NORMAL, VIEW), 1e-4);
		vec3 h = normalize(VIEW + LIGHT);
		float ldh = clamp(dot(LIGHT, h), 0.0, 1.0);
		float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
		// diffusa di Burley, come quella di Godot
		float fd90m1 = 2.0 * ldh * ldh * ROUGHNESS - 0.5;
		float fdv = 1.0 + fd90m1 * pow(1.0 - ndv, 5.0);
		float fdl = 1.0 + fd90m1 * pow(1.0 - ndl, 5.0);
		DIFFUSE_LIGHT += lc * (fdv * fdl * ndl / PI);
		if (ROUGHNESS > 0.0) {
			float a = ROUGHNESS * ROUGHNESS;
			float f0 = v_f0;
			float f90 = clamp(50.0 * f0, METALLIC, 1.0);
			vec3 f0c = mix(vec3(f0), ALBEDO, METALLIC);
			vec3 fr = f0c + (vec3(f90) - f0c) * pow(1.0 - ldh, 5.0);
			SPECULAR_LIGHT += lc * ndl * wr_d_ggx(ndh, a) * wr_v_ggx(ndl, ndv, a) * fr * SPECULAR_AMOUNT;
		}
	}
	// mai valori non validi nei buffer: si spargerebbero con riflessi e bagliore
	if (any(isnan(DIFFUSE_LIGHT)) || any(isinf(DIFFUSE_LIGHT))) {
		DIFFUSE_LIGHT = vec3(0.0);
	}
	if (any(isnan(SPECULAR_LIGHT)) || any(isinf(SPECULAR_LIGHT))) {
		SPECULAR_LIGHT = vec3(0.0);
	}
}
