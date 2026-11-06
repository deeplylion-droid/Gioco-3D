// La parete d'acqua nelle bocche dei tubi dell'inseguimento (SalaInseguimento._veli_bocche): come
// water_inseguimento.gdshader, ma da dentro il tubo (FRONT_FACING) è l'acqua vista da sotto, con il fondo della vasca che
// si intravede sfocato e mosso, non nitido come dietro un vetro (riscontro dell'utente sulla 0.3.20, «Da sotto deve
// sembrare acqua»; ricontrollo del collaudo della candidata 0.3.21: con la parete quasi piena le piastrelle illuminate
// del fondo si vedevano lo stesso nitide nei tubi 2 e 3, e la griglia nello scolo 1). Quello che c'è dietro si legge dallo
// schermo sfocato (mipmap) e spostato da onde lente, tinto dall'acqua, e si mescola al colore dell'acqua. Solo le pareti
// delle bocche usano questo shader: l'acqua delle vasche resta water_inseguimento.gdshader, com'era.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, depth_draw_always;

uniform vec4 water_color : source_color = vec4(0.2, 0.5, 0.46, 1.0);
uniform vec4 deep_color : source_color = vec4(0.06, 0.22, 0.21, 1.0);
uniform float absorption = 2.0;
uniform float min_alpha = 0.45;
uniform float under_alpha = 0.8;
uniform float wave_scale = 1.4;
uniform float wave_speed = 0.3;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.1;
uniform float lucido : hint_range(0.0, 1.0) = 0.0;
uniform float pieno_fisso = 0.97;
// La luce del colore dell'acqua che la parete fa da sola, vista da dentro il tubo (uguale in tutte e sei le bocche).
uniform float luce_propria = 0.1;
// Da dentro il tubo: quanto del fondo si intravede (0 niente, 1 tutto), quanto è sfocato (livello di mipmap dello schermo)
// e quanto lo muovono le onde (frazione dello schermo).
uniform float intravede : hint_range(0.0, 1.0) = 0.35;
uniform float sfocato : hint_range(0.0, 8.0) = 4.0;
uniform float mosso : hint_range(0.0, 0.05) = 0.012;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 wave_slope(vec2 p, float t) {
	vec2 s = vec2(0.0);
	s += vec2(cos(p.x * 1.0 + t * 1.3), 0.0) * 0.5;
	s += vec2(0.0, cos(p.y * 1.3 - t * 1.1)) * 0.5;
	s += vec2(cos((p.x + p.y) * 2.1 + t * 1.9), cos((p.x + p.y) * 2.1 + t * 1.9)) * 0.25;
	s += vec2(cos((p.x - p.y) * 3.7 - t * 2.3), -cos((p.x - p.y) * 3.7 - t * 2.3)) * 0.12;
	s += vec2(cos(p.x * 7.1 + p.y * 2.3 + t * 3.1), cos(p.y * 6.3 - p.x * 1.7 - t * 2.7)) * 0.06;
	return s;
}

void fragment() {
	vec2 slope = wave_slope(world_pos.xz * wave_scale, TIME * wave_speed * 6.0) * wave_strength;
	vec3 n_world = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	ROUGHNESS = mix(1.0, 0.03, lucido);
	SPECULAR = 0.6 * lucido;
	METALLIC = 0.0;
	if (FRONT_FACING) {
		// da dentro il tubo: l'acqua, e dietro il fondo sfocato e mosso
		float t = TIME * wave_speed * 6.0;
		vec2 off = vec2(sin(world_pos.y * 9.0 + t * 1.7) + sin((world_pos.x + world_pos.z) * 7.0 - t * 1.3),
				cos(world_pos.y * 8.0 - t * 1.5) + cos((world_pos.x - world_pos.z) * 6.0 + t * 1.1)) * 0.5 * mosso;
		vec3 dietro = textureLod(screen_tex, SCREEN_UV + off, sfocato).rgb;
		vec3 acqua = mix(water_color.rgb, deep_color.rgb, 0.5);
		vec3 col = mix(acqua * luce_propria * 1.3, dietro * water_color.rgb * 1.6, intravede);
		ALBEDO = vec3(0.0);
		EMISSION = col;
		ALPHA = 1.0;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		// dalla vasca la parete si vede da dietro, sott'acqua (come water_inseguimento.gdshader da sotto)
		NORMAL = -NORMAL;
		float su = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float finestra = smoothstep(0.6, 0.8, su);
		ALBEDO = mix(deep_color.rgb, water_color.rgb, 0.35 + 0.4 * finestra);
		ALPHA = mix(0.97, under_alpha, finestra);
	}
}
