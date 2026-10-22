shader_type canvas_item;
// Il finale dello spot della crociera (inquadrature 8-9, bozza in docs/proposte/spot/bozza.md): l'occhio di Jilly che
// riempie lo schermo e ipnotizza, sempre più forte. Va sopra l'immagine dell'occhio: su una camera (un ColorRect a tutto
// schermo, dallo_schermo acceso) o su un video (il materiale sul VideoStreamPlayer). I parametri li muove
// scripts/spot/occhio_ipnotico.gd: il battito che accelera, i fotogrammi saltati, il lampo in negativo, lo scatto in
// avanti e il nero. Niente sangue: fa paura col ritmo, l'occhio e i colori.

uniform bool dallo_schermo = false;
uniform sampler2D schermo : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform vec2 centro = vec2(0.5, 0.5);                       // la pupilla sullo schermo (UV)
uniform float raggio_pupilla : hint_range(0.01, 0.5) = 0.1;  // in altezze dello schermo (l'occhio a tutto schermo)
uniform float raggio_iride : hint_range(0.01, 1.0) = 0.36;
uniform float battito : hint_range(0.0, 1.0) = 0.0;         // il colpo del cuore (0 fra un battito e l'altro, 1 al colpo)
uniform float intensita : hint_range(0.0, 1.0) = 0.0;       // quanto è forte l'ipnosi (sale nell'inquadratura)
uniform float tempo = 0.0;                                   // il tempo dell'effetto (fermo nei fotogrammi saltati)
uniform float dilata : hint_range(0.0, 1.0) = 0.45;         // quanto si allarga la pupilla a ogni colpo
uniform float separa : hint_range(0.0, 0.05) = 0.018;       // i colori che si separano a ogni colpo
uniform float spirali : hint_range(0.0, 1.0) = 0.8;
uniform float anelli : hint_range(0.0, 1.0) = 0.7;
uniform vec3 rosa : source_color = vec3(1.0, 0.32, 0.72);
uniform vec3 viola : source_color = vec3(0.56, 0.22, 1.0);
uniform float negativo : hint_range(0.0, 1.0) = 0.0;
uniform float avanti : hint_range(0.0, 1.0) = 0.0;          // lo scatto in avanti finale
uniform float nero : hint_range(0.0, 1.0) = 0.0;

vec3 leggi(sampler2D tex, vec2 uv) {
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	if (dallo_schermo) {
		return textureLod(schermo, uv, 0.0).rgb;
	}
	return texture(tex, uv).rgb;
}

void fragment() {
	vec2 base = dallo_schermo ? SCREEN_UV : UV;
	vec2 px = dallo_schermo ? SCREEN_PIXEL_SIZE : TEXTURE_PIXEL_SIZE;
	float aspetto = px.y / px.x;                       // larghezza / altezza
	vec2 asp = vec2(aspetto, 1.0);
	float b = battito;
	float k = intensita;

	// lo scatto in avanti: tutto corre verso la pupilla; e a ogni colpo l'immagine fa un piccolo balzo verso chi guarda
	vec2 d = base - centro;
	d /= 1.0 + avanti * avanti * 9.0;
	d *= 1.0 - 0.045 * b * k;
	// la pupilla che si allarga a ogni colpo: dentro l'iride si legge più vicino al centro
	float r = length(d * asp);
	float spinta = dilata * b * (0.35 + 0.65 * k) * smoothstep(raggio_iride, 0.0, r);
	d *= 1.0 - spinta * 0.5;
	vec2 uv = centro + d;

	// i colori che si separano (rosso fuori, blu dentro) e la scia del colpo verso il centro
	vec2 dir = normalize(d * asp + vec2(1e-5)) / asp;
	float s = separa * (b * (0.5 + k) + avanti * 2.0);
	vec3 col = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float f = float(i) / 5.0;
		vec2 scia = -dir * f * (b * 0.035 * k + avanti * 0.12) * r;
		col.r += leggi(TEXTURE, uv + scia + dir * s).r;
		col.g += leggi(TEXTURE, uv + scia).g;
		col.b += leggi(TEXTURE, uv + scia - dir * s).b;
	}
	col /= 6.0;

	// spirali e anelli rosa e viola che girano nella pupilla e nell'iride, sempre più forti
	float a = atan(d.y * asp.y, d.x * asp.x);
	float rr = max(r, 0.002);
	float sp = 0.5 + 0.5 * sin(a * 3.0 + log(rr) * 9.0 - tempo * (3.0 + 6.0 * k));
	float an = 0.5 + 0.5 * sin(rr * (90.0 + 60.0 * k) - tempo * (8.0 + 10.0 * k) - b * 5.0);
	float dentro = smoothstep(raggio_iride * (1.0 + 0.6 * k), raggio_pupilla * 0.4, rr);
	vec3 giro = mix(viola, rosa, sp) * pow(sp, 3.0) * spirali + mix(rosa, viola, an) * pow(an, 6.0) * anelli;
	float forza = dentro * (0.25 + 0.75 * k) * (0.6 + 0.6 * b);
	col = col + giro * forza;                          // somma: brillano anche sul nero della pupilla
	// fuori dall'iride l'immagine si scurisce e pulsa di viola, verso i bordi
	float bordo = smoothstep(0.35, 1.0, length((base - 0.5) * asp) * 1.4);
	col = mix(col, col * 0.35 + viola * 0.08 * b, bordo * (0.3 + 0.6 * k));
	// il colpo: un lampo di luce
	col *= 1.0 + b * 0.35 * k;

	// il lampo in negativo, lo scatto finale e il nero
	col = mix(col, vec3(1.0) - clamp(col, 0.0, 1.0), negativo);
	col *= 1.0 - nero;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
