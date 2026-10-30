extends Node
## Collaudo dell'agnellino del tunnel (BambinoGalleria) per la 0.3.17, dagli occhi del giocatore: chi gli corre dietro non
## lo deve mai veder sparire, nemmeno in parte (riscontro dell'utente sulla 0.3.16). Il tunnel costruito da solo, con
## l'ambiente della sala, come video_bambini_sfuggita.gd. Il giocatore lo muove questo script, e la camera e gli occhi del
## giocatore (quelli con cui il bambino decide se lo si vede) stanno alla stessa altezza, anche accucciati; lo sguardo gira
## al più di [constant GIRO] gradi al secondo, come col mouse.
## Nel fotogramma in cui sparisce il disegno si rifà con lui al suo posto, nella stessa posa, e senza: i pixel che cambiano
## sono quello che si sarebbe visto sparire (sparito_con.png, sparito_senza.png, e sparito_senza2.png per il rumore).
## Casi:
##   bocca, dentro: quelli di mascotte (allo sprint fino alla bocca e fermo a guardare dentro; dietro di lui fin fuori);
##   via: dietro di lui fin fuori dalla bocca in fondo, fermo a guardarlo, poi si gira piano dall'altra parte;
##   indietro: dietro di lui nella galleria, a un terzo si volta e torna alla bocca, poi guarda di nuovo dentro;
##   meta: accucciato al passo (1,7 m/s) nella galleria, fermo a metà per 3 s, poi riparte fin fuori e guarda dov'è andato;
##   lontano: lo guarda da dove compare, poi va alla bocca camminando e guarda dentro.
## Scrive i fotogrammi in <cartella>/fotogrammi e una riga per fotogramma in <cartella>/fotogrammi.csv.
## Uso: xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##        --fixed-fps 30 --script res://tests/run.gd -- res://tests/collaudo/collaudo_agnellino_tunnel.gd <caso> <cartella>

const SPRINT := 5.8
const CAMMINA := 3.4
const ACCUCCIATO := 1.7
const OCCHI := 1.6
const OCCHI_GIU := 0.92
## Gradi al secondo dello sguardo (il mouse, svelto).
const GIRO := 300.0
const DT := 1.0 / 30.0

