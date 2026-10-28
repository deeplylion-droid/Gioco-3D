extends Node
## Screenshot del titolo, della schermata dei comandi e del caricamento (serve un vero renderer).
## Uso (con --fixed-fps il tempo di gioco avanza di 1/60 s per frame):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/screenshots_menu.gd <cartella> \
##        [inquadrature separate da virgole] [preset] [frame di attesa]
## Inquadrature: titolo_inizio, titolo_meta, titolo_viso, titolo_lampo, comandi, opzioni, caricamento.
## Il caricamento si fotografa fermo al 42% e senza caricare davvero la sala (è pesante).

const TITOLO := "res://scenes/ui/menu_principale.tscn"
const CARICAMENTO := "res://scenes/ui/caricamento.tscn"

var out_dir := "user://screenshots_menu"
var only := PackedStringArray()
var preset := "ultra"
var settle := 60


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2 and args[2] != "" and args[2] != "tutte":
		only = args[2].split(",")
	if args.size() > 3:
		preset = args[3]
	if args.size() > 4:
		settle = int(args[4])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _want(shot: String) -> bool:
	return only.is_empty() or only.has(shot)


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	if preset == "ultra":
		# Come al primo avvio (Ultra con SDFGI), ma con ombre "alte" e nebbia normale: sul
		# renderer software del sandbox l'Ultra pieno non sta in memoria.
		Grafica.applica_preset("ultra")
		Grafica.imposta("gi", 2)
		Grafica.imposta("ombre", 3)
		Grafica.imposta("nebbia", 1)
	else:
		Grafica.applica_preset(preset)
	if _want("titolo_inizio") or _want("titolo_meta") or _want("titolo_viso") or _want("titolo_lampo") \
			or _want("comandi") or _want("opzioni"):
		get_tree().change_scene_to_file(TITOLO)
		await _frames(3)
		var menu := get_tree().current_scene
		var tempesta: Tempesta = menu.get_node("Tempesta")
		tempesta.automatica = false
		# Niente lampo a copione né sfarfallio del titolo durante le foto (salvo "titolo_lampo").
		menu.set(&"_lampo_finale", true)
		menu.set(&"_prossimo_sfarfallio", 1.0e9)
		var durata: float = menu.get(&"durata_salita")
		if _want("titolo_inizio"):
			await _al_tempo(menu, 4.0)
			await _shot("titolo_inizio")
		if _want("titolo_meta"):
			await _al_tempo(menu, durata * 0.5)
			await _shot("titolo_meta")
		if _want("titolo_viso"):
			await _al_tempo(menu, durata + 8.0)
			await _shot("titolo_viso")
		if _want("titolo_lampo"):
			await _al_tempo(menu, durata + 8.0)
			tempesta.lampo_ora(1.3, 0.6, PI * 0.8)
			await _frames(4)
			await _shot("titolo_lampo", 0)
		if _want("comandi"):
			await _al_tempo(menu, durata * 0.62)
			(menu.find_child("Comandi", true, false) as Button).pressed.emit()
			await _shot("comandi")
			(menu.call(&"sottomenu").get_node("Comandi") as SchermataComandi).chiudi()
			await _frames(3)
		if _want("opzioni"):
			(menu.find_child("Opzioni", true, false) as Button).pressed.emit()
			await _shot("opzioni")
			(menu.call(&"sottomenu").get_node("Menu") as MenuOpzioni).chiudi_menu()
			await _frames(3)
	if _want("caricamento"):
		# La schermata vera, ma su una scena leggera e ferma al 42%.
		var car: Control = load(CARICAMENTO).instantiate()
		car.set(&"scena", "res://scenes/ui/comandi.tscn")
		car.set(&"tempo_minimo", 9999.0)
		var vecchia := get_tree().current_scene
		get_tree().root.add_child(car)
		get_tree().current_scene = car
		if vecchia:
			vecchia.queue_free()
		if Dissolvenza.presente(get_tree()):
			Dissolvenza.di(get_tree()).queue_free()
		await _frames(2)
		car.set_process(false)
		car.set(&"avanzamento", 0.42)
		(car.find_child("Barra", true, false) as ProgressBar).value = 0.42
		(car.find_child("Percento", true, false) as Label).text = "42%"
		await _shot("caricamento", 10)
	print("SCREENSHOT FATTI in ", out_dir)
	get_tree().quit()


## Porta l'animazione del titolo al secondo [param t] e lascia assestare nebbia e antialiasing.
func _al_tempo(menu: Node, t: float) -> void:
	menu.set(&"_t", t - settle / 60.0)
	if Dissolvenza.presente(get_tree()):
		Dissolvenza.di(get_tree()).queue_free()
	await _frames(1)


func _shot(nome: String, attesa := -1) -> void:
	await _frames(settle if attesa < 0 else attesa)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(nome + ".png")
	img.save_png(path)
	print("  ", path, " ", img.get_size())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
