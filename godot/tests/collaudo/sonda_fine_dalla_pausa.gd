extends Node
## Collaudo della fine della demo: durante la scritta si mette in pausa e si torna al titolo dal menu di pausa
## (Game.return_to_title, il pulsante "Torna al titolo"). Poi si resta 15 s sul titolo: la scena non deve cambiare di
## nuovo (il timer della fine non deve riportare al titolo una seconda volta né ricaricare niente).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/cz/sonda_fine_dalla_pausa.gd

const SALA := "res://scenes/sala_principale.tscn"

var _cambi := []
var _ultima: Node = null


func _ready() -> void:
	_run.call_deferred()


func _process(_d: float) -> void:
	var s := get_tree().current_scene
	if s != _ultima:
		_ultima = s
		_cambi.append(s.scene_file_path if s else "niente")


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	get_tree().change_scene_to_file(SALA)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene
	var nero := CanvasLayer.new()
	nero.layer = 80
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 1)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	nero.add_child(r)
	level.add_child(nero)
	level.call(&"_on_fine_torre")
	await _secondi(2.0)
	var cambi_prima := _cambi.size()
	Game.set_paused(true)
	await _secondi(1.0)
	print("SONDA FINE: in pausa da 1 s, scena ", get_tree().current_scene.scene_file_path)
	Game.return_to_title()
	await _secondi(3.0)
	var titolo := get_tree().current_scene
	print("SONDA FINE: dopo Torna al titolo: ", titolo.scene_file_path if titolo else "niente", "  in pausa ", get_tree().paused)
	await _secondi(15.0)
	print("SONDA FINE: 15 s dopo: ", get_tree().current_scene.scene_file_path if get_tree().current_scene else "niente",
			"  stessa scena ", get_tree().current_scene == titolo, "  cambi di scena dalla pausa ", _cambi.slice(cambi_prima))
	get_tree().quit()


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame
