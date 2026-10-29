extends Node
## Test della nebbia viola per zona (ZonaNebbiaViola, NebbiaViola.quanto di Grafica), senza schermo:
## - fuori dalle zone è spenta e non si disegna (quad e colore nascosti);
## - entrando sale piano (non tutta nel primo fotogramma, piena dopo [member NebbiaViolaProva.durata]), uscendo scende;
## - due zone sovrapposte (ambienti a pezzi): passando dall'una all'altra non cala;
## - con un salto della camera dentro la zona (checkpoint) è subito piena; una zona che nasce col giocatore dentro, anche;
## - l'opzione "Nebbia viola" spenta dentro la zona: scende piano e non si disegna più; riaccesa sale piano;
## - l'alone: fino a 4 lampade della zona davanti alla camera, prima la luce del gruppo dell'alone (lei); una lampada
##   che esce dall'alone si spegne piano, non di colpo;
## - le zone del gioco: l'infermeria, la sala principale e il tunnel dell'inseguimento ne hanno una.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_zona_nebbia.gd

var ok := 0
var falliti := 0
var corpo: Player
var cam: Camera3D
var n: NebbiaViola


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	corpo = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(corpo)
	corpo.set_physics_process(false)      # (lo muove il test)
	cam = corpo.camera
	GameState.player = corpo
	cam.make_current()
	Grafica.salva_su_disco = false
	n = Grafica.nebbia_viola
	n.quanto = 0.0
	var z1 := _zona(Vector3(0, 0, -20), Vector3(10, 6, 10))
	var z2 := _zona(Vector3(0, 0, -29), Vector3(10, 6, 10))
	await _per(0.3)
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

	await _opzione()
	await _alone()
	await _zone_del_gioco()
	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


## L'opzione cambiata dentro la zona (dalla pausa): scende e sale piano, come uscendo ed entrando.
func _opzione() -> void:
	corpo.global_position = Vector3(0, 0, -100)
	var z := _zona(Vector3(0, 0, -100), Vector3(8, 6, 8))
	await _per(0.3)
	var piena := n.quanto
	Grafica.imposta("nebbia_viola", false)
	await _per(0.5)
	var scende := n.quanto
	await _per(3.0)
	var spenta := n.quanto == 0.0 and not n._quad.visible and not n._strato.visible
	Grafica.imposta("nebbia_viola", true)
	await _per(0.5)
	var sale := n.quanto
	await _per(3.0)
	_controlla(piena == 1.0 and scende > 0.6 and scende < 1.0 and spenta and sale > 0.0 and sale < 0.4 and n.quanto == 1.0,
			"spenta dalle opzioni dentro la zona scende piano e non si disegna; riaccesa sale piano", [piena, scende, spenta, sale, n.quanto])
	z.queue_free()
	await _per(0.1)


