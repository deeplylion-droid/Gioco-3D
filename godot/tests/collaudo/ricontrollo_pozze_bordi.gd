extends Node
## Ricontrollo di ambienti-2 della stanza delle pozze con lei (LeiPozze + AcquaDiLei, candidata 0.4.0): la logica nei casi
## di bordo, nella stanza grigia di prova col giocatore vero e il motore vero (pause corte come in test_pozze_lei):
## A. svuotare il colore della sua pozza mentre la luce arriva, nel silenzio, mentre esce e mentre è fuori: la manda
##    via senza prendere, e poi tutto riparte (lei torna a girare e a venire);
## B. l'enigma risolto mentre lei è fuori: se ne va (FINITA), non prende, la luce non torna, la porta è aperta;
## C. il giocatore sceso in una pozza vuota accanto alla sua mentre lei arriva: cosa succede (la presa conta solo la
##    distanza in pianta dal punto d'uscita);
## D. il giocatore esce dalla stanza mentre lei è fuori e poi rientra: niente presa fuori, lei torna sotto, mentre è
##    fuori non la chiama, rientrato torna a venire.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/ricontrollo_pozze_bordi.gd

const PLAYER := "res://scenes/player/player.tscn"
const STANZA := preload("res://tests/pozze/stanza_prova.gd")
const F := AcquaDiLei.Fase
## La linea di mezzo della passerella (m dal centro della griglia).
var r := 0.0

var p: Player
var e: EnigmaPozze
var lei: LeiPozze
var acqua: AcquaDiLei
## Le fasi del motore: [fase, fotogramma di fisica].
var fasi: Array = []
## La camera del giocatore com'era (la scena della morte della medusa la porta davanti al viso di lei).
var _camera := Transform3D.IDENTITY
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		print("  FALLITO ", what)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(3)
	_camera = p.camera.transform

	var solo := OS.get_environment("SOLO")
	if solo == "" or "A" in solo:
		print("A. Svuotare il colore della sua pozza nelle fasi dell'uscita")
		for f in [F.ARRIVA, F.SILENZIO, F.ESCE, F.SU]:
			await _svuota_in(f)
	if solo == "" or "B" in solo:
		print("B. L'enigma risolto mentre lei è fuori")
		await _risolto_mentre_fuori()
	if solo == "" or "C" in solo:
		print("C. Il giocatore in una pozza vuota accanto alla sua")
		await _in_pozza_vuota()
	if solo == "" or "D" in solo:
		print("D. Fuori dalla stanza mentre lei è fuori, e dentro di nuovo")
		await _esce_e_rientra()
	_fine()


## Una stanza nuova con un colore tolto e lei sveglia (non dimostrativa), il giocatore sulla passerella sud a
## [param di_lato] m e a [param fuori] m dal bordo: aspetta che arrivi. Ritorna la pozza dove viene (o null).
func _pronta(di_lato := 0.0, fuori := 0.0) -> WaterTank:
	await _nuova_stanza(false)
	await _togli(WaterMix.ROSA)
	lei._t = -0.3
	# (nell'angolo della passerella: lì la mano non arriva, 1,4 m dal punto più vicino)
	_metti(Vector3(r, 0, r))
	var a := await _aspetta(F.ARRIVA, 10.0)
	if a.is_empty():
		check(false, "lei arriva (%s, motore %s)" % [lei.nome_fase(), acqua.fase])
		return null
	return lei.bersaglio


