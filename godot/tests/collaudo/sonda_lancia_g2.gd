extends Node
## Sonda di grafica-2 (#146, 0.3.26): quale pezzo della lancia (o del giocatore) compila pipeline guardando in basso
## col FOV largo. Nel livello di prova, col giocatore vero e lo zaino-pompa: tutte le mesh del giocatore nascoste, si
## guarda giù col FOV dato, poi si riaccendono una per volta (in vista) e per ognuna si stampano le compilazioni
## (surface, draw, specialization) e cosa è: il nodo, la mesh, i materiali delle superfici e il formato dei vertici.
## Modo "giro": senza nascondere niente, FOV 70, 90, 110, giù a -40, -65, -85, con la lancia ferma, che spruzza e che
## aspira; le compilazioni a ogni posa (LANCIA:). Con "riscalda" prima fa il riscaldamento della schermata di
## caricamento (RiscaldamentoShader), come il gioco vero.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/sonda_lancia_g2.gd <pezzi|giro> [riscalda] [fov]

const LEVEL := "res://scenes/test/test_level.tscn"

var p: Player


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _comp() -> Array:
	return [int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))]


func _diff(a: Array, b: Array) -> Array:
	var d := []
	for i in a.size():
		d.append(b[i] - a[i])
	return d


func _descrivi(g: GeometryInstance3D) -> String:
	var s := "%s (%s)" % [p.get_path_to(g), g.get_class()]
	if g is MeshInstance3D and (g as MeshInstance3D).mesh:
		var mi := g as MeshInstance3D
		s += " mesh %s" % (mi.mesh.resource_path if mi.mesh.resource_path != "" else mi.mesh.get_class())
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			var fmt := 0
			if mi.mesh is ArrayMesh:
				fmt = (mi.mesh as ArrayMesh).surface_get_format(i)
			s += " | sup %d: %s%s formato %d" % [i, m.get_class() if m else "nessuno",
				(" " + (m as ShaderMaterial).shader.resource_path) if m is ShaderMaterial and (m as ShaderMaterial).shader else
				(" trasp %d" % (m as BaseMaterial3D).transparency) if m is BaseMaterial3D else "", fmt]
		if mi.skeleton != NodePath():
			s += " (con scheletro)"
	s += " ombre %d strati %d" % [g.cast_shadow, g.layers]
	return s


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var modo: String = a[1] if a.size() > 1 else "pezzi"
	var fov_pezzi := 90.0
	for x in a:
		if x.is_valid_float() and float(x) > 30.0:
			fov_pezzi = float(x)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	if a.has("riscalda"):
		var rs := RiscaldamentoShader.new()
		add_child(rs)
		if not rs.concluso:
			await rs.finito
		rs.queue_free()
		print("LANCIA: riscaldamento fatto")
	get_tree().change_scene_to_file(LEVEL)
	await _frames(30)
	for i in 300:
		p = GameState.player
		if p and p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(18.0)
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(60)
	if modo == "pezzi":
		await _pezzi(fov_pezzi)
	else:
		await _giro()
	print("LANCIA FINITO")
	get_tree().quit()


func _pezzi(fov: float) -> void:
	var geo: Array[GeometryInstance3D] = []
	for n in p.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.visible:
			geo.append(g)
			g.visible = false
	print("LANCIA: %d mesh del giocatore accese, nascoste tutte" % geo.size())
	Grafica.imposta("fov", fov)
	p.set_look(p.yaw, 0.0)
	await _frames(40)
	var c0 := _comp()
	p.set_look(p.yaw, deg_to_rad(-65.0))
	await _frames(20)
	print("LANCIA: fov %d giù 65 senza le mesh del giocatore: %s" % [fov, _diff(c0, _comp())])
	for g in geo:
		c0 = _comp()
		g.visible = true
		await _frames(8)
		var d := _diff(c0, _comp())
		print("LANCIA: %s %s" % [d, _descrivi(g)])


func _giro() -> void:
	for stato in ["ferma", "spruzza", "aspira"]:
		Input.action_release(&"spray")
		Input.action_release(&"suck")
		if stato == "spruzza" and InputMap.has_action(&"spray"):
			Input.action_press(&"spray")
		elif stato == "aspira" and InputMap.has_action(&"suck"):
			Input.action_press(&"suck")
		await _frames(20)
		for fov in [70.0, 90.0, 110.0]:
			Grafica.imposta("fov", fov)
			p.set_look(p.yaw, 0.0)
			await _frames(30)
			for g in [-40.0, -65.0, -85.0]:
				var c0 := _comp()
				p.set_look(p.yaw, deg_to_rad(g))
				await _frames(12)
				print("LANCIA: %s fov %d giù %d: %s" % [stato, fov, -g, _diff(c0, _comp())])
	Input.action_release(&"spray")
	Input.action_release(&"suck")
