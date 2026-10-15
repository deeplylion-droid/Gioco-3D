extends Node
## Screenshot dello zaino-pompa nella sala vera: lo zaino sulla rastrelliera dei bagnini, la
## pistola in mano mentre spara l'acqua fuori dalla piscina a onde e mentre la aspira (tappa 5).
## Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1920x1080 --script res://tests/run.gd -- res://tests/screenshots_zaino.gd <cartella> \
##        [preset] [frame di attesa]

const LEVEL := "res://scenes/sala_principale.tscn"

var out_dir := "user://screenshots_zaino"
var preset := "ultra"
var settle := 40
## Solo un'inquadratura (rastrelliera, spruzzo, aspirazione) o tutte: sul renderer software
## conviene un processo per inquadratura (la memoria cresce a ogni nuova vista).
var only := ""


func _ready() -> void:
	# Interruttore per fermare in fretta una serie di screenshot già in coda: basta creare il
	# file user://salta_screenshot.
	if FileAccess.file_exists("user://salta_screenshot"):
		get_tree().quit()
		return
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2:
		preset = args[2]
	if args.size() > 3:
		settle = int(args[3])
	if args.size() > 4:
		only = args[4]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("ultra" if preset == "ultra" else ("alto" if preset in ["alto_senza_gi", "alto_smaa"] else preset))
	if preset == "alto_senza_gi":
		Grafica.imposta("gi", 0)
	if preset == "alto_smaa":
		# Come screenshots_sala.gd: SMAA al posto del TAA per la memoria del renderer software.
		Grafica.imposta("antialiasing", 2)
	if preset == "ultra":
		# Come screenshots_sala.gd: Ultra con SDFGI, qualche effetto un livello sotto per la
		# memoria del renderer software.
		Grafica.imposta("gi", 2)
		Grafica.imposta("ombre", 3)
		Grafica.imposta("nebbia", 1)
		Grafica.imposta("ssil", 2)
		Grafica.imposta("ssao", 3)
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 1)
	var level_path := OS.get_environment("SCATTI_LIVELLO")
	get_tree().change_scene_to_file(level_path if level_path != "" else LEVEL)
	await _frames(10)
	get_tree().paused = false
	var level := get_tree().current_scene
	var p: Player = GameState.player
	# Con gli interni si parte dal risveglio nel corridoio: si aspetta che finisca.
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	for we in level.find_children("*", "WorldEnvironment", true, false):
		if (we as WorldEnvironment).environment:
			(we as WorldEnvironment).environment.sdfgi_cascades = 3
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var storm: Tempesta = level.find_children("*", "Tempesta", true, false)[0]
	storm.automatica = false
	(level.get_node("Vasca/Sfarfallio") as FlickerLight).turn_on()
	# 1) Lo zaino sulla rastrelliera dei bagnini, all'ingresso.
	var pack_node: Node3D = level.get_node("PostazioneBagnini/Zaino")
	if only == "" or only == "rastrelliera":
		var station: Node3D = level.get_node("PostazioneBagnini")
		var view := station.global_position + station.global_basis.z * 1.6 + station.global_basis.x * 0.6
		p.teleport(Vector3(view.x, 0.0, view.z), 0.0, 0.0)
		p.look_at_point(pack_node.global_position + Vector3(0, 0.3, 0))
		await _frames(settle)
		await _capture("zaino_sulla_rastrelliera")
		if only != "":
			get_tree().quit()
			return
	var pick := level.get_node_or_null("PostazioneBagnini/Zaino/Prendi") as PackPickup
	if pick:
		pick.interact(p)
	else:
		# Senza la rastrelliera nella scena: lo zaino si dà direttamente.
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
		p.water_pack.set_equipped(true)
	await _frames(40 if only == "" else 2)
	# 2) La pistola in mano mentre spara fuori dalla piscina a onde, dal bordo est.
	if only == "aspirazione":
		await _suck_shot(p)
		return
	p.water_pack.set_tank_amount(18.0)
	p.teleport(Vector3(7.35, 0.0, 2.0), -PI * 0.5, 0.0)
	await _frames(10)
	p.look_at_point(Vector3(13.0, 0.8, 4.0))
	await _frames(maxi(settle - 20, 10))
	Input.action_press("spray")
	await _frames(50)
	await _capture("pistola_spruzza_fuori")
	Input.action_release("spray")
	if only == "spruzzo":
		get_tree().quit()
		return
	await _frames(10)
	await _suck_shot(p)


## 3) La pistola in mano mentre aspira l'acqua della piscina a onde, dal bordo est.
func _suck_shot(p: Player) -> void:
	p.water_pack.set_tank_amount(4.0)
	p.teleport(Vector3(7.35, 0.0, 2.0), -PI * 0.5, 0.0)
	await _frames(10)
	p.look_at_point(Vector3(5.6, -1.5, 2.4))
	await _frames(maxi(settle - 20, 10))
	Input.action_press("suck")
	await _frames(45)
	await _capture("pistola_aspira_piscina")
	Input.action_release("suck")
	print("screenshot salvati in ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(file + ".jpg"), 0.92)
	print("salvato ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
