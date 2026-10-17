// Goccia chiara per gli schizzi d'impatto (copia di addons/acqua water_droplet.gdshader): la goccia
// rifratta dell'addon contro un muro scuro quasi non si vede; questa ha un bianco-azzurro lucido.
// Quad rivolto alla camera che ruota solo attorno al proprio asse Y: con la particella allineata
// alla velocita' (ParticleProcessMaterial.particle_flag_align_y) la goccia si allunga nel verso del
// moto. La normale e' quella di un ellissoide, cosi' le luci (anche le rosse d'emergenza) fanno il
// riflesso; il centro rifrange lo sfondo.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_occlusion_disabled, skip_vertex_transform;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(0.75, 0.82, 0.85);
/** Opacita' complessiva (le gocce piccole e lontane vanno tenute leggere). */
uniform float opacity : hint_range(0.0, 1.0) = 0.75;
uniform float refraction = 0.012;
uniform float rim_light = 0.25;

varying vec3 v_axis_x;
varying vec3 v_axis_y;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 yaxis = MODEL_MATRIX[1].xyz;
	float ylen = length(yaxis);
	vec3 y = ylen > 1e-5 ? yaxis / ylen : vec3(0.0, 1.0, 0.0);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - center);
	vec3 x = cross(y, to_cam);
	if (length(x) < 1e-4) {
		x = INV_VIEW_MATRIX[0].xyz;
	}
	x = normalize(x);
	float sx = length(MODEL_MATRIX[0].xyz);
	vec3 wp = center + x * VERTEX.x * sx + y * VERTEX.y * ylen;
	v_axis_x = x;
	v_axis_y = y;
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(to_cam, 0.0)).xyz;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float inside = 1.0 - smoothstep(0.75, 1.0, r2);
	float z = sqrt(max(1.0 - min(r2, 1.0), 0.0));
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	vec3 n_world = normalize(v_axis_x * p.x + v_axis_y * (-p.y) + to_cam * z);
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	vec3 bg = textureLod(screen_tex, SCREEN_UV - p * refraction, 0.0).rgb;
	float fres = pow(1.0 - z, 3.0);
	ALBEDO = tint * 0.55;
	EMISSION = bg * 0.45 * (1.0 - fres) + tint * (0.12 + fres * rim_light * 0.4);
	ROUGHNESS = 0.05;
	SPECULAR = 0.5;
	METALLIC = 0.0;
	ALPHA = inside * opacity * COLOR.a * (0.55 + 0.45 * fres);
}