var _p: Player
var _cartella := ""
var _n := 0
var _sala: SalaSottomarino
var _b: BambinoSfuggita
var _s0 := 0.0
var _s1 := 0.0
var _lato := 1.0
var _dentro := 0.0
var _qui := Vector3.ZERO
var _occhi := OCCHI
var _yaw := 0.0
var _pitch := 0.0
var _s_qui := 0.0
var _csv: FileAccess
var _sparito := -1
var _passati_prima := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var caso := a[1] if a.size() > 1 else "bocca"
	_cartella = a[2] if a.size() > 2 else "/tmp/agnellino_tunnel"
	DirAccess.make_dir_recursive_absolute(_cartella.path_join("fotogrammi"))
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.009
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	_p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(_p)
	GameState.player = _p
	_p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := _p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	_p.camera.make_current()
	_sala = SalaSottomarino.new()
	_sala.name = "SalaSottomarino"
	add_child(_sala)
	_sala.costruisci()
	_b = _sala.find_child("BambinoGalleria", true, false) as BambinoSfuggita
	var g: Dictionary = {}
	for o in _sala.ostacoli:
		if o["tipo"] == "galleria":
			g = o
			break
	_s0 = float(g["s"]) - SalaSottomarino.GALLERIA_BOCCA
	_s1 = float(g["s"]) + float(g["lungo"]) + SalaSottomarino.GALLERIA_BOCCA
	_lato = g["lato"]
	_dentro = _sala.muro + _sala.spessore + SalaSottomarino.GALLERIA_LARGA * 0.5
	print("galleria: bocca d'entrata da s=%.1f, bocca d'uscita fino a s=%.1f, lato %+.0f" % [_s0, _s1, _lato])
	# il giocatore lontano, girato dall'altra parte, mentre il bambino si prepara (a schermo nero nel gioco)
	_qui = _al(_s0 - 34.0, _sala.muro - 1.2)
	_s_qui = _s0 - 34.0
	_guarda_subito(_al(_s0 - 60.0, _sala.muro - 1.2) + Vector3.UP * OCCHI)
	_metti_camera()
	for i in 240:
		await get_tree().process_frame
	_csv = FileAccess.open(_cartella.path_join("fotogrammi.csv"), FileAccess.WRITE)
	_csv.store_line("n,t,stato,visibile,visto_da_lui,punti_passati,s_giocatore,u_giocatore,occhi,s_bambino,u_bambino,dist")
	var m := _sala.muro
	var banchina := [_tappa(_s0 - 30.0, m - 1.2, SPRINT), _tappa(_s0 - 0.6, m - 1.2, SPRINT), _tappa(_s0 + 0.6, m - 0.3, SPRINT)]
	var piano := []
	match caso:
		"bocca":
			piano = banchina + [_tappa(_s0 + 0.9, m + _sala.spessore, SPRINT), _ferma(12.0)]
		"dentro":
			piano = banchina + [_tappa(_s0 + 1.4, _dentro, SPRINT), _tappa(_s1 - 1.4, _dentro, SPRINT),
					_tappa(_s1 - 0.6, m - 0.3, SPRINT), _tappa(_s1 + 1.0, m - 1.1, SPRINT), _tappa(_s1 + 20.0, m - 1.2, SPRINT),
					_ferma(3.0)]
		"via":
			piano = banchina + [_tappa(_s0 + 1.4, _dentro, SPRINT), _tappa(_s1 - 1.4, _dentro, SPRINT),
					_tappa(_s1 - 0.6, m - 0.3, SPRINT), _tappa(_s1 + 1.0, m - 1.1, SPRINT), _tappa(_s1 + 4.0, m - 1.2, CAMMINA),
					_ferma(3.0), _girati(_al(_s1 - 20.0, m - 1.5) + Vector3.UP * OCCHI, 80.0, 6.0),
					_girati(_al(_s1 + 16.0, m - 1.2) + Vector3.UP * 0.8, 80.0, 4.0)]
		"indietro":
			var terzo := _s0 + (_s1 - _s0) / 3.0
			piano = banchina + [_tappa(_s0 + 1.4, _dentro, SPRINT), _tappa(terzo, _dentro, ACCUCCIATO),
					_girati(_al(_s0 - 10.0, _dentro) + Vector3.UP * OCCHI_GIU, GIRO, 0.6),
					_tappa(_s0 + 1.4, _dentro, ACCUCCIATO, "avanti"), _tappa(_s0 + 0.6, m - 0.3, ACCUCCIATO, "avanti"),
					_tappa(_s0 - 0.8, m - 1.2, CAMMINA, "avanti"), _ferma(2.0, "avanti"),
					_girati(_al(_s0 + 0.9, m + _sala.spessore) + Vector3.UP * 1.0, GIRO, 0.8),
					_tappa(_s0 + 0.9, m + _sala.spessore, CAMMINA), _girati(_al(_s1 - 2.0, _dentro) + Vector3.UP * 0.9, GIRO, 1.0),
					_ferma(4.0)]
		"meta":
			var meta := (_s0 + _s1) * 0.5
			piano = banchina + [_tappa(_s0 + 1.4, _dentro, ACCUCCIATO), _tappa(meta, _dentro, ACCUCCIATO), _ferma(3.0),
					_tappa(_s1 - 1.4, _dentro, ACCUCCIATO), _tappa(_s1 - 0.6, m - 0.3, ACCUCCIATO),
					_tappa(_s1 + 1.0, m - 1.1, CAMMINA), _tappa(_s1 + 3.0, m - 1.2, CAMMINA),
					_girati(_al(_s1 + 16.0, m - 1.2) + Vector3.UP * 0.8, 120.0, 4.0)]
		"lontano":
			piano = [_tappa(_s0 - 30.0, m - 1.2, SPRINT), _tappa(_s0 - 18.0, m - 1.2, SPRINT), _ferma(8.0),
					_tappa(_s0 - 0.6, m - 1.2, CAMMINA), _tappa(_s0 + 0.6, m - 0.3, CAMMINA),
					_tappa(_s0 + 0.9, m + _sala.spessore, CAMMINA), _girati(_al(_s1 - 2.0, _dentro) + Vector3.UP * 0.9, GIRO, 1.0),
					_ferma(6.0)]
	print("caso %s: %d tappe" % [caso, piano.size()])
	_qui = piano[0]["a"]
	_s_qui = _s0 - 30.0
	_guarda_subito(_al(_s0 - 10.0, m - 1.2) + Vector3.UP * OCCHI)
	var t := 0.0
	for tappa in piano:
		var fine := t + float(tappa.get("per", 60.0))
		while t < fine:
			var arrivato := _passo(tappa)
			await _fotogramma()
			t += DT
			_riga(t)
			if _sparito < 0 and _b.stato == BambinoSfuggita.Stato.FINITO:
				_sparito = _n - 1
				print("SPARITO al fotogramma %d (%.2f s): bambino a s=%.1f u=%.2f, giocatore a s=%.1f u=%.2f, %.1f m" % [
					_sparito, t, _ascissa(_b.bambino.global_position, _s_qui), _u(_b.bambino.global_position),
					_s_qui, _u(_qui), _qui.distance_to(_b.bambino.global_position)])
				await _rifai_sparito()
			if arrivato:
				break
	_csv.close()
	var f := FileAccess.open(_cartella.path_join("sparito.txt"), FileAccess.WRITE)
	f.store_line(str(_sparito))
	print("FINE caso %s: sparito al fotogramma %d su %d" % [caso, _sparito, _n])
	get_tree().quit(0)


