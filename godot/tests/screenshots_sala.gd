extends Node
## Screenshot della demo della sala principale (serve un vero renderer).
## Uso (con --fixed-fps il tempo di gioco avanza di 1/60 s per frame):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1920x1080 --script res://tests/run.gd -- res://tests/screenshots_sala.gd <cartella> \
##        [inquadrature separate da virgole] [preset] [frame di attesa]
## Il preset (predefinito "ultra") è quello dell'addon grafica; "ultra" usa la GI SDFGI.
## I frame di attesa servono all'antialiasing temporale, alla GI e alla nebbia per assestarsi.

const LEVEL := "res://scenes/sala_principale.tscn"

var out_dir := "user://screenshots_sala"
var only := PackedStringArray()
var preset := "ultra"
var settle := 50
var level: Node
var p: Player


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
	if preset == "ultra" or preset == "ultra_sdfgi":
		Grafica.applica_preset("ultra")
		Grafica.imposta("gi", 2)
		# Sul renderer software del sandbox l'Ultra pieno non sta in memoria: ombre "alte"
		# (atlante 4096 invece di 8192) e nebbia volumetrica normale. A 1080p non si vede la differenza.
		Grafica.imposta("ombre", 3)
		Grafica.imposta("nebbia", 1)
	else:
		Grafica.applica_preset(preset)
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm and only.size() > 0 and not (only.has("piscina") or only.has("torcia")):
		wm.set(&"quality", 1)  # l'acqua non si vede: niente riflesso planare
	get_tree().change_scene_to_file(LEVEL)
	await _frames(10)
	get_tree().paused = false
	level = get_tree().current_scene
	p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var storm: Tempesta = level.get_node("Tempesta")
	storm.automatica = false
	var lamp: FlickerLight = level.get_node("Statua/Sfarfallio")
	lamp.turn_on()
	if _want("ingresso_statua"):
		# Dall'uscita degli spogliatoi: la medusa intera sul piedistallo, la cupola dietro.
		await _shot("ingresso_statua", Vector3(0.0, 0.0, 11.2), Vector3(0.0, 3.2, 6.9))
	if _want("statua_lampo_ingresso"):
		await _shot("statua_lampo_ingresso", Vector3(0.0, 0.0, 11.2), Vector3(0.0, 3.2, 6.9), func(): storm.lampo_ora(1.4, 0.5, PI * 0.95), 4)
	if _want("statua_meta"):
		# A metà strada.
		await _shot("statua_meta", Vector3(-0.5, 0.0, 9.6), Vector3(0.0, 3.7, 6.9))
	if _want("statua_piedi"):
		# Ai suoi piedi, guardando in su: deve incombere.
		await _shot("statua_piedi", Vector3(-0.75, 0.0, 9.1), Vector3(0.0, 4.9, 6.9))
	if _want("statua_vicino"):
		await _shot("statua_vicino", Vector3(1.7, 0.0, 9.2), Vector3(0.0, 3.6, 6.9))
	if _want("statua_lampo"):
		await _shot("statua_lampo", Vector3(-2.2, 0.0, 9.6), Vector3(0.0, 3.4, 6.9), func(): storm.lampo_ora(1.3, 0.6, PI * 0.8), 5)
	if _want("piscina"):
		# Dal bordo della parte profonda verso la spiaggia e l'area bimbi, sotto la cupola.
		await _shot("piscina", Vector3(5.6, 0.0, 6.6), Vector3(-2.0, -1.0, -6.0))
	if _want("torcia"):
		# La torcia sul pavimento bagnato, verso la torre degli scivoli.
		await _shot("torcia", Vector3(9.0, 0.0, 9.0), Vector3(13.0, 0.8, -4.0))
	if _want("area_bimbi"):
		await _shot("area_bimbi", Vector3(-6.5, 0.0, -6.0), Vector3(-13.0, 2.5, -15.0))
	print("screenshot salvati in ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _shot(file: String, pos: Vector3, look: Vector3, before := Callable(), after_frames := -1) -> void:
	p.teleport(pos, 0.0, 0.0)
	p.look_at_point(look)
	await _frames(settle)
	if before.is_valid():
		before.call()
		await _frames(after_frames if after_frames >= 0 else 4)
	await _capture(file)


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(out_dir.path_join(file + ".jpg"), 0.92)
	print("salvato ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
