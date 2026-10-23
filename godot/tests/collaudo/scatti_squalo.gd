extends Node
## Collaudo: scatti dagli occhi del giocatore durante la scena dello squalo, uno ogni [OGNI] fotogrammi (a 60 al
## secondo con --fixed-fps 60), più quelli ai tempi chiave dati sulla riga di comando.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --fixed-fps 60 --resolution 640x360 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_squalo.gd <cartella> [ogni]

var cartella := ""
var ogni := 6


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cartella = a[1]
	if a.size() > 2:
		ogni = int(a[2])
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var livello := (load("res://scenes/interni/interni.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 30:
		await get_tree().process_frame
	var p := GameState.player
	var rs := livello.get_node(^"Gioco/RisveglioSqualo")
	var finito := [false]
	rs.connect(&"finito", func(): finito[0] = true)
	livello.call(&"fai_risveglio", p, true)
	var n := 0
	var dopo := 0
	while dopo < 90:
		await get_tree().process_frame
		n += 1
		if finito[0]:
			dopo += 1
		if n % ogni == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_jpg(cartella + "/sq_%04d.jpg" % n, 0.85)
	print("SCATTI %d fotogrammi" % n)
	get_tree().quit()
