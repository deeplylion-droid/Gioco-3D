// Cielo in tempesta visto attraverso la cupola di vetro della sala (solo per la scena di prova).
// Nuvole scure in movimento, montanti della cupola, lampi (uniform `flash`).
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled;

#include "res://addons/acqua/shaders/water_common.gdshaderinc"

uniform float flash = 0.0;
uniform vec3 sky_color : source_color = vec3(0.012, 0.018, 0.03);
uniform vec3 cloud_color : source_color = vec3(0.03, 0.04, 0.06);
uniform vec3 flash_color : source_color = vec3(0.6, 0.7, 1.0);
uniform float mullions = 12.0;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 d = normalize(v_local);
	vec2 p = d.xz / max(d.y, 0.15);
	float t = water_time * 0.02;
	float n = texture(water_noise_tex, p * 0.08 + vec2(t, t * 0.6)).r;
	float n2 = texture(water_noise_tex, p * 0.21 - vec2(t * 1.7, 0.0)).g;
	float clouds = smoothstep(0.25, 0.85, n * 0.7 + n2 * 0.4);
	vec3 col = mix(sky_color, cloud_color, clouds);
	col += flash_color * flash * (0.35 + clouds * 1.6);
	// montanti di metallo della cupola
	// atan(0, 0) non e' definito: al polo darebbe NaN (e il bagliore lo spargerebbe ovunque)
	float az = atan(d.z, d.x + 1e-5) / (2.0 * PI) * mullions;
	float el = d.y * 5.0;
	float grid = max(smoothstep(0.035, 0.0, abs(fract(az) - 0.5) - 0.465), smoothstep(0.05, 0.0, abs(fract(el) - 0.5) - 0.44));
	col = mix(col, vec3(0.006, 0.006, 0.007), grid);
	ALBEDO = col;
}
