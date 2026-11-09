extends Node
## Collaudo 0.3.24 (Polaroid appoggiate, 6dbafdfe): le Polaroid P05, P08, P10, P12 e P16 da vicino nel loro posto, con
## l'ambiente della sala e le luci del blackout. Per ognuna: dagli occhi in piedi (1,6 m sopra la foto, a 0,6 m),
## accovacciato (0,97 m, a 0,5 m) da due lati, radente (6 mm sopra la foto, a 22 cm) dai quattro lati e di lato (2 cm,
## a 25 cm) da due lati; i radenti e di lato con una lampadina sulla camera (le luci del blackout lì sono deboli).
## Stampa (PV:) la posizione e la misura di test_polaroid_appoggiate (fondo dalla superficie sotto, punti dentro).
## Zone:
##   sala: la sala ridotta (tests/scena_ridotta.gd, senza interni, ambienti tecnici, torre e risalita, ma con le
##         Polaroid), preset medio come scatti_polaroid_nuove: P05 sul fondo in pendenza della piscina, P08;
##   torre: la sala della torre da sola: P10 sul lettino, P12 sul grigliato;
##   fiume: il fiume costruito a pezzi, acceso: P16;
##   fiume_fermo: il fiume costruito nascosto e fermo, lasciato così 30 s, poi riacceso a pezzi: P16 (come
##         test_polaroid_fiume_ferma).
## Uso: xvfb-run ... --script res://tests/run.gd -- res://tests/collaudo/polaroid_vicine.gd <cartella> <zona>

const LEVEL := "res://scenes/sala_principale.tscn"
const APPOGGIATE := preload("res://tests/test_polaroid_appoggiate.gd")
const TOGLI_SALA := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Atmosfera", "Sala/TorreScivoli", "Sala/Dettagli", "Sala/AreaBimbi", "Vasca", "Gioco/LeiSbuca"]
const TOGLI_SALA2 := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Atmosfera", "Sala/TorreScivoli", "Sala/Dettagli", "Vasca", "Gioco/LeiSbuca"]
const TOGLI_SALA3 := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Atmosfera", "Sala/Dettagli", "Sala/AreaBimbi", "Sala/Piscina", "Piscina", "Vasca", "Gioco/LeiSbuca"]
const DELLA_ZONA := {"sala3": ["Polaroid08"], "sala2": ["Polaroid05", "Polaroid08"], "sala": ["Polaroid05", "Polaroid08"], "torre": ["Polaroid10", "Polaroid12"], "fiume": ["Polaroid16"],
		"fiume_fermo": ["Polaroid16"]}

var cart := ""
var zona := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secondi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().process_frame


func _scatto(cam: Camera3D, nome: String, da: Vector3, verso: Vector3) -> void:
	cam.global_position = da
	cam.look_at(verso, Vector3.UP)
	await _frames(10)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join("%s_%s.jpg" % [zona, nome]), 0.9)


