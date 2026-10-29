extends Node
## Sonda del salvataggio entrando nella torre degli scivoli, giocando come chi gioca: il mondo fatto fino al portone
## aperto (come la partenza "torre" di genera_partenze_prova), il giocatore nella sala davanti al portone, che entra
## camminando.
## - "entra": entra e resta. Quando scatta il checkpoint del portone, e cosa c'è nell'istantanea (stati di Interni e
##   Tecnici); poi se gli interni e i tecnici vengono scaricati e il portone si chiude; poi una morte: dove si riparte.
## - "torna": entra e appena è dentro torna indietro di corsa. Se riesce a uscire nella sala mentre il portone si chiude
##   e gli ambienti si scaricano.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sonda_uscita_torre.gd [entra|torna]

const GEN := preload("res://tests/genera_partenze_prova.gd")
const SCENA := "res://scenes/sala_principale.tscn"

var level: Node
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var args := OS.get_cmdline_user_args()
	var modi := ["entra", "torna"] if args.size() < 2 else [args[1]]
	for m in modi:
		print("== ", m)
		await _prepara()
		if m == "entra":
			await _entra()
		else:
			await _torna()
	print("FINE")
	get_tree().quit()


func _prepara() -> void:
	GameState.reset_progress()
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file(SCENA)
	await _aspetta_livello()
	var stati := {}
	var raccolti: Array = []
	for k in 5:
		var parte: String = GEN.PARTI[k]
		stati.merge(GEN.FATTI.get(parte, {}), true)
		raccolti.append_array(GEN.RACCOLTI.get(parte, []))
		for e in GEN.POLAROID.get(parte, []):
			GameState.collect(&"polaroid", StringName(e))
	for n in get_tree().get_nodes_in_group(&"persist"):
		var key := GameState.persist_key(n)
		if key in raccolti:
			GameState.mark_removed(n)
			n.queue_free()
			continue
		if stati.has(key) and n.has_method(&"load_state"):
			var d: Dictionary = n.call(&"save_state") if n.has_method(&"save_state") else {}
			d.merge(stati[key], true)
			n.call(&"load_state", d)
	p = GameState.player
	p.inventory[&"zaino_pompa"] = 1
	if p.water_pack:
		p.water_pack.set_equipped(true, false)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for i in 10:
		await get_tree().physics_frame
	# la torre caricata e il portone aperto davvero (lo stato "aperto" del salvataggio non lo riapre)
	level.call(&"_carica_torre")
	for i in 60 * 120:
		await get_tree().process_frame
		var t = level.get(&"sala_torre")
		if t is Node and bool((t as Node).get(&"costruita")):
			break
	var portone: Node = level.get(&"portone")
	if not bool(portone.call(&"is_aperto")):
		portone.call(&"apri")
		for i in 60 * 15:
			await get_tree().physics_frame
			if bool(portone.call(&"is_aperto")):
				break
	print("  torre costruita %s, portone aperto %s" % [(level.get(&"sala_torre") as Node).get(&"costruita"), portone.call(&"is_aperto")])
	# davanti al portone, nella sala, rivolti a est (verso la torre)
	p.teleport(Vector3(16.5, 0.05, -15.0), -PI / 2.0, 0.0)
	for i in 30:
		await get_tree().physics_frame


func _conta(objects: Dictionary) -> String:
	var interni := 0
	var tecnici := 0
	for k: String in objects:
		if k.begins_with("Interni"):
			interni += 1
		elif k.begins_with("Tecnici"):
			tecnici += 1
	return "%d oggetti, %d di Interni, %d di Tecnici" % [objects.size(), interni, tecnici]


