extends Node
## I colori del cartello delle pozze (infermeria, accanto alla porta nord) contro quelli delle pozze, dagli occhi del
## giocatore, col renderer vero, nella Risalita della scena di prova (come tests/collaudo/pozze_giro.gd del collaudo:
## ambiente della sala, senza GI, nebbia volumetrica e SSIL se non c'è VERO=1, luci del blackout).
## Misura come il collaudo il colore medio sullo schermo al centro dei tre quadratini (viola, arancione, turchese) e
## dello smalto, da 1,5, 0,8 e 0,45 m, e al centro delle pozze dalla passerella sud; stampa RGB e tinta, saturazione,
## luminosità (COLORI:).
## Le varianti (terzo argomento, separate da virgole; senza, solo "gioco") cambiano il faretto, il materiale e la texture
## sul posto, per provarle in un giro solo:
##  - gioco: com'è nel gioco;
##  - altre: le voci di VARIANTI qui sotto.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/colori_cartello_pozze.gd <cartella> [varianti] [texture.png]

## nome -> [energia, colore, distanza dell'attacco dal muro (m), angolo, roughness, texture nuova]
## (null: com'è nel gioco)
const VARIANTI := {
	"gioco": [null, null, null, null, null, false],
	"bianco_2": [2.0, Color(1, 1, 1), null, null, null, false],
	"lontano_2": [2.0, Color(1, 1, 1), 1.2, 15.0, null, false],
	"lontano_3": [3.0, Color(1, 1, 1), 1.2, 15.0, null, false],
	"lontano_3_opaco": [3.0, Color(1, 1, 1), 1.2, 15.0, 0.75, false],
	"lontano_4_opaco": [4.0, Color(1, 1, 1), 1.2, 15.0, 0.75, false],
	"lontano_3_opaco_tex": [3.0, Color(1, 1, 1), 1.2, 15.0, 0.75, true],
	"lontano_4_opaco_tex": [4.0, Color(1, 1, 1), 1.2, 15.0, 0.75, true],
	"bianco_2_tex": [2.0, Color(1, 1, 1), null, null, null, true],
	"bianco_3_opaco_tex": [3.0, Color(1, 1, 1), null, null, 0.75, true],
	"lontano_2_opaco_tex": [2.0, Color(1, 1, 1), 1.2, 15.0, 0.75, true],
}

