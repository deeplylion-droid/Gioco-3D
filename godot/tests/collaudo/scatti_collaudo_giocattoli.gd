extends Node
## Collaudo indipendente dell'enigma dei giocattoli (ambienti-2, 29 ottobre), col renderer vero nella sala ridotta
## (tests/scena_ridotta.gd, come scatti_giocattoli_vicino.gd), preset medio.
## 1. Le pipeline a metà enigma, senza torcia, dagli occhi del giocatore sul bordo: dopo il riscaldamento si contano
##    quelle compilate guardando la piscina piena, poi vuota coi giocattoli posati, poi col piatto sceso, poi risolta
##    (luce verde). Attese: 0 draw.
## 2. Scatti radenti per il distacco (regola del 22 ottobre: anche 1-2 cm sono un difetto), con una torcia sulla
##    camera: ogni giocattolo da quattro lati all'altezza del contatto, a piscina vuota (posati), sul piatto sbagliato e
##    sui piatti scesi; i piatti a riposo di lato, a filo del fondo; i gonfiabili spostati sulla spiaggia da due lati.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/collaudo/scatti_collaudo_giocattoli.gd <cartella>

const SCENA := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Atmosfera", "Sala/TorreScivoli", "Sala/Dettagli", "Sala/AreaBimbi", "Vasca", "Gioco/LeiSbuca",
		"Gioco/EnigmaAcquari"]
const SPIAGGIA := ["ogg_paperella_gigante_0", "ogg_paperella_gigante_1", "ogg_pallone_spiaggia_2", "ogg_pallone_spiaggia_3",
	"ogg_pallone_spiaggia_43", "ogg_pallone_spiaggia_71"]

var cam: Camera3D
var out := ""
var enigma: EnigmaGiocattoli
var vasca: WaterTank


func _ready() -> void:
	_run.call_deferred()


