extends Node
## PROPOSTA: screenshot in prima persona delle lance nel corridoio degli interni, con la luce
## del gioco. Uso: ... --script res://tests/run.gd -- res://proposte/zaino/scatti_lance.gd <cartella> <lance separate da virgole: attuale,A,B,C>

const LEVEL := "res://scenes/interni/interni.tscn"
var cartella := "/tmp/claude-0/lance"
var lance := PackedStringArray(["attuale", "A", "B", "C"])


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		cartella = args[1]
	if args.size() > 2:
		lance = args[2].split(",")
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	get_tree().change_scene_to_file(LEVEL)
	for i in 10:
		await get_tree().process_frame
	get_tree().paused = false
	var p: Player = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var pack := p.water_pack
	pack.set_equipped(true, false)
	# Neon fissi per scatti confrontabili.
	for n in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if n.get_script() and String(n.get_script().get_global_name()) == "Neon":
			n.set(&"modalita", 0)
	p.teleport(Vector3(19.5, 0.0, -1.3), 0.0, 0.0)
	p.look_at_point(Vector3(9.0, 1.35, -1.25))
	for l in lance:
		if l != "attuale":
			pack.set_lance(load("res://proposte/zaino/lance/lancia_%s.tscn" % l))
		for i in 50:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join("lancia_%s.jpg" % l), 0.92)
		print("salvato ", l)
	get_tree().quit()
