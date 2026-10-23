extends Node
## Prova del lettore dello spot (scenes/spot/lettore_spot.tscn): parte, il tempo avanza col video, le voci e la sigla
## suonano ai loro tempi, e tenendo premuto un tasto per 1 s si salta (segnale finito). Senza schermo.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/spot/test_lettore_spot.gd [video.ogv]

var _finito := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := Array(OS.get_cmdline_user_args()).filter(func(a: String): return not a.ends_with(".gd"))
	var l := (load(LettoreSpot.SCENA) as PackedScene).instantiate() as LettoreSpot
	if args.size() > 0:
		l.video = load(String(args[0])) if String(args[0]).begins_with("res://") else VideoStreamTheora.new()
		if l.video is VideoStreamTheora and not String(args[0]).begins_with("res://"):
			(l.video as VideoStreamTheora).file = String(args[0])
	l.finito.connect(func(): _finito = true)
	get_tree().root.add_child(l)
	var errori := 0
	for i in 60:
		await get_tree().process_frame
	var t: float = l.get(&"_t")
	print("tempo dello spot dopo 60 fotogrammi: %.2f s" % t)
	if t <= 0.0:
		printerr("ERRORE: il tempo dello spot non avanza"); errori += 1
	var suonano := 0
	for e in l.get(&"_audio"):
		if (e["player"] as AudioStreamPlayer).playing:
			suonano += 1
	print("audio che suonano: ", suonano)
	# il tasto tenuto per 1,2 s salta lo spot
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 80:
		await get_tree().process_frame
	if not _finito:
		printerr("ERRORE: tenendo premuto un tasto lo spot non si salta"); errori += 1
	print("RISULTATO: ", "ok" if errori == 0 else "%d errori" % errori)
	get_tree().quit(1 if errori else 0)
