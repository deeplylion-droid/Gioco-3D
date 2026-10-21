extends Node
## Test del fiume lento del gioco (scenes/risalita/fiume.tscn, aspetto A, logica approvata il 18 ottobre),
## nella scena di prova tests/scene/fiume_gioco_prova.tscn, simulando gli input.
## 0. L'indizio: a ogni bivio è acceso solo il cartello del ramo giusto; seguendoli si arriva all'approdo.
##    A piedi: dall'ingresso si arriva all'imbarco, nel canale non si cade, dalla banchina si sale sulla
##    ciambella col tasto E.
## 1. Prima delle pompe la corrente non c'è.
## 2. Dopo: la ciambella va a circa 2,2 m/s; il getto accelera e frena; il serbatoio si ricarica.
## 3. Senza colpire niente al bivio 1 si va nel ramo sbagliato e si torna all'imbarco, sulla ciambella;
##    la paratia resta com'era.
## 4. Il giro giusto: il bersaglio 1 sì, il 2 no, il 3 dopo la colonna girandosi; all'approdo si scende
##    sulla banchina, davanti alla porta di servizio.
## 5. Il bersaglio 2 (già giusto) colpito sbaglia la paratia; dopo il bivio non risponde.
## 6. Checkpoint: si riparte all'imbarco, giù dalla ciambella, con le paratie come erano.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_fiume_gioco.gd

const SCENA := "res://tests/scene/fiume_gioco_prova.tscn"
const F := preload("res://scripts/risalita/fiume_gioco.gd")

