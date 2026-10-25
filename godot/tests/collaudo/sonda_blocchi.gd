extends "res://tests/test_strada.gd"
## Collaudo dei blocchi (lavoro/blocchi): le zone costruite e riaccese a pezzi devono avere tutto quello che avevano
## prima. Elenca cosa c'è davvero, a lavori a pezzi finiti: le mesh visibili (classe, centro e misura del riquadro),
## le forme di collisione attive nel mondo della fisica (classe, posto, strati), le luci accese, i checkpoint attivi,
## le porte; lo scrive in <cartella>/<nome>.json, per confrontarlo con lo stesso elenco su main
## (tools/collaudo/confronta_inventari.py). Misura anche il fotogramma più lungo (tempo vero) entrando in ogni zona.
## Modi:
##  - "strada <cartella>": la strada di test_strada fino alla torre (attraverso il portone), poi l'elenco dentro la
##    torre; una morte nella torre, la ripartenza, di nuovo l'elenco;
##  - "partenza <cartella> <id> [morte]": la partenza <id> del menu F9 (inseguimento, tunnel, risalita...), l'elenco;
##    con "morte" una morte e la ripartenza, di nuovo l'elenco (e sempre un secondo elenco dopo 30 s fermi);
##  - "lampade <cartella>": dalla partenza "inseguimento", le lampade delle vasche ogni 3 s per 90 s.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_blocchi.gd <modo> ...

var cart := ""
var _max_ms := 0.0
var _max_dove := ""
var _t_us := 0
var _misura := false
var _lunghi: Array = []


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[2]
	DirAccess.make_dir_recursive_absolute(cart)
	if a[1] == "lampade":
		_lampade.call_deferred()
		return
	if a[1] == "strada":
		_inizia_misura()
		super._ready()
	else:
		_partenza.call_deferred(a[3], a.has("morte"))


func _process(_d: float) -> void:
	var t := Time.get_ticks_usec()
	if _misura and _t_us > 0:
		var ms := (t - _t_us) / 1000.0
		if ms > 50.0:
			var pl := GameState.player
			_lunghi.append([ms, pl.global_position.snapped(Vector3.ONE * 0.1) if pl and is_instance_valid(pl) else Vector3.ZERO, Time.get_ticks_msec() / 1000.0])
		if ms > _max_ms:
			_max_ms = ms
			var sc := get_tree().current_scene
			_max_dove = String(sc.name) if sc else "-"
	_t_us = t


func _stampa_lunghi(nome: String) -> void:
	_lunghi.sort_custom(func(x, y): return x[0] > y[0])
	print("BLOCCHI: %s, fotogrammi sopra 50 ms: %d; i più lunghi: %s" % [nome, _lunghi.size(), ", ".join(_lunghi.slice(0, 8).map(
		func(x): return "%.0f ms a %.1f s in %s" % [x[0], x[2], x[1]]))])
	_lunghi.clear()


func _inizia_misura() -> void:
	_lunghi.clear()
	_max_ms = 0.0
	_t_us = 0
	_misura = true


## Aspetta che non ci siano più lavori a pezzi né caricamenti nel thread (al più 180 s), poi ancora 1 s.
func _aspetta_lavori(nome: String) -> void:
	var t0 := Time.get_ticks_msec()
	var sc := get_tree().current_scene
	while Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
		sc = get_tree().current_scene
		var lavori := sc != null and sc.has_method(&"lavori_in_corso") and bool(sc.call(&"lavori_in_corso"))
		if not lavori and not (Game.has_method(&"caricamenti_in_corso") and bool(Game.call(&"caricamenti_in_corso"))):
			break
	for i in 60:
		await get_tree().process_frame
	_stampa_lunghi(nome)
	print("BLOCCHI: %s, lavori finiti dopo %.1f s; fotogramma più lungo %.0f ms (%s)" % [nome, (Time.get_ticks_msec() - t0) / 1000.0, _max_ms, _max_dove])


