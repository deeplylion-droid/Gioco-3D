extends Node
## Ricontrollo incrociato della sala al buio di mascotte (LeiSalaAlBuio: il giro della luce rosa nelle vasche, poi la
## fossa), di ambienti-1 sulla prova d'insieme della 0.4.0 (15 novembre). Sulla sala vera, senza schermo, dalle
## partenze e dalle riprese (GameState.prepara_ripresa, come Continua e il menu F9):
## A. Continua dalla serranda: al checkpoint il giro non parte, 4 m dentro la sala parte; rientrando nel magazzino a
##    metà giro lei se ne va (nessuno specchio la tiene), tornando dentro il giro riparte;
## B. arrivo alla fossa senza passare dal bordo: il giro finisce, la luce va alla fossa e lei si affaccia; la sala si
##    spegne;
## C. morte sul bordo (lei chiamata al punto d'uscita lì vicino) e ripartenza: di nuovo alla serranda, il giro riparte
##    entrando;
## D. Continua dall'area bimbi (prima della fossa): cosa succede (lei alla fossa, niente giro);
## E. Continua dalla spiaggia al buio, dopo la fossa: niente giro;
## F. partenza F9 «Torre» (dopo la fossa): niente giro;
## e alla fine nel registro nessun errore (soprattutto «previously freed»).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/ricontrollo/ricontrollo_sala_buio.gd [A,B,...]

const GIRO := "Gioco/LeiSalaAlBuio"
const SBUCA := "Gioco/LeiSbuca"

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var solo := PackedStringArray()
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		solo = args[1].split(",")
	var buio := MenuProva.istantanea("sala_buio")
	var torre := MenuProva.istantanea("torre")
	for caso in ["A", "B", "C", "D", "E", "F"]:
		if not solo.is_empty() and not caso in solo:
			continue
		print("== ", caso)
		match caso:
			"A": await _caso_a(buio)
			"B": await _caso_b(buio)
			"C": await _caso_c(buio)
			"D": await _caso_d(buio)
			"E": await _caso_e(torre)
			"F": await _caso_f(torre)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _caso_a(d: Dictionary) -> void:
	var lv := await _parti(d)
	var g := lv.get_node_or_null(GIRO)
	var p := GameState.player
	await _fisica(30)
	_check(int(g.stato) == 0, "A: Continua dalla serranda, al checkpoint il giro non parte (stato %d)" % g.stato)
	var da := p.global_position
	await _metti(da + Vector3(0, 0, -4))
	await _fisica(20)
	_check(int(g.stato) == 1 and g.acqua.in_giro(), "A: 4 m dentro la sala il giro parte (stato %d)" % g.stato)
	await _fisica(120)
	# di nuovo nel magazzino, oltre la serranda
	await _metti(da + Vector3(0, 0, 3))
	await _fisica(30)
	_check(int(g.stato) == 0 and not g.acqua.in_giro() and AcquaDiLei.chi_la_usa() != g.acqua,
			"A: rientrato nel magazzino a metà giro, lei se ne va e nessuno la tiene (stato %d, usa %s)" % [g.stato, AcquaDiLei.chi_la_usa()])
	await _metti(da + Vector3(0, 0, -4))
	await _fisica(30)
	_check(int(g.stato) == 1, "A: tornato dentro, il giro riparte (stato %d)" % g.stato)


