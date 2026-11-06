extends Node
## Collaudo dei ritocchi di ambienti-2 (dopo la 0.3.20), col renderer vero: la torre da sola con l'inseguimento,
## l'ambiente della sala, al buio dopo la sala pompe, le paratie aperte, lei che non prende. Fasi (secondo argomento):
##  - scaletta: dopo SB1 (il faro della scaletta e la luce della porta accesi, come nel gioco), dall'acqua del bacino in
##    piedi e accovacciati a 1 e 2 m, i ravvicinati della curva sul bordo e dei pioli nuovi contro il muro (col faro, e
##    con una lampadina tecnica accanto alla camera), poi la salita col giocatore vero dall'acqua alla porta in cima;
##  - bocche: le 6 bocche dei tubi e degli scoli delle vasche dei bivi, il giocatore accovacciato che entra dalla vasca
##    (uno scatto ogni 6 fotogrammi fino a 3 m dentro), più uno scatto girato verso la vasca a 1,2 m dentro.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/vista_bacino.gd <cartella> <scaletta|bocche>

const PLAYER := "res://scenes/player/player.tscn"
var cart := ""
var p: Player
var ins: SalaInseguimento


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.88)


func _libera(da: Vector3, verso: Vector3, nome: String, fov := 55.0, luce := false) -> void:
	var c := Camera3D.new()
	c.fov = fov
	c.near = 0.03
	c.attributes = p.camera.attributes
	add_child(c)
	c.global_position = da
	c.look_at(verso, Vector3.UP)
	c.current = true
	if luce:
		var o := OmniLight3D.new()
		o.light_energy = 1.0
		o.omni_range = 2.5
		c.add_child(o)
	await _frames(12)
	await _scatto(nome)
	c.current = false
	c.queue_free()
	p.camera.current = true


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	DirAccess.make_dir_recursive_absolute(cart)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	await _frames(20)
	ins = torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	for k in (ins.dati["paratie"] as Array).size():
		ins.apri_paratia(k)
	await _frames(240)
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(5)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	if a[2] == "scaletta":
		await _scaletta()
	else:
		await _bocche()
	print("VISTA: finito")
	get_tree().quit()


func _scaletta(solo_salita := false) -> void:
	var sc: Dictionary = ins.dati["scale"][ins.dati["scale"].size() - 1]
	var piede := SalaInseguimento.b([sc["x"], sc["y"], sc["z0"]])
	var cima := SalaInseguimento.b([sc["x"], sc["y"], sc["z1"]])
	var scala := ins.find_children("*", "Ladder", true, false)[0] as Ladder
	var n := scala.get_climb_normal()
	# dopo SB1: il tunnel "pronto" (qui non c'è), poi quello che fa il gioco quando lei si tuffa
	AttesaZone.pronta(&"tunnel")
	p.teleport(piede + n * 2.0 + Vector3.UP * 0.1)
	await _frames(10)
	ins.call(&"_dopo_sb1")
	await _frames(120)
	var faro := ins.find_child("FaroScaletta", true, false) as Light3D
	print("VISTA: scaletta piede %s cima %s, verso chi sale %s; faro %s energia %.1f" % [piede.snapped(Vector3.ONE * 0.01),
			cima.snapped(Vector3.ONE * 0.01), n.snapped(Vector3.ONE * 0.01), faro != null, faro.light_energy if faro else -1.0])
	var lato := n.cross(Vector3.UP)
	for d in ([] if solo_salita else [2.0, 1.0]):
		for acc in [false, true]:
			p.teleport(piede + n * d + Vector3.UP * 0.1)
			if acc:
				Input.action_press(&"crouch")
			await _frames(30)
			p.look_at_point(piede + Vector3.UP * 1.0)
			await _frames(8)
			await _scatto("scaletta_occhi_%.0fm_%s" % [d, "accovacciato" if acc else "in_piedi"])
			Input.action_release(&"crouch")
	# i ravvicinati: il bordo è a circa 1,2 m sopra il piede, i pioli nuovi a -33,1 e -33,4 (il pelo a -33,26)
	var bordo := piede + Vector3.UP * 1.0
	for luce in ([] if solo_salita else [false, true]):
		var s := "_luce" if luce else ""
		await _libera(bordo + n * 0.55 + lato * 0.45 + Vector3.UP * 0.35, bordo, "vicino_curva_bordo" + s, 55.0, luce)
		await _libera(bordo + lato * 0.7 + Vector3.UP * 0.1 + n * 0.15, bordo - lato * 0.1, "vicino_curva_di_lato" + s, 55.0, luce)
		var pioli := Vector3(piede.x, -33.25, piede.z)
		await _libera(pioli + n * 0.6 + lato * 0.35 + Vector3.UP * 0.12, pioli, "vicino_pioli_pelo" + s, 55.0, luce)
		await _libera(pioli + lato * 0.6 + n * 0.12 + Vector3.UP * 0.05, pioli - lato * 0.1, "vicino_pioli_di_lato" + s, 55.0, luce)
		await _libera(cima + n * 0.3 + Vector3.UP * 0.8, piede + Vector3.UP * 1.2, "dall_alto" + s, 60.0, luce)
	# la salita col giocatore vero, dall'acqua alla porta
	var porta := SalaInseguimento.b(ins.dati["porta"]["pos"])
	p.teleport(piede + n * 1.0 + Vector3.UP * 0.1)
	await _frames(30)
	p.look_at_point(piede + Vector3.UP * 1.6)
	var presa := false
	var t_presa := -1.0
	var alto := -INF
	Input.action_press(&"move_forward")
	var f := 0
	var in_cima := false
	for i in 60 * 25:
		if not in_cima:
			p.set_look(atan2(n.x, n.z), 0.6)
		else:
			var g := porta - p.global_position
			p.set_look(atan2(-g.x, -g.z), 0.0)
		await get_tree().physics_frame
		if p.is_on_ladder() and not presa:
			presa = true
			t_presa = i / 60.0
		alto = maxf(alto, p.global_position.y)
		if presa and not p.is_on_ladder() and p.global_position.y > cima.y - 0.3:
			in_cima = true
		if i % 10 == 0:
			await _scatto("salita_%03d" % f)
			f += 1
		if in_cima and Vector2(p.global_position.x - porta.x, p.global_position.z - porta.z).length() < 0.8:
			break
	Input.action_release(&"move_forward")
	print("VISTA: salita dall'acqua: presa %s (dopo %.1f s), piedi da %.2f fino a %.2f (cima %.2f), arrivato in cima %s, fine %s, porta %s" % [
			presa, t_presa, piede.y, alto, cima.y, in_cima, p.global_position.snapped(Vector3.ONE * 0.01), porta.snapped(Vector3.ONE * 0.01)])


