extends Node
## Ricontrollo della parte tunnel dei caricamenti nel thread (0.3.25, enigmi): la prima volta nel tunnel, col renderer.
## 1. I materiali campione del tunnel (CampioniTunnel): quanto costa sul thread principale prepararli, come nella 0.3.24
##    (load e shader subito, "diretto") o come nel branch (il file dal thread, poi gli shader, "thread").
## 2. Il riscaldamento degli shader dell'avvio (RiscaldamentoShader), come nel gioco.
## 3. Il tunnel costruito fuori vista come nel gioco (a pezzi, col suo riscaldamento): i fotogrammi sopra 33 ms.
## 4. Il giocatore vero (con la lancia, campo visivo 62°) lungo tutta la strada, un punto ogni 3 m, guardando avanti:
##    le compilazioni di pipeline di ogni tipo, fotogramma per fotogramma. Atteso: 0.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd --
##   <questo> <diretto|thread>

var g: Player
var _ultimo := 0
var _lunghi: Array = []
var _misura := false


func _ready() -> void:
	process_priority = -1000
	_run.call_deferred()


func _process(_d: float) -> void:
	var t := Time.get_ticks_usec()
	if _misura and _ultimo > 0 and (t - _ultimo) / 1000.0 > 33.0:
		_lunghi.append(snappedf((t - _ultimo) / 1000.0, 0.1))
	_ultimo = t


func _info() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


