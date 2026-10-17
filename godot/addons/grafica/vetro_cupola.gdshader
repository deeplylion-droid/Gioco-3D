// Vetro della cupola: scuro, lucido, con i rivoli di pioggia che scendono.
// "lampo" lo muove il nodo Tempesta: il vetro bagnato si accende un poco col lampo.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

uniform vec3 colore : source_color = vec3(0.05, 0.065, 0.08);
uniform float opacita = 0.14;
uniform float pioggia = 1.0;
uniform float lampo = 0.0;
uniform vec3 colore_lampo : source_color = vec3(0.72, 0.8, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }

// Gocce che scendono in colonne (coordinate: x = intorno alla cupola, y = in alto).
float rivoli(vec2 uv, float t) {
	vec2 cella = vec2(floor(uv.x), 0.0);
	float h = hash(cella);
	float y = uv.y + t * (0.4 + h * 0.8) + h * 10.0;
	vec2 f = vec2(fract(uv.x) - 0.5, fract(y) - 0.5);
	float goccia = smoothstep(0.12, 0.0, length(f * vec2(1.0, 2.2)));
	float scia = smoothstep(0.05, 0.0, abs(f.x)) * smoothstep(-0.5, 0.4, f.y) * 0.35;
	return (goccia + scia) * step(0.35, hash(cella + floor(y)));
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = vec2(atan(wp.x, wp.z) * 40.0, wp.y * 6.0);
	float r = (rivoli(uv, TIME) + rivoli(uv * 1.7 + 3.1, TIME * 1.3) * 0.6) * pioggia;
	// Prova della v0.3.2 ("nella cupola aperta si vedono dei puntini bianchi che appaiono e spariscono"):
	// da terra le gocce sono più piccole di un pixel e i loro riflessi (vetro quasi a specchio, normale
	// piegata dalla goccia) accendevano e spegnevano pixel isolati. Dove una goccia è più piccola di
	// circa due pixel i rivoli sfumano, e le gocce non piegano più la normale né lucidano il vetro.
	float cella_px = 1.0 / max(fwidth(uv.y), 1e-4);
	r *= smoothstep(1.5, 4.0, cella_px);
	ALBEDO = colore;
	ALPHA = clamp(opacita + r * 0.25, 0.0, 1.0);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	EMISSION = colore_lampo * lampo * (0.02 + r * 0.3);
}