func _bocche() -> void:
	var veli := ins.find_children(SalaInseguimento.NOME_VELO + "*", "MeshInstance3D", true, false)
	for nome: String in ["ins_A_tubo_1", "ins_A_scolo_0", "ins_A_tubo_2", "ins_A_scolo_1", "ins_A_tubo_3", "ins_A_scolo_2"]:
		if ins.lei:
			ins.lei.visible = false
		var linea := PackedVector3Array()
		for q in ins.dati["tubi"][nome]:
			linea.append(SalaInseguimento.b(q))
		var velo: MeshInstance3D = null
		for v in veli:
			if velo == null or (v as Node3D).global_position.distance_to(linea[0]) < velo.global_position.distance_to(linea[0]):
				velo = v
		var dir := linea[3] - linea[0]
		dir.y = 0.0
		dir = dir.normalized()
		p.teleport(linea[0] - dir * 2.0 + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.1) + Vector3.UP * 0.5)
		await _frames(20)
		p.velocity = Vector3.ZERO
		Input.action_press(&"crouch")
		await _frames(20)
		Input.action_press(&"move_forward")
		var ultimo := 0
		var k := 0
		var girato := false
		for f in 60 * 12:
			var piedi := p.global_position
			var iv := ultimo
			for i in range(ultimo, mini(ultimo + 12, linea.size())):
				if linea[i].distance_to(piedi) < linea[iv].distance_to(piedi):
					iv = i
			ultimo = iv
			var av := mini(iv + 4, linea.size() - 1)
			var g := linea[av] - piedi
			g.y = 0.0
			if g.length() > 0.2:
				p.set_look(atan2(-g.x, -g.z), -0.15)
			await get_tree().physics_frame
			var lz := (velo.global_transform.affine_inverse() * p.camera.global_position).z
			if f % 6 == 0:
				await _scatto("%s_%03d_%.2fm" % [nome, k, lz])
				k += 1
			if lz > 1.2 and not girato:
				girato = true
				var y0 := p.yaw
				p.set_look(atan2(dir.x, dir.z), -0.2)
				await _frames(2)
				await _scatto("%s_girato_verso_la_vasca" % nome)
				p.set_look(y0, -0.15)
			if lz > 3.0:
				break
		Input.action_release(&"move_forward")
		Input.action_release(&"crouch")
		await _frames(20)
