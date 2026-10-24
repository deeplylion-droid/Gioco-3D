extends Node
## Test dell'infermeria del gioco (scenes/risalita/infermeria.tscn, aspetto B), nella scena di prova
## tests/scene/infermeria_gioco_prova.tscn: la catena dei 4 passi, simulando il getto e il tasto E
## guardando gli oggetti (così si prova anche che si raggiungono), e i checkpoint dopo ogni passo.
## 1. All'inizio il negatoscopio sfarfalla, la cassaforte è chiusa e la keycard non si prende.
## 2. Col getto sull'interruttore il negatoscopio si accende.
## 3. Solo un cassetto ha l'adesivo rosa; aperto, dentro c'è la radiografia, che si prende.
## 4. La radiografia sul negatoscopio: si vedono i puntini, 4, 1 e 7.
## 5. La cassaforte: un codice sbagliato non la apre, 4-1-7 sì; dentro la keycard e la Polaroid.
## 6. Checkpoint: tutto resta com'era (negatoscopio acceso con la radiografia, cassaforte aperta,
##    keycard nell'inventario e non più nella cassaforte).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_infermeria_gioco.gd

const SCENA := "res://tests/scene/infermeria_gioco_prova.tscn"

var level: Node
var p: Player
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(SCENA)
	await _aspetta_livello()
	var inf := level.get_node(^"Infermeria")
	var neg := inf.get_node(^"Negatoscopio") as Negatoscopio
	var cassa := inf.get_node(^"Cassaforte") as CassaforteRotelle
	var inter := inf.get_node(^"Interruttore") as WaterButton
	var keycard := inf.get_node(^"Keycard") as Pickup
	check(neg != null and cassa != null and inter != null, "ci sono negatoscopio, cassaforte e interruttore")
	if neg == null or cassa == null or inter == null:
		_fine()
		return

	print("1. All'inizio")
	check(not neg.e_acceso(), "il negatoscopio sfarfalla (senza corrente)")
	check(not cassa.aperta_ora and not keycard.can_interact(p), "la cassaforte è chiusa e la keycard non si prende")

	print("2. Il getto sull'interruttore")
	_zaino()
	p.teleport(Vector3(1.4, 0.0, 0.4), 0.0, 0.0)
	await _secondi(0.2)
	var bersaglio := inter.global_position
	var d := p.camera.global_position.distance_to(bersaglio)
	p.look_at_point(bersaglio + Vector3.UP * 0.0067 * d * d)
	Input.action_press(&"spray")
	for i in 240:
		await get_tree().physics_frame
		if inter.powered:
			break
	Input.action_release(&"spray")
	await _secondi(0.3)
	check(inter.powered and neg.e_acceso(), "colpito l'interruttore, il negatoscopio si accende")
	check(neg.gruppi_visibili().is_empty(), "senza radiografia non si vedono puntini")
	await _secondi(0.1)
	check(String(GameState.snapshot.get("checkpoint", "")).ends_with("DopoLuce"), "checkpoint dopo la luce")

	print("3. Lo schedario")
	var con_adesivo: Array = []
	var tutti := inf.find_children("Cassetto*", "CassettoSchedario", false, false)
	for c in tutti:
		if (c as CassettoSchedario).adesivo:
			con_adesivo.append(c)
	check(con_adesivo.size() == 1 and tutti.size() == 10, "un solo cassetto ha l'adesivo rosa (su %d)" % tutti.size())
	var giusto := con_adesivo[0] as CassettoSchedario
	var radio := giusto.find_child("Radiografia", true, false) as Pickup
	check(radio != null and not radio.can_interact(p), "a cassetto chiuso la radiografia non si prende")
	var altro := inf.get_node(^"Cassetto21") as CassettoSchedario
	p.teleport(Vector3(-1.9, 0.0, -0.9), PI * 0.5, 0.0)
	await _secondi(0.2)
	check(await _usa(altro), "guardando un altro cassetto si apre con E")
	check(altro.aperto and not p.has_item(&"radiografia"), "è vuoto")
	neg.interact(p)
	check(not neg.con_radiografia, "senza radiografia sul negatoscopio non si appoggia niente")
	check(await _usa(giusto), "guardando il cassetto con l'adesivo si apre con E")
	check(giusto.aperto and radio.can_interact(p), "dentro la radiografia")
	check(await _usa(radio), "guardandola la si prende con E")
	check(p.has_item(&"radiografia"), "presa la radiografia")
	await _secondi(0.1)
	check(String(GameState.snapshot.get("checkpoint", "")).ends_with("DopoRadiografia"), "checkpoint dopo la radiografia")

	print("4. La radiografia sul negatoscopio")
	check(neg.get_prompt(p) == "Appoggia la radiografia", "il negatoscopio chiede di appoggiarla")
	p.teleport(Vector3(0.3, 0.0, -1.6), 0.0, 0.0)
	await _secondi(0.2)
	check(await _usa(neg), "guardando il negatoscopio la si appoggia con E")
	check(neg.con_radiografia and not p.has_item(&"radiografia"), "appoggiata")
	await _secondi(0.1)
	check(String(GameState.snapshot.get("checkpoint", "")).ends_with("DopoNegatoscopio"), "checkpoint dopo il negatoscopio")
	var gruppi := neg.gruppi_visibili()
	check(gruppi == PackedInt32Array([4, 1, 7]), "si vedono i puntini: testa, corpo, coda = %s" % str(gruppi))

	print("5. La cassaforte")
	p.teleport(Vector3(2.3, 0.0, -1.05), -PI * 0.5, 0.0)
	await _secondi(0.2)
	# la cifra che si vede davanti è proprio quella della rotella, dritta e non specchiata, per ogni cifra di ogni
	# rotella (riscontro sulla v0.3.11: con le rotelle a 4-1-7 a vista la cassaforte non si apriva, le cifre erano
	# capovolte e c'erano anche sui tappi)
	var occhio := get_viewport().get_camera_3d()
	var giuste := true
	for i in 3:
		for n in 10:
			cassa.cifre[i] = n
			cassa.call(&"_metti")
			var v := _vista(cassa, i, occhio)
			if int(v.x) != n or v.y < 0.9 or v.z < 0.9:
				giuste = false
				print("    rotella %d, cifra %d: davanti si vede la %d (dritta %.2f, non specchiata %.2f)" % [i + 1, n, int(v.x), v.y, v.z])
		cassa.cifre[i] = 0
	cassa.call(&"_metti")
	check(giuste, "davanti a chi guarda c'è la cifra della rotella, dritta e non specchiata (tutte le cifre, tre rotelle)")
	check(_tappi_lisci(cassa), "i tappi delle rotelle sono di metallo liscio, senza cifre")
	# (con le rotelle sul codice, ma ancora chiusa: aperta, lo sportello gira e porta via le rotelle)
	cassa.load_state({"cifre": [4, 1, 7], "aperta": false})
	var a_vista := PackedInt32Array()
	for i in 3:
		a_vista.append(int(_vista(cassa, i, occhio).x))
	check(a_vista == PackedInt32Array([4, 1, 7]), "con le rotelle su 4-1-7 nelle finestrelle si legge 4-1-7 (%s)" % str(a_vista))
	cassa.load_state({"cifre": [0, 0, 0], "aperta": false})
	check(await _usa(cassa.rotella(1)), "guardando una rotella la si gira con E")
	_imposta(cassa, [4, 1, 6])
	check(not cassa.aperta_ora, "4-1-6 non la apre")
	_imposta(cassa, [4, 1, 7])
	check(cassa.aperta_ora, "4-1-7 la apre")
	var polaroid := inf.get_node(^"PolaroidPecora") as PolaroidPhoto
	check(keycard.can_interact(p) and polaroid.can_interact(p), "dentro ci sono la keycard e la Polaroid")
	check(not cassa.rotella(0).can_interact(p), "aperta, le rotelle non girano più")
	await _secondi(0.5)
	check(await _usa(keycard), "guardando la keycard la si prende con E")
	check(polaroid.photo == 11 and polaroid.get_texture() != null, "è la Polaroid vera della pecora (P11)")
	var h: float = preload("res://tests/polaroid_libere.gd").appoggio(get_tree().current_scene, polaroid)
	check(h >= -0.002 and h <= 0.012, "appoggiata sul fondo della cassaforte (%.1f cm)" % (h * 100.0))
	polaroid.interact(p)
	await _secondi(0.1)
	for v in get_tree().root.get_children():
		if v is CanvasLayer and v.get_script() == PolaroidPhoto.VIEWER:
			v.queue_free()
	get_tree().paused = false
	check(p.has_item(&"keycard") and GameState.has_collectible(&"polaroid", &"PolaroidPecora"), "prese la keycard e la Polaroid, che va nella collezione")

	print("6. Checkpoint")
	GameState.capture_snapshot("TestInfermeria", 900, Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.5)))
	var cp := GameState.snapshot.duplicate(true)
	GameState.snapshot = cp
	GameState.respawn()
	await _aspetta_livello()
	await _secondi(0.2)
	inf = level.get_node(^"Infermeria")
	neg = inf.get_node(^"Negatoscopio") as Negatoscopio
	cassa = inf.get_node(^"Cassaforte") as CassaforteRotelle
	check(neg.e_acceso() and neg.con_radiografia and neg.gruppi_visibili() == PackedInt32Array([4, 1, 7]), "il negatoscopio è acceso con la radiografia")
	check(cassa.aperta_ora and cassa.cifre == PackedInt32Array([4, 1, 7]), "la cassaforte è aperta")
	var kc := inf.get_node_or_null(^"Keycard")
	check(p.has_item(&"keycard") and (kc == null or kc.is_queued_for_deletion()), "la keycard è nell'inventario e non più nella cassaforte")
	_fine()


