extends Node
## Test automatico dell'inseguimento I1 e del finale SB1 (versione A, "Le condotte"), nella scena di prova
## scenes/test/inseguimento_prova.tscn (la sala da sola, col giocatore nella bocca del primo tubo):
## 1. La sala: i tubi nel gruppo "scivolo", sei paratie col bersaglio, la grata, quattro checkpoint, la
##    scala del bacino; lei non c'è.
## 2. Il primo tubo: ci si accovaccia, si scivola e si arriva nella vasca 1 (checkpoint).
## 3. Le paratie chiuse non si passano; tenendo il getto sul bersaglio quella giusta si alza, l'altra no.
## 4. Lei sale nella vasca: un getto in faccia la ricaccia sotto, poi torna; se la lasci, ti prende e si
##    riparte dalla vasca.
## 5. La paratia sbagliata: il tubo porta nella vasca di scolo e lì lei ti prende.
## 6. La strada giusta fino in fondo: vasca 2 (la paratia sale piano), vasca 3, la spirale, il bacino
##    (la grata cala dietro, checkpoint).
## 7. SB1: verso la scaletta lei sbuca dal pozzo, la camera la guarda, nero e fine del capitolo.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_inseguimento.gd

const LEVEL := "res://scenes/test/inseguimento_prova.tscn"

var level: Node
var sala: SalaInseguimento
var p: Player
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()
	# se qualcosa si blocca il test non resta appeso
	get_tree().create_timer(900.0, true, false, true).timeout.connect(func():
		printerr("  FALLITO tempo scaduto")
		_failed += 1
		_fine())


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


func _aspetta_livello() -> void:
	var vecchio := GameState.player
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player != vecchio and not GameState.is_dying:
			break
	await _frames(5)
	level = get_tree().current_scene
	p = GameState.player
	sala = level.get_node("SalaInseguimento") as SalaInseguimento
	# nel test lei arriva prima e torna prima (le regole sono le stesse)
	sala.comparsa = PackedFloat32Array([3.0, 1.0, 2.0])
	sala.ritorno_dopo = 3.0
	p.water_pack.set_equipped(true, false)
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame


func _lascia() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"spray"]:
		Input.action_release(a)


func _salta_morte() -> void:
	await _frames(20)
	for s in GameState.get_children():
		if s is DeathSequence:
			(s as DeathSequence).skip()
	await _aspetta_livello()


func _checkpoint() -> String:
	return String(GameState.snapshot.get("checkpoint", ""))


static func b(v: Array) -> Vector3:
	return SalaInseguimento.b(v)


## Scivola (tenendo avanti finché non si parte) finché non si è fermi in piedi fuori dai tubi, o si muore.
## Torna {"arrivo": posizione, "secondi", "accovacciato" (nei tubi), "morto"}.
func _scivola(max_s := 40.0, finche_non_parte := 0.0) -> Dictionary:
	var r := {"accovacciato": false, "morto": false, "scivolato": false, "secondi": 0.0}
	Input.action_press(&"move_forward")
	var t := 0.0
	while t < max_s:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if GameState.is_dying:
			r.morto = true
			break
		if p.is_sliding:
			r.scivolato = true
			Input.action_release(&"move_forward")
		if sala.in_tubo(p.global_position) and p.is_crouching:
			r.accovacciato = true
		if r.scivolato and not p.is_sliding and p.is_on_floor() and not sala.in_tubo(p.global_position) and t > 1.0:
			break
		if finche_non_parte > 0.0 and not r.scivolato and t > finche_non_parte:
			break
	_lascia()
	await _frames(20)
	r.secondi = t
	r.arrivo = p.global_position
	return r


## Si mette nella vasca [param v] davanti alla paratia [param k] e tiene il getto sul bersaglio.
func _spruzza_paratia(k: int, secondi: float) -> void:
	var d: Dictionary = sala.paratie[k]
	var bers := (d["bersaglio_nodo"] as Node3D).global_position
	var verso := b(d["verso"])
	var piedi := bers - verso * 3.0
	piedi.y = b(d["pannello"]).y - 0.75 + 0.05   # il pannello è centrato 75 cm sopra il fondo della vasca
	p.teleport(piedi)
	await _frames(3)
	p.look_at_point(bers)
	p.water_pack.set_tank_amount(20.0)
	Input.action_press(&"spray")
	await _frames(int(secondi * 60.0))
	Input.action_release(&"spray")


