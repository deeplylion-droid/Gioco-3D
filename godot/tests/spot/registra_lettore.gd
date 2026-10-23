extends Node
## Registra col Movie Maker lo spot come lo vede il giocatore: il lettore (scenes/spot/lettore_spot.tscn) col video,
## il filtro VHS, l'occhio e l'audio dal vivo. Serve per far vedere lo spot finito (l'audio entra nell'AVI).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##       --fixed-fps 30 --write-movie <uscita.avi> --script res://tests/run.gd -- res://tests/spot/registra_lettore.gd \
##       [video.ogv]
## Senza video usa assets/spot/spot.ogv. Finisce da solo alla fine dello spot.


func _ready() -> void:
	_via.call_deferred()


func _via() -> void:
	var args := Array(OS.get_cmdline_user_args()).filter(func(a: String): return not a.ends_with(".gd"))
	var l := (load(LettoreSpot.SCENA) as PackedScene).instantiate() as LettoreSpot
	if args.size() > 0:
		var v := VideoStreamTheora.new()
		v.file = String(args[0])
		l.video = v
	l.finito.connect(func(): get_tree().quit())
	get_tree().root.add_child(l)