## A: arriva lontano dal giocatore (fuori portata, così si vede cosa fa lei senza la presa), e a fase [param f] il colore
## della sua pozza comincia a svuotarsi (EnigmaPozze._comincia, come quando l'aspirazione supera la soglia).
func _svuota_in(f: F) -> void:
	var t := await _pronta(0.0, 0.9)
	if t == null:
		return
	if f != F.ARRIVA:
		var x := await _aspetta(f, acqua.avviso + 3.0)
		if x.is_empty():
			check(false, "%s: lei arriva alla fase %s" % [F.keys()[f], F.keys()[f]])
			return
	await _frames(6)
	var c := String(t.fill_pigment)
	var uscite := lei.uscite
	var cacciate := lei.cacciate
	var t0 := Engine.get_physics_frames()
	var da := fasi.size()
	e._comincia(c)
	# le fasi del motore nei 6 s dopo: se esce, quando torna sotto (SCENDE), e quando torna ad arrivare
	var bersagli: Array = []
	for i in 60 * 6:
		await get_tree().physics_frame
		if acqua.fase == F.ARRIVA and lei.bersaglio and not lei.bersaglio in bersagli:
			bersagli.append(lei.bersaglio)
	var dopo: Array = []
	var scende := -1.0
	var esce_dopo := false
	for k in range(da, fasi.size()):
		dopo.append(F.keys()[fasi[k][0]])
		if fasi[k][0] == F.SCENDE and scende < 0.0:
			scende = (fasi[k][1] - t0) / 60.0
		if fasi[k][0] == F.ESCE:
			esce_dopo = true
	var fuori := f in [F.ESCE, F.SU]
	check(lei.cacciate == cacciate + 1 and lei.prese == 0 and not GameState.is_dying,
		"svuotando il %s nella fase %s: cacciata, nessuna presa (fasi dopo: %s)" % [c, F.keys()[f], dopo])
	if not fuori:
		check(not esce_dopo or lei.bersaglio == null or String(lei.bersaglio.fill_pigment) != c, "  e da lì non esce (uscite %d)" % (lei.uscite - uscite))
	else:
		check(scende >= 0.0 and scende < 0.5, "  già fuori, torna sotto subito (dopo %.2f s; tempo su %.1f)" % [scende, acqua.tempo_su])
	check(bersagli.all(func(u): return String(u.fill_pigment) != c), "  e non torna a una pozza %s (torna a %s)" % [c, bersagli.map(func(u): return String(u.fill_pigment))])
	await _aspetta_tolto(c, 10.0)
	check(c in e.tolti, "  il %s si svuota del tutto" % c)
	if bersagli.is_empty():
		lei._t = maxf(lei._t, -0.3)
		_metti(Vector3(r, 0, r))
		var a := await _aspetta(F.ARRIVA, 15.0)
		check(not a.is_empty() and lei.bersaglio != null and String(lei.bersaglio.fill_pigment) != c,
			"  poi torna a venire, da una pozza ancora piena (%s)" % (String(lei.bersaglio.fill_pigment) if lei.bersaglio else "nessuna"))
	await _aspetta_calma()


## B: tolti due colori giusti, lei esce; mentre è su, il terzo giusto finisce di svuotarsi (risolto).
func _risolto_mentre_fuori() -> void:
	await _nuova_stanza(false)
	lei.letale = true
	await _togli(EnigmaPozze.GIUSTI[0])
	await _togli(EnigmaPozze.GIUSTI[1])
	var terzo := String(EnigmaPozze.GIUSTI[2])
	for prova in 4:
		lei._t = maxf(lei._t, -0.3)
		# (un angolo diverso a ogni prova: da uno di loro la pozza più vicina non è del terzo colore)
		_metti(Vector3(r if prova % 2 == 0 else -r, 0, r if prova < 2 else -r))
		var a := await _aspetta(F.ARRIVA, 12.0)
		if a.is_empty():
			check(false, "lei arriva")
			return
		if String(lei.bersaglio.fill_pigment) == terzo:
			# (viene proprio dal terzo colore: è il caso A; si riprova)
			await _aspetta_calma()
			continue
		var su := await _aspetta(F.SU, acqua.avviso + 4.0)
		if su.is_empty():
			check(false, "lei esce")
			return
		await _frames(10)
		e._comincia(terzo)
		for u: WaterTank in e.pozze_del_colore(terzo):
			u.fill = 0.0
		await _frames(3)
		check(e.stato == EnigmaPozze.Stato.RISOLTO, "il terzo colore giusto finisce mentre lei è su: risolto")
		check(lei.fase == LeiPozze.Fase.FINITA and not acqua.abilitata, "lei se ne va (%s)" % lei.nome_fase())
		var presa := false
		for i in 60 * 6:
			await get_tree().physics_frame
			presa = presa or GameState.is_dying
		check(not presa and lei.prese == 0 and acqua.fase == F.LONTANA, "torna sotto senza prendere (motore %s)" % F.keys()[acqua.fase])
		var n := fasi.size()
		await _secondi(6.0)
		check(fasi.size() == n and not acqua.in_giro() and not _luce_accesa(), "e non torna più, la luce non c'è")
		check(_porta().aperta, "la porta stagna è aperta")
		return
	check(false, "lei viene sempre dal terzo colore: caso B non provato")


