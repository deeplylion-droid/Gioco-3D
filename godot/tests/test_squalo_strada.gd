extends Node
## Lo squalo nel fiume lento del gioco (SqualoFiume di mascotte attaccato a FiumeLento, build 0.5.0, scelta A del
## GDD), nella scena di prova del fiume col giocatore vero sulla ciambella:
## 1. nel tratto d'imbarco non c'è; dopo il primo bivio arriva e segue, anche nel ramo sbagliato; in fondo al ramo
##    sbagliato non attacca; tornati all'imbarco se ne va;
## 2. chi non lo respinge: il morso, nero, e si riparte sulla ciambella all'imbarco con le paratie come le si era
##    lasciate, senza ricaricare la zona; conta come una morte; nei 3 s dopo non attacca;
## 3. chi lo respinge col getto sul muso e mira i dischi finisce il giro all'approdo;
## 4. con l'interruttore «letale» spento urta e fa girare la ciambella, e il giro continua;
## 5. ripartendo da un checkpoint è calmo: non c'è finché non si passa il primo bivio.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_squalo_strada.gd

const SCENA := "res://tests/scene/fiume_gioco_prova.tscn"
const S := SqualoFiume.Stato

var level: Node
var p: Player
var fiume: FiumeLento
var squalo: SqualoFiume
var _passed := 0
var _failed := 0
var _morsi_visti := 0
var _respinte := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(SCENA)
	await _aspetta_livello()
	check(fiume != null and squalo != null, "nel fiume c'è lo squalo (SqualoFiume, figlio di FiumeLento, con la guida)")
	if squalo == null:
		return _fine()
	squalo.respinto.connect(func(): _respinte += 1)
	fiume.morso_dallo_squalo.connect(func(): _morsi_visti += 1)
	var p1 := fiume.get_node(^"Paratia1") as ParatiaFiume
	var p3 := fiume.get_node(^"Paratia3") as ParatiaFiume
	_zaino()
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _sali()

	print("1. L'imbarco è calmo; dopo il primo bivio arriva, anche nel ramo sbagliato")
	var calmo := true
	while fiume.tratto == fiume.imbarco:
		await get_tree().physics_frame
		if fiume.tratto == fiume.imbarco and (squalo.stato != S.ASSENTE or fiume.puo_attaccare()):
			calmo = false
	check(calmo, "nel tratto d'imbarco lo squalo non c'è e non può attaccare")
	check(fiume.tratto.ramo_sbagliato, "(senza colpire il disco: il ramo sbagliato, %s)" % fiume.tratto.name)
	await _secondi(1.0)
	check(squalo.stato == S.SEGUE and squalo.squalo.visible, "passato il bivio arriva e segue (%s)" % S.find_key(squalo.stato))
	var dietro := _dist_lungo_il_fiume()
	check(dietro > 8.0 and dietro < 16.0, "a circa 12 m dietro la ciambella, lungo il fiume (%.1f m in linea d'aria)" % dietro)
	var in_fondo_calmo := true
	var ev := {"tornato": false}
	fiume.ricominciato.connect(func(): ev.tornato = true, CONNECT_ONE_SHOT)
	for i in 60 * 40:
		await get_tree().physics_frame
		if ev.tornato:
			break
		if fiume.tratto.ramo_sbagliato and fiume.s > fiume.tratto.lunghezza() - fiume.calmo_in_fondo_ai_rami and fiume.puo_attaccare():
			in_fondo_calmo = false
	check(ev.tornato and in_fondo_calmo, "in fondo al ramo sbagliato (scivolo e vasca) non può attaccare")
	await _secondi(0.2)
	check(squalo.stato == S.ASSENTE, "tornati all'imbarco lo squalo se ne va")

	print("2. Chi non lo respinge mai: due morsi, poi solo urti, e al terzo tentativo finisce il giro")
	var morti0 := int(GameState.get(&"morti_totali")) if GameState.get(&"morti_totali") != null else -1
	var livello0 := get_tree().current_scene
	var esito := await _tentativo(func(_n): return false)
	check(esito == "morso" and fiume.morsi == 1 and fiume.morsi_giro == 1, "senza respingerlo morde (%s)" % esito)
	check(get_tree().current_scene == livello0 and is_instance_valid(fiume) and not GameState.is_dying,
		"la zona non si ricarica (niente kill_player né respawn)")
	check(fiume.a_bordo() and fiume.tratto == fiume.imbarco and fiume.s < 6.0, "si riparte sulla ciambella all'imbarco (%.1f m dopo l'ormeggio, finito il nero)" % fiume.s)
	check(not p1.a_destra, "con la paratia 1 come la si era lasciata")
	var quieto := true
	for i in 60 * 3:
		await get_tree().physics_frame
		if squalo.stato in [S.CARICA, S.ATTACCO]:
			quieto = false
	check(quieto, "nei 3 s dopo la ripartenza non attacca")
	await _fino_a(func(): return Dissolvenza.schermo_libero(get_tree()), 5.0)
	check(Dissolvenza.schermo_libero(get_tree()), "il nero se ne va")
	esito = await _tentativo(func(_n): return false)
	check(esito == "morso" and fiume.morsi_giro == 2, "il secondo tentativo: morde ancora, e il conto non si è azzerato (%s, %d)" % [esito, fiume.morsi_giro])
	check(not squalo.letale, "dopo %d morsi nello stesso giro non morde più" % fiume.morsi_per_giro)
	_urti_tratti.clear()
	_tratti_fatti.clear()
	esito = await _tentativo(func(_n): return false)
	check(esito == "approdo" and fiume.morsi == 2, "il terzo tentativo arriva all'approdo (%s, morsi %d)" % [esito, fiume.morsi])
	check(_urti_tratti.size() >= 1, "intanto urta, e la ciambella gira (%d urti: %s)" % [_urti_tratti.size(), _urti_tratti])
	check(_tratti_fatti == ["Imbarco", "Giusto1", "Giusto2", "Uscita"],
		"gli urti non portano nel ramo sbagliato né fanno perdere un bivio (%s)" % [_tratti_fatti])
	check(_urti_vicino_al_bivio == 0, "nessun urto negli ultimi %.0f m prima di un bivio" % fiume.calmo_prima_del_bivio)
	if morti0 >= 0:
		check(int(GameState.get(&"morti_totali")) == morti0 + 2, "i due morsi contano come morti, gli urti no (morti_totali %+d)" % (int(GameState.get(&"morti_totali")) - morti0))
	check(fiume.morsi_giro == 0 and squalo.letale, "all'approdo il conto si azzera e torna a mordere")

	print("3. Chi lo respinge sempre non viene mai morso")
	await _da_capo()
	var r0 := _respinte
	esito = await _tentativo(func(_n): return true)
	check(esito == "approdo" and fiume.morsi == 2 and _respinte > r0, "all'approdo senza morsi (%s, respinto %d volte)" % [esito, _respinte - r0])

	print("4. Chi lo respinge una volta sì e una no")
	await _da_capo()
	var tentativi := 0
	esito = ""
	while esito != "approdo" and tentativi < 4:
		tentativi += 1
		esito = await _tentativo(func(n): return n % 2 == 1)
	check(esito == "approdo" and tentativi <= 3, "finisce il giro (al tentativo %d, morsi in questo giro %d)" % [tentativi, fiume.morsi - 2])

	print("5. Con «letale» spento urta e fa girare la ciambella")
	await _da_capo()
	var morsi_prima := fiume.morsi
	fiume.squalo_letale = false
	var urti := {"n": 0}
	squalo.urta.connect(func(): urti.n += 1)
	var urtato := await _fino_a(func(): return urti.n > 0 or not fiume.a_bordo(), 120.0)
	var giro0: float = fiume.get(&"_giro")
	await _secondi(1.0)
	var giro1: float = fiume.get(&"_giro")
	check(urtato and fiume.morsi == morsi_prima, "urta invece di mordere")
	check(absf(giro1 - giro0) > 1.0 and fiume.a_bordo() and fiume.tratto != fiume.imbarco,
		"la ciambella gira su sé stessa (%.1f rad in 1 s) e il giro continua" % absf(giro1 - giro0))
	fiume.squalo_letale = true

	print("6. Dal checkpoint lo squalo è calmo fino al primo bivio")
	var cp := _salva("TestSqualoImbarco")
	await _riparti(cp)
	check(squalo != null and squalo.stato == S.ASSENTE, "ripartendo lo squalo non c'è")
	_zaino()
	await _sali()
	var calmo2 := true
	while fiume.tratto == fiume.imbarco:
		await get_tree().physics_frame
		if fiume.tratto == fiume.imbarco and squalo.stato != S.ASSENTE:
			calmo2 = false
	check(calmo2, "nel tratto d'imbarco resta calmo")
	var pronto := true
	for i in 60 * 3:
		await get_tree().physics_frame
		if squalo.stato in [S.CARICA, S.ATTACCO]:
			pronto = false
	check(pronto and squalo.stato == S.SEGUE, "passato il bivio arriva e per 3 s non attacca (%s)" % S.find_key(squalo.stato))
	_fine()


