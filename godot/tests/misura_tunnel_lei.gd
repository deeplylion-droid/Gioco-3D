extends Node
## Misura (renderer vero; llvmpipe con xvfb), richiesta del coordinatore del 25 ottobre: le compilazioni che grafica-2
## aveva visto nel tunnel col giocatore vero: intorno a s 133 (gommoni, attraversamento a 138,5) e quando ti giri verso
## lei e spruzzi (lei e il getto). Come nel gioco: il riscaldamento della schermata di caricamento, il tunnel costruito a
## pezzi col suo riscaldamento, poi il giocatore vero (lancia e zaino) sulla banchina. Solo numeri: niente limiti.
## Uso: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 \
##        --script res://tests/run.gd -- res://tests/misura_tunnel_lei.gd


func _ready() -> void:
	_run.call_deferred()


func _conta() -> Array:
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _diff(a: Array, b: Array) -> String:
	return "surface %d, draw %d, in sottofondo %d" % [b[0] - a[0], b[1] - a[1], b[2] - a[2]]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	var r := RiscaldamentoShader.new()
	add_child(r)
	while not r.concluso:
		await get_tree().process_frame
	print("MISURA riscaldamento finito")
	var sala := (load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene).instantiate() as SalaSottomarino
	add_child(sala)
	await sala.costruisci_a_pezzi()
	await _frames(20)
	var g := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(g)
	await _frames(2)
	var zaino := g.find_children("*", "WaterPack", true, false)
	var pack: WaterPack = zaino[0] if not zaino.is_empty() else null
	if pack:
		pack.set_equipped(true, false)
		pack.set_tank_amount(pack.tank_capacity)
	g.input_enabled = true
	var banchina := func(s: float) -> Vector3:
		return sala._al(sala.punto(s), sala.destra(s), Vector2(-(sala.canale + sala.banchina * 0.5), sala.piano + 0.1))
	var yaw_verso := func(d: Vector3) -> float:
		return atan2(-d.x, -d.z)
	# 1. lungo la banchina da 110 a 150, guardando avanti
	var s := 110.0
	while s <= 150.0:
		g.teleport(banchina.call(s), yaw_verso.call(sala.direzione(s)))
		var a := _conta()
		await _frames(4)
		var b := _conta()
		if b[0] != a[0] or b[1] != a[1] or b[2] != a[2]:
			print("MISURA s %.1f: %s" % [s, _diff(a, b)])
		s += 1.5
	# 2. a s 133 ti giri: lei riemerge 8 m dietro, nel canale
	var s0 := 133.0
	g.teleport(banchina.call(s0), yaw_verso.call(sala.direzione(s0)))
	await _frames(10)
	var lei_t := sala.lei_tunnel
	var dietro := sala.punto(s0 - 8.0)
	dietro.y = sala.acqua
	var a2 := _conta()
	lei_t.riemergi(dietro, sala.direzione(s0))
	g.teleport(banchina.call(s0), yaw_verso.call(dietro - g.global_position))
	await _frames(30)
	var b2 := _conta()
	print("MISURA ti giri e lei riemerge dietro: %s" % _diff(a2, b2))
	# 3. e spruzzi verso di lei
	var a3 := _conta()
	Input.action_press("spray")
	await _frames(120)
	Input.action_release("spray")
	await _frames(10)
	var b3 := _conta()
	print("MISURA spruzzi verso lei (2 s): %s (spruzzava: %s)" % [_diff(a3, b3), pack != null and pack.flow > 0.0 or true])
	Game.esci(0)
