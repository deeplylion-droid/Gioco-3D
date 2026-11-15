extends Node
## Ricontrollo incrociato della carica di lei nel tunnel (ambienti-1 sulla prova d'insieme della 0.4.0, 15 novembre):
## i casi di bordo che test_tunnel_carica e test_tunnel_attraversamenti non fanno. Senza schermo, con un bersaglio
## finto come quei test.
## 1. partita nuova nello stesso avvio: la prima respinta si dimentica e la carica torna lunga;
## 2. Continua (GameState.prepara_ripresa): stato del tunnel azzerato anche lì (la finestra lunga torna);
## 3. ripartenza da ogni checkpoint del tunnel (insegui_da 18 m dietro): lei insegue a 18 m, nessuna carica prima dei
##    2 s di banchina, la prima respinta resta ricordata;
## 4. una carica che comincia un attimo prima di un attraversamento sui gommoni: entrando la carica finisce, lei non
##    scende sotto 8 m e non prende; riatterrati sulla banchina, niente carica prima di 2 s;
## 5. lo scatto che comincia sulla banchina un attimo prima dell'attraversamento: cosa succede (stampato);
## 6. fermo sul bordo della banchina a ricaricare: carica, e senza respinta quanto passa fino alla presa;
## 7. fermo a guado nel canale a ricaricare: lei arriva e prende (le regole di sempre), in quanto tempo.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/ricontrollo/ricontrollo_carica_tunnel.gd

const STATO := preload("res://scripts/game/stato_tunnel.gd")