func _pipeline() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _run() -> void:
	out = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out)
	Game.pause_on_focus_loss = false
	Grafica.applica_preset("medio")
	Engine.set_meta(&"precarica_torre_spento", true)
	get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci(SCENA, TOGLI))
	while get_tree().current_scene == null or get_tree().current_scene == self:
		await get_tree().process_frame
	var level := get_tree().current_scene
	var p := level.get_node_or_null(^"Player") as Node3D
	if p:
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.global_position = Vector3(12.0, 0.0, -18.0)
		var hud := p.get_node_or_null(^"HUD")
		if hud:
			hud.set(&"visible", false)
	enigma = level.get_node(^"Piscina/EnigmaGiocattoli") as EnigmaGiocattoli
	vasca = level.get_node(^"Piscina/Pozza") as WaterTank
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.02
	get_tree().root.add_child(cam)
	cam.make_current()
	# (SOLO_DISEGNO=1: solo il disegno dei bambini sul muro ovest, dagli occhi del giocatore, con la luce del gioco)
	if OS.get_environment("SOLO_DISEGNO") != "":
		for i in 300:
			await get_tree().process_frame
		var muro := Vector3(-6.97, -0.8, -0.2)
		await _guarda("disegno dall'acqua", Vector3(-3.2, -0.35, -0.2), muro)
		await _guarda("disegno dal bordo", Vector3(-4.6, 1.6, 2.6), muro)
		await _guarda("disegno da vicino nell'acqua", Vector3(-5.2, -0.35, 0.4), muro)
		vasca.fill = 0.0
		for i in 240:
			await get_tree().physics_frame
		await _guarda("disegno dal fondo vuoto", Vector3(-3.5, -0.45, -0.2), muro)
		print("FINE")
		get_tree().quit()
		return
	# 1. le pipeline: dagli occhi sul bordo sud e sul bordo est, come il giocatore
	cam.look_at_from_position(Vector3(0.0, 1.6, -3.2), Vector3(0.0, -1.5, 2.0), Vector3.UP)
	for i in 300:
		await get_tree().process_frame
	var base := _pipeline()
	print("PIPELINE base (dopo il caricamento e il riscaldamento) ", base)
	await _guarda("piena", Vector3(7.3, 1.6, 2.0), Vector3(0.0, -1.5, 2.0))
	vasca.fill = 0.0
	for i in 240:
		await get_tree().physics_frame
	await _guarda("vuota coi giocattoli posati", Vector3(7.3, 1.6, 2.0), Vector3(0.0, -2.0, 2.0))
	enigma.metti_al_posto_uno(1)
	for i in 120:
		await get_tree().physics_frame
	await _guarda("un piatto sceso", Vector3(0.0, 1.6, -3.2), Vector3(3.9, -2.2, 3.3))
	enigma.load_state({"risolto": true})
	for i in 120:
		await get_tree().physics_frame
	await _guarda("risolto, luce verde", Vector3(0.0, 1.6, -3.2), Vector3(0.0, -2.2, 2.0))
	var fine := _pipeline()
	print("PIPELINE a metà enigma: draw %d, specializzazione %d" % [fine[0] - base[0], fine[1] - base[1]])
	# 2. gli scatti radenti, con la torcia
	var torcia := SpotLight3D.new()
	torcia.spot_range = 8.0
	torcia.spot_angle = 35.0
	torcia.light_energy = 3.0
	torcia.shadow_enabled = true
	cam.add_child(torcia)
	cam.fov = 50.0
	# a. piscina vuota, giocattoli posati dove sono all'inizio, piatti a riposo
	enigma.load_state({"pos": [[0.3, 2.5, 0.0], [4.4, -0.6, 0.0], [-0.2, -0.8, 0.0]], "giu": [false, false, false], "risolto": false})
	await _riposa()
	await _giro("a_vuota_giocattolo", false)
	for i in 3:
		var c := enigma.cerchio(i).global_position
		for k in 2:
			var dir := Vector3(cos(k * PI), 0, sin(k * PI))
			await _scatto(c + dir * 0.9 + Vector3(0, 0.04, 0), c + dir * 0.48 + Vector3(0, 0.01, 0), "a_vuota_piatto_%d_lato%d" % [i, k])
	# b. lo sbaglio: la paperella sul cerchio rosso
	var rosso := enigma.cerchio(1).position
	enigma.load_state({"pos": [[rosso.x, rosso.z, 0.4], [4.4, -0.6, 0.0], [-0.2, -0.8, 0.0]], "giu": [false, false, false], "risolto": false})
	await _riposa()
	await _giro("b_sbaglio_paperella_su_rosso", false, [0])
	# c. risolto: sui piatti scesi
	enigma.load_state({"risolto": true})
	await _riposa()
	await _giro("c_risolto", true)
	# e. a piscina vuota, il pallone appoggiato a ogni gonfiabile del fondo (dopo lo scivolamento attorno ai gonfiabili):
	# di lato, all'altezza del contatto, fra lui e il gonfiabile
	var r1: float = EnigmaGiocattoli.RAGGI[1]
	var k_cap := 0
	for f in enigma._capsule:
		var a: Vector2 = f["a"]
		var b: Vector2 = f["b"]
		var c := (a + b) / 2.0
		var verso := (Vector2(0.0, 1.5) - c)
		verso = verso.normalized() if verso.length() > 0.01 else Vector2.RIGHT
		var q := EnigmaGiocattoli._vicino(f, c + verso * 5.0)
		var pos := q + verso * (float(f["r"]) + r1 + 0.01)
		enigma.load_state({"pos": [[0.3, 2.5, 0.0], [pos.x, pos.y, 0.0], [-0.2, -0.8, 0.0]], "giu": [false, false, false], "risolto": false})
		await _riposa()
		var g := enigma.giocattolo(1).global_position
		var lato := Vector3(-verso.y, 0, verso.x)
		var tocco := enigma.to_global(Vector3(q.x, 0, q.y))
		tocco.y = g.y + 0.1
		print("GONFIABILE %d: capsula %s, pallone %s" % [k_cap, f, g])
		await _scatto(tocco + lato * 1.1 + Vector3(0, 0.05, 0), tocco + Vector3(verso.x, 0, verso.y) * 0.1, "e_gonfiabile_%d_lato" % k_cap)
		await _scatto(tocco + Vector3(verso.x, 0, verso.y) * 1.6 + lato * 0.5 + Vector3(0, 0.6, 0), tocco, "e_gonfiabile_%d_alto" % k_cap)
		k_cap += 1
	# d. la spiaggia
	var oggetti := level.get_node(^"Sala/Oggetti") as Node3D
	for nome in SPIAGGIA:
		var o := oggetti.get_node(NodePath(nome)) as MeshInstance3D
		var bb := o.global_transform * o.get_aabb()
		var q := bb.get_center()
		var basso := Vector3(q.x, bb.position.y + 0.05, q.z)
		var r := maxf(bb.size.x, bb.size.z) * 0.5
		for k in 2:
			var dir := Vector3(cos(k * PI + 0.6), 0, sin(k * PI + 0.6))
			await _scatto(basso + dir * (r + 0.6) + Vector3(0, 0.05, 0), basso, "d_spiaggia_%s_lato%d" % [nome.trim_prefix("ogg_"), k])
	print("PIPELINE totale col collaudo (torcia compresa) ", _pipeline())
	print("FINE")
	get_tree().quit()


func _riposa() -> void:
	for i in 300:
		await get_tree().physics_frame


## Quattro scatti radenti di ogni giocattolo (o solo di [param quali]), all'altezza del contatto col fondo o col piatto.
func _giro(nome: String, sui_piatti: bool, quali := [0, 1, 2]) -> void:
	for i in quali:
		var g := enigma.giocattolo(i)
		var gp := g.global_position
		var r: float = EnigmaGiocattoli.RAGGI[i]
		print("POSIZIONE %s %d: giocattolo %s, cerchio %s, piatto giù %s" % [nome, i, gp, enigma.cerchio(i).global_position, enigma.piatto_giu(i)])
		for k in 4:
			var dir := Vector3(cos(k * PI / 2 + 0.3), 0, sin(k * PI / 2 + 0.3))
			var contatto := gp + Vector3(0, 0.02, 0)
			await _scatto(contatto + dir * (r + 0.55) + Vector3(0, 0.03, 0), contatto + dir * (r * 0.5), "%s_%d_lato%d" % [nome, i, k])


func _guarda(cosa: String, da: Vector3, verso: Vector3) -> void:
	var prima := _pipeline()
	cam.look_at_from_position(da, verso, Vector3.UP)
	for i in 60:
		await get_tree().process_frame
	var dopo := _pipeline()
	print("PIPELINE %s: draw +%d, specializzazione +%d" % [cosa, dopo[0] - prima[0], dopo[1] - prima[1]])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out.path_join("occhi_" + cosa.replace(" ", "_").replace(",", "") + ".jpg"), 0.88)


func _scatto(da: Vector3, verso: Vector3, nome: String) -> void:
	cam.look_at_from_position(da, verso, Vector3.UP)
	for i in 15:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out.path_join(nome + ".jpg"), 0.88)
	print("SCATTO ", nome)