var _urti_tratti: Array = []
var _tratti_fatti: Array = []
var _urti_vicino_al_bivio := 0


## Un tentativo dall'imbarco, sulla ciambella: mira i dischi che servono (1 e 3) e, quando lo squalo attacca, lo
## respinge se [param respingi] (col numero dell'attacco) dice di sì. Finisce all'approdo, al morso (fatta la
## ripartenza) o dopo 150 s: "approdo", "morso", "tempo".
func _tentativo(respingi: Callable) -> String:
	var p1 := fiume.get_node(^"Paratia1") as ParatiaFiume
	var p3 := fiume.get_node(^"Paratia3") as ParatiaFiume
	var ev := {"fuori": false, "morso": false, "attacchi": 0}
	var su_fuori := func(): ev.fuori = true
	var su_morso := func(): ev.morso = true
	var su_urto := func():
		_urti_tratti.append("%s %.0f/%.0f" % [fiume.tratto.name, fiume.s, fiume.tratto.lunghezza()])
		if fiume.tratto.paratia and fiume.s > fiume.tratto.lunghezza() - fiume.calmo_prima_del_bivio:
			_urti_vicino_al_bivio += 1
	fiume.uscito.connect(su_fuori)
	fiume.morso_dallo_squalo.connect(su_morso)
	squalo.urta.connect(su_urto)
	var esito := "tempo"
	var era_attacco := false
	for i in 60 * 150:
		await get_tree().physics_frame
		if _tratti_fatti.is_empty() or _tratti_fatti.back() != String(fiume.tratto.name):
			if fiume.a_bordo():
				_tratti_fatti.append(String(fiume.tratto.name))
		if ev.fuori:
			esito = "approdo"
			break
		if ev.morso:
			esito = "morso"
			break
		var attacco := squalo.stato == S.ATTACCO
		if attacco and not era_attacco:
			ev.attacchi += 1
			if respingi.call(ev.attacchi):
				await _respingi()
		era_attacco = attacco
		if squalo.stato in [S.ATTACCO, S.MORSO]:
			continue
		if p1.attiva and p1.a_destra and _si_vede(p1.posizione_bersaglio):
			await _spara_al_bersaglio(p1, 8.0)
		elif p3.attiva and p3.a_destra and _si_vede(p3.posizione_bersaglio):
			await _spara_al_bersaglio(p3, 8.0)
	fiume.uscito.disconnect(su_fuori)
	fiume.morso_dallo_squalo.disconnect(su_morso)
	squalo.urta.disconnect(su_urto)
	if esito == "morso":
		await _fino_a(func(): return Dissolvenza.schermo_libero(get_tree()), 5.0)
	return esito


