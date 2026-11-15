extends Node
## Test della carica di lei nel tunnel sottomarino (build 0.4.0 «L'acqua è sua», scelta dell'utente del 15 novembre:
## «Ogni 15-20 secondi lei arriva a 8 metri, smette di cantare e carica: se non ti giri a spruzzarla, ti prende.
## Colpita, torna indietro e si ricomincia. Il serbatoio basta per pochi spruzzi»). Senza schermo.
## Con un bersaglio finto che corre sulla banchina (5,8 m/s):
## - lei guadagna terreno e carica a 8 m dopo circa SalaSottomarino.avvicinamento secondi, e mentre carica il canto tace;
## - la prima carica della partita dura carica_finestra_prima secondi, le altre carica_finestra;
## - se non la colpisci scatta e ti prende, poco dopo la fine della finestra;
## - colpita nella finestra torna a distanza_max metri, il canto riprende, e la carica dopo arriva più tardi;
## - fermo sulla banchina lei arriva a 8 m e carica, senza prenderti prima;
## - con carica_attiva spento corri e lei resta fra 8 e 18 m (come prima della 0.4.0).
## Col giocatore vero (zaino e getto veri, la mira sul suo occhio): nel tunnel lo zaino ha il serbatoio del tunnel;
## quante cariche respinge un serbatoio pieno senza ricaricare, con la mira giusta (3-4: circa tre, scelta del
## coordinatore del 15 novembre); la ricarica dal canale in circa 2 s; uscendo, lo zaino torna com'era.
## Le cariche fuori dai passaggi obbligati le prova test_tunnel_attraversamenti.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tunnel_carica.gd

const STATO := preload("res://scripts/game/stato_tunnel.gd")
## Quante respinte deve dare un serbatoio pieno al più e al meno.
const RESPINTE := Vector2i(3, 4)
## Il giocatore vero si gira e spruzza dopo questi secondi dall'inizio della carica.
const REAZIONE := 0.7

