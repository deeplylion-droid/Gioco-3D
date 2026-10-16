// Post-processing finale sopra il 3D: aberrazione cromatica, vignettatura,
// gamma della calibrazione e grana della pellicola. Lo usa l'autoload Grafica.
shader_type canvas_item;

uniform sampler2D schermo : hint_screen_texture, filter_linear;
uniform float gamma = 1.0;          // >1 schiarisce le ombre (schermata di calibrazione)
uniform float grana = 1.0;          // 0 spenta, 1 normale
uniform float forza_grana = 0.045;
uniform float vignetta = 1.0;
uniform float forza_vignetta = 0.3;
uniform float aberrazione = 1.0;
uniform float forza_aberrazione = 0.0035;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	vec3 c;
	if (aberrazione > 0.0) {
		// Più forte verso i bordi, quasi nulla al centro.
		vec2 off = d * dot(d, d) * 4.0 * forza_aberrazione * aberrazione;
		c.r = texture(schermo, uv + off).r;
		c.g = texture(schermo, uv).g;
		c.b = texture(schermo, uv - off).b;
	} else {
		c = texture(schermo, uv).rgb;
	}
	float asp = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(d * vec2(asp, 1.0));  // 0 al centro, circa 1 negli angoli in 16:9
	c *= mix(1.0, 1.0 - smoothstep(0.35, 1.05, r), forza_vignetta * vignetta);
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma));
	if (grana > 0.0) {
		// Grana animata, un po' più visibile nelle zone scure come sulla pellicola.
		vec2 cella = floor(FRAGCOORD.xy / 1.5);
		float n = hash(cella + fract(TIME * 7.13) * 917.0) + hash(cella * 1.7 + fract(TIME * 3.7) * 311.0) - 1.0;
		float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
		c += n * forza_grana * grana * mix(1.0, 0.45, clamp(lum, 0.0, 1.0));
	}
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
