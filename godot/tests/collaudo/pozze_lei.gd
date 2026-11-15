extends Node
## Collaudo 0.4.0 (candidata), fase 2: lei nella stanza delle pozze, senza schermo, col gioco vero (F9 «Stanza delle
## pozze»), coi tempi veri. PL:. Ogni cambio di fase (LeiPozze e motore) col tempo, la pozza, il colore e la distanza dal
## giocatore; la luce: fotogrammi accesa fuori dall'acqua delle pozze; il canto (SC:).
## 1. tolto il turchese: il giro di pozza in pozza, l'uscita dimostrativa (lontana, non prende), poi fermo sulla
##    passerella: la presa alla caviglia; la morte e la ripartenza (pozze piene, lei dorme);
## 2. tolto il viola: alla prima uscita il getto sulla mano (respinta);
## 3. all'arrivo dopo: si comincia a svuotare il colore di quella pozza (cacciata);
## 4. all'arrivo dopo: ci si allontana lungo la passerella (salvo);
## 5. si toglie l'arancione: risolto, poi 30 s: lei non torna (niente luce, niente canto).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/pozze_lei.gd

var spia: Node
var e: EnigmaPozze
var p: Player
var t0 := 0
var fuori := 0
var accesa := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _t() -> float:
	return (Time.get_ticks_msec() - t0) / 1000.0


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secondi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().physics_frame


func _arriva(vecchio: int) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		var g := GameState.player
		if s and String(s.name) != "Caricamento" and g and is_instance_valid(g) and g.get_instance_id() != vecchio \
				and g.is_inside_tree() and not GameState.is_dying and not GameState.is_restoring() and g.input_enabled:
			return true
	return false


func _prendi() -> void:
	var level := get_tree().current_scene
	p = GameState.player as Player
	e = level.find_child("EnigmaPozze", true, false) as EnigmaPozze
	if e and e.lei:
		e.lei.fase_cambiata.connect(func(f): print("PL: %.2f s LeiPozze %s" % [_t(), f]))
		e.lei.cacciata.connect(func(): print("PL: %.2f s CACCIATA" % _t()))
		e.lei.acqua.fase_cambiata.connect(_su_fase)


func _su_fase(f) -> void:
	var a := e.lei.acqua
	var q: Node3D = a.get(&"_punto")
	var pozza := e.lei.call(&"_pozza_sotto", q.global_position) as WaterTank if q else null
	var col := ""
	if pozza:
		for c in EnigmaPozze.COLORI:
			if e.pozze_del_colore(c).has(pozza):
				col = c
	print("PL: %.2f s motore %s, pozza %s (%s), punto a %.2f m dal giocatore, dimostrativa %s, giocatore %s, canto %s" % [_t(), AcquaDiLei.Fase.keys()[int(f)],
			pozza.name if pozza else "-", col, AcquaDiLei._in_pianta(q.global_position, p.global_position) if q else -1.0,
			a.get(&"_dimostrativa"), p.global_position.snappedf(0.01), spia.call(&"adesso")])


func _physics_process(_d: float) -> void:
	if e == null or not is_instance_valid(e) or e.lei == null:
		return
	var l: OmniLight3D = e.lei.acqua.get(&"_luce")
	if l and is_instance_valid(l) and l.is_visible_in_tree() and l.light_energy > 0.01 and l.get_parent() == e.lei.acqua:
		accesa += 1
		var dentro := false
		for t in e.pozze():
			var loc := t.to_local(l.global_position)
			var m := t.inner_size * 0.5
			if absf(loc.x) <= m.x and absf(loc.z) <= m.z and l.global_position.y <= t.get_surface_global_y() + 0.01 and l.global_position.y >= t.get_floor_global_y() - 0.01:
				dentro = true
				break
		if not dentro:
			fuori += 1


func _davanti(x: float) -> Vector3:
	return e.to_global(Vector3(x, 0.0, e.passo * 2.5 + 0.6))


func _vai(t: Vector3, max_f := 900) -> void:
	for i in max_f:
		var d := Vector2(t.x - p.global_position.x, t.z - p.global_position.z)
		if d.length() < 0.35:
			break
		p.yaw = atan2(-d.x, -d.y)
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
	Input.action_release(&"move_forward")


func _pozza_sul_bordo(c: String) -> WaterTank:
	var m: WaterTank = null
	for t: WaterTank in e.pozze_del_colore(c):
		if m == null or t.position.z > m.position.z:
			m = t
	return m


func _togli(c: String, aspetta := true) -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	var t := _pozza_sul_bordo(c)
	await _vai(_davanti(t.position.x))
	p.look_at_point(Vector3(t.global_position.x, t.get_surface_global_y(), t.global_position.z))
	Input.action_press(&"suck")
	await _fisica(30)
	Input.action_release(&"suck")
	print("PL: %.2f s aspirato dal %s" % [_t(), c])
	if aspetta:
		for i in 60 * 8:
			await get_tree().physics_frame
			if c in e.tolti or e.stato != EnigmaPozze.Stato.APERTO:
				break
		print("PL: %.2f s tolto %s: %s, stato enigma %s" % [_t(), c, c in e.tolti, EnigmaPozze.Stato.keys()[e.stato]])


