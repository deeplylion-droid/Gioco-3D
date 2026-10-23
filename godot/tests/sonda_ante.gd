extends Node
## Sonda: le ante degli armadietti aperti nella scena degli interni (visibili? dove? chi le cambia?).

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/interni/interni.tscn")
	for i in 120:
		await get_tree().process_frame
	var s := get_tree().current_scene
	for nome in ["armadietti_est_01_anta", "armadietti_ovest_02_anta", "armadietto_sbatte_anta"]:
		var n := s.find_child(nome, true, false)
		if n == null:
			printerr("SONDA manca ", nome)
			continue
		var mi := n as MeshInstance3D
		printerr("SONDA ", nome, " classe ", n.get_class(), " in albero ", n.is_inside_tree(), " visibile ", (n as Node3D).is_visible_in_tree(),
				" pos ", (n as Node3D).global_position, " scala ", (n as Node3D).global_basis.get_scale(),
				" vis_range ", mi.visibility_range_end if mi else -1.0, " layers ", mi.layers if mi else -1,
				" mesh ", mi.mesh if mi else null, " aabb ", (mi.global_transform * mi.get_aabb()) if mi else AABB(),
				" materiale ", mi.get_active_material(0) if mi else null, " trasparenza ", (mi.get_active_material(0) as BaseMaterial3D).transparency if mi and mi.get_active_material(0) is BaseMaterial3D else -1,
				" override ", mi.material_override if mi else null, " genitore ", n.get_parent().name)
	get_tree().quit()
