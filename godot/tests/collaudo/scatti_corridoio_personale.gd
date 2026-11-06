extends Node
## Il cartello delle pozze nel corridoio del personale (scelta B dell'utente del 4 novembre): gli scatti prima e dopo, per
## vedere che il faretto non cambia la luce del corridoio oltre al cartello. La Risalita da sola, come scatti_d7.gd: ambiente
## della sala, luci del blackout (dopo la sala pompe), lei dietro l'oblò. Con "prima" il cartello e il suo faretto si
## tolgono (com'era il corridoio prima della 0.3.21). Gli scatti dell'infermeria mostrano il muro dove stava.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_corridoio_personale.gd <cartella> [prima|dopo]

var cartella := "user://corridoio_personale"
var fase := "dopo"
const Y := -5.4
## [nome, da, verso] nel mondo. Il corridoio: x da -36 a -34, z da 48,1 (porta dell'infermeria) a 50,7 (capannone).
const VISTE := [
	["1_entrando_dal_capannone", Vector3(-35.0, Y + 1.6, 51.6), Vector3(-35.0, Y + 1.25, 48.1)],
	["2_entrando_guarda_a_destra", Vector3(-35.1, Y + 1.6, 51.1), Vector3(-34.0, Y + 1.45, 50.1)],
	["3_dalla_porta_infermeria_indietro", Vector3(-35.0, Y + 1.6, 48.5), Vector3(-34.6, Y + 1.3, 50.7)],
	["4_cartello_da_vicino", Vector3(-35.0, Y + 1.55, 50.35), Vector3(-34.0, Y + 1.5, 50.35)],
	["5_faretto_e_soffitto", Vector3(-35.8, Y + 1.5, 49.3), Vector3(-34.8, Y + 2.5, 50.4)],
	["6_oblo_di_lei", Vector3(-34.4, Y + 1.6, 50.2), Vector3(-36.0, Y + 1.5, 49.6)],
	["7_pavimento_e_polaroid", Vector3(-35.2, Y + 1.6, 49.3), Vector3(-34.2, Y + 0.05, 50.2)],
]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	if a.size() > 2:
		fase = a[2]
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
	var cp := ris.get_node_or_null(^"CartelloPozzeColorate") as Node3D
	if fase == "prima" and cp:
		cp.queue_free()
	for i in 3600:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 200 and ris.get(&"infermeria") != null:
			break
	var o := ris.find_child("ObloPersonale", true, false) as ObloLei
	if o:
		o.set_process(false)
		o._mostra()
	await _f(90)
	var viste := VISTE.duplicate()
	var inf := ris.get(&"infermeria") as Node3D
	if inf:
		# il muro nord dell'infermeria, a ovest della porta nord, dove stava il cartello
		viste.append(["8_infermeria_muro_della_porta_nord", inf.to_global(Vector3(-1.2, 1.6, -0.6)), inf.to_global(Vector3(-2.7, 1.45, -3.2))])
	for v in viste:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		await _f(20)
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		im.save_jpg(cartella.path_join("%s_%s.jpg" % [fase, v[0]]), 0.9)
		var tot := 0.0
		for y in range(0, im.get_height(), 4):
			for x in range(0, im.get_width(), 4):
				tot += im.get_pixel(x, y).get_luminance()
		print("SCATTO %s %s: luminosità media %.4f" % [fase, v[0], tot / float((im.get_height() / 4) * (im.get_width() / 4))])
	print("CORRIDOIO FINITO")
	get_tree().quit()


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame
