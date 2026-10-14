// Funzioni per le superfici che "ricevono" l'acqua: pareti e fondo delle vasche, pavimenti bagnati,
// oggetti immersi. Fornisce:
//  - mappatura triplanare in coordinate del mondo (texture senza UV);
//  - umidita' (pozzanghere, zone umide, banda bagnata sopra il pelo dell'acqua) e cerchi delle gocce;
//  - una funzione di luce che aggiunge caustiche e assorbimento della luce sott'acqua.
// Uso tipico: vedi wet_surface.gdshader.
#ifndef WATER_RECEIVER_INC
#define WATER_RECEIVER_INC

#include "res://water/shaders/water_common.gdshaderinc"

// ---------------------------------------------------------------------------------------------
// Triplanare

vec3 triplanar_weights(vec3 n, float sharpness) {
	vec3 w = pow(abs(n), vec3(sharpness));
	return w / max(w.x + w.y + w.z, 1e-5);
}

vec4 triplanar_sample(sampler2D tex, vec3 p, vec3 w, float scale, vec2 offs) {
	vec4 c = vec4(0.0);
	if (w.x > 0.01) {
		c += texture(tex, vec2(p.z, -p.y) * scale + offs) * w.x;
	}
	if (w.y > 0.01) {
		c += texture(tex, p.xz * scale + offs) * w.y;
	}
	if (w.z > 0.01) {
		c += texture(tex, vec2(p.x, -p.y) * scale + offs) * w.z;
	}
	return c;
}

vec3 decode_normal_map(vec4 t, float strength) {
	vec2 xy = (t.rg * 2.0 - 1.0) * strength;
	return vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.0)));
}

// Normale nel mondo da una normal map (convenzione OpenGL) proiettata sui tre piani.
vec3 triplanar_normal(sampler2D tex, vec3 p, vec3 n_geo, vec3 w, float scale, vec2 offs, float strength) {
	vec3 acc = vec3(0.0);
	if (w.x > 0.01) {
		vec3 t = decode_normal_map(texture(tex, vec2(p.z, -p.y) * scale + offs), strength);
		acc += vec3(sign(n_geo.x) * t.z, t.y, t.x) * w.x;
	}
	if (w.y > 0.01) {
		vec3 t = decode_normal_map(texture(tex, p.xz * scale + offs), strength);
		acc += vec3(t.x, sign(n_geo.y) * t.z, -t.y) * w.y;
	}
	if (w.z > 0.01) {
		vec3 t = decode_normal_map(texture(tex, vec2(p.x, -p.y) * scale + offs), strength);
		acc += vec3(t.x, t.y, sign(n_geo.z) * t.z) * w.z;
	}
	return normalize(acc);
}

// ---------------------------------------------------------------------------------------------
// Umidita'

// Maschera delle pozzanghere: rumore largo + incavi (fughe tra le piastrelle) + quantita'.
float puddle_mask(vec3 wp, float height01, float amount, float scale, float up) {
	if (amount <= 0.0 || up < 0.6) {
		return 0.0;
	}
	float n = texture(water_noise_tex, wp.xz * scale).r;
	float n2 = texture(water_noise_tex, wp.xz * scale * 3.7 + vec2(0.37, 0.11)).g;
	float field = n * 0.75 + n2 * 0.25 + (1.0 - height01) * 0.12;
	float thr = 1.0 - amount * 0.75;
	return smoothstep(thr, thr + 0.05, field) * smoothstep(0.6, 0.9, up);
}

// ---------------------------------------------------------------------------------------------
// Luce: diffusa + GGX come Godot, con caustiche e assorbimento quando il punto e' sott'acqua.

// come in Godot, D e V sono limitati al massimo dei float a 16 bit (niente infiniti nei buffer)
float wr_d_ggx(float n_dot_h, float a) {
	float a2 = a * a;
	float d = n_dot_h * n_dot_h * (a2 - 1.0) + 1.0;
	return min(a2 / (PI * d * d + 1e-7), 65000.0);
}

float wr_v_ggx(float n_dot_l, float n_dot_v, float a) {
	return min(0.5 / max(mix(2.0 * n_dot_l * n_dot_v, n_dot_l + n_dot_v, a), 1e-6), 65000.0);
}

// depth_below: profondita' del punto sotto il pelo dell'acqua (<= 0 se all'asciutto).
// Restituisce il moltiplicatore della luce (caustiche * assorbimento lungo il tragitto in acqua).
vec3 water_light_modulation(vec3 light_world, vec3 wpos, float depth_below, vec3 absorption, float turbidity,
		float caustics_amount, float caustics_scale, float lod) {
	// luce che sta dentro l'acqua (WaterGlowLight): niente caustiche, solo assorbimento sul tragitto
	float glow_r = water_glow_light_distance(wpos, normalize(light_world));
	if (glow_r > 0.0) {
		float in_water = depth_below > 0.0 ? glow_r : 0.0;
		if (depth_below <= 0.0) {
			// punto all'asciutto illuminato da sotto la superficie: tratto in acqua approssimato
			in_water = min(glow_r, 0.6);
		}
		return water_transmittance(absorption, turbidity * 0.35, in_water);
	}
	if (depth_below <= 0.0) {
		return vec3(1.0);
	}
	if (light_world.y <= 0.02) {
		// luce radente o da sotto: niente caustiche, solo assorbimento su un tratto lungo
		return water_transmittance(absorption, turbidity, depth_below * 6.0);
	}
	vec3 lw = refract(-normalize(light_world), vec3(0.0, 1.0, 0.0), 1.0 / WATER_IOR);
	float up_len = depth_below / max(-lw.y, 0.2);
	vec2 surf = wpos.xz - lw.xz * up_len;
	vec3 caus = water_caustics(surf, depth_below, caustics_scale, lod);
	vec3 tr = water_transmittance(absorption, turbidity * 0.35, up_len);
	return max(mix(vec3(1.0), caus, caustics_amount), vec3(0.0)) * tr;
}

#endif
