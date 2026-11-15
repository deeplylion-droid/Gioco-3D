extends "res://tests/test_portone_torre.gd"
## Collaudo del portone della torre (enigmi 9afdcf0e, in lavoro/godot ca4aef21), oltre a test_portone_torre: come chi
## gioca, coi tasti veri. Modi (primo argomento dopo lo script):
##  - "giochi": dal mondo fatto fino al portone aperto (come il test), quattro prove:
##    A. entrato, indietro di corsa saltando di continuo;
##    B. entrato, indietro accucciato;
##    C. entrato, contro la soglia di corsa andando di lato, avanti e indietro lungo tutta la larghezza (gli spigoli);
##    D. una morte 0,7 s dopo essere entrati, col portone che si sta chiudendo e gli ambienti ancora caricati;
##  - "salva <cartella> <subito|chiuso>": col salvataggio su disco vero, si entra camminando e, appena il checkpoint del
##    portone è su disco, si chiude il gioco ("subito", col portone che si chiude) o dopo, a portone chiuso ("chiuso");
##  - "continua <cartella>": dal titolo, Continua col tasto vero; arrivati, il portone, gli ambienti, il posto e la corsa
##    indietro verso la sala.
## Errori del motore e degli script contati come test_presa_vera. Stampa righe "PORTONE: ...".
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_portone.gd <modo> ...

const Presa := preload("res://tests/test_presa_vera.gd")
const TITOLO := "res://scenes/ui/menu_principale.tscn"

var _errori := Presa.ContaErrori.new()


func _run() -> void:
	OS.add_logger(_errori)
	_errori.attivo = true
	var a := OS.get_cmdline_user_args()
	var modo := a[1] if a.size() > 1 else "giochi"
	Game.pause_on_focus_loss = false
	match modo:
		"giochi":
			GameState.save_to_disk = false
			for prova in ["A", "B", "C", "D"]:
				print("== prova ", prova)
				await _prepara()
				match prova:
					"A": await _prova_A()
					"B": await _prova_B()
					"C": await _prova_C()
					"D": await _prova_D()
		"salva":
			GameState.save_to_disk = true
			await _salva(a[2], a[3] if a.size() > 3 else "subito")
		"continua":
			GameState.save_to_disk = true
			await _continua(a[2])
		"misura":
			GameState.save_to_disk = false
			await _prepara()
			await _misura()
	_errori.attivo = false
	for e in _errori.errori.slice(0, 15):
		printerr("    ", e)
	print("PORTONE: errori del motore e degli script: %d" % _errori.errori.size())
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _stato_portone() -> String:
	return "quanto %.2f, chiuso_dietro %s, soglia %s" % [float(portone.get(&"quanto")), portone.get(&"chiuso_dietro"),
		portone.get_node_or_null(^"SogliaChiusa") != null]


## Dopo una prova: il portone chiuso, gli ambienti via, il giocatore nella torre.
func _fine_prova(nome: String, minimo: float) -> void:
	_check(minimo > SOGLIA, "%s: non si passa la soglia (x minima %.2f, soglia %.2f)" % [nome, minimo, SOGLIA])
	for i in 60 * 12:
		await get_tree().physics_frame
		if float(portone.get(&"quanto")) <= 0.0 and not _ambienti():
			break
	_check(float(portone.get(&"quanto")) <= 0.0 and not _ambienti(), "%s: portone chiuso e ambienti scaricati (%s)" % [nome, _stato_portone()])
	_check(p.global_position.x > SOGLIA and absf(p.global_position.y) < 0.3, "%s: il giocatore è nella torre, in piedi (%s)" % [nome, p.global_position])
	var x0 := p.global_position.x
	await _cammina(EST, 0.4)
	_check(p.global_position.x > x0 + 0.6, "%s: poi cammina nella torre (x da %.2f a %.2f)" % [nome, x0, p.global_position.x])


func _prova_A() -> void:
	await _cammina(EST, 4.0, true, _dentro)
	_check(_dentro(), "A: entrato (x %.2f)" % p.global_position.x)
	var minimo := p.global_position.x
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in 60 * 4:
		p.set_look(lerp_angle(EST, OVEST, minf(float(i + 1) / 15.0, 1.0)), 0.0)
		if i % 20 == 0:
			Input.action_press(&"jump")
		elif i % 20 == 4:
			Input.action_release(&"jump")
		await get_tree().physics_frame
		minimo = minf(minimo, p.global_position.x)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	Input.action_release(&"jump")
	await _fine_prova("A (salti)", minimo)


func _prova_B() -> void:
	await _cammina(EST, 4.0, false, _dentro)
	_check(_dentro(), "B: entrato (x %.2f)" % p.global_position.x)
	var minimo := p.global_position.x
	Input.action_press(&"crouch")
	Input.action_press(&"move_forward")
	for i in 60 * 4:
		p.set_look(OVEST, 0.0)
		await get_tree().physics_frame
		minimo = minf(minimo, p.global_position.x)
	Input.action_release(&"move_forward")
	Input.action_release(&"crouch")
	for i in 30:
		await get_tree().physics_frame
	await _fine_prova("B (accucciato)", minimo)


