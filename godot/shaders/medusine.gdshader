shader_type spatial;
// Micro medusine luminose della piscina a onde (scripts/game/medusine.gd): campana trasparente
// che pulsa, braccia orali e tentacoli che ondeggiano e restano indietro quando si muovono.
// Additive e senza test di profondità: si vedono attraverso la superficie dell'acqua (che scrive
// la profondità); quello che sta davanti (pavimento, pareti, il giocatore) le copre con il
// confronto a mano sulla profondità della scena.
//
// Mesh (Medusine.mesh_medusina): raggio della campana = 1.
// UV.x: 0..1 campana (profilo, 0 in cima, 1 sull'orlo); 1 + traverso tentacoli; 2 + traverso braccia.
// UV.y: lungo tentacoli e braccia (0 attacco, 1 punta). UV2: angolo / TAU, seme del filamento.
// Istanza: COLOR.rgb colore già attenuato dall'acqua, COLOR.a luce (0 spenta);
// INSTANCE_CUSTOM: x contrazione 0..1, yz tentacoli trascinati (unità della campana),
// w seme 0..1 (+2 quando è a terra, schiacciata).
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

#include "res://addons/acqua/shaders/water_common.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform float luminosita = 2.6;

varying vec4 v_col;
varying float v_c;
varying float v_seed;
varying vec3 v_world;

void vertex() {
	float c = INSTANCE_CUSTOM.x;
	vec2 lean = INSTANCE_CUSTOM.yz;
	float terra = step(1.5, INSTANCE_CUSTOM.w);
	float seed = fract(INSTANCE_CUSTOM.w);
	float part = floor(UV.x + 0.0001);
	float time = TIME + seed * 37.0;
	vec3 v = VERTEX;
	if (part < 0.5) {
		// campana: contraendosi si stringe (soprattutto l'orlo) e si allunga
		float s = UV.x;
		v.xz *= 1.0 - c * 0.3 * s * s;
		v.y *= (1.0 + c * 0.25) * mix(1.0, 0.5, terra);
		v.xz *= 1.0 + terra * 0.15;
	} else {
		float t = UV.y;
		float ang = UV2.x * TAU;
		float sd = UV2.y * 13.0 + seed * 29.0;
		vec2 radial = vec2(cos(ang), sin(ang));
		vec2 tang = vec2(-radial.y, radial.x);
		float root_y = part < 1.5 ? -0.1 : 0.05;
		float below = max(root_y - VERTEX.y, 0.0);
		// l'attacco segue l'orlo che si stringe
		v.xz *= mix(1.0 - c * 0.3, 1.0, t * 0.7);
		// ondeggiano piano, ognuno a modo suo
		float w1 = sin(time * 1.6 + t * 4.5 + sd) * 0.22 * t;
		float w2 = sin(time * 1.1 + t * 3.1 + sd * 1.7) * 0.14 * t;
		v.xz += tang * w1 + radial * w2;
		// a campana rilassata si aprono un poco, contratta si chiudono
		v.xz += radial * (1.0 - c) * 0.2 * t;
		// restano indietro quando la medusina si muove di lato
		float ll = length(lean);
		v.xz += lean * pow(t, 1.4) * (part < 1.5 ? 1.0 : 0.6);
		v.y = root_y - below / sqrt(1.0 + ll * ll * 0.12);
		// a terra: tentacoli e braccia distesi sul pavimento, tutto intorno
		vec2 steso = v.xz + radial * below * 0.8;
		v.xz = mix(v.xz, steso, terra);
		v.y = mix(v.y, -0.08 + 0.02 * sin(t * 9.0 + sd), terra);
	}
	VERTEX = v;
	v_col = COLOR;
	v_c = c;
	v_seed = seed;
	v_world = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
}

void fragment() {
	if (v_col.a <= 0.001 || water_reflection_clip(v_world, CAMERA_VISIBLE_LAYERS, CAMERA_POSITION_WORLD)) {
		discard;
	}
	// quello che sta davanti (opaco) la copre
	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float scene_dist = -sv.z / sv.w;
	if (scene_dist < -VERTEX.z - 0.004) {
		discard;
	}
	float part = floor(UV.x + 0.0001);
	vec3 col = v_col.rgb;
	float a;
	if (part < 0.5) {
		float s = UV.x;
		float th = UV2.x * TAU;
		float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float rim = pow(1.0 - ndv, 2.0);
		// orlo luminoso, quattro gonadi a ferro di cavallo, canali radiali, puntini sull'orlo
		float orlo = smoothstep(0.8, 0.97, s);
		float gon = smoothstep(0.12, 0.22, s) * (1.0 - smoothstep(0.32, 0.45, s)) * pow(abs(cos(2.0 * th)), 2.0);
		float canali = pow(max(cos(th * 8.0), 0.0), 24.0) * smoothstep(0.25, 0.85, s) * 0.5;
		float puntini = pow(max(cos(th * 16.0), 0.0), 10.0) * smoothstep(0.9, 0.99, s);
		a = 0.06 + 0.5 * rim + 0.55 * orlo + 0.8 * gon + canali + 0.7 * puntini;
		col = mix(col, vec3(1.0), 0.3 * gon + 0.35 * puntini);
		// un lampo di luce a ogni contrazione
		a *= 0.8 + 0.45 * v_c;
	} else {
		float t = UV.y;
		float across = fract(UV.x) / 0.98;
		float edge = 1.0 - abs(across * 2.0 - 1.0);
		if (part < 1.5) {
			// tentacoli sottili con perline di luce che scendono
			float beads = pow(max(sin(t * 38.0 - TIME * 3.0 + UV2.y * 40.0 + v_seed * 20.0), 0.0), 12.0);
			a = (pow(1.0 - t, 1.3) * 0.45 + beads * (1.0 - t) * 0.9) * pow(edge, 1.5);
		} else {
			// braccia orali increspate
			float frill = 0.55 + 0.45 * sin(t * 30.0 + UV2.y * 9.0);
			a = pow(edge, 0.8) * frill * pow(1.0 - t, 0.8) * 0.4;
			col = mix(col, vec3(1.0), 0.2);
		}
	}
	ALBEDO = col * luminosita;
	ALPHA = clamp(a * v_col.a, 0.0, 1.0);
}