var level: Node
var p: Player
var fiume: FiumeLento
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(SCENA)
	await _aspetta_livello()
	check(fiume != null, "c'è il fiume lento")
	if fiume == null:
		_fine()
		return
	var p1 := fiume.get_node(^"Paratia1") as ParatiaFiume
	var p2 := fiume.get_node(^"Paratia2") as ParatiaFiume
	var p3 := fiume.get_node(^"Paratia3") as ParatiaFiume
	_zaino()

	print("0. L'indizio e la strada a piedi")
	var coerenti := true
	for par in [p1, p2, p3]:
		coerenti = coerenti and _cartello_acceso((par as ParatiaFiume).sinistra) != _cartello_acceso((par as ParatiaFiume).destra)
	check(coerenti, "a ogni bivio è acceso il cartello di un ramo solo")
	var t: TrattoFiume = fiume.imbarco
	var passi := 0
	while t and not t.uscita and passi < 10:
		if t.paratia:
			t = t.paratia.sinistra if _cartello_acceso(t.paratia.sinistra) else t.paratia.destra
		else:
			t = t.prossimo
		passi += 1
	check(t != null and t.uscita, "seguendo i cartelli accesi si arriva all'approdo (%d tratti)" % passi)
	var tot := 0.0
	for n in ["Imbarco", "Giusto1", "Giusto2", "Uscita"]:
		tot += (fiume.get_node(NodePath(n)) as TrattoFiume).lunghezza()
	check(tot / fiume.velocita > 60.0 and tot / fiume.velocita < 100.0, "il giro giusto senza fermarsi dura %.0f s" % (tot / fiume.velocita))
	var ingresso := level.get_node(^"Fiume/Marker/Ingresso") as Node3D
	var imbarco := level.get_node(^"Fiume/Marker/Imbarco") as Node3D
	p.teleport(ingresso.global_position, 0.0, 0.0)
	await _secondi(0.3)
	var arrivato := await _cammina_verso(imbarco.global_position, 25.0)
	check(arrivato, "dall'ingresso si arriva a piedi all'imbarco (%s)" % str(p.global_position))
	# verso l'acqua: la barriera ferma
	await _cammina_verso(imbarco.global_position + (fiume.imbarco.punto(0.0) - imbarco.global_position) * 3.0, 3.0)
	check(p.global_position.y > -0.1 and p.is_on_floor(), "nel canale non si cade (%.2f)" % p.global_position.y)
	p.teleport(imbarco.global_position, 0.0, 0.0)
	await _secondi(0.2)
	p.look_at_point(fiume.get_node(^"Ciambella").global_position)
	await _secondi(0.2)
	var bersaglio_e: Interactable = p.find_children("*", "Interactor", true, false)[0].get(&"current") if not p.find_children("*", "Interactor", true, false).is_empty() else null
	check(bersaglio_e != null and bersaglio_e.name == &"Sali", "dalla banchina la ciambella si raggiunge col tasto E")
	Input.action_press(&"interact")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"interact")
	check(fiume.a_bordo(), "si sale sulla ciambella")

	print("1. Prima delle pompe la corrente non c'è")
	GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO)
	await _secondi(1.0)
	check(fiume.s < 0.01, "la ciambella non si muove (%.2f m)" % fiume.s)

	print("2. Le pompe: la corrente porta; il getto accelera e frena")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var x0 := fiume.s
	await _secondi(2.0)
	var vel := (fiume.s - x0) / 2.0
	check(absf(vel - 2.2) < 0.15, "va a %.2f m/s" % vel)
	check(absf(p.global_position.distance_to(fiume.get_node(^"Ciambella").global_position)) < 0.2, "il giocatore è sulla ciambella")
	var dir := fiume.tratto.direzione(fiume.s)
	_guarda_verso(-dir + Vector3(0, -0.2, 0))
	Input.action_press(&"spray")
	await _secondi(1.2)
	Input.action_release(&"spray")
	check(fiume.v > 3.0, "sparando all'indietro accelera (%.2f m/s)" % fiume.v)
	_guarda_verso(dir + Vector3(0, -0.2, 0))
	Input.action_press(&"spray")
	await _secondi(1.6)
	Input.action_release(&"spray")
	check(fiume.v < 1.4, "sparando in avanti frena (%.2f m/s)" % fiume.v)
	check(p.water_pack.tank_amount > p.water_pack.tank_capacity * 0.5, "il serbatoio si ricarica da solo (%.1f L)" % p.water_pack.tank_amount)

	print("3. Al bivio 1 senza colpire: ramo sbagliato e di nuovo all'imbarco")
	var t0 := _ora()
	var ev := {"tornato": false, "fuori": false}
	fiume.ricominciato.connect(func(): ev.tornato = true, CONNECT_ONE_SHOT)
	for i in 60 * 80:
		await get_tree().physics_frame
		if ev.tornato:
			break
	check(ev.tornato and fiume.tratto == fiume.imbarco and fiume.a_bordo(), "il ramo sbagliato riporta all'imbarco, sulla ciambella (in %.0f s)" % (_ora() - t0))
	check(p1.a_destra and p1.colpi == 0, "la paratia 1 è rimasta com'era")

	print("4. Il giro giusto")
	t0 = _ora()
	var preso1 := await _spara_al_bersaglio(p1, 40.0)
	check(preso1 and not p1.a_destra, "colpito il bersaglio 1: la paratia si gira")
	await _fino_al_tratto("Giusto1", 30.0)
	check(fiume.tratto.name == &"Giusto1", "si va nel ramo giusto")
	await _fino_al_tratto("Giusto2", 40.0)
	check(fiume.tratto.name == &"Giusto2" and p2.colpi == 0, "al bivio 2, senza colpire, si va avanti")
	var bers3: Vector3 = p3.posizione_bersaglio
	await _fino_a(func(): return fiume.tratto.name == &"Giusto2" and _angolo() > 212.0, 30.0)
	check(not _si_vede(bers3), "arrivando, la colonna nasconde il bersaglio 3")
	await _fino_a(func(): return _angolo() > 236.0, 10.0)
	check(_si_vede(bers3), "passata la colonna il bersaglio si vede")
	var preso3 := await _spara_al_bersaglio(p3)
	check(preso3 and not p3.a_destra, "girandosi lo si colpisce: la paratia 3 si gira")
	fiume.uscito.connect(func(): ev.fuori = true, CONNECT_ONE_SHOT)
	await _fino_a(func(): return ev.fuori, 30.0)
	var giro := _ora() - t0
	check(ev.fuori and not fiume.a_bordo(), "approdo: si scende dalla ciambella")
	check(giro > 50.0 and giro < 110.0, "il giro giusto dura %.0f s" % giro)
	await _secondi(0.5)
	var porta := level.get_node(^"Fiume/Marker/PortaPersonale") as Node3D
	check(p.is_on_floor() and absf(p.global_position.y) < 0.1, "si sta in piedi sulla banchina dell'approdo (%s)" % str(p.global_position))
	check(await _cammina_verso(porta.global_position + Vector3(0.8, 0, 0), 8.0), "e si arriva alla porta di servizio")

	print("5. Il bersaglio 2 (già giusto) colpito sbaglia la paratia; dopo il bivio non risponde")
	var cp := _salva("TestFiumeImbarco")
	fiume.arrivato = false
	fiume.load_state({"arrivato": false})
	p.teleport(imbarco.global_position, 0.0, 0.0)
	await _secondi(0.2)
	fiume.sali(p)
	await _fino_al_tratto("Giusto1", 40.0)
	var preso2 := await _spara_al_bersaglio(p2, 20.0)
	check(preso2 and p2.a_destra, "colpito il bersaglio 2: ora manda nel ramo sbagliato")
	await _fino_al_tratto("Sbagliato2", 30.0)
	check(fiume.tratto.name == &"Sbagliato2", "e infatti si va nel ramo sbagliato")
	var colpi := p2.colpi
	await _spara_al_bersaglio(p2, 1.0)
	check(p2.colpi == colpi, "dopo il bivio il bersaglio non risponde")

	print("6. Checkpoint")
	await _riparti(cp)
	p1 = fiume.get_node(^"Paratia1") as ParatiaFiume
	p2 = fiume.get_node(^"Paratia2") as ParatiaFiume
	p3 = fiume.get_node(^"Paratia3") as ParatiaFiume
	check(not fiume.a_bordo() and fiume.tratto == fiume.imbarco and fiume.s == 0.0, "si riparte all'imbarco, giù dalla ciambella")
	check(not p1.a_destra and not p2.a_destra and not p3.a_destra, "le paratie sono come erano al checkpoint")
	_fine()


