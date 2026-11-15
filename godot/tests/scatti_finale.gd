extends Node
## Scatti del finale del tunnel (build 0.5.0) dagli occhi del giocatore vero, nella camera stagna: chiude il portello e
## si scatta a ogni tappa (appena girato, coi due passi fatti, sul foglio), più la stanza vuota prima di chiudere.
## Per il collaudo e per il coordinatore.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 30 --script res://tests/run.gd -- res://tests/scatti_finale.gd <cartella>

var cartella := "/tmp/scatti_finale"
var sala: SalaSottomarino
var _pl: Player


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _scatta(nome: String) -> void:
	var f := cartella.path_join(nome + ".jpg")
	get_viewport().get_texture().get_image().save_jpg(f, 0.9)
	print("scatto -> ", f)


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.009
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	sala = SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	sala.costruisci()
	_pl = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(_pl)
	var L := sala.lunghezza()
	var d := sala.direzione(L)
	var sg := sala.piano + SalaSottomarino.SOGLIA
	var dentro := sala.punto(L) + d * 1.2
	dentro.y = sg + 0.05
	await _fotogrammi(2)
	_pl.water_pack.set_equipped(true, false)
	_pl.teleport(dentro, atan2(-d.x, -d.z))   # (di spalle al portello: guarda la stanza)
	await _fotogrammi(60)
	_scatta("00_stanza_vuota")
	_pl.teleport(dentro, atan2(d.x, d.z))     # (verso il portello)
	await _fotogrammi(10)
	var fatte := {}
	sala.fase_finale_cambiata.connect(func(f: String): fatte[f] = Engine.get_process_frames())
	sala.chiudi_portello()
	var t0 := Time.get_ticks_msec()
	while not fatte.has("fermi") and Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
	await _fotogrammi(12)
	_scatta("01_appena_girato")
	while not fatte.has("porge") and Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
	while not fatte.has("foglio") and Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
	_scatta("02_due_passi")
	while sala.fase_finale == "foglio" and Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		if Engine.get_process_frames() - int(fatte["foglio"]) == int(30 * (sala.finale_abbassa + 1.5)):
			_scatta("03_sul_foglio")
	print("fasi: ", fatte)
	get_tree().quit()
