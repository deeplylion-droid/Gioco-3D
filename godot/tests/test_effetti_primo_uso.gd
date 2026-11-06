extends Node
## Test degli effetti visti per la prima volta a metà partita (ritocco "scatti" dell'utente del 4 novembre, scelta A):
## dopo il riscaldamento della schermata di caricamento (RiscaldamentoShader), accende uno per volta davanti alla camera gli
## effetti che compaiono solo con un evento e conta, per ognuno, le compilazioni che fermano il fotogramma ("surface" e
## "draw", come test_primo_uso) e il fotogramma più lungo (stampato soltanto: su llvmpipe ogni fotogramma ne fa già circa
## 100). Con "senza_riscaldamento" si vede che il test se ne accorge (2 compilazioni per effetto).
## Serve il renderer vero: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan
##   --resolution 320x180 --script res://tests/run.gd -- res://tests/test_effetti_primo_uso.gd


var _prima := {}
var _max_ms := 0.0
var _ultimo := 0
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _process(_d: float) -> void:
	var adesso := Time.get_ticks_usec()
	if _ultimo > 0:
		_max_ms = maxf(_max_ms, (adesso - _ultimo) / 1000.0)
	_ultimo = adesso


func _azzera() -> void:
	_prima = {"surface": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
			"draw": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)}
	_max_ms = 0.0


func _stampa(cosa: String) -> void:
	var s := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) - _prima["surface"])
	var d := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) - _prima["draw"])
	var testo := "%s: surface %d, draw %d (fotogramma più lungo %.0f ms)" % [cosa, s, d, _max_ms]
	if s == 0 and d == 0:
		_passed += 1
		print("  ok   ", testo)
	else:
		_failed += 1
		printerr("  FAIL ", testo, ": compila al primo uso, va nel riscaldamento (RiscaldamentoShader.effetti_campione)")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


var _cam: Camera3D


func _davanti(dist := 2.5) -> Vector3:
	return _cam.global_position + (-_cam.global_basis.z) * dist


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	GameState.save_to_disk = false
	if RenderingServer.get_rendering_device() == null:
		printerr("  FAIL serve il renderer vero")
		get_tree().quit(1)
		return
	# un mondo piccolo con la camera, le luci con le ombre e l'ambiente della sala (gli interni col riscaldamento non
	# stanno nei 15 GB su llvmpipe); lo spruzzo e l'aspirazione li prova test_primo_uso
	var scena := Node3D.new()
	scena.name = "Mondo"
	add_child(scena)
	var amb := RiscaldamentoShader.ambiente()
	if amb:
		var we := WorldEnvironment.new()
		we.environment = amb
		scena.add_child(we)
	var sole := DirectionalLight3D.new()
	sole.shadow_enabled = true
	sole.rotation_degrees = Vector3(-50, 30, 0)
	scena.add_child(sole)
	var punto := OmniLight3D.new()
	punto.shadow_enabled = true
	punto.position = Vector3(0, 2.0, -1.0)
	scena.add_child(punto)
	_cam = Camera3D.new()
	scena.add_child(_cam)
	_cam.current = true
	_cam.position = Vector3(0, 1.6, 0)
	await _frames(10)
	if not OS.get_cmdline_user_args().has("senza_riscaldamento"):
		var r := RiscaldamentoShader.new()
		add_child(r)
		var t := Time.get_ticks_msec()
		while not r.concluso and Time.get_ticks_msec() - t < 600000:
			await get_tree().process_frame
		print("  (riscaldamento fatto in %.0f s)" % ((Time.get_ticks_msec() - t) / 1000.0))
		await _frames(10)

	# il gorgo dello scarico (vasche che si svuotano)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	g.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/vortex.gdshader")
	gm.set_shader_parameter(&"strength", 1.0)
	g.material_override = gm
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_azzera()
	scena.add_child(g)
	g.global_position = _davanti() + Vector3(0, -0.8, 0)
	await _frames(20)
	_stampa("gorgo dello scarico")
	g.queue_free()

	# la bava rosa di lei
	var b := BavaRosa.new()
	var c := _davanti(2.0)
	b.punti = PackedVector3Array([c + Vector3(-0.6, -1.0, 0), c + Vector3(0, -1.0, 0.2), c + Vector3(0.6, -1.0, 0)])
	_azzera()
	scena.add_child(b)
	await _frames(20)
	_stampa("bava rosa")
	b.queue_free()

	# il vapore (sala pompe al risveglio, ritorno al buio)
	var v := Vapore.new()
	_azzera()
	scena.add_child(v)
	v.global_position = _davanti() + Vector3(0, -1.0, 0)
	v.emitting = true
	await _frames(40)
	_stampa("vapore")
	v.queue_free()

	# le medusine della piscina a onde (MultiMesh con colori e dati, come Medusine._multimesh)
	var mmi: Array[Node] = []
	_azzera()
	for parte in [[Medusine.mesh_medusina(), "res://shaders/medusine.gdshader", 2],
			[QuadMesh.new(), "res://shaders/medusine_alone.gdshader", 1]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = parte[0]
		mm.instance_count = 3
		for i in 3:
			mm.set_instance_transform(i, Transform3D(Basis() * 0.2, _davanti() + Vector3(i * 0.4 - 0.4, 0, 0)))
			mm.set_instance_color(i, Color(0.4, 1, 0.8, 1))
			mm.set_instance_custom_data(i, Color(0.2, 0.7, 0.1, 0.9))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = load(parte[1])
		mat.render_priority = parte[2]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.top_level = true
		scena.add_child(mi)
		mmi.append(mi)
	await _frames(20)
	_stampa("medusine")
	for n in mmi:
		n.queue_free()

	# la Polaroid ingrandita
	var viewer: CanvasLayer = load("res://scripts/ui/photo_viewer.gd").new()
	viewer.set(&"texture", load("res://icon.svg") if ResourceLoader.exists("res://icon.svg") else null)
	_azzera()
	get_tree().root.add_child(viewer)
	await _frames(30)
	_stampa("Polaroid ingrandita")
	viewer.queue_free()
	await _frames(5)


	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
