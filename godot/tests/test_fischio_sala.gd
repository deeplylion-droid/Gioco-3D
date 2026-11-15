extends Node
## Il fischio nella sala al buio (build 0.5.0, LeiSalaAlBuio.fischio): nella sala vera, al buio,
## 1. il giocatore entra dalla serranda e cammina verso la vasca grande: un fischio solo, dal buio, lontano da lui (oltre
##    10 m); poi la luce va al punto d'uscita più vicino a lui con l'avviso intero (3,5 s: arriva, si spegne, silenzio) e
##    lei esce;
## 2. nello stesso attraversamento non fischia più;
## 3. mai durante un'uscita già in corso (il fischio arriva con lei LONTANA);
## 4. uscito dalla sala e rientrato, può fischiare di nuovo;
## 5. dopo la fossa niente fischio; con l'interruttore spento niente fischio.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_fischio_sala.gd

const LEVEL := "res://scenes/sala_principale.tscn"

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


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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
	var level := get_tree().current_scene
	var buio := level.find_child("LeiSalaAlBuio", true, false) as LeiSalaAlBuio
	var p := GameState.player as Player
	var acqua := buio.acqua
	buio.letale = false
	# (qui solo il fischio: il passaggio alla fossa da lontano, a 21 m, lo prova test_fossa_mai_di_sorpresa)
	buio.distanza_fossa_lontano = 0.0
	var fischi: Array = []
	buio.fischiato.connect(func(dove: Vector3): fischi.append([dove, p.global_position, acqua.fase]))
	GameState.imposta_luci(GameState.Luci.BLACKOUT)

	print("1. Dalla serranda verso la vasca grande")
	var pos := Vector3(-15.0, 0.05, 19.3)
	var meta := Vector3(-12.5, 0.05, 8.2)   # davanti al bordo sud della vasca grande, fuori dalla portata
	var t := 0.0
	var t_fischio := -1.0
	var fasi: Array = []
	var t_arriva := -1.0
	var t_esce := -1.0
	for i in 60 * 30:
		pos = pos.move_toward(meta, 3.4 / 60.0)
		p.teleport(pos)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if fischi.size() == 1 and t_fischio < 0.0:
			t_fischio = t
		if fasi.is_empty() or fasi[-1] != acqua.fase:
			fasi.append(acqua.fase)
			if acqua.fase == AcquaDiLei.Fase.ARRIVA and t_fischio >= 0.0 and t_arriva < 0.0:
				t_arriva = t
			if acqua.fase == AcquaDiLei.Fase.ESCE and t_arriva >= 0.0 and t_esce < 0.0:
				t_esce = t
		if t_esce >= 0.0 and acqua.fase == AcquaDiLei.Fase.CALMA:
			break
	check(fischi.size() == 1, "un fischio (%d)" % fischi.size())
	if fischi.is_empty():
		_fine()
		return
	var lontano := AcquaDiLei._in_pianta(fischi[0][0], fischi[0][1])
	check(lontano > 10.0, "dal buio, lontano dal giocatore (%.1f m)" % lontano)
	check(fischi[0][2] == AcquaDiLei.Fase.LONTANA, "con lei lontana: nessuna uscita in corso")
	check(t_arriva >= 0.0 and t_arriva - t_fischio < 1.0, "poi la luce parte verso il giocatore (%.2f s dopo)" % (t_arriva - t_fischio))
	check(t_esce >= 0.0 and absf(t_esce - t_arriva - acqua.avviso) < 0.1, "con l'avviso intero lei esce (%.2f s)" % (t_esce - t_arriva))
	var q_vicino: Node3D = null
	for q in acqua.punti_uscita:
		if q_vicino == null or AcquaDiLei._in_pianta(q.global_position, meta) < AcquaDiLei._in_pianta(q_vicino.global_position, meta):
			q_vicino = q
	check(acqua.get(&"_punto") == q_vicino, "dal punto d'uscita più vicino al giocatore")

	print("2. Nello stesso attraversamento non fischia più")
	for i in 60 * 25:
		p.teleport(meta + Vector3(4.0 * sin(i / 90.0), 0, 0))
		await get_tree().physics_frame
	check(fischi.size() == 1, "25 s ancora nella sala: nessun altro fischio (%d)" % fischi.size())

	print("3. Uscito e rientrato, fischia di nuovo")
	for i in 60 * 10:
		p.teleport(Vector3(-15.0, 0.05, 28.0))
		await get_tree().physics_frame
		if buio.stato == LeiSalaAlBuio.Stato.ATTESA:
			break
	check(buio.stato == LeiSalaAlBuio.Stato.ATTESA and not buio.fischio_fatto, "fuori dalla sala il giro finisce")
	pos = Vector3(-15.0, 0.05, 19.3)
	for i in 60 * 20:
		pos = pos.move_toward(meta, 3.4 / 60.0)
		p.teleport(pos)
		await get_tree().physics_frame
		if fischi.size() >= 2:
			break
	check(fischi.size() == 2, "rientrando, un fischio nuovo")

	print("4. Con l'interruttore spento niente fischio")
	for i in 60 * 10:
		p.teleport(Vector3(-15.0, 0.05, 28.0))
		await get_tree().physics_frame
		if buio.stato == LeiSalaAlBuio.Stato.ATTESA and acqua.fase == AcquaDiLei.Fase.LONTANA:
			break
	buio.fischio = false
	pos = Vector3(-15.0, 0.05, 19.3)
	for i in 60 * 12:
		pos = pos.move_toward(meta, 3.4 / 60.0)
		p.teleport(pos)
		await get_tree().physics_frame
	check(fischi.size() == 2, "spento: nessun fischio")
	buio.fischio = true

	print("5. Dopo la fossa niente fischio")
	var occhio := buio.lei_sbuca.punto_sbuca.global_position
	for i in 60 * 20:
		p.teleport(Vector3(occhio.x + 6.0, 0.05, occhio.z + 6.0))
		await get_tree().physics_frame
		if buio.stato == LeiSalaAlBuio.Stato.FINITO:
			break
	pos = Vector3(-12.5, 0.05, 12.0)
	for i in 60 * 10:
		p.teleport(pos)
		await get_tree().physics_frame
	check(buio.stato == LeiSalaAlBuio.Stato.FINITO and fischi.size() == 2, "passata la fossa: nessun fischio (%d)" % fischi.size())
	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
