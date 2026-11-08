extends Node
## Ricontrollo del guanto per la 0.3.23 (enigmi): le compilazioni di pipeline quando il guanto entra in vista la prima
## volta, di ogni tipo (canvas, mesh, surface, draw, specialization), fotogramma per fotogramma.
## Come nel gioco: prima il riscaldamento degli shader della schermata di caricamento (RiscaldamentoShader), poi:
## - oblo: il giocatore vero con la lancia davanti a un oblò (ObloLei); la lancia in vista per un po', poi lei compare
##   con la sua luce rosa (preparata fuori vista come negli oblò leggeri), poi si guarda in basso piano piano fino a
##   -89° e si torna su, col campo visivo del gioco (62°) e poi a 90°;
## - tunnel: il tunnel sottomarino costruito come nel gioco (a pezzi, col suo riscaldamento), il giocatore vero sulla
##   banchina a s 133; la lancia in vista, poi si guarda in basso e si torna su, a 62° e poi a 90°.
## Con "vecchio" il guanto ha il suo materiale di prima (mani_col_materiale_del_modello falso), per controllo.
## Per ogni fotogramma con una compilazione: quale tipo, l'angolo, se il guanto è dentro la vista (la sua scatola) e
## quanti suoi vertici sono nello schermo.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##   --script res://tests/run.gd -- res://tests/collaudo/sonda_guanto_pipeline.gd <oblo|tunnel> <nuovo|vecchio> \
##   [senza_riscaldamento|nascondi_guanto|nascondi_lancia]

var g: Player
var guanto: MeshInstance3D
var _punti := PackedVector3Array()
var _totali := {}


func _ready() -> void:
	_run.call_deferred()


func _info() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


const TIPI := ["canvas", "mesh", "surface", "draw", "specialization"]


func _trova_guanto() -> void:
	guanto = null
	for m in g.water_pack.lance_rig.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var mat := mi.mesh.surface_get_material(0) if mi.mesh and mi.mesh.get_surface_count() > 0 else null
		if mat and String(mat.resource_name).begins_with("Guanto"):
			guanto = mi
	_punti = PackedVector3Array()
	if guanto:
		var f := guanto.mesh.get_faces()
		for i in range(0, f.size(), 3):
			_punti.append(f[i])


## [dentro la vista (la scatola del guanto tocca il tronco della camera), vertici nello schermo]
func _in_vista() -> Array:
	var cam := get_viewport().get_camera_3d()
	if guanto == null or cam == null:
		return [false, 0]
	var xf := guanto.global_transform
	var aabb := xf * guanto.get_aabb()
	var tocca := false
	var piani := cam.get_frustum()
	tocca = true
	for pl in piani:
		# la scatola è tutta fuori da un piano: fuori dalla vista
		var fuori := true
		for i in 8:
			if not pl.is_point_over(aabb.get_endpoint(i)):
				fuori = false
				break
		if fuori:
			tocca = false
			break
	var n := 0
	var r := get_viewport().get_visible_rect().size
	for v in _punti:
		var w := xf * v
		if cam.is_position_behind(w):
			continue
		var s := cam.unproject_position(w)
		if s.x >= 0.0 and s.x <= r.x and s.y >= 0.0 and s.y <= r.y:
			n += 1
	return [tocca, n]


