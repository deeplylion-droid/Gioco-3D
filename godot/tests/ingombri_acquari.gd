extends Node
## Strumento (non è un test della CI): elenca le collisioni e le mesh della sala principale che
## entrano in un riquadro, per trovare un posto libero agli acquari. Esclude l'enigma stesso.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/ingombri_acquari.gd [x0 x1 z0 z1 [con_acquari] [tutte_le_quote]]

const LEVEL := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var x0 := float(a[1]) if a.size() > 4 else 9.0
	var x1 := float(a[2]) if a.size() > 4 else 21.0
	var z0 := float(a[3]) if a.size() > 4 else -14.0
	var z1 := float(a[4]) if a.size() > 4 else 6.0
	var zona := AABB(Vector3(x0, -0.5, z0), Vector3(x1 - x0, 9.0, z1 - z0))
	# Con "tutte_le_quote" guarda dal fondo dello scafo al tetto (per cercare spazio per stanze nuove).
	if "tutte_le_quote" in a:
		zona = AABB(Vector3(x0, -40.0, z0), Vector3(x1 - x0, 80.0, z1 - z0))
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 30:
		await get_tree().physics_frame
	var level := get_tree().current_scene
	var enigma := level.get_node_or_null(^"Gioco/EnigmaAcquari")
	# Con "con_acquari" li mostra (come rientrando dal magazzino) e li mette nell'elenco.
	var con := "con_acquari" in a
	if con and enigma:
		enigma.call(&"_mostra", true)
		for i in 5:
			await get_tree().physics_frame
	print("ZONA ", zona)
	for n in level.find_children("*", "", true, false):
		if enigma and not con and (n == enigma or enigma.is_ancestor_of(n)):
			continue
		var box := AABB()
		var tipo := ""
		if n is CollisionShape3D and (n as CollisionShape3D).shape and not (n as CollisionShape3D).disabled:
			var cs := n as CollisionShape3D
			box = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
			tipo = "COL"
		elif n is VisualInstance3D and not (n is Light3D) and not (n is GPUParticles3D):
			var vi := n as VisualInstance3D
			box = vi.global_transform * vi.get_aabb()
			tipo = "VIS"
		else:
			continue
		if box.size.length() < 0.001 or box.size.length() > 200.0 or not box.intersects(zona):
			continue
		var visibile := not (n is Node3D) or (n as Node3D).is_visible_in_tree()
		print("%s %s%s  da (%.2f, %.2f, %.2f) a (%.2f, %.2f, %.2f)" % [tipo, level.get_path_to(n),
			"" if visibile else " [nascosto]", box.position.x, box.position.y, box.position.z,
			box.end.x, box.end.y, box.end.z])
	get_tree().quit(0)
