// Spruzzo nebulizzato (sbuffi di vapore d'acqua di schizzi e getti). Sprite morbido sempre rivolto
// alla camera, illuminato dalle luci della scena con una diffusione "avvolgente" e controluce,
// che sfuma vicino alle superfici (particelle morbide) e con la vita della particella.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://addons/acqua/shaders/water_common.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 tint : source_color = vec3(0.8, 0.85, 0.88);
uniform float density : hint_range(0.0, 2.0) = 0.5;
uniform float soft_distance = 0.4;
/** Distanza dalla camera (m) sotto cui lo sbuffo sparisce: si rimpicciolisce da 2 volte questa
 *  distanza fino a zero (niente sbuffi a tutto schermo davanti alla camera). 0: spento. */
uniform float near_camera = 0.0;

varying float v_seed;

void vertex() {
	v_seed = INSTANCE_CUSTOM.x;
	// billboard con la scala della particella
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	if (near_camera > 0.0) {
		s *= smoothstep(near_camera, near_camera * 2.0, distance(CAMERA_POSITION_WORLD, MODEL_MATRIX[3].xyz));
	}
	mv = mv * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = mv;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float puff = texture(water_noise_tex, UV * 0.35 + vec2(v_seed * 7.0, water_time * 0.03)).g;
	float shape = (1.0 - smoothstep(0.2, 1.0, r)) * (0.55 + 0.9 * puff);
	float raw = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float scene_z = sv.z / sv.w;
	float soft = clamp((VERTEX.z - scene_z) / soft_distance, 0.0, 1.0);
	ALBEDO = tint;
	BACKLIGHT = tint * 0.6;
	ROUGHNESS = 1.0;
	ALPHA = clamp(shape * density * soft * COLOR.a, 0.0, 1.0);
}
