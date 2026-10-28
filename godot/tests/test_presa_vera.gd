extends Node
## Lo spavento vero della tappa 8 nel gioco (crash segnalato dall'utente sulla v0.3.14, 25 ottobre: "il gioco crasha
## dopo il primo spavento", su un PC nuovo, la prima volta). La strada di test_strada fino alla serranda (stesse
## scorciatoie: così Risalita e torre si caricano nel thread come nel gioco), poi lungo la scia fino alla fossa
## dell'area bimbi: lei ti prende, la sequenza di morte va fino in fondo senza saltarla (urlo e glitch), la sala
## si ricarica dal checkpoint e si gioca ancora 30 s. Stampa lo stato dei caricamenti nel thread e la memoria.
## Alla presa la torre si sta ancora caricando nel thread (dalla serranda): la sala deve ricaricarsi solo quando il
## caricamento è finito (GameState.respawn, Game.aspetta_caricamenti), e dalla presa a 30 s dopo non ci devono essere
## errori del motore o degli script.
## Con l'argomento "corto" (per il renderer vero, tests/collaudo/presa_vulkan.gd) si va dal risveglio subito alla scia.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_presa_vera.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var level: Node
var p: Player
var tec: Node3D
var ris: Node
var _passed := 0
var _failed := 0
var _checkpoint_visti: Array[String] = []
var _errori := ContaErrori.new()


