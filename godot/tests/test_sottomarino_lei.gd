extends Node
## Test di lei che insegue nel tunnel sottomarino (SalaSottomarino), senza schermo, con un bersaglio finto al posto
## del giocatore che va lungo la banchina:
## - se corri (5,8 m/s) lei resta fra 8 e 18 m dietro e non ti prende;
## - se cammini (3,4 m/s) o ti fermi ti raggiunge, morde a vuoto sotto i 7 m e ti prende sotto i 2,5 m;
## - un getto in faccia la rimanda indietro di circa 6 m e la ferma 2 s;
## - nella galleria di servizio (dietro il muro) non ti prende.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_sottomarino_lei.gd

var ok := 0
var falliti := 0
var sala: SalaSottomarino
var b: Node3D
var preso := false
var morsi := 0


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
	sala.lei_morde.connect(func(): morsi += 1)

	# 1) corri: resta fra 8 e 18 m
	var gap := await _prova(20.0, 5.8, 30.0, 8.0)
	_controlla(not preso and gap[0] >= 7.5 and gap[1] <= 18.6, "se corri resta fra 8 e 18 m e non ti prende",
			["min %.1f max %.1f preso %s" % [gap[0], gap[1], preso]])
	# 2) cammini: ti raggiunge e ti prende, mordendo prima
	gap = await _prova(60.0, 3.4, 30.0, 18.0)
	_controlla(preso and morsi > 0, "se cammini ti raggiunge, morde a vuoto e ti prende", ["preso %s morsi %d" % [preso, morsi]])
	# 3) fermo: ti prende in pochi secondi
	var t0 := Time.get_ticks_msec()
	gap = await _prova(100.0, 0.0, 8.0, 18.0)
	_controlla(preso, "se ti fermi ti prende", ["preso %s" % preso])
	# 4) il getto in faccia
	await _prova(150.0, 0.0, 0.6, 6.0)
	var prima := sala.lei_s
	sala.respingi()
	await _aspetta(1.2)
	var indietro := prima - sala.lei_s
	await _aspetta(0.6)
	var ferma := sala.lei_stato == SalaSottomarino.Lei.RESPINTA
	await _aspetta(0.6)
	_controlla(indietro > 5.0 and indietro < 7.5 and ferma and sala.lei_stato == SalaSottomarino.Lei.INSEGUE,
			"il getto in faccia la rimanda indietro di circa 6 m e la ferma 2 s", ["indietro %.1f" % indietro])
	# 5) nella galleria di servizio non ti prende
	preso = false
	var g: Dictionary = sala.ostacoli.filter(func(o): return o["tipo"] == "galleria")[0]
	var sg: float = float(g["s"]) + 4.0
	var p := sala.punto(sg) + sala.destra(sg) * float(g["lato"]) * (sala.muro + sala.spessore + 0.7)
	b.global_position = Vector3(p.x, sala.piano, p.z)
	sala.insegui_da(sg - 4.0)
	await _aspetta(3.0)
	_controlla(not preso, "nella galleria di servizio non ti prende", ["preso %s" % preso])

	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


## Il bersaglio parte da [param s0] sulla banchina sinistra e va a [param v] m/s per [param secondi]; lei parte
## [param dietro] metri dietro. Ritorna [distanza minima, massima].
func _prova(s0: float, v: float, secondi: float, dietro: float) -> Array:
	preso = false
	morsi = 0
	var s := s0
	_metti(s)
	sala._s_bersaglio = s
	sala.insegui_da(s0 - dietro)
	var lo := INF
	var hi := 0.0
	var t := 0.0
	while t < secondi and not preso:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		s += v * dt
		_metti(s)
		var gap := sala._s_bersaglio - sala.lei_s
		if t > 3.0:
			lo = minf(lo, gap)
			hi = maxf(hi, gap)
	return [lo, hi]


func _metti(s: float) -> void:
	var p := sala.punto(s) - sala.destra(s) * (sala.canale + sala.banchina * 0.5)
	b.global_position = Vector3(p.x, sala.piano, p.z)


func _aspetta(secondi: float) -> void:
	var t := 0.0
	while t < secondi:
		await get_tree().process_frame
		t += get_process_delta_time()


func _controlla(cond: bool, cosa: String, dove: Array) -> void:
	if cond:
		ok += 1
		print("  ok      " + cosa)
	else:
		falliti += 1
		print("  FALLITO " + cosa + ": " + str(dove))
