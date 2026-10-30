extends Node
## La grana della nebbia viola (riscontro dell'utente sulla 0.3.16: "la film grain con la nebbia stona"), col renderer
## vero su una scena piccola e buia (muro e pavimento, una lampada con l'alone), con la Grana della pellicola spenta:
## per i passi di [param passi] scatta due fotogrammi con la camera spostata di 2 cm e misura il rumore fine
## (deviazione del laplaciano della luminosità) con e senza nebbia, e quanto cambia fra i due fotogrammi dove
## l'immagine dovrebbe restare quasi uguale (il rumore fermo sullo schermo che "scorre" sopra il mondo). PNG in
## <cartella>, i ritagli ingranditi a parte.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 640x360 --script res://tests/run.gd \
##        -- res://tests/collaudo/prova_nebbia_grana.gd <cartella> [passi separati da virgole] [tempo]

var cartella := "user://prova_grana"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	var passi: PackedStringArray = a[2].split(",") if a.size() > 2 else PackedStringArray(["20", "10"])
	DirAccess.make_dir_recursive_absolute(cartella)
	Grafica.salva_su_disco = false
	Grafica.imposta("grana", false)
	var we := WorldEnvironment.new()
	we.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	add_child(we)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.33, 0.3)
	m.roughness = 0.8
	_box(Vector3(14, 0.2, 14), Vector3(0, -0.1, -5), m)
	_box(Vector3(14, 5, 0.2), Vector3(0, 2.5, -9), m)
	var l := OmniLight3D.new()
	l.position = Vector3(1.5, 2.6, -4.5)
	l.light_energy = 2.0
	l.omni_range = 8.0
	l.light_color = Color(1.0, 0.7, 0.5)
	add_child(l)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.position = Vector3(0, 1.6, 1.5)
	add_child(cam)
	cam.look_at(Vector3(0, 1.0, -5), Vector3.UP)
	cam.make_current()
	var n := Grafica.nebbia_viola
	n.set_process(false)
	var mat := n.get(&"_mat") as ShaderMaterial
	n.imposta_luci([[l.position, l.light_color, NebbiaViola.ALONE]])
	n.quanto = 0.0
	var s0 := await _scatto("senza")
	print("GRANA senza nebbia: rumore fine %.2f" % _rumore(s0))
	for pv in passi:
		mat.set_shader_parameter(&"passi", int(pv))
		n.quanto = 1.0
		var x := await _scatto("passi%s_a" % pv)
		cam.position.x += 0.02
		var y := await _scatto("passi%s_b" % pv)
		cam.position.x -= 0.02
		print("GRANA %s passi: rumore fine %.2f (senza nebbia %.2f); cambio fra due fotogrammi a 2 cm %.2f" % [
				pv, _rumore(x), _rumore(s0), _diff(x, y)])
		_ritaglio(x, "passi%s_ritaglio" % pv)
	_ritaglio(s0, "senza_ritaglio")
	get_tree().quit()


func _box(size: Vector3, pos: Vector3, mt: Material) -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	b.mesh = bm
	b.material_override = mt
	b.position = pos
	add_child(b)


func _scatto(nome: String) -> Image:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(cartella.path_join(nome + ".png"))
	return img


## Il ritaglio al centro (160 x 90) ingrandito 4 volte, con la luminosità alzata (per vedere la grana).
func _ritaglio(img: Image, nome: String) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var r := img.get_region(Rect2i(w / 2 - 80, h / 2 - 20, 160, 90))
	for y in r.get_height():
		for x in r.get_width():
			var c := r.get_pixel(x, y)
			r.set_pixel(x, y, Color(minf(c.r * 3.0, 1.0), minf(c.g * 3.0, 1.0), minf(c.b * 3.0, 1.0)))
	r.resize(640, 360, Image.INTERPOLATE_NEAREST)
	r.save_png(cartella.path_join(nome + ".png"))


## La deviazione del laplaciano della luminosità (0..255) nella parte centrale: il rumore da un pixel all'altro.
static func _rumore(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var s := 0.0
	var s2 := 0.0
	var k := 0
	for y in range(h / 4, h * 3 / 4):
		for x in range(w / 4, w * 3 / 4):
			var c := _l(img, x, y) * 4.0 - _l(img, x - 1, y) - _l(img, x + 1, y) - _l(img, x, y - 1) - _l(img, x, y + 1)
			s += c
			s2 += c * c
			k += 1
	var media := s / k
	return sqrt(maxf(s2 / k - media * media, 0.0)) * 255.0


static func _l(img: Image, x: int, y: int) -> float:
	var c := img.get_pixel(x, y)
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


static func _diff(x: Image, y: Image) -> float:
	var w := x.get_width()
	var h := x.get_height()
	var s := 0.0
	var k := 0
	for yy in range(h / 4, h * 3 / 4, 2):
		for xx in range(w / 4, w * 3 / 4, 2):
			s += absf(_l(x, xx, yy) - _l(y, xx, yy))
			k += 1
	return s / k * 255.0
