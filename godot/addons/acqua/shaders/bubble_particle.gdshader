// Bollicina d'aria sott'acqua: quad sempre rivolto alla camera, bordo luminoso (riflessione totale)
// e centro trasparente che lascia vedere lo sfondo leggermente spostato.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec3 rim_color : source_color = vec3(0.75, 0.9, 1.0);
uniform float rim_strength = 1.4;

void vertex() {
	// billboard che conserva la scala della particella
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mv = mv * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = mv;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = min(length(p), 1.0);
	float z = sqrt(1.0 - r * r);
	float rim = pow(1.0 - z, 3.0);
	vec2 refr = SCREEN_UV - p * 0.01;
	vec3 bg = textureLod(screen_tex, refr, 0.0).rgb;
	float spec = smoothstep(0.75, 0.95, 1.0 - length(p - vec2(-0.35, -0.35)));
	ALBEDO = bg * 0.9 + rim_color * (rim * rim_strength + spec * 2.0) * COLOR.a;
	ALPHA = clamp(0.25 + rim + spec, 0.0, 1.0) * smoothstep(1.0, 0.85, r);
}
