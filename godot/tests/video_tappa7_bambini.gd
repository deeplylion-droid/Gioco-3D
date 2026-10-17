extends Node
## Video delle proposte di apparizione dei bambini sulla strada di risalita (tappa 7 B, punto 12 della prova
## v0.3.1). Solo proposte: i bambini si aggiungono qui, nel gioco non c'è niente. Il giocatore segue un percorso
## fisso (camminando, con lo sguardo guidato) e i bambini fanno da soli quello che fanno nel gioco (Bambino).
##   1 "scala": un agnellino aspetta in cima alla scala di C2; guardato inclina la testa, quando ti avvicini
##     scappa lungo il corridoio e sparisce dietro l'angolo di C3.
##   2 "scaffali": un testa-a-cubo tra gli scaffali del magazzino ti segue con lo sguardo; con la torcia addosso
##     scappa tra gli scaffali verso la serranda.
##   3 "serranda": oltre la serranda, nella sala buia, due bambini fermi ti guardano; quando arrivi alla serranda
##     il cubo scappa di lato e sparisce, l'agnellino resta lì a fissarti.
## Uso (fotogrammi PNG, poi labs/grafica/strumenti/componi_video.py):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 24 --write-movie <cartella>/f.png --script res://tests/run.gd -- res://tests/video_tappa7_bambini.gd <scena> <1|2|3>

const CUBO := preload("res://scenes/creature/bambino_cubo.tscn")
const AGNELLO := preload("res://scenes/creature/bambino_agnello.tscn")

var scena := "res://tests/scene/tappa7_arredo_A.tscn"
var quale := 1
var p: Player


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	scena = a[1]
	quale = int(a[2])
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("medio")
	get_tree().change_scene_to_file(scena)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	get_tree().paused = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.set_physics_process(false)
	match quale:
		1:
			await _scala()
		2:
			await _scaffali()
		3:
			await _serranda()
	get_tree().quit()


## Un bambino a terra in pos, con la faccia (asse +Z) verso 'verso'.
func _bambino(scena_b: PackedScene, pos: Vector3, verso: Vector3, impostazioni: Dictionary) -> Bambino:
	var b := scena_b.instantiate() as Bambino
	for k in impostazioni:
		b.set(k, impostazioni[k])
	get_tree().current_scene.add_child(b)
	b.global_position = pos
	var dir := (pos - verso) * Vector3(1, 0, 1)
	b.look_at(pos + dir, Vector3.UP)   # -Z lontano dal giocatore: la faccia (+Z) verso di lui
	return b


func _punti(posizioni: Array) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for v in posizioni:
		var m := Marker3D.new()
		get_tree().current_scene.add_child(m)
		m.global_position = v
		out.append(m)
	return out


## Cammina da a a b (piedi) in 'secondi', guardando 'mira' (un punto o un Node3D che si muove).
func _cammina(a: Vector3, b: Vector3, secondi: float, mira) -> void:
	var n := int(secondi * Engine.physics_ticks_per_second)
	for i in n:
		var t := float(i) / maxf(n - 1, 1)
		p.teleport(a.lerp(b, t), p.yaw, 0.0)
		p.velocity = Vector3.ZERO
		_guarda(mira)
		await get_tree().physics_frame


func _fermo(secondi: float, mira) -> void:
	for i in int(secondi * Engine.physics_ticks_per_second):
		_guarda(mira)
		await get_tree().physics_frame


func _guarda(mira) -> void:
	var punto: Vector3
	if typeof(mira) == TYPE_OBJECT:
		if not is_instance_valid(mira) or not (mira as Node3D).is_visible_in_tree():
			return   # il bambino è sparito: lo sguardo resta dov'era
		punto = (mira as Node3D).global_position + Vector3(0, 0.9, 0)
	else:
		punto = mira
	p.look_at_point(punto)