func _fine() -> void:
	# dentro la torre, attraverso il portone
	await _aspetta_lavori("torre dal portone")
	await _inventario("torre_ingresso")
	await _morte("torre")
	await _inventario("torre_dopo_morte")
	super._fine()


func _partenza(id: String, morte: bool) -> void:
	Game.pause_on_focus_loss = false
	_inizia_misura()
	if not MenuProva.parti(get_tree(), id):
		print("BLOCCHI: ERRORE niente partenza ", id)
		get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		var pl := GameState.player
		var sc := get_tree().current_scene
		if pl and is_instance_valid(pl) and pl.input_enabled and sc and not String(sc.scene_file_path).contains("caricamento"):
			break
	if id == "risalita":
		# le stanze della Risalita, caricate dopo nel thread
		var tr := Time.get_ticks_msec()
		while Time.get_ticks_msec() - tr < 180000:
			await get_tree().process_frame
			var r := get_tree().current_scene.get_node_or_null(^"Risalita") if get_tree().current_scene else null
			if r and r.get(&"fiume") != null:
				break
		print("BLOCCHI: stanze della Risalita dopo %.1f s" % ((Time.get_ticks_msec() - tr) / 1000.0))
	_inizia_misura()
	print("BLOCCHI: partenza %s arrivata dopo %.1f s (%s)" % [id, (Time.get_ticks_msec() - t0) / 1000.0, _cp()])
	await _aspetta_lavori("partenza " + id)
	await _inventario(id)
	# di nuovo dopo 30 s fermi: se qualcosa arriva dopo, si vede
	for i in 60 * 30:
		await get_tree().process_frame
	await _inventario(id + "_30s")
	if morte:
		await _morte(id)
		await _inventario(id + "_dopo_morte")
	get_tree().quit()


func _cp() -> String:
	return String(GameState.snapshot.get("checkpoint", "")) if GameState.snapshot is Dictionary else ""


func _morte(nome: String) -> void:
	var cp := _cp()
	var vecchia := get_tree().current_scene
	print("BLOCCHI: morte in %s (checkpoint %s)" % [nome, cp])
	GameState.kill_player(&"generico")
	var t0 := Time.get_ticks_msec()
	# la sequenza di morte si salta come chi gioca (tenendo premuto)
	Input.action_press(&"skip")
	while Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
		if get_tree().current_scene != vecchia and get_tree().current_scene != null:
			var pl := GameState.player
			if pl and is_instance_valid(pl) and pl.input_enabled and not GameState.is_dying:
				break
	Input.action_release(&"skip")
	_inizia_misura()
	print("BLOCCHI: ripartenza dopo %.1f s, checkpoint %s (prima %s), giocatore %s" % [(Time.get_ticks_msec() - t0) / 1000.0, _cp(), cp,
		GameState.player.global_position.snapped(Vector3.ONE * 0.01) if GameState.player else "-"])
	await _aspetta_lavori("dopo la morte in " + nome)


func _v(x: Vector3) -> Array:
	return [snappedf(x.x, 0.001), snappedf(x.y, 0.001), snappedf(x.z, 0.001)]


