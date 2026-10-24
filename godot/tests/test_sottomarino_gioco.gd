extends Node
## Test di gioco del tunnel del viaggio sottomarino, col giocatore vero, nella scena di prova
## scenes/test/sottomarino_prova.tscn (la sala delle condotte e il tunnel, come nel livello):
## 1. SB1: lei ti fissa, poi si tuffa e i comandi tornano; la scaletta e la porta si accendono.
## 2. Dalla passerella si passa la porta del bacino e si entra nel tunnel.
## 3. Guardando la presa lei riemerge.
## 4. Correndo sulla banchina si passa la prima curva (torre e condotte si possono liberare) e lei non ti prende.
## 5. Dalla banchina si salta sui due gommoni e si arriva sull'altra banchina.
## 6. Nel canale si va a guado (piano) e dai gradini si risale.
## 7. Nella galleria di servizio si sta accovacciati e si passa.
## 8. Il portello: dalla banchina su per la scala e lungo il pontile si entra di lato nella camera stagna; con E si
##    chiude, poi la fine.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_sottomarino_gioco.gd

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"

var level: Node
var ins: SalaInseguimento
var sott: SalaSottomarino
var p: Player
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()
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


func _lascia() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"spray", &"sprint", &"jump", &"crouch"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	level = get_tree().current_scene
	p = GameState.player
	ins = level.get_node("SalaInseguimento") as SalaInseguimento
	sott = level.get_node("SalaSottomarino") as SalaSottomarino
	sott.costruisci()
	ins.sb1_finito.connect(sott.attiva_tunnel)
	p.water_pack.set_equipped(true, false)
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame

	# (con PASSO=7 nell'ambiente si parte dalla galleria: per provarla senza rifare SB1)
	if OS.get_environment("PASSO") == "":
		await _passi_1_6()
	var t0 := 0
	print("7. La galleria di servizio")
	var gal: Dictionary = sott.ostacoli.filter(func(o): return o["tipo"] == "galleria")[0]
	var s_in: float = float(gal["s"]) - SalaSottomarino.GALLERIA_BOCCA - 2.0
	var st := sott.punto(s_in) - sott.destra(s_in) * (sott.muro - 0.6)
	p.teleport(Vector3(st.x, sott.piano + 0.05, st.z))
	await _frames(10)
	var accovacciato := false
	Input.action_press(&"move_forward")
	t0 = Time.get_ticks_msec()
	var s_p := s_in
	var fine_g: float = float(gal["s"]) + float(gal["lungo"]) + SalaSottomarino.GALLERIA_BOCCA + 1.5
	var bocca0: float = float(gal["s"]) - SalaSottomarino.GALLERIA_BOCCA * 0.5
	while s_p < fine_g and Time.get_ticks_msec() - t0 < 30000:
		s_p = float(sott.proietta_vicino(p.global_position, s_p)[0])
		# (prima verso la bocca d'entrata, poi lungo la galleria fino a metà della bocca d'uscita, poi sulla banchina)
		var u_gal := sott.muro + sott.spessore + SalaSottomarino.GALLERIA_LARGA * 0.5
		var bocca1: float = float(gal["s"]) + float(gal["lungo"]) + SalaSottomarino.GALLERIA_BOCCA * 0.5
		var s_q := s_p + 2.0
		var u := sott.muro - 0.6
		if s_p < bocca0 - 0.3:
			s_q = bocca0
			u = u_gal
		elif s_p < bocca1 - 0.3:
			s_q = minf(s_p + 2.0, bocca1)
			u = u_gal
		var q := sott.punto(s_q) + sott.destra(s_q) * float(gal["lato"]) * u
		p.look_at_point(Vector3(q.x, p.global_position.y + 1.0, q.z))
		p.set_look(p.yaw, 0.0)
		# (davanti alla bocca ci si accovaccia col tasto, come farebbe il giocatore; dentro resta accovacciato da solo)
		if sott.in_tubo(p.global_position):
			Input.action_release(&"crouch")
			if p.is_crouching:
				accovacciato = true
		elif s_p > bocca0 - 1.5 and s_p < bocca0 + 1.0:
			Input.action_press(&"crouch")
		if OS.get_environment("PASSO") != "" and Engine.get_physics_frames() % 30 == 0:
			print("    s %.2f lato %.2f y %.2f tubo %s acc %s" % [s_p, float(sott.proietta_vicino(p.global_position, s_p)[1]), p.global_position.y, sott.in_tubo(p.global_position), p.is_crouching])
		await _frames(1)
	_lascia()
	check(s_p >= fine_g, "la galleria di servizio si passa (s %.1f di %.1f)" % [s_p, fine_g])
	check(accovacciato, "nella galleria si sta accovacciati")

	print("8. Il portello")
	var fine := [false]
	sott.fine_demo.connect(func(): fine[0] = true)
	var L := sott.lunghezza()
	var pL := sott.punto(L)
	var rL := sott.destra(L)
	var dL := sott.direzione(L)
	var sg := sott.piano + SalaSottomarino.SOGLIA
	# dalla banchina sinistra: su per la scala lungo il muro, lungo il pontile fino alla sua testa, poi di lato nella
	# porta e dentro la camera stagna
	var s_scala := L - SalaSottomarino.BALLATOIO - 12 * 0.32 - 1.5
	var via := [
		sott.punto(s_scala) - sott.destra(s_scala) * (sott.muro - 0.5) + Vector3.UP * (sott.piano - sott.acqua),
		pL - dL * 0.5 - rL * (sott.muro - 0.5) + Vector3.UP * (sg - sott.acqua),
		pL - dL * 0.55 + rL * (SalaSottomarino.PONTILE_FINO - 0.35) + Vector3.UP * (sg - sott.acqua),
		pL - dL * 0.05 + rL * (SalaSottomarino.PORTA_SX + 0.45) + Vector3.UP * (sg - sott.acqua),
		pL + dL * 1.2 + rL * (SalaSottomarino.PORTA_SX + 0.6) + Vector3.UP * (sg - sott.acqua),
	]
	p.teleport(via[0] + Vector3.UP * 0.05)
	await _frames(10)
	Input.action_press(&"move_forward")
	t0 = Time.get_ticks_msec()
	var tappa := 1
	while tappa < via.size() and Time.get_ticks_msec() - t0 < 30000:
		var q: Vector3 = via[tappa]
		if Vector2(p.global_position.x - q.x, p.global_position.z - q.z).length() < 0.3:
			tappa += 1
			continue
		p.look_at_point(Vector3(q.x, p.global_position.y + 1.6, q.z))
		p.set_look(p.yaw, 0.0)
		await _frames(1)
	_lascia()
	await _frames(10)
	var dentro_camera := (p.global_position - pL).dot(dL) > 0.3 and absf(p.global_position.y - sg) < 0.15
	check(tappa >= via.size() and dentro_camera, "dalla banchina su per la scala, lungo il pontile e di lato nella porta, fino alla camera (tappa %d, y %.2f)" % [tappa, p.global_position.y])
	var verso_porta := sott.punto(L) + Vector3.UP * (sott.piano - sott.acqua + SalaSottomarino.SOGLIA + 1.0)
	p.look_at_point(verso_porta)
	await _frames(5)
	if InputMap.has_action(&"interact"):
		Input.action_press(&"interact")
		await _frames(3)
		Input.action_release(&"interact")
	t0 = Time.get_ticks_msec()
	while not fine[0] and Time.get_ticks_msec() - t0 < 10000:
		await _frames(1)
	check(fine[0], "dalla camera stagna con E si chiude il portello, poi la fine")
	_fine()


