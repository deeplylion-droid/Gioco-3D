extends Node
## Collaudo finale della 0.3.22 (ambienti-2): gli scatti dagli occhi nei punti dove arrivano le partenze F9
## (Inseguimento e Tunnel) e dove si riparte dopo la morte, col renderer vero. La sala intera con torre e condotte sul
## renderer software non sta in memoria (le partenze dal titolo vengono uccise): qui, come in misura_lampo_bacino.gd, la
## sala della torre con le condotte (luci del blackout, ambiente della sala) e il tunnel costruito a pezzi come lo mette la
## sala (SDFGI spento e accese solo le mesh entro 25 m, per la memoria); una camera agli occhi (1,6 m) nel punto, quattro scatti attorno (avanti, destra, dietro, sinistra), 8 gradi in basso.
## I punti (piedi del giocatore e direzione, gradi) vengono dalle partenze vere senza schermo (giro_0322_partenze.gd, righe POSA).
## Uso (sotto il lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_0322_partenze.gd <cartella> <nome:x,y,z,gradi> ...

const PLAYER := "res://scenes/player/player.tscn"


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var cartella := a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	# (come misura_lampo_bacino.gd: con l'SDFGI la torre col tunnel non sta in memoria sul renderer software)
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	var ins := torre.inseguimento as SalaInseguimento
	for i in 1200:
		await get_tree().physics_frame
		if ins.costruita:
			break
	print("SCATTI: torre e condotte costruite")
	if ins.lei:
		ins.lei.visible = false
	var tun := (load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene).instantiate() as SalaSottomarino
	tun.name = "SalaSottomarino"
	add_child(tun)
	await tun.costruisci_a_pezzi()
	AttesaZone.pronta(&"tunnel")
	print("SCATTI: tunnel costruito")
	# (una camera agli occhi del giocatore, 1,6 m sopra i piedi, come misura_lampo_bacino.gd: il giocatore intero in più
	# non sta in memoria sul renderer software)
	var cam := Camera3D.new()
	cam.near = 0.05
	cam.fov = 62.0
	add_child(cam)
	cam.make_current()
	await _frames(30)
	for arg in a.slice(2):
		var parti := String(arg).split(":")
		var v := parti[1].split(",")
		var piedi := Vector3(float(v[0]), float(v[1]), float(v[2]))
		var yaw := deg_to_rad(float(v[3]))
		# accese solo le mesh entro 25 m (come i collaudi della sala: la memoria delle pipeline di llvmpipe)
		for n in find_children("*", "GeometryInstance3D", true, false):
			var g := n as GeometryInstance3D
			if g == null:
				continue
			var box := g.get_aabb()
			var c := g.global_transform * box.get_center()
			g.visible = c.distance_to(piedi) - box.size.length() * 0.5 < 25.0
		cam.global_position = piedi + Vector3(0, 1.6, 0)
		await _frames(40)
		for k in 4:
			cam.rotation = Vector3(deg_to_rad(-8.0), yaw - k * PI * 0.5, 0.0)
			await _frames(12)
			await RenderingServer.frame_post_draw
			var f := cartella.path_join("%s_%d.jpg" % [parti[0], k])
			get_viewport().get_texture().get_image().save_jpg(f, 0.88)
			print("SCATTO %s da %s" % [f, cam.global_position.snapped(Vector3.ONE * 0.01)])
	get_tree().quit()