## Gli errori del motore e degli script dalla presa in poi: nel gioco esportato un accesso a un oggetto già liberato, che
## qui è solo un errore, può essere un crash. Gli avvisi e il renderer finto dei test headless non contano.
class ContaErrori extends Logger:
	var attivo := false
	var errori: PackedStringArray = []
	var _m := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if not attivo or error_type == Logger.ERROR_TYPE_WARNING or file.contains("rendering/dummy"):
			return
		_m.lock()
		errori.append("%s (%s:%d, %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		_m.unlock()


func _ready() -> void:
	OS.add_logger(_errori)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.reset_progress()
	GameState.checkpoint_reached.connect(func(id): _checkpoint_visti.append(id.get_file()))
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	level = get_tree().current_scene
	p = GameState.player
	tec = level.get_node(^"Tecnici") as Node3D
	ris = level.get_node(^"Risalita")
	# il risveglio nel corridoio: i comandi arrivano alla fine della scena
	for i in 60 * 60:
		if p.input_enabled:
			break
		await get_tree().physics_frame
	check(p.input_enabled, "dopo il risveglio nel corridoio si gioca (%s)" % p.global_position)
	if OS.get_cmdline_user_args().has("corto"):
		# (per il renderer vero, dove la strada intera non sta nella memoria: dal risveglio subito alla scia, e la torre
		# comincia a caricarsi nel thread come quando la serranda si apre)
		print("  (corto: dal risveglio alla scia dell'area bimbi; la torre si comincia a caricare come alla serranda)")
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
		level.call(&"_precarica_torre")
		p.teleport(Vector3(-18.3, 0.0, 2.6), 0.0, 0.0)
		p.input_enabled = true
		await _frames(10)
		await _presa()
		return
	var interni := level.get_node(^"Interni")

	print("Gli interni: corridoio, spogliatoi, lo stanzino del bagnino con lo zaino")
	await _vai("dal corridoio del risveglio agli spogliatoi", [Vector3(4.3, 0, 39.6), Vector3(-2.9, 0, 39.6), Vector3(-2.9, 0, 37.0)])
	await _vai("dagli spogliatoi dentro lo stanzino", [Vector3(-1.5, 0, 34.0), Vector3(-1.0, 0, 32.45), Vector3(2.5, 0, 32.45), Vector3(3.6, 0, 32.47)])
	var zaino: Node3D = level.find_children("*", "PackPickup", true, false).front() as Node3D if not level.find_children("*", "PackPickup", true, false).is_empty() else null
	if zaino:
		p.look_at_point(zaino.global_position + Vector3(0, 0.35, 0))
		await _frames(3)
		print("  (zaino in %s, il raggio trova %s)" % [zaino.global_position, p.interactor.current])
		await _premi(&"interact")
		await _frames(5)
	check(p.water_pack.equipped and p.has_item(&"zaino_pompa"), "nello stanzino si prende lo zaino-pompa dalla rastrelliera (in %s, il raggio trova %s)" % [p.global_position.snapped(Vector3.ONE * 0.01), p.interactor.current])
	await _vai("dallo stanzino al lavapiedi, fino al tornello", [Vector3(2.5, 0, 32.45), Vector3(-1.0, 0, 32.45),
		Vector3(-0.45, 0, 31.2), Vector3(-0.45, 0, 28.5), Vector3(0, 0, 26.6)])
	print("  (scorciatoia: il tornello sbloccato col getto, lo prova test_interni)")
	interni.call(&"_sblocca_tornello")
	await _vai("il tornello", [Vector3(0, 0, 25.0), Vector3(0, 0, 22.9)])
	print("  (scorciatoia: la saracinesca aperta con la turbina, lo prova test_interni)")
	var saracinesca := interni.find_child("Saracinesca", true, false)
	saracinesca.call(&"load_state", {"latched": true, "open": 1.0})
	await _frames(10)
	await _vai("sotto la saracinesca, nella sala, fino alla statua", [Vector3(0, 0, 20.3), Vector3(0, 0, 18.5), Vector3(0, 0, 14.4)])

	print("La sala: la piscina a onde e il pozzo")
	print("  (scorciatoia: la piscina vuota e il portello aperto, la tappa 5 la prova test_tappe56)")
	var pozza := level.get_node_or_null(^"Piscina/Pozza")
	if pozza and pozza.has_method(&"load_state"):
		pozza.call(&"load_state", {"fill": 0.0})
	(level.get_node(^"Piscina/Portello")).call(&"load_state", {"open": true})
	await _frames(10)
	p.teleport(Vector3(0.0, -2.2, 3.25), 0.0, 0.0)
	await _frames(10)
	p.set_look(0.0, deg_to_rad(-60.0))
	Input.action_press(&"move_forward")
	for i in 900:
		await get_tree().physics_frame
		if not p.is_on_ladder() and p.is_on_floor() and p.global_position.y < -8.5:
			break
	Input.action_release(&"move_forward")
	await _frames(5)
	check(p.global_position.y < -8.5, "giù per la scala del pozzo fino alla camera delle onde (y %.2f)" % p.global_position.y)
	await _vai("la camera delle onde: le paratie si aprono al passaggio, il tunnel fino alla sala pompe",
		[tec.to_global(Vector3(4.0, 0, 0.3)), tec.to_global(Vector3(16.0, 0, 0.3)), tec.to_global(Vector3(23.0, 0, 0.0)),
		tec.to_global(Vector3(27.0, 0, 0.0)), tec.to_global(Vector3(31.0, 0, 0.0))])

	print("La sala pompe, il risveglio e il raccordo")
	print("  (scorciatoia: le pompe avviate e la leva tirata, li prova test_tappe56)")
	GameState.imposta_luci(GameState.Luci.FLASH)
	await _frames(70)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var maniglione := tec.get_node(^"Logica/SalaPompe/Maniglione") as PortaManiglione
	maniglione.call(&"load_state", {"aperta": false, "bloccata": false})
	var cp_ris := tec.get_node(^"Logica/Checkpoint/CheckpointRisveglio") as Checkpoint
	GameState.reach_checkpoint(cp_ris)
	var porta_ponte := tec.to_global(_m("marker_porta_ponte"))
	# (girando a est intorno alla vasca di raccolta, la fossa in mezzo alla sala)
	await _vai("nella sala pompe fino alla porta del ponte inferiore", [Vector3(2.0, -9.05, 34.0), Vector3(2.0, -9.05, 43.0), porta_ponte])
	p.look_at_point(porta_ponte + Vector3(1.0, 1.0, 0.0))
	await _frames(3)
	maniglione.interact(p)
	await _frames(120)
	check(maniglione.is_open, "col maniglione la porta del ponte si apre")
	await _vai("dalla porta del ponte su per le due rampe del raccordo", [tec.to_global(Vector3(47.4, 0, 1.4)),
		tec.to_global(Vector3(51.6, 0, 1.4)), tec.to_global(Vector3(51.6, 0, 0.6)), tec.to_global(Vector3(51.6, 3.625, -6.2)),
		tec.to_global(Vector3(50.0, 3.625, -7.8)), tec.to_global(Vector3(44.6, 7.25, -7.8))])
	await _vai("il corridoio C2 fino alla porta di servizio", [tec.to_global(Vector3(44.55, 7.25, -4.0)),
		tec.to_global(Vector3(44.55, 9.05, 2.0)), tec.to_global(Vector3(44.55, 7.25, -5.1)), _mr("PortaC2")])

	print("La Risalita: la scala verso il fiume, il capannone, la barca, l'infermeria, la scala di servizio")
	await _vai("dalla porta di servizio giù per la scala fino al capannone", [_mr("CimaScalaFiume"), _mr("FondoScalaFiume"),
		_mr("PortaFiume")])
	check(ris.get(&"fiume") != null, "le stanze della Risalita sono caricate (nel thread, dalla sala pompe)")
	if ris.get(&"fiume") == null:
		ris.call(&"carica_subito")
		await _frames(30)
	var fiume := ris.get_node(^"Fiume/FiumeLento") as FiumeLento
	await _vai("nel capannone fino all'imbarco", [(ris.get_node(^"Fiume/Marker/Ingresso") as Node3D).global_position,
		(ris.get_node(^"Fiume/Marker/FineFila") as Node3D).global_position, (ris.get_node(^"Fiume/Marker/Imbarco") as Node3D).global_position])
	print("  (scorciatoia: le paratie girate per il giro giusto, lo prova test_risalita)")
	(fiume.get_node(^"Paratia1") as ParatiaFiume).a_destra = false
	(fiume.get_node(^"Paratia3") as ParatiaFiume).a_destra = false
	var giro := {"fuori": false}
	fiume.uscito.connect(func(): giro.fuori = true, CONNECT_ONE_SHOT)
	fiume.sali(p)
	for i in 60 * 120:
		await get_tree().physics_frame
		if giro.fuori:
			break
	await _frames(30)
	check(giro.fuori and p.is_on_floor() and absf(p.global_position.y + 5.4) < 0.15, "in barca fino all'approdo, giù sulla banchina (%s)" % p.global_position)
	var porta := ris.get_node(^"Fiume/Marker/PortaPersonale") as Node3D
	var inf := ris.get_node(^"Infermeria") as Node3D
	# (la porta nord resta chiusa finché non colpisci il pulsantone: richiesta dell'utente del 25 ottobre)
	print("  (scorciatoia: il pulsantone dell'infermeria colpito col getto, la porta nord si apre; lo prova test_infermeria_gioco)")
	inf.get_node(^"Interruttore").set(&"powered", true)
	await _vai("dall'approdo, porta di servizio, zona del personale, infermeria, porta nord", [
		porta.global_position + porta.global_basis.z * 0.8, porta.global_position - porta.global_basis.z * 1.5,
		inf.to_global(Vector3(1.6, 0, 3.6)), inf.to_global(Vector3(1.8, 0, 1.6)), inf.to_global(Vector3(0.0, 0, 0.0)),
		inf.to_global(Vector3(-2.2, 0, -2.4)), inf.to_global(Vector3(-2.2, 0, -3.8))])
	await _vai("su per la scala di servizio fino alla porta di C3", [Vector3(p.global_position.x, 0, _mr("PortaC3").z),
		_mr("CimaScala"), _mr("PortaC3")])

	print("C3, il magazzino, la serranda, la sala")
	await _vai("da C3 al magazzino dei gonfiabili", [tec.to_global(Vector3(37.09, 9.05, 15.0)), tec.to_global(Vector3(30.0, 9.05, 15.0)),
		tec.to_global(Vector3(26.5, 9.05, 15.0)), tec.to_global(Vector3(21.0, 9.05, 15.9))])
	print("  (scorciatoia: la keycard della cassaforte, la provano test_infermeria_gioco e test_risalita)")
	p.add_item(&"keycard", 1, "Keycard")
	var lettore := tec.find_child("LettoreTessera", true, false) as LettoreTessera
	p.look_at_point(lettore.global_position)
	await _frames(6)
	await _premi(&"interact")
	await _frames(5)
	check(lettore.aperto, "la keycard nel lettore col tasto E: verde")
	await _vai("sotto la serranda, nella sala", [tec.to_global(Vector3(19.3, 9.05, 15.0)), tec.to_global(Vector3(17.9, 9.05, 15.0))], 1200)

	await _presa()


func _presa() -> void:
	print("La sala al buio: lungo la scia fino alla fossa dell'area bimbi, lei ti prende")
	var lei := level.get(&"lei_sbuca") as LeiSbuca
	if lei and not lei.abilitata:
		lei.abilitata = true
	var ritorno := level.get(&"ritorno") as RitornoAlBuio
	var scia := ritorno.scia
	var vicino := 0
	for i in scia.size():
		if scia[i].distance_to(p.global_position) < scia[vicino].distance_to(p.global_position):
			vicino = i
	_stato("alla serranda")
	Input.action_press(&"move_forward")
	for k in range(vicino, scia.size()):
		for i in 600:
			var d := scia[k] - p.global_position
			if Vector2(d.x, d.z).length() < 0.35 or GameState.is_dying:
				break
			p.set_look(atan2(-d.x, -d.z), 0.0)
			await get_tree().physics_frame
		if GameState.is_dying:
			break
	Input.action_release(&"move_forward")
	check(GameState.is_dying and lei.fase == LeiSbuca.Fase.PRESA, "lungo la scia, alla fossa, lei ti prende (in %s)" % p.global_position.snapped(Vector3.ONE * 0.01))
	_stato("presa")
	var vecchia := level
	var seq := GameState.get_children().filter(func(n): return n is DeathSequence)
	check(seq.size() == 1 and (seq[0] as DeathSequence).cause == &"medusa", "parte la sequenza di morte di lei, che non si salta")
	var glitch := (seq[0] as Node).find_children("*", "JumpscareGlitch", true, false) if seq.size() == 1 else []
	check(glitch.size() == 1, "con il jumpscare (glitch e urlo)")
	_errori.attivo = true
	var t0 := Time.get_ticks_msec()
	var f := 0
	var in_corso := false
	var attesa_da := -1
	var spia := false
	while (get_tree().current_scene == vecchia or get_tree().current_scene == null) and Time.get_ticks_msec() - t0 < 150000:
		in_corso = Game.caricamenti_in_corso()
		if attesa_da < 0 and vecchia.process_mode == Node.PROCESS_MODE_DISABLED:
			attesa_da = Time.get_ticks_msec()
		spia = spia or get_tree().root.has_node(^"AttesaCaricamenti")
		if f == 270 and not Game.caricamenti_in_corso():
			# (la torre ha già finito, come su un PC veloce: perché la ripartenza trovi lo stesso un caricamento nel thread
			# in corso, alla fine della sequenza comincia quello del tunnel)
			var tunnel := String(vecchia.get(&"sala_sottomarino_scena"))
			if tunnel != "" and Game.carica_in_thread(tunnel, "PackedScene") == OK:
				print("  (la torre è già caricata: alla fine della sequenza comincia il caricamento del tunnel nel thread)")
		await get_tree().process_frame
		f += 1
	print("  (sala ricaricata dopo %d fotogrammi, %.1f s; finita la sequenza, %.1f s fino alla sala nuova)" % [f,
		(Time.get_ticks_msec() - t0) / 1000.0, (Time.get_ticks_msec() - attesa_da) / 1000.0 if attesa_da >= 0 else 0.0])
	_stato("ricaricata")
	check(get_tree().current_scene != vecchia and f >= 60 * 5 - 5, "la sequenza va fino in fondo (5 s) e poi la sala si ricarica")
	check(not in_corso, "la sala si ricarica solo a caricamenti nel thread finiti (la torre, dalla serranda)")
	var attesa := GameState.attesa_ripartenza
	print("  (la ripartenza ha aspettato i caricamenti per %.1f s)" % attesa)
	check(spia or attesa < Game.ATTESA_SPIA + 0.1, "se l'attesa è lunga si vede la spia del caricamento (%.1f s, spia %s)" % [attesa, spia])
	# (a tempo: la ripartenza aspetta i caricamenti nel thread, anche qualche secondo)
	var t_attesa := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_attesa < 90000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying and GameState.player.input_enabled:
			break
	level = get_tree().current_scene
	p = GameState.player
	check(p != null and is_instance_valid(p) and p.input_enabled and not GameState.is_dying, "si riparte dal checkpoint e si gioca (%s)" % _checkpoint())
	lei = level.get(&"lei_sbuca") as LeiSbuca
	if lei and not lei.abilitata:
		lei.abilitata = true
	print("30 s di gioco dopo la ripartenza")
	t0 = Time.get_ticks_msec()
	for s in 30:
		# qualche passo avanti e indietro lungo la scia, lontano dalla fossa
		p.set_look(PI if s % 2 == 0 else 0.0, 0.0)
		Input.action_press(&"move_forward")
		await _frames(20)
		Input.action_release(&"move_forward")
		await _frames(40)
		if s % 5 == 4:
			_stato("dopo %d s" % (s + 1))
	check(is_instance_valid(p) and not GameState.is_dying, "dopo 30 s si gioca ancora (%.1f s veri)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_errori.attivo = false
	for e in _errori.errori.slice(0, 20):
		printerr("    ", e)
	check(_errori.errori.is_empty(), "dalla presa a 30 s dopo la ripartenza nessun errore del motore o degli script (%d)" % _errori.errori.size())
	_fine()



func _checkpoint() -> String:
	return String(GameState.snapshot.get("checkpoint", "")).get_file()


## Stato dei caricamenti nel thread, della torre e della memoria.
func _stato(quando: String) -> void:
	var parti: PackedStringArray = []
	var finiti := 0
	for percorso in Game.get(&"_caricamenti"):
		var st := ResourceLoader.load_threaded_get_status(percorso)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS or st == ResourceLoader.THREAD_LOAD_LOADED:
			parti.append("%s %s" % [String(percorso).get_file(), "in corso" if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS else "caricato"])
		else:
			finiti += 1
	parti.append("altri %d finiti" % finiti)
	var sala := get_tree().current_scene
	var torre := ""
	if sala:
		torre = "torre: in caricamento %s, pronta %s, nascosta %s, in sala %s" % [sala.get(&"_torre_in_caricamento"),
			sala.get(&"_torre_pronta") != null, sala.get(&"_torre_nascosta"), sala.get(&"sala_torre") != null]
	print("  [stato %s, %.1f s] thread: %s | %s | pipeline draw %d spec %d | memoria statica %d MB, oggetti %d, nodi %d, orfani %d" % [quando,
		Time.get_ticks_msec() / 1000.0, ", ".join(parti), torre,
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)),
		int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])


