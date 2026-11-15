extends Node
## Test dei contatori della partita e del riepilogo di fine capitolo (build 0.5.0):
## - GameState.tempo_gioco conta solo col giocatore nel livello e senza pausa (non nel titolo né nei caricamenti, dove il
##   giocatore non c'è), e si ferma alla fine del capitolo; morti_totali sale a ogni morte;
## - restano dopo una morte (la ripartenza non li tocca), vanno nell'istantanea e nel salvataggio su disco (anche alla
##   morte, senza un checkpoint dopo), Continua li ritrova (prepara_ripresa non li azzera dopo averli letti), la partita
##   nuova li azzera;
## - il riepilogo: Polaroid su 16, tempo, morti, in italiano e in inglese; un tasto non lo chiude prima di 4 s, dopo sì;
##   da solo torna al titolo dopo 25 s.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_contatori.gd

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(c: bool, msg: String) -> void:
	if c:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	# il salvataggio di chi lancia il test resta com'era
	var prima := FileAccess.get_file_as_string(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else ""
	GameState.reset_progress()
	check(GameState.tempo_gioco == 0.0 and GameState.morti_totali == 0, "la partita nuova parte da zero")

	print("== il tempo di gioco")
	await _secondi(1.0)
	check(GameState.tempo_gioco == 0.0, "senza il giocatore (titolo, caricamenti) il tempo non conta")
	var stanza := Node3D.new()
	stanza.name = "StanzaProva"
	get_tree().root.add_child(stanza)
	get_tree().current_scene = stanza
	var pav := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	cs.shape = box
	pav.add_child(cs)
	stanza.add_child(pav)
	pav.position = Vector3(0, -0.1, 0)
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	stanza.add_child(p)
	await _secondi(0.2)
	GameState.player = p
	var t0 := GameState.tempo_gioco
	await _secondi(2.0)
	var conto := GameState.tempo_gioco - t0
	check(absf(conto - 2.0) < 0.1, "col giocatore nel livello conta (%.2f s in 2 s)" % conto)
	Game.set_paused(true)
	var t1 := GameState.tempo_gioco
	for i in 120:
		await get_tree().process_frame
	check(GameState.tempo_gioco == t1, "in pausa no")
	Game.set_paused(false)

	print("== le morti, l'istantanea e il disco")
	GameState.capture_snapshot("prova", 1, Transform3D())
	check(is_equal_approx(float(GameState.snapshot.get("tempo_gioco", -1.0)), GameState.tempo_gioco)
			and int(GameState.snapshot.get("morti_totali", -1)) == 0, "l'istantanea del checkpoint ha i contatori")
	GameState.save_to_disk = true
	GameState.kill_player(&"prova")
	GameState.save_to_disk = false
	check(GameState.morti_totali == 1, "una morte: 1")
	var su_disco = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH)) if FileAccess.file_exists(GameState.SAVE_PATH) else {}
	check(typeof(su_disco) == TYPE_DICTIONARY and int(su_disco.get("morti_totali", -1)) == 1 and float(su_disco.get("tempo_gioco", 0.0)) > 1.5,
			"alla morte i contatori vanno su disco, anche senza un checkpoint dopo")
	# (la sequenza della morte non serve: niente ripartenza in questa stanza)
	for n in GameState.get_children():
		if n is DeathSequence:
			n.queue_free()
	GameState.is_dying = false
	p.input_enabled = true
	await _secondi(0.2)
	var tempo := GameState.tempo_gioco
	check(GameState.morti_totali == 1 and tempo > 2.0, "dopo la morte restano (tempo %.1f s, morti %d)" % [tempo, GameState.morti_totali])

	print("== Continua e partita nuova")
	var dati := (GameState.snapshot as Dictionary).duplicate(true)
	GameState.reset_progress()
	check(GameState.tempo_gioco == 0.0 and GameState.morti_totali == 0, "tornando al titolo (partita nuova) si azzerano")
	GameState.prepara_ripresa(dati)
	GameState._restore_pending = false
	check(absf(GameState.tempo_gioco - float(dati["tempo_gioco"])) < 0.01 and GameState.morti_totali == 1,
			"Continua li ritrova (tempo %.1f s, morti %d)" % [GameState.tempo_gioco, GameState.morti_totali])
	GameState.tempo_fermo = true
	var t2 := GameState.tempo_gioco
	await _secondi(0.5)
	check(GameState.tempo_gioco == t2, "dalla fine del capitolo il tempo è fermo")
	GameState.tempo_fermo = false
	check(GameState.tempo_leggibile(65.4) == "1:05" and GameState.tempo_leggibile(3725.0) == "1:02:05", "il tempo come si legge (1:05, 1:02:05)")

	print("== il riepilogo")
	GameState.tempo_gioco = 754.0
	GameState.morti_totali = 3
	var r := RiepilogoCapitolo.mostra(stanza)
	await _secondi(0.2)
	var testi := r.righe.map(func(l: Label): return l.text)
	check(testi.size() == 3 and testi[0] == "Polaroid trovate: %d su 16" % PolaroidPhoto.quante_trovate() and testi[1] == "Tempo: 12:34"
			and testi[2] == "Morti: 3", "in italiano: %s" % [testi])
	r.queue_free()
	var lingua := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var en := RiepilogoCapitolo.mostra(stanza)
	await _secondi(0.2)
	var testi_en := en.righe.map(func(l: Label): return l.text)
	check(testi_en[0].begins_with("Polaroids found:") and testi_en[1] == "Time: 12:34" and testi_en[2] == "Deaths: 3", "in inglese: %s" % [testi_en])
	TranslationServer.set_locale(lingua)
	var chiuso := [false]
	en.finito.connect(func(): chiuso[0] = true)
	await _secondi(1.0)
	_tasto()
	await _secondi(0.3)
	check(not chiuso[0], "un tasto prima di 4 s non lo chiude")
	# da solo dopo 25 s (qui si guarda il segnale: il titolo vero lo prova test_fine_titolo col tasto)
	var t3 := Time.get_ticks_msec()
	while not chiuso[0] and Time.get_ticks_msec() - t3 < 40000:
		await get_tree().process_frame
	check(chiuso[0], "da solo dopo 25 s torna al titolo")
	var t4 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t4 < 90000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == Game.SCENE_TITLE:
			break
	var fine := get_tree().current_scene
	check(fine and fine.scene_file_path == Game.SCENE_TITLE, "ed è il titolo (%s)" % (fine.scene_file_path if fine else "niente"))
	if prima != "":
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		f.store_string(prima)
		f.close()
	else:
		DirAccess.remove_absolute(GameState.SAVE_PATH)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _tasto() -> void:
	for giu in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		ev.pressed = giu
		Input.parse_input_event(ev)
