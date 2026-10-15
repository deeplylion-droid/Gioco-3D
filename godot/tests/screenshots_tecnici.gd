extends Node
## Screenshot degli ambienti tecnici (scenes/tecnici/tecnici.tscn); serve un vero renderer.
## Uso:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/screenshots_tecnici.gd <cartella> \
##        [inquadrature separate da virgole] [preset] [frame di attesa]

const LEVEL := "res://scenes/tecnici/tecnici.tscn"

var out_dir := "user://screenshots_tecnici"
var only := PackedStringArray()
var preset := "alto"
var settle := 60
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
	Grafica.applica_preset(preset)
	get_tree().change_scene_to_file(LEVEL)
	await _frames(10)
	get_tree().paused = false
	level = get_tree().current_scene
	p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	if _want("tecnici_camera"):
		# In fondo alla scala del pozzo, lungo la camera delle onde: pale, bocchette, paratie alzate.
		await _shot("tecnici_camera", Vector3(1.4, 0.0, 0.9), Vector3(20.0, 1.9, -0.4))
	if _want("tecnici_pompe"):
		# Le tre pompe con le turbine d'avviamento, la vasca di raccolta davanti.
		await _shot("tecnici_pompe", Vector3(40.5, 0.0, 3.2), Vector3(34.0, 1.0, -4.2))
	if _want("tecnici_leva"):
		# La leva grande dietro la grata e lo schema a colori sul muro est.
		await _shot("tecnici_leva", Vector3(41.8, 0.0, 0.2), Vector3(46.0, 2.9, -3.6))
	if _want("tecnici_scrivania"):
		# La scrivania col monitor a tubo.
		await _shot("tecnici_scrivania", Vector3(40.3, 0.0, 0.4), Vector3(41.8, 0.85, 3.3))
	if _want("tecnici_monitor") or _want("tecnici_monitor_vicino") or _want("tecnici_monitor_lato") or _want("tecnici_monitor_neve"):
		# Il monitor a tubo come nel gioco (MonitorCrt della sala principale): da 1,3 m e da vicino.
		if level.find_children("*", "MonitorCrt", true, false).is_empty():
			var mon := MonitorCrt.new()
			mon.name = "Monitor"
			mon.schermo_path = NodePath("../Ambienti/SalaPompe/SCHERMO_CRT")
			mon.luce_path = NodePath("../Ambienti/SalaPompe/LUCE_crt")
			mon.immagine = load("res://assets/tecnici/monitor_sala.jpg")
			# SCATTI_MONITOR_PIATTO=1: com'era nella v0.3.0, il rettangolo piatto del modello.
			mon.appoggia_sul_vetro = OS.get_environment("SCATTI_MONITOR_PIATTO") != "1"
			level.add_child(mon)
		if _want("tecnici_monitor"):
			await _shot("tecnici_monitor", Vector3(41.15, 0.0, 1.75), Vector3(41.57, 1.0, 2.96))
		if _want("tecnici_monitor_vicino"):
			await _shot("tecnici_monitor_vicino", Vector3(41.33, 0.0, 2.3), Vector3(41.57, 1.05, 2.96))
		if _want("tecnici_monitor_lato"):
			# Di sbieco, da vicino: lo schermo deve stare sul vetro, non staccato come un foglio.
			await _shot("tecnici_monitor_lato", Vector3(40.6, 0.0, 2.45), Vector3(41.57, 1.02, 2.96))
		if _want("tecnici_monitor_neve"):
			GameState.imposta_luci(GameState.Luci.BLACKOUT)
			await _shot("tecnici_monitor_neve", Vector3(41.15, 0.0, 1.75), Vector3(41.57, 1.0, 2.96))
			GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO)
	if _want("tecnici_vasca"):
		# La vasca di raccolta piena d'acqua nera.
		await _shot("tecnici_vasca", Vector3(39.6, 0.0, 3.1), Vector3(36.0, -0.2, 0.4))
	if _want("tecnici_raccordo"):
		# Il raccordo di servizio: dalla porta del ponte inferiore verso il vano scala.
		await _shot("tecnici_raccordo", Vector3(47.0, 0.0, 1.4), Vector3(52.0, 1.6, -0.6))
	if _want("tecnici_rampa"):
		# La seconda rampa, verso la scala degli interni.
		await _shot("tecnici_rampa", Vector3(51.7, 3.625, -7.8), Vector3(44.0, 8.3, -7.8))
	get_tree().quit()


func _shot(file: String, pos: Vector3, look: Vector3) -> void:
	p.teleport(pos, 0.0, 0.0)
	p.look_at_point(look)
	await _frames(settle)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(out_dir.path_join(file + ".jpg"), 0.92)
	print("salvato ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
