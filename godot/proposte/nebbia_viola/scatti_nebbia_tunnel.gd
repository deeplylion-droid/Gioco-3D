extends Node
## Scatti della prova della nebbia viola (NebbiaViolaProva) nell'inseguimento del tunnel sottomarino (richiesta
## dell'utente del 29 ottobre: la variante B, "ridotta di più", anche lì). La nebbia e i suoi valori sono quelli di
## grafica-2, così come sono: qui solo gli scatti.
## Come nel gioco: il riscaldamento della schermata di caricamento, poi il tunnel costruito a pezzi col suo riscaldamento,
## a fotogrammi fissi; l'ambiente e la camera della sala (il tunnel sta nella sala). Per ogni punto di vista, dagli occhi
## del giocatore (1,6 m), lo scatto senza nebbia e con la B, dalla stessa camera. Per l'alone: le lampade del tunnel nella
## vista (le più vicine, fino a 4) e la luce rosa di lei quando è nell'inquadratura.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 30 --script res://tests/run.gd -- res://proposte/nebbia_viola/scatti_nebbia_tunnel.gd <cartella>

## La variante B di grafica-2 (docs/proposte/nebbia_viola/LEGGIMI.md): forza, lontano, oltre, cala.
const B := [1.2, 4.5, 1.8, 0.8]
## [s, lato, quota degli occhi, s guardato, lato guardato, quota guardata, campo visivo, s di lei (o -1)]
## (come tests/scatti_sottomarino.gd: lato -1 la banchina sinistra, 1 la destra, frazioni del canale fra -1 e 1).
const VISTE := {
	"1_inizio": [4.0, -1.0, 1.6, 20.0, -0.3, 1.0, 75.0, -1.0],
	"2_gommoni_lei": [74.0, -1.0, 1.6, 64.0, 0.0, 1.2, 75.0, 69.0],
	"3_galleria": [199.0, -1.0, 1.6, 203.8, -1.0, 0.6, 70.0, -1.0],
}


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[1]
	var solo: PackedStringArray = OS.get_cmdline_user_args()[2].split(",", false) if OS.get_cmdline_user_args().size() > 2 else PackedStringArray()
	DirAccess.make_dir_recursive_absolute(out)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	# il riscaldamento della schermata di caricamento
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	var r := RiscaldamentoShader.new()
	add_child(r)
	while not r.concluso:
		await get_tree().process_frame
	r.queue_free()
	# l'ambiente e la camera della sala, dove sta il tunnel
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var sala := (load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene).instantiate() as SalaSottomarino
	add_child(sala)
	await sala.costruisci_a_pezzi()
	await _frames(20)
	var cam := Camera3D.new()
	cam.near = 0.05
	add_child(cam)
	cam.current = true
	var nebbia := NebbiaViolaProva.new()
	add_child(nebbia)
	nebbia.su(cam)
	nebbia.forza = B[0]
	nebbia.imposta(&"lontano", B[1])
	nebbia.imposta(&"oltre", B[2])
	nebbia.imposta(&"cala", B[3])
	nebbia.quota = sala.piano
	var occhi := Node3D.new()
	add_child(occhi)
	for nome in VISTE:
		if not solo.is_empty() and not solo.has(nome):
			continue
		var v: Array = VISTE[nome]
		cam.fov = v[6]
		cam.look_at_from_position(_occhio(sala, v[0], v[1], v[2]), _occhio(sala, v[3], v[4], v[5]))
		occhi.global_position = cam.global_position
		var con_lei: bool = float(v[7]) >= 0.0 and sala.lei_tunnel != null
		if sala.lei:
			sala.lei.visible = false
		if con_lei:
			# lei che insegue nel canale: risale dall'acqua davanti alla camera e la guarda (come tests/misura_tunnel_lei.gd)
			var dove := sala.punto(float(v[7]))
			dove.y = sala.acqua
			sala.lei_tunnel.riemergi(dove, cam.global_position - dove)
			await _frames(150)
		await _frames(30)
		nebbia.imposta_luci(_luci(sala, cam, con_lei))
		nebbia.attiva = false
		await _frames(30)
		await _scatto(out.path_join("%s_senza.jpg" % nome))
		nebbia.attiva = true
		await _frames(30)
		await _scatto(out.path_join("%s_nebbia_B.jpg" % nome))
	get_tree().quit()


## Le luci dell'alone: la luce rosa di lei se si vede, poi le lampade del tunnel davanti alla camera, le più vicine
## (fino a 4 in tutto), a forza 0,18 come nell'infermeria di grafica-2.
func _luci(sala: SalaSottomarino, cam: Camera3D, con_lei: bool) -> Array:
	var scelte: Array = []
	var avanti := -cam.global_basis.z
	if con_lei:
		for l in sala.lei_tunnel.find_children("*", "OmniLight3D", true, false):
			var lu := l as Light3D
			if lu.is_visible_in_tree() and not cam.is_position_behind(lu.global_position):
				scelte.append([lu.global_position, lu.light_color, 0.18])
				print("NEBBIA luce di lei %s a %s" % [lu.light_color, lu.global_position.snapped(Vector3.ONE * 0.01)])
	var lampade: Array = []
	for n in sala.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l is DirectionalLight3D or not l.is_visible_in_tree() or l.light_energy <= 0.0:
			continue
		if (sala.lei and sala.lei.is_ancestor_of(l)) or (sala.lei_tunnel and sala.lei_tunnel.is_ancestor_of(l)):
			continue
		var d := l.global_position - cam.global_position
		if d.length() > 16.0 or d.normalized().dot(avanti) < 0.3:
			continue
		lampade.append([d.length(), l])
	lampade.sort_custom(func(a, b): return a[0] < b[0])
	for x in lampade:
		if scelte.size() >= 4:
			break
		var l := x[1] as Light3D
		scelte.append([l.global_position, l.light_color, 0.18])
		print("NEBBIA lampada %s a %.1f m, colore %s" % [l.name, x[0], l.light_color])
	return scelte


func _occhio(sala: SalaSottomarino, s: float, lato: float, su: float) -> Vector3:
	var di_lato := lato * sala.canale if absf(lato) < 0.99 else signf(lato) * (sala.canale + sala.banchina * 0.5)
	return sala.punto(s) + sala.destra(s) * di_lato + Vector3.UP * (sala.piano - sala.acqua + su)


func _scatto(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(file, 0.9)
	print("salvato ", file)
