extends Node
## Test del guado nel canale del tunnel sottomarino (SalaSottomarino), col Player vero e gli input simulati.
## Le scelte del 24 ottobre (GDD "Il tunnel del viaggio sottomarino" e coordinatore): "Se finisci in acqua sei
## rallentato ma puoi risalire e proseguire saltando".
## - velocità: nell'acqua 2,0 m/s camminando e correndo, 1,2 accovacciati; sulla banchina le solite;
## - salto: nell'acqua del canale non si salta (richiesta dell'utente del 25 ottobre: "se finisci in acqua in quella
##   sezione, non puoi saltare"), sulla banchina sì;
## - risalita: da 30 punti del canale, dalla presa all'approdo, si torna sulla banchina più vicina **camminando**, dai
##   due scalini del gradino, in pochi secondi ("Se cadi nella piscinetta della stanza generatori non puoi uscire":
##   dall'acqua si esce sempre); sotto le gallerie di servizio, dove le due banchine sono crollate, si va a guado fino
##   alla fine del crollo; nella presa (il fondo più basso) e all'approdo (sotto il pontile) fino al gradino più vicino;
## - di sbieco (collaudo di grafica-2 del 25 ottobre: camminando a 45° ci si fermava sugli scalini): da 18 punti a caso,
##   (non sui gommoni né accanto a un crollo) verso la banchina più vicina a 30°, 45° e 60° dalla perpendicolare, in avanti e indietro, tenendo
##   l'angolo con la riva anche in curva, si esce entro 4 s; non contano le uscite che finiscono contro un ostacolo di
##   quella banchina (crollo, galleria, carico...: lì si guada);
## - aspirazione: dal canale e dalla banchina lo zaino si riempie dovunque, e l'acqua non finisce.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_guado.gd

const PLAYER := "res://scenes/player/player.tscn"
## Entro quanti secondi si deve essere fuori dall'acqua.
const RISALITA_MAX := 6.0
const PUNTI := 30
## Di sbieco: quanti punti, gli angoli dalla perpendicolare alla banchina, entro quanti secondi si esce.
const SBIECO_PUNTI := 18
const SBIECO_ANGOLI := [30.0, 45.0, 60.0]
const SBIECO_MAX := 4.0

var sala: SalaSottomarino
var p: Player
var ok := 0
var falliti := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	sala = SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	get_tree().root.add_child(sala)
	sala.costruisci()
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	get_tree().root.add_child(p)
	await _frames(10)
	if OS.get_environment("GUADO_SOLO") in ["", "velocita"]:
		await _velocita()
	if OS.get_environment("GUADO_SOLO") in ["", "salto"]:
		await _salto()
	if OS.get_environment("GUADO_SOLO") in ["", "risalita"]:
		await _risalita()
	if OS.get_environment("GUADO_SOLO") in ["", "sbieco"]:
		await _sbieco()
	if OS.get_environment("GUADO_SOLO") in ["", "aspirazione"]:
		await _aspirazione()
	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


# --- aiuti ---------------------------------------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _rilascia() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"crouch", &"jump", &"spray", &"suck"]:
		Input.action_release(a)


func _controlla(cond: bool, cosa: String) -> void:
	if cond:
		ok += 1
		print("  ok      " + cosa)
	else:
		falliti += 1
		print("  FALLITO " + cosa)


