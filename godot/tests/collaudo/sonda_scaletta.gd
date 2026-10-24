extends Node
## Collaudo: la scaletta del bacino dopo SB1 (dalla vasca alla porta del tunnel), col giocatore vero, in tre modi:
## A) su guardando in alto fino a 40 cm dalla cima, poi verso la porta e avanti (come la partita automatica);
## B) avanti guardando la scaletta finché scavalca da solo, poi verso la porta;
## C) avanti guardando la porta (in orizzontale) da subito, dal piede della scaletta.
## Stampa ogni 0,25 s posizione, scala sì/no, a terra, velocità. Uso:
##   godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_scaletta.gd [A,B,C]

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"

var ins: SalaInseguimento
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _yaw(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	var level := get_tree().current_scene
	p = GameState.player
	ins = level.get_node("SalaInseguimento") as SalaInseguimento
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var sc: Dictionary = ins.dati["scale"][ins.dati["scale"].size() - 1]
	var piede := SalaInseguimento.b([float(sc["x"]), float(sc["y"]), float(sc["z0"])])
	var cima := SalaInseguimento.b([float(sc["x"]), float(sc["y"]), float(sc["z1"])])
	var porta := SalaInseguimento.b(ins.dati["porta"]["pos"])
	var uscita := SalaInseguimento.b(ins.dati["porta"]["uscita"])
	print("SCALETTA: piede ", piede, " cima ", cima, " porta ", porta, " uscita ", uscita)
	var modi := (OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "A,B,C").split(",")
	print("SCALETTA: maschera del giocatore ", p.collision_mask)
	for modo in modi:
		print("SCALETTA: --- modo ", modo)
		p.teleport(piede + (piede - cima).normalized() * 0.0 + Vector3(1.2, 0.05, 0.0))
		await _frames(10)
		# al piede: verso la scaletta
		var verso := Vector3(piede.x - p.global_position.x, 0.0, piede.z - p.global_position.z)
		p.set_look(_yaw(verso), 0.0)
		Input.action_press(&"move_forward")
		var t := 0
		var fase := "su"
		while t < 60 * 14:
			await _frames(1)
			t += 1
			match modo:
				"A":
					if fase == "su":
						p.set_look(_yaw(Vector3(cima.x - p.global_position.x, 0, cima.z - p.global_position.z)) if Vector2(cima.x - p.global_position.x, cima.z - p.global_position.z).length() > 0.05 else p.yaw, 0.6)
						if p.global_position.y > cima.y - 0.4:
							fase = "porta"
							Input.action_release(&"move_forward")
							await _frames(10)
							Input.action_press(&"move_forward")
					else:
						p.set_look(_yaw(Vector3(uscita.x - p.global_position.x, 0, uscita.z - p.global_position.z)), 0.0)
				"B":
					if fase == "su":
						p.set_look(_yaw(Vector3(piede.x - p.global_position.x, 0, piede.z - p.global_position.z)) if Vector2(piede.x - p.global_position.x, piede.z - p.global_position.z).length() > 0.05 else p.yaw, 0.6)
						if p.ladder == null and p.global_position.y > cima.y - 0.2:
							fase = "porta"
					else:
						p.set_look(_yaw(Vector3(uscita.x - p.global_position.x, 0, uscita.z - p.global_position.z)), 0.0)
				"D":
					if fase == "su":
						p.set_look(_yaw(Vector3(piede.x - p.global_position.x, 0, piede.z - p.global_position.z)) if Vector2(piede.x - p.global_position.x, piede.z - p.global_position.z).length() > 0.05 else p.yaw, 0.6)
						if p.ladder == null and p.global_position.y > cima.y - 0.2:
							fase = "porta"
							await _frames(60)
							var prima := p.global_position
							for prova in [&"jump", &"move_left", &"move_right", &"move_back"]:
								var da := p.global_position
								Input.action_press(prova)
								await _frames(30)
								Input.action_release(prova)
								await _frames(30)
								print("SCALETTA: D dopo %s si è mosso di %.2f m (pos %s)" % [prova, p.global_position.distance_to(da), str(p.global_position.snappedf(0.01))])
							print("SCALETTA: D in tutto mosso di %.2f m dal punto incastrato" % p.global_position.distance_to(prima))
					else:
						p.set_look(_yaw(Vector3(uscita.x - p.global_position.x, 0, uscita.z - p.global_position.z)), 0.0)
				"C":
					p.set_look(_yaw(Vector3(uscita.x - p.global_position.x, 0, uscita.z - p.global_position.z)), 0.0)
			if fase == "porta" and OS.get_environment("OGNI_FOTOGRAMMA") != "" and t % 2 == 0 and t < 60 * 9:
				print("SCALETTA: f %d pos %s scala %s dall_alto %s attesa %.2f terra %s vel %s muri %s" % [t, str(p.global_position.snappedf(0.001)), p.ladder != null, p.get(&"_ladder_from_top"), float(p.get(&"_ladder_cooldown")), p.is_on_floor(), str(p.velocity.snappedf(0.01)), p.is_on_wall()])
			if t % 15 == 0:
				print("SCALETTA: %s %.2f s %s pos %s scala %s terra %s vel %s dist_uscita %.2f" % [modo, t / 60.0, fase, str(p.global_position.snappedf(0.01)), p.ladder != null, p.is_on_floor(), str(p.velocity.snappedf(0.01)), Vector2(uscita.x - p.global_position.x, uscita.z - p.global_position.z).length()])
			if Vector2(uscita.x - p.global_position.x, uscita.z - p.global_position.z).length() < 0.5:
				print("SCALETTA: %s ARRIVATO all'uscita in %.2f s" % [modo, t / 60.0])
				break
		Input.action_release(&"move_forward")
		await _frames(20)
		_cosa_blocca(uscita)
	get_tree().quit()


func _cosa_blocca(uscita: Vector3) -> void:
	var spazio := p.get_world_3d().direct_space_state
	print("SCALETTA: comandi %s accovacciato %s pos %s" % [p.input_enabled, p.is_crouching, str(p.global_position)])
	var dir := Vector3(uscita.x - p.global_position.x, 0, uscita.z - p.global_position.z).normalized()
	for d in [dir, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT]:
		for h in [0.05, 0.3, 0.9, 1.5, 1.85]:
			var a: Vector3 = p.global_position + Vector3.UP * h
			var q := PhysicsRayQueryParameters3D.create(a, a + d * 2.5, p.collision_mask, [p.get_rid()])
			var r := spazio.intersect_ray(q)
			print("SCALETTA:   raggio %s h %.2f: %s" % [str(d.snappedf(0.01)), h, ("%.2f m %s" % [a.distance_to(r.position), (r.collider as Node).get_path()]) if r else "libero"])
	# cosa tocca la forma del giocatore spostata di 15 cm verso l'uscita
	for c in p.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape:
			var qs := PhysicsShapeQueryParameters3D.new()
			qs.shape = (c as CollisionShape3D).shape
			qs.transform = (c as CollisionShape3D).global_transform.translated(dir * 0.15)
			qs.collision_mask = p.collision_mask
			qs.exclude = [p.get_rid()]
			for hit in spazio.intersect_shape(qs, 16):
				print("SCALETTA:   la forma %s spostata verso l'uscita tocca %s" % [c.name, (hit.collider as Node).get_path()])
