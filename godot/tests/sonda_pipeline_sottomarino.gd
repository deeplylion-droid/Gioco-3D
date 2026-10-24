extends Node
## Sonda: le pipeline degli shader che si compilano quando il tunnel sottomarino si vede la prima volta (gli scatti
## della prima volta). Costruisce il tunnel fuori vista come nel gioco (a pezzi, col riscaldamento), poi porta la
## camera lungo la strada e stampa dove si compila qualcosa al disegno. Atteso: niente righe "s ...".
## Uso (sotto il lock, col renderer vero):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 640x360 \
##       --script res://tests/run.gd -- res://tests/sonda_pipeline_sottomarino.gd
func _ready() -> void:
	_run.call_deferred()
func _info() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH)]
func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 50, 0)
	cam.look_at(Vector3(0, 100, 1))
	for i in 30:
		await get_tree().process_frame
	print("prima ", _info())
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	await sala.costruisci_a_pezzi()
	for i in 120:
		await get_tree().process_frame
	var base := _info()
	print("costruito, fuori vista ", base)
	var s := 0.0
	while s < sala.lunghezza():
		var p := sala.punto(s)
		cam.global_position = Vector3(p.x, sala.piano + 1.6, p.z) - sala.destra(s) * 5.0
		cam.look_at(cam.global_position + sala.direzione(s), Vector3.UP)
		for i in 4:
			await get_tree().process_frame
		var ora := _info()
		if ora[0] != base[0] or ora[1] != base[1]:
			print("s %.0f: disegno +%d, specializzazione +%d" % [s, ora[0] - base[0], ora[1] - base[1]])
		base = ora
		s += 12.0
	print("fine ", _info())
	get_tree().quit()
