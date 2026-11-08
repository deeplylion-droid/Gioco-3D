extends Node
## Un video della schermata di caricamento con Jilly, per mostrarla (col Movie Maker): la schermata vera, che però
## carica una scena vuota (la sala non serve e sul renderer software non entra in memoria), per un ciclo del video.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 24 --write-movie <cartella>/schermata.png --script res://tests/run.gd -- \
##     res://tests/collaudo/video_caricamento_jilly.gd

const SECONDI := 8.5


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	var s := (load("res://scenes/ui/caricamento.tscn") as PackedScene).instantiate()
	s.set(&"scena", "res://tests/scene/prova_vuota.tscn")
	s.set(&"tempo_minimo", 600.0)
	get_tree().root.add_child(s)
	var t := 0.0
	while t < SECONDI:
		await get_tree().process_frame
		t += get_process_delta_time()
	get_tree().quit()
