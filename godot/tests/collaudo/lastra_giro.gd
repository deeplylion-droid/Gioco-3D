extends Node
## Collaudo di lavoro/varchi-cielo (ambienti-1): la lastra che chiude la fessura di 31 cm fra la camera delle onde e la
## sala pompe (pavimento_giunzione_onde, tecnici.gd). Tecnici da solo messo come nella sala (TECNICI_IN_SALA), con le
## sue luci, l'ambiente della sala e il giocatore vero. Fasi:
##  - passi: il giocatore vero attraversa la giunzione camminando, correndo e saltando, in 5 punti della larghezza e nei
##    due versi: quota dei piedi, velocità verticale, se perde il pavimento e se rallenta (PASSI:);
##  - occhi: attraversando a piedi, dagli occhi, guardando in basso, uno scatto ogni 6 fotogrammi, nei due versi;
##  - vicino: ravvicinati del bordo al centro e alle due estremità contro i muri, radenti e dall'alto, con e senza una
##    lampadina tecnica; e lo sfarfallio: da 2, 5 e 9 m, radente, 8 scatti spostando la camera di 1 cm, e quanto cambia
##    la striscia della giunzione da uno all'altro (VICINO:).
## Uso: xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##   --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/lastra_giro.gd <cartella> [fasi]

const TECNICI_IN_SALA := Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), Vector3(0, -9.05, 1.36))
const PLAYER := "res://scenes/player/player.tscn"
const Z0 := 25.35
const Z1 := 25.66
const PAVIMENTO := -9.05
var cart := ""
var p: Player
var t: Node3D


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.9)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	var fasi := (a[2] if a.size() > 2 else "passi,occhi,vicino").split(",")
	DirAccess.make_dir_recursive_absolute(cart)
	var we := WorldEnvironment.new()
	we.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	we.environment.sdfgi_enabled = false
	we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(we)
	t = (load("res://scenes/tecnici/tecnici.tscn") as PackedScene).instantiate() as Node3D
	t.set(&"giocatore_proprio", false)
	t.transform = TECNICI_IN_SALA
	add_child(t)
	await _frames(30)
	var lastra := t.find_child("pavimento_giunzione_onde", true, false) as MeshInstance3D
	var ab := lastra.global_transform * lastra.get_aabb()
	print("VICINO: lastra %s, scatola %s .. %s" % [lastra != null, ab.position.snapped(Vector3.ONE * 0.001), ab.end.snapped(Vector3.ONE * 0.001)])
	# il pavimento vero ai due lati e sulla lastra (raggi in giù)
	var spazio := get_viewport().world_3d.direct_space_state
	for z in [Z0 - 0.3, Z0 + 0.05, 25.505, Z1 - 0.05, Z1 + 0.3]:
		var righe := []
		for x in [-2.2, -1.1, 0.0, 1.1, 2.2]:
			var h := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, -8.0, z), Vector3(x, -10.5, z)))
			righe.append("%.3f" % (h.position as Vector3).y if h else "nulla")
		print("VICINO: pavimento (collisioni) a z %.3f, x da -2,2 a 2,2: %s" % [z, ", ".join(righe)])
	if OS.has_environment("SENZA_LASTRA"):
		print("VICINO: lastra tolta per il confronto")
		lastra.free()
		lastra = null
		await _frames(5)
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(5)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	if "passi" in fasi:
		await _passi()
	if "occhi" in fasi:
		await _occhi()
	if "vicino" in fasi:
		await _vicino(lastra)
	print("VICINO: finito")
	get_tree().quit()


func _attraversa(x: float, verso: float, modo: String) -> String:
	var z_da := 25.505 - verso * 3.0
	p.teleport(Vector3(x, PAVIMENTO + 0.1, z_da))
	await _frames(20)
	p.velocity = Vector3.ZERO
	p.set_look(0.0 if verso < 0.0 else PI, 0.0)
	await _frames(5)
	Input.action_press(&"move_forward")
	if modo == "corsa":
		Input.action_press(&"sprint")
	var y_min := INF
	var y_max := -INF
	var vy_max := 0.0
	var in_aria := 0
	var v_prima := 0.0
	var v_min_giunzione := INF
	var salto_fatto := false
	var arrivato := false
	for f in 60 * 4:
		var z := p.global_position.z
		if modo == "salto" and not salto_fatto and absf(z - 25.505) < 0.7:
			salto_fatto = true
			Input.action_press(&"jump")
		await get_tree().physics_frame
		Input.action_release(&"jump")
		z = p.global_position.z
		var vh := Vector2(p.velocity.x, p.velocity.z).length()
		var vicino := absf(z - 25.505) < 0.5
		if absf(z - 25.505) > 0.8 and absf(z - 25.505) < 1.6 and (z - 25.505) * verso < 0.0:
			v_prima = maxf(v_prima, vh)
		if vicino:
			y_min = minf(y_min, p.global_position.y)
			y_max = maxf(y_max, p.global_position.y)
			if modo != "salto":
				vy_max = maxf(vy_max, absf(p.velocity.y))
				if not p.is_on_floor():
					in_aria += 1
				v_min_giunzione = minf(v_min_giunzione, vh)
		if (z - 25.505) * verso > 1.5:
			arrivato = true
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	var r := "%s x %+.1f verso %s: arrivato %s, piedi sulla giunzione fra %.3f e %.3f" % [modo, x, "nord" if verso > 0.0 else "sud", arrivato, y_min, y_max]
	if modo != "salto":
		r += ", velocità verticale max %.3f m/s, fotogrammi senza pavimento %d, velocità prima %.2f e minima sulla giunzione %.2f m/s" % [vy_max, in_aria, v_prima, v_min_giunzione]
	await _frames(10)
	return r