## L'angolo della ciambella sull'anello (gradi da nord, in senso orario).
func _angolo() -> float:
	var q := fiume.to_local(fiume.tratto.punto(fiume.s))
	return fposmod(rad_to_deg(atan2(q.x, -q.z)), 360.0)


## Cammina (tasto avanti) verso il punto per al massimo [param secondi]; vero se ci arriva entro 0,6 m.
func _cammina_verso(dove: Vector3, secondi: float) -> bool:
	for i in int(secondi * 60.0):
		var d := dove - p.global_position
		d.y = 0.0
		if d.length() < 0.6:
			Input.action_release(&"move_forward")
			return true
		p.look_at_point(p.get_eye_position() + d.normalized())
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	return false


# --- Azioni ---------------------------------------------------------------------------------

## Mira al bersaglio della paratia (con la parabola del getto) e spara finché si gira, al massimo
## [param secondi]: comincia quando il bersaglio risponde, si vede ed è a meno di 18 m (la portata
## del getto è di circa 28 m). Vero se si è girata.
func _spara_al_bersaglio(par: ParatiaFiume, secondi := 6.0) -> bool:
	var colpi := par.colpi
	var bersaglio: Vector3 = par.posizione_bersaglio
	# Aspetta che risponda e che si veda.
	var n := int(secondi * 60.0)
	var sparando := false
	for i in n:
		var d := p.camera.global_position.distance_to(bersaglio)
		p.look_at_point(bersaglio + Vector3.UP * 0.0067 * d * d)
		if par.attiva and _si_vede(bersaglio) and d < 18.0 and not sparando:
			Input.action_press(&"spray")
			sparando = true
		await get_tree().physics_frame
		if par.colpi > colpi:
			break
	Input.action_release(&"spray")
	await _secondi(0.2)
	return par.colpi > colpi


func _cartello_acceso(t: TrattoFiume) -> bool:
	for c in level.find_children("*", "CartelloUscita", true, false):
		if (c as CartelloUscita).tratto == t:
			return (c as CartelloUscita).acceso
	return false


func _guarda_verso(d: Vector3) -> void:
	p.look_at_point(p.get_eye_position() + d)


func _si_vede(punto: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p.get_eye_position(), punto, Layers.WORLD, [p.get_rid()])
	return p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _fino_al_tratto(nome: String, secondi: float) -> void:
	await _fino_a(func(): return fiume.tratto.name == StringName(nome), secondi)


func _fino_a(cond: Callable, secondi: float) -> void:
	for i in int(secondi * 60.0):
		if cond.call():
			return
		await get_tree().physics_frame


func _zaino() -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(20.0)


func _salva(nome: String) -> Dictionary:
	GameState.capture_snapshot(nome, 900, (level.get_node(^"Fiume/Marker/Imbarco") as Node3D).global_transform)
	return GameState.snapshot.duplicate(true)


func _riparti(s: Dictionary) -> void:
	GameState.snapshot = s.duplicate(true)
	GameState.respawn()
	await _aspetta_livello()
	await _secondi(0.2)


func _ora() -> float:
	return float(Engine.get_physics_frames()) / 60.0


func _aspetta_livello() -> void:
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _secondi(0.1)
	level = get_tree().current_scene
	p = GameState.player
	fiume = level.get_node_or_null(^"Fiume/FiumeLento") as FiumeLento
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
