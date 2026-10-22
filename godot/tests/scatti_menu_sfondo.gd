extends Node
## Scatti delle prove dello sfondo del titolo (MenuSfondo, scenes/ui/menu_principale.tscn): il menu vero
## all'inizio della salita, con la statua intera, tra un lampo e l'altro e durante un lampo.
## Gli strati si scelgono con la variabile d'ambiente MENU_SFONDO (per esempio "A,B" o "B,C").
## Uso (sotto il render.lock):
##   MENU_SFONDO=A,B xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan \
##        --fixed-fps 60 --resolution 1280x720 --script res://tests/run.gd -- res://tests/scatti_menu_sfondo.gd \
##        <cartella> <nome> [lampo]

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var cartella := "user://scatti_menu_sfondo"
var nome := "sfondo"
var con_lampo := false


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	if a.size() > 2:
		nome = a[2]
	con_lampo = a.size() > 3 and a[3] == "lampo"
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	# come screenshots_menu.gd: Ultra con ombre alte e nebbia normale (l'Ultra pieno non sta in memoria)
	Grafica.applica_preset("ultra")
	Grafica.imposta("gi", 2)
	Grafica.imposta("ombre", 3)
	Grafica.imposta("nebbia", 1)
	get_tree().change_scene_to_file(TITOLO)
	await _frames(3)
	var menu := get_tree().current_scene
	var tempesta: Tempesta = menu.get_node("Tempesta")
	tempesta.automatica = false
	menu.set(&"_lampo_finale", true)
	# l'inizio della salita (la statua intera), lasciando assestare nebbia e antialiasing
	menu.set(&"_t", 0.0)
	if Dissolvenza.presente(get_tree()):
		Dissolvenza.di(get_tree()).queue_free()
	await _frames(90)
	menu.set(&"_t", 1.5)
	await _frames(1)
	if OS.has_environment("CAMERA_DEBUG"):
		# (per controllare l'acqua: dall'alto, verso il piedistallo)
		menu.set_process(false)
		(menu.get(&"camera") as Camera3D).look_at_from_position(Vector3(3.5, 2.2, 5.5), Vector3(0, 0.5, 0))
		await _frames(30)
	await _scatto(nome)
	if con_lampo:
		menu.set(&"_t", 1.5)
		tempesta.lampo_ora(1.3, 0.8, PI * 1.1)
		await _frames(3)
		await _scatto(nome + "_lampo")
	print("SCATTI FATTI in ", cartella)
	get_tree().quit()


func _scatto(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(cartella.path_join(n + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
