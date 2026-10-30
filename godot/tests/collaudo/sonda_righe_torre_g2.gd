extends Node
## Sonda (grafica-2): da dove vengono la luce di lei sulla faccia della cisterna dell'oblò della torre (dalla sala delle
## condotte) e le due righe rosse sul suo lato. Nella torre costruita come nel gioco, con lei comparsa e ferma, dalla
## vista "condotte_altro_lato" di oblo_bias_g2.gd: una variante alla volta (nebbia, ombre, la vasca interna, luce di lei
## spenta), scatto e misura del rosso nella riga alta, nella riga bassa e sulla parete; poi la riga bassa: il punto del
## mondo dove sta e le luci vicine, spente una alla volta.
## Uso (sotto il lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/sonda_righe_torre_g2.gd <cartella>

const PLAYER := "res://scenes/player/player.tscn"
const POSTO_TORRE := Vector3(38.0, -19.98, -13.4)
var cartella := ""
var p: Player
var env: WorldEnvironment


func _ready() -> void:
	cartella = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	env = WorldEnvironment.new()
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
	var o := torre.oblo
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	o.set_process(false)
	p.teleport(POSTO_TORRE)
	await _fotogrammi(4)
	p.look_at_point(o.global_position + Vector3.DOWN * 0.15)
	await _fotogrammi(150)
	o._mostra()
	await _fotogrammi(90)
	var luce: OmniLight3D = o.lei.get(&"_luce")
	# la vista dell'altro lato (come oblo_bias_g2.gd)
	var c := o.centro_vetro()
	var n := o.normale()
	var lato := n.cross(Vector3.UP).normalized()
	var dietro := c - n * 1.8
	p.set_physics_process(false)
	p.teleport(dietro - lato * 3.6 - Vector3.UP * 1.6)
	p.look_at_point(dietro - lato * 1.6)
	print("SONDA luce di lei a ", luce.global_position, " vetro ", c, " normale ", n)
	var interno := o.find_child("struttura_vasca_oblo", true, false) as GeometryInstance3D
	# la riga alta: dove sta nel mondo
	var cam := p.camera
	for x in [650, 750, 850]:
		for y in [122, 126, 130]:
			var da := cam.project_ray_origin(Vector2(x, y))
			var dir := cam.project_ray_normal(Vector2(x, y))
			var q := PhysicsRayQueryParameters3D.create(da, da + dir * 30.0)
			var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
			if h:
				print("SONDA riga alta pixel %d,%d: punto %s su %s (normale %s)" % [x, y, h.position, (h.collider as Node).get_path(), h.normal])
	var struttura: Array = []
	for n2 in torre.find_children("*", "MeshInstance3D", true, false):
		if String(n2.get_path()).contains("InseguimentoStruttura"):
			struttura.append(n2)
	var nebbia := FogVolume.new()
	nebbia.size = Vector3(12, 10, 12)
	var fm := FogMaterial.new()
	fm.density = -1.0
	nebbia.material = fm
	add_child(nebbia)
	nebbia.global_position = dietro - n * 4.0
	nebbia.visible = false
	var varianti := [
		["base", func(): pass, func(): pass],
		["struttura_due_facce", func(): _ombra(struttura, GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED),
			func(): _ombra(struttura, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)],
		["lei_senza_ombre", func(): luce.shadow_enabled = false, func(): luce.shadow_enabled = true],
		["nebbia_di_lei_0", func(): luce.light_volumetric_fog_energy = 0.0, func(): luce.light_volumetric_fog_energy = 2.0],
		["nebbia_tolta_condotte", func(): nebbia.visible = true, func(): nebbia.visible = false],
		["lei_spenta", func(): luce.visible = false, func(): luce.visible = true],
	]
	for v in varianti:
		(v[1] as Callable).call()
		await _fotogrammi(40)
		await _misura(v[0])
		(v[2] as Callable).call()
	# dalla torre: lei con la nebbia della sua luce a 0 (si vede diversa?)
	p.teleport(POSTO_TORRE)
	p.look_at_point(c)
	await _fotogrammi(40)
	await _misura("torre_base")
	luce.light_volumetric_fog_energy = 0.0
	await _fotogrammi(40)
	await _misura("torre_nebbia_di_lei_0")
	luce.light_volumetric_fog_energy = 2.0
	nebbia.visible = true
	await _fotogrammi(40)
	await _misura("torre_nebbia_tolta_condotte")
	get_tree().quit()


func _ombra(lista: Array, modo: GeometryInstance3D.ShadowCastingSetting) -> void:
	for m in lista:
		(m as GeometryInstance3D).cast_shadow = modo


func _misura(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(cartella.path_join(nome + ".jpg"), 0.92)
	var alta := _rosso(img, Rect2i(0, 118, 1200, 14))
	var bassa := _rosso(img, Rect2i(0, 636, 700, 12))
	var parete := _media(img, Rect2i(100, 200, 900, 250))
	print("SONDA %-28s riga alta R %3d  riga bassa R %3d  parete R %.1f G %.1f B %.1f" % [nome, alta, bassa, parete.r * 255, parete.g * 255, parete.b * 255])


func _rosso(img: Image, r: Rect2i) -> int:
	var m := 0.0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x, 2):
			m = maxf(m, img.get_pixel(x, y).r)
	return int(m * 255)


func _media(img: Image, r: Rect2i) -> Color:
	var s := Color(0, 0, 0, 0)
	var k := 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			s += img.get_pixel(x, y)
			k += 1
	return s / k


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().process_frame
