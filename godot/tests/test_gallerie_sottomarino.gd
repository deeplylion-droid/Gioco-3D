extends Node
## Test delle gallerie di servizio del tunnel sottomarino (collaudo G1: all'imbocco della galleria a 425 il giocatore
## restava fermo contro lo spigolo della bocca), col giocatore vero nella scena di prova sottomarino_prova.tscn: in ogni
## galleria si entra come un giocatore (dalla banchina verso la bocca, ci si accovaccia davanti, poi lungo la galleria
## fino alla bocca d'uscita e di nuovo sulla banchina), centrati e spostati di 30 cm a destra e a sinistra; non ci si
## deve mai fermare (velocità sotto 0,3 m/s per più di 0,5 s) e si arriva in fondo.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_gallerie_sottomarino.gd

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"

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


func _fine() -> void:
	for a in [&"move_forward", &"crouch", &"sprint"]:
		Input.action_release(a)
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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
	sott = level.get_node("SalaSottomarino") as SalaSottomarino
	sott.costruisci()
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	# (lei qui non serve: resta sotto)
	sott.lei_stato = SalaSottomarino.Lei.VIA
	for gal in sott.ostacoli.filter(func(o): return o["tipo"] == "galleria"):
		for spostato in [0.0, 0.3, -0.3]:
			await _attraversa(gal, spostato)
	_fine()


## Dalla banchina dentro la galleria [param gal] e fuori dall'altra bocca, spostati di [param spostato] metri (a destra
## di chi cammina) rispetto alla linea di mezzo.
func _attraversa(gal: Dictionary, spostato: float) -> void:
	var lato := float(gal["lato"])
	var s_in: float = float(gal["s"]) - SalaSottomarino.GALLERIA_BOCCA - 2.0
	var u_banchina := sott.muro - 0.6 - spostato * lato
	var st := sott.punto(s_in) + sott.destra(s_in) * lato * u_banchina
	p.teleport(Vector3(st.x, sott.piano + 0.05, st.z))
	await _frames(10)
	sott.lei_stato = SalaSottomarino.Lei.VIA
	Input.action_press(&"move_forward")
	var s_p := s_in
	var fine_g: float = float(gal["s"]) + float(gal["lungo"]) + SalaSottomarino.GALLERIA_BOCCA + 1.5
	var bocca0: float = float(gal["s"]) - SalaSottomarino.GALLERIA_BOCCA * 0.5
	var bocca1: float = float(gal["s"]) + float(gal["lungo"]) + SalaSottomarino.GALLERIA_BOCCA * 0.5
	var u_gal := sott.muro + sott.spessore + SalaSottomarino.GALLERIA_LARGA * 0.5 - spostato * lato
	var fermo := 0.0
	var fermo_max := 0.0
	var dove_fermo := ""
	var f := 0
	while s_p < fine_g and f < 60 * 40:
		var pr := sott.proietta_vicino(p.global_position, s_p)
		s_p = float(pr[0])
		var s_q := s_p + 2.0
		var u := u_banchina
		if s_p < bocca0 - 0.3:
			s_q = bocca0
			u = u_gal
		elif s_p < bocca1 - 0.3:
			s_q = minf(s_p + 2.0, bocca1)
			u = u_gal
		var q := sott.punto(s_q) + sott.destra(s_q) * lato * u
		p.look_at_point(Vector3(q.x, p.global_position.y + 1.0, q.z))
		p.set_look(p.yaw, 0.0)
		if sott.in_tubo(p.global_position):
			Input.action_release(&"crouch")
		elif s_p > bocca0 - 1.5 and s_p < bocca0 + 1.0:
			Input.action_press(&"crouch")
		await _frames(1)
		f += 1
		var v := Vector2(p.velocity.x, p.velocity.z).length()
		if v < 0.3 and f > 20:
			fermo += 1.0 / 60.0
			if fermo > fermo_max:
				fermo_max = fermo
				dove_fermo = "s %.2f lato %.2f" % [s_p, float(pr[1])]
		else:
			fermo = 0.0
	Input.action_release(&"move_forward")
	Input.action_release(&"crouch")
	await _frames(10)
	check(s_p >= fine_g and fermo_max <= 0.5, "galleria %d, %s: si passa senza fermarsi (s %.1f di %.1f in %.1f s; fermo al più %.2f s%s)" % [
			int(gal["s"]), "centrati" if spostato == 0.0 else ("30 cm a destra" if spostato > 0.0 else "30 cm a sinistra"),
			s_p, fine_g, f / 60.0, fermo_max, (" a " + dove_fermo) if fermo_max > 0.5 else ""])