func _scala() -> void:
	# dal pianerottolo T verso la scala di C2, che sale verso -X (globale) fino al livello della sala
	var b := _bambino(AGNELLO, Vector3(-1.6, 0.0, 45.91), Vector3(7.0, -1.8, 45.91), {
		&"modalita": Bambino.Modalita.STATUA, &"reazione": Bambino.Reazione.INCLINA_TESTA, &"tempo_per_vederlo": 0.5,
		&"distanza_fuga": 3.6, &"scappa_con_la_torcia": false})
	b.punti_fuga = _punti([Vector3(-7.0, 0.0, 45.91), Vector3(-14.9, 0.0, 45.91), Vector3(-15.0, 0.0, 43.2)])
	await _fermo(0.6, Vector3(0.0, 0.6, 45.91))
	await _cammina(Vector3(7.0, -1.8, 45.91), Vector3(3.9, -1.8, 45.91), 3.0, b)
	await _fermo(1.6, b)
	await _cammina(Vector3(3.9, -1.8, 45.91), Vector3(1.0, -0.15, 45.91), 3.2, b)
	await _fermo(2.4, Vector3(-14.0, 1.0, 45.91))


func _scaffali() -> void:
	# nel magazzino: il cubo nel varco tra due scaffali del muro est, la torcia lo fa scappare
	var b := _bambino(CUBO, Vector3(-13.6, 0.0, 25.4), Vector3(-15.0, 0.0, 29.0), {
		&"modalita": Bambino.Modalita.OSSERVA, &"tempo_torcia": 2.5, &"distanza_fuga": 0.0, &"velocita_corsa": 3.2})
	b.punti_fuga = _punti([Vector3(-13.4, 0.0, 24.6), Vector3(-12.9, 0.0, 24.9)])   # nel varco tra due scaffali
	await _fermo(0.5, Vector3(-15.0, 1.0, 24.0))
	await _cammina(Vector3(-15.0, 0.0, 29.6), Vector3(-15.0, 0.0, 28.4), 2.0, Vector3(-15.0, 1.1, 22.0))
	await _cammina(Vector3(-15.0, 0.0, 28.4), Vector3(-15.0, 0.0, 27.6), 1.4, b)
	await _fermo(4.0, b)
	await _fermo(1.6, Vector3(-12.9, 0.8, 24.9))


func _serranda() -> void:
	# dal magazzino verso la serranda mezza alzata: oltre, nella sala, due bambini fermi che guardano
	var da := Vector3(-15.0, 0.0, 25.5)
	var b1 := _bambino(CUBO, Vector3(-14.2, 0.0, 16.9), da, {
		&"modalita": Bambino.Modalita.STATUA, &"reazione": Bambino.Reazione.NESSUNA, &"distanza_fuga": 4.4, &"scappa_con_la_torcia": false})
	var b2 := _bambino(AGNELLO, Vector3(-15.9, 0.0, 16.2), da, {
		&"modalita": Bambino.Modalita.STATUA, &"reazione": Bambino.Reazione.INCLINA_TESTA, &"tempo_per_vederlo": 1.2,
		&"distanza_fuga": 5.0, &"scappa_con_la_torcia": false})
	b1.punti_fuga = _punti([Vector3(-11.5, 0.0, 16.4), Vector3(-9.0, 0.0, 15.5)])
	b2.punti_fuga = _punti([Vector3(-18.0, 0.0, 15.8), Vector3(-19.4, 0.0, 14.0)])
	await _fermo(0.5, Vector3(-15.0, 1.0, 20.2))
	await _cammina(da, Vector3(-15.0, 0.0, 22.6), 4.0, Vector3(-15.0, 0.9, 16.6))
	await _cammina(Vector3(-15.0, 0.0, 22.6), Vector3(-15.0, 0.0, 21.2), 1.6, Vector3(-15.0, 0.9, 16.6))
	await _fermo(2.6, Vector3(-15.0, 0.9, 15.5))
