extends Node
## Misura (renderer vero): le compilazioni di pipeline alla prima curva del tunnel, quando le condotte si liberano
## (collaudo dell'inseguimento del 29 ottobre: 10-15 compilazioni lì). Nella scena di prova del tunnel, costruito come
## nel gioco (a pezzi, col suo riscaldamento e lei preparata) o, con SUBITO=1, tutto subito come nella partita del
## collaudo. Il giocatore vero sulla banchina guarda la strada da s 0 a s 70, poi a s 58 le condotte si liberano (la sala
## dell'inseguimento tolta, come nella partita), e si contano le compilazioni che bloccano (surface e draw).
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 640x360 --fixed-fps 60 \
##        --script res://tests/run.gd -- res://tests/collaudo/misura_prima_curva.gd

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"


func _ready() -> void:
	_run.call_deferred()


func _conta() -> Array:
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _diff(a: Array, b: Array) -> String:
	return "surface %d, draw %d, in sottofondo %d" % [b[0] - a[0], b[1] - a[1], b[2] - a[2]]


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	var level := get_tree().current_scene
	var p := GameState.player
	var ins := level.get_node("SalaInseguimento") as Node3D
	var sott := level.get_node("SalaSottomarino") as SalaSottomarino
	if OS.get_environment("SUBITO") == "1":
		sott.costruisci()
	else:
		await sott.costruisci_a_pezzi()
	p.water_pack.set_equipped(true, false)
	p.input_enabled = false
	var banchina := func(s: float) -> Vector3:
		return sott._al(sott.punto(s), sott.destra(s), Vector2(-(sott.canale + sott.banchina * 0.5), sott.piano + 0.1))
	var yaw := func(d: Vector3) -> float:
		return atan2(-d.x, -d.z)
	await _frames(20)
	var a := _conta()
	var s := 0.0
	while s <= 70.0:
		p.teleport(banchina.call(s), yaw.call(sott.direzione(s)))
		var a1 := _conta()
		await _frames(4)
		var b1 := _conta()
		if b1[0] != a1[0] or b1[1] != a1[1]:
			print("MISURA strada s %.0f: %s" % [s, _diff(a1, b1)])
		s += 2.0
	print("MISURA strada da 0 a 70: %s" % _diff(a, _conta()))
	# alla prima curva le condotte si liberano
	p.teleport(banchina.call(58.0), yaw.call(sott.direzione(58.0)))
	await _frames(10)
	var c := _conta()
	ins.queue_free()
	await _frames(30)
	print("MISURA condotte liberate a s 58: %s" % _diff(c, _conta()))
	var d := _conta()
	s = 58.0
	while s <= 90.0:
		p.teleport(banchina.call(s), yaw.call(sott.direzione(s)))
		await _frames(4)
		s += 2.0
	print("MISURA strada da 58 a 90 dopo: %s" % _diff(d, _conta()))
	Game.esci(0)
