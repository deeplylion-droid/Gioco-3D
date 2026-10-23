// Il disco a strisce del bersaglio (80 cm): otto spicchi rossi e bianchi e il bordo nero, disegnati
// sulle due facce del CylinderMesh (le UV del cilindro non danno un cerchio intero).
shader_type spatial;

uniform vec3 rosso : source_color = vec3(0.75, 0.05, 0.04);
uniform vec3 bianco : source_color = vec3(0.92, 0.9, 0.85);
uniform float raggio = 0.4;

varying vec3 v_pos;

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	float r = length(v_pos.xz) / raggio;
	float spicchio = mod(floor((atan(v_pos.z, v_pos.x) + PI) / (PI / 4.0)), 2.0);
	vec3 c = mix(bianco, rosso, spicchio);
	c = mix(c, vec3(0.03), step(0.93, r));
	c = mix(c, vec3(0.45), step(abs(v_pos.y), 0.015));   // il bordo laterale, di lamiera
	ALBEDO = c;
	ROUGHNESS = 0.55;
}