func _fiume(fermo: bool) -> Node3D:
	var radice := Node3D.new()
	add_child(radice)
	var f := (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate() as Node3D
	f.name = "Fiume"
	f.set(&"costruzione_a_pezzi", true)
	if fermo:
		f.visible = false
		f.process_mode = Node.PROCESS_MODE_DISABLED
	radice.add_child(f)
	await f.call(&"costruisci_a_pezzi")
	return f


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	zona = a[2] if a.size() > 2 else "fiume"
	DirAccess.make_dir_recursive_absolute(cart)
	Engine.set_meta(&"precarica_torre_spento", true)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.applica_preset("basso" if zona == "sala3" else ("medio" if zona.begins_with("sala") else "alto"))
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var we := WorldEnvironment.new()
	var look := LookSala.new()
	we.environment = look.ambiente
	we.camera_attributes = look.attributi_camera
	look.free()
	get_tree().root.add_child(we)
	var scena: Node
	if zona.begins_with("sala"):
		get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci(LEVEL, TOGLI_SALA3 if zona == "sala3" else (TOGLI_SALA2 if zona == "sala2" else TOGLI_SALA)))
		while get_tree().current_scene == null or get_tree().current_scene == self:
			await get_tree().process_frame
		scena = get_tree().current_scene
		var giocatore := scena.get_node_or_null(^"Player") as Node3D
		if giocatore:
			giocatore.process_mode = Node.PROCESS_MODE_DISABLED
			giocatore.global_position = Vector3(12.0, 0.0, -18.0)
			var hud := giocatore.get_node_or_null(^"HUD")
			if hud:
				hud.set(&"visible", false)
		we.queue_free()
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
		await _secondi(8.0)
		# nella sala ridotta la sala non risulta mai costruita e la foto aspetta la sua zona: il calcolo del gioco
		# (adagia) chiamato qui, poi la posizione confrontata con quella della sala intera (test_polaroid_appoggiate)
		for nome in DELLA_ZONA[zona]:
			var f := scena.find_child(nome, true, false) as PolaroidPhoto
			if f:
				var prima := f.global_position
				f.adagia(scena)
				for i in 10:
					await get_tree().physics_frame
				print("PV: %s adagiata qui: da %s a %s" % [nome, prima.snappedf(0.0001), f.global_position.snappedf(0.0001)])
	elif zona == "torre":
		scena = (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate()
		add_child(scena)
		for i in 600:
			if bool(scena.get(&"costruita")):
				break
			await get_tree().process_frame
		await _secondi(5.0)
	elif zona == "fiume":
		scena = await _fiume(false)
		await _secondi(3.0)
	else:
		scena = await _fiume(true)
		var p0 := scena.find_child("Polaroid16", true, false) as Node3D
		var prima := p0.global_position if p0 else Vector3.ZERO
		print("PV: fiume fermo, P16 prima in %s; 30 s fermo" % prima.snappedf(0.0001))
		await _secondi(30.0)
		await AccensioneAPezzi.accendi(scena)
		scena.visible = true
		await _secondi(3.0)
		print("PV: fiume riacceso, P16 in %s (spostata di %.2f mm)" % [p0.global_position.snappedf(0.0001), p0.global_position.distance_to(prima) * 1000.0])
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.01
	get_tree().root.add_child(cam)
	cam.make_current()
	var lamp := OmniLight3D.new()
	lamp.omni_range = 3.0
	lamp.light_energy = 0.6
	lamp.shadow_enabled = true
	cam.add_child(lamp)
	lamp.position = Vector3(0.15, 0.25, 0)
	for nome in DELLA_ZONA[zona]:
		var ph := scena.find_child(nome, true, false) as PolaroidPhoto
		if ph == null:
			print("PV: %s non c'è" % nome)
			continue
		var m: Array = APPOGGIATE.misura(ph)
		var c := ph.global_position
		var su := ph.global_basis.y.normalized()
		print("PV: %s in %s, inclinata %.1f°, fondo dalla superficie sotto: più vicino %.2f mm, più lontano %.2f mm, punti dentro %d su %d" % [
				nome, c.snappedf(0.0001), rad_to_deg(su.angle_to(Vector3.UP)), float(m[0]) * 1000.0, float(m[1]) * 1000.0, int(m[2]), int(m[3])])
		var k: String = String(nome).trim_prefix("Polaroid")
		lamp.visible = false
		await _scatto(cam, "P%s_occhi" % k, c + Vector3(0.6, 1.6, 0.0), c)
		for g in [45, 225]:
			var d := Vector3(sin(deg_to_rad(g)), 0, cos(deg_to_rad(g)))
			await _scatto(cam, "P%s_accovacciato_%03d" % [k, g], c + d * 0.5 + Vector3.UP * 0.97, c)
		lamp.visible = true
		for g in [0, 90, 180, 270]:
			var d := Vector3(sin(deg_to_rad(g)), 0, cos(deg_to_rad(g)))
			await _scatto(cam, "P%s_radente_%03d" % [k, g], c + d * 0.22 + su * 0.006, c + su * 0.002)
		for g in [0, 180]:
			var d := Vector3(sin(deg_to_rad(g)), 0, cos(deg_to_rad(g)))
			await _scatto(cam, "P%s_lato2cm_%03d" % [k, g], c + d * 0.25 + su * 0.02, c + su * 0.003)
	print("PV: finito")
	get_tree().quit()
