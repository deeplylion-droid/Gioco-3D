extends Node
## Breve video dell'enigma degli acquari risolto (forme provvisorie), dagli occhi del giocatore:
## dopo la tappa 8 aspira due volte il giallo e una il blu, versa ogni volta nell'acquario vuoto, che
## cambia colore e diventa verde, poi il portone si apre con le lampade accese.
## La sala intera su llvmpipe qui si blocca nel caricamento: il video si fa in una scena piccola fatta
## al volo, con l'enigma, il giocatore, pavimento e parete est provvisori e un portone provvisorio
## (PortoneTorre con un'anta a scatola) al posto di quello della sala.
## Salva un JPG per fotogramma in <cartella>; poi ffmpeg -framerate 25 -i <cartella>/f_%05d.jpg ne
## fa il video. Uso, sotto il render.lock:
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --fixed-fps 25 \
##        --resolution 960x540 --script res://tests/run.gd -- res://tests/video_acquari.gd <cartella>

var level: Node
var p: Player
var enigma: EnigmaAcquari
var _guarda := Vector3.ZERO
var _cartella := ""
var _n := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		_cartella = args[1]
		DirAccess.make_dir_recursive_absolute(_cartella)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _cartella == "" or p == null:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg("%s/f_%05d.jpg" % [_cartella, _n], 0.9)
	_n += 1
	if _n % 50 == 0:
		print("fotogramma ", _n)


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("medio")
	level = _scena()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _frames(10)
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	enigma = level.get_node(^"EnigmaAcquari") as EnigmaAcquari
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(0.0)
	# Al buio con la torcia accesa, come nel gioco.
	for t in p.find_children("*", "", true, false):
		if t.has_method(&"imposta_accesa"):
			t.call(&"imposta_accesa", true)
	var giallo := enigma.get_node(^"AcquarioGiallo") as WaterTank
	var blu := enigma.get_node(^"AcquarioBlu") as WaterTank
	var misto := enigma.get_node(^"AcquarioMisto") as WaterTank
	# Si parte guardando i tre acquari.
	p.teleport(Vector3(13.0, 0.0, -7.2), PI * 0.5, 0.0)
	_guarda = Vector3(17.0, 0.6, -7.2)
	p.look_at_point(_guarda)
	await _secondi(1.5)
	for t in [giallo, giallo, blu]:
		var c: Vector3 = (t as WaterTank).global_position
		await _vai(Vector3(c.x - 1.6, 0.0, c.z), c + Vector3(0.0, t.get_level() * 0.5, 0.0), 1.0)
		Input.action_press(&"suck")
		for i in 240:
			await get_tree().physics_frame
			if p.water_pack.tank_amount >= p.water_pack.tank_capacity - 0.01:
				break
		Input.action_release(&"suck")
		await _secondi(0.3)
		var m := misto.global_position
		var b := m + Vector3(0.3, 0.45, 0.0)
		var d := (Vector3(m.x - 2.0, 1.6, m.z)).distance_to(b)
		await _vai(Vector3(m.x - 2.0, 0.0, m.z), b + Vector3.UP * 0.0067 * d * d, 1.0)
		Input.action_press(&"spray")
		for i in 900:
			await get_tree().physics_frame
			if p.water_pack.tank_amount <= 0.001:
				break
		await _secondi(0.6)
		Input.action_release(&"spray")
		await _secondi(0.4)
	print("stato dell'enigma: ", enigma.stato, " (", Engine.get_frames_drawn(), " fotogrammi)")
	await _secondi(1.0)
	# Il portone che si apre, con le lampade accese.
	await _vai(Vector3(12.5, 0.0, -11.5), Vector3(19.8, 2.4, -15.0), 1.5)
	await _secondi(7.5)
	get_tree().quit()


## Va in [param piedi] guardando [param punto] in [param secondi], senza scatti.
func _vai(piedi: Vector3, punto: Vector3, secondi: float) -> void:
	var da := p.global_position
	var g0 := _guarda
	var n := maxi(int(secondi * 60.0), 1)
	for i in n:
		var k := smoothstep(0.0, 1.0, float(i + 1) / n)
		p.teleport(da.lerp(piedi, k), p.yaw, p.pitch)
		_guarda = g0.lerp(punto, k)
		p.look_at_point(_guarda)
		await get_tree().physics_frame


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		p.look_at_point(_guarda)
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## La scena piccola: pavimento, parete est, luce e ambiente scuri, il giocatore, l'enigma e il portone.
func _scena() -> Node3D:
	var radice := Node3D.new()
	radice.name = "VideoAcquari"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.025, 0.035)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.4, 0.5)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	radice.add_child(env)
	var luce := DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	luce.light_energy = 0.5
	luce.shadow_enabled = true
	radice.add_child(luce)
	var mondo := StaticBody3D.new()
	mondo.name = "Mondo"
	radice.add_child(mondo)
	Graybox.box(mondo, Vector3(16.0, 0.2, 20.0), Vector3(13.0, -0.1, -9.0), Graybox.FLOOR)
	Graybox.box_shape(mondo, Vector3(16.0, 0.2, 20.0), Vector3(13.0, -0.1, -9.0))
	# Parete est, con il vano del portone (z da -16 a -14, alto 3,5 m).
	for parte in [[Vector3(0.4, 7.0, 13.0), Vector3(20.04, 3.5, -22.5)], [Vector3(0.4, 7.0, 13.0), Vector3(20.04, 3.5, -7.5)],
			[Vector3(0.4, 3.5, 2.0), Vector3(20.04, 5.25, -15.0)]]:
		Graybox.box(mondo, parte[0], parte[1], Graybox.WALL)
		Graybox.box_shape(mondo, parte[0], parte[1])
	var anta := Node3D.new()
	anta.name = "Anta"
	radice.add_child(anta)
	anta.position = Vector3(19.84, 0.0, -15.0)
	var corpo := StaticBody3D.new()
	anta.add_child(corpo)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.35, 0.12)
	Graybox.box(corpo, Vector3(0.15, 3.5, 2.0), Vector3(0.0, 1.75, 0.0), mat)
	var portone := PortoneTorre.new()
	portone.name = "PortoneTorre"
	portone.apertura = PortoneTorre.Apertura.SOLO_ENIGMA
	portone.anta = anta
	radice.add_child(portone)
	portone.position = Vector3(19.84, 0.0, -15.0)
	var e := (load("res://scenes/sala/enigma_acquari.tscn") as PackedScene).instantiate()
	e.set(&"portone", portone)
	radice.add_child(e)
	var giocatore := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	radice.add_child(giocatore)
	giocatore.position = Vector3(13.0, 0.0, -7.2)
	return radice
