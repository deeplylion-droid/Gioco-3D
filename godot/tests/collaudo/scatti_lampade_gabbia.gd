extends Node
## Scatti delle lampade a gabbia col globo (assets/enigma_acquari/lampada_gabbia.glb) nel fiume e nel tunnel (l'utente,
## 30 ottobre: "secondo me sono quelle lampade tonde che hai messo a muro": fiume e tunnel troppo luminosi). Impostazioni
## predefinite, l'ambiente e l'esposizione della sala (dove stanno nel gioco), la nebbia viola com'è dentro la zona.
## Per ogni vista uno scatto com'è e uno con le luci delle lampade a gabbia spente (solo la prova: i globi restano).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/collaudo/scatti_lampade_gabbia.gd <cartella> <fiume|tunnel>

const F := preload("res://scripts/risalita/fiume_gioco.gd")

var out := ""
var cam: Camera3D
var luci: Array[Light3D] = []
var globi: Array[MeshInstance3D] = []


func _ready() -> void:
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.fov = 75.0
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	match a[2]:
		"fiume":
			await _fiume()
		"tunnel":
			await _tunnel()
	get_tree().quit()


## Le luci delle lampade a gabbia: quelle a meno di 0,7 m da un globo.
func _trova(radice: Node) -> void:
	globi.clear()
	luci.clear()
	for g in radice.find_children("globo", "MeshInstance3D", true, false):
		globi.append(g as MeshInstance3D)
	for l in radice.find_children("*", "OmniLight3D", true, false):
		for g in globi:
			if (l as Node3D).global_position.distance_to(g.global_position) < 0.7:
				luci.append(l as Light3D)
				break
	print("LAMPADE %d globi, %d luci" % [globi.size(), luci.size()])


func _zona(radice: Node) -> void:
	var zone := radice.find_children("*", "ZonaNebbiaViola", true, false)
	if not zone.is_empty():
		Grafica.nebbia_viola.zona(zone[0], true, true)
		print("NEBBIA in ", radice.get_path_to(zone[0]))


func _coppia(nome: String, da: Vector3, verso: Vector3) -> void:
	cam.look_at_from_position(da, verso, Vector3.UP)
	for l in luci:
		l.visible = true
	await _frames(40)
	await _scatto(nome + "_com_e")
	for l in luci:
		l.visible = false
	await _frames(40)
	await _scatto(nome + "_spente")
	for l in luci:
		l.visible = true


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out.path_join(nome + ".jpg"), 0.88)
	print("SCATTO ", nome)


## Una lampada da vicino: 1,3 m davanti al globo, un po' di lato e in basso, come la vede chi passa.
func _vicino(nome: String, g: MeshInstance3D) -> void:
	var c := g.global_position
	var lampada := g.get_parent() as Node3D
	while lampada.get_parent() is Node3D and not (lampada.get_parent() as Node3D).find_children("globo", "MeshInstance3D", true, false).size() > 1:
		lampada = lampada.get_parent() as Node3D
	var avanti := (lampada.global_basis.z * Vector3(1, 0, 1)).normalized()
	# (il davanti della lampada è dalla parte libera: si prova da tutte e due e si tiene quella senza muro)
	var spazio := g.get_world_3d().direct_space_state
	var colpo := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(c, c + avanti * 1.4))
	if not colpo.is_empty():
		avanti = -avanti
	var lato := avanti.cross(Vector3.UP).normalized()
	cam.look_at_from_position(c + avanti * 1.3 + lato * 0.4 + Vector3.DOWN * 0.5, c, Vector3.UP)
	await _frames(40)
	await _scatto(nome)


