extends Node
## Collaudo dei ritocchi di ambienti-2: la salita dall'acqua del bacino alla porta, col renderer vero, nella stessa
## scena di test_scaletta_bacino (sottomarino_prova, SB1 vero). Dopo SB1, dall'acqua a 1,2 m dalla scaletta: avanti
## guardandola (come il modo B del test), poi verso la porta e dentro il tunnel. Uno scatto ogni 8 fotogrammi.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 960x540 --fixed-fps 60 \
##   --script res://tests/run.gd -- res://tests/collaudo/salita_bacino.gd <cartella> [di_lato]

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"
var cart := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.88)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	var di_lato := float(a[2]) if a.size() > 2 else 0.0
	DirAccess.make_dir_recursive_absolute(cart)
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
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var sc: Dictionary = ins.dati["scale"][ins.dati["scale"].size() - 1]
	var piede := SalaInseguimento.b([float(sc["x"]), float(sc["y"]), float(sc["z0"])])
	var cima := SalaInseguimento.b([float(sc["x"]), float(sc["y"]), float(sc["z1"])])
	var uscita := SalaInseguimento.b(ins.dati["porta"]["uscita"])
	var fatto := [false]
	ins.sb1_finito.connect(func(): fatto[0] = true)
	ins.cala_grata()
	p.teleport(piede + Vector3(3.0, 0.3, 0.0))
	await _frames(3)
	ins.inizia_sb1()
	var t0 := Time.get_ticks_msec()
	while not (fatto[0] and p.input_enabled) and Time.get_ticks_msec() - t0 < 900000:
		await _frames(1)
	sott.lei_stato = SalaSottomarino.Lei.VIA
	sott.lei_tunnel.via()
	await _frames(60)
	print("SALITA: SB1 finito %s, comandi %s" % [fatto[0], p.input_enabled])
	p.teleport(piede + Vector3(1.2, 0.05, di_lato))
	await _frames(20)
	var verso := atan2(-(piede.x - p.global_position.x), -(piede.z - p.global_position.z))
	p.set_look(verso, 0.0)
	await _frames(10)
	await _scatto("salita_000_dall_acqua")
	Input.action_press(&"move_forward")
	var fase := "su"
	var su_scala := false
	var t_presa := -1.0
	var alto := -INF
	var k := 1
	var f := 0
	var oltre := false
	while f < 60 * 20:
		if fase == "su":
			p.set_look(verso, 0.6)
			if p.ladder == null and p.global_position.y > cima.y - 0.2:
				fase = "porta"
		else:
			p.set_look(atan2(-(uscita.x - p.global_position.x), -(uscita.z - p.global_position.z)), 0.0)
		await _frames(1)
		f += 1
		if p.ladder != null and not su_scala:
			su_scala = true
			t_presa = f / 60.0
		alto = maxf(alto, p.global_position.y)
		if f % 8 == 0:
			await _scatto("salita_%03d_%s" % [k, fase])
			k += 1
		if fase == "porta" and Vector2(uscita.x - p.global_position.x, uscita.z - p.global_position.z).length() < 0.5:
			if not oltre:
				oltre = true
				f = maxi(f, 60 * 20 - 90)
	Input.action_release(&"move_forward")
	print("SALITA: presa %s dopo %.2f s, piedi da %.2f a %.2f (cima %.2f), alla porta %s, fine %s" % [su_scala, t_presa,
			piede.y, alto, cima.y, oltre, p.global_position.snapped(Vector3.ONE * 0.01)])
	print("SALITA: finito")
	get_tree().quit()
