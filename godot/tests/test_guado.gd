extends Node
## Test del guado nel canale del tunnel sottomarino (SalaSottomarino), col Player vero e gli input simulati.
## Le scelte del 24 ottobre (GDD "Il tunnel del viaggio sottomarino" e coordinatore): "Se finisci in acqua sei
## rallentato ma puoi risalire e proseguire saltando".
## - velocità: nell'acqua 2,0 m/s camminando e correndo, 1,2 accovacciati; sulla banchina le solite;
## - risalita: da 20 punti a caso del canale si torna sulla banchina più vicina col salto vero in pochi secondi
##   ("Se cadi nella piscinetta della stanza generatori non puoi uscire": dall'acqua si esce sempre);
## - aspirazione: dal canale e dalla banchina lo zaino si riempie dovunque, e l'acqua non finisce.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_guado.gd

const PLAYER := "res://scenes/player/player.tscn"
## Entro quanti secondi si deve essere fuori dall'acqua.
const RISALITA_MAX := 6.0
const PUNTI := 20

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
	await _velocita()
	await _risalita()
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


# --- risalita ------------------------------------------------------------------------------------------------------

## Dal punto nel canale, verso la banchina dal lato [param lato]: avanti e salto ogni tanto. Il tempo per stare in
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
		# un salto ogni 0,5 s, tenuto premuto 3 tick (come chi preme il tasto)
		if i % 30 == 0:
			Input.action_press(&"jump")
		elif i % 30 == 3:
			Input.action_release(&"jump")
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
		var s := rng.randf_range(SalaSottomarino.PRESA_FINO + 4.0, lung - 6.0)
		var di_lato := rng.randf_range(-(sala.canale - 0.45), sala.canale - 0.45)
		var lato := 1.0 if di_lato >= 0.0 else -1.0
		var t := await _esci(_nel_canale(s, di_lato), s, lato)
		if t < 0.0:
			# dalla banchina di fronte (dove un ostacolo chiude la più vicina)
			t = await _esci(_nel_canale(s, di_lato), s, -lato)
		if t < 0.0:
			bloccati.append(snappedf(s, 0.1))
		else:
			tempi.append(t)
	tempi.sort()
	var peggio: float = tempi.back() if not tempi.is_empty() else -1.0
	_controlla(bloccati.is_empty(), "da %d punti a caso del canale si risale in meno di %.0f s (peggiore %.1f s)%s" % [
			PUNTI, RISALITA_MAX, peggio, "" if bloccati.is_empty() else "; bloccati a s " + str(bloccati)])


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
