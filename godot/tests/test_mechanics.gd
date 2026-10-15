extends Node
## Test automatico delle meccaniche nella scena di prova, simulando gli input.
## Uso (senza schermo, deterministico):
##   godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_mechanics.gd
## Esce con codice 0 se tutto va bene, 1 se qualche controllo fallisce.

const LEVEL := "res://scenes/test/test_level.tscn"

var level: Node
var p: Player
var _passed := 0
var _failed := 0
var _steps := 0
var _lands := 0
var _last_step_surface: StringName
var _last_step_wet := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _load_level()
	await test_movement()
	await test_jump()
	await test_crouch_ceiling()
	await test_ladder()
	await test_pickup_and_polaroid()
	await test_turbine_door()
	await test_suction_and_flowing_water()
	await test_tank_transfer()
	await test_drain_button()
	await test_boost()
	await test_knockback()
	await test_checkpoint_death_respawn()
	await test_platform_carries_player()
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Aiuti ---------------------------------------------------------------------------------

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


func _release_all() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"crouch",
			&"jump", &"interact", &"spray", &"suck", &"skip"]:
		Input.action_release(a)


func _load_level() -> void:
	get_tree().change_scene_to_file(LEVEL)
	await _wait_for_player()


func _wait_for_player() -> void:
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _frames(3)
	level = get_tree().current_scene
	p = GameState.player
	p.footstep.connect(func(s: StringName, w: bool, _i: float) -> void:
		_steps += 1
		_last_step_surface = s
		_last_step_wet = w)
	p.landed.connect(func(_s: StringName, _w: bool, _f: float) -> void: _lands += 1)
	# Il manichino si muove solo nel suo test.
	(level.get_node("SalaVasche/Manichino") as Node).process_mode = Node.PROCESS_MODE_DISABLED


func _n(path: String) -> Node:
	return level.get_node(path)


# --- Test ----------------------------------------------------------------------------------

func test_movement() -> void:
	print("Movimento e passi")
	p.teleport(Vector3(1.0, 0, 4.5), 0.0)
	await _frames(5)
	var z0 := p.global_position.z
	_steps = 0
	await _hold(&"move_forward", 60)
	var walked := z0 - p.global_position.z
	check(walked > 2.2 and walked < 3.6, "cammina ~3,4 m/s (fatti %.2f m in 1 s)" % walked)
	check(_steps >= 2, "segnali dei passi (%d)" % _steps)
	check(_last_step_surface == &"generico" and not _last_step_wet, "passi su pavimento asciutto")
	p.teleport(Vector3(0, 0, 4.5), 0.0)
	Input.action_press(&"sprint")
	await _hold(&"move_forward", 50)
	Input.action_release(&"sprint")
	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	check(speed > p.walk_speed * 1.4, "corsa più veloce (%.2f m/s)" % speed)
	await _frames(30)
	# Passi bagnati nella pozzanghera.
	p.teleport(Vector3(-0.3, 0, 2.8), deg_to_rad(90.0))
	_steps = 0
	await _hold(&"move_forward", 40)
	check(_steps > 0 and _last_step_wet, "passi bagnati nella zona bagnata")
	# Superficie di metallo (meta "superficie" sul ballatoio).
	p.teleport(Vector3(5.75, 2.55, 0.5), PI)
	await _frames(10)
	var s := p.get_surface_under_feet()
	check(s[0] == &"metallo", "superficie dal meta \"superficie\" (%s)" % s[0])


func test_jump() -> void:
	print("Salto")
	p.teleport(Vector3(0.5, 0, 1.0), 0.0)
	await _frames(10)
	_lands = 0
	var max_y := 0.0
	Input.action_press(&"jump")
	for i in 70:
		await get_tree().physics_frame
		max_y = maxf(max_y, p.global_position.y)
		if i == 2:
			Input.action_release(&"jump")
	check(max_y > 0.85 and max_y < 1.15, "salto alto ~1 m (%.2f)" % max_y)
	check(_lands >= 1 and p.is_on_floor(), "atterraggio segnalato")


