extends Node
## Collaudo dell'ingresso del tunnel (porta del bacino, fra la sala delle condotte e il tunnel): dagli occhi del
## giocatore, nella scena di prova col renderer vero, da 12 punti (bacino, scaletta, passerella, soglia, passaggio,
## testa del tunnel) 24 viste ciascuno (8 direzioni, in alto, dritto e in basso), prima di SB1 e dopo. Ogni vista due
## volte: con la grafica del gioco (<nome>.jpg) e con lo sfondo magenta e senza nebbia (<nome>_m.png): ogni pixel
## magenta è vuoto fuori dal livello (lo conta tools/conta_magenta.py).
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 640x360 --fixed-fps 60 \
##        --script res://tests/run.gd -- res://tests/collaudo/sonda_buco.gd <cartella> [solo_maschera|tutto] [prima,dopo]

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"
var cart := ""
var cam: Camera3D
var env_magenta: Environment
var solo_maschera := false


func _ready() -> void:
	_run.call_deferred()


func _passa(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	solo_maschera = a.size() > 2 and a[2] == "solo_maschera"
	var stati := a[3] if a.size() > 3 else "prima,dopo"
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _passa(10)
	var level := get_tree().current_scene
	var p := GameState.player
	var ins := level.get_node("SalaInseguimento") as SalaInseguimento
	var sott := level.get_node("SalaSottomarino") as SalaSottomarino
	sott.costruisci()
	ins.sb1_finito.connect(sott.attiva_tunnel)
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	# il giocatore fuori dalle viste (la camera è una sua)
	p.visible = false
	cam = Camera3D.new()
	cam.near = 0.05
	cam.fov = 75.0
	level.add_child(cam)
	cam.current = true
	var we := level.get_node("Ambiente") as WorldEnvironment
	env_magenta = we.environment.duplicate()
	env_magenta.background_mode = Environment.BG_COLOR
	env_magenta.background_color = Color(1, 0, 1)
	env_magenta.fog_enabled = false
	env_magenta.volumetric_fog_enabled = false
	env_magenta.sky = null
	env_magenta.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_magenta.ambient_light_color = Color(0.3, 0.3, 0.3)
	env_magenta.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	if stati.contains("prima"):
		await _giro(sott, "prima")
	if stati.contains("dopo"):
		ins.sb1_finito.emit()
		await _passa(120)
		await _giro(sott, "dopo")
	print("BUCO: finito")
	get_tree().quit()


func _punti(sott: SalaSottomarino) -> Dictionary:
	var out := {
		"bacino_1": Vector3(43.8, -31.5, -3.2),
		"bacino_2": Vector3(45.0, -31.5, -5.0),
		"scaletta_meta": Vector3(43.0, -30.4, -3.2),
		"scaletta_cima": Vector3(42.7, -28.4, -3.4),
		"passerella": Vector3(42.0, -28.4, -4.4),
		"uscita": Vector3(41.6, -28.4, -5.0),
		"soglia": Vector3(40.9, -28.4, -5.0),
		"passaggio": Vector3(40.2, -28.4, -5.0),
	}
	var h := sott.piano - sott.acqua + 1.6
	for s in [-3.0, 0.0, 2.0]:
		for lato in [-1.0, 1.0]:
			if s == 2.0 and lato > 0.0:
				continue
			out["testa_s%+.0f_%s" % [s, "sx" if lato < 0 else "dx"]] = sott.punto(s) + sott.destra(s) * lato * (sott.canale + 1.3) + Vector3.UP * h
	return out


func _giro(sott: SalaSottomarino, stato: String) -> void:
	var punti := _punti(sott)
	var n := 0
	for nome in punti:
		var q: Vector3 = punti[nome]
		for k in 8:
			var yaw := TAU * k / 8.0
			for pitch in [-50.0, 0.0, 50.0]:
				cam.global_position = q
				cam.rotation = Vector3(deg_to_rad(pitch), yaw, 0.0)
				var base := "%s_%s_y%03d_p%+03d" % [stato, nome, int(rad_to_deg(yaw)), int(pitch)]
				if not solo_maschera:
					cam.environment = null
					await _passa(3)
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_jpg(cart.path_join(base + ".jpg"), 0.85)
				cam.environment = env_magenta
				await _passa(3)
				await RenderingServer.frame_post_draw
				var im := get_viewport().get_texture().get_image()
				im.resize(320, 180, Image.INTERPOLATE_NEAREST)
				im.save_png(cart.path_join(base + "_m.png"))
				n += 1
	print("BUCO: %s, %d viste" % [stato, n])
