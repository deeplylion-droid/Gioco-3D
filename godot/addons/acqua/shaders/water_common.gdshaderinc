// Funzioni comuni dell'acqua (Jilly Jubilee).
// Richiede le variabili globali degli shader definite in project.godot (sezione [shader_globals])
// e l'autoload WaterManager che le aggiorna. Vedi labs/acqua/README.md.
#ifndef WATER_COMMON_INC
#define WATER_COMMON_INC

global uniform float water_time;
global uniform int water_body_count;
global uniform sampler2D water_bodies_tex;
global uniform sampler3D water_caustics_tex;
global uniform sampler2D water_noise_tex;
global uniform sampler2D water_ripple_tex : filter_linear, repeat_disable;
global uniform vec4 water_ripple_rect;
global uniform sampler2D water_drops_tex;
global uniform int water_drop_count;
global uniform int water_quality;
global uniform sampler2D water_glow_tex;
global uniform int water_glow_count;

const float WATER_IOR = 1.333;
const int WATER_MAX_BODIES = 12;

// Dati di una massa d'acqua letti dalla tabella globale (4 texel per vasca).
struct WaterBody {
	bool found;
	vec4 rect;          // min x, min z, max x, max z
	float level;        // quota della superficie (m)
	float wet_level;    // fin dove le pareti sono ancora bagnate (m)
	float caustics;     // intensita' delle caustiche
	float caustics_scale; // metri per ripetizione del motivo
	vec3 absorption;    // assorbimento del volume (1/m)
	float turbidity;    // diffusione (1/m)
	vec3 fog_color;     // colore della nebbia sott'acqua (luce diffusa)
	float bottom;       // quota del fondo piu' profondo
};

WaterBody water_body_at(vec3 wp, float margin) {
	WaterBody b;
	b.found = false;
	b.rect = vec4(0.0);
	b.level = -1e6;
	b.wet_level = -1e6;
	b.caustics = 0.0;
	b.caustics_scale = 2.0;
	b.absorption = vec3(0.3, 0.08, 0.05);
	b.turbidity = 0.05;
	b.fog_color = vec3(0.0);
	b.bottom = -1e6;
	for (int i = 0; i < WATER_MAX_BODIES; i++) {
		if (i >= water_body_count) {
			break;
		}
		vec4 r = texelFetch(water_bodies_tex, ivec2(i * 4, 0), 0);
		if (wp.x >= r.x - margin && wp.x <= r.z + margin && wp.z >= r.y - margin && wp.z <= r.w + margin) {
			vec4 a = texelFetch(water_bodies_tex, ivec2(i * 4 + 1, 0), 0);
			vec4 c = texelFetch(water_bodies_tex, ivec2(i * 4 + 2, 0), 0);
			vec4 d = texelFetch(water_bodies_tex, ivec2(i * 4 + 3, 0), 0);
			// sotto il fondo di una vasca rialzata (gli acquari dell'enigma) non si è dentro: il
			// pavimento sotto e intorno non prende caustiche né colore
			if (wp.y < d.a - 0.25) {
				continue;
			}
			b.found = true;
			b.rect = r;
			b.level = a.x;
			b.wet_level = a.y;
			b.caustics = a.z;
			b.caustics_scale = max(a.w, 0.05);
			b.absorption = c.rgb;
			b.turbidity = c.a;
			b.fog_color = d.rgb;
			b.bottom = d.a;
			return b;
		}
	}
	return b;
}

// Layer di rendering della superficie dell'acqua (WaterBody.WATER_LAYER = layer 20).
const uint WATER_LAYER_BIT = 1u << 19u;

// Vero se il frammento va scartato perche' siamo nella passata del riflesso planare (camera
// speculare sotto il pelo dell'acqua, che non vede l'acqua) e il punto e' sott'acqua.
bool water_reflection_clip(vec3 wp, uint visible_layers, vec3 cam_pos) {
	if ((visible_layers & WATER_LAYER_BIT) != 0u) {
		return false;
	}
	WaterBody b = water_body_at(wp, 0.1);
	return b.found && cam_pos.y < b.level && wp.y < b.level - 0.005;
}

// Altezza delle increspature interattive (m) in un punto in pianta; 0 fuori dalla simulazione.
// `rect` = (min x, min z, larghezza, profondita') del rettangolo simulato.
float water_ripple_height_tex(sampler2D tex, vec4 rect, vec2 xz) {
	if (rect.z <= 0.0) {
		return 0.0;
	}
	vec2 uv = (xz - rect.xy) / rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	float h = textureLod(tex, uv, 0.0).r;
	return (isnan(h) || isinf(h)) ? 0.0 : h;
}

// Pendenza (dh/dx, dh/dz), curvatura (laplaciano, 1/m) e schiuma della simulazione.
// Restituisce vec4(dhdx, dhdz, laplaciano, schiuma).
vec4 water_ripple_sample_tex(sampler2D tex, vec4 rect, vec2 xz) {
	if (rect.z <= 0.0) {
		return vec4(0.0);
	}
	vec2 uv = (xz - rect.xy) / rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	vec2 tsize = vec2(textureSize(tex, 0));
	if (tsize.x < 2.0 || tsize.y < 2.0) {
		return vec4(0.0); // simulazione non ancora pronta (texture segnaposto)
	}
	vec2 texel = 1.0 / tsize;
	vec2 cell = rect.zw * texel; // metri per texel
	vec4 c = textureLod(tex, uv, 0.0);
	float hl = textureLod(tex, uv - vec2(texel.x, 0.0), 0.0).r;
	float hr = textureLod(tex, uv + vec2(texel.x, 0.0), 0.0).r;
	float hd = textureLod(tex, uv - vec2(0.0, texel.y), 0.0).r;
	float hu = textureLod(tex, uv + vec2(0.0, texel.y), 0.0).r;
	vec2 slope = vec2((hr - hl) / (2.0 * cell.x), (hu - hd) / (2.0 * cell.y));
	float lap = (hl + hr - 2.0 * c.r) / (cell.x * cell.x) + (hu + hd - 2.0 * c.r) / (cell.y * cell.y);
	// i bordi della simulazione sfumano a zero
	float edge = smoothstep(0.0, 0.02, min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y)));
	vec4 r = vec4(slope, lap, c.b) * edge;
	return (any(isnan(r)) || any(isinf(r))) ? vec4(0.0) : r;
}

// Versioni che usano la simulazione "attiva" (quella della vasca piu' vicina alla camera),
// scelta da WaterManager: servono alle caustiche dei materiali delle vasche.
float water_ripple_height(vec2 xz) {
	return water_ripple_height_tex(water_ripple_tex, water_ripple_rect, xz);
}

vec4 water_ripple_sample(vec2 xz) {
	return water_ripple_sample_tex(water_ripple_tex, water_ripple_rect, xz);
}

// Un campione del volume di caustiche (media 1, valori fino a 5).
float water_caustics_raw(vec2 p, float t, float lod) {
	float v = textureLod(water_caustics_tex, vec3(p, t), lod).r;
	return v * v * 5.0;
}

// Caustiche (moltiplicatore della luce, media circa 1) nel punto `surf_xz` della superficie
// da cui arriva la luce, a profondita' `depth` sotto il pelo dell'acqua.
// `lod`: livello di mipmap di base (si sfoca da solo con la profondita').
vec3 water_caustics(vec2 surf_xz, float depth, float scale, float lod) {
	float t = water_time * 0.22;
	// le increspature interattive spostano e concentrano la luce
	vec4 rs = water_ripple_sample(surf_xz);
	surf_xz -= rs.xy * depth * 0.25;
	float rip = clamp(1.0 - depth * 0.25 * rs.z * 0.35, 0.25, 3.0);

	// distorsione larga e lenta: il motivo (periodico) non si legge piu' come una rete regolare
	vec2 wq = surf_xz / scale;
	// (textureLod: questa funzione gira anche dentro light(), senza derivate affidabili)
	vec2 warp = vec2(textureLod(water_noise_tex, wq * 0.21 + vec2(t * 0.11, 0.0), 0.0).r,
			textureLod(water_noise_tex, wq * 0.21 + vec2(0.43, 0.71) - vec2(0.0, t * 0.09), 0.0).r) - 0.5;
	vec2 p1 = wq + warp * 0.9;
	vec2 p2 = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * (wq / 1.37 - warp * 0.7) + vec2(0.31, 0.77);
	float blur = lod + clamp(depth - 2.0, 0.0, 6.0) * 0.45;
	// sul bagnasciuga le onde non hanno spazio per concentrare la luce: le caustiche nascono
	// con la profondita'; a chiazze piu' e meno intense
	float focus = smoothstep(0.03, 0.6, depth);
	focus *= 0.55 + 0.9 * textureLod(water_noise_tex, wq * 0.13 + vec2(0.2, t * 0.05), 0.0).r;
	vec3 c;
	if (water_quality >= 2) {
		// dispersione: i tre colori arrivano in punti appena diversi (piu' separati in profondita')
		vec2 k = vec2(0.0035, 0.0022) * min(depth, 3.0);
		float r1 = water_caustics_raw(p1 - k, t, blur);
		float g1 = water_caustics_raw(p1, t, blur);
		float b1 = water_caustics_raw(p1 + k, t, blur);
		float l2 = water_caustics_raw(p2, t * 0.83 + 0.5, blur + 0.5);
		c = vec3(r1, g1, b1) * mix(1.0, l2, 0.5);
	} else if (water_quality == 1) {
		float l1 = water_caustics_raw(p1, t, blur);
		float l2 = water_caustics_raw(p2, t * 0.83 + 0.5, blur + 0.5);
		c = vec3(l1 * mix(1.0, l2, 0.5));
	} else {
		c = vec3(water_caustics_raw(p1, t, blur + 0.5));
	}
	return mix(vec3(1.0), c * rip, focus);
}

// Trasmittanza dell'acqua su un tratto lungo `dist` metri.
vec3 water_transmittance(vec3 absorption, float turbidity, float dist) {
	return exp(-(absorption + vec3(turbidity)) * max(dist, 0.0));
}

