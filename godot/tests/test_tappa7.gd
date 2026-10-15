extends Node
## Test automatico della tappa 7 (docs/livello/capitolo1.md), il ritorno al buio dopo il risveglio
## della sala pompe, simulando gli input. Prima del risveglio: la porta "sala pompe" del corridoio
## degli interni è chiusa e bloccata, la medusa è nella vasca, le docce chiuse. Poi blackout (come
## dopo la leva) con il passaggio degli spogliatoi già fatto (tornello e saracinesca aperti): dalla
## cima del raccordo su per la scala, la porta col maniglione, il corridoio, le docce che scorrono
## nel vapore, la saracinesca e la sala dalla stessa porta. Nella sala: vasca vuota (la medusa non
## c'è più), l'acqua che si muove, le gocce dal bordo e la scia verso l'area bimbi, la sigla muta,
## il lampione spento; i checkpoint lungo la strada e la fine della demo in fondo alla scia.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tappa7.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const INTERNI := Vector3(-9.7, 0.0, 40.9)

var level: Node
var p: Player
var _passed := 0
var _failed := 0
var salti := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(5)
	level = get_tree().current_scene
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var ritorno: RitornoAlBuio = level.get(&"ritorno")
	var interni: Node = level.get_node_or_null("Interni")
	var tec: Node3D = level.get_node_or_null("Tecnici")
	check(ritorno != null and interni != null and tec != null, "ci sono la tappa 7, gli interni e gli ambienti tecnici")
	if ritorno == null or interni == null or tec == null:
		_fine()
		return
	var porta: PortaManiglione = ritorno.porta_interni
	var medusa: Node3D = ritorno.medusa
	var space := p.get_world_3d().direct_space_state

	print("Prima del risveglio")
	check(GameState.luci == GameState.Luci.PRIMA_DEL_RISVEGLIO, "si parte con le luci di prima")
	var q := PhysicsRayQueryParameters3D.create(INTERNI + Vector3(17.5, 1.0, -1.2), INTERNI + Vector3(17.5, 1.0, 1.2))
	q.exclude = [p.get_rid()]
	check(not space.intersect_ray(q).is_empty(), "la porta della sala pompe nel corridoio è chiusa (ha la collisione)")
	porta.interact(p)
	await _frames(30)
	check(not porta.is_open, "e prima del risveglio non si apre")
	check(medusa.visible and not bool(interni.get(&"docce_aperte")), "la medusa è nella vasca, le docce chiuse")

	print("Il blackout (dopo la leva della sala pompe)")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _frames(3)
	check(ritorno.attivo, "parte il ritorno al buio")
	check(not medusa.visible, "la medusa non c'è più")
	check(ritorno.macchie_scia() >= 15, "una scia di gocce a terra (%d macchie)" % ritorno.macchie_scia())
	check(ritorno.find_children("*", "WaterDripEmitter", true, false).size() >= 2, "dal bordo della vasca gocciola ancora")
	check(bool(interni.get(&"docce_aperte")), "le docce scorrono")
	check(ritorno.find_children("VaporeBuio*", "", true, false).size() >= 2, "e il vapore copre gli spogliatoi")
	var sigla: Node = ritorno.pulsante_sigla
	check(sigla.process_mode == Node.PROCESS_MODE_DISABLED, "senza corrente il pulsante della sigla non fa niente")
	var lamp: FlickerLight = level.get_node("Vasca/Sfarfallio")
	check(not lamp.is_on, "il lampione è spento")
	await _frames(120)
	check(ritorno.increspature >= 2, "l'acqua della vasca si muove ancora (%d increspature)" % ritorno.increspature)
	# Il passaggio degli spogliatoi fatto all'inizio (tappa 2): tornello e saracinesca aperti.
	interni.call(&"_sblocca_tornello")
	for s in interni.find_children("*", "Saracinesca", true, false):
		(s as PoweredDoor).load_state({"latched": true, "open": 1.0})

	print("Dalla cima del raccordo agli interni")
	p.teleport(tec.to_global(Vector3(44.6, 7.25, -7.8)) + Vector3(0, 0.05, 0), 0.0, 0.0)
	await _frames(5)
	check(await _cammina_verso(tec.to_global(Vector3(40.4, 9.05, -7.8)), 600), "su per la scala degli interni fino alla porta")
	await _frames(5)
	porta.interact(p)
	for i in 120:
		await get_tree().physics_frame
	check(porta.is_open, "dopo il risveglio la porta della sala pompe si apre col maniglione")
	var ok := true
	for loc in [Vector3(17.5, 0, -1.4), Vector3(6.8, 0, -1.4)]:
		ok = ok and await _cammina_verso(INTERNI + loc, 900)
	check(ok, "si entra nel corridoio e lo si percorre al buio")
	check(_checkpoint().ends_with("CheckpointCorridoioBuio"), "checkpoint: il corridoio al buio (%s)" % _checkpoint())
	ok = true
	for loc in [Vector3(6.8, 0, -3.8), Vector3(6.0, 0, -9.5), Vector3(5.6, 0, -12.2)]:
		ok = ok and await _cammina_verso(INTERNI + loc, 900)
	check(ok, "negli spogliatoi fino alle docce")
	check(_checkpoint().ends_with("CheckpointDocceBuio"), "checkpoint: le docce al buio (%s)" % _checkpoint())
	ok = true
	for loc in [Vector3(7.4, 0, -10.2), Vector3(9.7, 0, -10.2), Vector3(9.7, 0, -12.6), Vector3(9.7, 0, -15.0), Vector3(9.7, 0, -17.8),
			Vector3(9.7, 0, -20.0), Vector3(9.7, 0, -21.6)]:
		ok = ok and await _cammina_verso(INTERNI + loc, 900)
	check(ok, "lava-piedi, tornello e saracinesca fino alla porta della sala (salti: %d)" % salti)

	print("Nella sala, dalla stessa porta")
	ok = await _cammina_verso(Vector3(0.0, 0.0, 18.4), 600)
	await _frames(5)
	check(ok and _checkpoint().ends_with("CheckpointRitornoSala"), "checkpoint: di nuovo nella sala (%s)" % _checkpoint())
	# Intorno al cordone della vasca fino a dove la scia esce sotto il cordone, poi la scia.
	ok = true
	for punto in [Vector3(-2.7, 0, 17.1), Vector3(-3.9, 0, 15.9), Vector3(-4.5, 0, 14.3), Vector3(-5.7, 0, 13.1),
			Vector3(-6.9, 0, 11.9), Vector3(-7.7, 0, 10.5), Vector3(-7.9, 0, 8.9)]:
		ok = ok and await _cammina_verso(punto, 900)
	for i in range(3, ritorno.scia.size()):
		ok = ok and await _cammina_verso(ritorno.scia[i], 900)
	check(ok, "si segue la scia di gocce fino all'area bimbi")
	await _frames(10)
	check(bool(level.get(&"demo_finished")), "in fondo alla scia finisce la demo")

	print("Si riparte da prima del risveglio")
	GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO)
	await _frames(3)
	check(medusa.visible and not ritorno.attivo and ritorno.macchie_scia() == 0, "la medusa torna nella vasca e la scia sparisce")
	_fine()


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _checkpoint() -> String:
	return String(GameState.snapshot.get("checkpoint", ""))


## Cammina in avanti verso t finché non ci arriva (in pianta). Falso se si blocca. Come farebbe
## un giocatore, se resta fermo contro un gradino (per esempio uscendo dal lava-piedi) salta.
func _cammina_verso(t: Vector3, max_frames: int) -> bool:
	Input.action_press(&"move_forward")
	var arrivato := false
	var prima := p.global_position
	var fermo := 0
	for i in max_frames:
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			arrivato = true
			break
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
		fermo = fermo + 1 if p.global_position.distance_to(prima) < 0.004 else 0
		prima = p.global_position
		if fermo == 20 and p.is_on_floor():
			salti += 1
			Input.action_press(&"jump")
			await get_tree().physics_frame
			Input.action_release(&"jump")
	Input.action_release(&"move_forward")
	if not arrivato:
		printerr("  bloccato in ", p.global_position, " andando verso ", t)
	return arrivato


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
