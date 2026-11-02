extends Node
## Scatti dal motore delle pile di scatoloni del fiume lento, lungo la strada del giocatore dall'ingresso del capannone
## al salvagente dell'imbarco (richiesta dell'utente sulla 0.3.19: "le scatole di quella parte sono dei muri troppo
## regolari, puoi renderle più sfalsate tra di loro e anche aderenti ai vari muri, in modo che non rimangano spazi aperti
## nel percorso"): ogni PASSO m, dagli occhi, avanti, a sinistra e a destra; poi la pianta vista dall'alto. Luci del gioco
## (blackout dopo il risveglio della sala pompe), ambiente della sala senza GI, nebbia volumetrica e SSIL (memoria).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_pile_fiume.gd <cartella> [solo=nome,...]

const PASSO := 2.5
## Quanto si gira a sinistra e a destra (gradi).
const LATO := 60.0

var _p: Player
var _cartella := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _guarda(occhio: Vector3, punto: Vector3) -> void:
	_p.global_position = occhio - Vector3.UP * (_p.get_eye_position().y - _p.global_position.y)
	_p.look_at_point(punto)
	_p.camera.global_transform = _p.get_aim_transform()


func _salva(nome: String) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("solo=") and not Array(a.substr(5).split(",")).any(func(x): return nome.begins_with(x)):
			return
	await _frames(30)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_cartella)
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join(nome + ".jpg"), 0.9)
	print("scatto ", nome)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_pile_fiume"
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	_p = GameState.player
	_p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := _p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	_p.camera.make_current()
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.volumetric_fog_enabled = false
	env.environment.ssil_enabled = false
	get_tree().current_scene.add_child(env)
	var ris := get_tree().current_scene.get_node(^"Risalita")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	ris.call(&"carica_subito")
	for i in 1800:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and ris.get(&"fiume") != null and i > 120:
			break
	var fiume := ris.get(&"fiume") as Node3D
	var m := fiume.get_node(^"Marker")
	var punti: Array[Vector3] = []
	for nome in ["Ingresso", "FineFila", "Imbarco"]:
		punti.append((m.get_node(NodePath(nome)) as Node3D).global_position)
	# la strada a passi di PASSO m
	var strada: Array[Vector3] = []
	for k in punti.size() - 1:
		var l := punti[k].distance_to(punti[k + 1])
		var n := maxi(1, int(ceil(l / PASSO)))
		for i in n:
			strada.append(punti[k].lerp(punti[k + 1], float(i) / n))
	strada.append(punti[-1])
	var e := Vector3.UP * 1.6
	for i in strada.size():
		var q := strada[i]
		var dopo := strada[mini(i + 1, strada.size() - 1)]
		var avanti := (dopo - q) if i < strada.size() - 1 else (q - strada[i - 1])
		avanti.y = 0.0
		avanti = avanti.normalized()
		for v in [["avanti", 0.0], ["sinistra", LATO], ["destra", -LATO]]:
			var dir := avanti.rotated(Vector3.UP, deg_to_rad(v[1]))
			_guarda(q + e, q + e + dir * 5.0 + Vector3.DOWN * 0.3)
			await _salva("%02d_%s" % [i, v[0]])
	# la pianta dall'alto: le pile, le transenne, le rocce e i muri intorno alla strada
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 34.0
	cam.far = 80.0
	get_tree().current_scene.add_child(cam)
	var centro := (punti[0] + punti[-1]) * 0.5
	cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), centro + Vector3.UP * 30.0)
	cam.make_current()
	# (dall'alto il soffitto copre: si nasconde quello che sta sopra i 7 m)
	for n in fiume.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.get_aabb().position.y + mi.global_position.y - fiume.global_position.y > 6.5:
			mi.visible = false
	var luce := DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-90, 0, 0)
	luce.light_energy = 0.6
	get_tree().current_scene.add_child(luce)
	await _salva("pianta")
	print("PILE: finito")
	get_tree().quit()
