extends Node
## Prima e dopo (grafica) dell'ombra della lampada d'emergenza del muro est sul muro sopra l'oblò della torre (collaudo di
## ambienti-1 del 29 ottobre: a sinistra della lampada una fascia scura col bordo netto, l'ombra della struttura della
## torre, dove nella 0.3.15 il muro era rosso). La torre costruita e preparata come nel gioco, la vasca vuota, con la
## camera vera del giocatore; ogni vista in tre modi:
## - "0315": la lampada senza ombra, com'era nella 0.3.15 (la riga rossa nelle condotte);
## - "ora": l'ombra piena, com'è nella 0.3.16 (la fascia scura sul muro);
## - "correzione": l'ombra senza torre_A fra chi la fa (SalaTorre.STRATO_SENZA_OMBRA_EST e shadow_caster_mask), come
##   nel codice dopo la correzione.
## Viste: il muro sopra l'oblò dalla torre, l'oblò di fronte e la sala delle condotte attorno alla cisterna. Stampa il
## rosso medio (0-255) del muro a sinistra della lampada e le pipeline compilate durante gli scatti.
## Uso (sotto il lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/muro_oblo_ombra.gd <cartella>

const PLAYER := "res://scenes/player/player.tscn"
const POSTO_TORRE := Vector3(38.0, -19.98, -13.4)
const STRATO := SalaTorre.STRATO_SENZA_OMBRA_EST
var cartella := ""
var p: Player


func _ready() -> void:
	cartella = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	for sc in ["res://scenes/creature/bambino_cubo.tscn", "res://scenes/creature/bambino_agnello.tscn", "res://scenes/props/polaroid.tscn"]:
		var n := (load(sc) as PackedScene).instantiate()
		n.set(&"visible", false)
		add_child(n)
	var campioni := SalaTorre.materiali_campione()
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	torre.costruzione_a_pezzi = true
	torre.visible = false
	torre.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(torre)
	await torre.costruisci_a_pezzi()
	await torre.prepara_materiali(get_viewport())
	torre.visible = true
	torre.process_mode = Node.PROCESS_MODE_INHERIT
	campioni.clear()
	var o: ObloLei = torre.oblo
	o.set_process(false)
	var lampada: OmniLight3D = null
	for l: OmniLight3D in torre.get_node(^"Luci").find_children("*", "OmniLight3D", true, false):
		if l.shadow_enabled and absf(l.global_position.x - SalaTorre.MURO_CONDOTTE_X) < 1.0 \
				and (lampada == null or l.global_position.distance_to(o.global_position) < lampada.global_position.distance_to(o.global_position)):
			lampada = l
	var torre_a := torre.find_child("torre_A", true, false) as GeometryInstance3D
	print("MURO lampada %s a %s, caster mask %x, torre_A strati %x" % [lampada.get_path(), lampada.global_position,
		lampada.shadow_caster_mask, torre_a.layers])
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.set_physics_process(false)
	var lp := lampada.global_position
	var c := o.centro_vetro()
	var n := o.normale()
	var lato := n.cross(Vector3.UP).normalized()
	var occhi := Vector3.UP * 1.6
	var dietro := c - n * 1.8
	var viste := [
		["muro", POSTO_TORRE, Vector3(SalaTorre.MURO_CONDOTTE_X, lp.y + 0.4, lp.z + 0.6)],
		["fronte", POSTO_TORRE, c],
		["condotte_lato", dietro + lato * 3.6 - occhi, dietro + lato * 1.6],
		["condotte_altro_lato", dietro - lato * 3.6 - occhi, dietro - lato * 1.6],
		["condotte_sotto", dietro + lato * 3.0 + Vector3.DOWN * 4.5 - occhi, dietro + lato * 1.6 + Vector3.DOWN * 2.5],
		["condotte_lontano", c - n * 9.0 + lato * 2.0 + Vector3.UP * 1.0 - occhi, dietro],
	]
	var pipe0 := _pipeline()
	var strati_a := torre_a.layers
	var mask := lampada.shadow_caster_mask
	for v in viste:
		p.teleport(v[1])
		await _fotogrammi(4)
		p.look_at_point(v[2])
		for modo in ["0315", "ora", "correzione"]:
			lampada.shadow_enabled = modo != "0315"
			if modo == "correzione":
				# (solo lo strato nuovo: con anche il primo la maschera delle ombre lo prendeva lo stesso)
				torre_a.layers = strati_a
				lampada.shadow_caster_mask = mask
			else:
				torre_a.layers = 1
				lampada.shadow_caster_mask = 0xFFFFF
			await _fotogrammi(30)
			await _scatto("%s_%s" % [v[0], modo], lp if v[0] == "muro" else Vector3.INF)
	# com'era nel codice
	torre_a.layers = strati_a
	lampada.shadow_caster_mask = mask
	lampada.shadow_enabled = true
	var pipe1 := _pipeline()
	print("MURO pipeline durante gli scatti: +%d / +%d" % [pipe1[0] - pipe0[0], pipe1[1] - pipe0[1]])
	get_tree().quit()


func _pipeline() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _fotogrammi(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _scatto(nome: String, lampada: Vector3) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
	var misura := ""
	if lampada != Vector3.INF:
		# il muro a sinistra della lampada (vista dalla torre: z più grande), sopra di lei, dove c'era la fascia scura
		var cam := get_viewport().get_camera_3d()
		for k in [["sopra_sinistra", Vector3(SalaTorre.MURO_CONDOTTE_X - 0.02, lampada.y + 0.35, lampada.z + 0.8)],
				["sopra", Vector3(SalaTorre.MURO_CONDOTTE_X - 0.02, lampada.y + 0.6, lampada.z)]]:
			var s := cam.unproject_position(k[1])
			var r := Rect2i(Vector2i(s) - Vector2i(20, 20), Vector2i(40, 40)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			var somma := 0.0
			var q := 0
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					somma += img.get_pixel(x, y).r
					q += 1
			misura += " %s R %.0f (a %s)" % [k[0], somma / maxf(q, 1) * 255.0, Vector2i(s)]
	print("scatto %s%s" % [nome, misura])