var ok := 0
var falliti := 0
var sala: SalaSottomarino
var b: Node3D
var preso := false
var cariche := 0
var respinte := 0
var _t := 0.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	sala = SalaSottomarino.new()
	get_tree().root.add_child(sala)
	sala.costruisci()
	b = Node3D.new()
	add_child(b)
	sala.bersaglio = b
	sala.giocatore_preso.connect(func(): preso = true)
	sala.lei_carica.connect(func(): cariche += 1)
	sala.lei_respinta.connect(func(): respinte += 1)
	STATO.azzera()

	# 1) corri: carica a 8 m dopo circa 15 s; la prima finestra è più lunga; il canto tace
	var r := await _corri_fino_alla_carica(30.0, 40.0)
	_controlla(not preso and r[0] >= 12.0 and r[0] <= 18.0 and absf(float(r[1]) - sala.distanza_min) < 0.3,
			"se corri lei guadagna terreno e carica a %.0f m dopo circa %.0f s" % [sala.distanza_min, sala.avvicinamento],
			["dopo %.1f s, a %.2f m, preso %s" % [r[0], r[1], preso]])
	_controlla(is_equal_approx(sala._finestra, sala.carica_finestra_prima), "la prima carica della partita dura %.0f s" % sala.carica_finestra_prima,
			["finestra %.1f s" % sala._finestra])
	_controlla(sala.lei_tunnel.lei.has_meta(LeiTunnel.CANTO_ZITTO) and sala.lei_tunnel.stato == LeiTunnel.Stato.CARICA,
			"mentre carica il canto tace", ["zitto %s, stato %s" % [sala.lei_tunnel.lei.has_meta(LeiTunnel.CANTO_ZITTO), sala.lei_tunnel.stato]])
	# 2) non la colpisci: scatta e ti prende poco dopo la finestra
	var t0 := _t
	var s := sala._s_bersaglio
	while not preso and _t - t0 < 8.0:
		s += 5.8 * await _passo()
		b.global_position = _banchina(s)
	_controlla(preso and _t - t0 >= sala.carica_finestra_prima and _t - t0 <= sala.carica_finestra_prima + 1.5,
			"se non la colpisci scatta e ti prende", ["preso %s dopo %.2f s dalla carica" % [preso, _t - t0]])

	# 3) la colpisci: torna a 18 m, il canto riprende, la carica dopo arriva più tardi (la seconda: finestra corta)
	# (col bersaglio finto la presa lascia lei nella posa della presa: nel gioco la morte ricostruisce il tunnel)
	preso = false
	sala.lei_tunnel.via()
	r = await _corri_fino_alla_carica(60.0, 40.0)
	_controlla(not preso and is_equal_approx(sala._finestra, sala.carica_finestra), "dalla seconda carica la finestra è di %.0f s" % sala.carica_finestra,
			["finestra %.1f s, preso %s" % [sala._finestra, preso]])
	s = sala._s_bersaglio
	t0 = _t
	while _t - t0 < 1.0:
		s += 5.8 * await _passo()
		b.global_position = _banchina(s)
	var prima := respinte
	sala.respingi()
	var massimo := 0.0
	t0 = _t
	while _t - t0 < 2.5:
		s += 5.8 * await _passo()
		b.global_position = _banchina(s)
		massimo = maxf(massimo, sala._s_bersaglio - sala.lei_s)
	_controlla(respinte == prima + 1 and not preso and massimo >= sala.distanza_max - 0.5 + 5.8 * 0.0 and
			not sala.lei_tunnel.lei.has_meta(LeiTunnel.CANTO_ZITTO),
			"colpita nella finestra torna a %.0f m e il canto riprende" % sala.distanza_max,
			["respinte %d, fino a %.1f m, zitto %s" % [respinte - prima, massimo, sala.lei_tunnel.lei.has_meta(LeiTunnel.CANTO_ZITTO)]])
	var c0 := cariche
	t0 = _t
	while cariche == c0 and not preso and _t - t0 < 40.0:
		s += 5.8 * await _passo()
		b.global_position = _banchina(s)
	_controlla(cariche == c0 + 1 and not preso and _t - t0 >= 12.0 and _t - t0 <= 25.0,
			"dopo la respinta la carica dopo arriva fra 15 e 20 s circa", ["dopo %.1f s, preso %s" % [_t - t0, preso]])

	# 4) fermo sulla banchina: arriva a 8 m e carica, senza prenderti prima
	preso = false
	sala.lei_tunnel.via()
	var s4 := 100.0
	b.global_position = _banchina(s4)
	sala._s_bersaglio = s4
	sala.insegui_da(s4 - 18.0)
	c0 = cariche
	var minimo := INF
	t0 = _t
	while cariche == c0 and not preso and _t - t0 < 15.0:
		await _passo()
		minimo = minf(minimo, sala._s_bersaglio - sala.lei_s)
	_controlla(cariche == c0 + 1 and not preso and minimo >= sala.distanza_min - 0.05,
			"fermo sulla banchina lei arriva a %.0f m e carica, senza prenderti prima" % sala.distanza_min,
			["cariche %d, minimo %.2f m, preso %s" % [cariche - c0, minimo, preso]])

	# 5) carica spenta: corri e lei resta fra 8 e 18 m
	sala.carica_attiva = false
	preso = false
	sala.lei_tunnel.via()
	c0 = cariche
	var s5 := 200.0
	b.global_position = _banchina(s5)
	sala._s_bersaglio = s5
	sala.insegui_da(s5 - 18.0)
	minimo = INF
	massimo = 0.0
	t0 = _t
	while _t - t0 < 25.0 and not preso:
		s5 += 5.8 * await _passo()
		b.global_position = _banchina(s5)
		if _t - t0 > 1.0:
			minimo = minf(minimo, sala._s_bersaglio - sala.lei_s)
			massimo = maxf(massimo, sala._s_bersaglio - sala.lei_s)
	_controlla(not preso and cariche == c0 and minimo >= 7.5 and massimo <= 18.6,
			"con la carica spenta corri e lei resta fra 8 e 18 m", ["min %.1f max %.1f, cariche %d" % [minimo, massimo, cariche - c0]])
	sala.carica_attiva = true

	# 6) il giocatore vero: le respinte di un serbatoio pieno, poi la ricarica dal canale
	await _serbatoio()
	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


## Corre da [param s0] con lei 18 m dietro finché lei carica (al più [param per] s). Ritorna [secondi, distanza].
func _corri_fino_alla_carica(s0: float, per: float) -> Array:
	b.global_position = _banchina(s0)
	sala._s_bersaglio = s0
	sala.insegui_da(s0 - sala.distanza_max)
	var c0 := cariche
	var t0 := _t
	var s := s0
	while cariche == c0 and not preso and _t - t0 < per:
		s += 5.8 * await _passo()
		b.global_position = _banchina(s)
	return [_t - t0, sala._s_bersaglio - sala.lei_s]


