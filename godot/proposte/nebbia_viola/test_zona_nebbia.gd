extends Node
## Test della nebbia viola per zona (ZonaNebbiaViola, NebbiaViolaProva.quanto), senza schermo:
## - fuori dalle zone è spenta e non si disegna (quad e colore nascosti);
## - entrando sale piano (non tutta nel primo fotogramma, piena dopo [member NebbiaViolaProva.durata]), uscendo scende;
## - due zone sovrapposte (ambienti a pezzi): passando dall'una all'altra non cala;
## - con un salto della camera dentro la zona (checkpoint) è subito piena; una zona che nasce col giocatore dentro, anche.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://proposte/nebbia_viola/test_zona_nebbia.gd

var ok := 0
var falliti := 0
var corpo: Player
var cam: Camera3D
var n: NebbiaViolaProva


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	corpo = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(corpo)
	corpo.set_physics_process(false)      # (lo muove il test)
	cam = corpo.camera
	GameState.player = corpo
	n = NebbiaViolaProva.new()
	add_child(n)
	n.su(cam)
	n.quanto = 0.0
	var z1 := _zona(Vector3(0, 0, -20), Vector3(10, 6, 10))
	var z2 := _zona(Vector3(0, 0, -29), Vector3(10, 6, 10))
	await _per(0.3)
	n.zona(null, false)          # (come fa la prima zona in gioco: da qui conta solo dove sei)
	await _per(0.2)
	_controlla(n.quanto == 0.0 and not n._quad.visible and not n._strato.visible, "fuori è spenta e non si disegna",
			[n.quanto, n._quad.visible])

	# entra camminando
	await _cammina(Vector3(0, 0, -16), 6)
	await _per(0.1)
	var presto := n.quanto
	await _per(1.2)
	var meta := n.quanto
	await _per(2.5)
	_controlla(presto > 0.0 and presto < 0.15 and meta > 0.3 and meta < 0.7 and n.quanto == 1.0 and n._quad.visible,
			"entrando sale piano fino a piena", [presto, meta, n.quanto])

	# nella zona accanto (sovrapposta): non cala
	var lo := 1.0
	for i in 40:
		corpo.global_position = Vector3(0, 0, -16.0 - i * 0.4)
		await get_tree().physics_frame
		lo = minf(lo, n.quanto)
	_controlla(lo == 1.0, "da una zona all'altra non cala", [lo])

	# esce
	await _cammina(Vector3(0, 0, -36), 6)
	await _per(0.3)
	var scende := n.quanto
	await _per(3.5)
	_controlla(scende < 1.0 and scende > 0.6 and n.quanto == 0.0 and not n._quad.visible,
			"uscendo scende piano e si spegne", [scende, n.quanto])

	# checkpoint dentro la zona: subito piena
	corpo.global_position = Vector3(0, 0, -20)
	await _per(0.15)
	_controlla(n.quanto == 1.0, "ripartendo da un checkpoint dentro è subito piena", [n.quanto])
	corpo.global_position = Vector3(0, 0, 40)
	await _per(0.15)
	_controlla(n.quanto == 0.0, "ripartendo fuori è subito spenta", [n.quanto])

	# zona costruita col giocatore già dentro
	z1.queue_free()
	z2.queue_free()
	await _per(0.1)
	var z3 := _zona(Vector3(0, 0, 40), Vector3(8, 6, 8))
	await _per(0.15)
	_controlla(n.quanto == 1.0, "una zona che nasce col giocatore dentro è subito piena", [n.quanto])
	z3.queue_free()
	await _per(0.2)
	_controlla(n.quanto < 1.0, "togliendo la zona scende", [n.quanto])

	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


func _zona(dove: Vector3, misure: Vector3) -> ZonaNebbiaViola:
	var z := ZonaNebbiaViola.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = misure
	cs.shape = b
	z.add_child(cs)
	z.position = dove
	add_child(z)
	return z


## A piedi fino a [param a], a [param v] m/s (niente salti).
func _cammina(a: Vector3, v: float) -> void:
	while corpo.global_position.distance_to(a) > 0.05:
		await get_tree().physics_frame
		corpo.global_position = corpo.global_position.move_toward(a, v / Engine.physics_ticks_per_second)


func _per(secondi: float) -> void:
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
