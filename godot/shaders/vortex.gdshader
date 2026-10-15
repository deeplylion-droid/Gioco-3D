// Gorgo dello scarico: spirale trasparente che gira (grafica provvisoria).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 color : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float arms = 4.0;
uniform float twist = 6.0;
uniform float speed = 3.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float a = atan(p.y, p.x);
	float spiral = sin(a * arms + log(r + 0.02) * twist + TIME * speed);
	float band = smoothstep(0.3, 1.0, spiral);
	float fade = smoothstep(1.0, 0.55, r) * smoothstep(0.0, 0.15, r);
	ALBEDO = color.rgb * (0.6 + 0.4 * band);
	ALPHA = (band * 0.5 + (1.0 - r) * 0.25) * fade * strength;
}
