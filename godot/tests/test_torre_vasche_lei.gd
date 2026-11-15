extends Node
## Test di lei nelle vasche di raccolta della torre (build 0.4.0 «L'acqua è sua»), col giocatore vero, senza schermo.
## Per ogni vasca, a luci di dopo le pompe (BLACKOUT):
## - chi cade nella vasca la chiama: la luce parte dal pozzo e arriva alla vasca; lei esce dopo circa
##   SalaTorre.vasche_avviso secondi;
## - chi sale la scaletta e arriva sulla pedana in tempo è salvo: lei esce, ma non lo prende;
## - con letale_vasche spento lei esce e non prende nemmeno chi è rimasto nell'acqua;
## - chi resta nell'acqua viene preso, anche nell'angolo più lontano dall'uscita (l'ultima prova: la morte).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_torre_vasche_lei.gd

const TORRE := "res://scenes/sala/torre/sala_torre.tscn"

var ok := 0
var falliti := 0
var torre: SalaTorre
var g: Player
var _t := 0.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	torre = (load(TORRE) as PackedScene).instantiate() as SalaTorre
	# (finché il modo MANO non c'è nel motore, lei nelle vasche la accendono solo i test, col segnaposto intero)
	torre.lei_vasche = true
	torre.vasche_modo = AcquaDiLei.Modo.INTERA
	add_child(torre)
	g = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(g)
	for i in 10:
		await _passo()
	GameState.player = g
	g.input_enabled = true
	_controlla(torre.acque_vasche.size() == (torre.dati.get("raccolta", []) as Array).size() and torre.acque_vasche.size() > 0,
			"una lei per vasca di raccolta", ["%d vasche con lei" % torre.acque_vasche.size()])
	# 1) per ogni vasca: caduto dentro la chiama, la luce viene dal pozzo, lei esce dopo l'avviso; risalito in tempo è salvo
	for k in torre.acque_vasche.size():
		var voce: Array = torre.acque_vasche[k]
		var a := voce[0] as AcquaDiLei
		await _calma(a)
		_nell_acqua(voce)
		var t0 := _t
		while a.fase == AcquaDiLei.Fase.LONTANA and _t - t0 < 2.0:
			await _passo()
		var arriva := a.fase == AcquaDiLei.Fase.ARRIVA
		var da := a.punto_luce
		var pozzo := SalaTorre.b(torre.dati["pozzo"])
		var dal_pozzo := Vector2(da.x - pozzo.x, da.z - pozzo.z).length() < 1.5
		# sale la scaletta e arriva sulla pedana dopo 3 s
		while _t - t0 < 3.0:
			await _passo()
		_sulla_pedana(voce)
		var esce := -1.0
		var preso := false
		var letale_su := false
		while _t - t0 < torre.vasche_avviso + 6.0 and a.fase != AcquaDiLei.Fase.CALMA:
			await _passo()
			if esce < 0.0 and a.fase == AcquaDiLei.Fase.ESCE:
				esce = _t - t0
			preso = preso or a.fase == AcquaDiLei.Fase.PRESA
			letale_su = letale_su or (a.fase == AcquaDiLei.Fase.SU and a.letale)
		_controlla(arriva and dal_pozzo and esce >= torre.vasche_avviso - 0.2 and esce <= torre.vasche_avviso + 0.5,
				"vasca %d: caduto dentro, la luce arriva dal pozzo e lei esce dopo %.0f s" % [k, torre.vasche_avviso],
				["arriva %s, la luce parte a %.1f m dal pozzo, esce dopo %.2f s" % [arriva, Vector2(da.x - pozzo.x, da.z - pozzo.z).length(), esce]])
		_controlla(not preso and not GameState.is_dying and not letale_su, "vasca %d: chi sale la scaletta in tempo è salvo" % k,
				["preso %s, lei poteva prendere %s" % [preso, letale_su]])
		# (anche a meno di 3 m in pianta, la portata di lei: sulla pedana non è nella vasca; sulla scaletta in basso sì)
		var u := voce[1] as Marker3D
		var sopra := Vector3(u.global_position.x + 1.0, float(voce[4]) + 0.1, u.global_position.z)
		var scala_bassa := Vector3(u.global_position.x + 1.0, float(voce[4]) - 2.0, u.global_position.z)
		_controlla(not torre.in_vasca(sopra, voce) and torre.in_vasca(scala_bassa, voce),
				"vasca %d: alla quota della pedana si è fuori dalla vasca, a metà scaletta ancora dentro" % k,
				["pedana %s, metà scaletta %s" % [torre.in_vasca(sopra, voce), torre.in_vasca(scala_bassa, voce)]])
	# 2) letale spento: resta nell'acqua e non è preso
	var voce0: Array = torre.acque_vasche[1]
	var a0 := voce0[0] as AcquaDiLei
	await _calma(a0)
	torre.letale_vasche = false
	_nell_acqua(voce0)
	var su := false
	var preso0 := false
	var t1 := _t
	while _t - t1 < torre.vasche_avviso + 6.0 and a0.fase != AcquaDiLei.Fase.CALMA:
		await _passo()
		_nell_acqua(voce0, false)
		su = su or a0.fase == AcquaDiLei.Fase.SU
		preso0 = preso0 or a0.fase == AcquaDiLei.Fase.PRESA
	_controlla(su and not preso0 and not GameState.is_dying, "con letale_vasche spento lei esce e non prende",
			["su %s, preso %s" % [su, preso0]])
	torre.letale_vasche = true
	# 3) nell'angolo più lontano dall'uscita e dalla scaletta, fermo lì: preso lo stesso, dopo l'avviso (niente angoli
	# sicuri; la presa uccide: è l'ultima prova)
	var voce2: Array = torre.acque_vasche[torre.acque_vasche.size() - 1]
	var a2 := voce2[0] as AcquaDiLei
	await _calma(a2)
	var angolo := _angolo(voce2)
	g.teleport(angolo, g.yaw)
	var t3 := _t
	var preso2 := false
	while _t - t3 < torre.vasche_avviso + 6.0 and not preso2:
		await _passo()
		if not GameState.is_dying and g.global_position.distance_to(angolo) > 0.5:
			g.teleport(angolo, g.yaw)
		preso2 = a2.fase == AcquaDiLei.Fase.PRESA and GameState.is_dying
	var u2 := voce2[1] as Marker3D
	var lontano := Vector2(angolo.x - u2.global_position.x, angolo.z - u2.global_position.z).length()
	_controlla(preso2 and _t - t3 >= torre.vasche_avviso and lontano > 3.0,
			"nell'angolo più lontano della vasca (a %.1f m in pianta dall'uscita) chi resta viene preso, dopo l'avviso" % Vector2(angolo.x - u2.global_position.x, angolo.z - u2.global_position.z).length(),
			["preso %s dopo %.1f s, portata %.1f m" % [preso2, _t - t3, a2.portata]])
	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


