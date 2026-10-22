// Superficie dell'acqua delle vasche (Jilly Jubilee).
//
// Sopra l'acqua: rifrazione dello schermo con assorbimento e diffusione che dipendono dallo spessore
// d'acqua attraversato, riflessi (SSR fatto a mano, riflesso planare o cubemap di riserva) passati
// al motore come RADIANCE, cosi' Fresnel e luci (anche ad area) li calcola Godot; schiuma sui bordi
// e dove la simulazione delle increspature e' agitata; patina di sporco opzionale; bagliore delle
// luci che stanno in acqua (WaterGlowLight); gorghi e aspirazione (imbuto, rotazione, schiuma a
// spirale).
// Sotto l'acqua (faccia posteriore): finestra di Snell, riflessione totale interna e nebbia.
//
// I parametri di aspetto sono impostati da WaterBody a partire da una WaterStyle (preset).
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_occlusion_disabled;

#include "res://addons/acqua/shaders/water_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

group_uniforms volume;
/** Assorbimento per metro (rosso, verde, blu). Valori alti = acqua che si scurisce presto. */
uniform vec3 absorption = vec3(0.45, 0.10, 0.07);
/** Diffusione per metro: rende l'acqua lattiginosa/torbida. */
uniform float turbidity : hint_range(0.0, 6.0) = 0.06;
/** Colore della luce diffusa dal volume (illuminato dalle luci della scena). */
uniform vec3 scatter_color : source_color = vec3(0.10, 0.45, 0.55);
/** Luce propria minima del volume, per non farlo diventare nero dove non arrivano luci. */
uniform float scatter_ambient : hint_range(0.0, 2.0) = 0.02;
/** Oltre questa distanza nell'acqua il fondo non si vede piu' (m). */
uniform float max_view_depth = 40.0;
/** Moltiplicatore del bagliore delle luci immerse (WaterGlowLight). */
uniform float glow_scatter : hint_range(0.0, 10.0) = 1.0;

