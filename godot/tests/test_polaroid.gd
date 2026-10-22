extends Node
## Test automatico: la Polaroid 4 si prende davvero (richiesta del coordinatore, 22 ottobre: posizionamento
## concreto). Col controller vero del giocatore (input simulati, niente teletrasporti dopo la partenza): da
## terra nell'area bimbi si sale la scala della struttura di gioco fino in cima, si guarda la Polaroid
## appoggiata sul pianerottolo, il raggio dell'interazione la trova e la si raccoglie.
## Prima stava a 6,4 m nel vuoto (la struttura HD è cambiata) e poi sulla pedana sotto il secchio, dove
## a piedi non si arriva: le pedane delle torri, dalla scala, sono chiuse dalla collisione.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_polaroid.gd

const LEVEL := "res://scenes/sala_principale.tscn"
## Da terra, a est della scala; poi su per la scala, verso ovest, fino al pianerottolo in cima (1,24 m).
const PARTENZA := Vector3(-13.6, 0.0, -15.0)
const STRADA := [Vector3(-14.6, 0.0, -15.0), Vector3(-15.5, 0.0, -15.1), Vector3(-15.95, 0.0, -15.3)]

var p: Player
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.physics_ticks_per_second = 480
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	Engine.physics_ticks_per_second = 60
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var level := get_tree().current_scene
	var foto := level.find_child("Polaroid04", true, false) as Node3D
	check(foto != null, "c'è la Polaroid 4")
	if foto == null:
		_fine()
		return
	await _frames(5)
	print("La Polaroid 4 in cima alla scala della struttura di gioco, presa a piedi")
	check(absf(foto.global_position.y - 1.24) < 0.03, "è appoggiata sul pianerottolo in cima alla scala (y %.3f)" % foto.global_position.y)
	p.teleport(PARTENZA, 0.0, 0.0)
	await _frames(20)
	var ok := true
	for w in STRADA:
		ok = ok and await _cammina_verso(w, 400)
	await _frames(30)
	check(ok and p.is_on_floor() and p.global_position.y > 1.2, "da terra si sale la scala fino in cima (y %.2f, %s)" % [p.global_position.y, "arrivato" if ok else "bloccato"])
	p.look_at_point(foto.global_position)
	await _frames(5)
	check(p.interactor.current == foto, "guardandola, il raggio dell'interazione la trova (%s)" % str(p.interactor.current))
	await _hold(&"interact", 2)
	await _frames(5)
	check(GameState.has_collectible(&"polaroid", &"p04"), "e la si raccoglie")
	_fine()


func _cammina_verso(t: Vector3, max_frames: int) -> bool:
	Input.action_press(&"move_forward")
	var arrivato := false
	for i in max_frames:
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.25:
			arrivato = true
			break
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	if not arrivato:
		printerr("  bloccato in ", p.global_position, " andando verso ", t)
	return arrivato


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _fine() -> void:
	get_tree().paused = false
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
