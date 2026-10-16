#[compute]
#version 450
// Simulazione delle increspature (equazione delle onde 2D) per WaterRippleSim.
// Stato in RGBA32F: R = altezza attuale (m), G = altezza al passo precedente, B = schiuma (0..1).
// Ogni passo legge `src` e scrive `dst`; gli impulsi (oggetti, giocatore, getto, gocce) sono in un buffer.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f, set = 0, binding = 0) uniform restrict readonly image2D src;
layout(rgba32f, set = 1, binding = 0) uniform restrict writeonly image2D dst;
layout(set = 2, binding = 0, std430) restrict readonly buffer Impulses {
	// per impulso: vec4(x texel, y texel, raggio in texel, ampiezza in m), vec4(schiuma, 0, 0, 0)
	vec4 data[];
} impulses;

layout(push_constant, std430) uniform Params {
	vec4 a; // dimensione x, dimensione y, courant^2, smorzamento per passo
	vec4 b; // decadimento schiuma, schiuma da movimento, numero impulsi, diffusione schiuma
} params;

void main() {
	ivec2 size = ivec2(params.a.xy);
	ivec2 p = ivec2(gl_GlobalInvocationID.xy);
	if (p.x >= size.x || p.y >= size.y) {
		return;
	}
	ivec2 lo = ivec2(0);
	ivec2 hi = size - ivec2(1);
	vec4 c = imageLoad(src, p);
	vec4 l = imageLoad(src, clamp(p - ivec2(1, 0), lo, hi));
	vec4 r = imageLoad(src, clamp(p + ivec2(1, 0), lo, hi));
	vec4 d = imageLoad(src, clamp(p - ivec2(0, 1), lo, hi));
	vec4 u = imageLoad(src, clamp(p + ivec2(0, 1), lo, hi));

	float h = c.r;
	float h_prev = c.g;
	float lap = l.r + r.r + d.r + u.r - 4.0 * h;
	float h_new = (2.0 * h - h_prev + params.a.z * lap);
	// smorzamento: attenua l'onda e la sua velocita'
	h_new = h + (h_new - h) * (1.0 - params.a.w) - h * params.a.w * 0.02;

	// schiuma: decade, si allarga un poco, nasce dove l'acqua si muove in fretta
	float foam_avg = (l.b + r.b + d.b + u.b) * 0.25;
	float foam = mix(c.b, foam_avg, params.b.w) * params.b.x;
	foam += abs(h_new - h) * params.b.y;

	int count = int(params.b.z);
	for (int i = 0; i < count; i++) {
		vec4 imp = impulses.data[i * 2];
		vec4 extra = impulses.data[i * 2 + 1];
		vec2 dv = vec2(p) + 0.5 - imp.xy;
		float dist = length(dv);
		if (dist < imp.z) {
			float k = 0.5 + 0.5 * cos(3.14159265 * dist / imp.z);
			h_new += imp.w * k;
			foam += extra.x * k;
		}
	}
	h_new = clamp(h_new, -0.5, 0.5);
	imageStore(dst, p, vec4(h_new, h, clamp(foam, 0.0, 1.0), 1.0));
}