func _fine() -> void:
	_lascia()
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)



## I passi 1-6: SB1, la porta, la riemersione, la corsa, il guado.
func _passi_1_6() -> void:
	print("1. SB1")
	var finito_sb1 := [false]
	ins.sb1_finito.connect(func(): finito_sb1[0] = true)
	var nero := [false]
	ins.capitolo_finito.connect(func(): nero[0] = true)
	ins.cala_grata()
	var sc: Dictionary = ins.dati["scale"][ins.dati["scale"].size() - 1]
	var piede := SalaInseguimento.b([float(sc["x"]) + 3.0, float(sc["y"]), float(sc["z0"]) + 0.3])
	p.teleport(piede)
	await _frames(3)
	ins.inizia_sb1()
	var t0 := Time.get_ticks_msec()
	while not finito_sb1[0] and Time.get_ticks_msec() - t0 < 15000:
		await _frames(1)
	check(finito_sb1[0] and not nero[0], "dopo SB1 niente nero: il capitolo continua")
	check(p.input_enabled, "i comandi tornano")
	check(ins.find_child("FaroScaletta", true, false) != null and ins.find_child("LucePorta", true, false) != null, "la scaletta e la porta si accendono")

	print("2. La porta del bacino")
	var porta := SalaInseguimento.b(ins.dati["porta"]["uscita"])
	p.teleport(porta + Vector3.UP * 0.05)
	await _frames(5)
	var dentro := sott.punto(SalaSottomarino.PORTA_S) - sott.destra(SalaSottomarino.PORTA_S) * (sott.canale + 1.3)
	p.look_at_point(Vector3(dentro.x, p.global_position.y + 1.6, dentro.z))
	p.set_look(p.yaw, 0.0)
	Input.action_press(&"move_forward")
	t0 = Time.get_ticks_msec()
	while p.global_position.x > 38.6 and Time.get_ticks_msec() - t0 < 6000:
		await _frames(1)
	_lascia()
	check(p.global_position.x <= 38.6 and absf(p.global_position.y - sott.piano) < 0.2, "dalla passerella si entra nel tunnel (x %.1f, y %.2f)" % [p.global_position.x, p.global_position.y])

	print("3. La riemersione")
	p.look_at_point(sott.punto(-1.0) + Vector3.UP * 2.0)
	await _frames(20)
	check(sott.lei_stato == SalaSottomarino.Lei.SALE or sott.lei_stato == SalaSottomarino.Lei.INSEGUE, "guardando la presa lei riemerge")

	print("4. La corsa e la prima curva")
	var curva := [false]
	sott.prima_curva_passata.connect(func(): curva[0] = true)
	await _frames(100)
	Input.action_press(&"move_forward")
	if InputMap.has_action(&"sprint"):
		Input.action_press(&"sprint")
	t0 = Time.get_ticks_msec()
	var s_g := 2.0
	while s_g < 62.0 and Time.get_ticks_msec() - t0 < 25000 and not GameState.is_dying:
		s_g = float(sott.proietta_vicino(p.global_position, s_g)[0])
		var avanti := sott.punto(s_g + 5.0) - sott.destra(s_g + 5.0) * (sott.canale + 1.3)
		p.look_at_point(Vector3(avanti.x, p.global_position.y + 1.6, avanti.z))
		p.set_look(p.yaw, 0.0)
		await _frames(1)
	_lascia()
	check(s_g >= 62.0 and not GameState.is_dying, "correndo si passa la prima curva e lei non ti prende (s %.1f)" % s_g)
	check(curva[0], "passata la prima curva il tunnel lo dice (torre e condotte si liberano)")
	# da qui lei resta ferma: le prove dopo sono sul giocatore
	sott.lei_stato = SalaSottomarino.Lei.VIA
	sott.lei_tunnel.via()

	# 5. i gommoni e i salti li prova enigmi, che li fa (test_parkour_gommoni.gd)

	print("6. Il guado")
	var nel := sott.punto(100.0)
	p.teleport(Vector3(nel.x, sott.fondo + 0.05, nel.z))
	await _frames(20)
	var a := p.global_position
	var av := sott.punto(110.0)
	p.look_at_point(Vector3(av.x, p.global_position.y + 1.6, av.z))
	p.set_look(p.yaw, 0.0)
	Input.action_press(&"move_forward")
	if InputMap.has_action(&"sprint"):
		Input.action_press(&"sprint")
	await _frames(120)
	_lascia()
	var v := Vector2(p.global_position.x - a.x, p.global_position.z - a.z).length() / 2.0
	check(v < 2.3 and v > 0.5, "nel canale si va a guado, piano (%.2f m/s)" % v)
	# dal gradino continuo si risale da qualunque punto: qui, sulla riva destra
	var sg := 103.0
	var lato_g := 1.0
	var davanti := sott.punto(sg) + sott.destra(sg) * lato_g * (sott.canale - 1.6)
	p.teleport(Vector3(davanti.x, sott.fondo + 0.05, davanti.z))
	await _frames(10)
	var sopra := sott.punto(sg) + sott.destra(sg) * lato_g * (sott.canale + 1.2)
	p.look_at_point(Vector3(sopra.x, sott.piano + 1.6, sopra.z))
	p.set_look(p.yaw, 0.0)
	Input.action_press(&"move_forward")
	for k in 5:
		await _frames(20)
		Input.action_press(&"jump")
		await _frames(4)
		Input.action_release(&"jump")
	await _frames(20)
	_lascia()
	check(absf(p.global_position.y - sott.piano) < 0.15, "dal gradino continuo si risale sulla banchina (y %.2f)" % p.global_position.y)

