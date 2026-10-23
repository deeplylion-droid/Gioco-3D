extends Node
## Video dal motore del tuffo di lei nella fossa (tappa 8): la spruzzi in faccia con lo zaino e si tuffa. Per
## confrontare il tuffo prima e dopo il movimento secondario di tentacoli e campana (MorbidezzaLei).
##   camera "giocatore": dalla camera del giocatore, a 6,5 m da lei, che la spruzza;
##   camera "vicino": una camera ferma a 3,6 m di lato dalla fossa, all'altezza di lei, che guarda il tuffo.
##   "prima": senza il movimento secondario (Engine meta morbidezza_spenta); "dopo": com'è nel gioco.
## Stampa "INIZIO frame N" quando parte la scaletta. Durata 6,5 s (la spruzzi a 2,5 s).
## Uso (sotto /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --write-movie /tmp/x.avi --script res://tests/run.gd -- res://tests/video_tuffo.gd <prima|dopo> <giocatore|vicino> [preset]
## Il preset di serie è "medio": con "alto" la sala su llvmpipe supera la memoria della macchina (pipeline).

const LEVEL := "res://scenes/sala_principale.tscn"
const RISCALDA := 60
const DURATA := 6.5
## Quando la spruzzi (s): prima un paio di secondi di lei affacciata.
const SPRUZZO := 2.5

var versione := "dopo"
var camera := "giocatore"
var preset := "medio"
var p: Player
var lei: LeiSbuca
var _cam: Camera3D
var _f := -RISCALDA
var _partito := false
var _costi: Array = []


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		versione = args[1]
	if args.size() > 2:
		camera = args[2]
	if args.size() > 3:
		preset = args[3]
	if versione == "prima":
		Engine.set_meta(&"morbidezza_spenta", true)
	AudioLoop.forza_riproduzione(true)
	_avvia.call_deferred()


func _avvia() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(preset)
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 1)
	# la sala senza le parti che dall'area bimbi non si vedono, già nel file: su llvmpipe le texture si espandono
	# e la sala intera supera la memoria al caricamento (tests/scena_ridotta.gd)
	var ridotta: String = load("res://tests/scena_ridotta.gd").riduci(LEVEL, ["Interni", "Tecnici", "Risalita",
		"Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Polaroid", "Sala/Dettagli", "Sala/TorreScivoli", "Gioco/EnigmaAcquari", "Atmosfera"])
	var level := (load(ridotta) as PackedScene).instantiate()
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
	for v in lei.vasche:
		var t := v as WaterTank
		t.fill = clampf((lei.livello_pieno - t.get_floor_global_y()) / t.inner_size.y, 0.0, t.max_fill)
	lei.distanza_presa = 0.0
	await get_tree().physics_frame
	lei.call(&"_affaccia")
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(20.0)
	# a 6,5 m davanti a lei, un po' di lato (dentro la sala)
	var testa := _testa()
	var dir := lei.punto_sbuca.global_basis.z.rotated(Vector3.UP, deg_to_rad(25.0))
	dir.y = 0.0
	dir = dir.normalized()
	var da := Vector3(testa.x, 1.0, testa.z)
	var colpo := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(da, da + dir * 6.5, Layers.WORLD))
	var dist := 6.5 if colpo.is_empty() else maxf(da.distance_to(colpo.position) - 0.6, 3.0)
	var piedi := testa + dir * dist
	piedi.y = 0.0
	p.teleport(piedi, 0.0, 0.0)
	p.look_at_point(testa + Vector3(0.0, 0.6, 0.0))
	if camera == "vicino":
		# di lato alla fossa, alla sua destra (il tuffo va da quella parte), all'altezza della testa
		_cam = Camera3D.new()
		_cam.fov = 60.0
		level.add_child(_cam)
		var lato := lei.punto_sbuca.global_basis.x
		var avanti := lei.punto_sbuca.global_basis.z
		var occhio := testa + avanti * 2.2 + lato * 2.2 + Vector3(0, 0.3, 0)
		_cam.look_at_from_position(occhio, testa + lato * 0.8 + Vector3(0, -0.9, 0))
		_cam.current = true
	set_process(true)


func _testa() -> Vector3:
	return lei.punto_sbuca.global_transform * Vector3(0.0, 1.63, 1.8)


func _process(_delta: float) -> void:
	if p == null:
		return
	_f += 1
	if _f == 0:
		print("INIZIO frame ", Engine.get_frames_drawn())
	var t := _f / 30.0
	if not _partito:
		p.look_at_point(_testa() + Vector3(0.0, 0.6, 0.0))
	if t >= SPRUZZO and not _partito:
		_partito = true
		Input.action_press(&"spray")
	elif _partito:
		if lei.fase != LeiSbuca.Fase.GUARDA and Input.is_action_pressed(&"spray"):
			Input.action_release(&"spray")
	var m = lei.get(&"_morbidezza")
	if m and is_instance_valid(m) and m.durata_usec > 0:
		_costi.append(m.durata_usec)
	if t >= DURATA:
		if not _costi.is_empty():
			_costi.sort()
			var somma := 0.0
			for c in _costi:
				somma += c
			print("COSTO morbidezza (renderer software, %d fotogrammi): medio %.2f ms, mediano %.2f ms, massimo %.2f ms" % [_costi.size(), somma / _costi.size() / 1000.0, _costi[_costi.size() / 2] / 1000.0, _costi.back() / 1000.0])
		print("FINE")
		get_tree().quit()