## Entra nel tubo dietro la paratia [param k] (già aperta) camminando dalla vasca.
func _entra_paratia(k: int, max_s := 40.0, finche_non_parte := 0.0) -> Dictionary:
	var d: Dictionary = sala.paratie[k]
	var verso := b(d["verso"])
	var bocca := b(d["pannello"])
	var piedi := bocca - verso * 2.2
	piedi.y = bocca.y - 0.75 + 0.05
	p.teleport(piedi)
	await _frames(3)
	p.look_at_point(bocca + verso * 3.0)
	p.set_look(p.yaw, 0.0)
	return await _scivola(max_s, finche_non_parte)


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	await _aspetta_livello()

	print("1. La sala dell'inseguimento")
	var tubi := sala.get_children().filter(func(n): return n is StaticBody3D and n.is_in_group(&"scivolo"))
	check(tubi.size() == 7, "sette tubi nel gruppo \"scivolo\" (%d)" % tubi.size())
	check(sala.paratie.size() == 6 and sala.paratie.all(func(d): return d["pannello_nodo"] != null),
		"sei paratie, ognuna col suo pannello e il bersaglio")
	check(sala.paratie.filter(func(d): return d["giusta"]).size() == 3, "tre giuste e tre sbagliate")
	check(sala.grata != null and not sala.grata_giu, "la grata è alzata")
	check(sala.checkpoint.size() == 4, "quattro checkpoint: le tre vasche e il bacino")
	check(sala.get_node_or_null(^"Scala") is Ladder, "la scaletta del bacino")
	check(not sala.lei.visible, "lei non c'è")
	var luci := sala.find_children("*", "Light3D", true, false)
	check(luci.size() > 20 and luci.all(func(l): return l.has_meta(&"risveglio_ignora")),
		"%d luci, nessuna si spegne col blackout ripartendo" % luci.size())

	print("2. Il primo tubo, fino alla vasca 1")
	p.set_look(-PI / 2.0, 0.0)   # verso est, giù per il tubo (come chi arriva dalla torre)
	var r := await _scivola()
	check(r.scivolato and r.accovacciato, "nel tubo si scivola accovacciati")
	check(not r.morto and sala._vasca_di(r.arrivo) == 0, "si arriva nella vasca 1 (%s, %.1f s)" % [str(r.arrivo), r.secondi])
	check(_checkpoint().ends_with("Checkpoint_vasca_1"), "checkpoint: vasca 1 (%s)" % _checkpoint())
	check(not p.is_crouching, "fuori dal tubo ci si rialza")

	print("3. Le paratie")
	sala.comparsa = PackedFloat32Array([300.0, 1.0, 2.0])   # qui lei non serve ancora
	await _entra_paratia(0, 4.0, 3.0)
	check(sala._vasca_di(p.global_position) == 0, "chiusa, la paratia non si passa")
	await _spruzza_paratia(1, 0.5)
	await _spruzza_paratia(0, 2.0)
	await _frames(70)
	check(sala.paratie[0]["apre"] and float(sala.paratie[0]["aperta"]) >= 1.0, "col getto sul bersaglio la giusta si alza")
	check(not sala.paratie[1]["apre"], "mezzo secondo di getto non basta per l'altra")
	var pann: Node3D = sala.paratie[0]["pannello_nodo"]
	check(pann.global_position.y > b(sala.paratie[0]["pannello"]).y + 1.5, "il pannello è salito di %.1f m" % (pann.global_position.y - b(sala.paratie[0]["pannello"]).y))

	print("4. Lei nella vasca 1")
	sala._in_vasca_t = 0.0
	sala.comparsa = PackedFloat32Array([2.0, 1.0, 2.0])
	var t0 := Time.get_ticks_msec()
	while not sala.lei.visible and Time.get_ticks_msec() - t0 < 15000:
		await _frames(1)
	await _frames(100)
	check(sala.lei.visible and sala.lei_stato == SalaInseguimento.Lei.SU, "dopo un po' lei sale dall'acqua")
	var viso := sala.lei.get_eye_position()
	p.look_at_point(viso)
	p.water_pack.set_tank_amount(20.0)
	Input.action_press(&"spray")
	await _frames(90)
	Input.action_release(&"spray")
	check(sala.lei_stato == SalaInseguimento.Lei.SCENDE or sala.lei_stato == SalaInseguimento.Lei.VIA, "un getto in faccia la ricaccia sotto")
	await _frames(120)
	check(not sala.lei.visible, "torna sott'acqua")
	t0 = Time.get_ticks_msec()
	while not sala.lei.visible and Time.get_ticks_msec() - t0 < 15000:
		await _frames(1)
	check(sala.lei.visible, "se resti nella vasca torna")
	t0 = Time.get_ticks_msec()
	while not GameState.is_dying and Time.get_ticks_msec() - t0 < 20000:
		await _frames(1)
	check(GameState.is_dying and GameState.last_death_cause == &"medusa", "se la lasci, ti prende")
	await _salta_morte()
	check(sala._vasca_di(p.global_position) == 0, "si riparte nella vasca 1")

	print("5. La paratia sbagliata")
	await _spruzza_paratia(1, 2.0)
	await _frames(70)
	r = await _entra_paratia(1)
	t0 = Time.get_ticks_msec()
	while not GameState.is_dying and Time.get_ticks_msec() - t0 < 15000:
		await _frames(1)
	check(GameState.is_dying and sala._lei_dove.begins_with("scolo"), "nella vasca di scolo lei ti prende (arrivo %s, lei: %s)" % [str(r.arrivo), sala._lei_dove])
	await _salta_morte()
	check(sala._vasca_di(p.global_position) == 0, "e si riparte dalla vasca 1")

	print("6. La strada giusta")
	for passo in [[0, 1, "vasca_2", 3.8], [2, 2, "vasca_3", 2.0], [4, -1, "bacino", 2.0]]:
		var k: int = passo[0]
		await _spruzza_paratia(k, 2.0)
		# la paratia della vasca 2 sale piano: lei arriva subito e va respinta
		var attesa := 0
		while float(sala.paratie[k]["aperta"]) < 1.0 and attesa < 600:
			if sala.lei_stato == SalaInseguimento.Lei.SU:
				sala.respingi()
			await _frames(1)
			attesa += 1
		check(float(sala.paratie[k]["aperta"]) >= 1.0 and not GameState.is_dying, "paratia %d aperta" % k)
		r = await _entra_paratia(k)
		var arrivo_ok: bool = (sala._vasca_di(r.arrivo) == int(passo[1])) if int(passo[1]) >= 0 else sala.grata_giu
		check(not r.morto and arrivo_ok, "giù per il tubo fino a: %s (%.1f s, %s)" % [passo[2], r.secondi, str(r.arrivo)])
		await _frames(30)
		check(_checkpoint().ends_with("Checkpoint_" + String(passo[2])), "checkpoint %s (%s)" % [passo[2], _checkpoint()])
	check(sala.grata_giu, "nel bacino la grata cala dietro")
	check(sala._lei_dove == "grata", "e lei ci arriva contro")

	print("7. SB1")
	var finito := [false]
	sala.capitolo_finito.connect(func(): finito[0] = true)
	var s: Dictionary = sala.dati["scale"][0]
	var verso_scala := b([float(s["x"]) + 1.0, float(s["y"]), float(s["z0"])])
	Input.action_press(&"move_forward")
	p.look_at_point(verso_scala + Vector3.UP * 1.0)
	p.set_look(p.yaw, 0.0)
	t0 = Time.get_ticks_msec()
	while not sala._sb1 and Time.get_ticks_msec() - t0 < 15000:
		await _frames(1)
	_lascia()
	check(sala._sb1, "andando verso la scaletta parte SB1")
	check(not p.input_enabled, "il giocatore si ferma")
	await _frames(240)
	check(sala.lei.visible and sala.lei.animazione == &"affacciata", "lei sbuca dal pozzo, affacciata")
	var dir := (sala.lei.get_eye_position() - p.camera.global_position).normalized()
	check(dir.dot(-p.camera.global_basis.z) > 0.9, "e la camera la guarda (%.2f)" % dir.dot(-p.camera.global_basis.z))
	t0 = Time.get_ticks_msec()
	while not finito[0] and Time.get_ticks_msec() - t0 < 15000:
		await _frames(1)
	check(finito[0] and not GameState.is_dying, "nero: fine del capitolo")
	_fine()


func _fine() -> void:
	_lascia()
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
