extends Node
## Misura il costo delle gocce dell'impatto del getto (riscontro sulla v0.3.7: "se spruzzi da vicino
## contro un muro, le particle delle gocce degli spruzzi danno fastidio e fanno laggare"). Negli
## spogliatoi degli interni, col renderer vero (Vulkan), davanti al muro del tornello a più distanze.
## Per ogni distanza, prima senza spruzzare e poi spruzzando (dopo 1 s, a getto ormai pieno):
## - la mediana dei ms del fotogramma e del tempo di disegno della GPU (llvmpipe: è la CPU che disegna);
## - l'overdraw: la scena disegnata in modo DEBUG_DRAW_OVERDRAW (ogni strato aggiunge luce), la media
##   della luminosità dello schermo; la differenza con e senza getto è quanto schermo coprono gli effetti;
## - le particelle dell'impatto vive (somma di amount × amount_ratio di quelle che emettono).
## Uso (sotto flock /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path godot --rendering-driver vulkan --resolution 640x360 \
##     --script res://tests/run.gd -- res://tests/misura_impatto.gd [scatti]

const LEVEL := "res://scenes/interni/interni.tscn"
const POSIZIONE := Vector3(9.7, 0.0, -10.6)
const MIRA := Vector3(9.7, 1.2, -17.8)
const DISTANZE := [0.8, 1.5, 3.0, 6.0]

var p: Player
var _ms: Array = []
var _ultimo := 0


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	var ora := Time.get_ticks_usec()
	if _ultimo > 0:
		_ms.append((ora - _ultimo) / 1000.0)
	_ultimo = ora


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
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
	var vp := get_viewport()
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	# il muro davanti: dove arriva il raggio dagli occhi verso la mira
	p.teleport(POSIZIONE, 0.0, 0.0)
	p.look_at_point(MIRA)
	await _frames(30)
	var occhio := p.camera.global_position
	var q := PhysicsRayQueryParameters3D.create(occhio, occhio + (MIRA - occhio).normalized() * 20.0, 1)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		print("niente muro davanti")
		get_tree().quit(1)
		return
	var muro: Vector3 = hit.position
	var verso := Vector3(MIRA.x - POSIZIONE.x, 0, MIRA.z - POSIZIONE.z).normalized()
	print("muro a %s" % str(muro))
	print("distanza | ms fotogramma (fermo -> getto) | ms GPU | overdraw (fermo -> getto) | particelle impatto")
	for d in DISTANZE:
		var pos := Vector3(muro.x, POSIZIONE.y, muro.z) - verso * float(d)
		p.teleport(pos, 0.0, 0.0)
		p.look_at_point(muro)
		p.water_pack.set_tank_amount(20.0)
		await _frames(30)
		var fermo := await _misura(vp)
		Input.action_press(&"spray")
		await _secondi(1.0)
		p.water_pack.set_tank_amount(20.0)
		var getto := await _misura(vp)
		if OS.get_cmdline_user_args().has("scatti"):
			var img := vp.get_texture().get_image()
			img.save_jpg("user://impatto_%.1f.jpg" % d, 0.9)
			print("  scatto: %s" % ProjectSettings.globalize_path("user://impatto_%.1f.jpg" % d))
		var vive := _particelle_impatto()
		var colpisce: bool = p.water_pack.has_hit
		var k = p.water_pack.get_node(^"GettoPotente").get(&"lontananza_impatto")
		Input.action_release(&"spray")
		await _secondi(4.0)
		print("%.1f m | %.0f -> %.0f | %.0f -> %.0f | %.3f -> %.3f | %d (colpisce: %s, lontananza: %s)" % [d, fermo.ms,
				getto.ms, fermo.gpu, getto.gpu, fermo.overdraw, getto.overdraw, vive, colpisce, k])
	get_tree().quit()


## Mediana dei ms del fotogramma e della GPU su 40 fotogrammi, poi l'overdraw su 3 fotogrammi.
func _misura(vp: Viewport) -> Dictionary:
	_ms.clear()
	var gpu: Array = []
	for i in 40:
		await get_tree().process_frame
		p.water_pack.set_tank_amount(20.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid()))
	var ms := _ms.duplicate()
	ms.sort()
	gpu.sort()
	vp.debug_draw = Viewport.DEBUG_DRAW_OVERDRAW
	var somma := 0.0
	for i in 3:
		await RenderingServer.frame_post_draw
		somma += _luminosita(vp.get_texture().get_image())
	vp.debug_draw = Viewport.DEBUG_DRAW_DISABLED
	await _frames(2)
	return {"ms": ms[ms.size() / 2], "gpu": gpu[gpu.size() / 2], "overdraw": somma / 3.0}


static func _luminosita(img: Image) -> float:
	img.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var s := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			s += (c.r + c.g + c.b) / 3.0
	return s / float(img.get_width() * img.get_height())


func _particelle_impatto() -> int:
	var g := p.water_pack.get_node_or_null(^"GettoPotente")
	var n := 0
	for nome in [&"_schizzi", &"_lame", &"_goccioloni", &"_rivoli", &"_nebbia_impatto"]:
		var gp := g.get(nome) as GPUParticles3D
		if gp and gp.emitting:
			n += int(gp.amount * gp.amount_ratio)
	var fx := p.get_node_or_null(^"EffettiZaino")
	if fx:
		for nome in [&"_spray", &"_mist"]:
			var gp := fx.get(nome) as GPUParticles3D
			if gp and gp.emitting:
				n += int(gp.amount * gp.amount_ratio)
	return n


func _secondi(t: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < t * 1000.0:
		await get_tree().process_frame
		p.water_pack.set_tank_amount(20.0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
