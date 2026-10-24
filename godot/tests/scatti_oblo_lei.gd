extends Node
## Scatti degli oblò con lei dietro il vetro (ObloLei) nei tre corridoi della Risalita: dagli occhi del giocatore
## mentre arriva e davanti al vetro, più i ravvicinati dell'oblò (di fronte e di traverso, per vedere che è a filo del
## muro). La Risalita da sola (risalita.tscn), con l'ambiente della sala e le luci del blackout, senza torcia. Per il
## collaudo e per i controlli della squadra; quelli per l'utente si scelgono da qui.
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_oblo_lei.gd <cartella> [con_lei|senza_lei|staccata]
## con_lei: lei dietro ogni vetro (ferma, come quando compare); staccata: 1,5 s dopo che si è staccata; senza_lei: vuoti.

var cartella := "user://scatti_oblo"
var modo := "con_lei"

## nome -> [nodo dell'oblò, occhi del giocatore (nel mondo), punto guardato, campo]; "@" nel punto guardato vuol dire
## il centro dell'oblò.
var SCATTI := {
	"1_fiume_a_dalla_scala": ["ObloFiume", Vector3(-3.0, -3.8, 49.3), "@", 75.0],
	"1_fiume_b_a_meta": ["ObloFiume", Vector3(-5.2, -3.8, 52.6), "@", 75.0],
	"1_fiume_c_davanti": ["ObloFiume", Vector3(-5.6, -3.8, 57.2), "@", 75.0],
	"2_personale_a_dalla_porta": ["ObloPersonale", Vector3(-34.6, -3.8, 50.4), "@", 75.0],
	"2_personale_b_davanti": ["ObloPersonale", Vector3(-34.3, -3.8, 49.4), "@", 75.0],
	"3_servizio_a_dalle_rampe": ["ObloServizio", Vector3(-27.4, 1.6, 38.7), "@", 75.0],
	"3_servizio_b_a_meta": ["ObloServizio", Vector3(-24.5, 1.6, 38.9), "@", 75.0],
	"3_servizio_c_davanti": ["ObloServizio", Vector3(-21.3, 1.6, 39.1), "@", 75.0],
}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	if a.size() > 2:
		modo = a[2]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"risalita_subito", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var ris := (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate() as Node3D
	add_child(ris)
	var cam := Camera3D.new()
	cam.near = 0.03
	add_child(cam)
	cam.current = true
	for i in 30:
		await get_tree().process_frame
	var obli := {}
	for o in ris.find_children("*", "ObloLei", true, false):
		obli[String(o.name)] = o
		(o as ObloLei).set_process(false)
		if modo != "senza_lei":
			(o as ObloLei)._mostra()
	if modo == "staccata":
		for o in obli.values():
			(o as ObloLei)._stacca()
		for i in 90:
			await get_tree().process_frame
	# i ravvicinati di ogni oblò: di fronte da 1,4 m, di traverso lungo il muro
	var scatti := SCATTI.duplicate()
	for nome in obli:
		var o := obli[nome] as ObloLei
		var c := o.global_position
		var n := o.normale()
		var lungo := o.global_basis.x
		scatti["r_%s_fronte" % nome] = [nome, c + n * 1.4 + Vector3.UP * 0.1, c, 60.0]
		scatti["r_%s_traverso" % nome] = [nome, c + n * 0.25 + lungo * 1.3 + Vector3.UP * 0.05, c, 50.0]
	for nome in scatti:
		var s: Array = scatti[nome]
		var o := obli.get(s[0]) as ObloLei
		var verso: Vector3 = o.global_position if s[2] is String else s[2]
		cam.fov = s[3]
		cam.look_at_from_position(s[1], verso)
		for i in 30:
			await get_tree().process_frame
		var f := cartella.path_join(nome + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f)
	get_tree().quit()