func _aspetta_motore(nome: String, s: float) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().physics_frame
		if GameState.is_dying:
			return false
		if AcquaDiLei.Fase.keys()[e.lei.acqua.fase] == nome:
			return true
	return false


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	spia = preload("res://tests/collaudo/spia_canto.gd").new()
	get_tree().root.add_child.call_deferred(spia)
	GameState.reset_progress()
	MenuProva.parti(get_tree(), "pozze")
	await _arriva(0)
	t0 = Time.get_ticks_msec()
	_prendi()
	await _secondi(2.0)
	print("PL: arrivato in %s, checkpoint %s, lei %s, letale %s, luci %s" % [p.global_position.snappedf(0.01), GameState.snapshot.get("checkpoint", ""),
			e.lei.nome_fase(), e.lei.letale, GameState.luci])
	await _vai(_davanti(0.0))
	# 1
	spia.set(&"etichetta", "1")
	await _togli(WaterMix.TURCHESE)
	await _vai(_davanti(0.0))
	p.look_at_point(e.global_position)
	var t := Time.get_ticks_msec()
	while not GameState.is_dying and Time.get_ticks_msec() - t < 60000:
		await get_tree().physics_frame
	print("PL: 1: dopo %.1f s morendo %s, causa %s, uscite %d, prese %d; luce accesa %d fotogrammi, fuori dalle pozze %d" % [(Time.get_ticks_msec() - t) / 1000.0,
			GameState.is_dying, GameState.last_death_cause, e.lei.uscite, e.lei.prese, accesa, fuori])
	if GameState.is_dying:
		var v := p.get_instance_id()
		await _arriva(v)
		_prendi()
		await _secondi(3.0)
		var piene := true
		for c in EnigmaPozze.COLORI:
			for tk: WaterTank in e.pozze_del_colore(c):
				if tk.fill < e.pieno - 0.003:
					piene = false
		print("PL: ripartito: checkpoint %s, giocatore %s, pozze piene %s, tolti %s, lei %s" % [GameState.snapshot.get("checkpoint", ""),
				p.global_position.snappedf(0.01), piene, e.tolti, e.lei.nome_fase()])
	# 2: il getto sulla mano
	spia.set(&"etichetta", "2")
	await _vai(_davanti(0.0))
	await _togli(WaterMix.VIOLA)
	await _vai(_davanti(0.0))
	p.look_at_point(e.global_position)
	if await _aspetta_motore("ESCE", 40.0):
		var viso: Node3D = e.lei.acqua.get(&"_viso")
		Input.action_press(&"spray")
		var tg := Time.get_ticks_msec()
		while Time.get_ticks_msec() - tg < 4000 and AcquaDiLei.Fase.keys()[e.lei.acqua.fase] in ["ESCE", "SU"] and not GameState.is_dying:
			if viso and is_instance_valid(viso):
				p.look_at_point(viso.global_position)
			await get_tree().physics_frame
		Input.action_release(&"spray")
		print("PL: 2: getto sulla mano per %.2f s: motore %s, morendo %s" % [(Time.get_ticks_msec() - tg) / 1000.0, AcquaDiLei.Fase.keys()[e.lei.acqua.fase], GameState.is_dying])
	else:
		print("PL: 2: non esce in 40 s (motore %s, morendo %s)" % [AcquaDiLei.Fase.keys()[e.lei.acqua.fase], GameState.is_dying])
	# 3: svuotare il colore della pozza dove arriva
	spia.set(&"etichetta", "3")
	if not GameState.is_dying and await _aspetta_motore("ARRIVA", 40.0):
		var q: Node3D = e.lei.acqua.get(&"_punto")
		var pozza := e.lei.call(&"_pozza_sotto", q.global_position) as WaterTank
		var col := ""
		for c in EnigmaPozze.COLORI:
			if e.pozze_del_colore(c).has(pozza):
				col = c
		print("PL: 3: arriva alla pozza %s (%s): si svuota quel colore" % [pozza.name, col])
		p.look_at_point(Vector3(pozza.global_position.x, pozza.get_surface_global_y(), pozza.global_position.z))
		Input.action_press(&"suck")
		await _fisica(30)
		Input.action_release(&"suck")
		await _secondi(5.0)
		print("PL: 3: dopo 5 s motore %s, morendo %s, svuotando %s" % [AcquaDiLei.Fase.keys()[e.lei.acqua.fase], GameState.is_dying, e.svuotando])
	# 4: allontanarsi
	spia.set(&"etichetta", "4")
	if not GameState.is_dying and await _aspetta_motore("ARRIVA", 40.0):
		var q2: Node3D = e.lei.acqua.get(&"_punto")
		var lontano := _davanti(-2.2) if q2.global_position.x - e.global_position.x > 0 else _davanti(2.2)
		await _vai(lontano, 240)
		await _aspetta_motore("CALMA", 10.0)
		print("PL: 4: allontanato a %.2f m dal punto: motore %s, morendo %s" % [AcquaDiLei._in_pianta(q2.global_position, p.global_position),
				AcquaDiLei.Fase.keys()[e.lei.acqua.fase], GameState.is_dying])
	# 5: risolto
	spia.set(&"etichetta", "5")
	if not GameState.is_dying:
		for c in EnigmaPozze.GIUSTI:
			if not c in e.tolti:
				await _togli(c)
		await _secondi(3.0)
		print("PL: 5: stato enigma %s, lei %s" % [EnigmaPozze.Stato.keys()[e.stato], e.lei.nome_fase()])
		var a0 := accesa
		var forte := -80.0
		var tt := Time.get_ticks_msec()
		while Time.get_ticks_msec() - tt < 30000:
			await get_tree().physics_frame
			forte = maxf(forte, float(spia.call(&"adesso")[0]))
		print("PL: 5: nei 30 s dopo: luce accesa %d fotogrammi, canto più forte %.0f dB, motore %s" % [accesa - a0, forte, AcquaDiLei.Fase.keys()[e.lei.acqua.fase]])
	print("PL: totale luce accesa %d, fuori dalle pozze %d" % [accesa, fuori])
	spia.call(&"riassunto")
	print("PL: finito")
	Game.esci(0)