func _passi() -> void:
	for modo in ["cammino", "corsa", "salto"]:
		for x in ([-1.0, -0.5, 0.0, 0.5, 1.0] if OS.has_environment("SENZA_LASTRA") or OS.has_environment("FITTO") else [-2.0, -1.0, 0.0, 1.0, 2.0]):
			for verso in [1.0, -1.0]:
				print("PASSI: " + await _attraversa(x, verso, modo))


func _occhi() -> void:
	for verso in [1.0, -1.0]:
		p.teleport(Vector3(0.4, PAVIMENTO + 0.1, 25.505 - verso * 4.0))
		await _frames(20)
		p.velocity = Vector3.ZERO
		var yaw := 0.0 if verso < 0.0 else PI
		p.set_look(yaw, -0.55)
		await _frames(5)
		Input.action_press(&"move_forward")
		var k := 0
		for f in 60 * 5:
			p.set_look(yaw, -0.55)
			await get_tree().physics_frame
			if f % 6 == 0:
				await _scatto("occhi_%s_%03d_z%.2f" % ["verso_nord" if verso > 0.0 else "verso_sud", k, p.global_position.z])
				k += 1
			if (p.global_position.z - 25.505) * verso > 2.5:
				break
		Input.action_release(&"move_forward")
		await _frames(10)


func _libera(da: Vector3, verso: Vector3, nome: String, luce := false) -> Image:
	var c := Camera3D.new()
	c.fov = 55.0
	c.near = 0.02
	c.attributes = p.camera.attributes
	add_child(c)
	c.global_position = da
	c.look_at(verso, Vector3.UP if absf((verso - da).normalized().y) < 0.95 else Vector3.RIGHT)
	c.current = true
	if luce:
		var o := OmniLight3D.new()
		o.light_energy = 1.0
		o.omni_range = 3.0
		c.add_child(o)
	await _frames(10)
	await _scatto(nome)
	var im := get_viewport().get_texture().get_image()
	c.current = false
	c.queue_free()
	p.camera.current = true
	return im


func _vicino(lastra: MeshInstance3D) -> void:
	p.teleport(Vector3(0.0, PAVIMENTO + 0.1, 20.0))
	await _frames(10)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.visible = false
	for luce in [false, true]:
		var s := "_luce" if luce else ""
		for x in [-2.0, 0.0, 2.0]:
			var g := Vector3(x, PAVIMENTO, 25.505)
			await _libera(g + Vector3(0.0, 0.25, -0.6), g, "vicino_x%+.0f_da_sud%s" % [x, s], luce)
			await _libera(g + Vector3(0.0, 0.25, 0.6), g, "vicino_x%+.0f_da_nord%s" % [x, s], luce)
			await _libera(g + Vector3(0.35 * signf(x + 0.01), 0.06, 0.0), g - Vector3(0.35 * signf(x + 0.01), 0.0, 0.0), "radente_x%+.0f_lungo%s" % [x, s], luce)
			await _libera(g + Vector3(0.0, 0.5, 0.01), g, "x%+.0f_dall_alto%s" % [x, s], luce)
	# lo sfarfallio: radente da lontano, la camera che si sposta di 1 cm, la striscia della giunzione sullo schermo
	for d in [2.0, 5.0, 9.0]:
		for lato in [-1.0, 1.0]:
			var ims := []
			for k in 8:
				var da := Vector3(0.3 + 0.01 * k, PAVIMENTO + 1.6, 25.505 + lato * d)
				var im := await _libera(da, Vector3(0.0, PAVIMENTO, 25.505), "sfarfallio_%s_%.0fm_%d" % ["sud" if lato < 0.0 else "nord", d, k])
				ims.append(im)
			# la striscia: dove la giunzione cade sullo schermo, ±4 righe
			var cam := Camera3D.new()
			add_child(cam)
			cam.fov = 55.0
			cam.global_position = Vector3(0.3, PAVIMENTO + 1.6, 25.505 + lato * d)
			cam.look_at(Vector3(0.0, PAVIMENTO, 25.505), Vector3.UP)
			var sz := get_viewport().get_visible_rect().size
			var py := cam.unproject_position(Vector3(0.0, PAVIMENTO, 25.505)).y * float((ims[0] as Image).get_height()) / sz.y
			cam.queue_free()
			var diffs := []
			for k in 7:
				var a := ims[k] as Image
				var b := ims[k + 1] as Image
				var tot := 0.0
				var n := 0
				for y in range(maxi(int(py) - 4, 0), mini(int(py) + 5, a.get_height())):
					for x in range(a.get_width() / 4, a.get_width() * 3 / 4, 2):
						tot += absf(a.get_pixel(x, y).get_luminance() - b.get_pixel(x, y).get_luminance())
						n += 1
				diffs.append(snappedf(tot / maxi(n, 1) * 255.0, 0.01))
			print("VICINO: sfarfallio da %.0f m (%s), riga %d: cambio medio della striscia fra scatti successivi %s (su 255)" % [d, "sud" if lato < 0.0 else "nord", int(py), diffs])
