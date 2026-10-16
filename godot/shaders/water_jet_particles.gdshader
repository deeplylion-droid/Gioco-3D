// Particelle del getto d'acqua dello zaino-pompa.
// Seguono la stessa parabola usata dallo script per trovare i colpi (WaterPack._trace),
// e muoiono quando arrivano al punto d'impatto: max_age viene aggiornato ogni tick.
shader_type particles;
render_mode disable_force;

uniform float speed = 15.0;
uniform float speed_random : hint_range(0.0, 0.5) = 0.05;
uniform float spread_degrees = 1.4;
uniform vec3 gravity = vec3(0.0, -9.8, 0.0);
uniform float max_age = 1.2;
uniform float base_size = 0.03;
uniform float size_growth = 0.07;   // la goccia si allarga col tempo (m/s)
uniform float stretch = 0.012;      // lunghezza = velocità * stretch
uniform vec3 inherit_velocity = vec3(0.0);
uniform vec4 color : source_color = vec4(0.78, 0.9, 1.0, 0.75);

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
	uint seed = hash_u(NUMBER + uint(1) + RANDOM_SEED);
	float a = rand01(seed) * TAU;
	float c = sqrt(rand01(seed)) * radians(spread_degrees);
	vec3 local_dir = normalize(vec3(cos(a) * sin(c), sin(a) * sin(c), -cos(c)));
	vec3 dir = normalize((EMISSION_TRANSFORM * vec4(local_dir, 0.0)).xyz);
	float s = speed * (1.0 + (rand01(seed) * 2.0 - 1.0) * speed_random);
	VELOCITY = dir * s + inherit_velocity;
	TRANSFORM = mat4(1.0);
	TRANSFORM[3] = vec4(EMISSION_TRANSFORM[3].xyz + dir * rand01(seed) * 0.06, 1.0);
	CUSTOM = vec4(0.0, 0.0, rand01(seed), 0.0);
	COLOR = color;
}

void process() {
	CUSTOM.y += DELTA;
	if (CUSTOM.y > max_age) {
		ACTIVE = false;
	}
	VELOCITY += gravity * DELTA;
	float sp = length(VELOCITY);
	vec3 fwd = sp > 0.001 ? VELOCITY / sp : vec3(0.0, -1.0, 0.0);
	vec3 ref = abs(fwd.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 side = normalize(cross(fwd, ref));
	vec3 up = cross(side, fwd);
	float size = base_size * (0.7 + 0.6 * CUSTOM.z) + size_growth * CUSTOM.y;
	float len = max(size, sp * stretch);
	TRANSFORM[0].xyz = side * size;
	TRANSFORM[1].xyz = up * size;
	TRANSFORM[2].xyz = fwd * len;
	COLOR.a = color.a * (1.0 - smoothstep(0.75, 1.0, CUSTOM.y / max(max_age, 0.001)));
}
