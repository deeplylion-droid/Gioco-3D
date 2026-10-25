extends Node
## Test della distanza di lei negli attraversamenti sui gommoni del tunnel sottomarino (regola dell'utente: "lei ti sta
## dietro fra 8 e 18 m", il getto la ferma 2 s e la rimanda indietro di 6 m). Senza schermo, con un bersaglio finto al
## posto del giocatore che rifà i 5 attraversamenti coi tempi veri, saltando di gommone in gommone dalla banchina
## chiusa a quella libera, in tre modi:
## - corre: salti di fila (1,1 s l'uno), poi via di corsa;
## - si gira: salti come nel collaudo (2,25 s l'uno, i due salti del primo in 4,5 s), poi atterra, si gira e spruzza
##   (il getto arriva 1 s dopo l'atterraggio);
## - lento: si ferma 1,5 s su ogni gommone prima di saltare (3 s per salto), poi via di corsa.
## In tutti e tre all'atterraggio lei è almeno a 8 m e non lo prende. Se invece cade in acqua dal primo gommone e resta
## lì, lei lo prende. Lo stesso per le gallerie basse (a 205 e 425 m): entra accovacciato con lei a 17,9 m, esce con
## lei ad almeno 8 m. Poi l'approdo (guado obbligato, scala, pontile: lei sempre ad almeno 8 m) e il portello (mentre
## si chiude lei si ferma).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tunnel_attraversamenti.gd

var ok := 0
var falliti := 0
var sala: SalaSottomarino
var b: Node3D
var preso := false


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
	var modi := {"corre": [1.1, 0.0, 5.8], "si gira": [2.25, 0.0, 5.8], "lento": [1.5, 1.5, 5.8]}
	var k := 0
	for att in sala.attraversamenti:
		var n: int = (att[1] as Array).size() - 1
		var gs: Array = sala.gommoni.slice(k, k + n)
		k += n
		for modo: String in modi:
			var m: Array = modi[modo]
			var r: Array = await _attraversa(float(att[0]), gs, float(m[0]), float(m[1]), float(m[2]), modo)
			# (chi si gira a spruzzare resta fermo un secondo: lei si avvicina, ma il getto la rimanda indietro prima
			# che lo prenda)
			var dopo_ok := float(r[1]) > sala.distanza_presa if modo == "si gira" else float(r[1]) >= 7.95
			_controlla(not preso and float(r[0]) >= 7.95 and dopo_ok,
					"attraversamento a %d m, %s: all'atterraggio lei è almeno a 8 m e non ti prende" % [int(att[0]), modo],
					["all'atterraggio %.2f m, minimo dopo %.2f m, preso %s" % [r[0], r[1], preso]])
		# chi cade in acqua dal primo gommone e resta lì viene preso
		var caduto: bool = await _cade(gs)
		_controlla(caduto, "attraversamento a %d m: se cadi in acqua e resti lì ti prende" % int(att[0]), ["preso %s" % caduto])
	# le gallerie basse: entra accovacciato (2,3 m/s) con lei a 17,9 m, la attraversa senza fermarsi, esce e corre
	for g in sala.ostacoli:
		if g["tipo"] != "galleria":
			continue
		var r: Array = await _galleria(g)
		_controlla(not preso and float(r[0]) >= 7.95 and float(r[1]) > sala.distanza_presa,
				"galleria a %d m: all'uscita lei è almeno a 8 m e non ti prende" % int(g["s"]),
				["all'uscita %.2f m, minimo dopo %.2f m, preso %s" % [r[0], r[1], preso]])
	# l'approdo: il guado obbligato verso la scala, la scala e il pontile
	var r2: Array = await _approdo()
	_controlla(not preso and float(r2[0]) >= 7.95, "approdo: guado, scala e pontile con lei sempre ad almeno 8 m",
			["minimo %.2f m, preso %s" % [r2[0], preso]])
	# il portello: mentre si chiude lei non avanza più (e non prende dietro il portello)
	var r3: Array = await _portello()
	_controlla(not preso and float(r3[0]) < 0.05, "portello: mentre si chiude lei si ferma",
			["avanzata %.2f m, preso %s" % [r3[0], preso]])
	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


## Da che lato del canale sono la banchina chiusa (quella dell'ostacolo): +1 a destra.
func _lato(s_ost: float) -> float:
	for o in sala.ostacoli:
		if absf(float(o["s"]) - s_ost) < 0.01:
			return float(o["lato"])
	return 1.0


