extends Node
## Test della sala al buio (build 0.4.0, LeiSalaAlBuio): nella sala vera, al buio,
## 1. lontano dalla fossa la luce rosa gira nella vasca grande e nelle vasche dei bimbi, e lei alla fossa aspetta;
## 2. col giocatore sul bordo della vasca grande, quando la luce passa sotto quel punto lei esce (uscita intera) e,
##    se lui resta lì, lo prende (letale);
## 3. con letale spento esce e torna sotto senza prendere;
## 4. arrivati vicino alla fossa il giro finisce, la luce va nella fossa e lei si affaccia lì (la scena di oggi).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_sala_al_buio.gd

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


func _livello() -> Node:
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == LEVEL and GameState.player and is_instance_valid(GameState.player):
			break
	await _fisica(30)
	return get_tree().current_scene


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.reset_progress()
	var level := await _livello()
	var buio := level.find_child("LeiSalaAlBuio", true, false) as LeiSalaAlBuio
	var lei_sbuca := level.find_child("LeiSbuca", true, false) as LeiSbuca
	check(buio != null and buio.acqua != null and lei_sbuca != null, "c'è la sala al buio, col motore e la fossa")
	if buio == null or buio.acqua == null:
		_fine()
		return
	var p := GameState.player as Player
	var acqua := buio.acqua
	# il giocatore sul bordo sud della vasca grande, accanto al punto d'uscita di quel lato
	var vasca := buio.vasca_grande
	var bordo := vasca.to_global(Vector3(0, 0, vasca.inner_size.z * 0.5 + 0.4))
	bordo.y = 0.05
	p.teleport(bordo)
	await _fisica(5)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _fisica(10)

	print("1. Il giro")
	check(buio.stato == LeiSalaAlBuio.Stato.GIRO and acqua.in_giro() and AcquaDiLei.chi_la_usa() == acqua,
			"al buio, lontano dalla fossa, la luce gira: lei è lì")
	check(not lei_sbuca.medusa.visible and lei_sbuca.fase == LeiSbuca.Fase.ATTESA, "e alla fossa non c'è ancora")

	print("2. Sul bordo, quando la luce passa lì, esce e prende")
	var uscita := false
	var presa := false
	for i in 60 * 40:
		p.teleport(bordo)
		await get_tree().physics_frame
		if acqua.fase == AcquaDiLei.Fase.ESCE or acqua.fase == AcquaDiLei.Fase.SU:
			uscita = true
		if GameState.is_dying:
			presa = true
			break
	check(uscita, "la luce passa sotto il punto vicino al bordo: lei esce dalla vasca grande")
	check(presa and GameState.last_death_cause == &"medusa", "e prende il giocatore rimasto sul bordo")
	if presa:
		# la ripartenza: la sala si ricarica
		for i in 60 * 30:
			await get_tree().process_frame
			if not GameState.is_dying and GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene != level:
				break
		await _fisica(60)
		level = get_tree().current_scene
		buio = level.find_child("LeiSalaAlBuio", true, false) as LeiSalaAlBuio
		lei_sbuca = level.find_child("LeiSbuca", true, false) as LeiSbuca
		acqua = buio.acqua
		p = GameState.player as Player
		vasca = buio.vasca_grande

	print("3. Solo paura")
	buio.letale = false
	bordo = vasca.to_global(Vector3(0, 0, vasca.inner_size.z * 0.5 + 0.4))
	bordo.y = 0.05
	var uscita2 := false
	var tornata := false
	for i in 60 * 50:
		p.teleport(bordo)
		await get_tree().physics_frame
		if acqua.fase == AcquaDiLei.Fase.SU:
			uscita2 = true
		if uscita2 and acqua.fase == AcquaDiLei.Fase.CALMA:
			tornata = true
			break
	check(uscita2 and tornata and not GameState.is_dying, "con letale spento esce, incombe e torna sotto senza prendere")

	print("4. Verso la fossa")
	var fossa := lei_sbuca.punto_sbuca.global_position
	var vicino := fossa + Vector3(2.0, 0.0, 2.0)
	vicino.y = 0.05
	for i in 60 * 12:
		p.teleport(vicino)
		await get_tree().physics_frame
		if lei_sbuca.medusa.visible:
			break
	check(buio.stato == LeiSalaAlBuio.Stato.FINITO and not acqua.in_giro(), "vicino alla fossa il giro finisce")
	check(lei_sbuca.medusa.visible and (lei_sbuca.fase == LeiSbuca.Fase.GUARDA or lei_sbuca.fase == LeiSbuca.Fase.SBUCA),
			"e lei è alla fossa, come oggi")
	check(AcquaDiLei.chi_la_usa() == null, "il motore l'ha lasciata")
	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
