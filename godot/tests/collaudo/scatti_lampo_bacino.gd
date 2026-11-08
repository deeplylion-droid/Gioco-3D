extends Node
## Ricontrollo del lampo rosa sul bacino (#131, correzione di ambienti-2 su lavoro/lampo-bacino), enigmi.
## La sala della torre con le condotte come nel gioco (luci del blackout, ambiente della sala), il fondo nero nel vano
## della porta di servizio; per ogni punto di vista dal bacino (dove si riparte, il mezzo del bacino, in cima alla
## scaletta) il tunnel entra come lo mette la sala: SalaSottomarino costruito a pezzi col suo riscaldamento, poi pronto.
## Ogni fotogramma, dalla camera del giocatore: quanti pixel (su 160x90) diventano rosa rispetto allo scatto di prima del
## tunnel (rosso e blu salgono più del verde) e com'è la luce rosa degli effetti (accesa, energia, maschera, nebbia).
## Salva i fotogrammi del riscaldamento e quelli col rosa. Poi toglie il tunnel, rimette il fondo e passa al punto dopo.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720 --fixed-fps 60 \
##   --script res://tests/run.gd -- res://tests/collaudo/scatti_lampo_bacino.gd <cartella> [punti: ripartenza,mezzo,scaletta]

const VANO := Vector3(40.4, -28.925, -5.0)
const W := 160
const H := 90

var _cartella := ""
var _cam: Camera3D
var _ins: SalaInseguimento
var _rif: Image


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _immagine() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## Pixel rosa rispetto al riferimento: [quanti, il rosa medio dei rosa (0-255)].
func _rosa(im: Image) -> Array:
	var p := im.duplicate() as Image
	p.resize(W, H, Image.INTERPOLATE_BILINEAR)
	var n := 0
	var somma := 0.0
	for y in H:
		for x in W:
			var a := p.get_pixel(x, y)
			var b := _rif.get_pixel(x, y)
			var dr := a.r - b.r
			var dg := a.g - b.g
			var db := a.b - b.b
			if dr > dg + 0.025 and db > dg + 0.012 and dr > 0.02:
				n += 1
				somma += ((dr + db) * 0.5 - dg) * 255.0
	return [n, somma / maxf(n, 1)]


func _punti() -> Dictionary:
	var out := {}
	var w := get_viewport().find_world_3d()
	for c in _ins.find_children("Checkpoint_*", "", true, false):
		if String(c.name).to_lower().contains("bacino"):
			out["ripartenza"] = [(c as Checkpoint).get_spawn_transform().origin + Vector3.UP * 1.6, VANO]
	var bc: Array = _ins.dati["bacino"]["rett"]
	var fondo := float(_ins.dati["bacino"]["fondo"])
	out["mezzo"] = [Vector3((bc[0] + bc[2]) * 0.5, fondo + 1.65, -(bc[1] + bc[3]) * 0.5), VANO]
	out["scaletta"] = [VANO + Vector3(1.0, -0.2, 0.0), VANO + Vector3(-1.0, -0.3, 0.0)]
	return out


func _luce(tun: Node) -> String:
	var e: EffettiInseguimento = tun.get(&"effetti") if is_instance_valid(tun) else null
	if e == null or not is_instance_valid(e) or e.luce == null:
		return "luce: -"
	var l := e.luce
	return "luce accesa %s, energia %.1f, maschera %d, nebbia %.2f, cono %.0f, portata %.0f" % [l.is_visible_in_tree(),
			l.light_energy, l.light_cull_mask, l.light_volumetric_fog_energy, l.spot_angle, l.spot_range]


