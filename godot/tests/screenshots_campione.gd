extends Node
## Screenshot del pezzo campione di luce e immagine (corridoio del risveglio, tornello con la
## vasca lava-piedi, stanzino, corridoio buio con la torcia). Stessi punti per il prima e il dopo.
## Uso:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/screenshots_campione.gd <cartella> \
##        [prefisso] [inquadrature separate da virgole] [preset] [frame di attesa]

const LEVEL := "res://scenes/interni/interni.tscn"

var out_dir := "user://screenshots_campione"
var prefisso := ""
var only := PackedStringArray()
var preset := "alto"
var settle := 60
var level: Node
var p: Player


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2:
		prefisso = args[2]
	if args.size() > 3 and args[3] != "" and args[3] != "tutte":
		only = args[3].split(",")
	if args.size() > 4:
		preset = args[4]
	if args.size() > 5:
		settle = int(args[5])
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
	var torcia := p.find_child("Torcia", true, false)
	if torcia:
		torcia.set(&"accesa", true)
	if _want("corridoio"):
		# Dal punto del risveglio, verso ovest.
		await _shot("corridoio", Vector3(21.2, 0.0, -1.35), Vector3(9.0, 1.25, -1.05))
	if _want("tornello"):
		# Il tornello con la vasca lava-piedi davanti.
		await _shot("tornello", Vector3(9.7, 0.0, -11.4), Vector3(9.8, 1.2, -18.0))
	if _want("stanzino"):
		await _shot("stanzino", Vector3(11.5, 0.0, -8.55), Vector3(15.2, 1.0, -8.3))
	if _want("torcia"):
		# Corridoio al buio: si spengono le luci del corridoio, resta solo la torcia.
		for l in level.get_node(^"Ambienti/Corridoio").find_children("*", "Light3D", true, false):
			(l as Light3D).visible = false
			(l as Light3D).set_process(false)
		for n in level.get_node(^"Ambienti/Corridoio").find_children("*", "Node3D", true, false):
			if n.get_script() and String(n.get_script().get_global_name()) in ["Neon", "LuceEmergenza"]:
				n.set_process(false)
				for l in n.find_children("*", "Light3D", true, false):
					(l as Light3D).visible = false
		await _shot("torcia", Vector3(19.0, 0.0, -1.35), Vector3(12.0, 0.9, -1.2))
	get_tree().quit()


func _shot(file: String, pos: Vector3, look: Vector3) -> void:
	p.teleport(pos, 0.0, 0.0)
	p.look_at_point(look)
	await _frames(settle)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(out_dir.path_join(prefisso + file + ".jpg"), 0.92)
	print("salvato ", prefisso + file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
