// Liquido in un contenitore trasparente (finestrella del serbatoio sulla pistola ad acqua):
// si vede solo sotto la quota level_y (in coordinate del mondo), così il pelo dell'acqua
// resta orizzontale anche quando l'oggetto si inclina.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(0.32, 0.72, 0.95, 0.88);
uniform float level_y = 0.0;
uniform float emission_energy = 0.35;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (world_y > level_y) {
		discard;
	}
	// Le facce interne (il "pelo" visto da sopra) un po' più chiare.
	float inner = FRONT_FACING ? 0.0 : 1.0;
	ALBEDO = mix(color.rgb, vec3(0.75, 0.92, 1.0), inner * 0.35);
	ALPHA = color.a;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	EMISSION = color.rgb * emission_energy;
}
