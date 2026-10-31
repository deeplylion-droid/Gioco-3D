extends Node
## Crash della 0.3.17 (riscontro dell'utente: le partenze di prova "torre" e "inseguimento" chiudono il gioco): una
## partenza del menu di prova (MenuProva.parti, come F9) col renderer vero, e poi [constant SECONDI] s di gioco col
## giocatore fermo, stampando ogni secondo memoria e fotogrammi. Se il processo muore, l'ultima riga dice dove.
## Uso (sotto il render.lock, con 13,5 GB liberi):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/partenza_vera.gd <torre|inseguimento> [preset]

const SECONDI := 40


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var id := a[1] if a.size() > 1 else "inseguimento"
	if a.size() > 2:
		Grafica.applica_preset(a[2])
	Game.pause_on_focus_loss = false
	print("PARTENZA %s preset %s" % [id, a[2] if a.size() > 2 else "di serie"])
	if not MenuProva.parti(get_tree(), id):
		print("PARTENZA non c'è")
		get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	var giocatore_visto := false
	while Time.get_ticks_msec() - t0 < 1000 * (SECONDI + 600):
		await get_tree().create_timer(1.0, true, false, true).timeout
		var p := GameState.player
		var pronto := p != null and is_instance_valid(p) and p.is_inside_tree() and p.input_enabled
		if pronto and not giocatore_visto:
			giocatore_visto = true
			t0 = Time.get_ticks_msec() - 600 * 1000
			print("PRONTO giocatore a %s" % p.global_position)
		print("VIVO %d s, fotogrammi %d, memoria statica %d MB, video %d MB, scena %s, pronto %s" % [
				(Time.get_ticks_msec() - t0) / 1000, Engine.get_frames_drawn(),
				OS.get_static_memory_usage() / 1048576,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576,
				get_tree().current_scene.name if get_tree().current_scene else "-", pronto])
	print("FINE partenza %s senza chiudersi" % id)
	get_tree().quit()
