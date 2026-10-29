extends Node
## Ricontrollo (ambienti-1, 29 ottobre): gli oblò della risalita col rosso della torre (lavoro/torre-rosso) devono restare
## come prima (i loro veli e vetro non hanno colore). La risalita da sola, caricata subito; per ogni ObloLei lei compare
## e la camera la guarda da 1,5 m davanti al vetro. Da lanciare uguale sulla 0.3.15 e sul branch.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan
##   --resolution 1280x720 --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/oblo_risalita_a1.gd <cartella> <prefisso>


func _ready() -> void:
	_run.call_deferred()


func _fotogrammi(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella: String = a[1]
	var prefisso: String = a[2]
	DirAccess.make_dir_recursive_absolute(cartella)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"risalita_subito", true)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var r := (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate()
	if &"giocatore_proprio" in r:
		r.set(&"giocatore_proprio", false)
	add_child(r)
	await _fotogrammi(10)
	if r.has_method(&"carica_subito"):
		r.call(&"carica_subito")
	await _fotogrammi(30)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	cam.near = 0.05
	add_child(cam)
	cam.current = true
	var k := 0
	for ob in r.find_children("*", "ObloLei", true, false):
		var oblo := ob as ObloLei
		oblo.process_mode = Node.PROCESS_MODE_ALWAYS
		oblo.set_process(false)
		oblo._mostra()
		await _fotogrammi(30)
		var c := oblo.centro_vetro()
		cam.look_at_from_position(c + oblo.normale() * 1.5 + Vector3.UP * 0.1, c, Vector3.UP)
		await _fotogrammi(40)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s_risalita_oblo_%d.jpg" % [prefisso, k]), 0.92)
		print("OBLO risalita %d (%s) scattato" % [k, oblo.name])
		k += 1
		if k >= 3:
			break
	print("OBLO risalita: %d oblò" % k)
	get_tree().quit()