func _prova_C() -> void:
	await _cammina(EST, 4.0, true, _dentro)
	_check(_dentro(), "C: entrato (x %.2f)" % p.global_position.x)
	var minimo := p.global_position.x
	var zmin := p.global_position.z
	var zmax := zmin
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in 60 * 5:
		# verso ovest contro la soglia, e di lato avanti e indietro (un secondo per verso)
		p.set_look(OVEST, 0.0)
		var sx := (i / 60) % 2 == 0
		if sx:
			Input.action_release(&"move_right")
			Input.action_press(&"move_left")
		else:
			Input.action_release(&"move_left")
			Input.action_press(&"move_right")
		await get_tree().physics_frame
		minimo = minf(minimo, p.global_position.x)
		zmin = minf(zmin, p.global_position.z)
		zmax = maxf(zmax, p.global_position.z)
	for azione in [&"move_forward", &"sprint", &"move_left", &"move_right"]:
		Input.action_release(azione)
	print("PORTONE: C lungo la soglia da z %.2f a %.2f" % [zmin, zmax])
	await _fine_prova("C (di lato lungo la soglia)", minimo)


func _prova_D() -> void:
	await _cammina(EST, 4.0, false, _dentro)
	_check(_dentro(), "D: entrato (x %.2f)" % p.global_position.x)
	for i in 42:
		await get_tree().physics_frame
	_check(_ambienti() and float(portone.get(&"quanto")) > 0.0, "D: si muore mentre si chiude, con gli ambienti caricati (%s)" % _stato_portone())
	var cp := String(GameState.snapshot.get("checkpoint", ""))
	var vecchio := p
	GameState.kill_player(&"generico")
	Input.action_press(&"skip")
	await _aspetta_livello(vecchio)
	Input.action_release(&"skip")
	for i in 60 * 10:
		await get_tree().physics_frame
		if not _ambienti():
			break
	portone = level.get(&"portone")
	print("PORTONE: D ripartiti dal checkpoint %s (prima %s), %s, in %s" % [GameState.snapshot.get("checkpoint", ""), cp, _stato_portone(), p.global_position])
	_check(float(portone.get(&"quanto")) <= 0.0 and bool(portone.get(&"chiuso_dietro")), "D: ripartiti col portone chiuso (%s)" % _stato_portone())
	_check(not _ambienti(), "D: ripartiti senza interni e tecnici")
	var minimo := p.global_position.x
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in 60 * 3:
		p.set_look(OVEST, 0.0)
		await get_tree().physics_frame
		minimo = minf(minimo, p.global_position.x)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	await _fine_prova("D (dopo la morte)", minimo)


