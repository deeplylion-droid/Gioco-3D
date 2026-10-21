extends Node
## Prova (non è nella CI): la sala della torre caricata in un thread, da sola.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := "res://scenes/sala/torre/sala_torre.tscn"
	var tipo := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else ""
	var sub := OS.get_cmdline_user_args().has("sub")
	if OS.get_cmdline_user_args().has("prima_diretta"):
		var t: Node = (load(path) as PackedScene).instantiate()
		add_child(t)
		await get_tree().process_frame
		t.free()
		print("caricata e liberata prima")
	if OS.get_cmdline_user_args().has("sala"):
		get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
		for i in 30:
			await get_tree().process_frame
		print("sala caricata")
	print("RICHIESTA ", ResourceLoader.load_threaded_request(path, tipo, sub))
	var t0 := Time.get_ticks_msec()
	while true:
		var st := ResourceLoader.load_threaded_get_status(path)
		if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			print("STATO ", st, " dopo ", Time.get_ticks_msec() - t0, " ms")
			break
		await get_tree().process_frame
	get_tree().quit()
