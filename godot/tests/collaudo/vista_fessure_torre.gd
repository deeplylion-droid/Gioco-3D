extends Node
## Collaudo di lavoro/varchi-cielo: le aperture della torre trovate da cielo_fessure.gd, viste col renderer vero. La torre
## come in vista_bacino.gd (sala_torre.tscn con l'ambiente della sala, luci del blackout), una camera con gli attributi
## del giocatore negli occhi di ogni posto e girata verso l'apertura (fov 70), più uno scatto più largo (fov 100).
## Uso: xvfb-run ... --script res://tests/run.gd -- res://tests/collaudo/vista_fessure_torre.gd <cartella>

const PLAYER := "res://scenes/player/player.tscn"
const VISTE := [["portone_su", Vector3(21.4, 1.59, -15.0), Vector3(0.426, 0.337, 0.84)],
		["portone_giu", Vector3(21.4, 1.59, -15.0), Vector3(-0.52, -0.654, -0.549)],
		["NEm3_su", Vector3(37.47, -1.41, -18.97), Vector3(0.45, 0.887, -0.099)],
		["NOm12_su", Vector3(27.05, -10.41, -21.41), Vector3(0.128, 0.904, 0.408)],
		["NOm12_lato", Vector3(27.05, -10.41, -21.41), Vector3(0.686, 0.387, -0.616)]]


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var cart: String = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate()
	add_child(torre)
	await _frames(240)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(5)
	var cam := Camera3D.new()
	cam.attributes = p.camera.attributes
	cam.near = 0.05
	add_child(cam)
	p.global_position = Vector3(0, -50, 0)
	p.set_physics_process(false)
	cam.make_current()
	for v in VISTE:
		for fov in [70.0, 100.0]:
			cam.fov = fov
			cam.global_position = v[1]
			var d: Vector3 = v[2]
			cam.look_at(cam.global_position + d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
			await _frames(12)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(cart.path_join("%s_fov%.0f.jpg" % [v[0], fov]), 0.9)
	print("VISTA: finito")
	get_tree().quit()
