extends Node
## Video delle proposte del geyser (dopo la v0.3.5): come tests/video_lei.gd in modalità geyser, ma al posto del
## geyser di oggi (GeyserFossa) usa quello della proposta, e misura quanto costa ogni fotogramma (tempo della CPU,
## primitive disegnate, chiamate di disegno), prima e durante il geyser.
## Argomenti: <v1|v2|oggi> [angolo in gradi] [distanza in m, 0 = come video_lei] [fine in s] [foto: t1,t2,... o "video"] [cartella]
## Il resto com'era in video_lei.gd:
##   jumpscare: sei a 2,8 m da lei; a 1,0 s ti prende (LeiSbuca._prendi: DeathSequence con
##     JumpscareGlitch e il suo urlo). Fine a 3,0 s.
##   geyser: sei a 6,5 m da lei con lo zaino; a 1,0 s la spruzzi in faccia: appena il getto la colpisce
##     parte il geyser (GeyserFossa col boato) e lei sparisce. Fine a 4,5 s.
## Stampa "INIZIO frame N" quando parte la scaletta (per tagliare il video).
## Uso (con Movie Maker l'audio viene registrato):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --write-movie /tmp/x.avi --script res://tests/run.gd -- res://tests/video_lei.gd \
##     <jumpscare|geyser> [foto: t1,t2,... o "video"] [angolo in gradi rispetto a dove guarda lei] [cartella]

const LEVEL := "res://scenes/sala_principale.tscn"
const V1 := preload("res://proposte/geyser/geyser_mesh.gd")
const V2 := preload("res://proposte/geyser/geyser_flipbook.gd")
const RISCALDA := 60

var tipo := "geyser"
var versione := "v1"
var distanza := 0.0
var fine_s := 7.0
var _misure := {"prima": [], "durante": []}
var angolo := 25.0
var foto := PackedFloat32Array()
var cartella := "/tmp/claude-0/medusa_foto"
var p: Player
var lei: LeiSbuca
var _f := -RISCALDA
var _partito := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		versione = args[1]
	if args.size() > 2:
		angolo = float(args[2])
	if args.size() > 3:
		distanza = float(args[3])
	if args.size() > 4:
		fine_s = float(args[4])
	if args.size() > 5 and args[5] != "video":
		for t in args[5].split(","):
			foto.append(float(t))
	if args.size() > 6:
		cartella = args[6]
	DirAccess.make_dir_recursive_absolute(cartella)
	# Il sistema audio del gioco tace senza scheda audio: qui deve suonare per il video.
	AudioLoop.forza_riproduzione(true)
	_avvia.call_deferred()


func _avvia() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 1)
	var level := (load(LEVEL) as PackedScene).instantiate()
	# Come tests/scatti_tappa8.gd con SCATTI_TOGLI=Interni,Tecnici: con tutto la memoria non basta (qui anche
	# le polaroid e la medusa della vasca centrale, fuori inquadratura: col geyser in più si arrivava a 13,4 GB).
	for percorso in ["Interni", "Tecnici", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata", "Polaroid", "Vasca/Medusa"]:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	for i in 10:
		await get_tree().process_frame
	get_tree().paused = false
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for t in level.find_children("*", "Tempesta", true, false):
		(t as Tempesta).automatica = false
	p.stand_eye_height = 1.7
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	lei = level.get_node(^"Gioco/LeiSbuca") as LeiSbuca
	# Lei affacciata, l'acqua alta; non ti prende da sola e non scivola via prima del tempo.
	for v in lei.vasche:
		var t := v as WaterTank
		t.fill = clampf((lei.livello_pieno - t.get_floor_global_y()) / t.inner_size.y, 0.0, t.max_fill)
	lei.distanza_presa = 0.0
	if versione in ["v1", "v2"]:
		var g: Node3D = (V1 if versione == "v1" else V2).new()
		g.name = "Geyser"
		lei.add_child(g)
		lei._geyser = g
	await get_tree().physics_frame
	lei.call(&"_affaccia")
	if tipo == "geyser":
		if not p.has_item(&"zaino_pompa"):
			p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
		p.water_pack.set_equipped(true, false)
		p.water_pack.set_tank_amount(20.0)
	_mettiti()
	set_process(true)


func _testa() -> Vector3:
	return lei.punto_sbuca.global_transform * Vector3(0.0, 1.63, 1.8)


func _mettiti() -> void:
	var testa := _testa()
	var avanti := lei.punto_sbuca.global_basis.z
	var piedi: Vector3
	if tipo == "jumpscare":
		piedi = testa + avanti.rotated(Vector3.UP, deg_to_rad(20.0)) * 2.8
	else:
		# A 6,5 m, ma sempre dentro la sala: se in quella direzione c'è un muro ci si ferma prima.
		var dir := avanti.rotated(Vector3.UP, deg_to_rad(angolo))
		dir.y = 0.0
		dir = dir.normalized()
		var da := Vector3(testa.x, 1.0, testa.z)
		var colpo := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(da, da + dir * 6.5, Layers.WORLD))
		var dist := 6.5 if colpo.is_empty() else maxf(da.distance_to(colpo.position) - 0.6, 3.0)
		if distanza > 0.0:
			dist = minf(dist, distanza)
		piedi = testa + dir * dist
		print("camera a %.1f m, angolo %.0f" % [dist, angolo])
	piedi.y = 0.0
	p.teleport(piedi, 0.0, 0.0)
	_guarda()


func _guarda() -> void:
	if tipo == "jumpscare":
		p.look_at_point(_testa() + Vector3(0.0, -0.15, 0.0))
	else:
		p.look_at_point(_testa() + Vector3(0.0, 0.6, 0.0))


func _process(_delta: float) -> void:
	if p == null:
		return
	_f += 1
	if _f == 0:
		print("INIZIO frame ", Engine.get_frames_drawn())
	var t := _f / 30.0
	if not _partito:
		_guarda()
	if t >= 1.0 and not _partito:
		_partito = true
		if tipo == "jumpscare":
			lei.call(&"_prendi")
		else:
			# La nuova regola (v0.3.4): la spruzzi e se ne va.
			Input.action_press(&"spray")
	elif tipo == "geyser" and _partito:
		_guarda()
		if lei.fase != LeiSbuca.Fase.GUARDA and Input.is_action_pressed(&"spray"):
			Input.action_release(&"spray")
	for x in foto:
		if absf(t - x) < 0.5 / 30.0:
			_scatto.call_deferred(x)
	var g := lei.get_node_or_null(^"Geyser")
	var durante := g != null and g.has_method(&"in_corso") and bool(g.call(&"in_corso"))
	(_misure["durante" if durante else "prima"] as Array).append([Performance.get_monitor(Performance.TIME_PROCESS),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	var fine := fine_s
	if t >= fine or (not foto.is_empty() and t > foto[foto.size() - 1] + 0.1):
		for k in _misure:
			var v: Array = _misure[k]
			if v.is_empty():
				continue
			var cpu := 0.0
			var prim := 0.0
			var dc := 0.0
			for m in v:
				cpu = maxf(cpu, m[0]); prim = maxf(prim, m[1]); dc = maxf(dc, m[2])
			print("MISURA %s: %d fotogrammi, CPU massima %.1f ms, primitive massime %d, chiamate di disegno massime %d" % [k, v.size(), cpu * 1000.0, prim, dc])
		print("FINE")
		get_tree().quit()


func _scatto(x: float) -> void:
	await RenderingServer.frame_post_draw
	var nome := "%s_%03d_%03.1f.jpg" % [tipo, int(angolo), x]
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome), 0.9)
	print("salvato ", nome)
