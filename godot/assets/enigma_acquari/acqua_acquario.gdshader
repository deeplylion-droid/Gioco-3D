// L'acqua di un acquario vista attraverso i vetri (lati e fondo di una scatola, senza il coperchio:
// il pelo dell'acqua lo fa la WaterBody dell'addon acqua). Stessa luce della superficie
// (water_surface.gdshader): trasmissione di Beer-Lambert con absorption + turbidity, colore diffuso
// scatter_color illuminato dalle luci e un poco di luce propria (scatter_ambient).
// Lo spessore attraversato si calcola nello spazio locale della scatola (centrata, lato `box_size`)
// e si taglia con la profondità della scena (oggetti immersi) e con il livello dell'acqua.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, specular_schlick_ggx;

uniform vec3 box_size = vec3(1.0, 1.0, 1.0);
uniform bool cylinder = false;           // cilindro verticale di diametro box_size.x
uniform float level_local = 0.5;          // quota del pelo rispetto al centro della scatola
uniform vec3 absorption = vec3(0.45, 0.10, 0.07);
uniform float turbidity : hint_range(0.0, 6.0) = 0.06;
uniform vec3 scatter_color : source_color = vec3(0.10, 0.45, 0.55);
uniform float scatter_ambient : hint_range(0.0, 2.0) = 0.02;
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.02;
uniform float particles : hint_range(0.0, 1.0) = 0.3;   // sospensione sporca (puntini)

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 v_local;
varying vec3 v_cam_local;

void vertex() {
	v_local = VERTEX;
	v_cam_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	vec3 h = vec3(box_size.x, box_size.y, box_size.z) * 0.5;
	vec3 ro = v_local;
	vec3 rd = normalize(v_local - v_cam_local);
	// uscita dalla scatola (il tetto è il pelo dell'acqua)
	vec3 bmax = vec3(h.x, min(h.y, level_local), h.z);
	vec3 bmin = -h;
	vec3 inv = 1.0 / rd;
	vec3 t1 = (bmin - ro) * inv;
	vec3 t2 = (bmax - ro) * inv;
	float t_exit = min(min(max(t1.x, t2.x), max(t1.y, t2.y)), max(t1.z, t2.z));
	if (cylinder) {
		// uscita dal cilindro (pianta) e dalle due basi
		float r = h.x;
		vec2 o2 = ro.xz;
		vec2 d2 = rd.xz;
		float a = dot(d2, d2);
		float b = dot(o2, d2);
		float c = dot(o2, o2) - r * r;
		float disc = max(b * b - a * c, 0.0);
		float tc = (-b + sqrt(disc)) / max(a, 1e-5);
		t_exit = min(tc, max(t1.y, t2.y));
	}
	// tagliata dagli oggetti dentro (profondità della scena), in metri lungo il raggio
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float scene_dist = length(vp.xyz);
	float frag_dist = length(VERTEX);
	float scale = length(MODEL_MATRIX[0].xyz);
	float path = clamp(min(t_exit * scale, scene_dist - frag_dist), 0.0, 20.0);
	// sopra il pelo non c'è acqua
	if (v_local.y > level_local + 0.001) {
		discard;
	}
	vec3 sigma_t = absorption + vec3(turbidity);
	vec3 tr = exp(-sigma_t * path);
	// rifrazione leggera: lo sfondo si sposta con la normale della faccia
	vec2 off = (VIEW * NORMAL).xy * refraction_strength * min(path, 1.0);
	vec3 behind = textureLod(screen_tex, SCREEN_UV - off, 0.0).rgb;
	// puntini in sospensione
	vec3 cell = floor(v_local * 60.0 + vec3(0.0, TIME * 0.4, 0.0));
	float dot_ = step(0.985, hash(cell)) * particles;
	vec3 inscatter = scatter_color * (vec3(1.0) - tr);
	ALBEDO = inscatter + vec3(dot_) * 0.15;
	ROUGHNESS = 0.2;
	SPECULAR = 0.3;
	ALPHA = 1.0;
	EMISSION = behind * tr + scatter_color * scatter_ambient * (vec3(1.0) - tr);
}
