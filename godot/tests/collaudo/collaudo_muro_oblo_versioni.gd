extends Node
## Ricontrollo (enigmi, 30 ottobre) del muro sopra l'oblò della torre (lavoro/torre-muro-oblo): lo stesso giro su ogni
## versione vera (0.3.15 503b5d45, 0.3.16 7deab786, il branch), senza toccare niente, con la camera vera del giocatore.
## La torre costruita e preparata come nel gioco (come tests/collaudo/muro_oblo_ombra.gd), la vasca vuota.
## - il muro sopra la lampada d'emergenza del muro est vicina all'oblò, l'oblò di fronte, le 4 viste dalle condotte;
##   il rosso medio (0-255) del muro sopra a sinistra e sopra la lampada;
## - una vista per ogni luce con l'ombra della torre (dal lato del centro della torre) e quattro viste larghe;
## - con il branch (SalaTorre.STRATO_SENZA_OMBRA_EST), ogni vista anche con torre_A come nella 0.3.16 (strato 1,
##   maschera piena, "_come_0316"): la differenza dice cosa cambia la correzione; in 4 viste di nuovo com'è nel codice
##   ("_di_nuovo"), per il rumore fra due scatti uguali;
## - con VISTE_CORTE nell'ambiente (le versioni vecchie) solo il muro, le condotte, le viste larghe e le lampade del
##   muro est; con VISTE_CORTE=2 solo il muro, l'oblò di fronte e le condotte;
## - lei nell'oblò (da lontano e da vicino), col colore medio del vetro;
## - le pipeline compilate in ogni fase.
## Gli scatti in PNG in <cartella>; le righe "VERSIONI" nel log.
## Uso (sotto il lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/collaudo_muro_oblo_versioni.gd <cartella>