func test_crouch_ceiling() -> void:
	print("Accovacciato e soffitto")
	Input.action_press(&"crouch")
	p.teleport(Vector3(-5.6, 0, 2.0), deg_to_rad(90.0))
	await _frames(10)
	check(p.is_crouching, "si accovaccia")
	await _hold(&"move_forward", 80)
	check(p.global_position.x < -7.2, "passa nel passaggio basso (x=%.2f)" % p.global_position.x)
	p.teleport(Vector3(-8.3, 0, 2.0), deg_to_rad(90.0))
	Input.action_release(&"crouch")
	await _frames(15)
	check(p.is_crouching and not p.can_stand_up(), "sotto il soffitto basso resta accovacciato")
	p.teleport(Vector3(-5.5, 0, 2.0), deg_to_rad(90.0))
	await _frames(15)
	check(not p.is_crouching, "fuori dal passaggio si rialza")


func test_ladder() -> void:
	print("Scala a pioli")
	p.teleport(Vector3(3.85, 0, -4.0), -PI * 0.5)
	await _frames(5)
	var climbed := false
	Input.action_press(&"move_forward")
	for i in 300:
		await get_tree().physics_frame
		if p.is_on_ladder():
			climbed = true
		if p.global_position.y > 2.4 and p.is_on_floor() and not p.is_on_ladder():
			break
	Input.action_release(&"move_forward")
	await _frames(10)
	check(climbed, "si aggrappa alla scala")
	check(p.global_position.y > 2.4 and p.global_position.x > 4.6, "arriva sul ballatoio (%s)" % str(p.global_position))


func test_pickup_and_polaroid() -> void:
	print("Interazione, raccolta e Polaroid")
	p.teleport(Vector3(2.5, 0, 4.7), 0.0)
	p.look_at_point(Vector3(2.5, 0.88, 3.5))
	await _frames(3)
	check(p.interactor.current is Pickup, "il raggio trova la chiave")
	await _hold(&"interact", 2)
	await _frames(2)
	check(p.has_item(&"chiave"), "la chiave è nell'inventario")
	check(not is_instance_valid(_n_or_null("StanzaPartenza/Chiave")), "la chiave sparisce dalla scena")
	p.teleport(Vector3(6.0, 2.5, 0.6), PI)
	p.look_at_point(Vector3(6.3, 2.52, -0.6))
	await _frames(3)
	check(p.interactor.current is Collectible, "il raggio trova la Polaroid")
	await _hold(&"interact", 2)
	await _frames(2)
	check(GameState.get_collected_count(&"polaroid") == 1 and GameState.get_total(&"polaroid") == 3,
		"contatore Polaroid 1/3 (%d/%d)" % [GameState.get_collected_count(&"polaroid"), GameState.get_total(&"polaroid")])


func _n_or_null(path: String) -> Node:
	return level.get_node_or_null(path)


func test_turbine_door() -> void:
	print("Turbina e porta")
	var turbine: Turbine = _n("StanzaPartenza/Turbina")
	var door: PoweredDoor = _n("StanzaPartenza/PortaTurbina")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(-2.2, 0, -1.5), 0.0)
	p.look_at_point(Vector3(-3.5, 2.2, -5.75))
	await _frames(3)
	check(not door.is_open and door.open_amount == 0.0, "la porta parte chiusa")
	await _hold(&"spray", 90)
	check(turbine.powered and turbine.energy > 0.55, "la turbina gira e dà energia (%.2f)" % turbine.energy)
	check(p.water_pack.tank_amount < 12.0, "il getto consuma il serbatoio (%.1f l)" % p.water_pack.tank_amount)
	for i in 240:
		await get_tree().physics_frame
		if door.is_open:
			break
	check(door.is_open, "la porta si apre")
	for i in 900:
		await get_tree().physics_frame
		if not door.is_open and door.open_amount == 0.0:
			break
	check(not turbine.powered and door.open_amount == 0.0, "la turbina rallenta e la porta si richiude")
	# Senza acqua non si spruzza.
	p.water_pack.set_tank_amount(0.0)
	var empty_signals := [0]
	p.water_pack.tank_empty.connect(func() -> void: empty_signals[0] += 1)
	await _hold(&"spray", 20)
	check(not p.water_pack.is_spraying and empty_signals[0] > 0, "serbatoio vuoto: niente getto")


