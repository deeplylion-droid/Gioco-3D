extends Node
## La strada del capitolo col controller vero (richiesta del coordinatore del 23 ottobre, dopo lo stanzino chiuso
## nella build): dalla partenza nel corridoio del risveglio fino all'ingresso nella sala della torre, il giocatore
## cammina (tasto avanti e sguardo, come chi gioca) attraverso ogni porta della strada, raccoglie lo zaino-pompa
## nello stanzino, scende la scala del pozzo e va in barca sul fiume lento.
## Gli enigmi non si risolvono qui (li provano i loro test: test_interni, test_tappe56, test_risalita, test_tappa7,
## test_tappa8, test_acquari): si mettono nello stato risolto con una scorciatoia, detta nel log, e poi si cammina.
## Le stanze della Risalita si caricano come nel gioco (nel thread, dalla sala pompe), la torre pure.
## Se un tratto non si fa, il caso è fallito e il giocatore si mette alla fine del tratto, così il resto della strada
## si prova lo stesso.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_strada.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var level: Node
var p: Player
var tec: Node3D
var ris: Node
var _passed := 0
var _failed := 0
var _checkpoint_visti: Array[String] = []


func _ready() -> void:
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

	print("La sala al buio: l'area bimbi, la spiaggia, il portone della torre")
	print("  (scorciatoia: lei già tuffata nella fossa, la tappa 8 la prova test_tappa8)")
	var lei := level.get(&"lei_sbuca") as LeiSbuca
	lei.call(&"load_state", {"finita": true})
	var ritorno := level.get(&"ritorno") as RitornoAlBuio
	var cp_bimbi := (level.get_node(^"Gioco/CheckpointAreaBimbi") as Node3D).global_position
	var scia: Array[Vector3] = []
	var primo := -1
	var spazio := p.get_world_3d().direct_space_state
	for i in ritorno.scia.size():
		var q := ritorno.scia[i]
		var dal_centro := PhysicsRayQueryParameters3D.create(Vector3(0.0, 1.0, 10.0), Vector3(q.x, 1.0, q.z), Layers.BARRIERS)
		if primo < 0 and not spazio.intersect_ray(dal_centro).is_empty():
			primo = i
		if primo >= 0:
			scia.append(q)
			if Vector2(q.x - cp_bimbi.x, q.z - cp_bimbi.z).length() < 0.6:
				break
	# dalla serranda al punto della scia più vicino, poi lungo la scia fino all'area bimbi
	var vicino := 0
	for i in scia.size():
		if scia[i].distance_to(p.global_position) < scia[vicino].distance_to(p.global_position):
			vicino = i
	await _vai("dalla serranda lungo la scia fino all'area bimbi", scia.slice(vicino))
	print("  (scorciatoia: l'enigma degli acquari risolto, il portone si apre; lo prova test_acquari)")
	var portone := level.get(&"portone") as PortoneTorre
	portone.apri()
	await _vai("dall'area bimbi lungo la spiaggia fino al portone", [Vector3(-14.0, 0, -4.0), Vector3(-8.3, 0, -4.5),
		Vector3(-8.3, 0, -8.0), Vector3(-8.3, 0, -12.75), Vector3(0.0, 0, -12.75), Vector3(8.0, 0, -12.75), Vector3(15.0, 0, -14.0),
		Vector3(16.5, 0, -15.0)])
	var t0 := Time.get_ticks_msec()
	while (level.get(&"sala_torre") == null or not portone.is_aperto()) and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	check(level.get(&"sala_torre") != null and portone.is_aperto(), "il portone è aperto e dietro c'è la sala della torre")
	await _vai("attraverso il portone, sulla passerella della torre", [Vector3(19.8, 0, -15.0), Vector3(22.4, 0, -15.0)])
	await _frames(10)
	check(bool(level.get(&"_dentro_torre")), "si entra nella sala della torre")

	print("I checkpoint lungo la strada: %s" % ", ".join(_checkpoint_visti))
	for cp in ["CheckpointRisveglio", "CheckpointRaccordo", "CheckpointIngresso", "CheckpointApprodo", "CheckpointMagazzino",
			"CheckpointSerranda", "CheckpointAreaBimbi", "CheckpointTorre"]:
		check(cp in _checkpoint_visti, "checkpoint %s" % cp)
	_fine()


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