func _al(s: float, u: float) -> Vector3:
	return _sala._al(_sala.punto(s), _sala.destra(s) * _lato, Vector2(u, _sala.piano))


func _tappa(s: float, u: float, vel: float, guarda := "lui") -> Dictionary:
	return {"a": _al(s, u), "vel": vel, "guarda": guarda}


func _ferma(secondi: float, guarda := "lui") -> Dictionary:
	return {"per": secondi, "guarda": guarda}


func _girati(punto: Vector3, gradi_al_secondo: float, secondi: float) -> Dictionary:
	return {"punto": punto, "giro": gradi_al_secondo, "per": secondi, "guarda": "punto"}


## Un passo di [constant DT]: avanza verso la tappa e gira lo sguardo; vero quando la tappa è finita.
func _passo(tappa: Dictionary) -> bool:
	var finita := false
	var avanti := Vector3.ZERO
	if tappa.has("a"):
		var verso: Vector3 = tappa["a"] - _qui
		avanti = verso
		var v: float = tappa["vel"]
		if verso.length() <= v * DT:
			_qui = tappa["a"]
			finita = true
		else:
			_qui += verso.normalized() * v * DT
	_s_qui = _ascissa(_qui, _s_qui)
	var giu := _accucciato()
	_occhi = move_toward(_occhi, OCCHI_GIU if giu else OCCHI, 2.4 * DT)
	var mira := Vector3.INF
	match tappa.get("guarda", "lui"):
		"lui":
			if _b.stato == BambinoSfuggita.Stato.GUARDA or _b.stato == BambinoSfuggita.Stato.SCAPPA:
				mira = _b.bambino.punto_testa()
			elif avanti.length() > 0.05:
				mira = _qui + avanti.normalized() * 5.0 + Vector3.UP * _occhi
		"avanti":
			if avanti.length() > 0.05:
				mira = _qui + avanti.normalized() * 5.0 + Vector3.UP * _occhi
		"punto":
			mira = tappa["punto"]
		"fisso":
			pass
	if mira != Vector3.INF:
		_gira_verso(mira, float(tappa.get("giro", GIRO)))
	_metti_camera()
	return finita


## Accucciato vicino alle bocche e nella galleria (alta 1,25 m): da mezzo metro prima del muro.
func _accucciato() -> bool:
	return _u(_qui) > _sala.muro - 0.6


func _u(p: Vector3) -> float:
	var s := _ascissa(p, _s_qui)
	return (p - _sala.punto(s)).dot(_sala.destra(s) * _lato)


