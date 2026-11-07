extends Node
## Collaudo finale 0.3.21 (enigmi): il fondo nero dietro la porta di servizio del bacino (SalaInseguimento._fondo_porta)
## dagli occhi del giocatore. La sala della torre con le condotte, come nel gioco (luci del blackout, ambiente della sala);
## il tunnel non c'è (AttesaZone "tunnel" non pronta): scatti dai punti di ripartenza delle condotte che vedono il vano,
## dal bacino e da vicino. Poi il tunnel entra come lo mette la sala (SalaSottomarino costruito a pezzi, poi
## AttesaZone.pronta), con un fotogramma ogni 3 dal bacino durante la costruzione e il passaggio; poi gli stessi scatti.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd --
##   <questo> <cartella>

const VANO := Vector3(40.4, -28.925, -5.0)

var _cartella := ""
var _cam: Camera3D
var _ins: SalaInseguimento
var _n := 0


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _salva(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join(nome + ".jpg"), 0.9)


func _scatto(nome: String, da: Vector3, verso: Vector3, fov := 75.0) -> void:
	_cam.fov = fov
	_cam.global_position = da
	_cam.look_at(verso, Vector3.UP)
	await _frames(12)
	await _salva(nome)
	print("SCATTO %s (fondi %d, tunnel pronto %s)" % [nome, _fondi(), AttesaZone.e_pronta(&"tunnel")])


func _fondi() -> int:
	return get_tree().root.find_children("FondoPortaServizio", "", true, false).size()


func _punti() -> Array:
	# [nome, occhi, verso]: i punti di ripartenza delle condotte da cui si vede il vano, il bacino e da vicino
	var out := []
	var w := get_viewport().find_world_3d()
	for c in _ins.find_children("Checkpoint_*", "", true, false):
		var o := (c as Checkpoint).get_spawn_transform().origin + Vector3.UP * 1.6
		var visti := 0
		for dz in [-0.6, 0.0, 0.6]:
			for dy in [-0.9, 0.0, 0.9]:
				if w.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(o, VANO + Vector3(0.02, dy, dz))).is_empty():
					visti += 1
		print("PUNTI: %s, occhi in %s, a %.1f m dal vano: %d punti del vano su 9" % [c.name, o.snapped(Vector3.ONE * 0.01), o.distance_to(VANO), visti])
		if visti > 0:
			out.append(["ripartenza_%s" % String(c.name).trim_prefix("Checkpoint_"), o, VANO])
	var bc: Array = _ins.dati["bacino"]["rett"]
	var fondo := float(_ins.dati["bacino"]["fondo"])
	var centro := Vector3((bc[0] + bc[2]) * 0.5, fondo + 1.65, -(bc[1] + bc[3]) * 0.5)
	out.append(["bacino_mezzo", centro, VANO])
	out.append(["vicino_1m", VANO + Vector3(1.0, -0.2, 0.0), VANO + Vector3(-1.0, -0.3, 0.0)])
	out.append(["vicino_40cm", VANO + Vector3(0.4, -0.2, 0.0), VANO + Vector3(-1.0, -0.2, 0.0)])
	out.append(["filo_muro_sud", VANO + Vector3(0.35, 0.0, 1.1), VANO + Vector3(-0.05, 0.0, 0.75)])
	out.append(["filo_muro_nord", VANO + Vector3(0.35, 0.0, -1.1), VANO + Vector3(-0.05, 0.0, -0.75)])
	out.append(["filo_sopra", VANO + Vector3(0.35, 1.3, 0.0), VANO + Vector3(-0.05, 1.075, 0.0)])
	return out


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_fondo_porta"
	DirAccess.make_dir_recursive_absolute(_cartella)
	DirAccess.make_dir_recursive_absolute(_cartella.path_join("passaggio"))
	AttesaZone.non_pronta(&"tunnel")
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	_ins = torre.inseguimento as SalaInseguimento
	for i in 1200:
		await get_tree().physics_frame
		if _ins.costruita:
			break
	for i in 30:
		await get_tree().physics_frame
	if _ins.lei:
		_ins.lei.visible = false
	var fondi := get_tree().root.find_children("FondoPortaServizio", "", true, false)
	print("FONDO: condotte costruite %s, fondi %d%s" % [_ins.costruita, fondi.size(), (" in %s" % (fondi[0] as Node3D).global_position.snapped(Vector3.ONE * 0.001)) if fondi.size() > 0 else ""])
	_cam = Camera3D.new()
	_cam.near = 0.05
	add_child(_cam)
	_cam.make_current()
	var punti := _punti()
	for p in punti:
		await _scatto("prima_" + p[0], p[1], p[2])
	# il tunnel come lo mette la sala: a pezzi, poi pronto
	var bacino: Array = punti.filter(func(x): return x[0] == "bacino_mezzo")[0]
	_cam.global_position = bacino[1]
	_cam.look_at(bacino[2], Vector3.UP)
	var tun := (load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene).instantiate() as Node3D
	tun.name = "SalaSottomarino"
	add_child(tun)
	var finito := [false]
	var costruisci := func():
		await tun.call(&"costruisci_a_pezzi")
		AttesaZone.pronta(&"tunnel")
		print("FONDO: tunnel costruito e pronto, fondi %d" % _fondi())
		finito[0] = true
	costruisci.call()
	var k := 0
	var dopo := 0
	while dopo < 45 and k < 3000:
		await get_tree().process_frame
		if k % 3 == 0:
			await _salva("passaggio/%04d" % _n)
			print("PASSAGGIO %04d: fotogramma %d, fondi %d, tunnel pronto %s" % [_n, k, _fondi(), AttesaZone.e_pronta(&"tunnel")])
			_n += 1
		if finito[0]:
			dopo += 1
		k += 1
	await _frames(30)
	for p in punti:
		await _scatto("dopo_" + p[0], p[1], p[2])
	print("FONDO: FINE")
	get_tree().quit()