## C: lei arriva alla pozza piena del bordo accanto a una pozza vuota; il giocatore scende nella pozza vuota, vicino al
## punto d'uscita della mano (entro la sua portata in pianta).
func _in_pozza_vuota() -> void:
	await _nuova_stanza(false)
	await _togli(WaterMix.ROSA)
	var vuote := e.pozze_del_colore(WaterMix.ROSA).filter(func(u): return lei._sul_bordo(u))
	var coppia: Array = []
	for v: WaterTank in vuote:
		for u in lei._vicine(v):
			if lei._sul_bordo(u) and lei._piena(u):
				coppia = [v, u]
				break
		if not coppia.is_empty():
			break
	if coppia.is_empty():
		check(false, "c'è una pozza rosa vuota del bordo accanto a una piena")
		return
	var vuota: WaterTank = coppia[0]
	var piena: WaterTank = coppia[1]
	# il giocatore sulla passerella davanti alla pozza piena: lei viene lì
	var m: Marker3D = lei.uscita_di(piena)
	p.teleport(m.global_position + m.global_basis.z * 0.9 + Vector3(0, 0.05, 0), p.yaw, 0.0)
	lei._t = -0.3
	var a := await _aspetta(F.ARRIVA, 10.0)
	if a.is_empty() or lei.bersaglio != piena:
		print("  (lei viene alla pozza %s, non %s)" % [lei.bersaglio.name if lei.bersaglio else "nessuna", piena.name])
		if a.is_empty() or lei.bersaglio == null:
			check(false, "lei arriva")
			return
		piena = lei.bersaglio
		m = lei.uscita_scelta
	# giù nella pozza vuota, sul fondo, nel punto più vicino all'uscita della mano
	var q := vuota.to_local(m.global_position)
	var mezzo := vuota.inner_size * 0.5
	q.x = clampf(q.x, -mezzo.x + 0.3, mezzo.x - 0.3)
	q.z = clampf(q.z, -mezzo.z + 0.3, mezzo.z - 0.3)
	q.y = 0.05
	var giu := vuota.to_global(q)
	p.teleport(giu, p.yaw, 0.0)
	await _frames(5)
	var d := _in_pianta(p.global_position, m.global_position)
	print("  (nella pozza %s vuota, a %.2f m in pianta dalla mano e %.2f m sotto il grigliato; portata della mano %.1f m)" % [
			vuota.name, d, m.global_position.y - p.global_position.y, acqua.portata_mano])
	var esito := ""
	for i in 60 * 10:
		await get_tree().physics_frame
		if GameState.is_dying:
			esito = "preso (%s)" % GameState.last_death_cause
			break
		if acqua.fase == F.CALMA:
			esito = "non preso"
			break
	print("  ESITO C: %s; uscite %d, prese %d" % [esito, lei.uscite, lei.prese])
	check(esito != "", "nella pozza vuota accanto la sequenza finisce (%s)" % esito)
	if d <= acqua.portata_mano:
		check(not GameState.is_dying, "la mano sul grigliato non prende chi sta giù nella pozza vuota accanto (%.2f m sotto)" % (m.global_position.y - p.global_position.y))
	if GameState.is_dying:
		_rianima()