var p: Player
var cart := ""
var varianti: PackedStringArray = []
var tex_nuova := ""
var _k := 0
var ris: Node3D
var st: Node3D
var e: Node3D
var inf: Node3D
var cam: Camera3D
var luce: SpotLight3D
var faccia: MeshInstance3D
var _orig := {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	varianti = (a[2] if a.size() > 2 else "gioco").split(",")
	tex_nuova = a[3] if a.size() > 3 else ""
	DirAccess.make_dir_recursive_absolute(cart)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> Image:
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	im.save_png(cart.path_join("%03d_%s.png" % [_k, nome]))
	_k += 1
	return im


func S(v: Vector3) -> Vector3:
	return st.to_global(v)


func I(v: Vector3) -> Vector3:
	return inf.to_global(v)


func _guarda(da: Vector3, verso: Vector3, nome: String, accovacciato := false) -> Image:
	p.teleport(da + Vector3.UP * 0.05)
	if accovacciato:
		Input.action_press(&"crouch")
	await _frames(30)
	p.look_at_point(verso)
	await _frames(8)
	var im := await _scatto(nome)
	Input.action_release(&"crouch")
	return im


## Il punto del mondo [param w] sull'immagine dello schermo: unproject_position dà le coordinate della finestra di base
## (1280x720, stretch canvas_items), l'immagine è grande quanto la finestra vera.
func _px(im: Image, w: Vector3) -> Vector2:
	var c := get_viewport().get_camera_3d()
	return c.unproject_position(w) * Vector2(im.get_size()) / get_viewport().get_visible_rect().size


## Il colore medio di un quadrato di lato 2 [param mezzo] (m) attorno a [param w], sul piano del cartello (lungo
## [param lato] e in verticale).
func _media_area(im: Image, w: Vector3, lato: Vector3, mezzo: float) -> Color:
	var r := maxi(1, roundi(_px(im, w).distance_to(_px(im, w + lato * mezzo))))
	return _media(im, _px(im, w), r)


func _media(im: Image, px: Vector2, r := 4) -> Color:
	var s := Color(0, 0, 0, 0)
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := int(px.x) + dx
			var y := int(px.y) + dy
			if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
				s += im.get_pixel(x, y)
				n += 1
	return s / maxf(n, 1)


func _c(c: Color) -> String:
	return "(%d, %d, %d) tinta %d° sat %.2f lum %.2f" % [int(c.r * 255), int(c.g * 255), int(c.b * 255),
			roundi(c.h * 360.0), c.s, c.v]


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	p = GameState.player
	cam = p.get_viewport().get_camera_3d()
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	if not OS.has_environment("VERO"):
		env.environment.sdfgi_enabled = false
		env.environment.volumetric_fog_enabled = false
		env.environment.ssil_enabled = false
	get_tree().current_scene.add_child(env)
	ris = get_tree().current_scene.get_node(^"Risalita") as Node3D
	for nome in ["BambinoCorridoioFiume"]:
		var b := ris.find_child(nome, true, false) as Node3D
		if b:
			b.process_mode = Node.PROCESS_MODE_DISABLED
			b.visible = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for i in 3600:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 300 and ris.get(&"pozze") != null:
			break
	st = ris.get(&"pozze") as Node3D
	inf = ris.get(&"infermeria") as Node3D
	e = st.get_node(^"EnigmaPozze") as Node3D
	luce = inf.get_node(^"FarettoCartelloPozze/Luce") as SpotLight3D
	faccia = inf.find_child("CartelloPozzeFaccia", true, false) as MeshInstance3D
	var m := faccia.get_active_material(0) as StandardMaterial3D
	_orig = {"energia": luce.light_energy, "colore": luce.light_color, "xf": luce.global_transform,
			"angolo": luce.spot_angle, "portata": luce.spot_range, "rough": m.roughness, "tex": m.albedo_texture}
	print("COLORI: luci %s; faretto in %s, energia %.2f, angolo %.1f; GI e nebbia %s" % [GameState.luci,
			inf.to_local(luce.global_position).snapped(Vector3.ONE * 0.01), luce.light_energy, luce.spot_angle,
			"accese" if OS.has_environment("VERO") else "spente"])
	var interr := inf.get_node_or_null(^"Interruttore")
	if interr:
		interr.set(&"powered", true)
	p.teleport(I(Vector3(-1.0, 0.05, -1.0)))
	await _frames(60)
	for v in varianti:
		_applica(v)
		await _frames(4)
		await _cartello(v)
	await _pozze()
	print("COLORI: finito")
	get_tree().quit()


func _applica(nome: String) -> void:
	var d: Array = VARIANTI[nome]
	var m := faccia.get_active_material(0) as StandardMaterial3D
	luce.light_energy = d[0] if d[0] != null else _orig["energia"]
	luce.light_color = d[1] if d[1] != null else _orig["colore"]
	luce.spot_angle = d[3] if d[3] != null else _orig["angolo"]
	m.roughness = d[4] if d[4] != null else _orig["rough"]
	if d[2] != null:
		# il faretto attaccato al soffitto più lontano dal muro, puntato sul cartello (solo la luce: per la misura)
		var testa := I(Vector3(-2.95, 3.0 - 0.16, -3.2 + float(d[2])))
		var bersaglio := I(Vector3(-2.95, 1.52, -3.2))
		var dir := (bersaglio - testa).normalized()
		luce.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), testa + dir * 0.125)
		luce.spot_range = testa.distance_to(bersaglio) + 1.5
	else:
		luce.global_transform = _orig["xf"]
		luce.spot_range = _orig["portata"]
	if d[5] and tex_nuova != "":
		var im := Image.load_from_file(tex_nuova)
		im.generate_mipmaps()
		m.albedo_texture = ImageTexture.create_from_image(im)
	else:
		m.albedo_texture = _orig["tex"]
	print("COLORI: variante %s: energia %.2f, colore %s, faretto a %.2f m dal muro, angolo %.1f, roughness %.2f, texture %s" % [
			nome, luce.light_energy, luce.light_color, absf(inf.to_local(luce.global_position).z + 3.2), luce.spot_angle,
			m.roughness, tex_nuova if d[5] and tex_nuova != "" else "del gioco"])


func _cartello(v: String) -> void:
	var c := I(Vector3(-2.95, 1.5, -3.2))
	var quad := I(Vector3(-2.95, 1.73 - 0.405, -3.2 + 0.0085))
	var lato := (I(Vector3(1, 0, 0)) - I(Vector3.ZERO)).normalized()
	for d in [1.5, 0.8, 0.45]:
		var da := I(Vector3(-2.95, 0, -3.2 + d))
		var im := await _guarda(da, c, "%s_cartello_%.2fm" % [v, d], d < 0.6)
		for k in [-1, 0, 1]:
			var w: Vector3 = quad + lato * (0.092 * float(k))
			if cam.is_position_behind(w):
				continue
			# il centro del quadratino, 3 cm per lato (la cera e i buchi del pastello insieme, come li vede l'occhio)
			print("COLORI: %s da %.2f m, %s: %s" % [v, d, ["viola", "arancione", "turchese"][k + 1],
					_c(_media_area(im, w, lato, 0.015))])
		print("COLORI: %s da %.2f m, smalto: %s" % [v, d, _c(_media_area(im, I(Vector3(-2.95, 1.43, -3.2 + 0.0085)) + lato * 0.11, lato, 0.015))])
	# arrivando verso la porta, come lo vede il giocatore
	await _guarda(I(Vector3(-1.4, 0, -1.6)), c, "%s_cartello_diagonale" % v)


func _pozze() -> void:
	for c2 in ["viola", "arancione", "turchese", "rosa", "bianco_latte"]:
		var t := _pozza_sud(c2)
		var su := Vector3(t.global_position.x, t.get_surface_global_y(), t.global_position.z)
		var im := await _guarda(S(Vector3(st.to_local(t.global_position).x, 0, 3.4)), su, "pozza_%s" % c2)
		print("COLORI: pozza %s dalla passerella sud, al centro: %s" % [c2, _c(_media(im, _px(im, su), 8))])


func _pozza_sud(c: String) -> WaterTank:
	var migliore: WaterTank = null
	for t: WaterTank in e.call(&"pozze_del_colore", c):
		if migliore == null or t.position.z > migliore.position.z:
			migliore = t
	return migliore