func _fiume() -> void:
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	await _frames(90)
	_trova(f)
	_zona(f)
	await _frames(30)
	# la lampada più vicina all'ingresso, da vicino
	var ingresso := Vector3(F.INGRESSO_X, 2.0, F.Z0 + 1.0)
	var vicina: MeshInstance3D = null
	for g in globi:
		if vicina == null or g.global_position.distance_to(ingresso) < vicina.global_position.distance_to(ingresso):
			vicina = g
	if vicina:
		await _vicino("fiume_0_lampada_vicino", vicina)
	# l'ingresso: il corridoio fra le pile, la piazza, l'imbarco col salvagente
	var da := Vector3(F.INGRESSO_X, 0, F.Z0 + 1.0)
	var dir := (F.FINE_FILA - da).normalized()
	var lungo := da.distance_to(F.FINE_FILA)
	var p1: Vector3 = da + dir * lungo * 0.25
	await _coppia("fiume_1_corridoio_pile", p1 + Vector3(0, 1.6, 0), p1 + dir * 8.0 + Vector3(0, 1.3, 0))
	await _coppia("fiume_2_piazza", Vector3(F.INGRESSO_X, 1.6, F.Z0 + 1.0), Vector3(-3.6, 0.6, -3.6))
	await _coppia("fiume_3_imbarco", F.FINE_FILA + Vector3(0, 1.6, 0), Vector3(-2.3, 0.4, -2.3))
	# l'uscita: l'approdo dalla barca, la banchina, il corridoio del personale
	await _coppia("fiume_4_approdo", Vector3(-29.6, 0.6, 0.0), Vector3(-40.0, 0.8, 0.0))
	await _coppia("fiume_5_banchina", Vector3(F.APPRODO.x + 1.5, 1.6, F.APPRODO.y + 2.0), Vector3(F.X0 - 2.0, 1.3, F.APPRODO.y))
	await _coppia("fiume_6_corridoio_personale", Vector3(F.X0 + 1.0, 1.6, F.APPRODO.y), Vector3(F.X0 - 8.0, 1.4, F.APPRODO.y))


func _tunnel() -> void:
	var sala := (load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene).instantiate() as SalaSottomarino
	add_child(sala)
	await sala.costruisci_a_pezzi()
	await _frames(20)
	if sala.lei_tunnel:
		sala.lei_tunnel.visible = false
	_trova(sala)
	_zona(sala)
	await _frames(30)
	# un tratto con le lampade calde e uno nel giardino dei coralli (le lampade sono ogni 9 m da s 3)
	var calda := -1.0
	var coralli := -1.0
	var s := 3.0
	while s < sala.lunghezza():
		var amb := int(sala.ambiente(s))
		if amb == 0 and calda < 0.0 and s > 20.0:
			calda = s
		if amb == 1 and coralli < 0.0:
			coralli = s
		s += 9.0
	print("TRATTI calda s %.0f, coralli s %.0f" % [calda, coralli])
	for v in [["tunnel_1_calde", calda], ["tunnel_2_coralli", coralli]]:
		if float(v[1]) < 0.0:
			continue
		var s0: float = v[1]
		# la lampada di quel tratto da vicino
		var p := sala.punto(s0)
		var vicina: MeshInstance3D = null
		for g in globi:
			if vicina == null or g.global_position.distance_to(p) < vicina.global_position.distance_to(p):
				vicina = g
		if vicina:
			await _vicino(v[0] + "_0_lampada_vicino", vicina)
		# dagli occhi del giocatore sulla banchina, 7 m prima, guardando avanti lungo il tunnel
		var da := _occhio(sala, s0 - 7.0, 1.0, 1.6)
		var verso := _occhio(sala, s0 + 6.0, 0.0, 1.2)
		await _coppia(v[0], da, verso)


func _occhio(sala: SalaSottomarino, s: float, lato: float, su: float) -> Vector3:
	var di_lato := lato * sala.canale if absf(lato) < 0.99 else signf(lato) * (sala.canale + sala.banchina * 0.5)
	return sala.punto(s) + sala.destra(s) * di_lato + Vector3.UP * (sala.piano - sala.acqua + su)
