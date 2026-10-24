extends Node
## Sonda: gli ingombri (AABB nel mondo) delle parti del livello, per trovare spazio libero (tunnel sottomarino).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_ingombri_mondo.gd

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	var sala := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(sala)
	for i in 5:
		await get_tree().process_frame
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate()
	sala.add_child(torre)
	if torre.has_method(&"costruisci_a_pezzi"):
		await torre.call(&"costruisci_a_pezzi", 50.0)
	for i in 5:
		await get_tree().process_frame
	_stampa(sala, 0)
	get_tree().quit()


func _stampa(n: Node, livello: int) -> void:
	for c in n.get_children():
		var box := _box(c)
		if box.size != Vector3.ZERO:
			var lo := box.position
			var hi := box.end
			print("%s%s  da (%.1f, %.1f, %.1f) a (%.1f, %.1f, %.1f)" % ["  ".repeat(livello), c.name, lo.x, lo.y, lo.z, hi.x, hi.y, hi.z])
			if livello < 2 and box.size.length() > 30.0:
				_stampa(c, livello + 1)


func _box(n: Node) -> AABB:
	var out := AABB()
	var primo := true
	var pila: Array[Node] = [n]
	while not pila.is_empty():
		var x: Node = pila.pop_back()
		if x is VisualInstance3D and not (x is Light3D) and x.is_visible_in_tree():
			var b: AABB = (x as VisualInstance3D).global_transform * (x as VisualInstance3D).get_aabb()
			if b.size.length() < 2000.0:
				out = b if primo else out.merge(b)
				primo = false
		pila.append_array(x.get_children())
	return out