func test_suction_and_flowing_water() -> void:
	print("Aspirazione e acqua che scorre")
	var basin: WaterTank = _n("StanzaPartenza/VascaPiccola")
	var pack := p.water_pack
	pack.set_tank_amount(2.0)
	var before := basin.get_liters()
	p.teleport(Vector3(3.5, 0, 1.0), 0.0)
	p.look_at_point(Vector3(3.5, 0.45, -0.5))
	await _frames(2)
	await _hold(&"suck", 60)
	var taken := before - basin.get_liters()
	var gained := pack.tank_amount - 2.0
	check(gained > 8.0, "aspira dalla vasca piccola (+%.1f l)" % gained)
	check(absf(taken - gained) < 0.05, "il livello della vasca scende degli stessi litri (%.2f / %.2f)" % [taken, gained])
	pack.set_tank_amount(0.0)
	p.teleport(Vector3(-4.5, 0, -2.0), 0.0)
	await _frames(60)
	check(pack.tank_amount > 6.0, "nell'acqua che scorre il serbatoio si ricarica (%.1f l)" % pack.tank_amount)
	var s := p.get_surface_under_feet()
	check(s[0] == &"acqua", "passi nell'acqua (%s)" % s[0])


func test_tank_transfer() -> void:
	print("Svuota una vasca e riempine un'altra")
	var source: WaterTank = _n("SalaVasche/VascaSorgente")
	var big: WaterTank = _n("SalaVasche/VascaGrande")
	var door: PoweredDoor = _n("StanzaPartenza/PortaTurbina")
	door.stay_open = true
	big.fill = 0.0
	var pack := p.water_pack
	p.teleport(Vector3(-3.9, 0, -18.2), 0.0)
	p.look_at_point(Vector3(-6.0, 0.9, -20.0))
	await _frames(3)
	pack.set_tank_amount(0.0)
	var src0 := source.get_liters()
	await _hold(&"suck", 150)
	check(pack.tank_amount > 19.9, "serbatoio pieno dalla vasca sorgente (%.1f l)" % pack.tank_amount)
	check(absf((src0 - source.get_liters()) - pack.tank_amount) < 0.05, "la vasca sorgente ha perso %.1f l" % (src0 - source.get_liters()))
	p.teleport(Vector3(0, 1.4, -15.6), 0.0)
	p.look_at_point(Vector3(0.8, -0.8, -20.5))
	await _frames(2)
	var big0 := big.get_liters()
	await _hold(&"spray", 260)
	await _frames(30)
	var added := big.get_liters() - big0
	check(pack.tank_amount < 0.01, "serbatoio svuotato spruzzando")
	check(added > 19.0 and added < 20.05, "la vasca grande ha ricevuto ~20 l (%.2f)" % added)