## L'angolo della vasca [param voce] più lontano dalla scaletta, 30 cm dentro i bordi (oltre i 3 m in pianta
## dall'uscita, la portata di base del motore).
func _angolo(voce: Array) -> Vector3:
	var rett := (voce[2] as Rect2).grow(-0.3)
	var u := voce[1] as Marker3D
	var sc := torre.get_node_or_null("ScalaRaccolta%d" % torre.acque_vasche.find(voce)) as Node3D
	var meglio := Vector3.ZERO
	var d := -1.0
	for c: Vector2 in [rett.position, rett.position + Vector2(rett.size.x, 0), rett.position + Vector2(0, rett.size.y), rett.end]:
		var dd := 0.0 if sc == null else c.distance_to(Vector2(sc.global_position.x, sc.global_position.z))
		if dd > d:
			d = dd
			meglio = Vector3(c.x, u.global_position.y - 0.3, c.y)
	return meglio


## Aspetta che [param a] sia di nuovo lontana (dopo la calma), e che lei sia libera.
func _calma(a: AcquaDiLei) -> void:
	_sulla_pedana(torre.acque_vasche[0])
	var t0 := _t
	while a.fase != AcquaDiLei.Fase.LONTANA and _t - t0 < 30.0:
		await _passo()
	for voce in torre.acque_vasche:
		while (voce[0] as AcquaDiLei).fase != AcquaDiLei.Fase.LONTANA and _t - t0 < 30.0:
			await _passo()


## Il giocatore nell'acqua della vasca [param voce], vicino al bordo della scaletta (a 1 m dal centro).
func _nell_acqua(voce: Array, sposta := true) -> void:
	var u := voce[1] as Marker3D
	var pos := u.global_position + Vector3(0.6, -0.3, 0.6)
	if sposta or g.global_position.distance_to(pos) > 0.8:
		g.teleport(pos, g.yaw)


## Il giocatore sulla pedana sopra la scaletta della vasca [param voce] (la quota della pedana, accanto all'uscita in
## pianta: in pianta lei è a meno di 3 m).
func _sulla_pedana(voce: Array) -> void:
	var u := voce[1] as Marker3D
	var rett := voce[2] as Rect2
	var y := float(voce[4]) + 0.1
	# (sopra il bordo della vasca, sul lato della scaletta: il punto del rettangolo più vicino alla scaletta)
	var sc := torre.get_node_or_null("ScalaRaccolta%d" % torre.acque_vasche.find(voce)) as Node3D
	var p := Vector3(u.global_position.x, y, u.global_position.z)
	if sc:
		p = Vector3(sc.global_position.x, y, sc.global_position.z) - sc.global_basis.z * 0.6
	g.teleport(p, g.yaw)
	print("    sulla pedana a %.1f m in pianta dall'uscita (rettangolo %s)" % [Vector2(p.x - u.global_position.x, p.z - u.global_position.z).length(), rett])


func _passo() -> float:
	await get_tree().physics_frame
	_t += get_physics_process_delta_time()
	return get_physics_process_delta_time()


func _controlla(cond: bool, cosa: String, dove: Array) -> void:
	if cond:
		ok += 1
		print("  ok      ", cosa)
	else:
		falliti += 1
		print("  FALLITO ", cosa, ": ", dove)
