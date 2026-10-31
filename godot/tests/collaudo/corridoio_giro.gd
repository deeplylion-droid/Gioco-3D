extends Node
## Collaudo del corridoio in fondo alla scala del fiume (arredo A+C della 0.3.17), col renderer vero e il giocatore
## vero che cammina: dalla fine della scala alla porta del capannone e indietro, poi accovacciato, guardando avanti, uno
## scatto ogni [constant OGNI] fotogrammi. A ogni fotogramma cerca che cosa c'è fra 0,1 e 2 m sopra i piedi in un
## cilindro di 25 cm (collisioni) e se i piedi si fermano contro qualcosa. Alla fine va alla P13, la guarda e la
## raccoglie col tasto. La Risalita della scena di prova, con l'ambiente della sala senza GI, nebbia volumetrica e SSIL
## (come scatti_corridoio_fiume.gd: se no va oltre la memoria), luci del blackout, bambino e oblò fermi.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/corridoio_giro.gd <cartella>

const OGNI := 20
var p: Player
var cart := ""
var _k := 0


func _ready() -> void:
	cart = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join("%03d_%s.jpg" % [_k, nome]), 0.88)
	_k += 1


## Che cosa c'è fra 0,1 e 2 m sopra i piedi, in un cilindro di 25 cm di raggio (non il giocatore).
func _sopra(piedi: Vector3) -> Array:
	var c := CylinderShape3D.new()
	c.radius = 0.25
	c.height = 1.9
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = c
	q.transform = Transform3D(Basis(), piedi + Vector3.UP * 1.05)
	q.exclude = [p.get_rid()]
	var out := []
	for h in p.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var n = h.collider
		out.append(str(n.get_path()) if n is Node else str(n))
	return out


func _cammina(da: Vector3, a: Vector3, nome: String, accovacciato: bool) -> void:
	p.teleport(da)
	await _frames(4)
	if accovacciato:
		Input.action_press(&"crouch")
		await _frames(30)
	var fermo := 0
	var max_fermo := 0
	var prima := p.global_position
	var trovati := {}
	Input.action_press(&"move_forward")
	for f in 60 * 25:
		p.look_at_point(Vector3(a.x, p.global_position.y + 1.3, a.z))
		await get_tree().physics_frame
		var piedi := p.global_position
		for s in _sopra(piedi):
			if not trovati.has(s):
				trovati[s] = piedi.snapped(Vector3.ONE * 0.01)
		fermo = fermo + 1 if piedi.distance_to(prima) < 0.004 else 0
		max_fermo = maxi(max_fermo, fermo)
		prima = piedi
		if f % OGNI == 0:
			await _scatto(nome)
		if Vector2(piedi.x - a.x, piedi.z - a.z).length() < 0.6 or fermo > 90:
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"crouch")
	print("CORRIDOIO: %s: da %s a %s, arrivato a %s, fermo al più %d fotogrammi di fila" % [nome, da.snapped(Vector3.ONE * 0.01),
			a.snapped(Vector3.ONE * 0.01), p.global_position.snapped(Vector3.ONE * 0.01), max_fermo])
	for s in trovati:
		print("CORRIDOIO:   fra 0,1 e 2 m sopra i piedi: %s (la prima volta coi piedi in %s)" % [s, trovati[s]])
	await _frames(30)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.volumetric_fog_enabled = false
	env.environment.ssil_enabled = false
	get_tree().current_scene.add_child(env)
	var ris := get_tree().current_scene.get_node(^"Risalita")
	var b := ris.find_child("BambinoCorridoioFiume", true, false) as Node3D
	if b:
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b.visible = false
	var oblo := ris.find_child("ObloFiume", true, false)
	if oblo:
		oblo.set(&"attivo", false)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var m := ris.get_node(^"Marker")
	var fondo := (m.get_node(^"FondoScalaFiume") as Node3D).global_position
	var porta := (m.get_node(^"PortaFiume") as Node3D).global_position
	p.teleport(fondo)
	for i in 3600:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 300:
			break
	print("CORRIDOIO: fondo della scala %s, porta %s" % [fondo.snapped(Vector3.ONE * 0.01), porta.snapped(Vector3.ONE * 0.01)])
	var da := fondo + Vector3(0, 0, 0.8)
	var a := porta + Vector3(0, 0, -0.8)
	await _cammina(da, a, "andata", false)
	await _cammina(a, da, "ritorno", false)
	await _cammina(da, a, "accovacciato", true)
	# la P13
	var p13: PolaroidPhoto = null
	for f in ris.find_children("*", "PolaroidPhoto", true, false):
		if int(f.get(&"photo")) == 13:
			p13 = f
	if p13 == null:
		print("CORRIDOIO: ERRORE nessuna P13")
		get_tree().quit()
		return
	var c := p13.global_position
	print("CORRIDOIO: P13 in %s, visibile %s" % [c.snapped(Vector3.ONE * 0.01), p13.is_visible_in_tree()])
	# dalla strada, in piedi a 1,5 m, guardando avanti e poi lei
	p.teleport(Vector3(-5.0, fondo.y, c.z - 1.5))
	await _frames(20)
	p.look_at_point(Vector3(-5.0, fondo.y + 1.3, c.z + 3.0))
	await _frames(10)
	await _scatto("p13_passando")
	p.teleport(Vector3(c.x - 0.8, fondo.y, c.z - 0.2))
	await _frames(20)
	p.look_at_point(c + Vector3.UP * 0.01)
	await _frames(10)
	await _scatto("p13_guardata")
	var prima := GameState.get_collected_count(&"polaroid")
	var vista = p.interactor.current
	Input.action_press(&"interact")
	await _frames(3)
	Input.action_release(&"interact")
	await _frames(20)
	await _scatto("p13_raccolta")
	Input.action_press(&"interact")
	await _frames(3)
	Input.action_release(&"interact")
	await _frames(10)
	Input.action_press(&"ui_cancel")
	await _frames(3)
	Input.action_release(&"ui_cancel")
	await _frames(20)
	if get_tree().paused:
		get_tree().paused = false
	print("CORRIDOIO: P13 raccolta %s (collezione da %d a %d), il raggio di chi guarda trovava %s" % [
			GameState.get_collected_count(&"polaroid") > prima, prima, GameState.get_collected_count(&"polaroid"), vista])
	await _frames(20)
	await _scatto("p13_dopo")
	print("CORRIDOIO: finito")
	get_tree().quit()
