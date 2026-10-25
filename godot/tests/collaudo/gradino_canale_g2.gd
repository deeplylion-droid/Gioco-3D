extends Node
## Collaudo (grafica-2): il gradino a due scalini lungo il canale del tunnel, dagli occhi del giocatore, in 12 punti
## dalla presa all'approdo (ostacoli, gallerie, crollo, abisso). Per ogni punto: dalla banchina guardando giù il
## gradino avanti, e dall'acqua guardando il gradino di fronte; con una lampadina neutra sulla camera (al buio non si
## vede niente). Uso (sotto il lock): xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720
##   --script res://tests/run.gd -- res://tests/collaudo/gradino_canale_g2.gd <cartella>

const PUNTI := [4.0, 30.0, 72.0, 78.0, 138.5, 205.0, 211.0, 262.0, 340.0, 410.0, 476.0, 546.0]
var cartella := ""


func _ready() -> void:
	cartella = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.volumetric_fog_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	var sala := SalaSottomarino.new()
	add_child(sala)
	sala.costruisci()
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.03
	add_child(cam)
	cam.current = true
	var luce := OmniLight3D.new()
	luce.light_energy = 1.5
	luce.omni_range = 8.0
	add_child(luce)
	for i in 30:
		await get_tree().process_frame
	for s: float in PUNTI:
		for lato: float in [-1.0, 1.0]:
			var bordo := sala.canale + 0.3
			if sala._lato(s, lato)["crollo"]:
				bordo = sala.canale - 0.1
			var da := _p(sala, s - 1.5, lato * bordo, sala.piano + 1.6)
			var a := _p(sala, s + 2.5, lato * (sala.canale - 0.25), sala.fondo + 0.4)
			await _scatto(cam, luce, da, a, "s%03d_%s_banchina" % [int(s), "sx" if lato < 0.0 else "dx"])
		var da2 := _p(sala, s - 1.0, 0.0, sala.fondo + 1.5)
		var a2 := _p(sala, s + 1.0, sala.canale - 0.25, sala.fondo + 0.45)
		await _scatto(cam, luce, da2, a2, "s%03d_dall_acqua" % int(s))
	get_tree().quit()


func _p(sala: SalaSottomarino, s: float, di_lato: float, y: float) -> Vector3:
	var q := sala.punto(s) + sala.destra(s) * di_lato
	return Vector3(q.x, y, q.z)


func _scatto(cam: Camera3D, luce: OmniLight3D, da: Vector3, a: Vector3, nome: String) -> void:
	cam.look_at_from_position(da, a)
	luce.global_position = da + Vector3.UP * 0.2
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.85)
	print("scatto ", nome)
