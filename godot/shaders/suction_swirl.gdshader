// Gorgo sulla superficie da cui lo zaino-pompa aspira: anelli che corrono verso il centro e
// bracci a spirale che girano, visibili soprattutto nei riflessi (normale perturbata).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color : source_color = vec4(0.75, 0.88, 0.95, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float fade = smoothstep(1.0, 0.55, r) * strength;
	// Anelli che si stringono verso il centro e spirale che gira.
	float rings = sin(r * 34.0 + TIME * 11.0);
	float spiral = sin(a * 3.0 + r * 16.0 - TIME * 7.0);
	float h = (rings * 0.6 + spiral * 0.4) * fade;
	vec3 n_tan = normalize(vec3(cos(a) * h * 0.55, 1.0, sin(a) * h * 0.55));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_tan, 0.0)).xyz);
	float foam = smoothstep(0.65, 1.0, spiral) * smoothstep(0.7, 0.1, r) * fade;
	ALBEDO = color.rgb * (0.25 + 0.6 * foam);
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
	ALPHA = clamp(fade * (0.18 + 0.5 * foam + 0.12 * abs(h)), 0.0, 1.0);
}
