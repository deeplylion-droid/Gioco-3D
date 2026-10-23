extends SceneTree
## Sonda: quanto ci mette sala_torre.tscn a caricarsi. Modi: sync (load), thread (load_threaded_request),
## thread_sub (con i sotto-thread), sala (nel thread con la sala principale che gira).
## Uso: godot --headless --path godot --script res://tests/sonda_caricamento_torre.gd -- <modo>
const T := "res://scenes/sala/torre/sala_torre.tscn"
func _initialize():
	var modo: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "sync"
	var t0 := Time.get_ticks_msec()
	if modo == "sync":
		var p = load(T)
		print("SONDA sync %d ms %s" % [Time.get_ticks_msec() - t0, p])
	elif modo == "thread":
		ResourceLoader.load_threaded_request(T, "PackedScene")
		while ResourceLoader.load_threaded_get_status(T) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await process_frame
		print("SONDA thread %d ms stato %d" % [Time.get_ticks_msec() - t0, ResourceLoader.load_threaded_get_status(T)])
	elif modo == "thread_sub":
		ResourceLoader.load_threaded_request(T, "PackedScene", true)
		while ResourceLoader.load_threaded_get_status(T) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await process_frame
		print("SONDA thread_sub %d ms stato %d" % [Time.get_ticks_msec() - t0, ResourceLoader.load_threaded_get_status(T)])
	elif modo == "sala":
		var s := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
		root.add_child(s)
		for i in 30:
			await process_frame
		t0 = Time.get_ticks_msec()
		ResourceLoader.load_threaded_request(T, "PackedScene")
		var f := 0
		while ResourceLoader.load_threaded_get_status(T) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec() - t0 < 120000:
			await process_frame
			f += 1
		print("SONDA sala+thread %d ms, %d fotogrammi, stato %d" % [Time.get_ticks_msec() - t0, f, ResourceLoader.load_threaded_get_status(T)])
	quit()
