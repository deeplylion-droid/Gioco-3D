extends Node
## Collaudo finale 0.3.21 (enigmi): le lampade rosse della scala di servizio (LampadaMuro), soprattutto le due in cima
## alzate di 5 cm. Per ognuna vicino alla scala: la scatola delle sue mesh, quanto spazio resta sotto fino al pavimento
## o al gradino (raggio verso il basso sulle collisioni: almeno 2 m dove si cammina), e il distacco dal muro dietro
## (raggio dal centro della lampada verso il muro). Poi i ravvicinati di ognuna (SCATTI_LUCE=1): davanti, di lato e
## radente al muro (l'attacco).
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd --
##   <questo file> <cartella> [scatti]

var _cartella := ""
var cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String, da: Vector3, verso: Vector3, fov := 50.0) -> void:
	cam.fov = fov
	cam.global_position = da
	var su := Vector3.UP if absf((verso - da).normalized().y) < 0.98 else Vector3.FORWARD
	cam.look_at(verso, su)
	await _frames(20)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join(nome + ".jpg"), 0.9)
	print("SCATTO ", nome)


func _colpo(a: Vector3, b: Vector3, w: World3D, escludi := []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.hit_from_inside = false
	q.exclude = escludi
	return w.direct_space_state.intersect_ray(q)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://collaudo_lampade"
	DirAccess.make_dir_recursive_absolute(_cartella)
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	var p: Player = GameState.player
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.volumetric_fog_enabled = false
	env.environment.ssil_enabled = false
	get_tree().current_scene.add_child(env)
	var ris := get_tree().current_scene.get_node(^"Risalita") as Node3D
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for i in 1200:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 300:
			break
	for i in 10:
		await get_tree().physics_frame
	var w := ris.get_world_3d()
	var cima := (ris.get_node(^"Marker/CimaScala") as Node3D).global_position
	# le lampade rosse: i modelli della LampadaMuro (la scena del GLB, con la piastra figlia) vicino alla scala
	var lampade := []
	for n in ris.find_children("*", "Node3D", true, false):
		if (n as Node).scene_file_path == LampadaMuro.MODELLO and (n as Node3D).global_position.distance_to(cima) < 18.0:
			lampade.append(n)
	lampade.sort_custom(func(x, y): return x.global_position.distance_to(cima) < y.global_position.distance_to(cima))
	print("LAMPADE: %d vicino alla scala (cima in %s)" % [lampade.size(), cima.snapped(Vector3.ONE * 0.01)])
	var k := 0
	var dati := []
	for l: Node3D in lampade:
		var ab := AABB()
		var primo := true
		var sue := l.find_children("*", "MeshInstance3D", true, false)
		for m in sue:
			var mi := m as MeshInstance3D
			var bb := mi.global_transform * mi.get_aabb()
			ab = bb if primo else ab.merge(bb)
			primo = false
		var c := ab.get_center()
		# il pavimento o il gradino sotto la lampada (dal fondo della lampada in giù, e 30 cm davanti, dove si passa)
		var dir := -l.global_basis.z
		var avanti := Vector3(dir.x, 0, dir.z).normalized()
		var minimo := 99.0
		for d: float in [0.0, 0.15, 0.3, 0.5]:
			var da := Vector3(c.x, ab.position.y - 0.001, c.z) + avanti * d
			var r := _colpo(da, da + Vector3.DOWN * 4.0, w, [p.get_rid()])
			if not r.is_empty():
				minimo = minf(minimo, ab.position.y - (r.position as Vector3).y)
		# il muro dietro: dal centro della lampada verso il muro (contro il verso in cui guarda)
		var r_muro := _colpo(c, c - avanti * 1.0, w, [p.get_rid()])
		var muro_d := -1.0
		var dietro_l := -INF    # il punto del modello più verso il muro
		var dietro_p := -INF    # la faccia di dietro della piastra
		var davanti_p := INF    # la faccia di davanti della piastra
		if not r_muro.is_empty():
			muro_d = c.distance_to(r_muro.position as Vector3)
		for m in sue:
			var mi := m as MeshInstance3D
			for v in mi.mesh.get_faces():
				var g := mi.global_transform * v
				var d := (c - g).dot(avanti)
				if mi.name == &"Piastra":
					dietro_p = maxf(dietro_p, d)
					davanti_p = minf(davanti_p, d)
				else:
					dietro_l = maxf(dietro_l, d)
		print("LAMPADA %d %s: centro %s, scatola da %s a %s; sotto %.3f m liberi fino a pavimento/gradino (fondo a y %.3f)" % [
				k, l.name, c.snapped(Vector3.ONE * 0.01), ab.position.snapped(Vector3.ONE * 0.001), ab.end.snapped(Vector3.ONE * 0.001), minimo, ab.position.y])
		print("LAMPADA %d: muro a %.4f m dal centro; piastra da %.4f a %.4f; staffa del modello a %.4f: piastra-muro %.1f mm, staffa-piastra %.1f mm" % [
				k, muro_d, davanti_p, dietro_p, dietro_l, (muro_d - dietro_p) * 1000.0 if muro_d > 0 else -1.0, (davanti_p - dietro_l) * 1000.0])
		dati.append([l, c, avanti, ab])
		k += 1
	if not "scatti" in a:
		print("LAMPADE: FINE")
		get_tree().quit()
		return
	cam = Camera3D.new()
	cam.near = 0.02
	get_tree().current_scene.add_child(cam)
	cam.make_current()
	if OS.get_environment("SCATTI_LUCE") == "1":
		var o := OmniLight3D.new()
		o.omni_range = 2.0
		o.light_energy = 0.8
		o.shadow_enabled = true
		cam.add_child(o)
	var scelte := []
	for x in OS.get_environment("SOLO").split(",", false):
		scelte.append(int(x))
	if scelte.is_empty():
		scelte = range(mini(dati.size(), 5))
	for i: int in scelte:
		var c: Vector3 = dati[i][1]
		var av: Vector3 = dati[i][2]
		var lat := av.cross(Vector3.UP).normalized()
		await _scatto("lampada_%d_davanti" % i, c + av * 0.6 + Vector3.DOWN * 0.25, c)
		await _scatto("lampada_%d_di_lato" % i, c + av * 0.15 + lat * 0.45 + Vector3.DOWN * 0.05, c)
		await _scatto("lampada_%d_attacco_radente" % i, c + av * 0.06 + lat * 0.35 + Vector3.UP * 0.12, c - av * 0.06, 45.0)
		await _scatto("lampada_%d_da_sotto" % i, c + av * 0.35 + Vector3.DOWN * 0.9, c, 55.0)
		# dagli occhi del giocatore: in piedi a 1 m dalla lampada (60 cm dal muro), e passandoci sotto (30 cm dal muro)
		var ab: AABB = dati[i][3]
		var suolo := ab.position.y - 2.0
		var r := _colpo(Vector3(c.x, ab.position.y - 0.001, c.z) + av * 0.3, Vector3(c.x, ab.position.y - 4.0, c.z) + av * 0.3, get_tree().current_scene.get_world_3d(), [GameState.player.get_rid()])
		if not r.is_empty():
			suolo = (r.position as Vector3).y
		var piede := Vector3(c.x, suolo, c.z) + av * 0.5
		await _scatto("lampada_%d_occhi_a_1m" % i, piede + lat * 1.0 + Vector3.UP * 1.6, c, 75.0)
		await _scatto("lampada_%d_occhi_sotto" % i, Vector3(c.x, suolo, c.z) + av * 0.3 - lat * 0.3 + Vector3.UP * 1.6, c + lat * 0.2, 75.0)
	print("LAMPADE: FINE")
	get_tree().quit()