## L'alone: 6 lampade nella zona davanti alla camera e la luce di lei (gruppo dell'alone) più lontana: lei e le 3 lampade
## più vicine; spenta una lampada scelta, la sua parte cala piano.
func _alone() -> void:
	var radice := Node3D.new()
	add_child(radice)
	corpo.global_position = Vector3(0, 0, -150)
	corpo.rotation = Vector3.ZERO
	cam.rotation = Vector3.ZERO
	var lampade: Array[OmniLight3D] = []
	for i in 6:
		var l := OmniLight3D.new()
		l.light_color = Color(0.2 * i, 1.0, 0.5)
		l.position = Vector3(0, 2.5, -150.0 - 2.0 - i * 2.0)
		radice.add_child(l)
		lampade.append(l)
	var lei := OmniLight3D.new()
	lei.add_to_group(NebbiaViola.GRUPPO_ALONE)
	lei.position = Vector3(1, 1.5, -150.0 - 14.0)
	add_child(lei)
	var dietro := OmniLight3D.new()
	dietro.position = Vector3(0, 2.5, -150.0 + 3.0)
	radice.add_child(dietro)
	var z := _zona(Vector3(0, 0, -155), Vector3(10, 6, 20))
	z.luci = [z.get_path_to(radice)]
	await _per(1.5)
	var scelte: Array = n._slot.map(func(s): return s[0])
	var attese := [lei, lampade[0], lampade[1], lampade[2]]
	var tutte := attese.all(func(l): return scelte.has(l))
	_controlla(tutte and not scelte.has(dietro) and n._slot.all(func(s): return s[1] == 1.0),
			"l'alone: prima la luce di lei, poi le 3 lampade più vicine davanti (non quella dietro)", [scelte])
	# spenta la lampada più vicina: non sparisce di colpo dall'alone
	lampade[0].visible = false
	await _per(0.05)
	var i0 := scelte.find(lampade[0])
	var c0 := (n._mat.get_shader_parameter(&"luci_col") as PackedVector3Array)[i0]
	_controlla(c0 == Vector3.ZERO, "una lampada spenta (sfarfallio) non fa più alone", [c0])
	lampade[0].visible = true
	lampade[0].position.z = -150.0 - 30.0     # lontana: esce dall'alone
	await _per(0.25)
	var peso: float = n._slot[i0][1] if n._slot[i0][0] == lampade[0] else -1.0
	await _per(1.0)
	_controlla(peso > 0.2 and peso < 1.0 and n._slot.any(func(s): return s[0] == lampade[3]),
			"una lampada che esce dall'alone cala piano e una nuova prende il suo posto", [peso])
	z.queue_free()
	radice.queue_free()
	lei.queue_free()
	await _per(0.1)


## Le zone vere: l'infermeria, la sala principale e il tunnel dell'inseguimento.
func _zone_del_gioco() -> void:
	var inf: Node3D = (load("res://scenes/risalita/infermeria.tscn") as PackedScene).instantiate()
	add_child(inf)
	await _per(0.1)
	var zi := inf.find_child("NebbiaViola", false, false) as ZonaNebbiaViola
	_controlla(zi != null, "l'infermeria ha la zona della nebbia viola", [zi])
	inf.queue_free()
	var sp := SalaSottomarino.new()
	add_child(sp)
	sp.costruisci()
	var zt := sp.find_child("NebbiaViola", false, false) as ZonaNebbiaViola
	var dentro := zt != null
	if zt:
		# dalla testa al portello, sulle banchine (e mai fuori dai muri)
		var punti := [-4.0, 0.0, 30.0, sp.lunghezza() * 0.5, sp.lunghezza() - 1.0]
		await get_tree().physics_frame
		for s in punti:
			var p := sp.punto(s) - sp.destra(s) * (sp.canale + sp.banchina * 0.5)
			dentro = dentro and _in_zona(zt, Vector3(p.x, sp.piano + 1.0, p.z))
		var fuori := sp.punto(20.0) + sp.destra(20.0) * (sp.muro + 1.0)
		dentro = dentro and not _in_zona(zt, Vector3(fuori.x, sp.piano + 1.0, fuori.z))
	_controlla(dentro, "il tunnel ha la zona della nebbia viola dalla testa al portello, fra i muri", [zt != null])
	sp.queue_free()
	var sala := load("res://scripts/game/sala_principale.gd")
	_controlla(sala != null and sala.NEBBIA_SALA.has_point(Vector3(0, 1, 19)) and sala.NEBBIA_SALA.has_point(Vector3(0, 1, 10))
			and not sala.NEBBIA_SALA.has_point(Vector3(-9.7, 1, 40)) and not sala.NEBBIA_SALA.has_point(Vector3(30, 1, -15))
			and (sala as GDScript).source_code.contains("_nebbia_viola()"),
			"la sala principale ha la zona della nebbia viola (dentro l'ingresso e la vasca, fuori gli interni e la torre)")


func _in_zona(z: ZonaNebbiaViola, p: Vector3) -> bool:
	for c in z.get_children():
		var cs := c as CollisionShape3D
		if cs and (cs.shape as BoxShape3D):
			var loc := (z.global_transform * cs.transform).affine_inverse() * p
			var h := (cs.shape as BoxShape3D).size * 0.5
			if absf(loc.x) <= h.x and absf(loc.y) <= h.y and absf(loc.z) <= h.z:
				return true
	return false


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