## Cammina per i punti in fila (tasto avanti, sguardo verso il punto, come chi gioca). Se un punto non si raggiunge,
## il tratto è fallito: si dice dove si è fermato e il giocatore va alla fine del tratto.
func _vai(nome: String, punti: Array, per_punto := 900) -> bool:
	for k in punti.size():
		var t: Vector3 = punti[k]
		if not await _cammina_verso(t, per_punto):
			check(false, "%s: fermo in %s andando verso il punto %d %s" % [nome, p.global_position.snapped(Vector3.ONE * 0.01), k, t.snapped(Vector3.ONE * 0.01)])
			var fine: Vector3 = punti[punti.size() - 1]
			p.teleport(fine + Vector3(0, 0.05, 0), p.yaw, 0.0)
			await _frames(10)
			return false
	check(true, nome)
	return true


func _cammina_verso(t: Vector3, max_frames: int) -> bool:
	Input.action_press(&"move_forward")
	var arrivato := false
	var fermo := 0
	var prima := p.global_position
	for i in max_frames:
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			arrivato = true
			break
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
		# fermo da 3 s contro qualcosa: inutile aspettare
		if i % 60 == 59:
			fermo = fermo + 1 if p.global_position.distance_to(prima) < 0.05 else 0
			prima = p.global_position
			if fermo >= 3:
				break
	Input.action_release(&"move_forward")
	return arrivato


func _premi(azione: StringName) -> void:
	Input.action_press(azione)
	await _frames(2)
	Input.action_release(azione)


func _m(nome: String) -> Vector3:
	return (tec.get_node("Marker/" + nome) as Node3D).position


func _mr(nome: String) -> Vector3:
	return (ris.get_node("Marker/" + nome) as Node3D).global_position


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
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)
