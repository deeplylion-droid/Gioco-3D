extends Node
## Test del prototipo grigio dell'infermeria (proposte/infermeria/infermeria_prototipo.tscn): la catena
## dei 4 passi, simulando il getto e il tasto E.
## 1. All'inizio il negatoscopio sfarfalla, la cassaforte è chiusa e la keycard non si prende.
## 2. Col getto sull'interruttore il negatoscopio si accende.
## 3. Solo un cassetto ha l'adesivo rosa; aperto, dentro c'è la radiografia, che si prende.
## 4. La radiografia sul negatoscopio: si vedono i puntini, 4, 1 e 7.
## 5. La cassaforte: un codice sbagliato non la apre, 4-1-7 sì; dentro la keycard e la Polaroid.
## 6. Checkpoint: tutto resta com'era (negatoscopio acceso con la radiografia, cassaforte aperta,
##    keycard nell'inventario e non più nella cassaforte).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_infermeria.gd

const SCENA := "res://proposte/infermeria/infermeria_prototipo.tscn"

var level: Node
var p: Player
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(SCENA)
	await _aspetta_livello()
	var neg := level.get_node(^"Negatoscopio") as Negatoscopio
	var cassa := level.get_node(^"Cassaforte") as CassaforteRotelle
	var inter := level.get_node(^"Interruttore") as WaterButton
	var keycard := level.get_node(^"Keycard") as Pickup
	check(neg != null and cassa != null and inter != null, "ci sono negatoscopio, cassaforte e interruttore")

	print("1. All'inizio")
	check(not neg.e_acceso(), "il negatoscopio sfarfalla (senza corrente)")
	check(not cassa.aperta_ora and not keycard.can_interact(p), "la cassaforte è chiusa e la keycard non si prende")

	print("2. Il getto sull'interruttore")
	_zaino()
	p.teleport(Vector3(0.9, 0.0, -0.5), 0.0, 0.0)
	await _secondi(0.2)
	var bersaglio := inter.global_position
	var d := p.camera.global_position.distance_to(bersaglio)
	p.look_at_point(bersaglio + Vector3.UP * 0.0067 * d * d)
	Input.action_press(&"spray")
	for i in 240:
		await get_tree().physics_frame
		if inter.powered:
			break
	Input.action_release(&"spray")
	await _secondi(0.3)
	check(inter.powered and neg.e_acceso(), "colpito l'interruttore, il negatoscopio si accende")
	check(neg.gruppi_visibili().is_empty(), "senza radiografia non si vedono puntini")

	print("3. Lo schedario")
	var con_adesivo: Array = []
	for c in level.find_children("Cassetto*", "CassettoSchedario", false, false):
		if (c as CassettoSchedario).adesivo:
			con_adesivo.append(c)
	check(con_adesivo.size() == 1, "un solo cassetto ha l'adesivo rosa (su %d)" % level.find_children("Cassetto*", "CassettoSchedario", false, false).size())
	var giusto := con_adesivo[0] as CassettoSchedario
	var radio := level.get_node(^"Radiografia") as Pickup
	check(not radio.can_interact(p), "a cassetto chiuso la radiografia non si prende")
	var altro := level.get_node(^"Cassetto0") as CassettoSchedario
	altro.interact(p)
	check(altro.aperto and not p.has_item(&"radiografia"), "un altro cassetto si apre, vuoto")
	neg.interact(p)
	check(not neg.con_radiografia, "senza radiografia sul negatoscopio non si appoggia niente")
	giusto.interact(p)
	check(giusto.aperto and radio.can_interact(p), "il cassetto con l'adesivo si apre: dentro la radiografia")
	radio.interact(p)
	check(p.has_item(&"radiografia"), "presa la radiografia")

	print("4. La radiografia sul negatoscopio")
	check(neg.get_prompt(p) == "Appoggia la radiografia", "il negatoscopio chiede di appoggiarla")
	neg.interact(p)
	check(neg.con_radiografia and not p.has_item(&"radiografia"), "appoggiata")
	var gruppi := neg.gruppi_visibili()
	check(gruppi == PackedInt32Array([4, 1, 7]), "si vedono i puntini: testa, corpo, coda = %s" % str(gruppi))

	print("5. La cassaforte")
	_imposta(cassa, [4, 1, 6])
	check(not cassa.aperta_ora, "4-1-6 non la apre")
	_imposta(cassa, [4, 1, 7])
	check(cassa.aperta_ora, "4-1-7 la apre")
	var polaroid := level.get_node(^"PolaroidPecora") as Pickup
	check(keycard.can_interact(p) and polaroid.can_interact(p), "dentro ci sono la keycard e la Polaroid")
	check(not cassa.rotella(0).can_interact(p), "aperta, le rotelle non girano più")
	keycard.interact(p)
	polaroid.interact(p)
	check(p.has_item(&"keycard") and p.has_item(&"polaroid_pecora"), "prese la keycard e la Polaroid")

	print("6. Checkpoint")
	GameState.capture_snapshot("TestInfermeria", 900, Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.5)))
	var cp := GameState.snapshot.duplicate(true)
	GameState.snapshot = cp
	GameState.respawn()
	await _aspetta_livello()
	await _secondi(0.2)
	neg = level.get_node(^"Negatoscopio") as Negatoscopio
	cassa = level.get_node(^"Cassaforte") as CassaforteRotelle
	check(neg.e_acceso() and neg.con_radiografia and neg.gruppi_visibili() == PackedInt32Array([4, 1, 7]), "il negatoscopio è acceso con la radiografia")
	check(cassa.aperta_ora and cassa.cifre == PackedInt32Array([4, 1, 7]), "la cassaforte è aperta")
	var kc := level.get_node_or_null(^"Keycard")
	check(p.has_item(&"keycard") and (kc == null or kc.is_queued_for_deletion()), "la keycard è nell'inventario e non più nella cassaforte")
	_fine()


## Gira le rotelle (col tasto E) fino alle cifre [param voluto].
func _imposta(cassa: CassaforteRotelle, voluto: Array) -> void:
	for i in voluto.size():
		var giri := 0
		while cassa.cifre[i] != int(voluto[i]) and giri < 10 and not cassa.aperta_ora:
			cassa.rotella(i).interact(p)
			giri += 1


func _zaino() -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(20.0)


func _aspetta_livello() -> void:
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _secondi(0.1)
	level = get_tree().current_scene
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
