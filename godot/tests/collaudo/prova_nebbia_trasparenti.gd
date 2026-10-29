extends Node
## Prova della nebbia viola sopra le cose trasparenti (collaudo del 29 ottobre: con la nebbia accesa sparivano l'acqua
## della piscina e le medusine): una scena piccola col renderer vero, un pavimento a riquadri (opaco), un'acqua
## trasparente che riflette e sfere trasparenti che si illuminano davanti alla camera, con l'ambiente della sala.
## Scatti senza nebbia, con la nebbia di adesso e con quella di prima ([param vecchia], lo shader della e9fabb28 che
## ricopiava lo schermo); misura la differenza fra adesso e prima dove non c'è niente di trasparente (deve essere ~0)
## e quanto si vedono acqua e sfere (con la nebbia di adesso devono restare).
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 640x360 --script res://tests/run.gd \
##        -- res://tests/collaudo/prova_nebbia_trasparenti.gd <cartella> [shader vecchio]

var cartella := "user://prova_nebbia"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	var vecchia: String = a[2] if a.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(cartella)
	Grafica.salva_su_disco = false
	var we := WorldEnvironment.new()
	we.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	add_child(we)
	# il pavimento a riquadri (opaco) e un muro
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in 8:
		for x in 8:
			img.set_pixel(x, y, Color(0.8, 0.75, 0.6) if (x + y) % 2 == 0 else Color(0.15, 0.2, 0.3))
	var mp := StandardMaterial3D.new()
	mp.albedo_texture = ImageTexture.create_from_image(img)
	mp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mp.uv1_scale = Vector3(4, 4, 4)
	_box(Vector3(12, 0.2, 12), Vector3(0, -0.1, -4), mp)
	_box(Vector3(12, 4, 0.2), Vector3(0, 2, -10), mp)
	# l'acqua: trasparente, riflettente, solo nella metà sinistra
	var ma := StandardMaterial3D.new()
	ma.albedo_color = Color(0.2, 0.5, 0.7, 0.55)
	ma.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ma.metallic = 0.6
	ma.roughness = 0.05
	ma.emission_enabled = true
	ma.emission = Color(0.1, 0.3, 0.45)
	_box(Vector3(5, 0.02, 8), Vector3(-3, 0.3, -4), ma)
	# le medusine: sfere trasparenti che si illuminano
	for i in 6:
		var ms := StandardMaterial3D.new()
		ms.albedo_color = Color.from_hsv(i / 6.0, 0.6, 1.0, 0.6)
		ms.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ms.emission_enabled = true
		ms.emission = Color.from_hsv(i / 6.0, 0.6, 1.0) * 2.0
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		s.mesh = sm
		s.material_override = ms
		s.position = Vector3(-4.5 + i * 0.6, 0.8, -3.0 - (i % 2) * 1.5)
		add_child(s)
	var l := OmniLight3D.new()
	l.position = Vector3(1, 3, -3)
	l.light_energy = 3.0
	l.omni_range = 10.0
	add_child(l)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.position = Vector3(0, 1.6, 2.5)
	add_child(cam)
	cam.look_at(Vector3(0, 0.3, -4), Vector3.UP)
	cam.make_current()
	var n := Grafica.nebbia_viola
	n.imposta_luci([[l.position, l.light_color, 0.18]])
	n.set_process(false)
	n.quanto = 0.0
	var senza := await _scatto("senza")
	n.quanto = 1.0
	var adesso := await _scatto("adesso")
	var prima: Image = null
	if vecchia != "":
		(n.get(&"_mat") as ShaderMaterial).shader = load(vecchia)
		n.quanto = 1.0
		prima = await _scatto("prima")
	# dove non c'è niente di trasparente (la metà destra del pavimento e del muro) e dove ci sono acqua e sfere
	var w := adesso.get_width()
	var h := adesso.get_height()
	var destra := Rect2i(int(w * 0.62), int(h * 0.1), int(w * 0.35), int(h * 0.85))
	var sinistra := Rect2i(int(w * 0.02), int(h * 0.45), int(w * 0.4), int(h * 0.5))
	if prima:
		print("NEBBIA differenza adesso-prima dove è tutto opaco: %.2f (su 255)" % _diff(adesso, prima, destra))
		print("NEBBIA differenza adesso-prima su acqua e sfere: %.2f" % _diff(adesso, prima, sinistra))
	print("NEBBIA acqua e sfere: senza nebbia-adesso %.2f (prima: %.2f)" % [_diff(senza, adesso, sinistra),
			_diff(senza, prima, sinistra) if prima else -1.0])
	get_tree().quit()


func _box(size: Vector3, pos: Vector3, m: Material) -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	b.mesh = bm
	b.material_override = m
	b.position = pos
	add_child(b)


func _scatto(nome: String) -> Image:
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(cartella.path_join(nome + ".jpg"), 0.92)
	print("salvato ", nome)
	return img


func _diff(x: Image, y: Image, r: Rect2i) -> float:
	var s := 0.0
	var k := 0
	for yy in range(r.position.y, r.end.y, 3):
		for xx in range(r.position.x, r.end.x, 3):
			var c1 := x.get_pixel(xx, yy)
			var c2 := y.get_pixel(xx, yy)
			s += (absf(c1.r - c2.r) + absf(c1.g - c2.g) + absf(c1.b - c2.b)) / 3.0
			k += 1
	return s / maxf(k, 1) * 255.0
