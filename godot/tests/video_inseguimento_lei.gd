extends Node
## Video dal motore di lei nell'inseguimento (scena di prova scenes/test/inseguimento_prova.tscn), dalla camera del
## giocatore, per confrontare prima e dopo il movimento secondario di tentacoli e campana (MorbidezzaLei):
##   "vasca_0": il giocatore nella vasca 1, lei sale accanto e incombe;
##   "sb1": il giocatore nel bacino, lei sbuca dal pozzo di scarico e lo guarda.
##   "prima": senza la morbidezza (Engine meta morbidezza_spenta); "dopo": com'è nel gioco.
## Lei sale a 0,8 s; il video dura 5 s.
## Uso (sotto /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --write-movie /tmp/x.avi --script res://tests/run.gd -- res://tests/video_inseguimento_lei.gd <prima|dopo> <vasca_0|sb1> [preset]

const LEVEL := "res://scenes/test/inseguimento_prova.tscn"
const RISCALDA := 60
const DURATA := 5.0

var versione := "dopo"
var dove := "vasca_0"
var preset := "medio"
var p: Player
var sala: SalaInseguimento
var _f := -RISCALDA
var _partito := false
var _costi: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		versione = args[1]
	if args.size() > 2:
		dove = args[2]
	if args.size() > 3:
		preset = args[3]
	if versione == "prima":
		Engine.set_meta(&"morbidezza_spenta", true)
	_avvia.call_deferred()


func _avvia() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(preset)
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	p = GameState.player
	sala = get_tree().current_scene.get_node("SalaInseguimento") as SalaInseguimento
	sala.tempo_presa = 1e6
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.stand_eye_height = 1.7
	if dove == "sb1":
		# nel bacino, 4,5 m a sud del pozzo (assi di Blender: y)
		var r: Array = sala.dati["pozzo"]["rett"]
		var c := SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0 - 4.5, float(sala.dati["bacino"]["fondo"])])
		p.teleport(c + Vector3.UP * 0.05, 0.0, 0.0)
	else:
		# nella vasca 1, verso il lato sud, così il tubo giallo sul bordo nord non copre lei
		var v: Dictionary = sala.dati["vasche"][0]
		var r: Array = v["rett"]
		p.teleport(SalaInseguimento.b([r[0] + 2.5, r[1] + 1.2, float(v["fondo"])]) + Vector3.UP * 0.05, 0.0, 0.0)
	set_process(true)


func _testa() -> Vector3:
	if sala.lei.visible:
		var o: Vector3 = sala.lei.get_eye_position()
		if o != Vector3.ZERO:
			return o
	if dove == "sb1":
		var r: Array = sala.dati["pozzo"]["rett"]
		return SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(sala.dati["pozzo"]["bordo"]) + 1.0])
	return sala.call(&"_posto_vasca", 0) + Vector3.UP * 3.2


func _process(_delta: float) -> void:
	if p == null or sala == null:
		return
	_f += 1
	if _f == 0:
		print("INIZIO frame ", Engine.get_frames_drawn())
	var t := _f / 30.0
	p.look_at_point(_testa())
	if t >= 0.8 and not _partito:
		_partito = true
		if dove == "sb1":
			sala.call(&"_lei_sale", "sb1", sala.call(&"_posto_sb1"), 1.3)
		else:
			sala.call(&"_lei_sale", "vasca_0", sala.call(&"_posto_vasca", 0), 1.6)
	var m := MorbidezzaLei.su(sala.lei) if sala.lei else null
	if m and m.durata_usec > 0:
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