## A che punto della strada del tunnel è [param p] (il centro più vicino, cercato attorno a [param vicino]).
func _ascissa(p: Vector3, vicino: float) -> float:
	var migliore := vicino
	var d_min := INF
	var x := vicino - 40.0
	while x <= vicino + 40.0:
		var d := (_sala.punto(x) * Vector3(1, 0, 1) - p * Vector3(1, 0, 1)).length_squared()
		if d < d_min:
			d_min = d
			migliore = x
		x += 0.05
	return migliore


func _guarda_subito(punto: Vector3) -> void:
	var d := punto - (_qui + Vector3.UP * _occhi)
	_yaw = atan2(-d.x, -d.z)
	_pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _gira_verso(punto: Vector3, gradi_al_secondo: float) -> void:
	var d := punto - (_qui + Vector3.UP * _occhi)
	if d.length() < 0.05:
		return
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var passo := deg_to_rad(gradi_al_secondo) * DT
	_yaw += clampf(angle_difference(_yaw, yaw), -passo, passo)
	_pitch += clampf(pitch - _pitch, -passo, passo)


## La camera e gli occhi del giocatore nello stesso punto (Bambino.visibile_da guarda da Player.get_eye_position).
func _metti_camera() -> void:
	_p.global_position = _qui
	_p.set(&"_eye_height", _occhi)
	_p.set(&"_eye_prev", _occhi)
	_p.set_look(_yaw, _pitch)
	_p.camera.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), _qui + Vector3.UP * _occhi)


func _fotogramma() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join("fotogrammi/%05d.jpg" % _n), 0.88)
	_n += 1


## Le animazioni del bambino adesso (per rimetterlo nella posa dell'ultimo fotogramma).
func _stati_animazioni() -> Array:
	var out := []
	for ap in _b.bambino.find_children("*", "AnimationPlayer", true, false):
		var a := ap as AnimationPlayer
		out.append([a, a.current_animation, a.current_animation_position if a.current_animation != &"" else 0.0, a.speed_scale])
	return out


var _stati_prima: Array = []


func _riga(t: float) -> void:
	var bb := _b.bambino
	var passati: int = int(bb.get(&"_n_punti_fuga")) - (bb.get(&"_punti") as Array).size() if bb.modalita == Bambino.Modalita.SCAPPA else -1
	var vis := bb.visible
	var visto := bb.visible and bb.visibile_da(_p)
	_csv.store_line("%d,%.3f,%d,%d,%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f" % [_n - 1, t, _b.stato, int(vis), int(visto), passati,
			_s_qui, _u(_qui), _occhi, _ascissa(bb.global_position, _s_qui), _u(bb.global_position), _qui.distance_to(bb.global_position)])
	if bb.visible:
		_stati_prima = _stati_animazioni()


## Il fotogramma in cui è sparito, rifatto: con lui nella posa che aveva (l'animazione di un fotogramma più avanti di
## quella salvata prima) e senza, con la stessa camera.
func _rifai_sparito() -> void:
	var bb := _b.bambino
	for st in _stati_prima:
		var ap := st[0] as AnimationPlayer
		if st[1] != &"":
			ap.play(st[1])
			ap.speed_scale = st[3]
			ap.seek(float(st[2]) + DT * float(st[3]), true)
			ap.pause()
	bb.visible = true
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_cartella.path_join("sparito_con.png"))
	bb.visible = false
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_cartella.path_join("sparito_senza.png"))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_cartella.path_join("sparito_senza2.png"))
	# (dove stava, proiettato sullo schermo: le ossa)
	var cam := _p.camera
	var r := Rect2()
	var primo := true
	for sk in bb.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		if not (s.get_parent() as Node3D).visible:
			continue
		for o in s.get_bone_count():
			var w: Vector3 = s.global_transform * s.get_bone_global_pose(o).origin
			if cam.is_position_behind(w):
				continue
			var px := cam.unproject_position(w)
			if primo:
				r = Rect2(px, Vector2.ZERO)
				primo = false
			else:
				r = r.expand(px)
	var f := FileAccess.open(_cartella.path_join("sparito_ossa.txt"), FileAccess.WRITE)
	f.store_line("%d %d %d %d" % [int(r.position.x), int(r.position.y), int(r.end.x), int(r.end.y)] if not primo else "nessuno")
	for st in _stati_prima:
		(st[0] as AnimationPlayer).stop()
