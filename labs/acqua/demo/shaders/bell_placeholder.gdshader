// SEGNAPOSTO della campana luminosa della medusa, solo per provare la luce che si diffonde
// nell'acqua. Il modello e l'aspetto veri li decide e li fa il ramo della medusa.
shader_type spatial;
render_mode cull_disabled;

#include "res://addons/acqua/shaders/water_common.gdshaderinc"

uniform vec3 glow_color : source_color = vec3(1.0, 0.35, 0.75);
uniform float glow_energy = 4.0;
uniform float pulse = 1.0;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 d = normalize(v_local);
	float az = atan(d.z, d.x + 1e-5);
	float canals = pow(abs(sin(az * 8.0)), 24.0) * smoothstep(0.05, 0.6, d.y + 0.2);
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	ALBEDO = glow_color * 0.25;
	ROUGHNESS = 0.2;
	EMISSION = glow_color * glow_energy * pulse * (0.12 + canals * 1.2 + rim * 0.5);
}