func _caso_b(d: Dictionary) -> void:
	var lv := await _parti(d)
	var g := lv.get_node_or_null(GIRO)
	var s := lv.get_node_or_null(SBUCA) as LeiSbuca
	var p := GameState.player
	await _metti(p.global_position + Vector3(0, 0, -4))
	await _fisica(30)
	_check(int(g.stato) == 1, "B: il giro è partito")
	# vicino alla fossa (entro distanza_fossa), lontano dai punti d'uscita della vasca grande
	var fossa := s.punto_sbuca.global_position
	var dove := Vector3.INF
	for dx in [-6.0, -4.0, 0.0, 4.0, 6.0]:
		for dz in [-6.0, -4.0, 0.0, 4.0, 6.0]:
			var q := Vector3(fossa.x + dx, 0.05, fossa.z + dz)
			var dist := Vector2(dx, dz).length()
			var vicino: bool = dist <= float(g.distanza_fossa) - 1.0 and dist >= 3.0
			if vicino and not _vicino_ai_punti(g, q) and dove == Vector3.INF:
				dove = q
	_check(dove != Vector3.INF, "B: c'è un posto vicino alla fossa lontano dal bordo (%s)" % dove)
	if dove == Vector3.INF:
		return
	# (aspetta che lei sia lontana: alla fossa si va solo da LONTANA)
	for i in 600:
		if g.acqua.fase == AcquaDiLei.Fase.LONTANA:
			break
		await get_tree().physics_frame
	await _metti(dove)
	await _fisica(20)
	_check(int(g.stato) == 2, "B: arrivato alla fossa senza passare dal bordo, il giro finisce (stato %d)" % g.stato)
	await _secondi(2.5)
	_check(s.fase != LeiSbuca.Fase.ATTESA, "B: la luce è andata alla fossa e lei si affaccia (fase %d)" % s.fase)
	_check(not g.acqua.abilitata and not g.acqua.in_giro(), "B: la sala al buio si spegne")


func _caso_c(d: Dictionary) -> void:
	var lv := await _parti(d)
	var g := lv.get_node_or_null(GIRO)
	var p := GameState.player
	var spawn := p.global_position
	await _metti(spawn + Vector3(0, 0, -4))
	await _fisica(30)
	# sul bordo della vasca grande, davanti al punto d'uscita più vicino, e lei chiamata lì
	var q := _punto_vicino(g, p.global_position)
	var bordo := _sul_bordo_di(g, q)
	g.acqua.smetti_giro(q.global_position + Vector3.DOWN * 0.6, 0.2)
	await _fisica(30)
	await _metti(bordo)
	await _fisica(5)
	var chiamata := bool(g.acqua.chiama(q))
	var morto := false
	for i in 60 * 12:
		await get_tree().physics_frame
		if GameState.is_dying:
			morto = true
			break
	_check(chiamata and morto, "C: sul bordo, lei chiamata al punto lì vicino esce e prende (chiamata %s, morto %s, bordo %s, fase %d)"
			% [chiamata, morto, bordo, g.acqua.fase])
	if not morto:
		GameState.kill_player(&"medusa")
	await _aspetta_ripresa(true)
	lv = get_tree().current_scene
	g = lv.get_node_or_null(GIRO)
	p = GameState.player
	_check(p != null and p.global_position.distance_to(spawn) < 1.5, "C: ripartito alla serranda")
	await _fisica(30)
	_check(g != null and int(g.stato) == 0, "C: dopo la morte il giro aspetta")
	if p and g:
		await _metti(spawn + Vector3(0, 0, -4))
		await _fisica(30)
		_check(int(g.stato) == 1, "C: entrando riparte (stato %d)" % g.stato)


func _caso_d(d: Dictionary) -> void:
	var dd := d.duplicate(true)
	dd["checkpoint"] = "Gioco/CheckpointAreaBimbi"
	dd["order"] = 17
	dd["player"]["position"] = [-18.3, 0.05, -0.5]
	var lv := await _parti(dd)
	var g := lv.get_node_or_null(GIRO)
	var s := lv.get_node_or_null(SBUCA) as LeiSbuca
	await _secondi(3.0)
	print("    dall'area bimbi: a %.1f m dalla fossa, giro stato %d, fossa fase %d" % [
			AcquaDiLei._in_pianta(GameState.player.global_position, s.punto_sbuca.global_position), g.stato, s.fase])
	_check(int(g.stato) != 1 and s.fase != LeiSbuca.Fase.ATTESA,
			"D: Continua dall'area bimbi, niente giro e lei va alla fossa (stato %d, fase %d)" % [g.stato, s.fase])


