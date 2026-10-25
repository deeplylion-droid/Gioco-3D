extends Node
## D7 degli oblò: gli scatti dai punti del collaudo di grafica, con lei dietro i vetri di ObloPersonale e ObloServizio
## (al buio dopo la sala pompe): la soglia della porta fra il corridoio del personale e il capannone (dove si vedeva
## dentro la vasca) e la riga rosa vicino a ObloServizio. La Risalita da sola, come scatti_oblo_lei.gd.
## Uso: xvfb-run ... --script res://tests/run.gd -- res://tests/collaudo/scatti_d7.gd <cartella>

var cartella := "user://d7"
const VISTE := [
	["personale_fessura", Vector3(-34.75, -4.7, 51.6), Vector3(-35.1, -5.4, 50.85)],
	["personale_fessura_alta", Vector3(-34.6, -3.8, 52.2), Vector3(-35.0, -5.4, 50.85)],
	["servizio_verso_oblo", Vector3(-17.5, 1.6, 37.7), Vector3(-21.5, 1.5, 37.45)],
	["servizio_verso_angolo", Vector3(-17.5, 1.6, 37.7), Vector3(-16.3, 1.9, 37.45)],
	["servizio_verso_porta", Vector3(-17.5, 1.6, 37.7), Vector3(-16.15, 1.2, 38.45)],
]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"risalita_subito", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var ris := (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate() as Node3D
	add_child(ris)
	var cam := Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.make_current()
	await _f(20)
	for nome in ["ObloPersonale", "ObloServizio"]:
		var o := ris.find_child(nome, true, false) as ObloLei
		o.set_process(false)
		o._mostra()
	await _f(90)
	for v in VISTE:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		await _f(20)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join(v[0] + ".jpg"), 0.9)
		print("scatto -> ", v[0])
	print("D7 FINITO")
	get_tree().quit()


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame
