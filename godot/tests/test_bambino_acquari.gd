extends Node
## Il bambino col cubo agli acquari (build 0.5.0, «La storia»; GDD «l'apparizione agli acquari»; EnigmaAcquari
## [method EnigmaAcquari._bambino_col_cubo], BambinoSfuggita con guarda_il_disegno, posa di mascotte), nella sala vera:
## 1. il posto: in piedi a circa 1,2 m dal vetro del cilindro giallo, sotto il disegno, girato verso il vetro; nascosto;
## 2. prima che gli acquari ci siano, o con gli acquari risolti, non compare;
## 3. con gli acquari che funzionano: mai sotto gli occhi del giocatore; guardando altrove compare, in piedi che guarda in
##    su il disegno col pastello in mano (DISEGNA con guarda_il_disegno); se nessuno lo guarda resta lì;
## 4. arrivando a 6 m gira la testa, resta un secondo e scappa; il pastello gli cade e resta per terra (appoggiato,
##    lontano dalla Polaroid 14); la fuga è libera (niente collisioni sul percorso) e finisce nascosta, dove sparisce solo
##    fuori vista;
## 5. il checkpoint: ripartendo il bambino non torna e il pastello è per terra dov'era; una volta sola.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_bambino_acquari.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var level: Node
var p: Player
var enigma: EnigmaAcquari
var b: BambinoSfuggita
var _passed := 0
var _failed := 0
var _testa := -1.0
var _scappa := -1.0
var _caduto := Vector3.INF


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		print("  FALLITO ", what)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	await _aspetta_livello()
	check(enigma != null and b != null, "agli acquari c'è il bambino col cubo (BambinoAcquari)")
	if b == null:
		return _fine()

	print("1. Il posto")
	var giallo := enigma.get_node(^"AcquarioGiallo") as Node3D
	var asse := Vector2(giallo.global_position.x, giallo.global_position.z)
	var qui := Vector2(b.global_position.x, b.global_position.z)
	var dis := enigma.get_node(^"Disegno/Modello") as MeshInstance3D
	var ab := dis.global_transform * dis.get_aabb()
	var raggio := Vector2(ab.get_center().x, ab.get_center().z).distance_to(asse)
	var dal_vetro := qui.distance_to(asse) - raggio
	check(dal_vetro > 1.0 and dal_vetro < 1.3, "a %.2f m dal vetro, sotto il disegno (che va da %.2f a %.2f m)" % [dal_vetro, ab.position.y, ab.end.y])
	var verso := Vector2(b.global_basis.z.x, b.global_basis.z.z).normalized()
	check(verso.dot((asse - qui).normalized()) > 0.95, "girato verso il vetro")
	check(absf(b.global_position.y) < 0.01, "coi piedi sul pavimento (y %.3f)" % b.global_position.y)
	check(b.stato == BambinoSfuggita.Stato.ATTESA and not b.bambino.visible, "all'inizio non c'è")

	print("2. Prima degli acquari, e con gli acquari risolti, non compare")
	await _guarda_altrove(Vector3(12.0, 0.0, -14.0), 1.5)
	check(b.stato == BambinoSfuggita.Stato.ATTESA, "gli acquari non ci sono ancora: niente")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var lettore := level.get_node_or_null(^"Tecnici/Logica/LettoreTessera") as LettoreTessera
	if lettore:
		p.add_item(&"keycard", 1, "Keycard")
		lettore.interact(p)
	else:
		level.get_node(^"Tecnici/Logica/SerrandaMagazzino").call(&"apri")
	await _frames(10)
	await _guarda_altrove(Vector3(12.0, 0.0, -14.0), 1.5)
	check(enigma.comparsi and b.stato == BambinoSfuggita.Stato.ATTESA, "gli acquari ci sono ma lei non se n'è andata (tappa 8): niente")
	var stato_prima := enigma.stato
	enigma.stato = EnigmaAcquari.Stato.RISOLTO
	var lei: Node = level.get(&"lei_sbuca")
	lei.call(&"load_state", {"finita": true})
	if lei.has_signal(&"andata_via"):
		lei.emit_signal(&"andata_via")
	await _frames(10)
	await _guarda_altrove(Vector3(12.0, 0.0, -14.0), 1.5)
	check(enigma.tappa8_finita() and b.stato == BambinoSfuggita.Stato.ATTESA, "lei se n'è andata ma gli acquari sono risolti: niente")

	print("3. Compare solo fuori vista, e aspetta")
	p.teleport(Vector3(14.0, 0.0, -12.0), 0.0, 0.0)
	p.look_at_point(b.global_position + Vector3.UP * 0.9)
	await _frames(2)
	# (gli acquari tornano da risolvere mentre il giocatore guarda già il posto del bambino)
	enigma.stato = stato_prima
	var visto_comparire := false
	for i in 90:
		p.look_at_point(b.global_position + Vector3.UP * 0.9)
		await get_tree().physics_frame
		visto_comparire = visto_comparire or b.stato != BambinoSfuggita.Stato.ATTESA
	check(not visto_comparire, "guardando il suo posto non compare (mai sotto gli occhi)")
	b.bambino.alza_la_testa.connect(func(): _testa = Engine.get_physics_frames() / 60.0)
	b.bambino.scappa.connect(func(): _scappa = Engine.get_physics_frames() / 60.0)
	b.pastello_caduto.connect(func(d): _caduto = d)
	await _guarda_altrove(Vector3(14.0, 0.0, -12.0), 0.5)
	check(b.stato == BambinoSfuggita.Stato.GUARDA and b.bambino.visible, "guardando altrove compare")
	check(b.bambino.modalita == Bambino.Modalita.DISEGNA and b.bambino.guarda_il_disegno, "in piedi che guarda in su il disegno (DISEGNA, guarda_il_disegno)")
	await _guarda_altrove(Vector3(14.0, 0.0, -12.0), 3.0)
	check(b.stato == BambinoSfuggita.Stato.GUARDA and _testa < 0.0, "se nessuno lo guarda, a più di 6 m, resta lì")

	print("4. A 6 m gira la testa, un secondo, scappa; il pastello resta per terra")
	# (a sud, nella sala: a est c'è il muro a 2 m)
	var davanti := Vector3(qui.x, 0.0, qui.y + 5.0)
	p.teleport(Vector3(davanti.x, 0.0, davanti.z), 0.0, 0.0)
	var t0 := Engine.get_physics_frames() / 60.0
	for i in 60 * 4:
		p.look_at_point(b.bambino.global_position + Vector3.UP * 0.9)
		await get_tree().physics_frame
		if _scappa > 0.0:
			break
	check(_testa > 0.0 and _testa - t0 < 0.3, "arrivato a 5 m gira subito la testa (%.2f s)" % (_testa - t0))
	check(_scappa > 0.0 and _scappa - _testa > 0.8 and _scappa - _testa < 1.6, "resta un secondo e scappa (%.2f s)" % (_scappa - _testa))
	check(b.stato == BambinoSfuggita.Stato.SCAPPA, "(e scappa davvero)")
	await _frames(3)
	var pastello := b.pastello
	check(_caduto != Vector3.INF and pastello != null and is_instance_valid(pastello), "il pastello gli cade di mano")
	if pastello:
		var space := (level as Node3D).get_world_3d().direct_space_state
		var giu := space.intersect_ray(PhysicsRayQueryParameters3D.create(pastello.global_position + Vector3.UP * 0.5, pastello.global_position + Vector3.DOWN * 0.5))
		var y_pav: float = (giu.position as Vector3).y if giu else -99.0
		check(giu and absf(pastello.global_position.y - y_pav) < 0.005, "appoggiato al pavimento (scarto %.4f m)" % (pastello.global_position.y - y_pav))
		var pol := enigma.get_node_or_null(^"Polaroid14") as Node3D
		var dpol := Vector2(pastello.global_position.x, pastello.global_position.z).distance_to(Vector2(pol.global_position.x, pol.global_position.z)) if pol else 9.0
		check(dpol > 0.2, "lontano dalla Polaroid 14 (%.2f m)" % dpol)
		check(Vector2(pastello.global_position.x, pastello.global_position.z).distance_to(qui) < 0.8, "lì dov'era il bambino")
	# la fuga: niente collisioni sul percorso, e il bambino sparisce solo fuori vista
	var visto_sparire := false
	for i in 60 * 10:
		# (visto adesso, prima del fotogramma: se nel fotogramma sparisce, è sparito sotto gli occhi)
		var visto := b.bambino.visible and b.bambino.visibile_da(p)
		await get_tree().physics_frame
		if visto and not b.bambino.visible:
			visto_sparire = true
		if b.stato == BambinoSfuggita.Stato.FINITO:
			break
		if i == 60 * 3:
			# il giocatore si gira: così sparisce
			p.set_look(p.rotation.y + PI, 0.0)
	check(b.stato == BambinoSfuggita.Stato.FINITO and not b.bambino.visible, "alla fine della fuga sparisce")
	check(not visto_sparire, "non sparisce mai sotto gli occhi")
	check(_fuga_libera(), "il percorso della fuga è libero (niente collisioni a 0,15, 0,6 e 1,1 m, largo mezzo metro)")

	print("5. Il checkpoint: una volta sola, il pastello resta")
	var dov_era := pastello.global_position if pastello else Vector3.ZERO
	GameState.capture_snapshot("TestBambinoAcquari", 900, p.global_transform)
	var s := GameState.snapshot.duplicate(true)
	GameState.snapshot = s.duplicate(true)
	GameState.respawn()
	await _aspetta_livello()
	await _frames(10)
	check(b != null and b.stato == BambinoSfuggita.Stato.FINITO and not b.bambino.visible, "ripartendo il bambino non torna")
	check(b.pastello != null and b.pastello.global_position.distance_to(dov_era) < 0.01, "e il pastello è per terra dov'era (%.3f m)" % (b.pastello.global_position.distance_to(dov_era) if b.pastello else 9.0))
	await _guarda_altrove(Vector3(14.0, 0.0, -12.0), 2.0)
	check(b.stato == BambinoSfuggita.Stato.FINITO, "una volta sola")
	_fine()


