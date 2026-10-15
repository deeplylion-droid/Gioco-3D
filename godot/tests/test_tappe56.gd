extends Node
## Test automatico delle tappe 5 e 6 (docs/livello/capitolo1.md), tutto il percorso dalla pozza
## della piscina a onde fino al raccordo verso gli interni, simulando gli input:
## - tappa 5: il gonfiabile cade col getto, la turbina dello scarico svuota la pozza (si ricarica
##   dalla pozza stessa), il pulsante apre il portello e si scende davvero dalla scala del pozzo;
## - camera delle onde e tunnel fino alla sala pompe;
## - tappa 6: acqua dalla vasca di raccolta, turbine nell'ordine sbagliato (si ricomincia) e in
##   quello dello schema (blu, giallo, rosso), la leva bloccata e poi tirata col getto, il
##   risveglio (flash, blackout con le sole luci rosse, neve sul monitor, paratie giù), la porta
##   col maniglione, il raccordo fino alla scala degli interni e la fine della demo;
## - i checkpoint lungo la strada e una ripartenza dopo il risveglio.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tappe56.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var level: Node
var tec: Node3D
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
	tec = level.get_node_or_null("Tecnici") as Node3D
	check(tec != null, "gli ambienti tecnici sono montati sotto la sala")
	if tec == null:
		_fine()
		return
	var porta_sala: Node3D = level.get_node("Sala/Interattivi/sala_portello_scarico")
	var centro_pozzo := tec.to_global(_m("marker_portello"))
	check(Vector2(centro_pozzo.x, centro_pozzo.z).distance_to(Vector2(0.0, 2.0)) < 0.05 and absf(centro_pozzo.y + 2.25) < 0.1,
		"il pozzo è sotto il centro del portello (%s)" % centro_pozzo)
	var doppione := tec.get_node_or_null("Ambienti/CameraOnde/PORTELLO") as Node3D
	check(doppione == null or not doppione.visible, "il coperchio doppione in cima al pozzo è nascosto")
	check(porta_sala != null, "c'è il portello della sala")

	# Lo zaino: quello dello stanzino (con gli interni) o della rastrelliera.
	var picks := level.find_children("*", "PackPickup", true, false)
	if picks.size() > 0:
		(picks[0] as PackPickup).interact(p)
	await _frames(3)
	check(p.water_pack.equipped, "lo zaino è in spalla")

	print("Tappa 5: la pozza, la turbina dello scarico e il portello")
	var puddle: WaterTank = level.get_node("Piscina/Pozza")
	var turbine: Turbine = level.get_node("Piscina/TurbinaScarico")
	var inflatable: StuckInflatable = level.get_node("Piscina/GonfiabileIncastrato")
	var hatch_button: WaterButton = level.get_node("Piscina/PulsantePortello")
	var hatch: Node = level.get_node("Piscina/Portello")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(3.4, -1.95, 1.2), PI, 0.0)
	await _frames(10)
	p.look_at_point(turbine.global_position + Vector3(0, 0.3, 0))
	await _frames(3)
	await _hold(&"spray", 60)
	check(not inflatable.is_stuck(), "il getto fa cadere il gonfiabile dalla turbina")
	await _frames(40)
	for round in 14:
		if puddle.fill <= 0.001:
			break
		p.look_at_point(turbine.global_position + Vector3(0.0, 0.3, 0.0))
		await _hold(&"spray", 150)
		if puddle.fill > 0.001:
			p.look_at_point(Vector3(1.2, -2.07, 2.4))
			await _hold(&"suck", 60)
	for i in 900:
		if puddle.fill <= 0.001:
			break
		await get_tree().physics_frame
	check(puddle.fill <= 0.001, "tenendo il getto sulla turbina la pozza si svuota (fill %.3f)" % puddle.fill)
	check(_checkpoint() == "Piscina/CheckpointPozzaVuota", "checkpoint: pozza vuota (%s)" % _checkpoint())
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(0.6, -1.95, 1.0), PI, 0.0)
	await _frames(10)
	p.look_at_point(hatch_button.global_position + Vector3(0, 0.4, 0))
	await _frames(3)
	await _hold(&"spray", 60)
	for i in 300:
		await get_tree().physics_frame
		if bool(hatch.get(&"is_open")):
			break
	check(bool(hatch.get(&"is_open")), "il pulsante apre il portello")
	check(not bool(level.get(&"demo_finished")), "la demo non finisce più al portello")

	print("Giù dalla scala del pozzo")
	# Sul fondo, a sud del buco, si cammina verso la scala (nord) e ci si aggrappa.
	p.teleport(Vector3(0.0, -2.2, 3.25), 0.0, 0.0)
	await _frames(10)
	check(p.is_on_floor() and p.global_position.y > -2.4, "si sta sul fondo della piscina accanto al buco (y %.2f)" % p.global_position.y)
	Input.action_press(&"move_forward")
	for i in 240:
		await get_tree().physics_frame
		if p.is_on_ladder():
			break
	Input.action_release(&"move_forward")
	check(p.is_on_ladder(), "si prende la scala del pozzo (%s)" % p.global_position)
	Input.action_press(&"move_back")
	for i in 600:
		await get_tree().physics_frame
		if not p.is_on_ladder() and p.is_on_floor() and p.global_position.y < -8.5:
			break
	Input.action_release(&"move_back")
	await _frames(10)
	var giu := p.global_position
	check(absf(giu.y - (-9.05)) < 0.15, "si scende fino in fondo al pozzo (y %.2f)" % giu.y)
	check(not p.is_on_ladder(), "e si lascia la scala sul pavimento della camera delle onde")
	await _frames(5)
	check(_checkpoint() == "Tecnici/Logica/Checkpoint/CheckpointPozzo", "checkpoint: in fondo al pozzo (%s)" % _checkpoint())
	# E si risale fino al fondo della piscina: avanti verso la scala, su, e in cima si scavalca il
	# bordo dalla parte della cerniera, sopra il portello aperto.
	p.teleport(p.global_position + Vector3(0.0, 0.0, 0.3), 0.0, 0.0)
	await _frames(30)
	Input.action_press(&"move_forward")
	var su := false
	for i in 900:
		await get_tree().physics_frame
		if p.is_on_ladder():
			su = true
		if su and not p.is_on_ladder() and p.is_on_floor() and p.global_position.y > -2.5:
			break
	await _frames(30)
	Input.action_release(&"move_forward")
	await _frames(10)
	check(su and p.is_on_floor() and p.global_position.y > -2.3 and p.global_position.z < 1.2,
		"risalendo si esce dal pozzo sul fondo della piscina, sopra il portello aperto (%s)" % p.global_position)
	# E di nuovo giù, per andare avanti (guardando in basso e camminando nel buco).
	p.teleport(Vector3(0.0, -2.2, 3.25), 0.0, 0.0)
	await _frames(5)
	p.set_look(0.0, deg_to_rad(-60.0))
	Input.action_press(&"move_forward")
	for i in 900:
		await get_tree().physics_frame
		if not p.is_on_ladder() and p.is_on_floor() and p.global_position.y < -8.5:
			break
	Input.action_release(&"move_forward")
	await _frames(5)
	check(p.global_position.y < -8.5, "guardando in basso e camminando nel buco si scende (y %.2f)" % p.global_position.y)

	print("La camera delle onde e il tunnel fino alla sala pompe")
	var ok := true
	for loc in [Vector3(4.0, 0, 0.3), Vector3(16.0, 0, 0.3), Vector3(23.0, 0, 0.0), Vector3(27.0, 0, 0.0), Vector3(31.0, 0, 0.0)]:
		ok = ok and await _cammina_verso(tec.to_global(loc), 900)
	check(ok, "si cammina dalla scala, sotto le paratie e nel tunnel fino alla sala pompe")
	await _frames(5)
	check(_checkpoint() == "Tecnici/Logica/Checkpoint/CheckpointSalaPompe", "checkpoint: ingresso della sala pompe (%s)" % _checkpoint())

	print("Tappa 6: acqua dalla vasca di raccolta")
	var raccolta: WaterTank = tec.get_node("Acqua/VascaRaccolta")
	p.water_pack.set_tank_amount(0.0)
	_metti(Vector3(36.5, 0.0, 3.1), Vector3(36.5, -0.15, 1.2))
	await _frames(8)
	_guarda(Vector3(36.5, -0.15, 1.2))
	var prima := raccolta.get_liters()
	await _hold(&"suck", 90)
	check(p.water_pack.tank_amount > 8.0, "lo zaino si riempie dalla vasca di raccolta (%.1f l)" % p.water_pack.tank_amount)
	check(raccolta.get_liters() < prima - 5.0, "e la vasca di raccolta scende")

	var ris: RisveglioSalaPompe = level.get(&"risveglio")
	var leva: LevaGrande = ris.leva
	print("La leva bloccata")
	p.water_pack.set_tank_amount(20.0)
	_metti(Vector3(43.6, 0.0, -4.4), _m("marker_leva") + Vector3(0, 0.25, 0))
	await _frames(8)
	_guarda(_m("marker_leva") + Vector3(0, 0.45, 0))
	var bloccate := [0]
	leva.colpita_bloccata.connect(func(): bloccate[0] += 1)
	await _hold(&"spray", 60)
	check(bloccate[0] > 0 and not leva.abbassata, "prima delle pompe il getto arriva alla leva oltre la grata, ma è bloccata")

	print("Le turbine nell'ordine sbagliato")
	var sbagliate := [0]
	ris.sequenza_sbagliata.connect(func(): sbagliate[0] += 1)
	await _gira_turbina(ris.turbine[0])     # blu: giusta
	check(ris.avviate == 1 and ris.pompe[0].stato == Pompa.Stato.AVVIATA, "la turbina blu avvia la sua pompa")
	await _gira_turbina(ris.turbine[2])     # rossa: tocca alla gialla
	check(sbagliate[0] == 1 and ris.avviate == 0 and ris.pompe[0].stato == Pompa.Stato.FERMA, "la rossa prima della gialla: le pompe si fermano, si ricomincia")
	await _ferme(ris.turbine)

	print("Le turbine nell'ordine dello schema: blu, giallo, rosso")
	for i in 3:
		await _gira_turbina(ris.turbine[i])
		check(ris.avviate == i + 1 and ris.pompe[i].stato == Pompa.Stato.AVVIATA, "pompa %d avviata (%s)" % [i + 1, ris.turbine[i].name])
	check(leva.sbloccata, "con le tre pompe la leva si sblocca")

	print("La leva e il risveglio")
	var fasi := []
	GameState.luci_cambiate.connect(func(f): fasi.append(f))
	p.water_pack.set_tank_amount(20.0)
	_metti(Vector3(43.6, 0.0, -4.4), _m("marker_leva") + Vector3(0, 0.25, 0))
	await _frames(8)
	_guarda(_m("marker_leva") + Vector3(0, 0.45, 0))
	await _hold(&"spray", 60)
	check(leva.abbassata, "il getto tira giù la leva")
	check(GameState.luci == GameState.Luci.FLASH, "tutte le luci si accendono (flash)")
	for pm in ris.pompe:
		check(pm.stato == Pompa.Stato.RUGGISCE, "la pompa %s ruggisce" % pm.name)
	await _frames(int(ris.durata_flash * 60) + 10)
	check(GameState.luci == GameState.Luci.BLACKOUT and fasi == [GameState.Luci.FLASH, GameState.Luci.BLACKOUT], "poi salta la corrente (blackout)")
	check(ris.monitor.mostra_neve_attiva(), "il monitor mostra solo neve")
	# (I neon si spengono con una scintilla di un terzo di secondo.)
	await _frames(30)
	var accese := 0
	var rosse := 0
	var altre := []
	for l in tec.find_children("*", "Light3D", true, false):
		if (l as Light3D).visible and (l as Light3D).is_visible_in_tree() and (l as Light3D).light_energy > 0.01:
			accese += 1
			if LuciRisveglio._di_emergenza(l) or (l as Light3D).has_meta(&"risveglio_ignora"):
				rosse += 1
			else:
				altre.append(String(tec.get_path_to(l)))
	check(accese > 0 and accese == rosse, "restano solo le luci rosse d'emergenza (e il monitor): %d su %d %s" % [rosse, accese, altre])
	var porta: PortaManiglione = ris.porta
	porta.interact(p)
	await _frames(3)
	check(not porta.is_open, "durante il risveglio la porta è ancora bloccata")
	for i in 60 * 20:
		if ris.finito:
			break
		await get_tree().physics_frame
	check(ris.finito, "il risveglio arriva alla fine")
	for pa in ris.paratie:
		check(pa.is_chiusa, "la paratia %s è scesa" % pa.name)
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(tec.to_global(Vector3(15.0, 1.0, 0.0)), tec.to_global(Vector3(23.0, 1.0, 0.0)))
	check(not space.intersect_ray(q).is_empty(), "le paratie chiudono la camera delle onde")
	await _frames(3)
	check(_checkpoint() == "Tecnici/Logica/Checkpoint/CheckpointRisveglio", "checkpoint: dopo il risveglio (%s)" % _checkpoint())
	check(int(GameState.snapshot.get("luci", -1)) == GameState.Luci.BLACKOUT, "il checkpoint ricorda il blackout")

	print("La porta del ponte inferiore e il raccordo")
	_metti(_m("marker_porta_ponte"), _m("marker_porta_ponte") + Vector3(1.0, 1.0, 0.0))
	await _frames(5)
	porta.interact(p)
	for i in 120:
		await get_tree().physics_frame
	check(porta.is_open, "col maniglione la porta si apre")
	ok = true
	for loc in [Vector3(47.4, 0, 1.4), Vector3(51.6, 0, 1.4), Vector3(51.6, 0, 0.6), Vector3(51.6, 3.625, -6.2),
			Vector3(50.0, 3.625, -7.8), Vector3(44.6, 7.25, -7.8)]:
		ok = ok and await _cammina_verso(tec.to_global(loc), 900)
	check(ok, "dalla porta su per le due rampe del raccordo")
	await _frames(10)
	check(_checkpoint() == "Tecnici/Logica/Checkpoint/CheckpointRaccordo", "checkpoint: in cima al raccordo (%s)" % _checkpoint())
	ok = await _cammina_verso(tec.to_global(Vector3(42.6, 8.2, -7.8)), 600)
	await _frames(10)
	check(bool(level.get(&"demo_finished")), "ai piedi della scala degli interni finisce la demo")

	print("Si riparte dal checkpoint del risveglio")
	GameState.snapshot["checkpoint"] = "Tecnici/Logica/Checkpoint/CheckpointRisveglio"
	GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO)
	GameState._restore_pending = true
	GameState._on_level_ready()
	await _frames(5)
	check(GameState.luci == GameState.Luci.BLACKOUT, "ripartendo, le luci sono di nuovo al blackout")

	_fine()


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## La turbina gira col getto finché non dà energia (il giocatore davanti, a 2 m).
func _gira_turbina(t: Turbine) -> void:
	p.water_pack.set_tank_amount(20.0)
	var centro := tec.to_local(t.global_position)
	_metti(Vector3(centro.x, 0.0, centro.z + 2.4), centro + Vector3(0, 0.2, 0))
	await _frames(8)
	_guarda(centro + Vector3(0, 0.35, 0))
	for i in 6:
		if t.powered:
			break
		await _hold(&"spray", 40)
	await _frames(2)


## Aspetta che le turbine si fermino (senza energia).
func _ferme(ts: Array) -> void:
	for i in 60 * 30:
		var tutte := true
		for t in ts:
			if (t as Turbine).powered:
				tutte = false
		if tutte:
			return
		await get_tree().physics_frame


## Mette il giocatore in [param dove] (coordinate degli ambienti tecnici) e lo gira verso [param verso].
func _metti(dove: Vector3, verso: Vector3) -> void:
	var g := tec.to_global(dove)
	p.teleport(g + Vector3(0, 0.05, 0), p.yaw, 0.0)
	_guarda(verso)


func _guarda(verso_locale: Vector3) -> void:
	p.look_at_point(tec.to_global(verso_locale))


func _m(nome: String) -> Vector3:
	return (tec.get_node("Marker/" + nome) as Node3D).position


func _checkpoint() -> String:
	return String(GameState.snapshot.get("checkpoint", ""))


## Cammina in avanti verso t finché non ci arriva (in pianta). Falso se si blocca.
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


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
