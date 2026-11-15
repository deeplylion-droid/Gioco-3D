extends Node
## Collaudo: le gallerie basse del tunnel col giocatore vero, una alla volta (GAL=0 la 205, GAL=1 la 425), con lo
## stesso modo di test_sottomarino_gioco (verso la bocca, accovacciati, lungo la galleria fino alla bocca d'uscita).
## Se resta fermo più di 1 s prova come farebbe una persona: un passo a destra, poi a sinistra, poi indietro e avanti.
## Stampa ogni 0,25 s dove si è e, se si resta fermi, cosa tocca. Lei è ferma (VIA).
## Uso: GAL=1 godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_galleria.gd

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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
	var sott := level.get_node("SalaSottomarino") as SalaSottomarino
	sott.costruisci()
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var k := int(OS.get_environment("GAL")) if OS.get_environment("GAL") != "" else 1
	var gal: Dictionary = sott.ostacoli.filter(func(o): return o["tipo"] == "galleria")[k]
	var lato := float(gal["lato"])
	var s_in: float = float(gal["s"]) - SalaSottomarino.GALLERIA_BOCCA - 2.0
	var st := sott.punto(s_in) + sott.destra(s_in) * lato * (sott.muro - 0.6)
	p.teleport(Vector3(st.x, sott.piano + 0.05, st.z))
	await _frames(10)
	var fine_g: float = float(gal["s"]) + float(gal["lungo"]) + SalaSottomarino.GALLERIA_BOCCA + 1.5
	var bocca0: float = float(gal["s"]) - SalaSottomarino.GALLERIA_BOCCA * 0.5
	var bocca1: float = float(gal["s"]) + float(gal["lungo"]) + SalaSottomarino.GALLERIA_BOCCA * 0.5
	var u_gal := sott.muro + sott.spessore + SalaSottomarino.GALLERIA_LARGA * 0.5
	print("GALLERIA: %d a s %.0f lato %.0f, bocche %.1f-%.1f, centro della galleria a %.2f dall'asse (muro %.2f spessore %.2f)" % [k, float(gal["s"]), lato, bocca0, bocca1, u_gal, sott.muro, sott.spessore])
	Input.action_press(&"move_forward")
	var s_p := s_in
	var t := 0
	var fermo := 0
	var ultima := p.global_position
	var prove := [&"move_right", &"move_left", &"move_back"]
	var prova := 0
	while s_p < fine_g and t < 60 * 40:
		var pr: Array = sott.proietta_vicino(p.global_position, s_p)
		s_p = float(pr[0])
		var s_q := s_p + 2.0
		var u := sott.muro - 0.6
		if s_p < bocca0 - 0.3:
			s_q = bocca0
			u = u_gal
		elif s_p < bocca1 - 0.3:
			s_q = minf(s_p + 2.0, bocca1)
			u = u_gal
		var q := sott.punto(s_q) + sott.destra(s_q) * lato * u
		p.look_at_point(Vector3(q.x, p.global_position.y + 1.0, q.z))
		p.set_look(p.yaw, 0.0)
		if sott.in_tubo(p.global_position):
			Input.action_release(&"crouch")
		elif s_p > bocca0 - 1.5 and s_p < bocca0 + 1.0:
			Input.action_press(&"crouch")
		await _frames(1)
		t += 1
		if t % 15 == 0:
			var mosso := p.global_position.distance_to(ultima)
			ultima = p.global_position
			fermo = fermo + 1 if mosso < 0.05 else 0
			print("GALLERIA: %.2f s s %.2f lato %.2f y %.2f tubo %s acc %s muro %s vel %s" % [t / 60.0, s_p, float(pr[1]), p.global_position.y, sott.in_tubo(p.global_position), p.is_crouching, p.is_on_wall(), str(p.velocity.snappedf(0.01))])
			if fermo == 4:
				_cosa_tocca(p, q)
				if prova < prove.size():
					print("GALLERIA: fermo, provo ", prove[prova])
					Input.action_press(prove[prova])
					await _frames(30)
					Input.action_release(prove[prova])
					prova += 1
					fermo = 0
	print("GALLERIA: %d %s a s %.2f di %.2f in %.1f s" % [k, "PASSATA" if s_p >= fine_g else "NON PASSATA", s_p, fine_g, t / 60.0])
	get_tree().quit()


func _cosa_tocca(p: Player, q: Vector3) -> void:
	var spazio := p.get_world_3d().direct_space_state
	var dir := Vector3(q.x - p.global_position.x, 0, q.z - p.global_position.z).normalized()
	for c in p.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape and not (c as CollisionShape3D).disabled:
			var qs := PhysicsShapeQueryParameters3D.new()
			qs.shape = (c as CollisionShape3D).shape
			qs.transform = (c as CollisionShape3D).global_transform.translated(dir * 0.1)
			qs.collision_mask = p.collision_mask
			qs.exclude = [p.get_rid()]
			for hit in spazio.intersect_shape(qs, 8):
				print("GALLERIA:   la forma %s spostata di 10 cm verso dove va tocca %s" % [c.name, (hit.collider as Node).get_path()])
	for h in [0.1, 0.5, 0.9, 1.2]:
		var a: Vector3 = p.global_position + Vector3.UP * h
		var r := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + dir * 2.0, p.collision_mask, [p.get_rid()]))
		print("GALLERIA:   raggio verso dove va a h %.1f: %s" % [h, ("%.2f m %s" % [a.distance_to(r.position), (r.collider as Node).get_path()]) if r else "libero"])
