extends Node
## Collaudo della morbidezza (correzioni del 29 ottobre): lei che sbuca dalla fossa nella sala (LeiSbuca, tappa 8),
## dalla camera del giocatore 7 m davanti (come in test_morbidezza_sbuca), a 60 fps: salva ogni fotogramma della
## salita e del primo secondo affacciata in <cartella>/<nome>_NNNN.jpg e stampa i fotogrammi dove un punto dei
## tentacoli va più veloce (lo scatto a 35 m/s di test_morbidezza_sbuca a 60 fps), per farne poi i fogli.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scatti_lei_sbuca.gd <cartella> <nome> [preset]
## (con la sala principale il processo arriva a 12-13 GB: solo con 13,5 GB liberi)

const LEVEL := "res://scenes/sala_principale.tscn"

var _cartella := ""
var _nome := "sbuca"


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	# (SCATTI_LEGGERO=1: niente preparazione degli effetti e degli oblò, che sul renderer software si prende la memoria)
	if OS.has_environment("SCATTI_LEGGERO"):
		Engine.set_meta(&"prepara_effetti_spento", true)
		Engine.set_meta(&"oblo_senza_preparazione", true)
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_sbuca"
	_nome = a[2] if a.size() > 2 else "sbuca"
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(OS.get_cmdline_user_args()[3] if OS.get_cmdline_user_args().size() > 3 else "medio")
	# per parti, come tests/scatti_tappa8.gd: con tutto, sul renderer software, la memoria non basta. Si tolgono prima
	# del primo fotogramma gli interni e gli ambienti tecnici (dalla fossa non si vedono); SCATTI_TOGLI per cambiarli,
	# uguale nei prima e nei dopo
	# (senza la cache: tolte le parti, le loro risorse si liberano davvero, la scena caricata non le tiene)
	var pacchetto := ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var level := pacchetto.instantiate()
	pacchetto = null
	var togli := OS.get_environment("SCATTI_TOGLI").split(",", false)
	if togli.is_empty():
		togli = PackedStringArray(["Interni", "Tecnici/Ambienti/CameraOnde", "Tecnici/Ambienti/SalaPompe"])
	for percorso in togli:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
			print("tolto ", percorso)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	for i in 3000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var lei := level.get_node(^"Gioco/LeiSbuca") as LeiSbuca
	for v in lei.vasche:
		var t := v as WaterTank
		t.fill = clampf((lei.livello_pieno - t.get_floor_global_y()) / t.inner_size.y, 0.0, t.max_fill)
	lei.distanza_presa = 0.0
	var p := GameState.player
	p.teleport(lei.punto_sbuca.global_position + lei.punto_sbuca.global_basis.z * 7.0 + Vector3(0, 0.1, 0), 0.0, 0.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.camera.make_current()
	# (il mondo intorno caricato e disegnato prima di cominciare)
	await Game.aspetta_caricamenti(level)
	for i in 120:
		await get_tree().process_frame
	lei.call(&"_ricomincia")
	for i in 3:
		await get_tree().process_frame
	var m := MorbidezzaLei.su(lei.medusa)
	DirAccess.make_dir_recursive_absolute(_cartella)
	lei.call(&"_sbuca")
	var durata := lei.durata_sbuca + 1.0
	var t := 0.0
	var f := 0
	var prima := PackedVector3Array()
	var veloci: Array = []
	while t < durata:
		# lo sguardo sul punto dove sale (un po' sopra la fossa), la camera come la girerebbe il giocatore
		p.look_at_point(lei.punto_sbuca.global_position + Vector3.UP * 1.6)
		p.camera.global_transform = p.get_aim_transform()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(_cartella.path_join("%s_%04d.jpg" % [_nome, f]), 0.9)
		var pt := m.punti() if m else PackedVector3Array()
		if pt.size() == prima.size() and f > 0:
			var mx := 0.0
			for i in pt.size():
				mx = maxf(mx, pt[i].distance_to(prima[i]) / get_process_delta_time())
			veloci.append([mx, f])
		prima = pt
		await get_tree().process_frame
		t += get_process_delta_time()
		f += 1
	veloci.sort_custom(func(a, b): return a[0] > b[0])
	print("FOTOGRAMMI %d; i più veloci (m/s, fotogramma): %s" % [f, str(veloci.slice(0, 8))])
	print("FINE")
	get_tree().quit()