func _inventario(nome: String) -> void:
	var sc := get_tree().current_scene
	var out := {"mesh": [], "forma": [], "luce": [], "checkpoint": [], "porta": []}
	for n in sc.find_children("*", "", true, false):
		var percorso := String(sc.get_path_to(n))
		if n is VisualInstance3D and not (n is Light3D) and (n as VisualInstance3D).is_visible_in_tree():
			var vi := n as VisualInstance3D
			var bb := vi.global_transform * vi.get_aabb()
			if bb.size.length() > 0.0001:
				out.mesh.append({"c": vi.get_class(), "p": _v(bb.get_center()), "s": _v(bb.size), "l": vi.layers, "n": percorso})
		elif n is CollisionShape3D:
			var cs := n as CollisionShape3D
			var co := cs.get_parent() as CollisionObject3D
			if cs.disabled or cs.shape == null or co == null:
				continue
			var spazio := PhysicsServer3D.body_get_space(co.get_rid()) if co is PhysicsBody3D else PhysicsServer3D.area_get_space(co.get_rid())
			if not spazio.is_valid() or co.collision_layer == 0:
				continue
			# il centro e la misura della forma nel mondo (le forme convesse e concave hanno i punti già al loro posto)
			var punti := PackedVector3Array()
			if cs.shape is ConvexPolygonShape3D:
				punti = (cs.shape as ConvexPolygonShape3D).points
			elif cs.shape is ConcavePolygonShape3D:
				punti = (cs.shape as ConcavePolygonShape3D).get_faces()
			var centro := cs.global_position
			var misura := Vector3.ZERO
			if punti.size() > 0:
				var bb := AABB(punti[0], Vector3.ZERO)
				for q in punti:
					bb = bb.expand(q)
				bb = cs.global_transform * bb
				centro = bb.get_center()
				misura = bb.size
			elif cs.shape is BoxShape3D:
				misura = (cs.shape as BoxShape3D).size
			out.forma.append({"c": cs.shape.get_class(), "p": _v(centro), "s": _v(misura), "l": co.collision_layer, "a": co is Area3D, "n": percorso})
		elif n is Light3D and (n as Light3D).is_visible_in_tree() and (n as Light3D).light_energy > 0.0:
			out.luce.append({"c": n.get_class(), "p": _v((n as Node3D).global_position), "l": (n as Light3D).layers, "m": (n as Light3D).light_cull_mask, "n": percorso})
		if n is Checkpoint:
			var ck := n as Checkpoint
			out.checkpoint.append({"c": "Checkpoint", "p": _v(ck.global_position), "attivo": ck.monitoring and ck.can_process()
				and PhysicsServer3D.area_get_space(ck.get_rid()).is_valid(), "n": percorso})
		elif n is Node3D and n.get_script() and String((n.get_script() as Script).get_global_name()).begins_with("Porta"):
			out.porta.append({"c": String((n.get_script() as Script).get_global_name()), "p": _v((n as Node3D).global_position),
				"attivo": n.can_process(), "n": percorso})
	var f := FileAccess.open(cart.path_join(nome + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	var attivi: int = out.checkpoint.filter(func(c): return c.attivo).size()
	print("BLOCCHI: elenco %s: mesh %d, forme %d, luci %d, checkpoint %d (attivi %d), porte %d" % [nome, out.mesh.size(),
		out.forma.size(), out.luce.size(), out.checkpoint.size(), attivi, out.porta.size()])


## Le lampade da lavoro sulle vasche dell'inseguimento (spente nell'elenco di blocchi dopo la partenza): dalla partenza
## "inseguimento", ogni 3 s per 90 s, com'è ognuna (nell'albero, visibile, energia, chi la nasconde).
func _lampade() -> void:
	Game.pause_on_focus_loss = false
	MenuProva.parti(get_tree(), "inseguimento")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		var pl := GameState.player
		if pl and is_instance_valid(pl) and pl.input_enabled and get_tree().current_scene and not String(get_tree().current_scene.scene_file_path).contains("caricamento"):
			break
	var t1 := Time.get_ticks_msec()
	for k in 31:
		var sc := get_tree().current_scene
		var luci := sc.get_node_or_null(^"SalaTorre/SalaInseguimento/Luci")
		var righe: PackedStringArray = []
		if luci:
			for l in luci.find_children("*", "Light3D", true, false):
				var x := (l as Node3D).global_position.x
				if absf(x - 54.55) < 0.1 or absf(x - 64.0) < 0.1 or absf(x - 72.05) < 0.1:
					var lt := l as Light3D
					var nasc := ""
					var q: Node = lt
					while q and q != sc:
						if q is Node3D and not (q as Node3D).visible:
							nasc = String(sc.get_path_to(q))
							break
						q = q.get_parent()
					righe.append("%s vis %s en %.2f nasc %s" % [lt.name, lt.is_visible_in_tree(), lt.light_energy, nasc])
		print("LAMPADE %.0f s: %s" % [(Time.get_ticks_msec() - t1) / 1000.0, " | ".join(righe)])
		for i in 180:
			await get_tree().process_frame
	get_tree().quit()
