// Il colore della nebbia viola, alla fine (dopo il tone mapping): un po' di contrasto a "S", le ombre verso il blu viola
// e le luci verso il bianco freddo, la vignetta (ColoreViola di assets_src/nebbia_viola/nebbia_viola.js).
shader_type canvas_item;

uniform sampler2D schermo : hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 ombre = vec3(0.56, 0.54, 1.0);
uniform vec3 luci = vec3(0.84, 0.88, 1.0);
uniform float tinta = 0.9;
uniform float contrasto = 0.45;
uniform float saturazione = 1.0;
uniform float vignetta = 0.5;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 tono_colore(vec3 c) {
	float l = dot(c, LUMA);
	vec3 t = mix(ombre, luci, smoothstep(0.05, 0.7, l));
	t /= max(dot(t, LUMA), 0.001);
	vec3 g = c * t;
	float lg = dot(g, LUMA);
	g = mix(vec3(lg), g, 0.85);
	return pow(max(g, vec3(0.0)), vec3(1.12)) * 0.9;
}

void fragment() {
	vec3 x = clamp(texture(schermo, SCREEN_UV).rgb, 0.0, 1.0);
	float l = dot(x, LUMA);
	x = clamp(mix(vec3(l), x, saturazione), 0.0, 1.0);
	x = mix(x, x * x * (3.0 - 2.0 * x), contrasto);
	x = mix(x, tono_colore(x), tinta);
	vec2 d = SCREEN_UV - 0.5;
	x *= mix(1.0, smoothstep(0.85, 0.25, length(d * vec2(1.0, 0.75))), vignetta);
	COLOR = vec4(x, 1.0);
}
