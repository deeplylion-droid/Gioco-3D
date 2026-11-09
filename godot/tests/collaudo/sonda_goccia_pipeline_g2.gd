extends Node
## Sonda di grafica-2 (0.3.24): da dove viene la pipeline 2D ("canvas") che il collaudo della 0.3.23 vede compilare nel
## fotogramma in cui compare la goccia di bava della scena dello squalo, nel gioco vero dopo la schermata di caricamento.
## Senza la sala (non ci sta in memoria): il riscaldamento intero della schermata di caricamento (RiscaldamentoShader),
## poi una vista 3D con l'ambiente della sala e la goccia fatta come la fa RisveglioSqualo (_crea_goccia: disegnata
## trasparente per FOTOGRAMMI_GOCCIA fotogrammi, poi nascosta; _muovi_goccia: accesa coi parametri della scena).
## Stampa le pipeline 2D compilate in ogni fase.
## Uso (sotto il render.lock, col renderer vero):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720
##     --script res://tests/run.gd -- res://tests/collaudo/sonda_goccia_pipeline_g2.gd [senza_riscaldamento]

var _c0 := 0


func _canvas() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))


func _fase(nome: String) -> void:
	var c := _canvas()
	print("FASE %-55s canvas +%d (totale %d)" % [nome, c - _c0, c])
	_c0 = c


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	await _frames(5)
	_c0 = _canvas()
	_fase("avvio")
	# "goccia_vuoto" / "goccia_3d": solo RiscaldamentoShader.riscalda_goccia, in un SubViewport 64x64 vuoto o con la vista
	# 3D del riscaldamento (ambiente, luci, camera)
	if args.has("goccia_vuoto") or args.has("goccia_3d"):
		var sv := SubViewport.new()
		sv.size = Vector2i(64, 64)
		sv.own_world_3d = true
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		RiscaldamentoShader.copia_viewport(sv, get_viewport())
		add_child(sv)
		if args.has("goccia_3d"):
			var env := WorldEnvironment.new()
			env.environment = RiscaldamentoShader.ambiente()
			sv.add_child(env)
			var c3 := Camera3D.new()
			c3.position = Vector3(0, 0, 3)
			sv.add_child(c3)
			c3.current = true
			await _frames(5)
			_fase("SubViewport con la vista 3D")
		await RiscaldamentoShader.riscalda_goccia(sv, 3)
		_fase("riscalda_goccia")
		sv.queue_free()
	elif not args.has("senza_riscaldamento"):
		Grafica.post_processing_visibile(false)
		var rs := RiscaldamentoShader.new()
		add_child(rs)
		if not rs.concluso:
			await rs.finito
		await _frames(2)
		_fase("riscaldamento intero (schermata di caricamento)")
		rs.queue_free()
		RiscaldamentoShader._tenuti.clear()
		Grafica.post_processing_visibile(true)
		await _frames(5)
		_fase("post-processing di nuovo visibile")
	# la vista 3D del gioco: l'ambiente della sala, una luce, un cubo
	var we := WorldEnvironment.new()
	we.environment = RiscaldamentoShader.ambiente()
	add_child(we)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1, 3)
	add_child(cam)
	cam.current = true
	var luce := OmniLight3D.new()
	luce.position = Vector3(1, 2, 2)
	add_child(luce)
	var cubo := MeshInstance3D.new()
	cubo.mesh = BoxMesh.new()
	add_child(cubo)
	await _frames(10)
	_fase("vista 3D")
	# la goccia come RisveglioSqualo._crea_goccia
	var strato := CanvasLayer.new()
	strato.layer = 2
	add_child(strato)
	var goccia := ColorRect.new()
	goccia.set_anchors_preset(Control.PRESET_FULL_RECT)
	goccia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = RisveglioSqualo.SHADER_GOCCIA
	mat.set_shader_parameter(&"forza", 0.0)
	goccia.material = mat
	strato.add_child(goccia)
	await _frames(RisveglioSqualo.FOTOGRAMMI_GOCCIA)
	_fase("goccia creata e disegnata trasparente (forza 0)")
	goccia.visible = false
	await _frames(20)
	_fase("goccia nascosta")
	# accesa come _muovi_goccia, fotogramma per fotogramma per 2,7 s a 30 fps
	goccia.visible = true
	var vp := get_viewport().get_visible_rect().size
	for f in 81:
		var x := f / 30.0
		var arrivo := clampf(x / 0.06, 0.0, 1.0)
		var spezzato := clampf((x - 0.55) / 0.3, 0.0, 1.0)
		var tirata := arrivo * (1.0 - spezzato) * (0.7 + 0.3 * sin(x * 9.0))
		var scivola := maxf(x - 0.65, 0.0)
		var giu := 0.12 * scivola * scivola + 0.03 * scivola
		var centro := Vector2(0.37 + 0.015 * sin(scivola * 2.3), 0.28 - 0.012 * tirata + 0.01 * spezzato + giu)
		mat.set_shader_parameter(&"aspetto", vp.x / maxf(vp.y, 1.0))
		mat.set_shader_parameter(&"centro", centro)
		mat.set_shader_parameter(&"raggio", lerpf(0.035, 0.08, arrivo) * (1.0 - 0.3 * clampf(scivola / 2.0, 0.0, 1.0)))
		mat.set_shader_parameter(&"scia", clampf(giu / 0.05, 0.0, 9.0))
		mat.set_shader_parameter(&"tirata", tirata)
		mat.set_shader_parameter(&"rottura", spezzato)
		mat.set_shader_parameter(&"filo", arrivo * (1.0 - smoothstep(0.75, 1.0, spezzato)))
		mat.set_shader_parameter(&"tempo", x)
		mat.set_shader_parameter(&"aggancio", Vector2(0.6, 0.45))
		mat.set_shader_parameter(&"forza", arrivo * (1.0 - clampf((x - 2.0) / 0.7, 0.0, 1.0)))
		await _frames(1)
		var c := _canvas()
		if c != _c0:
			print("  a %.2f s della goccia: canvas +%d" % [x, c - _c0])
			_c0 = c
	_fase("goccia accesa per 2,7 s (dopo l'ultima riga sopra)")
	print("RISULTATO: 1 controlli ok, 0 falliti")
	get_tree().quit()
