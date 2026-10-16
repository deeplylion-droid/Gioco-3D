extends Node
## Test automatico della tappa 7 (docs/livello/capitolo1.md), il ritorno al buio dopo il risveglio
## della sala pompe, simulando gli input, sulla strada B scelta dall'utente il 16 ottobre. Prima del
## risveglio la medusa è nella vasca. Poi il blackout (come dopo la leva): dalla porta col maniglione
## della sala pompe si sale per il raccordo fino al pianerottolo davanti alla grata chiusa della scala
## degli interni (di lì non si passa), si va per il corridoio e su per la scala, nel magazzino dei
## gonfiabili e fuori dalla serranda nell'angolo sud-ovest della sala; la porta "sala pompe" degli
## interni resta chiusa e le docce non scorrono. Nella sala: vasca vuota (la medusa non c'è più),
## l'acqua che si muove, le gocce dal bordo, la scia di bava rosa dalla serranda lungo il muro ovest,
## la sigla muta, il lampione spento; i checkpoint sui marker della strada fino all'area bimbi, dove
## comincia la tappa 8 (test_tappa8.gd).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tappa7.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const INTERNI := Vector3(-9.7, 0.0, 40.9)
const CP := "Tecnici/Logica/Checkpoint/"

var level: Node
var p: Player
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
	var porta := level.get_node_or_null("Gioco/PortaSalaPompeInterni") as PortaManiglione
	var medusa: Node3D = ritorno.medusa
	var space := p.get_world_3d().direct_space_state
	for m in ["marker_t7_inizio", "marker_t7_magazzino", "marker_t7_serranda", "marker_t7_inizio_scia"]:
		check(tec.get_node_or_null("Marker/" + m) is Marker3D, "c'è il marker " + m)

	print("Prima del risveglio")
	check(GameState.luci == GameState.Luci.PRIMA_DEL_RISVEGLIO, "si parte con le luci di prima")
	check(medusa.visible and not bool(interni.get(&"docce_aperte")), "la medusa è nella vasca, le docce chiuse")

	print("Il blackout (dopo la leva della sala pompe)")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _frames(3)
	check(ritorno.attivo, "parte il ritorno al buio")
	check(not medusa.visible, "la medusa non c'è più")
	var inizio_scia := tec.to_global(_m(tec, "marker_t7_inizio_scia"))
	check(ritorno.metri_scia() >= 8.0, "una scia di bava rosa a terra (%.1f m)" % ritorno.metri_scia())
	check(ritorno.scia.size() > 0 and Vector2(ritorno.scia[0].x - inizio_scia.x, ritorno.scia[0].z - inizio_scia.z).length() < 0.2,
		"la scia comincia alla serranda (%s)" % (str(ritorno.scia[0]) if ritorno.scia.size() > 0 else "-"))
	var ovest := true
	for q in ritorno.scia:
		ovest = ovest and q.x < -14.0
	check(ovest, "e va lungo il muro ovest fino all'area bimbi")
	check(ritorno.find_children("*", "WaterDripEmitter", true, false).size() >= 2, "dal bordo della vasca gocciola ancora")
	check(not bool(interni.get(&"docce_aperte")) and ritorno.find_children("VaporeBuio*", "", true, false).is_empty(),
		"con la strada B le docce non scorrono e negli spogliatoi non c'è vapore")
	if porta:
		porta.interact(p)
		await _frames(30)
		check(not porta.is_open, "la porta \"sala pompe\" degli interni resta chiusa")
	var sigla: Node = ritorno.pulsante_sigla
	check(sigla.process_mode == Node.PROCESS_MODE_DISABLED, "senza corrente il pulsante della sigla non fa niente")
	var lamp: FlickerLight = level.get_node("Vasca/Sfarfallio")
	check(not lamp.is_on, "il lampione è spento")
	await _frames(120)
	check(ritorno.increspature >= 2, "l'acqua della vasca si muove ancora (%d increspature)" % ritorno.increspature)

	print("Dalla porta della sala pompe su per il raccordo")
	p.teleport(tec.to_global(_m(tec, "marker_t7_inizio")) + Vector3(0, 0.05, 0), 0.0, 0.0)
	await _frames(10)
	check(_checkpoint() == CP + "CheckpointT7Inizio", "checkpoint: appena fuori dalla porta col maniglione (%s)" % _checkpoint())
	var ok := true
	for loc in [Vector3(51.6, 0, 1.4), Vector3(51.6, 0, 0.6), Vector3(51.6, 3.625, -6.2), Vector3(50.0, 3.625, -7.8),
			Vector3(44.55, 7.25, -7.8)]:
		ok = ok and await _cammina_verso(tec.to_global(loc), 900)
	await _frames(5)
	check(ok and _checkpoint() == CP + "CheckpointRaccordo", "su per le due rampe fino al pianerottolo: checkpoint (%s)" % _checkpoint())
	var grata := PhysicsRayQueryParameters3D.create(tec.to_global(Vector3(44.2, 8.0, -7.8)), tec.to_global(Vector3(42.5, 8.0, -7.8)))
	grata.exclude = [p.get_rid()]
	check(not space.intersect_ray(grata).is_empty(), "la grata chiude la scala degli interni")

	print("Il corridoio, il magazzino dei gonfiabili e la serranda")
	ok = true
	for loc in [Vector3(44.55, 7.25, -4.0), Vector3(44.55, 9.05, 2.0), Vector3(44.55, 9.05, 15.0), Vector3(30.0, 9.05, 15.0)]:
		ok = ok and await _cammina_verso(tec.to_global(loc), 1200)
	check(ok and absf(p.global_position.y) < 0.1, "per il corridoio e su per la scala, al livello della sala (y %.2f)" % p.global_position.y)
	ok = await _cammina_verso(tec.to_global(Vector3(26.5, 9.05, 15.0)), 900)
	await _frames(5)
	check(ok and _checkpoint() == CP + "CheckpointMagazzino", "nel magazzino dei gonfiabili: checkpoint (%s)" % _checkpoint())
	ok = true
	for loc in [Vector3(24.0, 9.05, 15.0), Vector3(19.3, 9.05, 15.0), Vector3(17.9, 9.05, 15.0)]:
		ok = ok and await _cammina_verso(tec.to_global(loc), 900)
	await _frames(5)
	check(ok and _checkpoint() == CP + "CheckpointSerranda", "sotto la serranda, nella sala: checkpoint (%s)" % _checkpoint())
	var snap_serranda := GameState.snapshot.duplicate(true)

	print("Nella sala, lungo la scia")
	var cp_bimbi := (level.get_node("Gioco/CheckpointAreaBimbi") as Node3D).global_position
	ok = true
	for i in ritorno.scia.size():
		ok = ok and await _cammina_verso(ritorno.scia[i], 900)
		if Vector2(ritorno.scia[i].x - cp_bimbi.x, ritorno.scia[i].z - cp_bimbi.z).length() < 0.6:
			break
	await _frames(5)
	check(ok and _checkpoint().ends_with("CheckpointAreaBimbi"), "si segue la scia fino all'area bimbi (%s)" % _checkpoint())
	check(not bool(level.get(&"demo_finished")), "la demo non finisce sulla scia: va avanti con la tappa 8")

	print("Si riparte dalla serranda")
	GameState.snapshot = snap_serranda
	GameState._restore_pending = true
	GameState._on_level_ready()
	await _frames(5)
	var ripartenza := p.global_position
	check(Vector2(ripartenza.x + 15.0, ripartenza.z - 19.3).length() < 0.5 and GameState.luci == GameState.Luci.BLACKOUT,
		"si riparte appena fuori dalla serranda, al buio (%s)" % str(ripartenza))
	check(absf(wrapf(p.yaw, -PI, PI)) < 0.2, "guardando a nord, verso la scia (yaw %.2f)" % p.yaw)

	print("Si riparte da prima del risveglio")
	GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO)
	await _frames(3)
	check(medusa.visible and not ritorno.attivo and ritorno.metri_scia() == 0.0, "la medusa torna nella vasca e la scia sparisce")
	_fine()


func _m(tec: Node3D, nome: String) -> Vector3:
	return (tec.get_node("Marker/" + nome) as Node3D).position


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _checkpoint() -> String:
	return String(GameState.snapshot.get("checkpoint", ""))


## Cammina in avanti verso t finché non ci arriva (in pianta), senza mai saltare: i gradini
## bassi (per esempio uscendo dal lava-piedi) si salgono da soli. Falso se si blocca.
func _cammina_verso(t: Vector3, max_frames: int) -> bool:
	Input.action_press(&"move_forward")
	var arrivato := false
	for i in max_frames:
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			arrivato = true
			break
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
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
