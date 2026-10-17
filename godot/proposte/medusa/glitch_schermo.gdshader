// PROPOSTA jumpscare: lo schermo che si rompe. forza 0 = niente, 1 = raffica piena. seme cambia a
// scatti (a ogni fotogramma durante le raffiche): righe spostate, blocchi fuori posto, RGB separati,
// righe di scansione, neve, a volte i colori invertiti.
shader_type canvas_item;

uniform sampler2D schermo : hint_screen_texture, filter_nearest, repeat_disable;
uniform float forza : hint_range(0.0, 1.0) = 0.0;
uniform float seme = 0.0;

float h(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float f = forza;
	// Righe orizzontali spostate di lato (solo alcune, di altezza a caso).
	float righe = mix(10.0, 48.0, h(vec2(seme, 1.7)));
	float banda = floor(uv.y * righe);
	float tocca = step(1.0 - f * 0.7, h(vec2(banda, seme + 3.1)));
	uv.x += (h(vec2(banda, seme)) - 0.5) * 0.3 * f * tocca;
	// Blocchi fuori posto.
	vec2 blocco = floor(SCREEN_UV * vec2(14.0, 8.0));
	if (h(blocco + seme * 1.3) < f * f * 0.18) {
		uv += (vec2(h(blocco + seme + 1.0), h(blocco + seme + 2.0)) - 0.5) * 0.18;
	}
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	// Rosso, verde e blu separati.
	float split = 0.003 + 0.028 * f * (0.5 + h(vec2(seme, 5.0)));
	vec3 c;
	c.r = texture(schermo, uv + vec2(split, 0.0)).r;
	c.g = texture(schermo, uv).g;
	c.b = texture(schermo, uv - vec2(split, split * 0.4)).b;
	// Righe di scansione e neve.
	c *= mix(1.0, 0.8 + 0.2 * sin(SCREEN_UV.y * 1100.0), f);
	float neve = h(floor(FRAGCOORD.xy * 0.5) + seme * 17.0);
	c = mix(c, vec3(neve), f * f * 0.22);
	// Lampi coi colori invertiti durante le raffiche più forti.
	if (f > 0.7 && h(vec2(seme, 9.0)) < 0.3) {
		c = vec3(1.0) - c;
	}
	// Una dominante rossa che cresce col disturbo.
	c = mix(c, c * vec3(1.35, 0.55, 0.6), f * 0.35);
	COLOR = vec4(c, 1.0);
}
