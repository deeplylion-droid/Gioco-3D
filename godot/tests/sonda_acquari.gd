extends Node
## Sonda della zona degli acquari davanti al portone della torre, come la vede il giocatore (acquari comparsi):
## per ogni mesh della zona stampa dove sta, quanto è grande e se il controllo di posizionamento la guarda.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sonda_acquari.gd [risolto]

const LEVEL := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var level := (load(LEVEL) as PackedScene).instantiate()
	for p in ["Interni", "Tecnici", "Risalita"]:
		var n := level.get_node_or_null(p)
		if n:
			n.get_parent().remove_child(n)
			n.free()
	get_tree().root.add_child(level)
	for i in 20:
		await get_tree().physics_frame
	var enigma := level.find_child("EnigmaAcquari", true, false)
	if OS.get_cmdline_user_args().has("risolto"):
		enigma.set(&"stato", 3)
	else:
		var s := enigma.get(&"serranda") as Node
		if s:
			s.set(&"aperta", true)
	for i in 30:
		await get_tree().physics_frame
	print("comparsi: %s, stato: %s" % [enigma.get(&"comparsi"), enigma.get(&"stato")])
	var radice := enigma as Node3D
	var box := AABB()
	var primo := true
	for n in radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var a := mi.global_transform * mi.get_aabb()
		box = a if primo else box.merge(a)
		primo = false
		print("MESH %s | vis %s | centro %s | misure %s | diag %.2f" % [radice.get_path_to(mi), mi.is_visible_in_tree(),
			a.get_center().snapped(Vector3.ONE * 0.01), a.size.snapped(Vector3.ONE * 0.01), a.size.length()])
	print("BOX della zona: %s" % box)
	# le mesh del resto della sala dentro il box della zona allargato (quelle che possono toccare gli acquari)
	var largo := box.grow(1.0)
	for n in level.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or radice.is_ancestor_of(mi) or not mi.is_visible_in_tree():
			continue
		var a := mi.global_transform * mi.get_aabb()
		if a.intersects(largo) and a.size.length() < 30.0:
			print("VICINA %s | centro %s | misure %s" % [level.get_path_to(mi), a.get_center().snapped(Vector3.ONE * 0.01),
				a.size.snapped(Vector3.ONE * 0.01)])
	get_tree().quit()