func test_platform_carries_player() -> void:
	print("Piattaforma galleggiante")
	var big: WaterTank = _n("SalaVasche/VascaGrande")
	var platform: FloatingPlatform = _n("SalaVasche/PiattaformaGalleggiante")
	big.fill = 0.0
	platform.snap_to_water()
	await _frames(5)
	var low := platform.global_position.y
	p.teleport(Vector3(0, low + 0.35, -20), 0.0)
	await _frames(20)
	var y0 := p.global_position.y
	check(p.is_on_floor(), "il giocatore sta sulla piattaforma sul fondo (y=%.2f)" % y0)
	p.water_pack.set_tank_amount(20.0)
	p.set_look(0.0, deg_to_rad(-75.0))
	await _hold(&"spray", 240)
	await _frames(150)
	var rise := p.global_position.y - y0
	check(big.fill > 0.4, "spruzzando dalla piattaforma la vasca si riempie (%.2f)" % big.fill)
	check(rise > 1.0 and p.is_on_floor(), "la piattaforma sale e porta su il giocatore (+%.2f m)" % rise)
	big.fill = 0.95
	await _frames(240)
	var top := platform.global_position.y + 0.3
	check(top > 1.6, "a vasca piena la piattaforma arriva in alto (%.2f m)" % top)
	# Dalla piattaforma alta si salta sulla sporgenza (2,5 m).
	p.teleport(Vector3(0, top + 0.05, -19.4), 0.0)
	await _frames(10)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _frames(14)
	await _hold(&"jump", 3)
	for i in 90:
		await get_tree().physics_frame
		if p.is_on_floor() and p.global_position.y > 2.4:
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	await _frames(20)
	check(p.global_position.y > 2.4 and p.global_position.z < -23.0, "salto dalla piattaforma alla sporgenza (%s)" % str(p.global_position))


func test_drain_button() -> void:
	print("Pulsante e scarico")
	var big: WaterTank = _n("SalaVasche/VascaGrande")
	var button: WaterButton = _n("SalaVasche/PulsanteScarico")
	big.fill = 0.8
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(-5.0, 0, -15.5), deg_to_rad(90.0))
	# Il getto cade per la gravità: si punta un po' sopra il pulsante.
	p.look_at_point(Vector3(-8.85, 2.35, -15.5))
	await _frames(2)
	await _hold(&"spray", 45)
	check(button.powered, "il pulsante colpito si accende (scarico aperto)")
	await _frames(60)
	check(big.fill < 0.75, "la vasca si svuota (%.2f)" % big.fill)
	await _hold(&"spray", 45)
	check(not button.powered, "colpito di nuovo si spegne")
	var f := big.fill
	await _frames(60)
	check(absf(big.fill - f) < 0.001, "scarico chiuso: il livello resta fermo")


func test_boost() -> void:
	print("Spinta verso l'alto")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(-3.0, 0, 0.0), 0.0, deg_to_rad(-89.0))
	await _frames(5)
	var plain := await _jump_max_y(false)
	p.teleport(Vector3(-3.0, 0, 0.0), 0.0, deg_to_rad(-89.0))
	await _frames(5)
	var boosted := await _jump_max_y(true)
	check(boosted > plain + 0.5, "salto con spinta più alto (%.2f contro %.2f)" % [boosted, plain])
	check(boosted < plain + 1.5, "spinta limitata (al massimo +1,5 m)")
	# Sulla mensola alta (1,55 m) si arriva solo con la spinta.
	p.teleport(Vector3(-6.0, 0, 3.0), PI, deg_to_rad(-80.0))
	await _frames(5)
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	Input.action_press(&"spray")
	await _frames(40)
	Input.action_release(&"spray")
	await _frames(40)
	Input.action_release(&"move_forward")
	check(p.global_position.y > 1.5 and p.global_position.z > 4.0, "arriva sulla mensola con la spinta (%s)" % str(p.global_position))


func _jump_max_y(spray: bool) -> float:
	var y0 := p.global_position.y
	var max_y := y0
	Input.action_press(&"jump")
	if spray:
		Input.action_press(&"spray")
	for i in 90:
		await get_tree().physics_frame
		max_y = maxf(max_y, p.global_position.y)
		if i == 2:
			Input.action_release(&"jump")
	Input.action_release(&"spray")
	await _frames(20)
	return max_y - y0


