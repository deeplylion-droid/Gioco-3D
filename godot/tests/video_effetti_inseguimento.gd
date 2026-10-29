extends Node
## Video dal motore degli effetti dell'inseguimento nel tunnel (EffettiInseguimento), dagli occhi del giocatore vero
## sulla banchina sinistra (da s 88, dopo il crollo, fino a prima della galleria): corre con lei dietro (la sua luce
## rosa lo supera sulle pareti e sull'acqua), rallenta e lei si avvicina (i bordi si scuriscono), si gira camminando
## all'indietro e lei morde (la camera trema), la spruzza in faccia e lei si ritrae, poi si rigira e corre.
## I comandi sono quelli veri (move_*, sprint, spray), con la forza giusta per seguire la banchina.
## Con "prima" gli effetti sono spenti: stessa partita (stesso seme), per gli scatti prima/dopo nello stesso istante.
## Stampa le pipeline compilate durante l'inseguimento (atteso: nessuna) e salva gli scatti in [cartella].
## Uso (sotto /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 [--write-movie /tmp/x.avi] --script res://tests/run.gd -- res://tests/video_effetti_inseguimento.gd \
##     <prima|dopo> <cartella> [preset]

const PLAYER := "res://scenes/player/player.tscn"
const S0 := 88.0
const DIETRO := 15.0

var versione := "dopo"
var cartella := "user://"
var preset := "medio"
var sala: SalaSottomarino
var p: Player
var fase := ""
var _t := 0.0
var _fase_t := 0.0
var _f := 0
var _s := S0
var _base := []
var _morsi := 0
var _respinta := false
var _scatti := {}
var _yaw_da := 0.0
var _girata := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		versione = args[1]
	if args.size() > 2:
		cartella = args[2]
	if args.size() > 3:
		preset = args[3]
	seed(25102026)
	_avvia.call_deferred()


func _info() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _avvia() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(preset)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	add_child(env)
	p = (load(PLAYER) as PackedScene).instantiate()
	add_child(p)
	GameState.player = p
	p.teleport(Vector3(0, 50, 0), 0.0, 1.2)          # (mentre si costruisce: guarda il cielo vuoto)
	p.set_physics_process(false)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	sala = SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	await sala.costruisci_a_pezzi()
	for i in 60:
		await get_tree().process_frame
	if versione == "prima":
		sala.effetti.process_mode = Node.PROCESS_MODE_DISABLED
		sala.effetti.luce.visible = false
		sala.effetti.bordi.visible = false
	sala.lei_morde.connect(func(): _morsi += 1)
	sala.lei_respinta.connect(func(): _respinta = true)
	p.water_pack.tank_amount = p.water_pack.tank_capacity
	p.set_physics_process(true)
	p.teleport(_banchina(S0), 0.0, 0.0)
	p.look_at_point(_banchina(S0 + 6.0) + Vector3.UP * 1.6)
	sala.attiva_tunnel()
	sala._s_bersaglio = S0
	sala.insegui_da(S0 - DIETRO)
	_base = _info()
	print("PRONTO pipeline ", _base, " frame ", Engine.get_frames_drawn())
	fase = "prepara"


func _banchina(s: float) -> Vector3:
	var q := sala.punto(s) - sala.destra(s) * (sala.canale + sala.banchina * 0.5)
	return Vector3(q.x, sala.piano + 0.05, q.z)


