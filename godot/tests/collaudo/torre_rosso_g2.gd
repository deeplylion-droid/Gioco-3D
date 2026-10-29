extends Node
## Scatti (grafica-2) del rosso dentro la vasca dell'oblò della torre (SalaTorre._rosso_vasca, scelta B dell'utente del
## 29 ottobre), con la camera vera del giocatore e la lancia, come oblo_righe_g2.gd: la torre costruita come nel gioco,
## lei comparsa e ferma. Dalla torre di fronte all'oblò, con la luce rossa della vasca a ogni energia di [energie]
## ("fronte_<energia>"), e dalle condotte sul lato della cisterna ("condotte_<energia>", con la prima e l'ultima). Senza
## la luce (una versione di prima, come la 0.3.15) scatta solo "fronte" e "condotte". Misura anche il rosso medio di lei
## e dell'acqua dietro (il riquadro del vetro) per il confronto.
## Uso (sotto il lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/torre_rosso_g2.gd <cartella> [0,0.3,0.6]

const PLAYER := "res://scenes/player/player.tscn"
const POSTO_TORRE := Vector3(38.0, -19.98, -13.4)
var cartella := ""
var energie: Array = [0.0, 0.3, 0.6, 1.0]
## Le prove: "x:y:z@energia" separate da ";" (posizione della luce nell'oblò); vuoto: solo le energie, al suo posto.
var prove: Array = []
var p: Player


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cartella = a[1]
	if a.size() > 2:
		energie = Array(a[2].split(",")).map(func(x): return float(x))
	if a.size() > 3:
		for t in a[3].split(";"):
			var pe := t.split("@")
			var xyz := pe[0].split(":")
			prove.append([Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2])), float(pe[1])])
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
	var prima := [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]
	await torre.prepara_materiali(get_viewport())
	torre.visible = true
	torre.process_mode = Node.PROCESS_MODE_INHERIT
	campioni.clear()
	var o := torre.oblo
	var rosso := o.get_node_or_null(^"RossoVasca") as OmniLight3D
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	o.set_process(false)
	p.teleport(POSTO_TORRE)
	await _fotogrammi(4)
	p.look_at_point(o.global_position + Vector3.DOWN * 0.15)
	await _fotogrammi(150)
	var base := _info()
	o._mostra()
	await _fotogrammi(90)
	var dopo_comparsa := _info()
	print("TORRE pipeline alla comparsa di lei: disegno +%d, specializzazione +%d (luce rossa nella vasca: %s)" % [
			dopo_comparsa[0] - base[0], dopo_comparsa[1] - base[1], rosso != null])
	p.set_physics_process(false)
	var c := o.centro_vetro()
	var n := o.normale()
	var lato := n.cross(Vector3.UP).normalized()
	var dietro := c - n * 1.8
	var condotte := [dietro - lato * 3.6 - Vector3.UP * 1.6, dietro - lato * 1.6]
	var lista: Array = energie if rosso else [null]
	if rosso and not prove.is_empty():
		lista = prove
	for k in lista.size():
		var e = lista[k]
		var nome := "" if e == null else "_%s" % str(e)
		if e is Array:
			rosso.position = e[0]
			rosso.light_energy = e[1]
			nome = "_%s_%s_%s@%s" % [e[0].x, e[0].y, e[0].z, e[1]]
		elif rosso:
			rosso.light_energy = float(e)
		p.teleport(POSTO_TORRE)
		p.look_at_point(o.global_position + Vector3.DOWN * 0.15)
		await _fotogrammi(30)
		await _scatto("fronte" + nome, true)
		if e == null or k == 0 or k == lista.size() - 1:
			p.teleport(condotte[0])
			p.look_at_point(condotte[1])
			await _fotogrammi(30)
			await _scatto("condotte" + nome, false)
	var fine := _info()
	print("TORRE pipeline dopo la comparsa, in tutti gli scatti: disegno +%d, specializzazione +%d" % [
			fine[0] - dopo_comparsa[0], fine[1] - dopo_comparsa[1]])
	get_tree().quit()


func _info() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _fotogrammi(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _scatto(nome: String, vetro: bool) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(cartella.path_join(nome + ".jpg"), 0.92)
	if vetro:
		# il riquadro del vetro (lei e l'acqua dietro), dove lo vede la camera
		var cam := p.camera
		var centro := cam.unproject_position((get_tree().root.find_child("ObloLei", true, false) as ObloLei).centro_vetro())
		if nome.begins_with("fronte") and nome.length() < 12:
			print("TORRE centro del vetro sullo schermo ", centro)
		var s := Color(0, 0, 0)
		var k := 0
		for y in range(int(centro.y) - 110, int(centro.y) + 110, 3):
			for x in range(int(centro.x) - 110, int(centro.x) + 110, 3):
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					s += img.get_pixel(x, y)
					k += 1
		s /= maxf(k, 1)
		# e il muro intorno all'oblò (sopra il vetro, fuori dalla cornice): quanto cambia la torre
		var m := Color(0, 0, 0)
		var km := 0
		for y in range(int(centro.y) - 330, int(centro.y) - 230, 4):
			for x in range(int(centro.x) - 200, int(centro.x) + 200, 4):
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					m += img.get_pixel(x, y)
					km += 1
		m /= maxf(km, 1)
		print("TORRE %-28s vetro: R %.1f G %.1f B %.1f   muro sopra: R %.1f G %.1f B %.1f" % [nome, s.r * 255, s.g * 255, s.b * 255, m.r * 255, m.g * 255, m.b * 255])
	else:
		print("TORRE scatto ", nome)
