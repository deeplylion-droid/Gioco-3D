extends Node
## Misura del lampo rosa sul bacino delle condotte mentre il tunnel si riscalda (#131, collaudo finale della 0.3.21:
## muro, scaletta e ringhiera del bacino rosa per 0,1-0,15 s). Come scatti_fondo_porta.gd di enigmi: la torre con le
## condotte come nel gioco (luci del blackout, ambiente della sala), il giocatore fermo nel bacino che guarda la porta di
## servizio; poi il tunnel entra come lo mette la sala (SalaSottomarino a pezzi, col riscaldamento). A ogni fotogramma,
## dalla costruzione a 45 fotogrammi dopo la fine, quanto rosa c'è in più rispetto allo scatto di prima del tunnel
## (pixel con rosso e blu che salgono più del verde), e se la luce del riscaldamento è accesa. Salva il fotogramma col
## rosa più forte e quelli del riscaldamento.
## Uso (sotto il lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan \
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/misura_lampo_bacino.gd <cartella> <prefisso>

const VANO := Vector3(40.4, -28.925, -5.0)

var _cartella := ""
var _prefisso := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _immagine() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## Quanto rosa in più c'è in [param im] rispetto a [param rif]: pixel (su una griglia 160x90) dove rosso e blu salgono
## di almeno 6/255 più del verde. [quanti pixel su 14400, aumento medio del rosa in quei pixel]
static func _rosa(im: Image, rif: Image) -> Array:
	var a := im.duplicate() as Image
	var b := rif.duplicate() as Image
	a.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	b.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var n := 0
	var somma := 0.0
	for y in 90:
		for x in 160:
			var c := a.get_pixel(x, y)
			var r := b.get_pixel(x, y)
			var dr := c.r - r.r
			var dg := c.g - r.g
			var db := c.b - r.b
			var rosa := minf(dr, db) - maxf(dg, 0.0)
			if rosa > 6.0 / 255.0:
				n += 1
				somma += rosa
	return [n, (somma / n * 255.0) if n > 0 else 0.0]


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1]
	_prefisso = a[2] if a.size() > 2 else ""
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
	var ins := torre.inseguimento as SalaInseguimento
	for i in 1200:
		await get_tree().physics_frame
		if ins.costruita:
			break
	for i in 30:
		await get_tree().physics_frame
	if ins.lei:
		ins.lei.visible = false
	var cam := Camera3D.new()
	cam.near = 0.05
	add_child(cam)
	cam.make_current()
	var bc: Array = ins.dati["bacino"]["rett"]
	var fondo := float(ins.dati["bacino"]["fondo"])
	cam.global_position = Vector3((bc[0] + bc[2]) * 0.5, fondo + 1.65, -(bc[1] + bc[3]) * 0.5)
	cam.look_at(VANO, Vector3.UP)
	await _frames(30)
	var rif := await _immagine()
	rif.save_jpg(_cartella.path_join(_prefisso + "riferimento.jpg"), 0.9)
	var tun := (load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene).instantiate() as SalaSottomarino
	tun.name = "SalaSottomarino"
	add_child(tun)
	var finito := [false]
	var costruisci := func():
		await tun.costruisci_a_pezzi()
		AttesaZone.pronta(&"tunnel")
		finito[0] = true
	costruisci.call()
	var k := 0
	var dopo := 0
	var peggio := [0, 0.0, -1]
	var riscaldati := 0
	var col_rosa := 0
	while dopo < 45 and k < 4000:
		await get_tree().process_frame
		var eff := tun.get(&"effetti") as EffettiInseguimento
		var accesa := eff != null and bool(eff.get(&"_riscalda"))
		var im := await _immagine()
		var r := _rosa(im, rif)
		if accesa:
			riscaldati += 1
			im.save_jpg(_cartella.path_join(_prefisso + "riscalda_%04d.jpg" % k), 0.85)
		if int(r[0]) > 20:
			col_rosa += 1
		if int(r[0]) > int(peggio[0]):
			peggio = [r[0], r[1], k]
			im.save_jpg(_cartella.path_join(_prefisso + "peggiore.jpg"), 0.9)
		if accesa or int(r[0]) > 20:
			print("FOTOGRAMMA %d: riscaldamento %s, pixel rosa %d su 14400 (+%.1f)" % [k, accesa, r[0], r[1]])
		if finito[0]:
			dopo += 1
		k += 1
	print("LAMPO: %d fotogrammi, %d col riscaldamento acceso, %d con più di 20 pixel rosa; il peggiore %d pixel (+%.1f) al fotogramma %d" % [
			k, riscaldati, col_rosa, peggio[0], peggio[1], peggio[2]])
	get_tree().quit()
