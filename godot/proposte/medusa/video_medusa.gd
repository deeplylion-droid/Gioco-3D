extends Node
## PROPOSTA (non usata dal gioco): video brevi dal motore per i riscontri 3 e 4 della v0.3.2, nella
## sala principale al buio (tappa 8), con lei affacciata alla fossa dell'area bimbi.
##   jumpscare: sei a 2,8 m da lei; a 1,0 s ti prende (LeiSbuca._prendi, la DeathSequence del
##     gioco) e, nelle versioni A e B, sopra c'è jumpscare.gd (glitch, scosse, urlo). Fine a 3,0 s.
##   esplosione: sei a 5 m da lei; a 1,0 s scivola sotto (LeiSbuca._scivola) e, nelle versioni A e
##     B, parte esplosione.gd. Fine a 4,5 s.
## Stampa "INIZIO frame N" quando parte la scaletta (per tagliare il video).
## Uso (con Movie Maker, l'audio viene registrato):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --write-movie /tmp/x.avi --script res://tests/run.gd -- res://proposte/medusa/video_medusa.gd \
##     <jumpscare|esplosione> <A|B|attuale> [foto: t1,t2,... (scatti invece del video)] [cartella]

const LEVEL := "res://scenes/sala_principale.tscn"
const JUMPSCARE := preload("res://proposte/medusa/jumpscare.gd")
const ESPLOSIONE := preload("res://proposte/medusa/esplosione.gd")
const RISCALDA := 60

var tipo := "jumpscare"
var versione := "A"
var foto := PackedFloat32Array()
var cartella := "/tmp/claude-0/medusa_foto"
var p: Player
var lei: LeiSbuca
var _f := -RISCALDA
var _partito := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		tipo = args[1]
	if args.size() > 2:
		versione = args[2]
	if args.size() > 3 and args[3] != "video":
		for t in args[3].split(","):
			foto.append(float(t))
	if args.size() > 4:
		cartella = args[4]
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
	# Come tests/scatti_tappa8.gd con SCATTI_TOGLI=Interni,Tecnici: con tutto la memoria non basta.
	for percorso in ["Interni", "Tecnici"]:
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
	lei.attesa = 1000.0
	await get_tree().physics_frame
	lei.call(&"_affaccia")
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
		piedi = testa + avanti.rotated(Vector3.UP, deg_to_rad(25.0)) * 6.5
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
			if versione != "attuale":
				var j := JUMPSCARE.new()
				j.set(&"versione", versione)
				get_tree().root.add_child(j)
		else:
			lei.call(&"_scivola")
			if versione != "attuale":
				var e := ESPLOSIONE.new()
				e.set(&"versione", versione)
				get_tree().current_scene.add_child(e)
				var centro := lei.punto_sbuca.global_transform * Vector3(0.0, 0.0, 1.5)
				e.call(&"scoppia", centro, lei.call(&"_pelo"), lei, lei.acque)
	elif tipo == "esplosione" and _partito:
		_guarda()
	for x in foto:
		if absf(t - x) < 0.5 / 30.0:
			_scatto.call_deferred(x)
	var fine := 3.0 if tipo == "jumpscare" else 4.5
	if t >= fine or (not foto.is_empty() and t > foto[foto.size() - 1] + 0.1):
		print("FINE")
		get_tree().quit()


func _scatto(x: float) -> void:
	await RenderingServer.frame_post_draw
	var nome := "%s_%s_%03.1f.jpg" % [tipo, versione, x]
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome), 0.9)
	print("salvato ", nome)
