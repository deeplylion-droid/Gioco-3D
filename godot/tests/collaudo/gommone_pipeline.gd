extends Node
## Collaudo 0.4.0: le compilazioni di pipeline salendo sui gommoni del tunnel, come test_riscaldamento_pipeline (renderer
## vero): l'ambiente della sala, il riscaldamento del gioco, il tunnel da solo costruito a pezzi, il giocatore vero con lo
## zaino. Per i primi due gommoni del primo attraversamento: il giocatore sulla banchina davanti, poi un salto sul
## gommone (avanti e salto, guardandolo), 90 fotogrammi; ogni fotogramma con compilazioni si stampa (surface, draw,
## specialization). GP:.
## Uso: xvfb-run ... --rendering-driver vulkan --resolution 640x360 --script res://tests/run.gd -- res://tests/collaudo/gommone_pipeline.gd

func _ready() -> void:
	_run.call_deferred()


func _conta() -> Array:
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _osserva(tag: String, n: int) -> Array:
	var tot := [0, 0, 0]
	var prima := _conta()
	for i in n:
		await get_tree().process_frame
		var ora := _conta()
		var d := [int(ora[0] - prima[0]), int(ora[1] - prima[1]), int(ora[2] - prima[2])]
		if d[0] + d[1] + d[2] > 0:
			print("GP: %s fotogramma %d: surface %d, draw %d, specialization %d" % [tag, i, d[0], d[1], d[2]])
			for k in 3:
				tot[k] += d[k]
		prima = ora
	print("GP: %s in %d fotogrammi: surface %d, draw %d, specialization %d" % [tag, n, tot[0], tot[1], tot[2]])
	return tot


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	var r := RiscaldamentoShader.new()
	add_child(r)
	while not r.concluso:
		await get_tree().process_frame
	print("GP: riscaldamento concluso, compilazioni %s" % [_conta()])
	cam.global_position = Vector3(0, 50, 0)
	cam.look_at(Vector3(0, 100, 1))
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	await sala.costruisci_a_pezzi()
	for i in 30:
		await get_tree().process_frame
	var g := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(g)
	await get_tree().process_frame
	var zaini := g.find_children("*", "WaterPack", true, false)
	if not zaini.is_empty():
		(zaini[0] as WaterPack).set_equipped(true, false)
	g.input_enabled = true
	(g.find_children("*", "Camera3D", true, false)[0] as Camera3D).make_current()
	var att: Array = sala.attraversamenti[0]
	var gs: Array = sala._gommoni.slice(0, (att[1] as Array).size() - 1)
	var lato := 1.0
	for o in sala.ostacoli:
		if absf(float(o["s"]) - float(att[0])) < 0.01:
			lato = float(o["lato"])
	var c1 := (gs[0]["corpo"] as Node3D).global_position
	var s1 := float(sala.proietta(c1)[0])
	var piedi := sala._al(sala.punto(s1 - 2.0), sala.destra(s1 - 2.0), Vector2(lato * (sala.canale + 0.4), sala.piano + 0.1))
	var verso := c1 - piedi
	g.teleport(piedi, atan2(-verso.x, -verso.z), -0.3)
	await _osserva("sulla banchina davanti al primo gommone (s %.1f)" % s1, 60)
	for k in mini(2, gs.size()):
		var corpo := gs[k]["corpo"] as Node3D
		var d := corpo.global_position - g.global_position
		g.teleport(g.global_position, atan2(-d.x, -d.z), -0.3)
		Input.action_press(&"move_forward")
		Input.action_press(&"jump")
		await get_tree().process_frame
		Input.action_release(&"jump")
		var tot := await _osserva("salto sul gommone %d" % (k + 1), 90)
		Input.action_release(&"move_forward")
		var su := Vector2(g.global_position.x - corpo.global_position.x, g.global_position.z - corpo.global_position.z).length() < 1.2
		print("GP: gommone %d: il giocatore è sopra %s (y %.2f, gommone %.2f)" % [k + 1, su, g.global_position.y, corpo.global_position.y])
		if not su:
			# (se il salto non c'è arrivato: messo sopra, come chi ci è salito)
			g.teleport(corpo.global_position + Vector3.UP * 0.4, g.yaw, -0.3)
			await _osserva("messo sopra il gommone %d" % (k + 1), 90)
	print("GP: finito")
	get_tree().quit()
