extends Node
## Collaudo degli oblò con lei: scatti da punti scelti a mano nella Risalita, al buio, con lei comparsa in tutti e tre
## gli oblò: per ogni punto uno scatto con la sua luce rosa e uno con la luce spenta (per vedere dove passa la luce e
## dove si vede dentro la vasca). Per ricontrollare un difetto trovato da luce_oblo.gd, dal punto e dai dintorni.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/punti_oblo.gd <cartella>

## [nome, occhio, guarda]
const PUNTI := [
	# D7: la fessura nel pavimento accanto al corridoio di ObloPersonale (luce_oblo.gd, verso la luce di lei)
	["d7_1_dal_punto", Vector3(-34.75, -4.7, 51.6), Vector3(-36.75, -6.7, 49.6)],
	["d7_2_dal_punto_giu", Vector3(-34.75, -4.7, 51.6), Vector3(-35.6, -6.3, 50.4)],
	["d7_3_di_lato", Vector3(-33.5, -4.7, 50.0), Vector3(-35.6, -6.3, 50.6)],
	["d7_4_dall_altra_parte", Vector3(-36.5, -4.7, 52.5), Vector3(-35.4, -6.3, 50.4)],
	["d7_5_radente_a", Vector3(-33.8, -6.05, 51.2), Vector3(-36.5, -6.3, 50.0)],
	["d7_6_radente_b", Vector3(-35.6, -6.05, 52.8), Vector3(-35.4, -6.3, 49.0)],
	["d7_7_radente_c", Vector3(-37.2, -6.05, 51.0), Vector3(-34.2, -6.3, 50.2)],
	# la riga rosa vicino a ObloServizio (luce_oblo.gd)
	["riga_1_dal_punto", Vector3(-17.5, 1.6, 37.7), Vector3(-21.5, -0.4, 36.7)],
	["riga_2_piu_vicino", Vector3(-18.5, 1.6, 37.7), Vector3(-21.5, -0.4, 36.7)],
	["riga_3_di_lato", Vector3(-17.5, 1.6, 38.7), Vector3(-21.5, 0.0, 36.2)],
]

var cartella := "user://punti_oblo"
var cam: Camera3D


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
	cam = Camera3D.new()
	cam.near = 0.03
	add_child(cam)
	cam.make_current()
	for i in 30:
		await get_tree().process_frame
	var luci: Array[OmniLight3D] = []
	for o in ris.find_children("*", "ObloLei", true, false):
		var ob := o as ObloLei
		ob.set_process(false)
		ob._mostra()
		for l in ob.find_children("*", "OmniLight3D", true, false):
			luci.append(l as OmniLight3D)
	for i in 60:
		await get_tree().process_frame
	for pt in PUNTI:
		cam.global_position = pt[1]
		cam.look_at(pt[2], Vector3.UP)
		for l in luci:
			l.visible = true
		await _scatto("%s_con" % pt[0])
		for l in luci:
			l.visible = false
		await _scatto("%s_senza" % pt[0])
	print("PUNTI: finito")
	get_tree().quit()


func _scatto(nome: String) -> void:
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.88)
	print("scatto -> ", nome)
