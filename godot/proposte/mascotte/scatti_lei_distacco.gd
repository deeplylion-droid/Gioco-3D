extends "res://proposte/mascotte/scatti_lei_oblo.gd"
## Scatti dal motore del distacco di lei da un oblò (la scena di scatti_lei_oblo.gd), prima e dopo la correzione della
## palpebra: "prima" con la vecchia dissolvenza (la trasparenza dei nodi, da ObloLei.DISSOLVE_DA della durata alla
## fine), "dopo" con lo scuro fino al nero (ObloLei._scurisci). Per ogni posa tre scatti dagli occhi del giocatore e
## uno da vicino sull'occhio e la palpebra, alle stesse frazioni del distacco.
## Uso (sotto render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --script res://tests/run.gd -- res://proposte/mascotte/scatti_lei_distacco.gd <cartella> \
##     prima|dopo [posa,posa]

## le frazioni del distacco degli scatti (dalla posa sul vetro alla fine)
const FRAZIONI := [0.5, 0.65, 0.8]
const VICINO := 0.65

var _modo := "dopo"
var _oblo: ObloLei
var _lo: LeiOblo
var _t := 0.0
var _d := 1.0


func _scurezza() -> float:
	return clampf((_t / _d - ObloLei.DISSOLVE_DA) / (1.0 - ObloLei.DISSOLVE_DA), 0.0, 1.0)


func _avanza_fino(frazione: float) -> void:
	while _t / _d < frazione:
		await get_tree().physics_frame
		_t += 1.0 / 30.0
		_applica()


func _applica() -> void:
	var x := _scurezza()
	if _modo == "prima":
		for g in _oblo._parti_lei():
			(g as GeometryInstance3D).transparency = x
	else:
		_oblo._scurisci(x)


## Lo scatto senza far andare avanti il distacco (lei ferma per i fotogrammi dello scatto).
func _scatta_fermo(nome: String) -> void:
	_lo.lei.process_mode = Node.PROCESS_MODE_DISABLED
	_lo.process_mode = Node.PROCESS_MODE_DISABLED
	await _scatta(nome)
	_lo.lei.process_mode = Node.PROCESS_MODE_INHERIT
	_lo.process_mode = Node.PROCESS_MODE_INHERIT


func _run() -> void:
	Game.pause_on_focus_loss = false
	var args := OS.get_cmdline_user_args()
	_modo = args[2] if args.size() > 2 else "dopo"
	var solo: PackedStringArray = args[3].split(",") if args.size() > 3 else PackedStringArray()
	var radice := Node3D.new()
	add_child(radice)
	_scena(radice)
	var giocatore := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	radice.add_child(giocatore)
	giocatore.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.player = giocatore
	_lo = LeiOblo.new()
	radice.add_child(_lo)
	# (fuori dall'albero: serve solo per lo scuro, sulle stesse copie dei materiali del gioco)
	_oblo = ObloLei.new()
	_oblo.lei = _lo
	for i in 5:
		await get_tree().process_frame
	for posa: String in ["schiacciata", "sbircia", "capovolta", "occhio"]:
		if not solo.is_empty() and not posa in solo:
			continue
		giocatore.global_position = GIOCATORE[posa]
		var occhi: Vector3 = GIOCATORE[posa] + Vector3.UP * 1.6
		giocatore.camera.current = true
		giocatore.camera.look_at_from_position(occhi, CENTRO, Vector3.UP)
		_lo.mostra(CENTRO, Vector3.BACK, posa)
		_oblo._scuri.clear()
		_oblo._copie_scure()
		_oblo._scurisci(0.0)
		for g in _oblo._parti_lei():
			(g as GeometryInstance3D).transparency = 0.0
		for i in (120 if posa == "occhio" else 45):
			await get_tree().physics_frame
		var ap := _lo.lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
		_d = ap.get_animation(StringName("inseguimento/oblo_%s_stacca" % posa)).length
		_t = 0.0
		_lo.stacca()
		for k in FRAZIONI.size():
			await _avanza_fino(FRAZIONI[k])
			await _scatta_fermo("%s_%s_%d" % [posa, _modo, k + 1])
			if is_equal_approx(FRAZIONI[k], VICINO):
				# da vicino: l'occhio e la palpebra, dal corridoio
				var cam2 := Camera3D.new()
				radice.add_child(cam2)
				cam2.fov = 22.0
				var occhio := _lo.get_eye_position()
				cam2.look_at_from_position(Vector3(occhio.x, occhio.y + 0.05, 0.9), occhio, Vector3.UP)
				cam2.current = true
				await _scatta_fermo("%s_%s_vicino" % [posa, _modo])
				cam2.queue_free()
				giocatore.camera.current = true
		while _lo.in_stacca():
			await get_tree().physics_frame
		print("SCATTI ", posa)
	get_tree().quit(0)
