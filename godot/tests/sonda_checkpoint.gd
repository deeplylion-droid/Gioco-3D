extends Node
## Prova (non è nella CI): elenca i checkpoint delle scene con punto e direzione di ripartenza.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for scena in ["res://scenes/interni/interni.tscn", "res://scenes/sala_principale.tscn"]:
		get_tree().change_scene_to_file(scena)
		for i in 20:
			await get_tree().physics_frame
		var cps := get_tree().current_scene.find_children("*", "Checkpoint", true, false)
		cps.sort_custom(func(a, b): return a.order < b.order)
		for c in cps:
			var t: Transform3D = c.get_spawn_transform()
			var f := -t.basis.z
			print("CP %s | %s | ordine %d | buio %s | pos %s | verso %s" % [scena.get_file(), c.get_path(), c.order, c.solo_al_buio, str(t.origin.snapped(Vector3.ONE * 0.1)), str(f.snapped(Vector3.ONE * 0.01))])
	get_tree().quit()
