shader_type spatial;
// L'acqua del geyser: bianca di schiuma perché piena d'aria, piena (non trasparente), con le bolle e le
// striature che corrono verso l'alto, un velo bagnato lucido dove l'acqua è più liscia e la luce che passa
// appena dai bordi sottili. Per passare da un fotogramma della simulazione al successivo senza scatti:
// [dissolvi] e [parte] fanno una dissolvenza retinata (opaca, niente trasparenza).
render_mode cull_back, depth_draw_opaque;

uniform sampler2D rumore : filter_linear_mipmap, repeat_enable;
uniform float tempo = 0.0;
uniform float dissolvi = 0.0;   // 0..1: quanto di questo fotogramma resta (retinato)
uniform float parte = 0.0;      // 0: il fotogramma corrente, 1: il successivo
uniform vec3 schiuma : source_color = vec3(0.9, 0.93, 0.95);
uniform vec3 acqua : source_color = vec3(0.62, 0.72, 0.76);
uniform float scala = 1.6;
// la base del geyser (come nella simulazione): l'acqua ferma della fossa e quella stesa a terra le fa il gioco,
// qui si tiene solo quella che sale e ricade
uniform vec3 centro = vec3(0.0);
uniform float z_acqua = 0.85;
uniform float z_pavimento = 0.55;
uniform float r_fossa = 1.35;
uniform float svanisci = 0.0;   // 0..1: alla fine sparisce tutta (retinata)

varying vec3 mondo;
varying vec3 normale_mondo;

float retino(vec2 p) {
	// un valore fisso per pixel (Bayer 4x4): la dissolvenza non sfarfalla
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

float tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(rumore, p.yz).r * w.x + texture(rumore, p.xz).r * w.y + texture(rumore, p.xy).r * w.z;
}

void vertex() {
	mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_mondo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float r = retino(FRAGCOORD.xy);
	if (parte < 0.5 ? r > dissolvi : r <= 1.0 - dissolvi) {
		discard;
	}
	float rr = length(mondo.xz - centro.xz);
	float h = mondo.y - centro.y;
	if (h < (rr < r_fossa ? z_acqua + 0.06 : z_pavimento + 0.16) || fract(r * 7.13) < svanisci) {
		discard;
	}
	vec3 p = mondo * scala + vec3(0.0, -tempo * 2.2, 0.0);
	float a = tri(p, normale_mondo);
	float b = tri(p * 3.1 + vec3(0.0, -tempo * 3.0, 0.0), normale_mondo);
	float bolle = smoothstep(0.35, 0.75, a * 0.65 + b * 0.35);
	// più schiuma dove l'acqua è mossa e in alto, un velo più liscio e lucido qua e là
	float liscio = smoothstep(0.55, 0.85, a) * 0.5;
	ALBEDO = mix(acqua, schiuma, clamp(0.55 + bolle * 0.4 - liscio * 0.4, 0.0, 1.0)) * 0.85;
	ROUGHNESS = mix(0.08, 0.45, bolle);
	SPECULAR = 0.5;
	// la luce che passa dai bordi sottili (l'acqua è piena d'aria: solo un filo, verso il bianco)
	BACKLIGHT = vec3(0.35, 0.4, 0.42);
	RIM = 0.25;
	RIM_TINT = 0.6;
}
