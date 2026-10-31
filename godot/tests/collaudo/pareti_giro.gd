extends Node
## Collaudo dei muri a pannelli (shader parete.gdshader) con i materiali veri: gli interni o i tecnici da soli, messi
## dove stanno nella sala principale, con l'ambiente e gli attributi della camera della sala, e una camera agli occhi
## nei punti di una lista (righe "nome px py pz yaw pitch", coordinate del mondo della sala, yaw 0 guarda verso -z).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --script res://tests/run.gd -- res://tests/collaudo/pareti_giro.gd <cartella> <interni|tecnici> <lista> [prima|blackout] [ogni]
## [ogni]: uno scatto ogni tante righe della lista (di serie 1).

const SCENE := {
	"interni": ["res://scenes/interni/interni.tscn", Transform3D(Basis(), Vector3(-9.7, 0, 40.9))],
	"tecnici": ["res://scenes/tecnici/tecnici.tscn", Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(0, -9.05, 1.36))],
}


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cart := a[1]
	var zona := a[2]
	var lista := a[3]
	var luci := a[4] if a.size() > 4 else "blackout"
	var ogni := int(a[5]) if a.size() > 5 else 1
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT if luci == "blackout" else GameState.Luci.PRIMA_DEL_RISVEGLIO
	var s: Node3D = (load(SCENE[zona][0]) as PackedScene).instantiate()
	s.set(&"giocatore_proprio", false)
	add_child(s)
	s.global_transform = SCENE[zona][1]
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.03
	add_child(cam)
	cam.make_current()
	await _frames(120)
	GameState.imposta_luci(GameState.Luci.BLACKOUT if luci == "blackout" else GameState.Luci.PRIMA_DEL_RISVEGLIO)
	await _frames(60)
	var n := 0
	var k := 0
	for riga in FileAccess.get_file_as_string(lista).split("\n"):
		var c := riga.strip_edges().split(" ", false)
		if c.size() < 6 or c[0].begins_with("#"):
			continue
		k += 1
		if (k - 1) % ogni != 0:
			continue
		cam.global_position = Vector3(float(c[1]), float(c[2]), float(c[3]))
		cam.rotation_degrees = Vector3(float(c[5]), float(c[4]), 0)
		await _frames(12)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cart.path_join("%s_%s_%s.jpg" % [zona, luci, c[0]]), 0.88)
		n += 1
	print("PARETI: %s %s: %d scatti" % [zona, luci, n])
	get_tree().quit()