func _process(delta: float) -> void:
	if fase == "" or fase == "fine":
		return
	_t += delta
	_fase_t += delta
	var gap := sala._s_bersaglio - sala.lei_s
	_s = sala._s_bersaglio
	var occhio := sala.lei.get_eye_position()
	match fase:
		"prepara":
			# lei risale dal canale dietro (fuori dal video): si comincia quando insegue
			_muovi(true)
			_guarda_avanti()
			if sala.lei_stato == SalaSottomarino.Lei.INSEGUE and _fase_t > 1.5:
				_cambia("corre")
				print("INIZIO frame ", Engine.get_frames_drawn())
		"corre":
			_muovi(true)
			_guarda_avanti()
			if _fase_t >= 3.0:
				_scatto("luce_avanti")
			if _fase_t >= 6.0:
				_cambia("cammina")
		"cammina":
			_muovi(false)
			_guarda_avanti()
			if gap < 9.0:
				_scatto("bordi_avanti")
				_cambia("si_gira")
				_yaw_da = p.yaw
		"si_gira":
			_muovi(false)
			var k := smoothstep(0.0, 0.9, _fase_t)
			var d := occhio - p.get_eye_position()
			var yaw_a := atan2(-d.x, -d.z)
			p.set_look(lerp_angle(_yaw_da, yaw_a, k), lerpf(0.0, atan2(d.y, Vector2(d.x, d.z).length()), k))
			if _fase_t >= 0.9:
				_cambia("indietro")
		"indietro":
			_muovi(false)
			p.look_at_point(occhio)
			if gap < 5.6:
				_scatto("morso")
			if gap < 4.6 or _morsi >= 3:
				_cambia("spruzza")
		"spruzza":
			_muovi(false)
			p.look_at_point(occhio)
			Input.action_press("spray")
			if _respinta or _fase_t > 2.5:
				Input.action_release("spray")
				_cambia("guarda")
		"guarda":
			_muovi(false)
			p.look_at_point(occhio)
			if _fase_t > 1.0:
				_scatto("ritrae")
			if _fase_t > 2.0:
				_yaw_da = p.yaw
				_cambia("riparte")
		"riparte":
			_muovi(true)
			var k := smoothstep(0.0, 0.8, _fase_t)
			var a := _banchina(_s + 6.0) + Vector3.UP * 1.6 - p.get_eye_position()
			p.set_look(lerp_angle(_yaw_da, atan2(-a.x, -a.z), k), lerpf(p.pitch, 0.0, k))
			if _fase_t > 4.0:
				_cambia("fine")
				_finisci()
	if fase != "prepara" and fase != "fine":
		_f += 1
		if _f % 15 == 0:
			var ora := _info()
			print("t %.1f fase %s gap %.1f bordi %.2f luce %.1f morsi %d s %.1f pipeline +%d/+%d" % [_f / 30.0, fase, gap,
					sala.effetti.bordi.modulate.a, sala.effetti.luce.light_energy if sala.effetti.luce.visible else 0.0,
					_morsi, _s, ora[0] - _base[0], ora[1] - _base[1]])
	if sala.lei_stato == SalaSottomarino.Lei.PRESA:
		print("PRESO (non doveva)")
		_finisci()


func _cambia(f: String) -> void:
	print("FASE ", f, " t %.2f frame %d" % [_f / 30.0, Engine.get_frames_drawn()])
	fase = f
	_fase_t = 0.0


## Lungo la banchina, [param corre]: sprint. I comandi veri, con la forza per andare verso la banchina 4 m avanti,
## qualunque sia lo sguardo.
func _muovi(corre: bool) -> void:
	var dove := _banchina(_s + 4.0) - p.global_position
	dove.y = 0.0
	var loc := p.get_aim_basis().inverse() * dove.normalized()
	loc.y = 0.0
	loc = loc.normalized()
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	if loc.x < 0.0:
		Input.action_press("move_left", -loc.x)
	else:
		Input.action_press("move_right", loc.x)
	if loc.z < 0.0:
		Input.action_press("move_forward", -loc.z)
	else:
		Input.action_press("move_back", loc.z)
	if corre:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


func _guarda_avanti() -> void:
	var a := _banchina(_s + 8.0) + Vector3.UP * 1.5 - p.get_eye_position()
	var yaw_a := atan2(-a.x, -a.z)
	p.set_look(lerp_angle(p.yaw, yaw_a, 0.15), lerpf(p.pitch, -0.05, 0.15))


func _scatto(nome: String) -> void:
	if _scatti.has(nome):
		return
	_scatti[nome] = _f
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var file := cartella.path_join("%s_%s.png" % [nome, versione])
	img.save_png(file)
	print("SCATTO ", nome, " t %.2f -> %s" % [_f / 30.0, file])
	if OS.get_environment("FINO") == nome:
		get_tree().quit()


func _finisci() -> void:
	fase = "fine"
	for a in ["move_left", "move_right", "move_forward", "move_back", "sprint", "spray"]:
		Input.action_release(a)
	var ora := _info()
	print("PIPELINE durante l'inseguimento: disegno +%d, specializzazione +%d" % [ora[0] - _base[0], ora[1] - _base[1]])
	print("FINE durata %.1f s" % (_f / 30.0))
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
