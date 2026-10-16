shader_type spatial;
// L'alone delle micro medusine (scripts/game/medusine.gd): la loro luce sparsa dall'acqua torbida,
// un disco morbido rivolto alla camera. Più sono in fondo, più è largo e fioco (lo calcola lo
// script). Additivo e senza test di profondità, come le medusine; lo coprono solo le cose opache
// che stanno chiaramente davanti (il fondo e le pareti vicine no: è luce nell'acqua intorno).
// Istanza: COLOR.rgb colore già attenuato, COLOR.a intensità.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

#include "res://addons/acqua/shaders/water_common.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform float luminosita = 0.7;
// Di quanto la scena può stare davanti all'alone prima di coprirlo (m).
uniform float tolleranza = 0.12;

varying vec4 v_col;
varying vec3 v_world;

void vertex() {
	// sempre rivolto alla camera, con la scala dell'istanza
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_col = COLOR;
	v_world = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d2 = dot(q, q);
	if (d2 >= 1.0 || v_col.a <= 0.001 || water_reflection_clip(v_world, CAMERA_VISIBLE_LAYERS, CAMERA_POSITION_WORLD)) {
		discard;
	}
	float a = exp(-d2 * 4.5) * (1.0 - d2);
	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float scene_dist = -sv.z / sv.w;
	a *= clamp((scene_dist + VERTEX.z + tolleranza) / tolleranza, 0.0, 1.0);
	ALBEDO = v_col.rgb * luminosita;
	ALPHA = clamp(a * v_col.a, 0.0, 1.0);
}