## D: lei fuori, il giocatore esce dalla stanza (dalla porta d'ingresso della stanza di prova), poi rientra.
func _esce_e_rientra() -> void:
	var t := await _pronta(0.0, 0.9)
	if t == null:
		return
	var su := await _aspetta(F.SU, acqua.avviso + 4.0)
	if su.is_empty():
		check(false, "lei esce")
		return
	# fuori dalla porta stagna finta: un corridoio col pavimento (la stanza di prova non ce l'ha)
	var corr := StaticBody3D.new()
	corr.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(3.0, 1.0, 10.0)
	cs.shape = bx
	corr.add_child(cs)
	e.get_parent().add_child(corr)
	corr.position = Vector3(0, -0.5, -(r + 0.6) - 5.0)
	await _frames(2)
	p.teleport(e.to_global(Vector3(0, 0.05, -(r + 0.6) - 6.0)), p.yaw, 0.0)
	var presa := false
	var fasi_fuori: Array = []
	var da := fasi.size()
	for i in 60 * 10:
		await get_tree().physics_frame
		presa = presa or GameState.is_dying
	for k in range(da, fasi.size()):
		fasi_fuori.append(F.keys()[fasi[k][0]])
	check(not presa and lei.prese == 0, "uscito dalla stanza mentre lei è fuori: non lo prende")
	check(not F.keys()[F.ARRIVA] in fasi_fuori, "torna sotto e, col giocatore fuori, non torna a venire (fasi %s)" % [fasi_fuori])
	check(lei.fase == LeiPozze.Fase.GIRA, "lei gira sotto le pozze (%s)" % lei.nome_fase())
	_metti(Vector3(r, 0, r))
	lei._t = maxf(lei._t, -0.3)
	var a := await _aspetta(F.ARRIVA, 12.0)
	check(not a.is_empty(), "rientrato, lei torna a venire")
	await _aspetta_calma()


func _aspetta_calma() -> void:
	for i in 60 * 14:
		if acqua.fase == F.LONTANA and not GameState.is_dying and lei.fase == LeiPozze.Fase.GIRA:
			return
		if GameState.is_dying:
			_rianima()
			return
		await get_tree().physics_frame


func _fine() -> void:
	Input.action_release(&"spray")
	Input.action_release(&"suck")
	Input.action_release(&"move_forward")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- La stanza ------------------------------------------------------------------------------

## Una stanza nuova (lei com'era all'inizio della partita se [param dimostrativa], se no la prima volta è già passata).
func _nuova_stanza(dimostrativa := true) -> void:
	var vecchia := get_node_or_null(^"StanzaPozzeProva")
	if vecchia:
		vecchia.name = "Vecchia"
		vecchia.queue_free()
		await _frames(2)
	if GameState.is_dying:
		_rianima()
	e = STANZA.costruisci(self)
	r = e.passo * 2.5 + 0.6
	lei = e.lei
	acqua = lei.acqua
	acqua.prima_volta_dimostrativa = dimostrativa
	fasi = []
	acqua.fase_cambiata.connect(func(f): fasi.append([f, Engine.get_physics_frames()]))
	# (pause corte: l'avviso, la presa, la respinta e le distanze restano quelli veri)
	lei.prima_attesa = 3.0
	lei.pausa_min = 1.5
	lei.pausa_max = 1.5
	acqua.pausa_dopo = 1.0
	acqua.pausa_respinta = 1.0
	GameState.snapshot = {}
	p.water_pack.set_tank_amount(0.0)
	await _frames(3)


func _porta() -> Node:
	return e.get_parent().get_node(^"PortaStagna")


# --- Il giocatore ---------------------------------------------------------------------------

func _metti(locale: Vector3) -> void:
	p.teleport(e.to_global(locale) + Vector3(0, 0.05, 0), p.yaw, 0.0)


func _zaino() -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)


func _pelo(t: WaterTank) -> Vector3:
	return Vector3(t.global_position.x, t.get_surface_global_y(), t.global_position.z)


func _pelo_pieno(t: WaterTank) -> float:
	return t.to_global(Vector3(0, t.inner_size.y * e.pieno, 0)).y


