// Il gorgo dell'acquario del miscuglio: un imbuto d'acqua che gira, appoggiato sul pelo (mesh a disco
// abbassata al centro da gorgo_mesh in acquari_gorgo.gd). Bracci di schiuma a spirale che ruotano verso
// il centro, l'acqua che scurisce scendendo e un nucleo scuro e opaco: dal gorgo non si vede il fondo.
// Durante il gorgo prende il posto del pelo dell'acqua (lo nasconde acquari_gorgo.gd).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform vec3 colore : source_color = vec3(0.3, 0.27, 0.16);   // l'acqua (dal miscuglio)
uniform vec3 schiuma : source_color = vec3(0.82, 0.8, 0.7);
uniform float forza : hint_range(0.0, 1.0) = 1.0;             // 0 = fermo e invisibile
uniform float giro = 0.0;                                      // angolo accumulato (rad), da GDScript
uniform float raggio = 0.7;
uniform sampler2D rumore : filter_linear_mipmap, repeat_enable;

varying vec2 v_xz;

void vertex() {
	v_xz = VERTEX.xz;   // mesh di raggio 1 (scalata dal nodo): v_xz è già relativo
}

void fragment() {
	float r = length(v_xz) / raggio;            // 0 al centro, 1 al bordo
	float ang = atan(v_xz.y, v_xz.x);
	// strisce di schiuma sottili e spezzate lungo una spirale che gira (più veloce verso il centro)
	float spir = ang * 2.0 + log(r + 0.04) * 6.0 - giro * (1.0 + 1.5 * (1.0 - r));
	float bracci = smoothstep(0.82, 0.99, sin(spir) * 0.5 + 0.5);
	// rumore nelle coordinate della spirale: la schiuma si strappa in fili e chiazze
	float n = texture(rumore, vec2(spir * 0.16, r * 3.0)).r;
	float n2 = texture(rumore, vec2(ang / 6.2832 * 5.0 + giro * 0.03, r * 7.0 - giro * 0.2)).r;
	float fo = (bracci * smoothstep(0.4, 0.8, n) + smoothstep(0.72, 0.95, n2) * 0.35)
			* smoothstep(1.0, 0.7, r) * smoothstep(0.05, 0.22, r) * 0.75;
	// l'acqua che scende si scurisce; il nucleo è scuro e pieno
	float giu = 1.0 - smoothstep(0.0, 0.6, r);
	vec3 acqua = colore * mix(1.0, 0.25, giu);
	ALBEDO = mix(acqua, schiuma, clamp(fo, 0.0, 1.0));
	ROUGHNESS = mix(0.04, 0.6, fo);
	// le strisce piegano la luce: un poco di normale lungo la spirale
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(cos(spir) * 0.08, 0.0, sin(spir) * 0.08, 0.0)).xyz);
	SPECULAR = 0.5;
	// un filo di luce propria sulla schiuma, per leggerla al buio rosso della sala
	EMISSION = schiuma * fo * 0.08;
	// fa da pelo per tutto il gorgo: pieno (niente acqua trasparente, il fondo non si vede)
	ALPHA = forza;
}
