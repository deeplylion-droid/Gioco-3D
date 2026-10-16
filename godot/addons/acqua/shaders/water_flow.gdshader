// Acqua che scorre su superfici curve (scivoli a tubo o a canale, cascatelle, canalette).
// La mesh e' un nastro con le UV allineate al flusso: UV.x lungo il percorso (in metri, oppure
// scalato con uv_length_scale), UV.y = 0..1 di traverso. UV2.x = turbolenza (0..1) calcolata da
// SlideWater nelle curve, UV2.y = 1 sui bordi.
// Mesh senza UV adatte (piani, FlowingWater): use_local_xz = vero, il flusso segue local_flow_dir.
// Le onde scorrono lungo il flusso; schiuma a strisce nelle curve e sui bordi dove l'acqua sbatte
// contro la parete; il fondo si vede attraverso l'acqua (rifrazione dello schermo).
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_occlusion_disabled;

#include "res://addons/acqua/shaders/water_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_b : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;

/** Velocita' dell'acqua lungo lo scivolo (m/s); negativa = verso le UV.x decrescenti. */
uniform float flow_speed = 3.5;
/** Metri per unita' di UV.x (strisce ACQUA_scorre_* del kit degli scivoli: 1 = 5 m). */
uniform float uv_length_scale = 1.0;
/** Coordinate dalla posizione locale (piano XZ della mesh) invece che dalle UV. */
uniform bool use_local_xz = false;
/** Con use_local_xz: direzione del flusso nel piano XZ locale della mesh. */
uniform vec2 local_flow_dir = vec2(0.0, -1.0);
/** Larghezza del nastro d'acqua (m), per avere onde non stirate di traverso. */
uniform float ribbon_width = 0.8;
uniform float wave_strength : hint_range(0.0, 2.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform vec3 water_tint : source_color = vec3(0.55, 0.7, 0.68);
/** Quanto l'acqua scurisce e colora il fondo (strato sottile). */
uniform float absorption : hint_range(0.0, 1.0) = 0.25;
uniform float refraction_strength = 0.02;
uniform vec3 foam_color : source_color = vec3(0.78, 0.8, 0.8);
uniform float foam_amount : hint_range(0.0, 3.0) = 1.0;
uniform float edge_foam : hint_range(0.0, 2.0) = 0.7;
/** Riflesso di riserva (colore dell'ambiente riflesso). */
uniform vec3 reflection_color : source_color = vec3(0.02, 0.02, 0.025);

varying vec2 v_uv2;
varying vec2 v_local;

void vertex() {
	v_uv2 = UV2;
	v_local = VERTEX.xz;
}

vec2 slope_nm(sampler2D tex, vec2 uv) {
	vec2 nxy = texture(tex, uv).rg * 2.0 - 1.0;
	float nz = sqrt(max(1.0 - dot(nxy, nxy), 0.04));
	return vec2(nxy.x, nxy.y) / nz;
}

void fragment() {
	float t = water_time;
	vec2 uvm = vec2(UV.x * uv_length_scale, UV.y * ribbon_width);   // metri lungo e di traverso
	float across = abs(UV.y * 2.0 - 1.0);   // 0 al centro del nastro, 1 sui bordi
	vec2 fd = normalize(local_flow_dir + vec2(1e-6));
	if (use_local_xz) {
		uvm = vec2(dot(v_local, fd), dot(v_local, vec2(-fd.y, fd.x)));
		across = 0.0;
	}
	float turb = clamp(v_uv2.x, 0.0, 1.0);
	// onde trascinate dal flusso, piu' fitte e forti dove c'e' turbolenza
	vec2 s = slope_nm(normal_a, vec2(uvm.x - t * flow_speed, uvm.y) * vec2(0.5, 0.9)) * wave_strength;
	s += slope_nm(normal_b, vec2(uvm.x - t * flow_speed * 1.25, uvm.y + 0.37) * vec2(1.3, 2.2)) * wave_strength * (0.6 + turb);
	s += slope_nm(normal_b, vec2(uvm.x * 0.7 - t * flow_speed * 0.8 + 0.5, uvm.y * 1.7) * 2.6) * wave_strength * 0.5;
	if (use_local_xz) {
		// piano: la normale si calcola nello spazio locale della mesh (su = +Y)
		vec2 sl = s.x * fd + s.y * vec2(-fd.y, fd.x);
		vec3 nl = normalize(vec3(-sl.x, 1.0, -sl.y));
		NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(nl, 0.0))).xyz);
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else {
		// normale in tangent space: x lungo il flusso, y di traverso
		NORMAL_MAP = normalize(vec3(-s.x, -s.y, 1.0)) * 0.5 + 0.5;
	}
	NORMAL_MAP_DEPTH = 1.0;

	// schiuma: strisce allungate nel verso del flusso
	vec2 fuv = vec2(uvm.x * 0.35 - t * flow_speed * 0.35, uvm.y * 1.4);
	float f1 = texture(foam_tex, fuv).r;
	float f2 = texture(foam_tex, fuv * vec2(0.6, 1.3) + vec2(0.31, 0.17) - vec2(t * flow_speed * 0.12, 0.0)).r;
	float pattern = max(f1, f2 * 0.9);
	float edge = smoothstep(0.75, 1.0, across);
	float foam = smoothstep(0.45, 0.9, pattern * (0.25 + turb * 1.6) * foam_amount);
	foam = max(foam, smoothstep(0.3, 0.8, edge * (0.4 + pattern) * edge_foam));

	// fondo visto attraverso lo strato d'acqua
	vec2 ruv = clamp(SCREEN_UV + s * refraction_strength, vec2(0.001), vec2(0.999));
	vec3 under = textureLod(screen_tex, ruv, 0.0).rgb;
	float fres = water_env_fresnel(roughness, clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	vec3 col = under * mix(vec3(1.0), water_tint, absorption) * (1.0 - fres);
	ALBEDO = mix(water_tint * 0.04, foam_color, foam);
	EMISSION = col * (1.0 - foam);
	RADIANCE = vec4(reflection_color, 1.0);
	ROUGHNESS = mix(roughness, 0.7, foam);
	SPECULAR = 0.354;
	METALLIC = 0.0;
	// bordo sottile che sfuma sulla parete
	ALPHA = smoothstep(0.0, 0.08, 1.0 - across);
}