const PLAYER := "res://scenes/player/player.tscn"
const POSTO_TORRE := Vector3(38.0, -19.98, -13.4)
const POSTO_LONTANO := Vector3(35.9, -20.0, -13.4)
const MURO_X := 40.0
const OCCHI := Vector3(0.0, 1.6, 0.0)
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
	var costanti := (load("res://scripts/game/sala_torre.gd") as Script).get_script_constant_map()
	var con_strato := costanti.has("STRATO_SENZA_OMBRA_EST")
	var pipe0 := _pipeline()
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
	var pipe1 := _pipeline()
	print("VERSIONI FASE costruzione e preparazione: pipeline +%d / +%d" % [pipe1[0] - pipe0[0], pipe1[1] - pipe0[1]])
	var o: ObloLei = torre.oblo
	o.set_process(false)
	var torre_a := torre.find_child("torre_A", true, false) as GeometryInstance3D
	# (solo le luci della torre, nel nodo Luci: non quelle di lei né della sala delle condotte)
	var luci: Array[Light3D] = []
	for l in torre.get_node(^"Luci").find_children("*", "Light3D", true, false):
		luci.append(l as Light3D)
	var lampada: OmniLight3D = null
	for l in luci:
		if l is OmniLight3D and absf(l.global_position.x - MURO_X) < 1.0 and (lampada == null
				or l.global_position.distance_to(o.global_position) < lampada.global_position.distance_to(o.global_position)):
			lampada = l as OmniLight3D
	print("VERSIONI strato nuovo nel codice: %s; torre_A strati %x; lampada %s a %s, ombra %s, caster mask %x" % [con_strato,
		torre_a.layers, lampada.get_path(), lampada.global_position, lampada.shadow_enabled, lampada.shadow_caster_mask])
	var est: Array[Light3D] = []
	for l in luci:
		print("VERSIONI luce %s %s a %s ombra %s caster %x cull %x strati %x" % [torre.get_path_to(l), l.get_class(),
			l.global_position, l.shadow_enabled, l.shadow_caster_mask, l.light_cull_mask, l.layers])
		if l is OmniLight3D and l.shadow_enabled and absf(l.global_position.x - MURO_X) < 1.0:
			est.append(l)
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.set_physics_process(false)
	var lp := lampada.global_position
	var c := o.centro_vetro()
	var n := o.normale()
	var lato := n.cross(Vector3.UP).normalized()
	var dietro := c - n * 1.8
	var box := torre_a.global_transform * torre_a.get_aabb()
	var centro := box.get_center()
	print("VERSIONI torre_A aabb %s" % box)
	var viste := [
		["muro", POSTO_TORRE, Vector3(MURO_X, lp.y + 0.4, lp.z + 0.6)],
		["fronte", POSTO_TORRE, c],
		["condotte_lato", dietro + lato * 3.6 - OCCHI, dietro + lato * 1.6],
		["condotte_altro_lato", dietro - lato * 3.6 - OCCHI, dietro - lato * 1.6],
		["condotte_sotto", dietro + lato * 3.0 + Vector3.DOWN * 4.5 - OCCHI, dietro + lato * 1.6 + Vector3.DOWN * 2.5],
		["condotte_lontano", c - n * 9.0 + lato * 2.0 + Vector3.UP * 1.0 - OCCHI, dietro],
		["larga_nord", POSTO_LONTANO, POSTO_LONTANO + OCCHI + Vector3(0, 1.5, -8)],
		["larga_sud", POSTO_LONTANO, POSTO_LONTANO + OCCHI + Vector3(0, 1.5, 8)],
		["larga_ovest", POSTO_LONTANO, POSTO_LONTANO + OCCHI + Vector3(-8, 2.0, 0)],
		["larga_est_su", POSTO_LONTANO, POSTO_LONTANO + OCCHI + Vector3(4, 6.0, 0)],
	]
	# una vista per ogni luce con l'ombra (e per le lampade del muro est, che nella 0.3.15 non l'avevano): 3 m verso il
	# centro della torre, guardando 1 m sotto la luce; il nome dalla posizione, uguale in tutte le versioni
	var corte := OS.get_environment("VISTE_CORTE") != ""
	var nome_lampada := ""
	for l in luci:
		var lq := l.global_position
		var del_muro_est := l is OmniLight3D and absf(lq.x - MURO_X) < 1.0
		if not (l.shadow_enabled or del_muro_est) or (corte and not del_muro_est):
			continue
		var verso := Vector3(centro.x - lq.x, 0.0, centro.z - lq.z)
		verso = verso.normalized() if verso.length() > 0.1 else Vector3.LEFT
		var nome := "luce_%s_%d_%d_%d" % ["omni" if l is OmniLight3D else "spot", roundi(lq.x), roundi(lq.y), roundi(lq.z)]
		if l == lampada:
			nome_lampada = nome
		viste.append([nome, lq + verso * 3.0 + Vector3.DOWN * 0.3 - OCCHI, lq + Vector3.DOWN * 1.0])
	if OS.get_environment("VISTE_CORTE") == "2":
		# (solo il muro, l'oblò di fronte e le condotte)
		viste = viste.slice(0, 6)
	print("VERSIONI FASE viste come nel codice (%d)" % viste.size())
	var strati_a := torre_a.layers
	var maschere := {}
	for l in est:
		maschere[l] = l.shadow_caster_mask
	var rumore := ["muro", "fronte", "larga_nord", nome_lampada]
	var pipe2 := _pipeline()
	for v in viste:
		await _vista(v)
		var mis := lp if v[0] == "muro" else Vector3.INF
		await _scatto(v[0], mis, Vector3.INF)
		if con_strato:
			# com'era nella 0.3.16 (torre_A sullo strato 1, maschera piena), poi di nuovo com'è nel codice
			torre_a.layers = 1
			for l in est:
				l.shadow_caster_mask = 0xFFFFF
			await _fotogrammi(24)
			await _scatto("%s_come_0316" % v[0], mis, Vector3.INF)
			torre_a.layers = strati_a
			for l in est:
				l.shadow_caster_mask = maschere[l]
			await _fotogrammi(24)
			if v[0] in rumore:
				await _scatto("%s_di_nuovo" % v[0], mis, Vector3.INF)
	var pipe3 := _pipeline()
	print("VERSIONI FASE viste: pipeline +%d / +%d" % [pipe3[0] - pipe2[0], pipe3[1] - pipe2[1]])
	# lei nell'oblò, come in tests/scatti_oblo_torre.gd
	print("VERSIONI FASE lei")
	var pipe5 := _pipeline()
	p.teleport(POSTO_LONTANO)
	await _fotogrammi(4)
	p.look_at_point(c + Vector3.DOWN * 0.1)
	o._mostra()
	await _fotogrammi(90)
	await _scatto("lei_da_lontano", Vector3.INF, c)
	p.teleport(POSTO_TORRE)
	await _fotogrammi(4)
	p.look_at_point(c + Vector3.DOWN * 0.1)
	await _fotogrammi(40)
	await _scatto("lei_da_vicino", Vector3.INF, c)
	var pipe6 := _pipeline()
	print("VERSIONI FASE lei: pipeline +%d / +%d" % [pipe6[0] - pipe5[0], pipe6[1] - pipe5[1]])
	print("VERSIONI fine")
	get_tree().quit()


func _vista(v: Array) -> void:
	p.teleport(v[1])
	await _fotogrammi(4)
	p.look_at_point(v[2])
	await _fotogrammi(24)


func _pipeline() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _fotogrammi(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _media(img: Image, s: Vector2, mezzo: int) -> Color:
	var r := Rect2i(Vector2i(s) - Vector2i(mezzo, mezzo), Vector2i(mezzo * 2, mezzo * 2)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var somma := Color(0, 0, 0, 0)
	var q := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			somma += img.get_pixel(x, y)
			q += 1
	return somma / maxf(q, 1)


func _scatto(nome: String, lampada: Vector3, vetro: Vector3) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(cartella.path_join(nome + ".png"))
	var misura := ""
	var cam := get_viewport().get_camera_3d()
	if lampada != Vector3.INF:
		for k in [["sopra_sinistra", Vector3(MURO_X - 0.02, lampada.y + 0.35, lampada.z + 0.8)],
				["sopra", Vector3(MURO_X - 0.02, lampada.y + 0.6, lampada.z)]]:
			var s := cam.unproject_position(k[1])
			misura += " %s R %.0f (a %s)" % [k[0], _media(img, s, 20).r * 255.0, Vector2i(s)]
	if vetro != Vector3.INF:
		var s := cam.unproject_position(vetro)
		var m := _media(img, s, 60)
		misura += " vetro RGB %.0f %.0f %.0f (a %s)" % [m.r * 255.0, m.g * 255.0, m.b * 255.0, Vector2i(s)]
	print("VERSIONI scatto %s%s" % [nome, misura])