## Il giocatore vero sulla banchina, che corre (spostato a 5,8 m/s); a ogni carica, dopo [constant REAZIONE] s, si
## gira verso l'occhio di lei e spruzza finché lei si ritrae, poi si rigira e corre. Senza ricaricare: quante
## respinte prima di restare a secco (o preso). Poi la ricarica dal canale, da fermo.
func _serbatoio() -> void:
	var g := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(g)
	await _passo()
	await _passo()
	var pack: WaterPack = g.water_pack
	pack.set_equipped(true, false)
	pack.set_tank_amount(pack.tank_capacity)
	g.input_enabled = true
	b.global_position = Vector3(0, -100, 0)
	sala.bersaglio = g
	# (il tunnel nel gioco: lo zaino prende il serbatoio del tunnel)
	sala.attiva_tunnel()
	await _passo()
	_controlla(is_equal_approx(pack.tank_capacity, sala.serbatoio_tunnel) and is_equal_approx(pack.suck_rate, sala.aspira_tunnel),
			"nel tunnel lo zaino ha il serbatoio del tunnel (%.0f litri)" % sala.serbatoio_tunnel, ["%.1f litri, %.1f l/s" % [pack.tank_capacity, pack.suck_rate]])
	pack.set_tank_amount(pack.tank_capacity)
	preso = false
	var s := 40.0
	sala.lei_tunnel.via()
	sala._s_bersaglio = s
	g.teleport(_banchina(s) + Vector3.UP * 0.1, _yaw(sala.direzione(s)))
	sala.insegui_da(s - sala.distanza_max)
	var r0 := respinte
	var litri: Array[float] = []
	var t0 := _t
	while not preso and pack.tank_amount > 0.05 and _t - t0 < 200.0 and s < sala.lunghezza() - 30.0:
		var dt := await _passo()
		if sala.lei_stato == SalaSottomarino.Lei.CARICA and sala._lei_t >= REAZIONE:
			# si gira e spruzza in faccia finché si ritrae
			var prima := pack.tank_amount
			Input.action_press(&"spray")
			var t1 := _t
			while sala.lei_stato == SalaSottomarino.Lei.CARICA and pack.tank_amount > 0.0 and _t - t1 < 3.0:
				g.look_at_point(sala.lei_tunnel.lei.get_eye_position())
				await _passo()
			Input.action_release(&"spray")
			litri.append(prima - pack.tank_amount)
			g.teleport(g.global_position, _yaw(sala.direzione(s)))
			continue
		s += 5.8 * dt
		g.teleport(_banchina(s) + Vector3.UP * 0.1, _yaw(sala.direzione(s)))
	var n := respinte - r0
	print("    serbatoio: %d respinte con %.0f litri, litri per carica %s, preso %s, %.1f litri rimasti" % [
			n, pack.tank_capacity, litri.map(func(x): return snappedf(x, 0.1)), preso, pack.tank_amount])
	_controlla(n >= RESPINTE.x and n <= RESPINTE.y, "un serbatoio pieno respinge circa tre cariche (%d-%d)" % [RESPINTE.x, RESPINTE.y],
			["%d respinte, preso %s" % [n, preso]])
	# la ricarica dal canale: fermo sul bordo della banchina, puntando l'acqua
	sala.lei_stato = SalaSottomarino.Lei.VIA
	sala.lei_tunnel.via()
	pack.set_tank_amount(0.0)
	var bordo := sala._al(sala.punto(s), sala.destra(s), Vector2(-(sala.canale + 0.6), sala.piano + 0.1))
	g.teleport(bordo, _yaw(sala.direzione(s)))
	await _passo()
	g.look_at_point(sala._al(sala.punto(s), sala.destra(s), Vector2(-(sala.canale - 1.2), sala.acqua)))
	await _passo()
	Input.action_press(&"suck")
	await _passo()
	print("    ricarica: da %s, fonte %s" % [g.global_position, pack.find_suction_source()])
	t0 = _t
	while pack.tank_amount < pack.tank_capacity - 0.05 and _t - t0 < 6.0:
		await _passo()
	Input.action_release(&"suck")
	_controlla(pack.tank_amount >= pack.tank_capacity - 0.05 and _t - t0 <= 3.0, "si ricarica dal canale in circa 2 s da fermo",
			["%.1f litri in %.1f s" % [pack.tank_amount, _t - t0]])
	sala.bersaglio = b
	sala._serbatoio_di_fuori()
	_controlla(is_equal_approx(pack.tank_capacity, 20.0) and is_equal_approx(pack.suck_rate, 10.0),
			"uscendo dal tunnel lo zaino torna com'era", ["%.1f litri, %.1f l/s" % [pack.tank_capacity, pack.suck_rate]])
	g.queue_free()


func _banchina(s: float) -> Vector3:
	var p := sala.punto(s) + sala.destra(s) * -(sala.canale + sala.banchina * 0.5)
	return Vector3(p.x, sala.piano, p.z)


func _yaw(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


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