var ok := 0
var falliti := 0
var sala: SalaSottomarino
var b: Node3D
var preso := false
var cariche := 0
var _t := 0.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.save_to_disk = false
	sala = SalaSottomarino.new()
	get_tree().root.add_child(sala)
	sala.costruisci()
	b = Node3D.new()
	add_child(b)
	sala.bersaglio = b
	sala.giocatore_preso.connect(func(): preso = true)
	sala.lei_carica.connect(func(): cariche += 1)

	print("1. Partita nuova nello stesso avvio")
	STATO.prima_respinta_fatta = true
	GameState.reset_progress()
	_controlla(not STATO.prima_respinta_fatta, "la partita nuova dimentica la prima respinta", [])
	await _fermo_fino_alla_carica(100.0)
	_controlla(is_equal_approx(sala._finestra, sala.carica_finestra_prima), "e la prima carica è di nuovo lunga",
			["finestra %.1f s" % sala._finestra])

	print("2. Continua (prepara_ripresa)")
	STATO.prima_respinta_fatta = true
	GameState.prepara_ripresa({})
	GameState._restore_pending = false
	_controlla(not STATO.prima_respinta_fatta,
			"Continua azzera anche lo stato del tunnel (la finestra lunga torna: comportamento da confermare)", [])

	print("3. Ripartenza da ogni checkpoint del tunnel")
	STATO.prima_respinta_fatta = true
	for s in sala.checkpoint_s:
		preso = false
		sala.lei_tunnel.via()
		var sp := clampf(s, 3.0, sala.lunghezza() - sala.approdo_tratto - 1.0)
		b.global_position = _banchina(sp)
		sala._s_bersaglio = sp
		sala.insegui_da(sp - sala.distanza_max)
		var c0 := cariche
		var prima_carica := -1.0
		var minimo := INF
		var t0 := _t
		while _t - t0 < 4.0 and not preso:
			await _passo()
			minimo = minf(minimo, sala._s_bersaglio - sala.lei_s)
			if cariche > c0 and prima_carica < 0.0:
				prima_carica = _t - t0
		_controlla(not preso and (prima_carica < 0.0 or prima_carica >= sala.carica_dopo_passaggio - 0.05) and minimo >= sala.distanza_min - 0.05,
				"da %.0f m: lei insegue, niente carica prima di 2 s di banchina, non prende" % s,
				["prima carica %.2f s, minimo %.2f m, preso %s" % [prima_carica, minimo, preso]])
	_controlla(STATO.prima_respinta_fatta, "ripartendo la prima respinta resta ricordata (finestra corta)", [])

	print("4. Carica un attimo prima di un attraversamento")
	var zona: Array = sala._zone_attraversamento[0]
	var z0 := float(zona[0])
	var z1 := float(zona[1])
	preso = false
	sala.lei_tunnel.via()
	await _fermo_fino_alla_carica(z0 - 2.0)
	_controlla(sala.lei_stato == SalaSottomarino.Lei.CARICA, "carica sulla banchina a 2 m dall'attraversamento", ["stato %d" % sala.lei_stato])
	var minimo4 := INF
	var cariche4 := cariche
	var s4 := z0 + 0.5
	var t4 := _t
	var stato_dopo := -1
	while _t - t4 < 5.0 and not preso:
		# sui gommoni: sopra il canale, fuori dall'acqua, avanti piano (2,25 s per salto, circa 1 m/s)
		s4 = minf(s4 + 1.0 * await _passo(), z1 - 0.5)
		b.global_position = _canale(s4, sala.acqua + 0.45)
		if stato_dopo < 0 and _t - t4 > 0.05:
			stato_dopo = sala.lei_stato
		minimo4 = minf(minimo4, sala._s_bersaglio - sala.lei_s)
	_controlla(stato_dopo == SalaSottomarino.Lei.INSEGUE and not preso and cariche == cariche4 and minimo4 >= sala.distanza_min - 0.05,
			"entrando sui gommoni la carica finisce, lei resta ad almeno 8 m e non prende",
			["stato dopo 0,05 s %d, minimo %.2f m, cariche in più %d, preso %s" % [stato_dopo, minimo4, cariche - cariche4, preso]])
	var s5 := z1 + 1.0
	b.global_position = _banchina(s5)
	var c5 := cariche
	var t5 := _t
	var dopo := -1.0
	while _t - t5 < 3.0 and not preso:
		s5 += 3.4 * await _passo()
		b.global_position = _banchina(s5)
		if cariche > c5 and dopo < 0.0:
			dopo = _t - t5
	_controlla(not preso and (dopo < 0.0 or dopo >= sala.carica_dopo_passaggio - 0.05),
			"riatterrato sulla banchina, niente carica prima di 2 s", ["carica dopo %.2f s, preso %s" % [dopo, preso]])

	print("5. Scatto un attimo prima di un attraversamento")
	preso = false
	sala.lei_tunnel.via()
	await _fermo_fino_alla_carica(z0 - 2.0)
	var t6 := _t
	while sala.lei_stato == SalaSottomarino.Lei.CARICA and _t - t6 < 6.0:
		await _passo()
	var s6 := z0 + 0.5
	var t7 := _t
	while _t - t7 < 3.0 and not preso:
		s6 = minf(s6 + 1.0 * await _passo(), z1 - 0.5)
		b.global_position = _canale(s6, sala.acqua + 0.45)
	print("    scattata sulla banchina, poi sui gommoni: preso %s dopo %.2f s, stato %d" % [preso, _t - t7, sala.lei_stato])

	print("6. Fermo sul bordo della banchina a ricaricare")
	preso = false
	sala.lei_tunnel.via()
	STATO.prima_respinta_fatta = true
	var s8 := 120.0
	b.global_position = sala._al(sala.punto(s8), sala.destra(s8), Vector2(-(sala.canale + 0.6), sala.piano))
	sala._s_bersaglio = s8
	sala.insegui_da(s8 - sala.distanza_max)
	var c8 := cariche
	var t8 := _t
	var alla_carica := -1.0
	while not preso and _t - t8 < 30.0:
		await _passo()
		if cariche > c8 and alla_carica < 0.0:
			alla_carica = _t - t8
	_controlla(alla_carica > 0.0 and preso, "sul bordo carica, e senza respinta prende",
			["carica dopo %.2f s, presa %.2f s dopo la carica" % [alla_carica, _t - t8 - alla_carica]])
	print("    dall'inizio della carica alla presa: %.2f s (finestra %.1f s; la ricarica piena dal canale ne prende 2)" % [_t - t8 - alla_carica, sala.carica_finestra])

	print("7. Fermo a guado nel canale a ricaricare")
	preso = false
	sala.lei_tunnel.via()
	var s9 := 140.0
	b.global_position = _canale(s9, sala.acqua - 0.3)
	sala._s_bersaglio = s9
	sala.insegui_da(s9 - sala.distanza_max)
	var c9 := cariche
	var t9 := _t
	while not preso and _t - t9 < 20.0:
		await _passo()
	_controlla(preso and cariche == c9, "a guado lei non carica, arriva e prende (le regole di sempre)",
			["preso %s dopo %.2f s, cariche %d" % [preso, _t - t9, cariche - c9]])

	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	sala.queue_free()
	get_tree().quit(1 if falliti > 0 else 0)


## Fermo sulla banchina a [param s]: lei parte 18 m dietro e carica (fermo: arriva a 8 m e carica).
func _fermo_fino_alla_carica(s: float) -> void:
	b.global_position = _banchina(s)
	sala._s_bersaglio = s
	sala.insegui_da(s - sala.distanza_max)
	var c0 := cariche
	var t0 := _t
	while cariche == c0 and not preso and _t - t0 < 20.0:
		await _passo()


func _banchina(s: float) -> Vector3:
	var p := sala.punto(s) + sala.destra(s) * -(sala.canale + sala.banchina * 0.5)
	return Vector3(p.x, sala.piano, p.z)


func _canale(s: float, y: float) -> Vector3:
	var p := sala.punto(s)
	return Vector3(p.x, y, p.z)


func _passo() -> float:
	await get_tree().process_frame
	_t += get_process_delta_time()
	return get_process_delta_time()


func _controlla(cond: bool, cosa: String, dove: Array) -> void:
	if cond:
		ok += 1
		print("  ok      ", cosa)
	else:
		falliti += 1
		print("  FALLITO ", cosa, ": ", dove)
