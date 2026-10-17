extends Node
## L'agnellino della scala di C2 (tappa 7 B) inseguito dal giocatore che corre: compare col blackout salendo la
## rampa F2, scappa quando ti avvicini, non lo raggiungi e non lo vedi mai sparire (sparisce solo fuori vista).
## Prova della v0.3.4: "deve correre più veloce perché altrimenti puoi raggiungerlo e vederlo sparire".
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_agnellino.gd

const LEVEL := "res://scenes/sala_principale.tscn"
## Da dove si parte (la rampa F2) e la strada di corsa, nelle coordinate della scena dei tecnici.
const PARTENZA := Vector3(49.5, 3.625, -7.8)
const CORSA := [Vector3(44.55, 7.25, -7.8), Vector3(44.55, 7.25, -4.0), Vector3(44.55, 9.05, 2.0), Vector3(44.55, 9.05, 15.0),
		Vector3(38.0, 9.05, 15.0)]

var p: Player
var _comparso := false
var _sparito_a := -1
var _visibile_quando_sparisce := false
var _corso := 0
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var tec: Node3D = get_tree().current_scene.get_node("Tecnici")
	var ag := tec.get_node_or_null("AgnellinoScala") as AgnellinoScala
	check(ag != null, "c'è l'agnellino della scala")
	if ag == null:
		_fine()
		return
	await _frames(30)
	check(ag.bambino == null, "prima del blackout non compare")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	p.teleport(tec.to_global(PARTENZA) + Vector3(0, 0.05, 0), PI * 0.5, 0.0)
	await _frames(10)
	var b: Bambino = null
	var minima := INF
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var tappa := 0
	for i in 1500:
		if b == null and ag.bambino and is_instance_valid(ag.bambino):
			b = ag.bambino
			_comparso = true
			b.sparito.connect(_su_sparito.bind(b))
		var t: Vector3 = tec.to_global(CORSA[tappa])
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			tappa += 1
			if tappa >= CORSA.size():
				break
			continue
		p.set_look(atan2(-d.x, -d.z), 0.0)
		if b and is_instance_valid(b) and b.visible:
			# si corre guardando avanti lungo la strada, come chi lo insegue
			minima = minf(minima, b.global_position.distance_to(p.global_position))
		await get_tree().physics_frame
		_corso += 1
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	check(_comparso, "salendo la rampa F2 l'agnellino compare in cima alla scala di C2")
	check(_sparito_a >= 0, "scappa e sparisce (dopo %d frame di corsa)" % _sparito_a)
	check(_sparito_a >= 0 and not _visibile_quando_sparisce, "non lo si vede sparire: nessun punto del corpo è in vista quando sparisce")
	check(minima > 3.0, "correndo non lo si raggiunge (il più vicino: %.1f m)" % minima)
	await _frames(10)
	check(ag.bambino == null or not is_instance_valid(ag.bambino), "non c'è più")
	_fine()


## Quando sparisce: una griglia fitta di punti sul corpo, nessuno nell'inquadratura e senza muri in mezzo.
func _su_sparito(b: Bambino) -> void:
	_sparito_a = _corso
	var cam := get_viewport().get_camera_3d()
	var occhio := p.get_eye_position()
	var space := p.get_world_3d().direct_space_state
	for h in range(0, 13):
		for l in range(-3, 4):
			var punto: Vector3 = b.global_position + b.global_basis.y * (h * 0.1) + b.global_basis.x * (l * 0.1)
			if cam and not cam.is_position_in_frustum(punto):
				continue
			var q := PhysicsRayQueryParameters3D.create(occhio, punto)
			q.exclude = [p.get_rid()]
			var hit := space.intersect_ray(q)
			if hit.is_empty() or hit.position.distance_to(punto) < 0.2:
				_visibile_quando_sparisce = true
				print("  in vista quando sparisce: ", punto)
				return


func _fine() -> void:
	print("risultato: %d ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		print("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