group_uniforms onde;
uniform sampler2D normal_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_b : filter_linear_mipmap_anisotropic, repeat_enable;
/** Metri coperti da una ripetizione delle onde lunghe / delle increspature fini. */
uniform float wave_scale_a = 4.0;
uniform float wave_scale_b = 1.1;
uniform float wave_strength_a : hint_range(0.0, 2.0) = 0.07;
uniform float wave_strength_b : hint_range(0.0, 2.0) = 0.06;
/** Velocita' di scorrimento delle onde (m/s). */
uniform float wave_speed = 0.05;
uniform vec2 wave_dir = vec2(0.8, 0.6);
/** Simulazione delle increspature di questa vasca (impostata da WaterBody). */
uniform sampler2D ripple_tex : filter_linear, repeat_disable;
uniform vec4 ripple_rect = vec4(0.0);
uniform float ripple_normal_strength : hint_range(0.0, 4.0) = 1.0;
uniform float ripple_height_scale : hint_range(0.0, 4.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.035;

group_uniforms rifrazione;
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.18;
/** Separazione dei colori nella rifrazione (solo qualita' alta). */
uniform float refraction_dispersion : hint_range(0.0, 0.1) = 0.02;

group_uniforms schiuma;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 foam_color : source_color = vec3(0.82, 0.85, 0.84);
/** Larghezza della schiuma dove l'acqua tocca pareti e oggetti (m). */
uniform float foam_shore_width = 0.22;
uniform float foam_shore_amount : hint_range(0.0, 2.0) = 0.6;
/** Schiuma generata da schizzi e getti (dalla simulazione). */
uniform float foam_ripple_amount : hint_range(0.0, 4.0) = 1.0;
uniform float foam_scale = 0.9;

group_uniforms sporco;
/** Patina galleggiante (alghe, polvere): 0 = acqua pulita. */
uniform float scum_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 scum_color : source_color = vec3(0.16, 0.17, 0.09);
uniform float scum_scale = 6.0;

group_uniforms flusso;
/** Gorgo/aspirazione 0: x, z (mondo), raggio (m), intensita' (0..1). */
uniform vec4 flow_point_0 = vec4(0.0, 0.0, 1.0, 0.0);
/** Forma 0: rotazione (segno = verso), profondita' dell'imbuto (m), richiamo verso il centro, schiuma. */
uniform vec4 flow_shape_0 = vec4(1.0, 0.3, 0.35, 0.8);
uniform vec4 flow_point_1 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 flow_shape_1 = vec4(0.2, 0.08, 1.0, 0.5);

group_uniforms riflessi;
/** 0 = solo cubemap di riserva, 1 = SSR + cubemap, 2 = riflesso planare. */
uniform int reflection_mode = 1;
uniform float reflection_strength : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D planar_reflection_tex : filter_linear, repeat_disable;
uniform float planar_distortion : hint_range(0.0, 0.5) = 0.08;
/** Riflessi allungati in verticale (frazione dell'altezza dello schermo): le scie delle luci
 *  sull'acqua increspata. 0 = riflesso netto. */
uniform float reflection_stretch : hint_range(0.0, 0.2) = 0.0;
uniform int ssr_steps : hint_range(4, 96) = 28;
uniform float ssr_max_distance = 30.0;
uniform float ssr_thickness = 0.6;
uniform samplerCube env_cubemap : filter_linear_mipmap;
uniform bool env_cubemap_valid = false;
uniform vec3 env_box_min = vec3(-10.0, -3.0, -8.0);
uniform vec3 env_box_max = vec3(10.0, 6.0, 8.0);
uniform vec3 env_capture_pos = vec3(0.0, 1.5, 0.0);
uniform float env_intensity = 1.0;
/** Colore di riserva dei riflessi quando non c'e' nessuna informazione. */
uniform vec3 env_fallback_color : source_color = vec3(0.004, 0.004, 0.005);

group_uniforms sotto;
/** Intensita' della finestra di Snell vista da sotto. */
uniform float underwater_window_strength : hint_range(0.0, 2.0) = 1.0;

varying vec3 v_world;

vec3 view_from_depth(vec2 uv, float raw_depth, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, raw_depth, 1.0);
	return v.xyz / v.w;
}

vec2 view_to_uv(vec3 pv, mat4 proj) {
	vec4 c = proj * vec4(pv, 1.0);
	return (c.xy / c.w) * 0.5 + 0.5;
}

// Pendenza della superficie da una normal map (convenzione OpenGL) mappata in pianta.
vec2 slope_from_normal_map(sampler2D tex, vec2 uv) {
	vec2 nxy = texture(tex, uv).rg * 2.0 - 1.0;
	float nz = sqrt(max(1.0 - dot(nxy, nxy), 0.04));
	return vec2(-nxy.x, nxy.y) / nz;
}

// Onde di fondo: due strati lunghi e due fini che scorrono in direzioni diverse.
vec2 wave_slope(vec2 xz, float tt) {
	vec2 dir = normalize(wave_dir);
	vec2 s = slope_from_normal_map(normal_a, xz / wave_scale_a + dir * tt / wave_scale_a) * wave_strength_a;
	s += slope_from_normal_map(normal_a, (xz * vec2(-0.83, 0.79)).yx / (wave_scale_a * 0.73) - dir.yx * tt * 0.7 / wave_scale_a) * wave_strength_a * 0.6;
	s += slope_from_normal_map(normal_b, xz / wave_scale_b + vec2(-dir.y, dir.x) * tt * 1.6 / wave_scale_b) * wave_strength_b;
	if (water_quality >= 1) {
		s += slope_from_normal_map(normal_b, xz / (wave_scale_b * 0.61) - dir * tt * 2.1 / wave_scale_b) * wave_strength_b * 0.7;
	}
	return s;
}

// --- gorghi e aspirazione ---
float flow_dip_one(vec2 xz, vec4 fp, vec4 fs) {
	if (fp.w <= 0.0) {
		return 0.0;
	}
	float r = length(xz - fp.xy);
	float core = max(fp.z * 0.14, 0.02);
	float q = r / core;
	return fs.y * fp.w / (1.0 + q * q) * (1.0 - smoothstep(fp.z * 0.55, fp.z, r));
}

float flow_dip(vec2 xz) {
	return flow_dip_one(xz, flow_point_0, flow_shape_0) + flow_dip_one(xz, flow_point_1, flow_shape_1);
}

vec2 flow_vel_one(vec2 xz, vec4 fp, vec4 fs) {
	if (fp.w <= 0.0) {
		return vec2(0.0);
	}
	vec2 d = xz - fp.xy;
	float r = length(d) + 1e-4;
	vec2 dir = d / r;
	vec2 tang = vec2(-dir.y, dir.x);
	float w = fp.w * (1.0 - smoothstep(fp.z * 0.45, fp.z, r));
	return (tang * fs.x - dir * fs.z) * w * 0.5 / (r + 0.2);
}

vec2 flow_velocity(vec2 xz) {
	return flow_vel_one(xz, flow_point_0, flow_shape_0) + flow_vel_one(xz, flow_point_1, flow_shape_1);
}

float flow_foam_one(vec2 xz, vec4 fp, vec4 fs, float t, float pattern) {
	if (fp.w <= 0.0) {
		return 0.0;
	}
	vec2 d = xz - fp.xy;
	float r = length(d);
	float ang = atan(d.y, d.x + 1e-5);
	float turn = fs.x >= 0.0 ? 1.0 : -1.0;
	float arms = sin(ang * 3.0 + turn * log(r + 0.03) * 4.5 + t * (2.0 + 4.0 * abs(fs.x)) * turn * fp.w);
	float ring = 1.0 - smoothstep(fp.z * 0.25, fp.z * 0.95, r);
	float m = smoothstep(0.15, 0.9, arms * 0.5 + 0.5) * ring * smoothstep(0.0, fp.z * 0.06, r);
	return clamp(m * fs.w * fp.w * (0.35 + pattern * 1.3), 0.0, 1.0);
}

vec3 box_projected_dir(vec3 wp, vec3 dir) {
	vec3 inv = 1.0 / (dir + vec3(1e-5));
	vec3 t1 = (env_box_max - wp) * inv;
	vec3 t2 = (env_box_min - wp) * inv;
	vec3 tmax = max(t1, t2);
	float t = min(min(tmax.x, tmax.y), tmax.z);
	return normalize(wp + dir * max(t, 0.0) - env_capture_pos);
}

vec3 env_lookup(vec3 wp, vec3 dir_world, float rough) {
	if (!env_cubemap_valid) {
		return env_fallback_color;
	}
	vec3 d = box_projected_dir(wp, dir_world);
	return textureLod(env_cubemap, d, rough * 6.0).rgb * env_intensity;
}

