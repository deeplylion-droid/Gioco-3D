shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// La bava del mostro-squalo (scripts/interni/bava_squalo.gd): nastri sottili girati verso la camera, che devono
// sembrare liquido: trasparenti in mezzo e più densi sui bordi (come un filo d'acqua visto di lato), lucidi, con il
// riflesso di luce lungo il filo. UV.x: lungo il filo (0..1), UV.y: di traverso (0..1).

uniform vec3 colore : source_color = vec3(0.82, 0.84, 0.78);
uniform float riflesso = 0.35;

void fragment() {
	float x = UV.y * 2.0 - 1.0;
	float bordo = x * x;
	ALBEDO = colore;
	ROUGHNESS = 0.04;
	SPECULAR = 1.0;
	METALLIC = 0.0;
	// il riflesso: una riga chiara lungo il filo, un poco fuori dal centro
	float riga = exp(-pow((x - 0.3) / 0.16, 2.0));
	EMISSION = vec3(1.0, 0.97, 0.92) * riga * riflesso;
	ALPHA = clamp(0.1 + 0.3 * bordo + 0.45 * riga, 0.0, 0.8) * COLOR.a;
}