## Toglie il colore [param c] come chi gioca, dalla passerella a sud: lo aspira e aspetta che le sue pozze siano vuote.
func _togli(c: String) -> void:
	_zaino()
	var t: WaterTank = null
	for u: WaterTank in e.pozze_del_colore(c):
		if t == null or u.position.z > t.position.z:
			t = u
	p.teleport(Vector3(t.global_position.x, e.global_position.y + 0.05, e.global_position.z + e.passo * 2.5 + 0.6), 0.0, 0.0)
	await _frames(3)
	p.look_at_point(_pelo(t))
	Input.action_press(&"suck")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release(&"suck")
	await _aspetta_tolto(c, 8.0)
	check(c in e.tolti, "tolto il %s" % c)


func _aspetta_tolto(c: String, secondi: float) -> void:
	for i in int(secondi * 60.0):
		if c in e.tolti:
			return
		await get_tree().physics_frame


## Cammina (col tasto avanti) lungo la passerella fino a [param d] m dal punto d'uscita della pozza [param t].
func _cammina_via(t: WaterTank, d: float) -> void:
	var meta := _punto_lontano(t, d + 0.3)
	p.look_at_point(meta + Vector3(0, 1.5, 0))
	p.pitch = 0.0
	Input.action_press(&"move_forward")
	for i in 60 * 3:
		await get_tree().physics_frame
		if _dist_uscita(t) >= d:
			break
		p.look_at_point(meta + Vector3(0, 1.5, 0))
	Input.action_release(&"move_forward")


## Il punto della linea di mezzo della passerella, a più di [param d] m dalla pozza [param t], più vicino al giocatore.
func _punto_lontano(t: WaterTank, d: float) -> Vector3:
	var migliore := Vector3.ZERO
	var dm := INF
	var s := 0.0
	while s < 8.0 * r:
		var q := LeiPozze._anello_punto(s, r)
		var g := e.to_global(Vector3(q.x, 0.0, q.y))
		var dg := _in_pianta(g, lei.uscita_scelta.global_position) if lei.uscita_scelta else lei._distanza_punto(g, t)
		if dg > d:
			var dd := g.distance_to(p.global_position)
			if dd < dm:
				dm = dd
				migliore = g
		s += 0.1
	return migliore


## Dopo una presa vera (kill_player): la scena della morte si toglie prima che finisca (la ripartenza ricaricherebbe la
## scena del test) e il giocatore torna quello di prima, con la camera al suo posto. Il motore resta nella presa: la
## stanza va rifatta.
func _rianima() -> void:
	var seq: Node = GameState.get(&"_death_sequence")
	if is_instance_valid(seq):
		seq.free()
	p.camera.transform = _camera
	GameState.is_dying = false
	GameState.player = p
	p.input_enabled = true


# --- Attese e controlli ---------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secondi(s: float) -> void:
	await _frames(int(s * 60.0))


## Aspetta la prossima fase [param f] del motore (al più [param secondi]); ritorna [fase, fotogramma], o [] se non arriva.
func _aspetta(f: F, secondi: float) -> Array:
	var da := fasi.size()
	for i in int(secondi * 60.0):
		for k in range(da, fasi.size()):
			if fasi[k][0] == f:
				return fasi[k]
		await get_tree().physics_frame
	for k in range(da, fasi.size()):
		if fasi[k][0] == f:
			return fasi[k]
	return []