## Fotogrammi [param n] con lo sguardo che va da [param da] a [param a] gradi: le compilazioni.
func _guarda(fase: String, da: float, a: float, n: int, yaw: float, piedi: Vector3) -> void:
	var prima := _info()
	var primo_dentro := -1
	for i in n:
		var pitch := lerpf(da, a, float(i) / maxf(n - 1, 1))
		g.teleport(piedi, yaw, deg_to_rad(pitch))
		await get_tree().process_frame
		var ora := _info()
		var v := _in_vista()
		if v[0] and primo_dentro < 0:
			primo_dentro = i
			print("PIPELINE %s: il guanto entra nella vista a %.0f° (vertici nello schermo %d)" % [fase, pitch, v[1]])
		var diff := []
		for k in 5:
			if ora[k] != prima[k]:
				diff.append("%s %d" % [TIPI[k], ora[k] - prima[k]])
				_totali[fase + " " + TIPI[k]] = int(_totali.get(fase + " " + TIPI[k], 0)) + ora[k] - prima[k]
		if not diff.is_empty():
			print("PIPELINE %s: fotogramma %d a %.0f°: %s (guanto nella vista %s, vertici nello schermo %d)" % [fase, i, pitch,
					", ".join(diff), v[0], v[1]])
		prima = ora
	if primo_dentro < 0:
		print("PIPELINE %s: il guanto non entra mai nella vista" % fase)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var dove: String = a[1] if a.size() > 1 else "tunnel"
	var versione: String = a[2] if a.size() > 2 else "nuovo"
	var riscalda := not (a.size() > 3 and a[3] == "senza_riscaldamento")
	# "nascondi_guanto" / "nascondi_lancia": a 90° il guanto (o tutta la lancia in mano) nascosto, per sapere di chi sono
	# le compilazioni guardando in basso
	var nascondi: String = a[3].trim_prefix("nascondi_") if a.size() > 3 and a[3].begins_with("nascondi_") else ""
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	print("PIPELINE: %s, guanto %s, riscaldamento dell'avvio %s, renderer %s" % [dove, versione, riscalda, RenderingServer.get_video_adapter_name()])
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(0, 50, 0)
	cam.look_at(Vector3(0, 100, 1))
	if riscalda:
		var r := RiscaldamentoShader.new()
		add_child(r)
		var t0 := Time.get_ticks_msec()
		while not r.concluso and Time.get_ticks_msec() - t0 < 1500000:
			await get_tree().process_frame
		print("PIPELINE: riscaldamento dell'avvio finito %s in %.0f s, contatori %s" % [r.concluso, (Time.get_ticks_msec() - t0) / 1000.0, _info()])
	var sala: SalaSottomarino = null
	var o: ObloLei = null
	if dove == "tunnel":
		sala = SalaSottomarino.new()
		sala.name = "SalaSottomarino"
		add_child(sala)
		await sala.costruisci_a_pezzi()
		for i in 30:
			await get_tree().process_frame
		print("PIPELINE: tunnel costruito e riscaldato, contatori %s" % [_info()])
	else:
		o = ObloLei.new()
		o.zona = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
		add_child(o)
		o.set_process(false)
		for i in 10:
			await get_tree().process_frame
	# il giocatore vero con la lancia (il guanto col materiale di prima, per controllo, prima del primo disegno)
	g = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(g)
	await get_tree().process_frame
	var rig := g.water_pack.lance_rig
	if versione == "vecchio" and rig and "mani_col_materiale_del_modello" in rig:
		rig.set(&"mani_col_materiale_del_modello", false)
	g.water_pack.set_equipped(true, false)
	g.water_pack.set_tank_amount(g.water_pack.tank_capacity)
	g.input_enabled = true
	(g.find_children("*", "Camera3D", true, false)[0] as Camera3D).make_current()
	Grafica.imposta("fov", 62.0)
	_trova_guanto()
	var mat := guanto.get_active_material(0) if guanto else null
	print("PIPELINE: guanto %s, materiale %s (%s), albedo %s" % [guanto != null, mat.resource_name if mat else "-", mat.get_class() if mat else "-",
			(mat as BaseMaterial3D).albedo_texture.get_image().get_pixel(0, 0) if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture else ((mat as BaseMaterial3D).albedo_color if mat is BaseMaterial3D else "-")])
	var piedi: Vector3
	var yaw := 0.0
	if dove == "tunnel":
		var s0 := 133.0
		piedi = sala._al(sala.punto(s0), sala.destra(s0), Vector2(-(sala.canale + sala.banchina * 0.5), sala.piano + 0.1))
		var avanti := sala.direzione(s0)
		yaw = atan2(-avanti.x, -avanti.z)
	else:
		var occhi_y := 1.6
		var davanti := o.centro_vetro() + o.normale() * 2.5
		piedi = davanti - Vector3.UP * occhi_y + Vector3.UP * 0.2
		var dir := o.centro_vetro() - davanti
		yaw = atan2(-dir.x, -dir.z)
	g.teleport(piedi, yaw, 0.0)
	g.set_physics_process(false)
	# la lancia in vista, lo sguardo dritto: la canna si compila qui
	await _guarda("dritto, prima", 0.0, 0.0, 40, yaw, piedi)
	if dove == "oblo":
		# lei compare, preparata fuori vista come negli oblò leggeri; la sua luce rosa prende la lancia
		o._mostra()
		o.lei.visible = false
		await RiscaldamentoShader.disegna_a_pezzi(o.lei, get_viewport())
		for i in 4:
			await get_tree().process_frame
		o.lei.visible = true
		await _guarda("lei compare", 0.0, 0.0, 20, yaw, piedi)
	await _guarda("in basso a 62°", 0.0, -89.0, 60, yaw, piedi)
	await _guarda("su a 62°", -89.0, 0.0, 30, yaw, piedi)
	Grafica.imposta("fov", 90.0)
	if nascondi == "guanto" and guanto:
		guanto.visible = false
		print("PIPELINE: a 90° il guanto è nascosto")
	elif nascondi == "lancia":
		g.water_pack.view_model.visible = false
		print("PIPELINE: a 90° la lancia in mano (col guanto) è nascosta")
	await _guarda("dritto a 90°", 0.0, 0.0, 20, yaw, piedi)
	await _guarda("in basso a 90°", 0.0, -89.0, 60, yaw, piedi)
	await _guarda("su a 90°", -89.0, 0.0, 30, yaw, piedi)
	Grafica.imposta("fov", 62.0)
	print("PIPELINE: RISULTATO %s, guanto %s: %s" % [dove, versione, _totali if not _totali.is_empty() else "nessuna compilazione"])
	get_tree().quit()
