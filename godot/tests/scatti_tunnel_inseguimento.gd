extends Node
## Scatti del tunnel sottomarino durante l'inseguimento, dagli occhi del giocatore che scappa lungo la banchina sinistra
## con lei [constant DIETRO] m dietro, in 4 punti della strada; per ogni punto con la luce rosa degli effetti
## (EffettiInseguimento, nuova nella 0.3.16) all'energia che si chiede e senza (com'era nella 0.3.15). Nebbia viola spenta
## (la sistema grafica-2 a parte). Stampa la luminanza media (0-255) di ogni scatto. Per il coordinatore, non per l'utente.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --script res://tests/run.gd -- res://tests/scatti_tunnel_inseguimento.gd <cartella> [energia]

const PUNTI := [30.0, 80.0, 140.0, 200.0]
const DIETRO := 12.0

var sala: SalaSottomarino
var b: Node3D
var s := 0.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var args := OS.get_cmdline_user_args()
	var cartella: String = args[1] if args.size() > 1 else "user://scatti_tunnel_inseguimento"
	DirAccess.make_dir_recursive_absolute(cartella)
	# (le opzioni cambiate qui si salvano nelle impostazioni: alla fine si rimettono com'erano, se no restano per i
	# test dopo, come la nebbia viola spenta in test_riscaldamento_pipeline)
	var opzioni_prima: Dictionary = Grafica.valori.duplicate()
	Grafica.imposta("nebbia_viola", false)
	var env := WorldEnvironment.new()
	env.environment = load("res://addons/grafica/sala/ambiente_sala.tres") as Environment
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	sala = SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	sala.costruisci()
	sala.vantaggio = 0.0
	var e := sala.effetti
	if args.size() > 2:
		e.luce_energia = float(args[2])
	var energia := e.luce_energia
	b = Node3D.new()
	add_child(b)
	sala.bersaglio = b
	var cam := Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.current = true
	for i in 30:
		await get_tree().process_frame
	for p in PUNTI:
		s = p
		_metti()
		sala._s_bersaglio = s
		sala.lei_tunnel.via()
		sala.lei_stato = SalaSottomarino.Lei.VIA
		sala.insegui_da(s - DIETRO)
		sala.velocita_lei = 0.0
		sala.velocita_rincorsa = 0.0
		var occhio := b.global_position + Vector3.UP * 1.6
		var avanti := sala.punto(s + 10.0) - sala.destra(s + 10.0) * (sala.canale + sala.banchina * 0.5)
		cam.look_at_from_position(occhio, Vector3(avanti.x, sala.piano + 1.2, avanti.z))
		for con in [true, false]:
			e.luce_energia = energia if con else 0.0
			for i in 60:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var nome := "s%03d_%s" % [int(p), ("rosa_%.0f" % energia) if con else "senza_rosa"]
			img.save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
			print("TUNNEL %s luce %.2f a %.1f m dietro, luminanza %.1f" % [nome, e.luce.light_energy if e.luce.visible else 0.0,
				sala._s_bersaglio - sala.lei_s, _luma(img)])
	print("SCATTI: fatti in ", cartella)
	Grafica.valori = opzioni_prima
	Grafica.salva()
	get_tree().quit()


func _metti() -> void:
	var p := sala.punto(s) - sala.destra(s) * (sala.canale + sala.banchina * 0.5)
	b.global_position = Vector3(p.x, sala.piano, p.z)


func _luma(img: Image) -> float:
	var somma := 0.0
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			somma += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return somma / maxf(n, 1) * 255.0
