// Particelle dell'aspirazione: nascono in un disco sulla superficie puntata e volano verso
// la punta della lancia (uniform target, aggiornata ogni tick da WaterPack).
shader_type particles;
render_mode disable_force;

uniform vec3 target = vec3(0.0, 1.5, 0.0);
uniform float emission_radius = 0.35;
uniform float start_speed = 1.5;
uniform float pull = 18.0;          // accelerazione verso la lancia (m/s²)
uniform float max_speed = 9.0;
uniform float base_size = 0.03;
uniform vec4 color : source_color = vec4(0.75, 0.88, 1.0, 0.7);

uint hash_u(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}

float rand01(inout uint seed) {
	seed = hash_u(seed);
	return float(seed % uint(65536)) / 65535.0;
}

void start() {
	uint seed = hash_u(NUMBER + uint(7) + RANDOM_SEED);
	float a = rand01(seed) * TAU;
	float r = sqrt(rand01(seed)) * emission_radius;
	vec3 origin = EMISSION_TRANSFORM[3].xyz + vec3(cos(a) * r, 0.02, sin(a) * r);
	TRANSFORM = mat4(1.0);
	TRANSFORM[3] = vec4(origin, 1.0);
	vec3 to_target = normalize(target - origin);
	VELOCITY = (vec3(0.0, 1.0, 0.0) * 0.6 + to_target * 0.4) * start_speed;
	CUSTOM = vec4(0.0, 0.0, rand01(seed), 0.0);
	COLOR = color;
}

void process() {
	CUSTOM.y += DELTA;
	vec3 pos = TRANSFORM[3].xyz;
	vec3 d = target - pos;
	float dist = length(d);
	if (dist < 0.12) {
		ACTIVE = false;
	}
	VELOCITY += normalize(d) * pull * DELTA;
	float sp = length(VELOCITY);
	if (sp > max_speed) {
		VELOCITY = VELOCITY / sp * max_speed;
		sp = max_speed;
	}
	vec3 fwd = sp > 0.001 ? VELOCITY / sp : vec3(0.0, 1.0, 0.0);
	vec3 ref = abs(fwd.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 side = normalize(cross(fwd, ref));
	vec3 up = cross(side, fwd);
	float size = base_size * (0.7 + 0.6 * CUSTOM.z);
	TRANSFORM[0].xyz = side * size;
	TRANSFORM[1].xyz = up * size;
	TRANSFORM[2].xyz = fwd * max(size, sp * 0.015);
	COLOR.a = color.a * smoothstep(0.0, 0.15, CUSTOM.y);
}