## Guarda il nodo e preme E: vero se l'Interactor lo trova (si raggiunge) e lo usa.
func _usa(n: Node3D) -> bool:
	var interactor := p.find_children("*", "Interactor", true, false)[0]
	p.look_at_point(n.global_position)
	await _secondi(0.1)
	if interactor.get(&"current") != n:
		print("    (guardando ", n.name, " si trova ", interactor.get(&"current"), ")")
		return false
	Input.action_press(&"interact")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"interact")
	await _secondi(0.1)
	return true


## La cifra della rotella [param i] che si vede da [param cam] nella finestrella: il punto del tamburo dove arriva lo
## sguardo che passa per il centro della finestrella, e la sua cella della texture (il CylinderMesh ha la U = 0 a +Z e
## la fa crescere verso +X); poi quanto è dritta (l'alto delle cifre, la U che cala, verso l'alto della camera: 1) e
## quanto non è specchiata (la destra delle cifre, la V che cala, verso la destra della camera: 1).
func _vista(cassa: CassaforteRotelle, i: int, cam: Camera3D) -> Vector3:
	var cil := cassa.rotella(i).get_node(^"Cilindro") as MeshInstance3D
	var dentro := cil.global_transform.affine_inverse()
	var o := dentro * cam.global_position
	var w := dentro * (cassa.rotella(i).global_transform * Vector3(0.0, 0.0, CassaforteRotelle.RAGGIO + CassaforteRotelle.MASCHERINA))
	var dd := w - o
	var r := CassaforteRotelle.RAGGIO
	var qa := dd.x * dd.x + dd.z * dd.z
	var qb := 2.0 * (o.x * dd.x + o.z * dd.z)
	var qc := o.x * o.x + o.z * o.z - r * r
	var h := o + dd * ((-qb - sqrt(maxf(qb * qb - 4.0 * qa * qc, 0.0))) / (2.0 * qa))
	var a := atan2(h.x, h.z)
	var cifra := int(floor(fposmod(a / TAU, 1.0) * 10.0)) % 10
	var b := cil.global_basis.orthonormalized()
	var u_cresce := (b * Vector3(cos(a), 0.0, -sin(a))).normalized()
	return Vector3(cifra, -u_cresce.dot(cam.global_basis.y.normalized()), (b * Vector3.UP).normalized().dot(cam.global_basis.x.normalized()))


## I tamburi senza tappi col materiale delle cifre, e due tappi di metallo liscio per rotella.
func _tappi_lisci(cassa: CassaforteRotelle) -> bool:
	for i in 3:
		var cil := cassa.rotella(i).get_node(^"Cilindro") as MeshInstance3D
		var cm := cil.mesh as CylinderMesh
		if cm == null or cm.cap_top or cm.cap_bottom:
			return false
		var tappi := cil.find_children("*", "MeshInstance3D", false, false)
		if tappi.size() != 2:
			return false
		for t in tappi:
			var m := (t as MeshInstance3D).material_override as StandardMaterial3D
			if m == null or m.albedo_texture != null:
				return false
	return true


## Gira le rotelle (col tasto E) fino alle cifre [param voluto].
func _imposta(cassa: CassaforteRotelle, voluto: Array) -> void:
	for i in voluto.size():
		var giri := 0
		while cassa.cifre[i] != int(voluto[i]) and giri < 10 and not cassa.aperta_ora:
			cassa.rotella(i).interact(p)
			giri += 1


func _zaino() -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(20.0)


func _aspetta_livello() -> void:
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _secondi(0.1)
	level = get_tree().current_scene
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
