extends Node
## Collaudo finale 0.3.21 (mascotte, seconda parte): il tunnel del viaggio sottomarino dagli occhi del giocatore, dal
## bacino (la porta, s 0) alla camera stagna in fondo, ogni [constant PASSO] m, dalle due banchine, guardando avanti
## (e indietro ogni due passi). La sala e l'ambiente come tests/scatti_sottomarino.gd; lei nascosta.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/collaudo_0321_tunnel.gd <cartella>
## I file: s<metri>_<sinistra|destra>_<avanti|indietro>.jpg.

const PASSO := 15.0
var cartella := "/tmp/tunnel"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.009
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	sala.costruisci()
	var cam := Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.current = true
	for i in 30:
		await get_tree().process_frame
	if sala.lei:
		sala.lei.visible = false
	var L := sala.lunghezza()
	print("TUNNEL lungo %.0f m" % L)
	var s := 0.0
	var k := 0
	while s <= L - 2.0:
		for lato in [-1.0, 1.0]:
			var viste := [["avanti", minf(s + 10.0, L)]]
			if k % 2 == 1:
				viste.append(["indietro", maxf(s - 10.0, 0.0)])
			for v in viste:
				cam.look_at_from_position(_occhio(sala, s, lato, 1.6), _occhio(sala, v[1], lato * 0.6, 1.2))
				for i in 24:
					await get_tree().process_frame
				get_viewport().get_texture().get_image().save_jpg(cartella.path_join("s%03d_%s_%s.jpg" % [int(s), "sinistra" if lato < 0 else "destra", v[0]]), 0.85)
		s += PASSO
		k += 1
	print("TUNNEL FINITO")
	get_tree().quit()


## Come in scatti_sottomarino.gd: un punto a [param s] lungo la strada, di lato (-1 la banchina sinistra, 1 la destra,
## frazioni del canale in mezzo), a [param su] sopra il piano delle banchine.
func _occhio(sala: SalaSottomarino, s: float, lato: float, su: float) -> Vector3:
	var di_lato := lato * sala.canale if absf(lato) < 0.99 else signf(lato) * (sala.canale + sala.banchina * 0.5)
	return sala.punto(s) + sala.destra(s) * di_lato + Vector3.UP * (sala.piano - sala.acqua + su)
