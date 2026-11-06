extends Node
## Test delle ripartenze, parte B (scelta C = A+B dell'utente, GDD "Dopo la 0.3.20"): la prima morte a un checkpoint ha
## la scena intera (5 s); dalla seconda di fila allo stesso checkpoint dura 1,1 s (la presa fino al morso, poi nero).
## Un checkpoint nuovo o una nuova partita ricominciano dalla scena intera. Senza ricaricare il livello: la sequenza si
## stacca da GameState prima che finisca.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_morte_breve.gd

var _passed := 0
var _failed := 0
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(p)
	await _frames(5)
	GameState.player = p
	GameState.snapshot = {"scene": "res://prova.tscn", "checkpoint": "a"}

	var s1 := await _muori()
	check(not bool(s1[0]) and is_equal_approx(float(s1[1]), 5.0), "prima morte al checkpoint a: scena intera (%.1f s)" % s1[1])
	var s2 := await _muori()
	check(bool(s2[0]) and float(s2[1]) <= 1.1, "seconda morte allo stesso checkpoint: scena breve (%.1f s)" % s2[1])
	var s3 := await _muori()
	check(bool(s3[0]), "terza: ancora breve")

	print("Quanto dura davvero e come finisce")
	var seq := await _muori_e_aspetta()
	check(seq[0] >= 1.05 and seq[0] <= 1.2, "la scena breve finisce in %.2f s" % seq[0])
	check(seq[1] >= 0.99, "e finisce sul nero (%.2f)" % seq[1])
	check(not bool(seq[2]), "senza la scritta per saltarla")

	GameState.snapshot = {"scene": "res://prova.tscn", "checkpoint": "b"}
	var s4 := await _muori()
	check(not bool(s4[0]), "checkpoint nuovo: di nuovo la scena intera")
	var s5 := await _muori()
	check(bool(s5[0]), "e la seconda lì è breve")
	GameState.reset_progress()
	GameState.player = p
	GameState.snapshot = {"scene": "res://prova.tscn", "checkpoint": "b"}
	var s6 := await _muori()
	check(not bool(s6[0]), "nuova partita: di nuovo la scena intera")
	GameState.reset_progress()
	_fine()


## Muore e stacca subito la sequenza: [breve, durata].
func _muori() -> Array:
	var seq := _uccidi()
	var r := [bool(seq.get(&"breve")), float(seq.get(&"duration"))]
	_stacca(seq)
	await _frames(2)
	return r


## Muore e lascia andare la sequenza fino a "finished": [secondi, nero, scritta visibile].
func _muori_e_aspetta() -> Array:
	var seq := _uccidi()
	var scritta: bool = (seq.get(&"_hint") as Control).visible
	_stacca(seq, false)
	var fine := [false]
	seq.connect(&"finished", func(_s): fine[0] = true)
	var t := 0.0
	while not fine[0] and t < 10.0:
		await get_tree().process_frame
		t += 1.0 / 60.0
	var nero: float = (seq.get(&"_black") as ColorRect).color.a
	_stacca(seq)
	await _frames(2)
	return [t, nero, scritta]


func _uccidi() -> Node:
	GameState.is_dying = false
	p.input_enabled = true
	GameState.kill_player(&"prova")
	return GameState.get(&"_death_sequence") as Node


func _stacca(seq: Node, libera := true) -> void:
	for c in seq.get_signal_connection_list(&"finished"):
		if (c["callable"] as Callable).get_object() == GameState:
			seq.disconnect(&"finished", c["callable"])
	if libera:
		seq.queue_free()
		GameState.is_dying = false


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)