## Lo yaw che guarda nella direzione [param d] (orizzontale): yaw 0 guarda verso -z.
static func _yaw(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


## Un punto del canale a [param s], [param di_lato] metri dall'asse (a destra positivo), sul fondo.
func _nel_canale(s: float, di_lato: float) -> Vector3:
	var q := sala.punto(s) + sala.destra(s) * di_lato
	return Vector3(q.x, sala.fondo + 0.02, q.z)


## La velocità orizzontale media in 1,5 s dopo 0,8 s di avvio, andando avanti lungo la strada.
func _misura(da: Vector3, s: float, azioni: Array) -> float:
	p.teleport(da, _yaw(sala.direzione(s)))
	await _frames(6)
	for a in azioni:
		Input.action_press(a)
	await _frames(48)
	var a0 := p.global_position
	await _frames(90)
	var a1 := p.global_position
	_rilascia()
	await _frames(20)
	return Vector2(a1.x - a0.x, a1.z - a0.z).length() / 1.5


# --- velocità ------------------------------------------------------------------------------------------------------

func _velocita() -> void:
	print("Velocità a guado")
	var s := 30.0
	var acqua := _nel_canale(s, 0.0)
	var cam := await _misura(acqua, s, [&"move_forward"])
	var cor := await _misura(acqua, s, [&"move_forward", &"sprint"])
	var acc := await _misura(acqua, s, [&"move_forward", &"crouch"])
	_controlla(absf(cam - 2.0) < 0.15, "nell'acqua camminando 2,0 m/s (%.2f)" % cam)
	_controlla(absf(cor - 2.0) < 0.15, "nell'acqua correndo 2,0 m/s (%.2f)" % cor)
	_controlla(absf(acc - 1.2) < 0.12, "nell'acqua accovacciati 1,2 m/s (%.2f)" % acc)
	var q := sala.punto(s) + sala.destra(s) * (sala.canale + sala.banchina * 0.5)
	var banchina := Vector3(q.x, sala.piano + 0.02, q.z)
	var bcam := await _misura(banchina, s, [&"move_forward"])
	var bcor := await _misura(banchina, s, [&"move_forward", &"sprint"])
	_controlla(absf(bcam - p.walk_speed) < 0.2, "sulla banchina si cammina come sempre (%.2f)" % bcam)
	_controlla(absf(bcor - p.run_speed) < 0.3, "sulla banchina si corre come sempre (%.2f)" % bcor)


# --- salto ---------------------------------------------------------------------------------------------------------

## Il salto: nell'acqua del canale non parte (in tre punti), sulla banchina sì.
func _salto() -> void:
	print("Salto")
	var nell_acqua := []
	var dentro := true
	for s in [30.0, 150.0, 420.0]:
		# (di lato, lontano dai gommoni sull'asse)
		p.teleport(_nel_canale(s, -(sala.canale - SalaSottomarino.GRADINO_LARGO - 0.6)))
		await _frames(30)
		dentro = dentro and p.in_acqua_senza_salto()
		var y0 := p.global_position.y
		var su := 0.0
		Input.action_press(&"jump")
		for i in 40:
			await get_tree().physics_frame
			su = maxf(su, p.global_position.y - y0)
		Input.action_release(&"jump")
		await _frames(20)
		nell_acqua.append(snappedf(su, 0.01))
	_controlla(dentro and nell_acqua.all(func(x): return x < 0.05), "nell'acqua del canale il salto non parte (salito %s m)" % str(nell_acqua))
	var q := sala.punto(60.0) + sala.destra(60.0) * (sala.canale + sala.banchina * 0.5)
	p.teleport(Vector3(q.x, sala.piano + 0.02, q.z))
	await _frames(20)
	var yb := p.global_position.y
	var sub := 0.0
	Input.action_press(&"jump")
	for i in 40:
		await get_tree().physics_frame
		sub = maxf(sub, p.global_position.y - yb)
	Input.action_release(&"jump")
	await _frames(30)
	_controlla(sub > 0.5, "sulla banchina si salta (%.2f m)" % sub)


# --- risalita ------------------------------------------------------------------------------------------------------

## Dal punto nel canale, verso la banchina dal lato [param lato]: solo avanti, senza saltare. Il tempo per stare in
## piedi sulla banchina, o -1.
func _esci(da: Vector3, s: float, lato: float) -> float:
	var verso := sala.destra(s) * lato
	p.teleport(da, _yaw(verso))
	await _frames(6)
	Input.action_press(&"move_forward")
	var t := 0.0
	var fuori := -1.0
	var i := 0
	while t < RISALITA_MAX:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		i += 1
		if p.is_on_floor() and p.global_position.y > sala.piano - 0.05:
			fuori = t
			break
	_rilascia()
	await _frames(10)
	return fuori


## Dove a [param s] sono crollate tutte e due le banchine: [da s, a s], altrimenti vuoto.
func _crollo(s: float) -> Array:
	if not (sala._lato(s, -1.0)["crollo"] and sala._lato(s, 1.0)["crollo"]):
		return []
	var a := s
	while a > 0.0 and sala._lato(a, -1.0)["crollo"] and sala._lato(a, 1.0)["crollo"]:
		a -= 0.25
	var b := s
	while b < sala.lunghezza() and sala._lato(b, -1.0)["crollo"] and sala._lato(b, 1.0)["crollo"]:
		b += 0.25
	return [a, b]


## A guado fino alla fine più vicina del crollo (o fino a [param fine_forzata], se data), poi sulla banchina, senza
## saltare: il tempo, o -1 (entro il tempo del guado più [constant RISALITA_MAX]).
func _esci_dal_crollo(da: Vector3, s: float, lato: float, crollo: Array, fine_forzata := -INF) -> float:
	var fine: float = fine_forzata if fine_forzata > -INF else (crollo[0] - 1.5 if s - float(crollo[0]) < float(crollo[1]) - s else crollo[1] + 1.5)
	# prima a guado fino a [param fine] (nel canale, davanti al gradino), poi sul gradino e sulla banchina
	var q0 := sala.punto(fine) + sala.destra(fine) * lato * (sala.canale - SalaSottomarino.GRADINO_LARGO - 0.4)
	var q := sala.punto(fine) + sala.destra(fine) * lato * (sala.canale + 1.0)
	var guado := Vector3(q0.x, sala.piano, q0.z)
	var meta := Vector3(q.x, sala.piano, q.z)
	p.teleport(da, _yaw(guado - da))
	await _frames(6)
	Input.action_press(&"move_forward")
	var limite := absf(fine - s) / 2.0 + RISALITA_MAX
	var t := 0.0
	var i := 0
	var fuori := -1.0
	while t < limite:
		if Vector2(guado.x - p.global_position.x, guado.z - p.global_position.z).length() < 0.3:
			guado = meta
		var d := guado - p.global_position
		p.set_look(_yaw(Vector3(d.x, 0.0, d.z)), p.pitch)
		await get_tree().physics_frame
		t += 1.0 / 60.0
		i += 1
		if p.is_on_floor() and p.global_position.y > sala.piano - 0.05:
			fuori = t
			break
	_rilascia()
	await _frames(10)
	return fuori


func _risalita() -> void:
	print("Risalita dal canale")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2410
	var lung := sala.lunghezza()
	var tempi: Array = []
	var bloccati: Array = []
	for k in PUNTI:
		# (tutto il canale: dalla presa all'approdo; i primi e gli ultimi punti fissi, nella presa e sotto il pontile)
		var s := rng.randf_range(0.5, lung - 1.0)
		if k == 0:
			s = 1.0
		elif k == 1:
			s = SalaSottomarino.PRESA_FINO - 1.0
		elif k == 2:
			s = lung - 2.0
		elif k == 3:
			s = lung - SalaSottomarino.BALLATOIO - 0.5
		var di_lato := rng.randf_range(-(sala.canale - SalaSottomarino.GRADINO_LARGO - 0.4), sala.canale - SalaSottomarino.GRADINO_LARGO - 0.4)
		var lato := 1.0 if di_lato >= 0.0 else -1.0
		var t := -1.0
		var crollo := _crollo(s)
		var fino_al_gradino := lung - SalaSottomarino.BALLATOIO - 2.5
		if s < SalaSottomarino.PRESA_FINO + 0.5:
			# nella presa il fondo scende: si va a guado fino a dove il fondo è quello del canale, poi sul gradino
			t = await _esci_dal_crollo(_nel_canale(s, di_lato), s, lato, [], SalaSottomarino.PRESA_FINO + 2.0)
		elif s > fino_al_gradino:
			# sotto il ballatoio e il pontile: indietro fino al gradino
			t = await _esci_dal_crollo(_nel_canale(s, di_lato), s, -1.0, [], fino_al_gradino - 1.0)
		elif crollo.is_empty():
			t = await _esci(_nel_canale(s, di_lato), s, lato)
			if t < 0.0:
				# dalla banchina di fronte (dove un ostacolo chiude la più vicina)
				t = await _esci(_nel_canale(s, di_lato), s, -lato)
		else:
			# sotto una galleria di servizio le due banchine sono crollate: si va a guado fino alla fine del crollo
			t = await _esci_dal_crollo(_nel_canale(s, di_lato), s, lato, crollo)
		if t < 0.0:
			bloccati.append(snappedf(s, 0.1))
		else:
			tempi.append(t)
	tempi.sort()
	var peggio: float = tempi.back() if not tempi.is_empty() else -1.0
	_controlla(bloccati.is_empty(), "da %d punti del canale (presa e approdo compresi) si risale camminando, senza saltare, in meno di %.0f s più il guado (peggiore %.1f s)%s" % [
			PUNTI, RISALITA_MAX, peggio, "" if bloccati.is_empty() else "; bloccati a s " + str(bloccati)])


# --- di sbieco ------------------------------------------------------------------------------------------------------

## Vero se la banchina dal lato [param lato] fra [param a] e [param b] (più 1,5 m) ha un ostacolo: lì non si sale.
func _ostacolo(lato: float, a: float, b: float) -> bool:
	for o in sala.ostacoli:
		if float(o["lato"]) == lato and float(o["s"]) < maxf(a, b) + 1.5 and float(o["s"]) + float(o["lungo"]) > minf(a, b) - 1.5:
			return true
	return false


## Da [param da] (a [param s]) avanti verso la banchina dal lato [param lato], a [param ang] gradi dalla perpendicolare
## alla riva ([param avanti] 1 in avanti lungo la strada, -1 indietro), tenendo l'angolo con la riva anche in curva, senza
## saltare: il tempo per stare in piedi sulla banchina, o -1 dopo il doppio di [constant SBIECO_MAX] secondi.
func _cammina_verso(da: Vector3, s: float, lato: float, ang: float, avanti: float) -> float:
	var c := cos(deg_to_rad(ang))
	var sn := sin(deg_to_rad(ang)) * avanti
	p.teleport(da, _yaw(sala.destra(s) * lato * c + sala.direzione(s) * sn))
	await _frames(6)
	Input.action_press(&"move_forward")
	var t := 0.0
	var fuori := -1.0
	var s_p := s
	while t < SBIECO_MAX * 2.0:
		s_p = float(sala.proietta_vicino(p.global_position, s_p)[0])
		p.set_look(_yaw(sala.destra(s_p) * lato * c + sala.direzione(s_p) * sn), p.pitch)
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if p.is_on_floor() and p.global_position.y > sala.piano - 0.05:
			fuori = t
			break
	_rilascia()
	await _frames(10)
	return fuori


func _sbieco() -> void:
	print("Uscite di sbieco")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2525
	var lung := sala.lunghezza()
	var da_s := SalaSottomarino.PRESA_FINO + 8.0
	var a_s := lung - SalaSottomarino.BALLATOIO - 10.0
	var prove := 0
	var voluti := 0
	var peggio := 0.0
	var bloccati: Array = []
	var punti := 0
	while punti < SBIECO_PUNTI:
		var s := rng.randf_range(da_s, a_s)
		var di_lato := rng.randf_range(-(sala.canale - SalaSottomarino.GRADINO_LARGO - 0.4), sala.canale - SalaSottomarino.GRADINO_LARGO - 0.4)
		var lato := 1.0 if di_lato >= 0.0 else -1.0
		# (dove la banchina più vicina è crollata si guada fino alla fine del crollo: lo prova la risalita)
		if sala._lato(s, lato)["crollo"]:
			continue
		var da := _nel_canale(s, di_lato)
		# (non dentro un gommone: lì si sale sul gommone)
		var sul_gommone := false
		for g in sala.find_children("Gommone", "AnimatableBody3D", true, false):
			var gp := (g as Node3D).global_position
			sul_gommone = sul_gommone or Vector2(gp.x - da.x, gp.z - da.z).length() < 2.5
		if sul_gommone:
			continue
		punti += 1
		var largo := sala.canale - di_lato * lato      # fino al bordo della banchina
		for ang: float in SBIECO_ANGOLI:
			for avanti: float in [1.0, -1.0]:
				var arrivo := s + avanti * largo * tan(deg_to_rad(ang))
				if _ostacolo(lato, s, arrivo):
					voluti += 1
					continue
				prove += 1
				var t := await _cammina_verso(da, s, lato, ang, avanti)
				if t < 0.0 or t > SBIECO_MAX:
					bloccati.append("s %.1f lato %+d %d° %s (%s, a %.2f sopra il fondo)" % [s, int(lato), int(ang), "avanti" if avanti > 0.0 else "indietro",
							"%.1f s" % t if t > 0.0 else "fermo", p.global_position.y - sala.fondo])
				else:
					peggio = maxf(peggio, t)
	_controlla(bloccati.is_empty(), "di sbieco (30°, 45°, 60°, avanti e indietro) da %d punti si esce camminando entro %.0f s: %d prove, peggiore %.1f s (%d contro un ostacolo della banchina, non contano)%s" % [
			SBIECO_PUNTI, SBIECO_MAX, prove, peggio, voluti, "" if bloccati.is_empty() else "; bloccati: " + ", ".join(bloccati)])


# --- aspirazione ---------------------------------------------------------------------------------------------------

## Aspira per [param secondi] guardando [param dove]; i litri entrati.
func _aspira(da: Vector3, dove: Vector3, secondi: float) -> float:
	var pack := p.water_pack
	pack.set_tank_amount(0.0)
	p.teleport(da)
	await _frames(6)
	p.look_at_point(dove)
	await _frames(4)
	Input.action_press(&"suck")
	await _frames(int(secondi * 60.0))
	Input.action_release(&"suck")
	await _frames(10)
	return pack.tank_amount


func _aspirazione() -> void:
	print("Aspirazione dal canale")
	var pack := p.water_pack
	var rng := RandomNumberGenerator.new()
	rng.seed = 2411
	var lung := sala.lunghezza()
	var vuoti: Array = []
	for k in 8:
		var s := rng.randf_range(SalaSottomarino.PRESA_FINO + 4.0, lung - 6.0)
		var lato := 1.0 if k % 2 == 0 else -1.0
		# dal canale, guardando l'acqua davanti ai piedi
		var a := _nel_canale(s, lato * 0.8)
		var l1 := await _aspira(a, a + sala.direzione(s) * 1.2 + Vector3.UP * 0.5, 1.0)
		# dalla banchina, a un metro dal bordo, guardando l'acqua del canale
		var qb := sala.punto(s) + sala.destra(s) * lato * (sala.canale + 1.0)
		var b := Vector3(qb.x, sala.piano + 0.02, qb.z)
		var qa := sala.punto(s) + sala.destra(s) * lato * (sala.canale - 0.8)
		var l2 := await _aspira(b, Vector3(qa.x, sala.acqua, qa.z), 1.0)
		if l1 < 3.0 or l2 < 3.0:
			vuoti.append("s %.0f: canale %.1f l, banchina %.1f l" % [s, l1, l2])
	_controlla(vuoti.is_empty(), "lo zaino aspira dal canale e dalla banchina in 8 punti a caso %s" % str(vuoti))
	# l'acqua non finisce: tre serbatoi pieni di fila dallo stesso punto
	var s0 := 60.0
	var a0 := _nel_canale(s0, 0.6)
	var pieni := 0
	for k in 3:
		var l := await _aspira(a0, a0 + sala.direzione(s0) * 1.2 + Vector3.UP * 0.5, pack.tank_capacity / pack.suck_rate + 1.0)
		if l >= pack.tank_capacity - 0.01:
			pieni += 1
	_controlla(pieni == 3, "l'acqua del canale non finisce: 3 serbatoi pieni di fila dallo stesso punto (%d)" % pieni)
