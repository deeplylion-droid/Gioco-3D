extends Node
## grafica-2 (ricontrollo di lavoro/avvio-sicuro-luminosita): primo avvio dopo una chiusura di colpo, con la luminosità
## da confermare (CALIBRATO=0) o già confermata (CALIBRATO=1). Preme due volte il tasto del giocatore (TASTO=invio:
## ui_accept da tastiera, TASTO=joy: il pulsante A del joypad) e a ogni passo stampa chi è aperto, chi ha il focus,
## il preset, calibrato e il segno della sessione. Uso: CALIBRATO=0 TASTO=joy godot --headless --path godot --script
## res://tests/run.gd -- res://tests/collaudo/sonda_avvio_sicuro_g2.gd

var cal: Control
var d: Node


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _stato(quando: String) -> void:
	cal = null
	for n in Game.find_children("*", "Control", true, false):
		if n is CalibrazioneLuminosita and n.is_inside_tree():
			cal = n
	d = get_tree().current_scene.find_child("DomandaAvvioSicuro", true, false)
	var f := get_viewport().gui_get_focus_owner()
	print("SONDA %s: calibrazione %s, domanda %s, focus %s, preset %s, calibrato %s, segno %s" % [quando, cal != null,
			d != null and d.is_inside_tree(), str(f.get_path()) if f else "nessuno", Grafica.valore("preset"),
			Grafica.valore("calibrato"), FileAccess.file_exists(AvvioSicuro.SEGNO)])


func _premi() -> void:
	var joy := OS.get_environment("TASTO") == "joy"
	for giu in [true, false]:
		if joy:
			var e := InputEventJoypadButton.new()
			e.button_index = JOY_BUTTON_A
			e.pressed = giu
			e.device = 0
			Input.parse_input_event(e)
		else:
			var k := InputEventKey.new()
			k.keycode = KEY_ENTER
			k.physical_keycode = KEY_ENTER
			k.pressed = giu
			Input.parse_input_event(k)
		await _frames(3)
	await _frames(20)


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	var calibrato := OS.get_environment("CALIBRATO") == "1"
	Grafica.imposta("calibrato", calibrato)
	AvvioSicuro.forza = true
	AvvioSicuro.chiesto = false
	AvvioSicuro.chiusa_di_colpo = true
	if not calibrato:
		Game.call(&"_show_calibration")
	await _frames(5)
	get_tree().change_scene_to_file("res://scenes/ui/menu_principale.tscn")
	await _frames(60)
	print("SONDA caso: calibrato %s, tasto %s" % [calibrato, OS.get_environment("TASTO")])
	await _stato("aperto")
	await _premi()
	await _stato("dopo il 1o tasto")
	await _premi()
	await _stato("dopo il 2o tasto")
	Game.esci(0)
