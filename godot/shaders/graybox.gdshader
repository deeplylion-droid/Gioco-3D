// Materiale da graybox: colore piatto con una griglia di 1 m in coordinate del mondo,
// così si leggono le distanze. Proiezione triplanare: va bene su qualsiasi forma.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 line_color : source_color = vec4(0.36, 0.36, 0.36, 1.0);
uniform float grid_size = 1.0;
uniform float line_width : hint_range(0.001, 0.2) = 0.025;
uniform float sub_lines : hint_range(0.0, 1.0) = 0.35; // intensità delle linee ogni 0,25 m
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
uniform float specular_value : hint_range(0.0, 1.0) = 0.5;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_lines(vec2 p, float size, float width) {
	vec2 q = p / size;
	vec2 d = abs(fract(q - 0.5) - 0.5) * size;
	vec2 aa = fwidth(p) * 1.2;
	vec2 l = 1.0 - smoothstep(vec2(width * 0.5), vec2(width * 0.5) + aa, d);
	return max(l.x, l.y);
}

float plane_grid(vec2 p) {
	float main_l = grid_lines(p, grid_size, line_width);
	float sub_l = grid_lines(p, grid_size * 0.25, line_width * 0.5) * sub_lines;
	return max(main_l, sub_l);
}

void fragment() {
	vec3 n = abs(world_normal);
	float g;
	if (n.x >= n.y && n.x >= n.z) {
		g = plane_grid(world_pos.zy);
	} else if (n.y >= n.z) {
		g = plane_grid(world_pos.xz);
	} else {
		g = plane_grid(world_pos.xy);
	}
	ALBEDO = mix(base_color.rgb, line_color.rgb, g);
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	EMISSION = emission_color.rgb * emission_energy;
}
