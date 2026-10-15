// Effetto sott'acqua a schermo intero (Splash Lagoon). Un quad davanti alla camera, disegnato per
// primo tra gli oggetti trasparenti (render_priority minima): legge l'immagine della scena opaca e
// la profondita', e dove il punto vicino alla camera e' sott'acqua applica:
//  - assorbimento e diffusione in base alla distanza (le luci lontane si spengono nel blu/verde);
//  - distorsione ondulata e leggera sfocatura con la distanza;
//  - vignettatura.
// La superficie vista da sotto e gli oggetti trasparenti disegnati dopo si occupano da soli della
// propria nebbia. Sopra l'acqua, dopo un'emersione, simula le gocce che colano sull'obiettivo.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, blend_mix;

#include "res://addons/acqua/shaders/water_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

/** Ampiezza della distorsione (in frazione dello schermo). */
uniform float distortion = 0.006;
/** Moltiplicatore della densita' dell'acqua per la vista da sotto. */
uniform float density = 1.0;
/** Sfocatura con la distanza (livelli di mipmap per metro). */
uniform float blur_per_meter = 0.12;
uniform float vignette = 0.45;
/** Moltiplicatore del bagliore delle luci immerse (WaterGlowLight). */
uniform float glow_scatter = 1.0;
/** 0..1: gocce sull'obiettivo dopo essere riemersi. */
uniform float lens_wet = 0.0;
uniform float camera_near = 0.05;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

vec3 view_from_depth(vec2 uv, float raw, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, raw, 1.0);
	return v.xyz / v.w;
}

// gocce che colano sull'obiettivo: spostamento dell'immagine
vec2 lens_drops(vec2 uv, float t) {
	vec2 offs = vec2(0.0);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 grid = vec2(9.0 + fi * 5.0, 4.0 + fi * 2.0);
		vec2 p = uv * grid;
		vec2 cell = floor(p);
		vec4 rnd = texture(water_noise_tex, (cell + fi * 17.0) / 64.0);
		float speed = 0.15 + rnd.a * 0.5;
		vec2 c = vec2(rnd.b * 0.6 + 0.2, fract(rnd.r * 3.0 + t * speed));
		vec2 d = (fract(p) - c) * vec2(1.0, grid.x / grid.y * 0.6);
		float r = 0.12 + rnd.g * 0.1;
		float drop = smoothstep(r, r * 0.4, length(d));
		// scia sopra la goccia
		float trail = smoothstep(0.05, 0.0, abs(d.x)) * step(0.0, -d.y) * smoothstep(-0.9, 0.0, d.y) * 0.4;
		offs += d * drop * 0.08 + vec2(0.0, trail * 0.004);
	}
	return offs;
}

void fragment() {
	// direzione del raggio e punto vicino alla camera nel mondo
	vec3 ray_v = normalize(view_from_depth(SCREEN_UV, 0.5, INV_PROJECTION_MATRIX));
	vec3 ray_w = normalize((INV_VIEW_MATRIX * vec4(ray_v, 0.0)).xyz);
	vec3 near_w = CAMERA_POSITION_WORLD + ray_w * (camera_near / max(-ray_v.z, 0.1));
	WaterBody b = water_body_at(near_w, 0.0);
	float t = water_time;
	float surf = b.level
			+ 0.012 * sin(near_w.x * 2.1 + t * 1.7) + 0.01 * sin(near_w.z * 2.7 - t * 1.3);
	bool under = b.found && near_w.y < surf;

	if (!under) {
		if (lens_wet <= 0.001) {
			ALPHA = 0.0;
			ALBEDO = vec3(0.0);
		} else {
			vec2 off = lens_drops(SCREEN_UV, t) * lens_wet;
			ALBEDO = textureLod(screen_tex, SCREEN_UV + off, length(off) * 120.0).rgb;
			ALPHA = clamp(length(off) * 400.0, 0.0, 1.0) * lens_wet;
		}
	} else {
		// distorsione ondulata
		vec2 w = vec2(sin(SCREEN_UV.y * 23.0 + t * 1.9) + sin(SCREEN_UV.y * 41.0 - t * 2.7) * 0.5,
				cos(SCREEN_UV.x * 19.0 + t * 1.6) + cos(SCREEN_UV.x * 37.0 + t * 2.3) * 0.5);
		vec2 uv = clamp(SCREEN_UV + w * distortion, vec2(0.001), vec2(0.999));
		float raw = textureLod(depth_tex, uv, 0.0).r;
		float dist = length(view_from_depth(uv, raw, INV_PROJECTION_MATRIX));
		if (raw <= 0.0) {
			dist = 1e3;
		}
		vec3 col = textureLod(screen_tex, uv, clamp(dist * blur_per_meter, 0.0, 4.0)).rgb;
		vec3 sig = (b.absorption + vec3(b.turbidity)) * density;
		vec3 tr = exp(-sig * min(dist, 200.0));
		col = col * tr + b.fog_color * (vec3(1.0) - tr);
		col += water_glow_inscatter(CAMERA_POSITION_WORLD, ray_w, min(dist, 60.0), sig, (b.turbidity + 0.04) * density * glow_scatter);
		// vignettatura
		vec2 q = SCREEN_UV - 0.5;
		col *= 1.0 - vignette * dot(q, q) * 2.0;
		ALBEDO = (any(isnan(col)) || any(isinf(col))) ? b.fog_color : col;
		ALPHA = 1.0;
	}
}