func _banchina(s: float, lato: float) -> Vector3:
	var p := sala.punto(s) + sala.destra(s) * lato * (sala.canale + sala.banchina * 0.5)
	return Vector3(p.x, sala.piano, p.z)


func _gommone(g: Array) -> Vector3:
	var s := float(g[0])
	var p := sala.punto(s) + sala.destra(s) * float(g[1])
	return Vector3(p.x, sala.acqua + 0.2, p.z)


## Un attraversamento: 30 m di corsa sulla banchina chiusa con lei 18 m dietro, poi i salti di gommone in gommone
## ([param salto] s l'uno, [param pausa] s fermo su ogni gommone), l'atterraggio sulla banchina libera e poi via a
## [param dopo] m/s (per "si gira": fermo 1 s, il getto, poi via). Ritorna [distanza all'atterraggio, minima dopo].
func _attraversa(s_ost: float, gs: Array, salto: float, pausa: float, dopo: float, modo: String) -> Array:
	preso = false
	var lato := _lato(s_ost)
	var s0 := float(gs[0][0])
	var s_via := s0 - 30.0
	b.global_position = _banchina(s_via, lato)
	sala._s_bersaglio = s_via
	sala.insegui_da(s_via - 18.0)
	# la corsa fino al bordo della banchina chiusa
	var s := s_via
	while s < s0 and not preso:
		var dt := await _passo()
		s += 5.8 * dt
		b.global_position = _banchina(minf(s, s0), lato)
	# i salti: dal bordo della banchina a ogni gommone e dall'ultimo alla banchina libera
	var punti: Array = []
	var bordo := sala.punto(s0) + sala.destra(s0) * lato * (sala.canale + 0.4)
	punti.append(Vector3(bordo.x, sala.piano, bordo.z))
	for g in gs:
		punti.append(_gommone(g))
	var sl := float(gs[gs.size() - 1][0])
	var arrivo := sala.punto(sl) - sala.destra(sl) * lato * (sala.canale + 0.4)
	punti.append(Vector3(arrivo.x, sala.piano, arrivo.z))
	for i in range(1, punti.size()):
		var a: Vector3 = punti[i - 1]
		var c: Vector3 = punti[i]
		var t := 0.0
		while t < salto and not preso:
			t += await _passo()
			var f := clampf(t / salto, 0.0, 1.0)
			b.global_position = a.lerp(c, f) + Vector3.UP * (4.0 * f * (1.0 - f) * 0.9)
		if i < punti.size() - 1:
			await _aspetta(pausa)
	var all_atterraggio := sala._s_bersaglio - sala.lei_s
	# dopo l'atterraggio
	var minimo := INF
	var sd := sl
	var t2 := 0.0
	var getto := false
	while t2 < 6.0 and not preso:
		var dt := await _passo()
		t2 += dt
		if modo == "si gira" and t2 < 1.0:
			pass
		else:
			if modo == "si gira" and not getto:
				getto = true
				sala.respingi()
			sd += dopo * dt
		b.global_position = _banchina(sd, -lato)
		minimo = minf(minimo, sala._s_bersaglio - sala.lei_s)
	print("    %s a %d m: all'atterraggio %.2f m, minimo dopo %.2f m" % [modo, int(s_ost), all_atterraggio, minimo])
	return [all_atterraggio, minimo]


