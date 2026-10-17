extends Node
## Controllo (non usato dal gioco): il getto B con la lancia C1 nella sala principale al blackout,
## verso l'area bimbi lungo la scia rosa. Due scatti: durante la carica e a getto pieno.
## Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 30 \
##        --resolution 1280x720 --script res://tests/run.gd -- res://proposte/zaino/controllo_buio.gd <cartella>

const LEVEL := "res://scenes/sala_principale.tscn"

var cartella := "/tmp/claude-0/c1"
var p: Player


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		cartella = args[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	var level := (load(LEVEL) as PackedScene).instantiate()
	for percorso in ["Interni", "Tecnici"]:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _frames(10)
	get_tree().paused = false
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.stand_eye_height = 1.7
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(20.0)
	var torcia := p.find_child("Torcia", true, false)
	if torcia:
		torcia.call(&"imposta_accesa", true)
	var mira := Vector3(-17.0, 1.0, 7.0)
	p.teleport(Vector3(-12.5, 0.0, 13.6), 0.0, 0.0)
	p.look_at_point(mira)
	await _frames(40)
	Input.action_press(&"spray")
	await _frames(6)
	await _salva("buio_carica")
	await _frames(40)
	p.look_at_point(mira + Vector3(1.0, 0.0, 0.0))
	await _salva("buio_getto")
	Input.action_release(&"spray")
	get_tree().quit()


func _salva(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join("c1_%s.jpg" % nome), 0.9)
	print("salvato ", nome)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
