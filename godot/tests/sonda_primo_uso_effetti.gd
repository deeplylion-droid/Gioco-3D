extends Node
## Sonda degli effetti visti per la prima volta a metà partita (ritocco "scatti" dell'utente del 4 novembre, scelta A):
## negli interni, dopo la preparazione dello zaino (PreparaEffetti), accende uno per volta davanti alla camera gli
## effetti che compaiono solo con un evento e conta, per ognuno, le compilazioni che fermano il fotogramma ("surface" e
## "draw", come test_primo_uso) e il fotogramma più lungo. Stampa soltanto: serve a decidere cosa mettere nel
## riscaldamento (RiscaldamentoShader).
## Serve il renderer vero: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan
##   --resolution 320x180 --script res://tests/run.gd -- res://tests/sonda_primo_uso_effetti.gd

const LEVEL := "res://scenes/interni/interni.tscn"
const POSIZIONE := Vector3(9.7, 0.0, -10.6)
const MIRA := Vector3(9.7, 1.2, -17.8)
const POZZA := Vector3(9.7, -0.05, -12.9)

var p: Player
var _prima := {}
var _max_ms := 0.0
var _ultimo := 0


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
	print("EFFETTO %-28s surface %3d  draw %3d  fotogramma più lungo %4.0f ms" % [cosa, s, d, _max_ms])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _davanti(dist := 2.5) -> Vector3:
	return p.camera.global_position + (-p.camera.global_basis.z) * dist


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	GameState.save_to_disk = false
	if RenderingServer.get_rendering_device() == null:
		print("SONDA: serve il renderer vero")
		get_tree().quit(1)
		return
	get_tree().change_scene_to_file(LEVEL)
	await _frames(10)
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.water_pack.call(&"set_equipped", true, false)
	p.teleport(POSIZIONE, 0.0, 0.0)
	p.look_at_point(MIRA)
	await _frames(60)
	var scena := get_tree().current_scene

	# lo spruzzo e l'aspirazione (già preparati: per confronto)
	p.water_pack.set_tank_amount(20.0)
	_azzera()
	Input.action_press(&"spray")
	await _frames(30)
	Input.action_release(&"spray")
	await _frames(10)
	_stampa("spruzzo")
	p.look_at_point(POZZA)
	p.water_pack.set_tank_amount(0.0)
	await _frames(20)
	_azzera()
	Input.action_press(&"suck")
	await _frames(25)
	Input.action_release(&"suck")
	await _frames(10)
	_stampa("aspirazione")
	p.look_at_point(MIRA)
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

	# le medusine della piscina a onde (luminose, aspirate)
	var med := load("res://shaders/medusine.gdshader") as Shader
	var mm := MeshInstance3D.new()
	mm.mesh = SphereMesh.new()
	var mmat := ShaderMaterial.new()
	mmat.shader = med
	mm.material_override = mmat
	_azzera()
	scena.add_child(mm)
	mm.global_position = _davanti()
	await _frames(20)
	_stampa("medusine (shader)")
	mm.queue_free()

	# la Polaroid ingrandita
	var viewer: CanvasLayer = load("res://scripts/ui/photo_viewer.gd").new()
	viewer.set(&"texture", load("res://icon.svg") if ResourceLoader.exists("res://icon.svg") else null)
	_azzera()
	get_tree().root.add_child(viewer)
	await _frames(30)
	_stampa("Polaroid ingrandita")
	viewer.queue_free()
	await _frames(5)

	# la prima morte (la scena di morte)
	_azzera()
	GameState.kill_player(&"sonda")
	await _frames(90)
	_stampa("scena di morte")

	print("SONDA FINITA")
	get_tree().quit(0)