// Riflessi nello spazio dello schermo: marcia del raggio riflesso contro il buffer di profondita'.
// Restituisce colore e fiducia (0 = nessun impatto).
vec4 trace_ssr(vec3 origin_v, vec3 dir_v, mat4 proj, mat4 inv_proj, mat4 inv_view, float min_world_y, float rough, float stretch) {
	if (dir_v.z > 0.25) {
		return vec4(0.0); // raggio verso la camera: fuori dallo schermo
	}
	float t = 0.05;
	float prev_t = 0.0;
	float step_len = ssr_max_distance / float(ssr_steps) * 0.25;
	vec2 hit_uv = vec2(-1.0);
	bool hit = false;
	for (int i = 0; i < 96; i++) {
		if (i >= ssr_steps) {
			break;
		}
		vec3 p = origin_v + dir_v * t;
		vec2 uv = view_to_uv(p, proj);
		if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0 || p.z > -0.05) {
			break;
		}
		float scene_z = view_from_depth(uv, textureLod(depth_tex, uv, 0.0).r, inv_proj).z;
		float diff = scene_z - p.z; // > 0: il raggio e' dietro la superficie della scena
		if (diff > 0.0 && diff < ssr_thickness + t * 0.06) {
			float a = prev_t;
			float b = t;
			for (int j = 0; j < 5; j++) {
				float m = 0.5 * (a + b);
				vec3 pm = origin_v + dir_v * m;
				vec2 uvm = view_to_uv(pm, proj);
				float zm = view_from_depth(uvm, textureLod(depth_tex, uvm, 0.0).r, inv_proj).z;
				if (zm - pm.z > 0.0) {
					b = m;
				} else {
					a = m;
				}
			}
			vec3 ph = origin_v + dir_v * b;
			hit_uv = view_to_uv(ph, proj);
			// scarta impatti sotto il pelo dell'acqua (fondo visto per rifrazione)
			vec3 hw = (inv_view * vec4(ph, 1.0)).xyz;
			hit = hw.y > min_world_y;
			break;
		}
		prev_t = t;
		t += step_len;
		step_len *= 1.12;
	}
	if (!hit) {
		return vec4(0.0);
	}
	vec2 edge = smoothstep(vec2(0.0), vec2(0.08), hit_uv) * smoothstep(vec2(0.0), vec2(0.08), vec2(1.0) - hit_uv);
	float conf = edge.x * edge.y;
	conf *= 1.0 - smoothstep(0.0, 0.25, dir_v.z + 0.1);
	conf *= 1.0 - smoothstep(ssr_max_distance * 0.6, ssr_max_distance, t);
	// scia verticale: alcuni campioni sopra e sotto il punto colpito
	int taps = stretch > 0.0005 ? (water_quality >= 2 ? 7 : 5) : 1;
	vec3 col = vec3(0.0);
	float wsum = 0.0;
	for (int k = 0; k < 7; k++) {
		if (k >= taps) {
			break;
		}
		float o = taps > 1 ? float(k) / float(taps - 1) * 2.0 - 1.0 : 0.0;
		float w = exp(-o * o * 2.0);
		vec2 uvk = clamp(hit_uv + vec2(0.0, o * stretch), vec2(0.001), vec2(0.999));
		col += textureLod(screen_tex, uvk, rough * 8.0).rgb * w;
		wsum += w;
	}
	return vec4(col / wsum, conf);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = water_ripple_height_tex(ripple_tex, ripple_rect, wp.xz) * ripple_height_scale - flow_dip(wp.xz);
	VERTEX.y += h;
	v_world = wp + vec3(0.0, h, 0.0);
}

