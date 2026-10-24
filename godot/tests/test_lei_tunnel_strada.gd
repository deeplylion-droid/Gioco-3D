extends Node
## Test di lei lungo la strada vera del tunnel del viaggio sottomarino (SalaSottomarino di ambienti-2, la collisione
## costruita da sottomarino_strada.json): riemerge dalla presa, insegue lungo tutti i 552 m a velocità diverse (ferma,
## al passo, di corsa, a scatti), si ritrae a qualche getto in faccia (indietro di 6 m), e alla fine sbatte sull'oblò
## del portello. Controlla con tests/misura_morbidezza.gd che nessun tratto dei tentacoli attraversi la collisione del
## tunnel e che la pelle vera (corpo e tentacoli) non ci entri.
## Senza scripts/game/sala_sottomarino.gd (prima di unire lavoro/sottomarino) il test non fa niente ed esce con 0.
## Uso: godot --headless --path godot --fixed-fps 30 --script res://tests/run.gd -- res://tests/test_lei_tunnel_strada.gd
## (DA=s0 A=s1: solo quel tratto di strada, per provare.)

const Misura := preload("res://tests/misura_morbidezza.gd")
const SALA := "res://scripts/game/sala_sottomarino.gd"
## Il centro dell'oblò dalla sua parte e la normale verso di lei (ambienti-2, 24 ottobre).
const OBLO := Vector3(-57.0, -25.70, 22.0)
const OBLO_NORMALE := Vector3(0, 0, 1)
## Le velocità di lei lungo la strada (m/s), a tratti: [fino a s, velocità] (0,4: quasi ferma; mai 0, o non arriva in fondo).
const VELOCITA := [[60.0, 4.6], [120.0, 6.5], [140.0, 0.4], [240.0, 3.4], [330.0, 7.0], [380.0, 2.0], [600.0, 5.0]]
## Dove la colpisce un getto in faccia (s): si ritrae e la logica la rimanda indietro di 6 m.
const GETTI := [90.0, 200.0, 310.0, 420.0, 500.0]

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


func _velocita(s: float) -> float:
	for v in VELOCITA:
		if s < float(v[0]):
			return float(v[1])
	return 5.0


func _run() -> void:
	if not ResourceLoader.exists(SALA):
		print("manca ", SALA, ": niente da provare")
		print("RISULTATO: 0 controlli ok, 0 falliti")
		get_tree().quit(0)
		return
	Game.pause_on_focus_loss = false
	var sala: Node3D = (load(SALA) as GDScript).new()
	add_child(sala)
	sala.call(&"costruisci")
	var lung: float = sala.call(&"lunghezza")
	var acqua: float = sala.get(&"acqua")
	var da := float(OS.get_environment("DA")) if OS.has_environment("DA") else -1.0
	# (mai oltre la fine della strada: dopo c'è il portello)
	var fino := minf(float(OS.get_environment("A")) if OS.has_environment("A") else lung, lung - 2.5)
	var giocatore: Node3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(giocatore)
	giocatore.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.player = giocatore as Player
	var lt := LeiTunnel.new()
	add_child(lt)
	for i in 3:
		await get_tree().process_frame
	# le forme del tunnel per i tentacoli (FormeTunnel di grafica), come nel gioco; senza (prima di unire), solo la posa
	const FORME := "res://scripts/environment/forme_tunnel.gd"
	if ResourceLoader.exists(FORME):
		var ft := load(FORME) as GDScript
		print("forme del tunnel: ", ft.call(&"prepara", sala))
		ft.call(&"aggiungi", lt.morbidezza, sala)
	var sk := lt.lei.get_model_instance().find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mis = Misura.new(sk, lt.morbidezza)
	mis.inizia()
	var s := da
	lt.riemergi(sala.call(&"punto", s), sala.call(&"direzione", maxf(s, 0.0)), acqua - float(sala.call(&"fondo_a", s)))
	var getti := GETTI.duplicate()
	var t := 0.0
	var max_alto := -INF
	var min_basso := INF
	while s < fino:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if lt.stato == LeiTunnel.Stato.INSEGUE or lt.stato == LeiTunnel.Stato.RITRAE:
			s += _velocita(s) * dt * (0.3 if lt.in_ritrae() else 1.0)
		if lt.stato == LeiTunnel.Stato.INSEGUE and not getti.is_empty() and s >= float(getti[0]):
			getti.pop_front()
			lt.respinta()
			s -= 6.0
		lt.vai(sala.call(&"punto", s), sala.call(&"direzione", maxf(s, 0.0)), dt)
		# il giocatore sulla banchina destra, 8-14 m avanti (a tratti vicino: morde)
		var avanti := 6.0 if fmod(t, 20.0) < 4.0 else 12.0
		giocatore.global_position = (sala.call(&"punto", s + avanti) as Vector3) + (sala.call(&"destra", s + avanti) as Vector3) * 4.8 \
			+ Vector3.UP * 0.42
		var occhio := lt.lei.get_eye_position()
		if occhio != Vector3.ZERO:
			max_alto = maxf(max_alto, occhio.y)
		min_basso = minf(min_basso, lt.global_position.y)
	_check(t > 1.0, "lei ha inseguito per %.0f s fino a s %.0f" % [t, s])
	# lo schianto sul portello
	var finito := [false]
	lt.schianto_finito.connect(func(): finito[0] = true)
	if fino >= lung - 3.0:
		lt.schianto(OBLO, OBLO_NORMALE)
		var t2 := 0.0
		while t2 < 3.0:
			await get_tree().physics_frame
			t2 += get_physics_process_delta_time()
		_check(finito[0], "lo schianto sul portello è arrivato in fondo")
	mis.ferma()
	var r: Dictionary = mis.risultati("strada")
	_check(r["attraversa"] == 0, "nessun tratto dei tentacoli attraversa il tunnel (%d)" % r["attraversa"])
	var pe: Dictionary = mis.pelle("strada", 0, 2, 0.01)
	_check(pe["pelle_dentro"] == 0, "la pelle vera fuori dal tunnel (%d vertici, al più %.1f cm)" % [pe["pelle_dentro"], pe["pelle_massimo"] * 100.0])
	print("  (l'occhio al più a %.2f; l'origine al più in basso a %.2f, l'acqua a %.2f)" % [max_alto, min_basso, acqua])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
