extends Node
## Screenshot dell'inizio del capitolo 1 (scenes/interni/interni.tscn); serve un vero renderer.
## Uso:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/screenshots_interni.gd <cartella> \
##        [inquadrature separate da virgole] [preset] [frame di attesa]

const LEVEL := "res://scenes/interni/interni.tscn"

var out_dir := "user://screenshots_interni"
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
	if _want("interni_corridoio"):
		# Dal punto del risveglio, verso ovest: cartellone a sinistra, luci rosse, acqua a terra.
		await _shot("interni_corridoio", Vector3(21.2, 0.0, -1.35), Vector3(9.0, 1.25, -1.05))
	if _want("interni_soffitto"):
		# Il soffitto del corridoio verso ovest: il pannello che pendeva (prova della v0.3.2, punto 2).
		await _shot("interni_soffitto", Vector3(17.0, 0.0, -1.3), Vector3(12.8, 2.5, -1.3))
	if _want("interni_spogliatoi"):
		await _shot("interni_spogliatoi", Vector3(6.8, 0.0, -3.25), Vector3(6.3, 1.15, -12.0))
	if _want("interni_lavapiedi"):
		await _shot("interni_lavapiedi", Vector3(9.7, 0.0, -11.4), Vector3(9.8, 1.2, -18.0))
	if _want("interni_vetro"):
		# Il pulsante del tornello dietro il vetro rotto del gabbiotto.
		await _shot("interni_vetro", Vector3(9.9, 0.0, -15.0), Vector3(13.1, 1.3, -16.0))
	if _want("interni_stanzino"):
		# Lo zaino-pompa sulla rastrelliera.
		await _shot("interni_stanzino", Vector3(11.5, 0.0, -8.55), Vector3(15.2, 1.0, -8.3))
	if _want("interni_docce"):
		var docce: Node = level
		docce.call(&"apri_docce", true)
		await _shot("interni_docce", Vector3(5.6, 0.0, -10.6), Vector3(5.6, 1.5, -14.6))
		docce.call(&"apri_docce", false)
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