void fragment() {
	vec3 wp = v_world;
	float level = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 to_frag = wp - cam;
	float cam_dist = length(to_frag);
	vec3 vdir = to_frag / cam_dist;
	float tt = water_time * wave_speed;

	// --- normale: onde (trascinate dal flusso), imbuto dei gorghi, simulazione interattiva ---
	vec2 flow_v = flow_velocity(wp.xz);
	float flow_len = length(flow_v);
	vec2 s;
	float fpat;
	// le celle della schiuma, deformate da un rumore largo, diventano chiazze e filamenti
	vec2 fwarp = vec2(texture(water_noise_tex, wp.xz * 0.37 + vec2(tt * 0.05, 0.0)).r,
			texture(water_noise_tex, wp.xz * 0.37 + vec2(0.57, 0.19) - vec2(0.0, tt * 0.04)).r) - 0.5;
	vec2 fuv = wp.xz * foam_scale + fwarp * 0.7;
	if (flow_len > 0.002) {
		// flow map a due fasi: le onde e la schiuma scorrono lungo il flusso senza stirarsi
		float cyc = 1.6;
		float ph0 = fract(water_time / cyc);
		float ph1 = fract(water_time / cyc + 0.5);
		float w0 = 1.0 - abs(1.0 - 2.0 * ph0);
		vec2 o0 = flow_v * ph0 * cyc;
		vec2 o1 = flow_v * ph1 * cyc;
		s = wave_slope(wp.xz - o0, tt) * w0 + wave_slope(wp.xz - o1, tt) * (1.0 - w0);
		s *= 1.0 + min(flow_len, 1.5) * 2.0;
		fpat = texture(foam_tex, fuv - o0 * foam_scale, 0.6).r * w0 + texture(foam_tex, fuv - o1 * foam_scale + 0.37, 0.6).r * (1.0 - w0);
	} else {
		s = wave_slope(wp.xz, tt);
		float ftex = texture(foam_tex, fuv + vec2(tt * 0.3, tt * 0.17), 0.6).r;
		float ftex2 = texture(foam_tex, fuv * 0.53 - vec2(tt * 0.21, -tt * 0.12), 0.6).r;
		fpat = max(ftex, ftex2 * 0.9);
	}
	float e = 0.03;
	vec2 dip_slope = vec2(flow_dip(wp.xz + vec2(e, 0.0)) - flow_dip(wp.xz - vec2(e, 0.0)),
			flow_dip(wp.xz + vec2(0.0, e)) - flow_dip(wp.xz - vec2(0.0, e))) / (2.0 * e);
	s -= dip_slope;
	vec4 rip = water_ripple_sample_tex(ripple_tex, ripple_rect, wp.xz);
	s += rip.xy * ripple_normal_strength;
	if (any(isnan(s)) || any(isinf(s))) {
		s = vec2(0.0);
	}
	// lontano le onde fini diventano rugosita' (meno scintillio)
	float far_fade = 1.0 / (1.0 + cam_dist * 0.02);
	vec3 n_world = normalize(vec3(-s.x * far_fade, 1.0, -s.y * far_fade));

	bool from_below = !FRONT_FACING;

	// --- scena dietro la superficie ---
	float raw0 = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec3 scene0 = view_from_depth(SCREEN_UV, raw0, INV_PROJECTION_MATRIX);
	float path0 = length(scene0 - VERTEX);
	if (raw0 <= 0.0) {
		path0 = 1e4;
	}
	vec3 sigma_t = absorption + vec3(turbidity);

	if (!from_below) {
		NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

		// rifrazione: sposta il campione in proporzione allo spessore d'acqua
		vec3 pert_v = (VIEW_MATRIX * vec4(n_world.x, 0.0, n_world.z, 0.0)).xyz;
		float thick = clamp(path0, 0.0, 2.5);
		vec2 refr_uv = view_to_uv(VERTEX + pert_v * refraction_strength * thick, PROJECTION_MATRIX);
		refr_uv = clamp(refr_uv, vec2(0.001), vec2(0.999));
		float raw1 = textureLod(depth_tex, refr_uv, 0.0).r;
		vec3 scene1 = view_from_depth(refr_uv, raw1, INV_PROJECTION_MATRIX);
		if (scene1.z > VERTEX.z - 0.02) {
			// il campione spostato e' davanti all'acqua: niente spostamento
			refr_uv = SCREEN_UV;
			scene1 = scene0;
			raw1 = raw0;
		}
		float path = min(length(scene1 - VERTEX), max_view_depth);
		if (!(raw1 > 0.0) || !(path >= 0.0)) {
			path = max_view_depth;   // anche se la profondita' non e' valida (NaN)
		}
		vec3 tr = exp(-sigma_t * path);

		vec3 refr;
		if (water_quality >= 2 && refraction_dispersion > 0.0) {
			vec2 d = (refr_uv - SCREEN_UV) * refraction_dispersion * 12.0;
			refr.r = textureLod(screen_tex, refr_uv - d, 0.0).r;
			refr.g = textureLod(screen_tex, refr_uv, 0.0).g;
			refr.b = textureLod(screen_tex, refr_uv + d, 0.0).b;
		} else {
			refr = textureLod(screen_tex, refr_uv, 0.0).rgb;
		}

		float n_dot_v = clamp(dot(n_world, -vdir), 0.0, 1.0);
		float fres = water_env_fresnel(roughness, n_dot_v);
		float kt = 1.0 - fres;

		// --- riflessi ---
		vec3 rdir_w = reflect(vdir, n_world);
		rdir_w.y = abs(rdir_w.y);
		vec3 refl = env_lookup(wp, rdir_w, roughness);
		// le scie si allungano di piu' guardando l'acqua di taglio
		float stretch = reflection_stretch * mix(0.35, 1.0, 1.0 - n_dot_v);
		if (reflection_mode == 2) {
			vec2 puv = vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y);
			vec2 dist = vec2(-s.x, s.y) * far_fade * planar_distortion;
			puv = clamp(puv + dist, vec2(0.002), vec2(0.998));
			int taps = stretch > 0.0005 ? (water_quality >= 2 ? 7 : 5) : 1;
			vec3 acc = vec3(0.0);
			float wsum = 0.0;
			for (int k = 0; k < 7; k++) {
				if (k >= taps) {
					break;
				}
				float o = taps > 1 ? float(k) / float(taps - 1) * 2.0 - 1.0 : 0.0;
				float w = exp(-o * o * 2.0);
				vec2 uvk = clamp(puv + vec2(0.0, o * stretch), vec2(0.002), vec2(0.998));
				acc += textureLod(planar_reflection_tex, uvk, 0.0).rgb * w;
				wsum += w;
			}
			refl = acc / wsum;
		} else if (reflection_mode == 1) {
			vec3 rdir_v = normalize((VIEW_MATRIX * vec4(rdir_w, 0.0)).xyz);
			vec4 ssr = trace_ssr(VERTEX, rdir_v, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, level - 0.03, roughness, stretch);
			refl = mix(refl, ssr.rgb, ssr.a);
		}

		// --- schiuma e sporco ---
		float noise_lo = texture(water_noise_tex, wp.xz * 0.11 + vec2(tt * 0.02)).r;
		float shore = 1.0 - smoothstep(0.0, foam_shore_width * (0.5 + noise_lo), path0);
		// a chiazze lungo la riva, non un anello uniforme
		float patchy = smoothstep(0.35, 0.7, texture(water_noise_tex, wp.xz * 0.19 + vec2(0.71, 0.23) - vec2(tt * 0.03, 0.0)).r);
		float foam = smoothstep(0.3, 0.8, shore * (0.25 + 0.75 * patchy) * (0.3 + fpat * 1.1)) * foam_shore_amount;
		foam += smoothstep(0.08, 0.6, rip.w * foam_ripple_amount * (0.4 + fpat));
		foam += flow_foam_one(wp.xz, flow_point_0, flow_shape_0, water_time, fpat);
		foam += flow_foam_one(wp.xz, flow_point_1, flow_shape_1, water_time, fpat);
		foam = clamp(foam, 0.0, 1.0);
		float scum = 0.0;
		if (scum_amount > 0.0) {
			float sn = texture(water_noise_tex, wp.xz / scum_scale + vec2(tt * 0.01) - flow_v * 0.3).r;
			float sn2 = texture(water_noise_tex, wp.xz / (scum_scale * 0.31) - vec2(0.0, tt * 0.015)).g;
			scum = smoothstep(1.0 - scum_amount, 1.0 - scum_amount + 0.35, sn * 0.7 + sn2 * 0.45) * (0.5 + 0.5 * scum_amount);
			scum = max(scum, shore * patchy * scum_amount * 0.8);
		}
		float cover = clamp(foam + scum, 0.0, 1.0);

		// --- bagliore delle luci immerse ---
		vec3 rin = refract(vdir, n_world, 1.0 / WATER_IOR);
		if (dot(rin, rin) < 1e-4) {
			rin = vdir;
		}
		vec3 glow = water_glow_inscatter(wp, normalize(rin), path, sigma_t, (turbidity + 0.04) * glow_scatter);

		// --- composizione ---
		// la luce diffusa dal volume la calcolano le luci di Godot sull'albedo
		vec3 inscatter = scatter_color * (vec3(1.0) - tr);
		ALBEDO = mix(inscatter * kt, mix(scum_color, foam_color, foam / max(cover, 1e-4)), cover);
		EMISSION = (refr * tr + scatter_color * scatter_ambient * (vec3(1.0) - tr) + glow) * kt * (1.0 - cover * 0.85);
		RADIANCE = vec4(refl * reflection_strength, 1.0);
		ROUGHNESS = mix(roughness, 0.75, cover);
		SPECULAR = mix(0.354, 0.3, cover);
		METALLIC = 0.0;
		// attenua il bordo duro dove la superficie taglia pareti e pavimento
		ALPHA = (path0 >= 0.0) ? clamp(path0 / 0.015, 0.0, 1.0) : 1.0;
		// mai valori non validi: un solo NaN si spanderebbe con riflessi e bagliore
		if (any(isnan(EMISSION)) || any(isinf(EMISSION))) {
			EMISSION = vec3(0.0);
		}
		if (any(isnan(RADIANCE.rgb)) || any(isinf(RADIANCE.rgb))) {
			RADIANCE = vec4(env_fallback_color, 1.0);
		}
	} else {
		// --- vista da sott'acqua ---
		vec3 n_up = n_world;               // verso l'aria
		vec3 n_dn = -n_world;              // verso chi guarda
		NORMAL = normalize((VIEW_MATRIX * vec4(n_dn, 0.0)).xyz);
		WaterBody wb = water_body_at(wp, 0.05);
		vec3 absb = wb.found ? wb.absorption : absorption;
		float turb = wb.found ? wb.turbidity : turbidity;
		vec3 fogc = wb.found ? wb.fog_color : scatter_color * 0.05;

		vec3 tdir = refract(vdir, n_dn, WATER_IOR);   // verso l'aria
		float fr;
		if (dot(tdir, tdir) < 1e-4) {
			fr = 1.0;                                // riflessione totale interna
		} else {
			float cos_t = clamp(dot(tdir, n_up), 0.0, 1.0);
			fr = 0.02 + 0.98 * pow(1.0 - cos_t, 5.0);
		}
		// cio' che sta sopra l'acqua: la scena e' gia' nello schermo, la spostiamo con la rifrazione
		vec3 above = vec3(0.0);
		if (fr < 0.999) {
			vec3 tv = normalize((VIEW_MATRIX * vec4(tdir, 0.0)).xyz);
			vec2 auv = view_to_uv(VERTEX + tv * 2.0, PROJECTION_MATRIX);
			auv = mix(SCREEN_UV, auv, 0.35);
			auv = clamp(auv, vec2(0.001), vec2(0.999));
			above = textureLod(screen_tex, auv, 0.0).rgb * underwater_window_strength;
		}
		// riflessione interna: la parte sommersa della scena
		vec3 below = fogc;
		vec3 rd = reflect(vdir, n_dn);
		if (reflection_mode >= 1) {
			vec3 rdv = normalize((VIEW_MATRIX * vec4(rd, 0.0)).xyz);
			vec4 ssr = trace_ssr(VERTEX, rdv, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, -1e6, roughness, 0.0);
			below = mix(below, water_fog(ssr.rgb, 3.0, wb), ssr.a);
		}
		vec3 col = mix(above, below, fr);
		// nebbia e bagliore tra la camera e la superficie
		vec3 sig = absb + vec3(turb);
		vec3 trc = exp(-sig * cam_dist);
		col = col * trc + fogc * (vec3(1.0) - trc);
		col += water_glow_inscatter(cam, vdir, cam_dist, sig, (turb + 0.04) * glow_scatter);
		ALBEDO = vec3(0.0);
		EMISSION = (any(isnan(col)) || any(isinf(col))) ? fogc : col;
		RADIANCE = vec4(0.0, 0.0, 0.0, 1.0);
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
		ALPHA = 1.0;
	}
}
