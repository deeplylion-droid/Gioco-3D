extends Node
## Collaudo riga del fiume (#130): le fessure magenta del fiume da solo (fra la capanna e la parete vicino all'imbarco,
## sotto la valvola verde dell'approdo) con tutta la risalita caricata (fiume, corridoi, infermeria) come nel gioco.
## Per ogni vista: lo scatto normale (luci del blackout, ambiente della sala) e quello con lo sfondo magenta senz'acqua.
## Uso (sotto il render.lock): xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720
##   --script res://tests/run.gd -- res://tests/collaudo/fessure_risalita_scatti.gd <cartella>

const GIRO := 70.0
var cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var cart: String = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.BLACKOUT
	Engine.set_meta(&"risalita_subito", true)
	Grafica.applica_preset("alto")
	var we := WorldEnvironment.new()
	var env_sala := load("res://addons/grafica/sala/ambiente_sala.tres") as Environment
	var env := env_sala.duplicate() as Environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 1)
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.06)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.ssr_enabled = false
	we.environment = env_sala
	we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(we)
	var ris: Node3D = (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate()
	add_child(ris)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	var f: Node3D = null
	for i in 20000:
		await get_tree().process_frame
		f = ris.get(&"fiume") as Node3D
		if f and bool(f.get(&"costruita")):
			break
	for i in 120:
		await get_tree().process_frame
	var viste := []
	for v in [["Sbagliato1", 25.0, 1.65, 0.0], ["Sbagliato1", 25.0, 1.65, GIRO], ["Sbagliato2", 25.0, 1.65, 0.0], ["Uscita", 1.0, 1.65, 0.0], ["Imbarco", 1.0, -1.0, 0.0]]:
		var t := f.find_child(v[0], true, false) as TrattoFiume
		var s: float = v[1]
		var d := t.direzione(s)
		d.y = 0.0
		d = d.normalized()
		if float(v[2]) < 0.0:
			var c := t.punto(s)
			var da := c + d.cross(Vector3.UP).normalized() * 3.6
			da.y = f.global_position.y + 1.6
			viste.append(["%s_%03d_banchina_dx" % [v[0], int(s)], da, Vector3(c.x, f.global_position.y - 0.4, c.z)])
		else:
			var p := t.punto(s) + Vector3.UP * float(v[2])
			var dir := d.rotated(Vector3.UP, deg_to_rad(v[3]))
			viste.append(["%s_%03d_piedi_%s" % [v[0], int(s), "sinistra" if float(v[3]) > 0.0 else "avanti"], p, p + dir * 10.0 + Vector3.DOWN * 0.9])
	var acque: Array = []
	for mi in ris.find_children("*", "GeometryInstance3D", true, false):
		if String(mi.name).to_lower().contains("acqua"):
			acque.append(mi)
	for magenta in [false, true]:
		we.environment = env if magenta else env_sala
		we.camera_attributes = null if magenta else load("res://addons/grafica/sala/attributi_camera_sala.tres")
		for a in acque:
			(a as GeometryInstance3D).visible = not magenta
		for v in viste:
			cam.global_position = v[1]
			cam.look_at(v[2], Vector3.UP)
			for i in 10:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var conta := 0
			if magenta:
				for y in range(0, img.get_height(), 2):
					for x in range(0, img.get_width(), 2):
						var c := img.get_pixel(x, y)
						if c.r > 0.7 and c.b > 0.7 and c.g < 0.25:
							conta += 1
			img.save_jpg(cart.path_join("%s_%s.jpg" % [v[0], "magenta" if magenta else "normale"]), 0.88)
			print("SCATTO %s %s magenta %d" % [v[0], "magenta" if magenta else "normale", conta])
	print("SCATTI FINITO")
	get_tree().quit()
