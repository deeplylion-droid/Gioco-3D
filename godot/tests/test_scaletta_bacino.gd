extends Node
## Test della scaletta del bacino dopo SB1 (collaudo T1: in cima il giocatore restava incastrato fra i montanti),
## col giocatore vero nella scena di prova scenes/test/sottomarino_prova.tscn, come nella partita:
## prima SB1 vero (lei ti fissa, si tuffa, i comandi tornano), poi su per la scaletta e oltre la porta nel tunnel,
## in quattro modi (quelli della sonda del collaudo, tests/collaudo/sonda_scaletta.gd):
## A) su guardando in alto fino a 40 cm dalla cima, poi verso la porta e avanti;
## B) avanti guardando la scaletta finché scavalca da solo, poi verso la porta;
## C) avanti guardando la porta da subito, dal piede della scaletta (anche spostati di lato di ±12 cm);
## D) come B, ma in cima fermo, poi salto, sinistra, destra e indietro, poi verso la porta.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_scaletta_bacino.gd

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"

var ins: SalaInseguimento
var sott: SalaSottomarino
var p: Player
var piede: Vector3
var cima: Vector3
var uscita: Vector3
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(1200.0, true, false, true).timeout.connect(func():
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


func _fine() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump"]:
		Input.action_release(a)
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _yaw_verso(q: Vector3) -> float:
	return atan2(-(q.x - p.global_position.x), -(q.z - p.global_position.z))


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	var level := get_tree().current_scene
	p = GameState.player
	ins = level.get_node("SalaInseguimento") as SalaInseguimento
	sott = level.get_node("SalaSottomarino") as SalaSottomarino
	sott.costruisci()
	ins.sb1_finito.connect(sott.attiva_tunnel)
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var sc: Dictionary = ins.dati["scale"][ins.dati["scale"].size() - 1]
	piede = SalaInseguimento.b([float(sc["x"]), float(sc["y"]), float(sc["z0"])])
	cima = SalaInseguimento.b([float(sc["x"]), float(sc["y"]), float(sc["z1"])])
	uscita = SalaInseguimento.b(ins.dati["porta"]["uscita"])

	print("1. SB1")
	var finito_sb1 := [false]
	ins.sb1_finito.connect(func(): finito_sb1[0] = true)
	var nero := [false]
	ins.capitolo_finito.connect(func(): nero[0] = true)
	ins.cala_grata()
	p.teleport(piede + Vector3(3.0, 0.3, 0.0))
	await _frames(3)
	ins.inizia_sb1()
	var t0 := Time.get_ticks_msec()
	while not finito_sb1[0] and Time.get_ticks_msec() - t0 < 15000:
		await _frames(1)
	check(finito_sb1[0] and not nero[0] and p.input_enabled, "SB1: lei si tuffa, niente nero, i comandi tornano")

	# (il primo giro parte da dove SB1 lascia il giocatore, gli altri dal piede della scaletta)
	var giri := [["A", 0.0, false], ["B", 0.0, true], ["C", 0.0, true], ["C", 0.12, true], ["C", -0.12, true], ["D", 0.0, true]]
	for g in giri:
		if OS.get_environment("GIRI") != "" and not String(g[0]) in OS.get_environment("GIRI"):
			continue
		await _giro(String(g[0]), float(g[1]), bool(g[2]))
	_fine()


## Un giro: su per la scaletta nel modo [param modo], poi oltre la porta del bacino nel tunnel.
func _giro(modo: String, di_lato: float, dal_piede: bool) -> void:
	print("2. Scaletta, modo %s%s (a %d s)" % [modo, (" spostato di %+.2f m" % di_lato) if di_lato != 0.0 else "", Time.get_ticks_msec() / 1000])
	# (lei qui non serve: entrando nel tunnel riemerge e insegue; a ogni giro si riparte con lei sotto)
	sott.lei_stato = SalaSottomarino.Lei.VIA
	sott.lei_tunnel.via()
	if dal_piede:
		p.teleport(piede + Vector3(1.2, 0.05, di_lato))
		await _frames(10)
	p.set_look(_yaw_verso(Vector3(piede.x, 0.0, p.global_position.z)), 0.0)
	Input.action_press(&"move_forward")
	var fase := "su"
	var su_scala := false
	var f := 0
	while f < 60 * 15 and Vector2(uscita.x - p.global_position.x, uscita.z - p.global_position.z).length() > 0.5:
		await _frames(1)
		f += 1
		su_scala = su_scala or p.ladder != null
		if fase == "su":
			match modo:
				"A":
					p.set_look(p.yaw, 0.6)
					if p.global_position.y > cima.y - 0.4:
						fase = "porta"
						Input.action_release(&"move_forward")
						await _frames(10)
						Input.action_press(&"move_forward")
				"B", "D":
					p.set_look(p.yaw, 0.6)
					if p.ladder == null and p.global_position.y > cima.y - 0.2:
						fase = "porta"
						if modo == "D":
							Input.action_release(&"move_forward")
							await _frames(60)
							for prova in [&"jump", &"move_left", &"move_right", &"move_back"]:
								Input.action_press(prova)
								await _frames(20)
								Input.action_release(prova)
								await _frames(20)
							Input.action_press(&"move_forward")
				"C":
					p.set_look(_yaw_verso(uscita), 0.0)
					if p.global_position.y > cima.y - 0.2:
						fase = "porta"
		else:
			p.set_look(_yaw_verso(uscita), 0.0)
	var arrivato := Vector2(uscita.x - p.global_position.x, uscita.z - p.global_position.z).length() <= 0.5
	check(su_scala and arrivato, "modo %s%s: dalla scaletta si arriva alla porta (in %.1f s, pos %s)" % [modo,
			(" %+.2f" % di_lato) if di_lato != 0.0 else "", f / 60.0, str(p.global_position.snappedf(0.01))])
	# poi oltre la porta, dentro il tunnel
	var dentro := sott.punto(SalaSottomarino.PORTA_S) - sott.destra(SalaSottomarino.PORTA_S) * (sott.canale + 1.3)
	f = 0
	while p.global_position.x > 38.6 and f < 60 * 6:
		p.set_look(_yaw_verso(dentro), 0.0)
		await _frames(1)
		f += 1
	Input.action_release(&"move_forward")
	check(not GameState.is_dying and p.global_position.x <= 38.6 and absf(p.global_position.y - sott.piano) < 0.2,
			"modo %s: oltre la porta si entra nel tunnel (x %.1f, y %.2f)" % [modo, p.global_position.x, p.global_position.y])
	await _frames(10)
