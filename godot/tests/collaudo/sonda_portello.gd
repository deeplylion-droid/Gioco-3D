extends Node
## Collaudo: chiudere il portello dalla camera stagna col giocatore vero, da un punto scelto, e vedere dove finisce il
## giocatore (il battente che si chiude lo spinge?) e se lo schianto di lei sull'oblò si vede. Lei è ferma a 8 m dal
## portello, nel canale (come arriva nel gioco). Scatti dagli occhi: prima di E, a battente chiuso, durante lo schianto.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 960x540 --fixed-fps 60 \
##        --script res://tests/run.gd -- res://tests/collaudo/sonda_portello.gd <cartella> <dentro m> <lato m>
## (dentro: quanto dentro la camera, dal piano della porta; lato: di lato dall'asse, positivo a destra)

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"
var cart := ""
var nome := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _foto(cosa: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join("%s_%s.jpg" % [nome, cosa]), 0.85)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	var dentro := float(a[2])
	var lato := float(a[3])
	nome = "portello_d%.1f_l%+.1f" % [dentro, lato]
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	var level := get_tree().current_scene
	var p := GameState.player
	var ins := level.get_node("SalaInseguimento") as SalaInseguimento
	var sott := level.get_node("SalaSottomarino") as SalaSottomarino
	sott.costruisci()
	ins.sb1_finito.connect(sott.attiva_tunnel)
	p.water_pack.set_equipped(true, false)
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	ins.sb1_finito.emit()
	await _frames(5)
	var L := sott.lunghezza()
	var d := sott.direzione(L)
	var r := sott.destra(L)
	var pf := sott.punto(L)
	var sg := sott.piano - sott.acqua + SalaSottomarino.SOGLIA
	var q := pf + d * dentro + r * lato + Vector3.UP * (sg + 0.05)
	p.teleport(q)
	await _frames(20)
	# lei nel canale a 8 m, che insegue
	sott.insegui_da(L - 8.0)
	var oblo := pf + r * 0.0 + Vector3.UP * (sg + SalaSottomarino.OBLO_Y)
	p.look_at_point(oblo)
	await _frames(10)
	var prima := p.global_position
	await _foto("0_prima")
	var fine := [false]
	sott.fine_demo.connect(func(): fine[0] = true)
	Input.action_press(&"interact")
	await _frames(3)
	Input.action_release(&"interact")
	await _frames(2)
	print("PORTELLO: %s giocatore a %s (dentro %.2f, lato %.2f), chiusura partita %s" % [nome, str(prima.snappedf(0.01)), dentro, lato, sott.finito])
	if not sott.finito:
		get_tree().quit()
		return
	var massimo := 0.0
	var cam := get_viewport().get_camera_3d()
	var visto := 0
	var guardati := 0
	for k in 60 * 7:
		await _frames(1)
		massimo = maxf(massimo, Vector2(p.global_position.x - prima.x, p.global_position.z - prima.z).length())
		if k == 50:
			await _foto("1_chiuso")
		if k == 150 or k == 200:
			await _foto("2_schianto_%d" % k)
		if k > 120 and k < 260 and cam:
			guardati += 1
			if cam.is_position_in_frustum(oblo):
				visto += 1
		if fine[0]:
			break
	var dopo := p.global_position
	print("PORTELLO: %s spostato al massimo di %.2f m (alla fine %.2f m, verso %s); oblò nella vista durante lo schianto %d su %d fotogrammi; fine_demo %s" % [
			nome, massimo, Vector2(dopo.x - prima.x, dopo.z - prima.z).length(), str((dopo - prima).snappedf(0.01)), visto, guardati, fine[0]])
	get_tree().quit()