func _salvataggio() -> Dictionary:
	if not FileAccess.file_exists(GameState.SAVE_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	return d if d is Dictionary else {}


func _salva(cart: String, quando: String) -> void:
	DirAccess.make_dir_recursive_absolute(cart)
	await _prepara()
	print("PORTONE: salvataggio su disco prima: %s" % _salvataggio().get("checkpoint", "-"))
	await _cammina(EST, 4.0, false, func(): return String(_salvataggio().get("checkpoint", "")) == "SalaTorre/Checkpoint_portone")
	for i in 60 * 3:
		if String(_salvataggio().get("checkpoint", "")) == "SalaTorre/Checkpoint_portone":
			break
		await get_tree().physics_frame
	var d := _salvataggio()
	var oggetti: Dictionary = d.get("objects", {}) if d.get("objects") is Dictionary else {}
	print("PORTONE: su disco checkpoint %s, portone %s; adesso %s, dentro %s, ambienti %s, x %.2f" % [d.get("checkpoint", "-"),
		oggetti.get("Gioco/PortoneTorre", "-"), _stato_portone(), _dentro(), _ambienti(), p.global_position.x])
	# (il checkpoint del portone è sulla soglia, prima dell'entrata: si entra davvero)
	await _cammina(EST, 4.0, false, _dentro)
	print("PORTONE: entrato in x %.2f, %s" % [p.global_position.x, _stato_portone()])
	if quando == "subito":
		for i in 30:
			await get_tree().physics_frame
		print("PORTONE: mezzo secondo dopo: %s, ambienti %s" % [_stato_portone(), _ambienti()])
	if quando == "chiuso":
		for i in 60 * 12:
			await get_tree().physics_frame
			if float(portone.get(&"quanto")) <= 0.0 and not _ambienti():
				break
		print("PORTONE: aspettato: %s, ambienti %s; su disco %s" % [_stato_portone(), _ambienti(), _salvataggio().get("checkpoint", "-")])
	print("PORTONE: si chiude il gioco")


func _tasto(k: Key) -> void:
	for premuto in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = premuto
		Input.parse_input_event(e)
		for i in 3:
			await get_tree().process_frame


func _continua(cart: String) -> void:
	var d := _salvataggio()
	print("PORTONE: salvataggio su disco: checkpoint %s" % d.get("checkpoint", "-"))
	get_tree().change_scene_to_file(TITOLO)
	for i in 240:
		await get_tree().process_frame
	var f := get_viewport().gui_get_focus_owner()
	print("PORTONE: al titolo il focus è su %s" % (String(f.name) if f else "niente"))
	await _tasto(KEY_ENTER)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		var pl := GameState.player
		if pl and is_instance_valid(pl) and pl.input_enabled and sc and not String(sc.scene_file_path).contains("caricamento") \
				and not String(sc.scene_file_path).contains("menu") and not GameState.is_restoring():
			break
	for i in 60:
		await get_tree().physics_frame
	level = get_tree().current_scene
	p = GameState.player
	for i in 60 * 10:
		await get_tree().physics_frame
		if not _ambienti():
			break
	portone = level.get(&"portone")
	print("PORTONE: arrivati dopo %.1f s al checkpoint %s, %s, ambienti %s, in %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		GameState.snapshot.get("checkpoint", ""), _stato_portone(), _ambienti(), p.global_position])
	_check(String(GameState.snapshot.get("checkpoint", "")) == "SalaTorre/Checkpoint_portone", "Continua: al checkpoint del portone")
	_check(float(portone.get(&"quanto")) <= 0.0 and bool(portone.get(&"chiuso_dietro")), "Continua: il portone è chiuso (%s)" % _stato_portone())
	_check(not _ambienti(), "Continua: niente interni e tecnici")
	_check(p.global_position.x > SOGLIA + 0.5, "Continua: nella torre (%s)" % p.global_position)
	var minimo := p.global_position.x
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in 60 * 3:
		p.set_look(OVEST, 0.0)
		await get_tree().physics_frame
		minimo = minf(minimo, p.global_position.x)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	await _fine_prova("Continua", minimo)


## Appoggiati alla soglia per tutta la chiusura: a ogni quarto di secondo, quanto la camera (e il piano vicino) dista
## dalla mesh dell'anta, cioè se la si vede da dentro.
func _misura() -> void:
	await _cammina(EST, 4.0, false, _dentro)
	var anta: Node3D = portone.get(&"anta")
	var cam := p.camera
	print("PORTONE: misura: camera near %.3f, raggio del giocatore %s" % [cam.near, _raggio()])
	Input.action_press(&"move_forward")
	for i in 60 * 5:
		p.set_look(OVEST if i > 15 else lerp_angle(EST, OVEST, float(i) / 15.0), 0.0)
		await get_tree().physics_frame
		if i % 15 == 0:
			var bb := _aabb(anta)
			var c := cam.global_position
			# il punto della scatola dell'anta più vicino alla camera
			var q := Vector3(clampf(c.x, bb.position.x, bb.end.x), clampf(c.y, bb.position.y, bb.end.y), clampf(c.z, bb.position.z, bb.end.z))
			print("PORTONE: t %.2f quanto %.2f camera x %.3f; anta (mesh) x da %.3f a %.3f, z da %.2f a %.2f; distanza camera-anta %.3f m" % [
				i / 60.0, float(portone.get(&"quanto")), c.x, bb.position.x, bb.end.x, bb.position.z, bb.end.z, c.distance_to(q)])
	Input.action_release(&"move_forward")
	var sg := portone.get_node_or_null(^"SogliaChiusa") as Node3D
	if sg:
		for f in sg.get_children():
			var cs := f as CollisionShape3D
			if cs and cs.shape:
				var pts: PackedVector3Array = cs.shape.get_debug_mesh().get_faces()
				var b := AABB(cs.global_transform * pts[0], Vector3.ZERO)
				for v in pts:
					b = b.expand(cs.global_transform * v)
				print("PORTONE: muro invisibile %s x da %.3f a %.3f, y da %.2f a %.2f, z da %.2f a %.2f" % [cs.shape.get_class(), b.position.x, b.end.x, b.position.y, b.end.y, b.position.z, b.end.z])


func _raggio() -> String:
	for f in p.find_children("*", "CollisionShape3D", false, false):
		var cs := f as CollisionShape3D
		if cs.shape is CapsuleShape3D:
			return "%.2f" % (cs.shape as CapsuleShape3D).radius
	return "?"


func _aabb(n: Node3D) -> AABB:
	var bb := AABB()
	var primo := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var vi := m as MeshInstance3D
		if not vi.is_visible_in_tree():
			continue
		var b := vi.global_transform * vi.get_aabb()
		bb = b if primo else bb.merge(b)
		primo = false
	return bb