## Dal posto del bambino lungo i punti della fuga: niente collisioni a tre altezze, al centro e a 25 cm dai lati.
func _fuga_libera() -> bool:
	var space := (level as Node3D).get_world_3d().direct_space_state
	var punti: Array[Vector3] = [b.global_position]
	for q in b.via:
		punti.append(enigma.to_global(q))
	for n in range(1, punti.size()):
		var a := punti[n - 1]
		var c := punti[n]
		var lat := (c - a).cross(Vector3.UP).normalized() * 0.25
		for off in [Vector3.ZERO, lat, -lat]:
			for h in [0.15, 0.6, 1.1]:
				var q := PhysicsRayQueryParameters3D.create(a + off + Vector3.UP * h, c + off + Vector3.UP * h)
				var hit := space.intersect_ray(q)
				if hit:
					print("    (fuga: %s fra %s e %s)" % [(hit.collider as Node).name, a, c])
					return false
	return true


func _guarda_altrove(dove: Vector3, secondi: float) -> void:
	p.teleport(dove, 0.0, 0.0)
	for i in int(secondi * 60.0):
		# di spalle agli acquari
		p.look_at_point(dove + (dove - b.global_position).normalized() * 5.0 + Vector3.UP * 1.6)
		await get_tree().physics_frame


func _aspetta_livello() -> void:
	var t_attesa := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_attesa < 90000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _frames(5)
	level = get_tree().current_scene
	p = GameState.player
	enigma = level.get_node_or_null(^"Gioco/EnigmaAcquari") as EnigmaAcquari
	b = enigma.bambino_disegno if enigma else null
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
