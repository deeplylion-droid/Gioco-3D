shader_type spatial;
// Geyser V2: il flipbook della simulazione reso in Cycles (assets_src/geyser/flipbook.py) su un cartellone che si
// gira solo attorno alla verticale verso la camera. Acqua piena: l'alfa taglia netto (niente trasparenza). Un
// fotogramma alla volta (niente retino); le normali della resa la fanno illuminare
// dalle luci della sala.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D colore : source_color, filter_linear_mipmap;
uniform sampler2D normali : hint_normal, filter_linear_mipmap;
uniform int colonne = 10;
uniform int righe = 8;
uniform int fotogrammi = 78;
uniform float alto_cartellone = 8.0;   // m, come flipbook.py
// alla fine l'acqua ricaduta affonda nella fossa: sotto questa altezza dal fondo del cartellone non si disegna (m)
uniform float affonda = 0.0;
uniform float fotogramma = 0.0;   // il fotogramma (intero: un fotogramma alla volta, niente retino)

vec2 cella(int f, vec2 uv) {
	f = clamp(f, 0, fotogrammi - 1);
	vec2 c = vec2(float(f % colonne), float(f / colonne));
	return (c + uv) / vec2(float(colonne), float(righe));
}

void vertex() {
	// cartellone verticale: l'asse alto resta quello del nodo, il fronte va verso la camera
	vec3 alto = normalize(MODEL_MATRIX[1].xyz);
	vec3 verso = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	verso = normalize(verso - alto * dot(verso, alto));
	vec3 destra = normalize(cross(alto, verso));
	mat4 m = mat4(vec4(destra * length(MODEL_MATRIX[0].xyz), 0.0), vec4(alto * length(MODEL_MATRIX[1].xyz), 0.0),
			vec4(verso * length(MODEL_MATRIX[2].xyz), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = vec2(UV.x, UV.y);
	int f = int(fotogramma + 0.5);
	vec4 c = texture(colore, cella(f, uv));
	if (c.a < 0.5 || (1.0 - UV.y) * alto_cartellone < affonda) {
		discard;
	}
	ALBEDO = c.rgb * 0.88;
	NORMAL_MAP = texture(normali, cella(f, uv)).rgb;
	ROUGHNESS = 0.22;
	SPECULAR = 0.55;
	BACKLIGHT = vec3(0.3, 0.33, 0.35);
	RIM = 0.2;
	RIM_TINT = 0.6;
}
