extends Node
## Ricontrollo delle strisce fosforescenti (enigmi): le pipeline che si compilano la prima volta che si vedono il
## nastro e la fascia in cima alla scala di servizio, dopo il riscaldamento dell'avvio (RiscaldamentoShader), con
## l'ambiente vero della sala. Prima si guarda tutto il resto (le rampe coi bordi dei gradini, il corridoio) con le
## strisce nascoste, poi si mostrano e si contano le compilazioni "surface" e "draw" nei fotogrammi dopo.
## Stampa anche le chiavi di shader del nastro e della fascia e se il riscaldamento ne ha una uguale.

var cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _conta() -> Array:
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	if OS.has_environment("PRESET"):
		Grafica.applica_preset(OS.get_environment("PRESET"))
	# 1. il riscaldamento dell'avvio, come dietro la schermata di caricamento
	# (col riscaldamento e la Risalita insieme llvmpipe supera la memoria: il riscaldamento solo con RISC=1; le strisce
	# non sono fra i suoi materiali, conta il confronto delle chiavi qui sotto)
	var t0 := Time.get_ticks_msec()
	if OS.get_environment("RISC") == "1":
		var r := RiscaldamentoShader.new()
		add_child(r)
		while not r.concluso and Time.get_ticks_msec() - t0 < 900000:
			await get_tree().process_frame
		print("PIPE: riscaldamento %s, %d materiali, %.0f s" % ["finito" if r.concluso else "NON finito", r.totale / 2, (Time.get_ticks_msec() - t0) / 1000.0])
	var chiavi := {}
	for m in RiscaldamentoShader.materiali():
		chiavi[RisorseNodi.chiave_shader(m)] = true
	# 2. la Risalita della scena di prova, con l'ambiente vero
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 10:
		await get_tree().physics_frame
	var p: Player = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	get_tree().current_scene.add_child(env)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var ris := get_tree().current_scene.get_node(^"Risalita") as Node3D
	for i in 2400:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 300:
			break
	var nastro := ris.find_child("NastroCimaScala", true, false) as Node3D
	if nastro == null:
		print("PIPE: MANCA NastroCimaScala")
		get_tree().quit(1)
		return
	for mi in nastro.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override
		print("PIPE: %s: chiave %s nel riscaldamento" % [mi.name, "C'È" if chiavi.has(RisorseNodi.chiave_shader(m)) else "NON c'è"])
	nastro.visible = false
	var marker := ris.get_node(^"Marker")
	var cima := (marker.get_node(^"CimaScala") as Node3D).global_position
	var c3 := (marker.get_node(^"PortaC3") as Node3D).global_position
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	get_tree().current_scene.add_child(cam)
	cam.current = true
	# tutto il resto, senza strisce: verso la porta, verso la rampa e giù per la scala
	var viste := [[cima + Vector3.UP * 1.6, c3 + Vector3.UP * 0.5], [cima + Vector3.UP * 1.6, cima + (cima - c3).normalized() * 3.0 + Vector3.DOWN * 1.5],
		[c3 + (cima - c3) * 0.5 + Vector3.UP * 1.6, cima + Vector3.UP * 0.3], [c3 + (cima - c3).normalized() * 0.8 + Vector3.UP * 1.6, cima]]
	for v in viste:
		cam.global_position = v[0]
		cam.look_at(v[1], Vector3.UP)
		for i in 40:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var prima := _conta()
	nastro.visible = true
	var tot := [0, 0, 0]
	for v in viste:
		cam.global_position = v[0]
		cam.look_at(v[1], Vector3.UP)
		for i in 20:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var c := _conta()
			for k in 3:
				if c[k] > prima[k]:
					tot[k] += c[k] - prima[k]
			prima = c
	print("PIPE: dopo aver mostrato le strisce: surface %d, draw %d, specialization %d" % tot)
	print("PIPE: FINE")
	get_tree().quit()
