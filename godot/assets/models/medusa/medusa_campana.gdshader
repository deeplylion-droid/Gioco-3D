// Campana della medusa: gelatina traslucida con i canali radiali luminosi (giallo in alto, rosa sul bordo)
// che pulsano piano. Si applica alla superficie "M_campana" della mesh Medusa (vedi LEGGIMI.md).
// Quello che sta dietro e dentro la campana (struttura interna, radici dei tentacoli) si vede attraverso la
// gelatina, un po' deformato (rifrazione) e tinto di lilla: la campana e' disegnata dopo gli oggetti opachi.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// campana_base_alfa.png: RGB = colore della campana, A = 1 vicino alla vita (si fonde con la pelle), ~0.4 sotto
uniform sampler2D tex_colore : source_color, filter_linear_mipmap;
// campana_emissione.png: da qui si prende solo la TINTA dei canali (giallo in alto, rosa sul bordo), sfocata;
// dove sono i canali lo dice la texture colore (i canali sono le righe chiare), che e' pulita
uniform sampler2D tex_canali : source_color, filter_linear_mipmap;
uniform sampler2D tex_dietro : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec3 tinta : source_color = vec3(0.80, 0.62, 0.98);
uniform float tinta_forza : hint_range(0.0, 1.0) = 0.25;
uniform float opacita_centro : hint_range(0.0, 1.0) = 0.35;   // dove la campana si guarda di fronte
uniform float opacita_bordo : hint_range(0.0, 1.0) = 0.85;    // dove si guarda di taglio (silhouette)
uniform float fresnel_esponente : hint_range(0.5, 8.0) = 2.5;
uniform float rifrazione : hint_range(0.0, 0.15) = 0.035;     // 0 = niente deformazione di quello che sta dietro
uniform vec3 tinta_dentro : source_color = vec3(0.78, 0.62, 1.0); // colore della gelatina vista in trasparenza
uniform float luce_canali : hint_range(0.0, 20.0) = 1.2;
uniform vec2 soglia_canali = vec2(0.74, 0.82);               // luminosita' del colore che diventa canale
uniform vec3 tinta_canali_base : source_color = vec3(1.0, 0.35, 0.55);
uniform float bagliore_dentro : hint_range(0.0, 2.0) = 0.25;  // la luce dei canali che si sparge nella gelatina
uniform float pulsazione_al_secondo = 0.4;                    // 0 = canali fissi (statua spenta)
uniform float pulsazione_ampiezza : hint_range(0.0, 1.0) = 0.3;
uniform float rugosita : hint_range(0.0, 1.0) = 0.08;
// 0..1: la campana si spegne (colore, canali, riflessi) e diventa del tutto trasparente, si vede solo quello che sta
// dietro (lei che si stacca da un oblò e sparisce nel buio, ObloLei: al posto della trasparenza del nodo)
uniform float scurisci : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(tex_colore, UV);
	vec3 colore = mix(c.rgb, tinta, tinta_forza);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_esponente);
	float gelatina = mix(opacita_centro, opacita_bordo, fres);
	// vicino alla vita la campana diventa opaca come la pelle di vinile
	float op = clamp(mix(gelatina, 1.0, smoothstep(0.75, 1.0, c.a)), 0.0, 1.0);
	// quello che sta dietro, deformato dalla curvatura della campana
	vec2 off = NORMAL.xy * rifrazione * (1.0 - fres * 0.5);
	vec3 dietro = textureLod(tex_dietro, SCREEN_UV - off, 1.5).rgb * tinta_dentro;
	float pulsa = 1.0 + pulsazione_ampiezza * sin(TIME * pulsazione_al_secondo * 6.2831853);
	float canale = smoothstep(soglia_canali.x, soglia_canali.y, dot(c.rgb, vec3(0.3, 0.3, 0.4)));
	vec3 tinta_c = textureLod(tex_canali, UV, 3.0).rgb;
	float mx = max(max(tinta_c.r, tinta_c.g), tinta_c.b);
	tinta_c = mx > 0.02 ? tinta_c / mx : tinta_canali_base;
	vec3 canali = canale * tinta_c * luce_canali * pulsa;
	vec3 sparsa = textureLod(tex_canali, UV, 5.0).rgb * bagliore_dentro * luce_canali * pulsa;
	float luce = 1.0 - clamp(scurisci, 0.0, 1.0);
	ALBEDO = colore * op * luce;
	ROUGHNESS = rugosita;
	SPECULAR = 0.6 * luce;
	EMISSION = (canali + sparsa) * luce + dietro * (1.0 - op * luce);
	ALPHA = 1.0;
}