func _punto(nome: String, da: Vector3, verso: Vector3) -> void:
	_cam.global_position = da
	_cam.look_at(verso, Vector3.UP)
	await _frames(40)
	_rif = await _immagine()
	_rif.save_jpg(_cartella.path_join("%s_riferimento.jpg" % nome), 0.9)
	DirAccess.make_dir_recursive_absolute(_cartella.path_join("%s_piccoli" % nome))
	var rp := _rif.duplicate() as Image
	rp.resize(320, 180, Image.INTERPOLATE_BILINEAR)
	rp.save_png(_cartella.path_join("%s_piccoli/riferimento.png" % nome))
	_rif.resize(W, H, Image.INTERPOLATE_BILINEAR)
	# (lo scatto di riferimento rifatto subito: il rumore fra due fotogrammi senza tunnel)
	var r0: Array = _rosa(await _immagine())
	print("LAMPO %s: riferimento da %s, rumore %d pixel" % [nome, da.snapped(Vector3.ONE * 0.01), r0[0]])
	var tun := (load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene).instantiate() as Node3D
	tun.name = "SalaSottomarino"
	add_child(tun)
	var finito := [false]
	var costruisci := func():
		await tun.call(&"costruisci_a_pezzi")
		finito[0] = true
	costruisci.call()
	var k := 0
	var riscalda := 0
	var rosa_n := 0
	var peggio := [0, 0.0, -1]
	var ultimo := ""
	while not finito[0] and k < 6000:
		var im := await _immagine()
		var e: EffettiInseguimento = tun.get(&"effetti")
		var acceso := e != null and is_instance_valid(e) and e.luce != null and e.luce.is_visible_in_tree() \
				and bool(e.get(&"_riscalda"))
		var r: Array = _rosa(im)
		# ogni fotogramma anche in piccolo (320x180), per la misura del rosa fuori dal motore (misura_rosa.py)
		var piccolo := im.duplicate() as Image
		piccolo.resize(320, 180, Image.INTERPOLATE_BILINEAR)
		piccolo.save_png(_cartella.path_join("%s_piccoli/%04d.png" % [nome, k]))
		if acceso and riscalda == 0:
			var pr := im.duplicate() as Image
			pr.resize(W, H, Image.INTERPOLATE_BILINEAR)
			print("LAMPO %s: immagine formato %d %s, piccola %s, pixel (20,45) %s, riferimento %s" % [nome, im.get_format(),
					im.get_size(), pr.get_size(), pr.get_pixel(20, 45), _rif.get_pixel(20, 45)])
		if acceso:
			riscalda += 1
		if int(r[0]) > 20:
			rosa_n += 1
		if int(r[0]) > int(peggio[0]):
			peggio = [r[0], r[1], k]
		var st := _luce(tun)
		if acceso or int(r[0]) > 20 or st != ultimo:
			print("LAMPO %s %04d: rosa %d pixel (%.1f), %s%s" % [nome, k, r[0], r[1], st, " [riscalda]" if acceso else ""])
			ultimo = st
		if acceso or int(r[0]) > 20:
			im.save_jpg(_cartella.path_join("%s_%04d.jpg" % [nome, k]), 0.88)
		k += 1
	print("LAMPO %s: RISULTATO fotogrammi col riscaldamento %d, fotogrammi con più di 20 pixel rosa %d, il peggiore %d pixel (%.1f) al fotogramma %d; %s" % [
			nome, riscalda, rosa_n, peggio[0], peggio[1], peggio[2], _luce(tun)])
	# pronto: il fondo va via, si vede il tunnel; poi si toglie e si rimette il fondo per il punto dopo
	AttesaZone.pronta(&"tunnel")
	await _frames(40)
	(await _immagine()).save_jpg(_cartella.path_join("%s_pronto.jpg" % nome), 0.88)
	print("LAMPO %s: pronto, %s" % [nome, _luce(tun)])
	tun.queue_free()
	await _frames(10)
	AttesaZone.non_pronta(&"tunnel")
	_ins.call(&"_fondo_porta")
	await _frames(20)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_lampo_bacino"
	var quali: PackedStringArray = (a[2] if a.size() > 2 else "ripartenza,mezzo,scaletta").split(",")
	DirAccess.make_dir_recursive_absolute(_cartella)
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
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.fov = 62.0
	add_child(_cam)
	_cam.make_current()
	var punti := _punti()
	for q in quali:
		if punti.has(q):
			await _punto(q, punti[q][0], punti[q][1])
	print("LAMPO: FINE")
	get_tree().quit()