// Nebbia sott'acqua su un colore visto a `dist` metri.
vec3 water_fog(vec3 color, float dist, WaterBody b) {
	vec3 tr = water_transmittance(b.absorption, b.turbidity, dist);
	return color * tr + b.fog_color * (vec3(1.0) - tr);
}

// Quanto e' bagnata una parete sopra il pelo dell'acqua (0..1): la banda tra il livello
// attuale e il livello massimo recente si asciuga dall'alto verso il basso.
float water_wet_band(WaterBody b, float y) {
	if (!b.found || y < b.level) {
		return 0.0;
	}
	float span = max(b.wet_level - b.level, 0.002);
	float w = 1.0 - clamp((y - b.level) / span, 0.0, 1.0);
	// sottile strato d'acqua che risale per capillarita' subito sopra la superficie
	float meniscus = 1.0 - smoothstep(0.0, 0.04, y - b.level);
	return max(w * w * 0.9 + 0.1 * w, meniscus) * step(y, b.wet_level + 0.04);
}

// Cerchi delle gocce (impatti registrati da WaterManager.add_drop_ring).
// Restituisce vec3(pendenza x, pendenza z, intensita' degli anelli).
vec3 water_drop_rings(vec2 p) {
	vec2 slope = vec2(0.0);
	float energy = 0.0;
	for (int i = 0; i < 24; i++) {
		if (i >= water_drop_count) {
			break;
		}
		vec4 d = texelFetch(water_drops_tex, ivec2(i, 0), 0);
		float age = water_time - d.z;
		if (age < 0.0 || age > 1.4) {
			continue;
		}
		vec2 dv = p - d.xy;
		float r = length(dv);
		float radius = 0.02 + age * 0.32;
		if (r > radius + 0.06) {
			continue;
		}
		float fade = (1.0 - age / 1.4);
		fade *= fade * d.w;
		float x = (r - radius) / 0.022;
		// pacchetto d'onda: due o tre creste concentriche
		float dh = cos(x * 3.1) * exp(-x * x * 0.35) * fade;
		slope += normalize(dv + vec2(1e-5)) * dh;
		energy += abs(dh);
	}
	return vec3(slope * 0.35, energy);
}

// ---------------------------------------------------------------------------------------------
// Luci dentro l'acqua (WaterGlowLight): bagliore diffuso nel volume.

// Luce diffusa verso l'osservatore lungo il segmento o + d*t, t in [0, len] (d normalizzata),
// dentro un'acqua con estinzione `sigma_t` e diffusione `sigma_s`. Integrale analitico della
// diffusione singola di una luce puntiforme (approssimazione con l'arcotangente).
vec3 water_glow_inscatter(vec3 o, vec3 d, float len, vec3 sigma_t, float sigma_s) {
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		if (i >= water_glow_count) {
			break;
		}
		vec4 a = texelFetch(water_glow_tex, ivec2(i * 2, 0), 0);
		vec4 c = texelFetch(water_glow_tex, ivec2(i * 2 + 1, 0), 0);
		vec3 ol = a.xyz - o;
		float t0 = dot(ol, d);
		// la sorgente non e' un punto (campana della medusa): niente picco infinito vicino alla luce
		float h = max(length(ol - d * t0), max(0.04, a.w * 0.05));
		float ang = atan((len - t0) / h) + atan(t0 / h);
		float tc = clamp(t0, 0.0, len);
		float dc = length(o + d * tc - a.xyz);
		float fade = 1.0 - smoothstep(a.w * 0.4, a.w, dc);
		vec3 ext = exp(-sigma_t * (tc + dc));
		acc += c.rgb * (ang / h) * ext * fade;
	}
	return acc * sigma_s * 0.0796; // 1 / (4 pi)
}

// Se la direzione verso la luce coincide con una WaterGlowLight, restituisce la sua distanza
// (altrimenti -1). Serve alla funzione di luce per riconoscere le luci che stanno in acqua.
float water_glow_light_distance(vec3 wp, vec3 light_dir_world) {
	for (int i = 0; i < 4; i++) {
		if (i >= water_glow_count) {
			break;
		}
		vec3 lp = texelFetch(water_glow_tex, ivec2(i * 2, 0), 0).xyz;
		vec3 dl = lp - wp;
		float r = length(dl);
		if (r > 1e-3 && dot(dl / r, light_dir_world) > 0.9993) {
			return r;
		}
	}
	return -1.0;
}

// Riflettanza totale dell'acqua (Fresnel mediato sulla rugosita'), F0 = 0.02.
float water_env_fresnel(float roughness, float n_dot_v) {
	const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
	const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
	vec4 r = roughness * c0 + c1;
	float a004 = min(r.x * r.x, exp2(-9.28 * n_dot_v)) * r.x + r.y;
	vec2 ab = vec2(-1.04, 1.04) * a004 + r.zw;
	return clamp(0.02 * ab.x + ab.y, 0.0, 1.0);
}

#endif