## Di nuovo sulla ciambella all'imbarco per un giro nuovo (dopo l'approdo; le paratie restano come sono).
func _da_capo() -> void:
	fiume.arrivato = false
	fiume.load_state(fiume.save_state())
	_tratti_fatti.clear()
	await _sali()


## Getto sul muso finché non torna sotto (al più 4 s).
func _respingi() -> void:
	var muso := squalo.get(&"_muso") as Node3D
	Input.action_press(&"spray")
	for i in 60 * 4:
		if muso:
			p.look_at_point(muso.global_position)
		await get_tree().physics_frame
		if squalo.stato != S.ATTACCO:
			break
	Input.action_release(&"spray")


## Quanto è lontano lo squalo dalla ciambella (in linea d'aria, in pianta).
func _dist_lungo_il_fiume() -> float:
	var a := fiume.ciambella()
	var b := squalo.squalo.global_position if squalo.squalo else squalo.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()


func _sali() -> void:
	var imbarco := level.get_node(^"Fiume/Marker/Imbarco") as Node3D
	p.teleport(imbarco.global_position, 0.0, 0.0)
	await get_tree().physics_frame
	fiume.sali(p)


func _spara_al_bersaglio(par: ParatiaFiume, secondi := 6.0) -> bool:
	var colpi := par.colpi
	var bersaglio: Vector3 = par.posizione_bersaglio
	var sparando := false
	for i in int(secondi * 60.0):
		if squalo.stato == S.ATTACCO:
			break
		var d := p.camera.global_position.distance_to(bersaglio)
		p.look_at_point(bersaglio + Vector3.UP * 0.0067 * d * d)
		if par.attiva and _si_vede(bersaglio) and d < 18.0 and not sparando:
			Input.action_press(&"spray")
			sparando = true
		await get_tree().physics_frame
		if par.colpi > colpi:
			break
	Input.action_release(&"spray")
	return par.colpi > colpi


func _si_vede(punto: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p.get_eye_position(), punto, Layers.WORLD, [p.get_rid()])
	return p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _fino_a(cond: Callable, secondi: float) -> bool:
	for i in int(secondi * 60.0):
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


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
	var t_attesa := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_attesa < 90000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _secondi(0.1)
	level = get_tree().current_scene
	p = GameState.player
	fiume = level.get_node_or_null(^"Fiume/FiumeLento") as FiumeLento
	squalo = fiume.squalo as SqualoFiume if fiume else null
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
	Input.action_release(&"spray")
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
