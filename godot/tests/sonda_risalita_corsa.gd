extends Node
## Sonda: la corsa del collaudo del 23 ottobre. Dal checkpoint della sala pompe (6) si corre subito verso nord, dove
## la sala pompe passa sotto il corridoio del fiume, mentre le stanze della Risalita arrivano dal thread e si
## costruiscono (qui, per il caso peggiore: appena comincia la costruzione a pezzi il giocatore è già nel punto
## del fermo del collaudo, e poi va avanti verso nord); stampa i fotogrammi sopra i 50 ms, il più lungo, e quando le stanze sono pronte.
## Con "dentro" il giocatore va invece dietro la porta di servizio di C2, dentro la zona: lì la costruzione accelera.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sonda_risalita_corsa.gd [dentro]

const PUNTI := [Vector3(-2.3, -9.05, 42.1), Vector3(-1.4, -9.05, 46.0)]

var _ultimo := 0
var _lunghi: Array = []
var _t0 := 0


func _ready() -> void:
	_run.call_deferred()


func _process(_d: float) -> void:
	var t := Time.get_ticks_usec()
	if _ultimo > 0 and _t0 > 0 and t - _ultimo > 50000:
		_lunghi.append([(t - _t0) / 1e6, (t - _ultimo) / 1000.0, GameState.player.global_position if GameState.player else Vector3()])
	_ultimo = t


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene
	var ris := level.get_node(^"Risalita")
	var p := GameState.player
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var cp := level.get_node(^"Tecnici/Logica/Checkpoint/CheckpointSalaPompe") as Checkpoint
	var spawn := cp.get_spawn_transform()
	p.teleport(spawn.origin, 0.0, 0.0)
	for i in 60:
		await get_tree().physics_frame
	GameState.capture_snapshot(GameState.persist_key(cp), cp.order, spawn)
	_t0 = Time.get_ticks_usec()
	var pronte := -1.0
	var k := 0
	var arrivato := false
	while Time.get_ticks_usec() - _t0 < 15_000_000:
		if not arrivato:
			if ris.get(&"_fiume_nuovo") != null or ris.get(&"fiume") != null:
				arrivato = true
				var dove: Vector3 = PUNTI[0]
				if OS.get_cmdline_user_args().has("dentro"):
					dove = (ris.get_node(^"Marker/CimaScalaFiume") as Node3D).global_position
					k = PUNTI.size()
				p.teleport(dove, 0.0, 0.0)
				print("SONDA costruzione cominciata a %.2f s: giocatore in %s" % [(Time.get_ticks_usec() - _t0) / 1e6, dove])
		elif k < PUNTI.size():
			var d: Vector3 = PUNTI[k] - p.global_position
			d.y = 0.0
			if d.length() < 0.6:
				k += 1
			else:
				p.look_at_point(p.get_eye_position() + d.normalized())
				Input.action_press(&"move_forward")
		else:
			Input.action_release(&"move_forward")
		if pronte < 0.0 and ris.get(&"fiume") != null:
			pronte = (Time.get_ticks_usec() - _t0) / 1e6
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	var peggiore := 0.0
	for l in _lunghi:
		peggiore = maxf(peggiore, l[1])
		print("SONDA  a %.2f s: %.0f ms in %s" % l)
	print("SONDA stanze pronte a %.2f s; fotogrammi sopra 50 ms: %d, il peggiore %.0f ms; giocatore arrivato a %s" % [pronte, _lunghi.size(), peggiore, p.global_position])
	Game.esci(0)
