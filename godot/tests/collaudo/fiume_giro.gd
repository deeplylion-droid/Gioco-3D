extends Node
## Collaudo riga del fiume (#130), dagli occhi del giocatore, prima e dopo: lungo tutti i tratti ogni PASSO m (di serie 8),
## sulla ciambella in piedi (1,65 m sopra il punto del tratto) e accovacciato (0,97), avanti, a sinistra e a destra
## (70°), guardando un po' in giù come mascotte; dalla banchina ai due lati del canale (3,6 m dal centro, occhi a 1,6,
## verso il centro del canale) ogni 2 PASSO; tre viste lontane; quattro viste delle pareti vicino alla ciambella
## ormeggiata. Con MAGENTA=1 lo sfondo è magenta pieno (niente cielo, niente nebbia) e per ogni scatto stampa i pixel
## magenta (buchi verso il cielo o il nero). Luci del blackout, ambiente ed esposizione della sala, preset alto.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/fiume_giro.gd <cartella>
## Scrive <cartella>/magenta.txt (nome e pixel) con MAGENTA=1.

const GIRO := 70.0
var cartella := "/tmp/fiume_giro"
var magenta := false
var cam: Camera3D
var _righe: Array[String] = []
var n := 0
## SOLO=<nomi separati da virgola>: fa solo quegli scatti (per esempio i residui magenta). RISALITA=1: carica tutta la
## risalita (fiume, corridoi, infermeria), come nel gioco, invece del fiume da solo.
var solo: PackedStringArray = []


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	magenta = OS.get_environment("MAGENTA") == "1"
	_run.call_deferred()


func _scatto(nome: String, da: Vector3, verso: Vector3) -> void:
	if not solo.is_empty() and not solo.has(nome):
		return
	cam.global_position = da
	cam.look_at(verso, Vector3.UP)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(cartella.path_join(nome + ".jpg"), 0.85)
	n += 1
	if magenta:
		var conta := 0
		var w := img.get_width()
		var h := img.get_height()
		for y in range(0, h, 2):
			for x in range(0, w, 2):
				var c := img.get_pixel(x, y)
				if c.r > 0.7 and c.b > 0.7 and c.g < 0.25:
					conta += 1
		_righe.append("%s %d" % [nome, conta])
		if conta > 0:
			print("MAGENTA %s %d" % [nome, conta])


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.BLACKOUT
	Grafica.applica_preset("alto")
	var we := WorldEnvironment.new()
	var env := (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	if magenta:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(1, 0, 1)
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.05, 0.05, 0.06)
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.glow_enabled = false
	we.environment = env
	if not magenta:
		we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(we)
	if OS.get_environment("SOLO") != "":
		solo = OS.get_environment("SOLO").split(",")
	var f: Node3D = null
	if OS.get_environment("RISALITA") == "1":
		Engine.set_meta(&"risalita_subito", true)
		var ris: Node3D = (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate()
		add_child(ris)
		for i in 20000:
			await get_tree().process_frame
			f = ris.get(&"fiume") as Node3D
			if f:
				break
		print("GIRO: risalita intera, fiume %s" % f)
	else:
		f = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
		add_child(f)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	var t0 := Time.get_ticks_msec()
	while not bool(f.get(&"costruita")) and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
	# NASCONDI_ACQUA=1: senza le superfici d'acqua (che col magenta riflettono lo sfondo): restano solo i buchi veri
	if OS.get_environment("NASCONDI_ACQUA") == "1":
		var nascoste := 0
		for mi in f.find_children("*", "GeometryInstance3D", true, false):
			if String(mi.name).to_lower().contains("acqua"):
				(mi as GeometryInstance3D).visible = false
				nascoste += 1
		print("GIRO: nascoste %d acque" % nascoste)
	if magenta:
		env.ssr_enabled = false
	for i in 120:
		await get_tree().process_frame
	var passo := OS.get_environment("PASSO").to_float() if OS.has_environment("PASSO") else 8.0
	var tratti := f.find_children("*", "TrattoFiume", true, false)
	print("GIRO: %d tratti, passo %.0f, magenta %s" % [tratti.size(), passo, magenta])
	for t: TrattoFiume in tratti:
		var lung := t.lunghezza()
		var s := 1.0
		var k := 0
		while s < lung:
			var d := t.direzione(s)
			d.y = 0.0
			d = d.normalized()
			for alt in [["piedi", 1.65], ["accovacciato", 0.97]]:
				var p := t.punto(s) + Vector3.UP * float(alt[1])
				for v in [["avanti", 0.0], ["sinistra", GIRO], ["destra", -GIRO]]:
					var dir := d.rotated(Vector3.UP, deg_to_rad(v[1]))
					await _scatto("%s_%03d_%s_%s" % [t.name, int(s), alt[0], v[0]], p, p + dir * 10.0 + Vector3.DOWN * 0.9)
			if k % 2 == 0:
				var c := t.punto(s)
				var lato := d.cross(Vector3.UP).normalized()
				for sl in [["banchina_dx", 1.0], ["banchina_sx", -1.0]]:
					var da := c + lato * 3.6 * float(sl[1])
					da.y = 1.6
					await _scatto("%s_%03d_%s" % [t.name, int(s), sl[0]], da, Vector3(c.x, -0.4, c.z))
			s += passo
			k += 1
	for v in [[Vector3(0.0, 14.0, -8.0), Vector3(0.0, -0.2, 14.0), "lontano_nord"], [Vector3(-8.0, 9.0, 0.0), Vector3(-30.0, -0.2, 0.0), "lontano_ovest"],
			[Vector3(10.0, 3.0, 12.0), Vector3(22.0, -0.2, 22.0), "banchina_est"]]:
		await _scatto(v[2], v[0], v[1])
	# le pareti vicino alla ciambella ormeggiata
	var ci := f.get_node_or_null(^"Ciambella") as Node3D
	if ci == null:
		for x in f.find_children("Ciambella", "Node3D", true, false):
			ci = x
	if ci:
		var c := ci.global_position
		print("GIRO: ciambella a %s" % c)
		for a in [0.0, 90.0, 180.0, 270.0]:
			var dir := Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a)))
			await _scatto("ciambella_%03d" % int(a), c + dir * 3.2 + Vector3.UP * 1.7, c + Vector3.DOWN * 0.3)
	if magenta:
		var fo := FileAccess.open(cartella.path_join("magenta.txt"), FileAccess.WRITE)
		for r in _righe:
			fo.store_line(r)
		fo.close()
	print("GIRO: %d scatti" % n)
	print("GIRO FINITO")
	get_tree().quit()
