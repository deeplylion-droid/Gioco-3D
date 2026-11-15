extends Node
## Collaudo della roccia delle sponde del fiume dagli occhi del giocatore seduto sulla ciambella (1,65 m sopra il punto
## del tratto), col renderer vero e l'ambiente della sala: lungo i tratti giusti (Imbarco, Giusto1, Giusto2, Uscita)
## ogni metro avanti, a sinistra e a destra; nel Giusto2 fra 12 e 26 m ogni 0,5 m a sinistra e a destra, anche di
## sbieco e in alto. Ogni vista anche con lo sfondo magenta (<nome>_m.png): il magenta è vuoto fuori dal livello.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 640x360 --fixed-fps 60 \
##        --script res://tests/run.gd -- res://tests/collaudo/sonda_roccia_giro.gd <cartella>

const OCCHI := 1.65
var cart := ""
var cam: Camera3D
var env_gioco: Environment
var env_magenta: Environment
var n := 0


func _ready() -> void:
	_run.call_deferred()


func _passa(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _run() -> void:
	cart = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	var we := WorldEnvironment.new()
	we.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(we)
	env_gioco = we.environment
	env_magenta = env_gioco.duplicate()
	env_magenta.background_mode = Environment.BG_COLOR
	env_magenta.background_color = Color(1, 0, 1)
	env_magenta.fog_enabled = false
	env_magenta.volumetric_fog_enabled = false
	env_magenta.sky = null
	env_magenta.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_magenta.ambient_light_color = Color(0.3, 0.3, 0.3)
	env_magenta.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	for i in 3000:
		await get_tree().process_frame
		if f.get(&"costruita"):
			break
	cam = Camera3D.new()
	cam.near = 0.05
	cam.fov = 75.0
	add_child(cam)
	cam.current = true
	var tratti := {}
	for t in f.find_children("*", "TrattoFiume", true, false):
		tratti[String(t.name)] = t
	print("ROCCIA: tratti ", tratti.keys())
	for nome in ["Imbarco", "Giusto1", "Giusto2", "Uscita"]:
		if not tratti.has(nome):
			continue
		var tr = tratti[nome]
		var L: float = tr.lunghezza()
		var s := 0.0
		while s <= L:
			var fitto: bool = nome == "Giusto2" and s >= 12.0 and s <= 26.0
			var viste := [["avanti", 0.0, -8.0], ["sx", 90.0, -5.0], ["dx", -90.0, -5.0]]
			if fitto:
				viste.append_array([["sx_avanti", 45.0, -5.0], ["dx_avanti", -45.0, -5.0], ["sx_indietro", 135.0, -5.0],
						["dx_indietro", -135.0, -5.0], ["sx_alto", 90.0, 35.0], ["dx_alto", -90.0, 35.0]])
			for v in viste:
				await _scatto(tr, s, nome, v[0], v[1], v[2])
			s += 0.5 if fitto else 1.0
	print("ROCCIA: finito, %d viste" % n)
	get_tree().quit()


func _scatto(tr, s: float, nome: String, verso: String, gira: float, pitch: float) -> void:
	var p: Vector3 = tr.punto(s)
	var d: Vector3 = tr.direzione(s)
	d.y = 0.0
	d = d.normalized()
	var yaw := atan2(-d.x, -d.z) + deg_to_rad(gira)
	cam.global_position = p + Vector3.UP * OCCHI
	cam.rotation = Vector3(deg_to_rad(pitch), yaw, 0.0)
	var base := "%s_s%04.1f_%s" % [nome, s, verso]
	cam.environment = null
	await _passa(2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(base + ".jpg"), 0.85)
	cam.environment = env_magenta
	await _passa(2)
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	im.resize(320, 180, Image.INTERPOLATE_NEAREST)
	im.save_png(cart.path_join(base + "_m.png"))
	n += 1
