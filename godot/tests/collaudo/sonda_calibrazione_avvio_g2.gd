extends Node
## grafica-2 (collaudo finale 0.3.21): primo avvio con la luminosità da confermare (calibrato falso) dopo una chiusura di
## colpo. La schermata della luminosità e la domanda «Avvio sicuro?» insieme: quale sta sopra, chi ha il focus, e dove
## va Invio (ui_accept) premuto dal giocatore. Uso: godot --headless --path godot --script res://tests/run.gd --
## res://tests/collaudo/sonda_calibrazione_avvio_g2.gd

func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.imposta("calibrato", false)
	AvvioSicuro.forza = true
	AvvioSicuro.chiesto = false
	AvvioSicuro.chiusa_di_colpo = true
	# come al primo avvio: Game._ready apre la calibrazione, poi arriva il titolo (che fa la domanda)
	Game.call(&"_show_calibration")
	await _frames(5)
	get_tree().change_scene_to_file("res://scenes/ui/menu_principale.tscn")
	await _frames(60)
	var d := get_tree().current_scene.get_node_or_null(^"DomandaAvvioSicuro")
	var cal: Control = null
	for n in Game.find_children("*", "Control", true, false):
		if n is CalibrazioneLuminosita:
			cal = n
	var f := get_viewport().gui_get_focus_owner()
	print("SONDA: domanda %s (livello %s), calibrazione %s (livello %s), focus su %s" % [d != null,
			(d.get_parent() as CanvasLayer).layer if d and d.get_parent() is CanvasLayer else "-", cal != null,
			(cal.owner as CanvasLayer).layer if cal and cal.owner is CanvasLayer else "-", f.get_path() if f else "nessuno"])
	var preset := String(Grafica.valore("preset"))
	var ev := InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	ev = InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = false
	Input.parse_input_event(ev)
	await _frames(10)
	print("SONDA: dopo Invio: calibrazione aperta %s, domanda aperta %s, preset %s -> %s, calibrato %s" % [is_instance_valid(cal) and cal.is_inside_tree(),
			is_instance_valid(d) and d.is_inside_tree(), preset, Grafica.valore("preset"), Grafica.valore("calibrato")])
	Game.esci(0)