func test_knockback() -> void:
	print("Spinta indietro del nemico")
	var dummy: DummyEnemy = _n("SalaVasche/Manichino")
	dummy.process_mode = Node.PROCESS_MODE_INHERIT
	dummy.kill_distance = 0.0
	dummy.global_position = Vector3(6.0, 0, -21.5)
	dummy.reset_physics_interpolation()
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(6.0, 0, -18.0), 0.0)
	await _frames(5)
	var d0 := dummy.global_position.distance_to(p.global_position)
	p.look_at_point(dummy.global_position + Vector3(0, 1.2, 0))
	var hits := [0]
	(dummy.get_node("Bersaglio") as WaterHitbox).water_hit.connect(func(_a: float, _pt: Vector3, _d: Vector3) -> void: hits[0] += 1)
	await _hold(&"spray", 60)
	var d1 := dummy.global_position.distance_to(p.global_position)
	check(hits[0] > 10, "segnale \"colpito dal getto\" sul nemico (%d)" % hits[0])
	check(d1 > d0 + 1.0, "il nemico viene spinto indietro (%.2f -> %.2f m)" % [d0, d1])
	dummy.process_mode = Node.PROCESS_MODE_DISABLED


func test_checkpoint_death_respawn() -> void:
	print("Checkpoint, morte e ripartenza")
	var big: WaterTank = _n("SalaVasche/VascaGrande")
	big.fill = 0.3
	p.water_pack.set_tank_amount(11.0)
	p.teleport(Vector3(0, 0, -8.0), 0.0)
	await _frames(5)
	check(String(GameState.snapshot.get("checkpoint", "")).ends_with("CheckpointCorridoio"), "checkpoint del corridoio salvato")
	# Dopo il checkpoint: raccolgo il fusibile, svuoto la vasca, poi muoio.
	p.add_item(&"fusibile", 1, "Fusibile")
	GameState.mark_removed(_n("StanzaPartenza/Fusibile"))
	_n("StanzaPartenza/Fusibile").queue_free()
	big.fill = 0.0
	# Il checkpoint con order più basso non sposta indietro la ripartenza.
	p.teleport(Vector3(0, 0, 4.5), 0.0)
	await _frames(5)
	check(String(GameState.snapshot.get("checkpoint", "")).ends_with("CheckpointCorridoio"), "un checkpoint precedente non sposta indietro la ripartenza")
	var died := [0]
	GameState.player_died.connect(func(_c: StringName) -> void: died[0] += 1, CONNECT_ONE_SHOT)
	p.teleport(Vector3(6.5, 0.5, -14.0), 0.0)
	for i in 120:
		await get_tree().physics_frame
		if died[0] > 0:
			break
	check(died[0] == 1 and GameState.is_dying, "cadendo nel pozzo si muore")
	await _frames(30)
	await _hold(&"skip", 70)
	await _wait_for_player()
	check(p.global_position.distance_to(Vector3(0, 0, -8.0)) < 0.3, "riparte dal checkpoint del corridoio (%s)" % str(p.global_position))
	check(not p.has_item(&"fusibile") and p.has_item(&"chiave"), "inventario come al checkpoint")
	check(is_instance_valid(_n_or_null("StanzaPartenza/Fusibile")), "il fusibile preso dopo il checkpoint è tornato")
	check(not is_instance_valid(_n_or_null("StanzaPartenza/Chiave")), "la chiave presa prima del checkpoint non ricompare")
	check(absf((_n("SalaVasche/VascaGrande") as WaterTank).fill - 0.3) < 0.01, "livello della vasca come al checkpoint")
	check(absf(p.water_pack.tank_amount - 11.0) < 0.01, "acqua nello zaino come al checkpoint")
	check(not is_instance_valid(_n_or_null("StanzaPartenza/Polaroid01")) and GameState.get_collected_count(&"polaroid") == 1, "la Polaroid raccolta resta raccolta")
	check(p.input_enabled and not GameState.is_dying, "si può giocare di nuovo")
	_release_all()