func _caso_e(d: Dictionary) -> void:
	var dd := d.duplicate(true)
	dd["checkpoint"] = "Gioco/CheckpointSpiaggiaBuio"
	dd["order"] = 18
	dd["player"]["position"] = [2.0, 0.05, -12.6]
	var lv := await _parti(dd)
	await _dopo_la_fossa(lv, "E: Continua dalla spiaggia al buio (dopo la fossa)")


func _caso_f(d: Dictionary) -> void:
	var lv := await _parti(d)
	await _dopo_la_fossa(lv, "F: partenza F9 «Torre» (dopo la fossa)")


func _dopo_la_fossa(lv: Node, cosa: String) -> void:
	var g := lv.get_node_or_null(GIRO)
	var s := lv.get_node_or_null(SBUCA) as LeiSbuca
	_check(s != null and s.fase == LeiSbuca.Fase.FINITA, "%s: la fossa è finita (fase %s)" % [cosa, s.fase if s else "-"])
	var giro := false
	var canto := false
	for i in 60 * 6:
		await get_tree().physics_frame
		giro = giro or (g != null and (int(g.stato) == 1 or g.acqua.in_giro()))
		var cp: Variant = Audio.get(&"canto_prima")
		canto = canto or (cp != null and cp.canta() and cp.lei == g.acqua)
	_check(not giro and not canto, "%s: niente giro della luce e niente canto dalla sala (giro %s, canto %s, a %s, in sala %s)"
			% [cosa, giro, canto, GameState.player.global_position, g.zona.has_point(GameState.player.global_position) if g else "-"])


# --- aiuti ---

func _parti(d: Dictionary) -> Node:
	GameState.prepara_ripresa(d.duplicate(true))
	get_tree().change_scene_to_file(MenuProva.SCENA_CARICAMENTO)
	await _aspetta_ripresa(false)
	return get_tree().current_scene


func _aspetta_ripresa(da_morte: bool) -> void:
	var t0 := Time.get_ticks_msec()
	if da_morte:
		while GameState.player != null and Time.get_ticks_msec() - t0 < 60000:
			await get_tree().process_frame
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and GameState.player \
				and is_instance_valid(GameState.player) and not GameState.is_restoring() and not GameState.is_dying:
			break
	for i in 30:
		await get_tree().process_frame


func _metti(pos: Vector3) -> void:
	for i in 3:
		GameState.player.teleport(pos)
		await get_tree().physics_frame


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secondi(s: float) -> void:
	await _fisica(int(s * 60.0))


func _vicino_ai_punti(g: Node, q: Vector3) -> bool:
	for m in g.acqua.punti_uscita:
		if AcquaDiLei._in_pianta(q, m.global_position) <= g.distanza_bordo + 1.0:
			return true
	return false


func _punto_vicino(g: Node, da: Vector3) -> Node3D:
	var best: Node3D = null
	for m in g.acqua.punti_uscita:
		if best == null or AcquaDiLei._in_pianta(da, m.global_position) < AcquaDiLei._in_pianta(da, best.global_position):
			best = m
	return best


## Sul bordo della vasca grande davanti al punto [param q]: dal centro della vasca, oltre il muro di 0,6 m.
func _sul_bordo_di(g: Node, q: Node3D) -> Vector3:
	var v: WaterTank = g.vasca_grande
	var l := v.to_local(q.global_position)
	var mezzo := v.inner_size * 0.5
	var fuori := l
	if absf(l.x) / mezzo.x > absf(l.z) / mezzo.z:
		fuori.x = signf(l.x) * (mezzo.x + 0.6)
	else:
		fuori.z = signf(l.z) * (mezzo.z + 0.6)
	var w := v.to_global(fuori)
	return Vector3(w.x, 0.05, w.z)