func _entra() -> void:
	var portone: Node = level.get(&"portone")
	var prima := {}
	for n in get_tree().get_nodes_in_group(&"persist"):
		if n.has_method(&"save_state"):
			prima[GameState.persist_key(n)] = true
	print("  persist nella sala prima di entrare: %s" % _conta(prima))
	var preso := [-1, -1.0, ""]
	GameState.checkpoint_reached.connect(func(k):
		preso[0] = Engine.get_physics_frames()
		preso[1] = p.global_position.x
		preso[2] = "%s: %s; dentro_torre %s" % [k, _conta(GameState.snapshot.get("objects", {})), level.get(&"_dentro_torre")])
	var f0 := Engine.get_physics_frames()
	var entrato := -1
	Input.action_press(&"move_forward")
	for i in 60 * 4:
		await get_tree().physics_frame
		p.set_look(-PI / 2.0, 0.0)
		if entrato < 0 and bool(level.get(&"_dentro_torre")):
			entrato = Engine.get_physics_frames()
			print("  dentro la torre (EntrataTorre) al fotogramma %d, x %.2f" % [entrato - f0, p.global_position.x])
		if p.global_position.x > 23.0:
			break
	Input.action_release(&"move_forward")
	print("  checkpoint al fotogramma %d, x %.2f: %s" % [preso[0] - f0, preso[1], preso[2]])
	var interni := level.get_node_or_null(^"Interni")
	for i in 60 * 8:
		await get_tree().physics_frame
	print("  dopo 8 s: x %.2f, Interni %s, Tecnici %s, portone chiuso_dietro %s quanto %.2f" % [p.global_position.x,
		is_instance_valid(interni) and interni.is_inside_tree(), level.get(&"tecnici") != null,
		portone.get(&"chiuso_dietro"), portone.get(&"quanto")])
	print("  istantanea: %s %s" % [GameState.snapshot.get("checkpoint", ""), _conta(GameState.snapshot.get("objects", {}))])
	# una morte: si riparte dal checkpoint
	GameState.respawn()
	await _aspetta_livello()
	for i in 60 * 6:
		await get_tree().physics_frame
	p = GameState.player
	portone = level.get(&"portone")
	print("  ripartito a %s; Interni %s, Tecnici %s; portone chiuso_dietro %s quanto %.2f; luci %d; Polaroid %d; zaino %s" % [
		p.global_position, level.get_node_or_null(^"Interni") != null, level.get(&"tecnici") != null,
		portone.get(&"chiuso_dietro"), portone.get(&"quanto"), GameState.luci, GameState.get_collected_count(&"polaroid"),
		p.has_item(&"zaino_pompa")])
	# prova a uscire dalla torre ripartito: cammina verso ovest
	Input.action_press(&"move_forward")
	for i in 60 * 3:
		await get_tree().physics_frame
		p.set_look(PI / 2.0, 0.0)
	Input.action_release(&"move_forward")
	print("  verso il portone per 3 s: x %.2f (il portone è a 19.84)" % p.global_position.x)


func _torna() -> void:
	var portone: Node = level.get(&"portone")
	var f0 := Engine.get_physics_frames()
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in 60 * 4:
		await get_tree().physics_frame
		p.set_look(-PI / 2.0, 0.0)
		if bool(level.get(&"_dentro_torre")):
			break
	Input.action_release(&"move_forward")
	print("  dentro al fotogramma %d, x %.2f; ora indietro di corsa" % [Engine.get_physics_frames() - f0, p.global_position.x])
	var minimo := p.global_position.x
	var fuori_quando := -1.0
	var giro := 0.0
	Input.action_press(&"move_forward")
	for i in 60 * 6:
		await get_tree().physics_frame
		# si gira in un quarto di secondo, come col mouse
		giro = minf(giro + 1.0 / 15.0, 1.0)
		p.set_look(lerp_angle(-PI / 2.0, PI / 2.0, giro), 0.0)
		minimo = minf(minimo, p.global_position.x)
		if fuori_quando < 0.0 and p.global_position.x < 19.3:
			fuori_quando = float(portone.get(&"quanto"))
			print("  uscito nella sala (x %.2f) a %.2f s, portone aperto ancora al %d%%" % [p.global_position.x,
				float(i) / 60.0, roundi(100.0 * fuori_quando)])
		if p.global_position.x < 15.0:
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	for i in 60 * 8:
		await get_tree().physics_frame
	print("  dopo: x %.2f (minimo %.2f); Interni %s, Tecnici %s; portone chiuso_dietro %s quanto %.2f; checkpoint %s" % [
		p.global_position.x, minimo, level.get_node_or_null(^"Interni") != null, level.get(&"tecnici") != null,
		portone.get(&"chiuso_dietro"), portone.get(&"quanto"), GameState.snapshot.get("checkpoint", "")])


func _aspetta_livello() -> void:
	for i in 1800:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == SCENA and GameState.player and is_instance_valid(GameState.player) \
				and GameState.player.is_inside_tree() and not GameState.is_restoring():
			level = s
			break
	for i in 30:
		await get_tree().physics_frame
