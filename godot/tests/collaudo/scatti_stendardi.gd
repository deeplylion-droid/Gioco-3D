extends Node
## Scatti degli stendardi dei bambini dietro le vasche dell'inseguimento (richiesta dell'utente del 6 novembre: «stendardi
## giganti appesi nel vuoto dietro, nella distanza ... come se fossero lenzuoli appesi e colorati dai bambini»): la sala
## della torre con le condotte, le luci della sala come le trova il giocatore (blackout), il giocatore vero in piedi in
## ogni vasca (al checkpoint), dagli occhi, verso i quattro lati e verso ogni stendardo.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan \
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/scatti_stendardi.gd <cartella> [giro|stendardi]

const PLAYER := "res://scenes/player/player.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	var a := OS.get_cmdline_user_args()
	var cartella: String = a[1]
	var modo: String = a[2] if a.size() > 2 else "giro"
	# (terzo argomento: il filo di luce dei pastelli sugli stendardi, StendardiInseguimento.luce)
	if a.size() > 3:
		StendardiInseguimento.luce = float(a[3])
	DirAccess.make_dir_recursive_absolute(cartella)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	Grafica.aggiorna_environment()
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	for i in 20:
		await get_tree().physics_frame
	var ins := torre.inseguimento as SalaInseguimento
	while not bool(ins.get(&"costruita")):
		await get_tree().process_frame
		if Engine.get_process_frames() > 20000:
			break
	ins.tempo_presa = 9999.0
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	for i in 10:
		await get_tree().physics_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	# (lei non c'è: gli scatti sono per gli stendardi; anche quella che sale accanto alla vasca 2)
	for n in ins.find_children("*", "Node3D", true, false):
		if String(n.name).to_lower().begins_with("lei") and n is VisualInstance3D or (n.get_script() and String(n.get_script().resource_path).contains("lei")):
			(n as Node3D).visible = false
	if ins.lei:
		ins.lei.visible = false
	var stendardi: Array = get_tree().get_nodes_in_group(&"stendardo")
	print("SCATTI stendardi trovati: ", stendardi.size())
	for cp in ins.dati["checkpoint"]:
		var nome: String = cp["nome"]
		if not nome.begins_with("vasca"):
			continue
		var pos := SalaInseguimento.b(cp["pos"])
		p.teleport(pos + Vector3.UP * 0.3)
		for i in 30:
			await get_tree().physics_frame
		p.set_physics_process(false)
		var occhi := p.get_eye_position()
		var mire: Array = []
		if modo == "giro":
			for k in 4:
				var d := Vector3.FORWARD.rotated(Vector3.UP, k * PI * 0.5)
				mire.append(["%s_%s" % [nome, ["nord", "ovest", "sud", "est"][k]], occhi + d * 10.0 + Vector3.UP * 3.0])
		else:
			# (da ogni vasca lo stendardo che le sta dietro: il centro del lenzuolo)
			var suoi := {"vasca_1": ["stendardo_1"], "vasca_2": ["stendardo_2"], "vasca_3": ["stendardo_3", "stendardo_4"]}
			for s in stendardi:
				if String(s.name) in suoi.get(nome, []):
					var c := (s as MeshInstance3D).global_transform * (s as MeshInstance3D).get_aabb().get_center()
					mire.append(["%s_verso_%s" % [nome, s.name], c])
		for m in mire:
			for i in 16:
				p.look_at_point(m[1])
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(cartella.path_join(m[0] + ".png"))
			print("SCATTO ", m[0], " occhi ", occhi.snapped(Vector3.ONE * 0.01))
		p.set_physics_process(true)
	print("SCATTI FINITI")
	get_tree().quit()