## Segue la luce del giro fino alla fase [param f] del motore (al più [param secondi]): le pozze sotto cui passa (in
## ordine), se sono una accanto all'altra, la vicinanza più alta, l'energia più bassa dopo il primo secondo e quante volte
## salta (più di 0,5 m in un fotogramma).
func _segui_luce(f: F, secondi: float) -> Dictionary:
	var out := {"arrivo": [], "pozze": [], "di_fila": true, "vicinanza": 0.0, "energia_min": INF, "energia_centro_min": INF,
			"salti": 0, "in_giro": false, "fuori_max": 0.0}
	var da := fasi.size()
	var prima := Vector3.INF
	var t0 := Engine.get_physics_frames()
	for i in int(secondi * 60.0):
		for k in range(da, fasi.size()):
			if fasi[k][0] == f:
				out["arrivo"] = fasi[k]
		if not (out["arrivo"] as Array).is_empty():
			break
		await get_tree().physics_frame
		if not acqua.in_giro() or not _luce_accesa():
			# (spenta fra due pozze: il salto si misura solo fra due istanti accesi di fila)
			prima = Vector3.INF
			continue
		out["in_giro"] = true
		var q := acqua.punto_luce
		if prima != Vector3.INF and _in_pianta(q, prima) > 0.5:
			out["salti"] += 1
		prima = q
		out["vicinanza"] = maxf(out["vicinanza"], acqua.vicinanza)
		var en: float = AcquaDiLei._luce.light_energy / AcquaDiLei.LUCE_SOTTO
		if Engine.get_physics_frames() - t0 > 90:
			out["energia_min"] = minf(out["energia_min"], en)
		# sotto un bordino (la striscia di 10 cm fra due pozze): quanto è accesa lì
		var dentro := false
		for u in e.pozze():
			var dq := e.global_basis.inverse() * (q - u.global_position)
			if absf(dq.x) < 0.5 and absf(dq.z) < 0.5:
				dentro = true
		if not dentro:
			out["fuori_max"] = maxf(out["fuori_max"], en)
		for u in e.pozze():
			if _in_pianta(u.global_position, q) < 0.15 and Engine.get_physics_frames() - t0 > 90:
				out["energia_centro_min"] = minf(out["energia_centro_min"], en)
			if _in_pianta(u.global_position, q) < 0.15:
				var viste: Array = out["pozze"]
				if viste.is_empty() or viste.back() != u:
					if not viste.is_empty() and not (u in lei._vicine(viste.back())):
						out["di_fila"] = false
					viste.append(u)
	return out


## L'estinzione più bassa dei tre canali (1/m) del liquido della pozza [param t] adesso (dal materiale), e quella del
## suo stile.
func _estinzione(t: WaterTank) -> float:
	var b := t.get_node(^"Acqua") as WaterBody
	var ab: Vector3 = b.material.get_shader_parameter(&"absorption")
	var tu: float = b.material.get_shader_parameter(&"turbidity")
	return minf(minf(ab.x, ab.y), ab.z) + tu


func _estinzione_stile(t: WaterTank) -> float:
	var st: WaterStyle = (t.get_node(^"Acqua") as WaterBody).style
	return minf(minf(st.absorption.x, st.absorption.y), st.absorption.z) + st.turbidity


## In pianta, dal giocatore al punto d'uscita dove sta venendo lei (o, senza, a quello più vicino della pozza [param t]).
func _dist_uscita(t: WaterTank = null) -> float:
	if lei.uscita_scelta:
		return _in_pianta(p.global_position, lei.uscita_scelta.global_position)
	return lei._distanza(p, t) if t else INF


func _luce_accesa() -> bool:
	var l := AcquaDiLei._luce
	return l != null and is_instance_valid(l) and l.visible and l.light_energy > 0.05


func _aspetta_lontana(secondi: float) -> void:
	for i in int(secondi * 60.0):
		if acqua.fase == F.LONTANA:
			return
		await get_tree().physics_frame


static func _in_pianta(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## La pozza piena del bordo più vicina al giocatore.
func _piu_vicina() -> WaterTank:
	var migliore: WaterTank
	var dm := INF
	for t in lei._pozze_buone():
		var d := lei._distanza(p, t)
		if d < dm:
			dm = d
			migliore = t
	return migliore


func _ce_ne_e_una_in_vista() -> bool:
	for t in lei._pozze_buone():
		if lei._distanza(p, t) >= lei.distanza_dimostrativa and lei._la_vede(p, t):
			return true
	return false


func _sotto_pozza_piena(pos: Vector3) -> bool:
	for t in e.pozze():
		if _in_pianta(t.global_position, pos) < 0.1:
			return lei._piena(t)
	return false
