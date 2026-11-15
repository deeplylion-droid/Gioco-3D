extends Node
## Scatti dagli occhi del giocatore della build 0.5.0, «La storia», lato enigmi:
## - "squalo": nel fiume lento del gioco (tests/scene/fiume_gioco_prova.tscn, col giocatore vero sulla ciambella, la
##   strada giusta), con l'ambiente e le luci del blackout della sala: lo squalo che segue (girandosi indietro), la testa
##   fuori quando attacca, il morso davanti alla camera;
## - "df": il foglio DF nel corridoio del fiume (la Risalita da sola, coi suoi corridoi): arrivando dalla scala, a metà
##   corridoio, davanti al foglio, e da vicino gli angoli col nastro, il pastello e le impronte.
## Uso (scena col renderer vero: llvmpipe, sotto il render.lock, con almeno 13,5 GB liberi):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scatti_storia_fiume.gd <cartella> squalo|df

const S := SqualoFiume.Stato
var cartella := ""


func _ready() -> void:
	_run.call_deferred()


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
	print("SCATTO %s" % nome)


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ambiente(dove: Node) -> void:
	var we := WorldEnvironment.new()
	we.environment = load("res://addons/grafica/sala/ambiente_sala.tres") as Environment
	we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	dove.add_child(we)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cartella = a[1] if a.size() > 1 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(cartella)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	var cosa := a[2] if a.size() > 2 else "squalo"
	if cosa == "df":
		await _df()
	else:
		await _squalo()
	print("SCATTI FINITI")
	get_tree().quit()


# --- Lo squalo nel fiume lento ---------------------------------------------------------------

func _squalo() -> void:
	get_tree().change_scene_to_file("res://tests/scene/fiume_gioco_prova.tscn")
	var p: Player = null
	for i in 3000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			p = GameState.player
			break
	await _fisica(10)
	var level := get_tree().current_scene
	_ambiente(level)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var fiume := level.get_node(^"Fiume/FiumeLento") as FiumeLento
	var squalo := fiume.squalo as SqualoFiume
	(fiume.get_node(^"Paratia1") as ParatiaFiume).a_destra = false
	(fiume.get_node(^"Paratia3") as ParatiaFiume).a_destra = false
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	p.camera.make_current()
	Grafica.imposta("fov", 75.0)
	p.teleport((level.get_node(^"Fiume/Marker/Imbarco") as Node3D).global_position, 0.0, 0.0)
	await get_tree().physics_frame
	fiume.sali(p)
	# all'imbarco, guardando avanti: è calmo
	await _fisica(120)
	await _scatta("squalo_0_imbarco_calmo")
	while fiume.tratto == fiume.imbarco:
		await get_tree().physics_frame
	# segue: ci si gira indietro, verso la scia
	for i in 60 * 12:
		await get_tree().physics_frame
		if squalo.stato == S.SEGUE and squalo.squalo.visible:
			break
	await _fisica(60 * 3)
	for k in 3:
		var pinna := squalo.squalo.global_position
		p.look_at_point(pinna + Vector3.UP * 0.1)
		await _fisica(2)
		await _scatta("squalo_1_segue_%d" % k)
		await _fisica(60)
	# attacca: la testa fuori dall'acqua, a bocca aperta
	for i in 60 * 40:
		await get_tree().physics_frame
		if squalo.stato == S.ATTACCO:
			break
	print("  (attacco: %s)" % S.find_key(squalo.stato))
	var muso := squalo.get(&"_muso") as Node3D
	for k in 3:
		if squalo.stato != S.ATTACCO:
			break
		if muso:
			p.look_at_point(muso.global_position)
		await _fisica(2)
		await _scatta("squalo_2_attacco_%d" % k)
		await _fisica(40)
	# il morso, se non lo si respinge
	for i in 60 * 6:
		await get_tree().physics_frame
		if squalo.stato == S.MORSO:
			break
	for k in 3:
		await _fisica(9)
		await _scatta("squalo_3_morso_%d" % k)


# --- Il foglio DF nel corridoio del fiume --------------------------------------------------

func _df() -> void:
	var radice := Node3D.new()
	radice.name = "Radice"
	add_child(radice)
	_ambiente(radice)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var ris := (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate() as Node3D
	radice.add_child(ris)
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	radice.add_child(p)
	GameState.player = p
	await _fisica(10)
	p.camera.make_current()
	Grafica.imposta("fov", 75.0)
	var df := ris.find_child("StoriaDF", true, false) as DisegnoBambino
	if df == null:
		push_error("niente StoriaDF")
		return
	# il bambino col cubo non c'è ancora (compare solo col giocatore nel corridoio): si guarda il foglio da solo
	var b := ris.find_child("BambinoCorridoioFiume", true, false)
	if b:
		b.set_process(false)
		b.set_physics_process(false)
	var c := df.global_position
	var verso := df.global_basis.z.normalized()
	var piedi := c - Vector3.UP * df.altezza
	for v in [["df_1_dalla_scala", 16.0], ["df_2_meta_corridoio", 8.0], ["df_3_davanti", 3.0], ["df_4_vicino", 1.3]]:
		p.teleport(piedi + verso * float(v[1]), atan2(verso.x, verso.z), 0.0)
		await _fisica(20)
		p.look_at_point(c)
		await _fisica(8)
		await _scatta(v[0])
	# da vicino (camera libera, come chi si avvicina col viso): i quattro angoli col nastro, il pastello e le impronte
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.02
	radice.add_child(cam)
	cam.make_current()
	var m := df.misura()
	var i := 0
	for ang in [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		var q := df.to_global(Vector3(ang.x * m.x * 0.5, ang.y * m.y * 0.5, 0.0))
		cam.global_position = q + verso * 0.28 + df.global_basis.x * ang.x * 0.12
		cam.look_at(q, Vector3.UP)
		await _fisica(6)
		await _scatta("df_5_nastro_%d" % i)
		i += 1
	var pastello := df.find_child("Pastello*", true, false) as Node3D
	if pastello:
		cam.global_position = pastello.global_position + verso * 0.35 + Vector3.UP * 0.25
		cam.look_at(pastello.global_position, Vector3.UP)
		await _fisica(6)
		await _scatta("df_6_pastello")
	cam.global_position = piedi + verso * 0.6 + Vector3.UP * 1.5 + df.global_basis.x * -0.2
	cam.look_at(piedi + verso * 0.9 + df.global_basis.x * 0.6, Vector3.UP)
	await _fisica(6)
	await _scatta("df_7_impronte")