const TIPI := ["canvas", "mesh", "surface", "draw", "specialization"]


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var modo := a[1] if a.size() > 1 else "thread"
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	if a.size() > 2 and a[2] == "dopo":
		await _campioni_dopo_avvio(modo)
		get_tree().quit()
		return
	# 1. i materiali campione
	var campioni: Array = []
	var tc := Time.get_ticks_usec()
	if modo == "thread":
		ResourceLoader.load_threaded_request(CampioniTunnel.FILE)
		while ResourceLoader.load_threaded_get_status(CampioniTunnel.FILE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		var tf := Time.get_ticks_usec()
		print("PRIMA campioni dal thread in %.1f ms (a fotogrammi)" % ((tf - tc) / 1000.0))
		tc = Time.get_ticks_usec()
		campioni = CampioniTunnel.carica()
	else:
		campioni = CampioniTunnel.carica()
	print("PRIMA campioni: %d materiali, sul thread principale %.1f ms (%s)" % [campioni.size(), (Time.get_ticks_usec() - tc) / 1000.0, modo])
	# 2. il riscaldamento dell'avvio
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(0, 50, 0)
	cam.look_at(Vector3(0, 100, 1))
	var r := RiscaldamentoShader.new()
	add_child(r)
	var t0 := Time.get_ticks_msec()
	while not r.concluso and Time.get_ticks_msec() - t0 < 1500000:
		await get_tree().process_frame
	print("PRIMA riscaldamento dell'avvio finito in %.0f s, contatori %s" % [(Time.get_ticks_msec() - t0) / 1000.0, _info()])
	# 3. il tunnel fuori vista, a pezzi col suo riscaldamento
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	_misura = true
	var tb := Time.get_ticks_msec()
	await sala.costruisci_a_pezzi()
	for i in 30:
		await get_tree().process_frame
	_misura = false
	print("PRIMA tunnel costruito e riscaldato in %.0f s, contatori %s; fotogrammi sopra 33 ms durante (col renderer): %d %s" % [
			(Time.get_ticks_msec() - tb) / 1000.0, _info(), _lunghi.size(), _lunghi.slice(0, 12)])
	# 4. il giocatore lungo la strada
	g = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(g)
	await get_tree().process_frame
	g.water_pack.set_equipped(true, false)
	g.water_pack.set_tank_amount(g.water_pack.tank_capacity)
	g.input_enabled = true
	(g.find_children("*", "Camera3D", true, false)[0] as Camera3D).make_current()
	Grafica.imposta("fov", 62.0)
	g.set_physics_process(false)
	var punti: Array = sala.punti_dove_si_cammina()
	var prima := _info()
	var totali := [0, 0, 0, 0, 0]
	var dove := []
	for i in punti.size():
		var p: Vector3 = punti[i]
		var s := float(sala.proietta(p)[0])
		var avanti := sala.direzione(s)
		g.teleport(p + Vector3.UP * 0.05, atan2(-avanti.x, -avanti.z), 0.0)
		for k in 4:
			await get_tree().process_frame
			var ora := _info()
			var diff := []
			for j in 5:
				if ora[j] != prima[j]:
					totali[j] += ora[j] - prima[j]
					diff.append("%s %d" % [TIPI[j], ora[j] - prima[j]])
			if not diff.is_empty():
				if dove.size() < 30:
					dove.append("s %.0f (fotogramma %d): %s" % [s, k, ", ".join(diff)])
				if i == 0 and k < 2:
					print("PRIMA al primo punto (il giocatore appena entrato): %s" % ", ".join(diff))
			prima = ora
	print("PRIMA lungo la strada (%d punti): compilazioni %s" % [punti.size(), dict_totali(totali)])
	for d in dove:
		print("   ", d)
	print("PRIMA: RISULTATO %s" % dict_totali(totali))
	get_tree().quit()


func dict_totali(t: Array) -> String:
	var out: PackedStringArray = []
	for j in 5:
		out.append("%s %d" % [TIPI[j], t[j]])
	return ", ".join(out)


## L'ordine del gioco: prima il riscaldamento dell'avvio (che tiene i materiali campione di tutte le zone, anche del
## tunnel), poi, a gioco avviato, i campioni del tunnel come li prende la 0.3.24 ("diretto": load e shader nello stesso
## fotogramma, _precarica_sottomarino) o il branch ("thread": il file dal thread, poi CampioniTunnel.carica in
## _aggiorna_sottomarino). Quanto costano sul thread principale, i fotogrammi sopra 33 ms intanto e le pipeline nuove.
func _campioni_dopo_avvio(modo: String) -> void:
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(0, 50, 0)
	cam.look_at(Vector3(0, 100, 1))
	var r := RiscaldamentoShader.new()
	add_child(r)
	var t0 := Time.get_ticks_msec()
	while not r.concluso and Time.get_ticks_msec() - t0 < 1500000:
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	print("DOPO riscaldamento dell'avvio finito in %.0f s; file dei campioni ancora in cache: %s" % [
			(Time.get_ticks_msec() - t0) / 1000.0, ResourceLoader.has_cached(CampioniTunnel.FILE)])
	var prima := _info()
	_lunghi = []
	_misura = true
	var tc := Time.get_ticks_usec()
	var campioni: Array = []
	var principale := 0.0
	if modo == "thread":
		if ResourceLoader.has_cached(CampioniTunnel.FILE):
			campioni = CampioniTunnel.carica()
		else:
			ResourceLoader.load_threaded_request(CampioniTunnel.FILE)
			while ResourceLoader.load_threaded_get_status(CampioniTunnel.FILE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
			print("DOPO campioni dal thread in %.1f ms (a fotogrammi)" % ((Time.get_ticks_usec() - tc) / 1000.0))
			tc = Time.get_ticks_usec()
			campioni = CampioniTunnel.carica()
	else:
		campioni = CampioniTunnel.carica()
	principale = (Time.get_ticks_usec() - tc) / 1000.0
	var gia := campioni.filter(func(m): return RiscaldamentoShader._tenuti.has(m)).size()
	for i in 30:
		await get_tree().process_frame
	_misura = false
	var ora := _info()
	var diff := []
	for j in 5:
		diff.append("%s %d" % [TIPI[j], ora[j] - prima[j]])
	print("DOPO: RISULTATO %s: %d campioni (%d gli stessi materiali tenuti dal riscaldamento), sul thread principale %.1f ms; fotogrammi sopra 33 ms %s; pipeline nuove %s" % [
			modo, campioni.size(), gia, principale, _lunghi, ", ".join(diff)])
