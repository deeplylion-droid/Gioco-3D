// Occhio della medusa: texture calma e texture venata (versione malvagia) mescolate da "venatura".
// venatura = 0: occhio calmo (come nel glTF); 1: capillari rossi, sclera ingiallita, iride piu' accesa.
// In gioco si puo' animare (per esempio da 0 a 1 quando attacca) con set_shader_parameter("venatura", v).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_calmo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_venato : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float venatura : hint_range(0.0, 1.0) = 0.0;
uniform float ruvidita : hint_range(0.0, 1.0) = 0.3;
uniform float luce_propria : hint_range(0.0, 2.0) = 0.22;

void fragment() {
	vec3 c = mix(texture(tex_calmo, UV).rgb, texture(tex_venato, UV).rgb, venatura);
	ALBEDO = c;
	ROUGHNESS = ruvidita;
	SPECULAR = 0.5;
	EMISSION = c * luce_propria;
}
