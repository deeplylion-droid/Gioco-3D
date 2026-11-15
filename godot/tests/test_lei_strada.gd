extends Node
## Dov'è lei sulla strada vera (build 0.4.0), nella sala intera con LeiSalaAlBuio, la fossa e la Risalita caricata:
## 1. dopo la leva (blackout), col giocatore nella sala pompe, nella stanza delle pozze e nell'infermeria, la sala al
##    buio non tiene lei (il giro non parte) e uno specchio lì vicino la può chiamare, anche con la lei della fossa
##    visibile (lontana, fuori vista);
## 2. all'uscita della serranda, dentro la sala, il giro parte; tornando nel magazzino finisce e lei è libera;
## 3. arrivati alla fossa il giro finisce e la sala al buio si spegne (gli acquari sono una pausa: niente canto);
## 4. un'altra lei davvero in vista (la fossa davanti, a pochi metri) blocca.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_lei_strada.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var _ok := 0
var _ko := 0
var level: Node
var p: Player


func _ready() -> void:
	_run.call_deferred()


func check(c: bool, msg: String) -> void:
	if c:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _sta(pos: Vector3, n := 60) -> void:
	for i in n:
		p.teleport(pos)
		await get_tree().physics_frame


## Uno specchio di prova con un punto d'uscita a 2 m dal giocatore (come le pozze di enigmi), al suo piano.
func _specchio(vicino: Vector3) -> AcquaDiLei:
	var a := AcquaDiLei.new()
	a.name = "SpecchioProva"
	a.pelo = vicino.y
	var m := Marker3D.new()
	m.name = "Uscita0"
	a.add_child(m)
	level.add_child(a)
	m.global_position = vicino + Vector3(2.0, 0.0, 0.0)
	var lista: Array[Node3D] = [m]
	a.punti_uscita = lista
	return a


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == LEVEL and GameState.player and is_instance_valid(GameState.player):
			break
	await _fisica(30)
	level = get_tree().current_scene
	p = GameState.player as Player
	var buio := level.find_child("LeiSalaAlBuio", true, false) as LeiSalaAlBuio
	var sbuca := level.find_child("LeiSbuca", true, false) as LeiSbuca
	var ris := level.get_node(^"Risalita")
	check(buio != null and buio.acqua != null and sbuca != null and ris != null, "c'è la sala intera, con la sala al buio, la fossa e la Risalita")
	if buio == null or buio.acqua == null or ris == null:
		_fine()
		return
	ris.call(&"carica_subito")
	await _fisica(30)
	var pompe := (level.find_child("CheckpointSalaPompe", true, false) as Checkpoint).spawn_point.global_position
	var inf := (ris.get_node(^"Infermeria") as Node3D).global_position
	var pozze := (ris.get_node(^"StanzaPozze") as Node3D).to_global(Vector3(0, 0, 3.4))
	await _sta(pompe, 5)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)

	print("1. Dopo la leva, lontano dalla sala al buio")
	for z in [["nella sala pompe", pompe], ["nella stanza delle pozze", pozze], ["nell'infermeria", inf]]:
		await _sta(z[1] + Vector3(0, 0.05, 0))
		check(buio.stato == LeiSalaAlBuio.Stato.ATTESA and AcquaDiLei.chi_la_usa() != buio.acqua,
				"%s la sala al buio non tiene lei (stato %d)" % [z[0], buio.stato])
		var sp := _specchio(p.global_position)
		await _fisica(2)
		check(sp.puo_venire(), "%s uno specchio lì vicino la può chiamare" % z[0])
		sbuca.medusa.visible = true    # (la lei della fossa lasciata visibile: lontana, fuori vista)
		await _fisica(2)
		check(sp.puo_venire(), "%s anche con la lei della fossa visibile, lontana" % z[0])
		sbuca.medusa.visible = false
		sp.queue_free()
		await _fisica(2)

	print("2. La serranda e il magazzino")
	await _sta(Vector3(-15.0, 0.05, 16.5), 90)
	check(buio.stato == LeiSalaAlBuio.Stato.GIRO and AcquaDiLei.chi_la_usa() == buio.acqua and buio.acqua.in_giro(),
			"usciti dalla serranda, nella sala: il giro parte")
	await _sta(Vector3(-15.0, 0.05, 29.0), 60)
	check(buio.stato == LeiSalaAlBuio.Stato.ATTESA and AcquaDiLei.chi_la_usa() == null and not buio.acqua.in_giro(),
			"tornati nel magazzino: il giro finisce e lei è libera")

	print("3. La fossa")
	var fossa := sbuca.punto_sbuca.global_position
	await _sta(Vector3(-15.0, 0.05, 16.5), 30)
	var vicino := fossa + Vector3(2.0, 0.0, 2.0)
	vicino.y = 0.05
	await _sta(vicino, 60 * 4)
	check(buio.stato == LeiSalaAlBuio.Stato.FINITO and not buio.acqua.abilitata and buio.acqua.fase_canto == &"ferma",
			"alla fossa il giro finisce e la sala al buio tace (fase_canto %s)" % buio.acqua.fase_canto)
	print("4. Un'altra lei davvero in vista")
	var davanti := fossa + Vector3(0, 0, 6)
	davanti.y = 0.05
	await _sta(davanti, 10)
	p.look_at_point(fossa + Vector3.UP * 1.2)
	await _fisica(2)
	var sp2 := _specchio(p.global_position)
	sbuca.medusa.visible = true
	await _fisica(2)
	check(sp2.lei_in_vista_altrove(), "la lei della fossa davanti, a 6 m: conta (non se ne vedono due)")
	sbuca.medusa.visible = false
	sp2.queue_free()
	await _fisica(2)

	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
