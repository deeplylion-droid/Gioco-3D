@tool
class_name WaterGlowLight
extends OmniLight3D
## Luce che sta dentro l'acqua (per esempio la campana luminosa della medusa).
## Oltre a illuminare le superfici come una OmniLight3D normale:
## - fa "brillare" il volume d'acqua intorno (diffusione calcolata dagli shader dell'acqua,
##   sia guardando da sopra la superficie sia da sott'acqua);
## - le superfici bagnabili la riconoscono e non le applicano le caustiche della superficie.
## Massimo 4 luci di questo tipo attive insieme (WaterManager.MAX_GLOWS).

## Intensita' del bagliore nel volume d'acqua (indipendente dall'illuminazione delle superfici).
@export_range(0.0, 20.0, 0.01) var glow_strength := 3.0
## Distanza oltre la quale il bagliore si spegne (m).
@export_range(0.1, 30.0, 0.1) var glow_radius := 6.0


func _enter_tree() -> void:
	var wm := get_node_or_null("/root/WaterManager")
	if wm:
		wm.register_glow(self)


func _exit_tree() -> void:
	var wm := get_node_or_null("/root/WaterManager")
	if wm:
		wm.unregister_glow(self)


func get_glow_rows() -> Array:
	var p := global_position
	var c := light_color * light_energy * glow_strength
	return [Color(p.x, p.y, p.z, glow_radius), Color(c.r, c.g, c.b, omni_range)]
