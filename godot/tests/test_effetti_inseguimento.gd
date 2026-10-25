extends Node
## Test degli effetti dell'inseguimento nel tunnel (EffettiInseguimento), senza schermo: un bersaglio finto va lungo la
## banchina alla velocità di lei, così la distanza resta quella voluta.
## - lontana (12 m): bordi chiari, la luce rosa accesa che guarda davanti al giocatore, nessun tremito;
## - a 5 m: i bordi scuri ma leggeri (sotto il massimo), la camera trema ai morsi;
## - a 3 m: i bordi al massimo, mai oltre;
## - dopo un morso la camera torna esattamente a posto; con l'oscillazione della camera spenta non trema;
## - la distanza di lei non cambia con gli effetti (corri: sempre fra 8 e 18 m);
## - quando lei ti prende o sparisce, tutto si spegne.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_effetti_inseguimento.gd

const PLAYER := "res://scenes/player/player.tscn"

var ok := 0
var falliti := 0
var sala: SalaSottomarino
var e: EffettiInseguimento
var b: Node3D
var pl: Player
var morsi := 0
var s := 0.0
var v := 0.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	sala = SalaSottomarino.new()
	get_tree().root.add_child(sala)
	sala.costruisci()
	sala.vantaggio = 0.0
	e = sala.effetti
	_controlla(e != null and e.get_parent() == sala, "la sala crea gli effetti con lei", [e])
	pl = (load(PLAYER) as PackedScene).instantiate()
	get_tree().root.add_child(pl)
	pl.process_mode = Node.PROCESS_MODE_DISABLED
	pl.global_position = Vector3(0, 200, 0)
	GameState.player = pl
	b = Node3D.new()
	add_child(b)
	sala.bersaglio = b
	sala.lei_morde.connect(func(): morsi += 1)

	# 1) lontana, 12 m
	await _insegui(60.0, 12.0, 3.0)
	var gap := sala._s_bersaglio - sala.lei_s
	var dir_luce := -e.luce.global_transform.basis.z
	var a := sala.punto(sala._s_bersaglio + e.luce_avanti)
	a.y = sala.acqua + 0.6
	var verso_avanti := (a - e.luce.global_position).normalized()
	_controlla(e.bordi.modulate.a < 0.01, "a %.1f m i bordi restano chiari" % gap, [e.bordi.modulate.a])
	_controlla(e.luce.visible and e.luce.light_energy > 1.0 and dir_luce.dot(verso_avanti) > 0.97,
			"la luce rosa è accesa e guarda la strada davanti al giocatore",
			[e.luce.visible, e.luce.light_energy, dir_luce.dot(verso_avanti)])
	_controlla(e.luce.global_position.distance_to(sala.lei.global_transform * EffettiInseguimento.LUCE_DA) < 0.3,
			"la luce nasce da lei", [e.luce.global_position])
	_controlla(morsi == 0 and pl.camera.rotation == Vector3.ZERO, "lontana niente morsi né tremito", [morsi, pl.camera.rotation])

	# 2) a 5 m: bordi leggeri, morsi e tremito
	morsi = 0
	var mosso := 0.0
	var lo := INF
	var hi := 0.0
	await _insegui(120.0, 5.0, 0.1)
	var t := 0.0
	while t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		_avanti()
		mosso = maxf(mosso, pl.camera.rotation.length())
		if t > 2.0:
			lo = minf(lo, e.bordi.modulate.a)
			hi = maxf(hi, e.bordi.modulate.a)
	gap = sala._s_bersaglio - sala.lei_s
	_controlla(lo > 0.25 and hi < e.bordi_max - 0.02, "a %.1f m i bordi si scuriscono ma non del tutto" % gap, [lo, hi])
	_controlla(morsi > 0 and mosso > deg_to_rad(0.1) and mosso <= deg_to_rad(e.tremito_gradi) * 1.3,
			"a ogni morso la camera trema appena", ["morsi %d, max %.2f gradi" % [morsi, rad_to_deg(mosso)]])

	# 3) a 3 m: al massimo, mai oltre
	await _insegui(200.0, 3.0, 2.5)
	_controlla(e.bordi.modulate.a > e.bordi_max * 0.85 and e.bordi.modulate.a <= e.bordi_max + 0.001,
			"a 3 m i bordi sono al massimo (%.2f)" % e.bordi_max, [e.bordi.modulate.a])

	# 4) dopo il morso la camera torna esattamente a posto
	await _insegui(260.0, 12.0, 0.1)
	e.morso()
	await _per(0.1)
	var durante := pl.camera.rotation.length()
	await _per(0.5)
	_controlla(durante > 0.0 and pl.camera.rotation == Vector3.ZERO and pl.camera.position == Vector3.ZERO,
			"dopo il morso la camera torna esattamente a posto", [durante, pl.camera.rotation, pl.camera.position])
	# 5) oscillazione della camera spenta: niente tremito
	pl.head_bob_enabled = false
	e.morso()
	await _per(0.1)
	_controlla(pl.camera.rotation == Vector3.ZERO, "con l'oscillazione della camera spenta non trema", [pl.camera.rotation])
	pl.head_bob_enabled = true

	# 6) la distanza non cambia: corri a 5,8 m/s per 25 s
	await _insegui(20.0, 8.0, 0.1)
	v = 5.8
	lo = INF
	hi = 0.0
	t = 0.0
	while t < 25.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		_avanti()
		var g := sala._s_bersaglio - sala.lei_s
		if t > 3.0:
			lo = minf(lo, g)
			hi = maxf(hi, g)
	_controlla(lo >= 7.5 and hi <= 18.6, "con gli effetti se corri lei resta fra 8 e 18 m", ["min %.1f max %.1f" % [lo, hi]])

	# 7) presa e sparita: tutto spento
	await _insegui(300.0, 3.0, 1.5)
	e.morso()
	await _per(0.05)
	sala._prendi()
	await get_tree().process_frame
	_controlla(pl.camera.rotation == Vector3.ZERO, "quando ti prende la camera è subito libera", [pl.camera.rotation])
	sala.lei_tunnel.via()
	sala.lei_stato = SalaSottomarino.Lei.VIA
	await _per(4.0)
	_controlla(e.bordi.modulate.a < 0.01 and not e.bordi.visible and not e.luce.visible,
			"quando lei non c'è i bordi e la luce si spengono", [e.bordi.modulate.a, e.luce.visible])

	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


## Lei a [param dietro] metri dal bersaglio, che parte da [param s0] alla velocità di lei; aspetta [param secondi].
func _insegui(s0: float, dietro: float, secondi: float) -> void:
	s = s0
	v = sala.velocita_lei
	_metti()
	sala._s_bersaglio = s
	sala.lei_tunnel.via()
	sala.lei_stato = SalaSottomarino.Lei.VIA
	sala.insegui_da(s0 - dietro)
	await _per(secondi)


func _per(secondi: float) -> void:
	var t := 0.0
	while t < secondi:
		await get_tree().process_frame
		t += get_process_delta_time()
		_avanti()


func _avanti() -> void:
	s += v * get_process_delta_time()
	_metti()


func _metti() -> void:
	var p := sala.punto(s) - sala.destra(s) * (sala.canale + sala.banchina * 0.5)
	b.global_position = Vector3(p.x, sala.piano, p.z)


func _controlla(cond: bool, cosa: String, dove: Array) -> void:
	if cond:
		ok += 1
		print("  ok      " + cosa)
	else:
		falliti += 1
		print("  FALLITO " + cosa + ": " + str(dove))
