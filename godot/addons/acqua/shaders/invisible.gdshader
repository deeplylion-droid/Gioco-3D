// Materiale invisibile: nasconde le superfici segnaposto dell'acqua quando c'e' quella vera.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
