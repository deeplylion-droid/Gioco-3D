// La nebbia viola di NotHuman (assets_src/nebbia_viola/nebbia_viola.js, dell'utente), tradotta per Godot 4.7 Forward+:
// un quad a schermo intero davanti alla camera (NebbiaViolaProva) che legge lo schermo prima del tone mapping e la
// profondità. Per ogni punto dello schermo si cammina lungo il raggio dall'occhio alla cosa vista per PASSI passi (con
// l'inizio sfalsato), e a ogni passo la nebbia toglie un po' della luce di dietro e ci mette la sua: l'aria viola,
// l'alone delle lampade e la polvere nella luce. È più fitta in basso e fatta a ciuffi che vanno col vento.
// Il sole e la finestra dell'originale non ci sono (nell'infermeria non servono).
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D schermo : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D profondita : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D rumore_tex : filter_linear, repeat_enable;

const int PASSI = 20;
uniform float lontano = 14.0;     // fin dove si calcola, in metri
uniform float oltre = 100.0;      // da qui (metri dall'occhio) la nebbia si dirada...
uniform float cala = 0.0;         // ...di tanto per metro (0: uguale dappertutto)
uniform float quota = 0.0;        // l'altezza del pavimento
uniform float densita = 0.08;     // la nebbia dappertutto, per metro
uniform float strato = 0.8;       // in più vicino al pavimento...
uniform float altezza = 3.0;      // ...che si dirada salendo
uniform float ciuffi = 1.0;       // 0 uniforme, 1 a banchi
uniform float scala = 1.3;        // la grandezza dei ciuffi (più alto, più piccoli)
uniform vec3 vento = vec3(0.06, 0.01, -0.035);
uniform vec3 aria = vec3(0.02, 0.018, 0.055);
uniform vec3 raggi = vec3(0.24, 0.2, 0.42);
uniform float particelle = 0.35;
uniform float quanto = 1.0;       // 0..1: la nebbia che sale entrando nella zona (0 spenta)
uniform float forza = 1.0;        // tutta la luce della nebbia (l'originale è tarato su AgX con esposizione 2,6)
uniform vec3 luci_pos[4];
uniform vec3 luci_col[4];         // il colore per la forza
uniform int n_luci = 0;

// il rumore in 3D con una lettura sola: nel rosso la tabella, nel verde la stessa spostata di (37, 17)
float rumore(vec3 x) {
	vec3 p = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	vec2 uv = p.xy + vec2(37.0, 17.0) * p.z + f.xy;
	vec2 rg = texture(rumore_tex, (uv + 0.5) / 256.0).yx;
	return mix(rg.x, rg.y, f.z);
}

float fbm(vec3 p) {
	return 0.55 * rumore(p) + 0.3 * rumore(p * 2.07 + 13.1) + 0.15 * rumore(p * 4.3 + 7.7);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);    // (davanti a tutto: Godot ha la profondità rovesciata, 1 è il piano vicino)
}

void fragment() {
	vec3 col = texture(schermo, SCREEN_UV).rgb;
	float z = texture(profondita, SCREEN_UV).x;
	vec2 ndc = SCREEN_UV * 2.0 - 1.0;
	// la direzione dal piano vicino; la distanza dalla profondità (0 è lontanissimo: niente dietro, fino a "lontano")
	vec4 vicino = INV_PROJECTION_MATRIX * vec4(ndc, 1.0, 1.0);
	vec3 dir_vista = normalize(vicino.xyz / vicino.w);
	float L = lontano;
	if (z > 0.0) {
		vec4 v = INV_PROJECTION_MATRIX * vec4(ndc, z, 1.0);
		L = min(length(v.xyz / v.w), lontano);
	}
	vec3 occhio = INV_VIEW_MATRIX[3].xyz;
	vec3 rd = normalize((INV_VIEW_MATRIX * vec4(dir_vista, 0.0)).xyz);
	float dt = L / float(PASSI);
	// un inizio diverso per ogni punto dello schermo (rumore a gradiente intrecciato)
	float j = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float T = 1.0;
	vec3 S = vec3(0.0);
	for (int i = 0; i < PASSI; i++) {
		float t = (float(i) + j) * dt;
		vec3 p = occhio + rd * t;
		float n = fbm(p * vec3(scala, scala * 1.8, scala) + vento * TIME);
		float d = (densita + strato * exp(-max(p.y - quota, 0.0) * altezza)) * mix(1.0, smoothstep(0.3, 0.75, n) * 2.0, ciuffi);
		d /= 1.0 + max(t - oltre, 0.0) * cala;
		d *= quanto;
		vec3 luce = aria;
		for (int k = 0; k < 4; k++) {
			if (k >= n_luci) {
				break;
			}
			vec3 a = p - luci_pos[k];
			luce += luci_col[k] / (dot(a, a) + 0.08);
		}
		// la polvere: puntini che salgono piano, visibili nella luce (senza sole: solo il loro poco)
		float g = rumore(p * 22.0 + vec3(0.0, -TIME * 0.25, TIME * 0.05));
		luce += particelle * smoothstep(0.86, 0.97, g) * 0.15 * raggi;
		float tr = exp(-d * dt);
		S += T * (1.0 - tr) * luce * forza;
		T *= tr;
	}
	ALBEDO = col * T + S;
	ALPHA = 1.0;
}
