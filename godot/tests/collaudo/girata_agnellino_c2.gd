extends Node
## Collaudo della girata dell'agnellino della scala di C2 (lavoro/bambini-squalo-0317): come si volta per scappare,
## da confrontare con la 0.3.15 (503b5d45), che all'utente piaceva di più. Come scatti_agnellino_buco.gd "girata", ma
## usa solo quello che c'è anche nel Bambino della 0.3.15, così gira su tutte e due: dal giocatore vero in cima alla
## scala di C2 si guarda l'agnellino; da quando scappa si salva ogni fotogramma per 1,5 s e si scrive in girata.csv
## quanto è girato e quanto si è spostato.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 30 --script res://tests/run.gd -- res://tests/collaudo/girata_agnellino_c2.gd <cartella>

const SCENA := "res://tests/scene/tappa7_gioco_agnellino.tscn"
const PUNTO := Vector3(44.2, 9.05, 0.5)
const FOTOGRAMMI := 45

var cartella := ""


func _ready() -> void:
	cartella = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	get_tree().change_scene_to_file(SCENA)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	get_tree().paused = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for n in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if n is LuceEmergenza and int(n.get(&"modalita")) in [1, 2]:
			n.set(&"modalita", 0)
	var p: Player = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var tec := get_tree().current_scene.get_node("Tecnici") as Node3D
	var ag := tec.get_node("AgnellinoScala") as AgnellinoScala
	p.teleport(tec.to_global(PUNTO) + Vector3(0, 0.05, 0), 0.0, 0.0)
	for i in 30:
		await get_tree().physics_frame
	GameState.luci_cambiate.emit(GameState.luci)
	ag.compari()
	var csv := FileAccess.open(cartella.path_join("girata.csv"), FileAccess.WRITE)
	csv.store_line("fotogramma,t,girata_gradi,spostato_m,dist_giocatore")
	var da := -1
	var rot0 := 0.0
	var pos0 := Vector3.ZERO
	var girata := 0.0
	var rot_prima := 0.0
	for i in 900:
		var b := ag.bambino
		if b and is_instance_valid(b) and b.visible:
			p.look_at_point(b.punto_testa())
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if b == null or not is_instance_valid(b):
			continue
		if da < 0 and b.modalita == Bambino.Modalita.SCAPPA:
			da = i
			rot0 = b.rotation.y
			rot_prima = rot0
			pos0 = b.global_position
		if da >= 0:
			var k := i - da
			girata += absf(angle_difference(rot_prima, b.rotation.y))
			rot_prima = b.rotation.y
			csv.store_line("%d,%.3f,%.1f,%.3f,%.2f" % [k, k / 30.0, rad_to_deg(girata), (b.global_position - pos0).length(),
					b.global_position.distance_to(p.global_position)])
			get_viewport().get_texture().get_image().save_jpg(cartella.path_join("girata_%02d.jpg" % k), 0.9)
			if k >= FOTOGRAMMI - 1:
				break
	csv.close()
	print("FINE girata, scappa al fotogramma %d" % da)
	get_tree().quit()
