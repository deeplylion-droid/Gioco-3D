extends Node
## Collaudo (squadra collaudo): il menu di prova nascosto del titolo, come lo usa il giocatore, col renderer vero.
## <id> = "menu": il titolo, F9 (evento vero della tastiera), il menu con le partenze, Esc che lo chiude, di nuovo F9.
## <id> = una partenza (inizio, risalita, fiume, torre, inseguimento, tunnel): il titolo, F9, il pulsante della
## partenza premuto, la schermata di caricamento, poi il livello: dove sta il giocatore, il checkpoint, e quattro scatti
## dagli occhi (avanti, destra, dietro, sinistra) con l'HUD.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 960x540 --fixed-fps 60 \
##        --script res://tests/run.gd -- res://tests/collaudo/sonda_f9.gd <cartella> <id>

var cart := ""
var id := ""


func _ready() -> void:
	_run.call_deferred()


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(id + "_" + nome + ".jpg"), 0.85)
	print("F9: scatto ", nome)


func _passa(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _tasto(k: Key) -> void:
	for premuto in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = premuto
		Input.parse_input_event(e)
		await _passa(2)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	id = a[2]
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(Game.SCENE_TITLE)
	await _passa(240)
	await _foto("0_titolo")
	await _tasto(KEY_F9)
	await _passa(30)
	var menu := get_tree().root.find_child("MenuProva", true, false)
	print("F9: menu aperto ", menu != null)
	await _foto("1_menu")
	if menu == null:
		get_tree().quit(1)
		return
	var voci: Array = []
	for b in menu.find_children("*", "Button", true, false):
		voci.append((b as Button).text)
	print("F9: voci ", voci)
	if id == "menu":
		await _tasto(KEY_ESCAPE)
		await _passa(30)
		var resta := is_instance_valid(menu) and menu.is_inside_tree()
		if resta and menu is CanvasItem:
			resta = (menu as CanvasItem).visible
		print("F9: dopo Esc il menu c'è ancora ", resta)
		await _foto("2_dopo_esc")
		await _tasto(KEY_F9)
		await _passa(30)
		await _foto("3_di_nuovo_f9")
		get_tree().quit()
		return
	var nome := ""
	for p in MenuProva.PARTENZE:
		if p["id"] == id:
			nome = p["nome"]
	var bottone: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(nome) or (b as Button).text.contains(nome):
			bottone = b
	print("F9: pulsante '", nome, "' ", bottone != null)
	if bottone == null:
		get_tree().quit(1)
		return
	bottone.grab_focus()
	await _passa(5)
	await _foto("2_scelta")
	bottone.pressed.emit()
	var t0 := Time.get_ticks_msec()
	var caricamento_visto := false
	while Time.get_ticks_msec() - t0 < 600000:
		await _passa(1)
		var sc := get_tree().current_scene
		if sc and String(sc.scene_file_path).contains("caricamento") and not caricamento_visto:
			caricamento_visto = true
			await _passa(20)
			await _foto("3_caricamento")
		var p := GameState.player
		if p and is_instance_valid(p) and p.input_enabled and sc and not String(sc.scene_file_path).contains("caricamento") and not String(sc.scene_file_path).contains("menu"):
			break
	var p := GameState.player
	var sc2 := get_tree().current_scene
	print("F9: livello ", sc2.scene_file_path if sc2 else "niente", " in ", (Time.get_ticks_msec() - t0) / 1000.0, " s; giocatore ", p.global_position if p and is_instance_valid(p) else "niente")
	if p == null or not is_instance_valid(p):
		get_tree().quit(1)
		return
	print("F9: checkpoint ", GameState.snapshot.get("checkpoint", "-") if GameState.get(&"snapshot") is Dictionary else "-", " acqua ", p.water_pack.tank_amount if p.water_pack else -1.0, " zaino ", p.has_item(&"zaino_pompa"))
	await _passa(180)
	await _foto("4_arrivo")
	var yaw0: float = p.yaw
	for k in 4:
		p.set_look(yaw0 + PI * 0.5 * k, 0.0)
		await _passa(20)
		await _foto("5_giro_%d" % k)
	print("F9: dopo 3 s giocatore ", p.global_position, " su un pavimento ", p.is_on_floor(), " morto ", GameState.is_dying)
	get_tree().quit()