## Una galleria bassa: sulla banchina fino alla bocca con lei 17,9 m dietro, dentro accovacciato a 2,3 m/s fino
## all'altra bocca, fuori e via di corsa. Ritorna [distanza all'uscita, minima dopo].
func _galleria(g: Dictionary) -> Array:
	preso = false
	var lato := float(g["lato"])
	var s0 := float(g["s"]) - sala.GALLERIA_BOCCA
	var s1 := float(g["s"]) + float(g["lungo"]) + sala.GALLERIA_BOCCA
	var dentro := sala.muro + sala.spessore + 0.7
	b.global_position = _banchina(s0, lato)
	sala._s_bersaglio = s0
	sala.insegui_da(s0 - 17.9)
	# dalla banchina alla bocca (accovacciato, 0,8 s), lungo la galleria, fuori sulla banchina
	var a := _banchina(s0, lato)
	var c := _al_lato(s0, lato * dentro)
	var t := 0.0
	while t < 0.8 and not preso:
		t += await _passo()
		b.global_position = a.lerp(c, clampf(t / 0.8, 0.0, 1.0))
	var s := s0
	while s < s1 and not preso:
		s += 2.3 * await _passo()
		b.global_position = _al_lato(minf(s, s1), lato * dentro)
	var all_uscita := sala._s_bersaglio - sala.lei_s
	a = b.global_position
	c = _banchina(s1, lato)
	t = 0.0
	while t < 0.8 and not preso:
		t += await _passo()
		b.global_position = a.lerp(c, clampf(t / 0.8, 0.0, 1.0))
	var minimo := INF
	t = 0.0
	s = s1
	while t < 6.0 and not preso:
		var dt := await _passo()
		t += dt
		s += 5.8 * dt
		b.global_position = _banchina(s, lato)
		minimo = minf(minimo, sala._s_bersaglio - sala.lei_s)
	print("    galleria a %d m: all'uscita %.2f m, minimo dopo %.2f m" % [int(g["s"]), all_uscita, minimo])
	return [all_uscita, minimo]


## L'approdo coi tempi del collaudo: arriva sulla banchina destra a 5,7 m dalla fine con lei 17,8 m dietro, guado di
## 3,5 s fino al gradino sinistro, scala in 2,2 s fino in fondo, 2 s sul pontile verso il portello. Ritorna
## [distanza minima dall'inizio del guado].
func _approdo() -> Array:
	preso = false
	var L := sala.lunghezza()
	var s0 := L - 5.7
	b.global_position = _banchina(s0, 1.0)
	sala._s_bersaglio = s0
	sala.insegui_da(s0 - 17.8)
	var minimo := INF
	var tappe := [[3.5, _al_lato(s0, -sala.canale) - Vector3.UP * 0.4], [0.4, _banchina(s0, -1.0)],
			[2.2, _al_lato(L - 0.1, -sala.muro + 0.6) + Vector3.UP * sala.SOGLIA],
			[2.0, _al_lato(L - 0.1, sala.PONTILE_FINO - 0.2) + Vector3.UP * sala.SOGLIA]]
	var a := _al_lato(s0, sala.canale) - Vector3.UP * 0.4
	b.global_position = a
	for tp in tappe:
		var c: Vector3 = tp[1]
		var t := 0.0
		while t < float(tp[0]) and not preso:
			t += await _passo()
			b.global_position = a.lerp(c, clampf(t / float(tp[0]), 0.0, 1.0))
			minimo = minf(minimo, sala._s_bersaglio - sala.lei_s)
		a = c
	print("    approdo: minimo %.2f m" % minimo)
	return [minimo]


## Il portello che si chiude con lei a 3 m: ritorna [quanto è avanzata lei mentre si chiude].
func _portello() -> Array:
	preso = false
	var L := sala.lunghezza()
	b.global_position = _al_lato(L + 1.0, 0.0) + Vector3.UP * sala.SOGLIA
	sala._s_bersaglio = L - 0.2
	sala.insegui_da(L - 3.2)
	await _passo()
	var prima := sala.lei_s
	sala.chiudi_portello()
	await _aspetta(1.9)
	return [sala.lei_s - prima]


func _al_lato(s: float, u: float) -> Vector3:
	var p := sala.punto(s) + sala.destra(s) * u
	return Vector3(p.x, sala.piano, p.z)


## Salta sul primo gommone (con lei a 9 m), cade in acqua e resta lì: vero se lei lo prende entro 10 s.
func _cade(gs: Array) -> bool:
	preso = false
	var g0 := _gommone(gs[0])
	var s0 := float(gs[0][0])
	b.global_position = g0
	sala._s_bersaglio = s0
	sala.insegui_da(s0 - 9.0)
	await _aspetta(0.5)
	b.global_position = Vector3(g0.x, sala.acqua - 0.6, g0.z)
	var t := 0.0
	while t < 10.0 and not preso:
		t += await _passo()
	return preso


func _passo() -> float:
	await get_tree().process_frame
	return get_process_delta_time()


func _aspetta(secondi: float) -> void:
	var t := 0.0
	while t < secondi and not preso:
		t += await _passo()


func _controlla(cond: bool, cosa: String, dove: Array) -> void:
	if cond:
		ok += 1
		print("  ok      " + cosa)
	else:
		falliti += 1
		print("  FALLITO " + cosa + ": " + str(dove))
