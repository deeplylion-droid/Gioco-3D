// Occhio della medusa: texture calma e texture venata (versione malvagia) mescolate da "venatura".
// venatura = 0: occhio calmo (come nel glTF); 1: capillari rossi, sclera ingiallita, iride piu' accesa.
// In gioco si puo' animare (per esempio da 0 a 1 quando attacca) con set_shader_parameter("venatura", v).
// Per una sola mesh (lo spot: l'occhio che pulsa, OcchioIpnotico) ci sono due instance uniform, con
// set_instance_shader_parameter: "pupilla" (1 = com'e', da 0,5 stretta a 2,0 larga: allarga la parte centrale della
// texture e stringe l'iride intorno, il bordo dell'iride resta dov'e'), "vene" (0..1, come venatura; vale la piu' alta)
// e "sorriso" (0..1): la palpebra di sotto sale a mezzaluna, col bordo ad arco piu' alto al centro (l'occhio "^" delle
// mascotte, scelta dell'utente del 23 ottobre per lo spot), del colore della palpebra di sopra.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_calmo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_venato : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float venatura : hint_range(0.0, 1.0) = 0.0;
uniform float ruvidita : hint_range(0.0, 1.0) = 0.3;
uniform float luce_propria : hint_range(0.0, 2.0) = 0.22;
instance uniform float pupilla : hint_range(0.5, 2.0) = 1.0;
instance uniform float vene : hint_range(0.0, 1.0) = 0.0;
instance uniform float sorriso : hint_range(0.0, 1.0) = 0.0;
// il colore della palpebra (medusa_palpebre.tres)
uniform vec4 colore_palpebra : source_color = vec4(0.514, 0.581, 0.880, 1.0);

// la pupilla e l'iride nella texture del bulbo (uguali nella calma e nella venata)
const vec2 CENTRO_PUPILLA = vec2(0.51, 0.491);
const float RAGGIO_PUPILLA = 0.14;
const float RAGGIO_IRIDE = 0.33;

vec2 uv_pupilla(vec2 uv) {
	float k = clamp(pupilla, 0.5, 2.0);
	vec2 d = uv - CENTRO_PUPILLA;
	float r = length(d);
	if (r >= RAGGIO_IRIDE || abs(k - 1.0) < 0.0001) {
		return uv;
	}
	float rp = RAGGIO_PUPILLA * k;
	float da = r < rp ? r / k : RAGGIO_PUPILLA + (r - rp) * (RAGGIO_IRIDE - RAGGIO_PUPILLA) / (RAGGIO_IRIDE - rp);
	return CENTRO_PUPILLA + d * (da / max(r, 0.000001));
}

void fragment() {
	vec2 uv = uv_pupilla(UV);
	// la palpebra di sotto: sopra il bordo l'occhio, sotto la pelle; il bordo sale col sorriso ed e' piu' basso ai lati
	float s = clamp(sorriso, 0.0, 1.0);
	float du = UV.x - CENTRO_PUPILLA.x;
	// arco di cerchio largo (raggio 0,9 nella texture): una mezzaluna morbida, bassa (sotto la pupilla: sopra resta
	// quasi tutto l'occhio), che scende appena ai lati (l'utente, 23 ottobre: "sale troppo appunta quella palpebra")
	float arco = 0.9 - sqrt(max(0.9 * 0.9 - du * du, 0.0));
	float bordo = mix(1.15, CENTRO_PUPILLA.y + 0.12, s) + arco * 1.0 * s;
	float palpebra = smoothstep(bordo - 0.004, bordo + 0.004, UV.y);
	float ciglia = (1.0 - smoothstep(0.0, 0.03, bordo - UV.y)) * step(0.001, s);
	vec3 c = mix(texture(tex_calmo, uv).rgb, texture(tex_venato, uv).rgb, max(venatura, vene));
	c = mix(c, c * 0.3, ciglia * (1.0 - palpebra));
	vec3 pelle = colore_palpebra.rgb * mix(0.8, 1.0, smoothstep(bordo, bordo + 0.08, UV.y));
	ALBEDO = mix(c, pelle, palpebra);
	ROUGHNESS = mix(ruvidita, 0.24, palpebra);
	SPECULAR = 0.5;
	EMISSION = c * luce_propria * (1.0 - palpebra);
}
