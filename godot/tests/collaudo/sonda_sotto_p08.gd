extends Node
## Collaudo 0.3.24: su che cosa poggia la P08 nella sala intera (le mesh visibili sotto di lei, coi loro percorsi).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_sotto_p08.gd

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 3000:
		await get_tree().process_frame
		if GameState.player and get_tree().current_scene and get_tree().current_scene.scene_file_path.ends_with("sala_principale.tscn"):
			break
	for i in 600:
		await get_tree().process_frame
	var sala := get_tree().current_scene
	for nome in ["Polaroid08", "Polaroid05"]:
		var ph := sala.find_child(nome, true, false) as PolaroidPhoto
		if ph == null:
			print("SP: %s non c'è" % nome)
			continue
		var c := ph.global_position
		var zona := AABB(c, Vector3.ZERO).grow(0.1)
		zona = zona.expand(c - Vector3.UP * 0.35)
		var vicine := Posa.mesh_vicine(ph, zona, sala)
		print("SP: %s in %s; mesh vicine sotto: %d" % [nome, c.snappedf(0.0001), vicine.size()])
		for m in vicine:
			var n: Node = m if m is Node else (m[0] if m is Array and m.size() > 0 and m[0] is Node else null)
			print("SP:   %s" % (sala.get_path_to(n) if n else str(m).left(120)))
	print("SP: finito")
	get_tree().quit()
