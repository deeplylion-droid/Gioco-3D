extends Node
## Ricontrollo di grafica-2 della riga a zig-zag (lavoro/linea-zigzag): interni e tecnici con le loro luci; per dei
## punti davanti ai muri a pannelli (parete.gdshader) lo stesso fotogramma con lo shader nuovo e con quello vecchio
## (letto dal file dato). Togliere la riga può solo schiarire: stampa quanti pixel schiariscono, quanti scuriscono
## (dovrebbero essere 0: vorrebbe dire che è cambiato altro) e salva la differenza ×8.
## Uso: ... -- res://tests/ricontrollo_zigzag_g2.gd <cartella> <shader vecchio (percorso assoluto)>

const SCENE_TUTTE := {"interni": ["res://scenes/interni/interni.tscn", "res://scenes/interni/luci_interni.tscn"],
		"tecnici": ["res://scenes/tecnici/tecnici.tscn", "res://scenes/tecnici/luci_tecnici.tscn"]}
const PER_ZONA := 8
var SCENE := {}

var nuovo: Shader
var vecchio: Shader
var materiali: Array[ShaderMaterial] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella: String = a[1]
	for z in SCENE_TUTTE:
		if a.size() < 4 or z in a[3].split(","):
			SCENE[z] = SCENE_TUTTE[z]
	DirAccess.make_dir_recursive_absolute(cartella)
	vecchio = Shader.new()
	vecchio.code = FileAccess.get_file_as_string(a[2])
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.25, 0.27)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = e
	add_child(we)
	var cam := Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.make_current()
	var tot_chiari := 0
	var tot_scuri := 0
	for zona in SCENE:
		var radice := Node3D.new()
		add_child(radice)
		for p in SCENE[zona]:
			if ResourceLoader.exists(p):
				radice.add_child((load(p) as PackedScene).instantiate())
		# (le lampade che pulsano o sfarfallano ferme: i due scatti differiscono solo per lo shader)
		for l in radice.find_children("*", "Node3D", true, false):
			if l is LuceEmergenza and int(l.get(&"modalita")) in [1, 2]:
				l.set(&"modalita", 0)
			if &"sfarfalla" in l:
				l.set(&"sfarfalla", false)
		for i in 30:
			await get_tree().process_frame
		var muri := []
		materiali.clear()
		for g in radice.find_children("*", "MeshInstance3D", true, false):
			var mi := g as MeshInstance3D
			var usa := false
			for m in _materiali(mi):
				if m is ShaderMaterial and (m as ShaderMaterial).shader and (m as ShaderMaterial).shader.resource_path.ends_with("parete.gdshader"):
					nuovo = (m as ShaderMaterial).shader
					if not materiali.has(m):
						materiali.append(m)
					usa = true
			if usa:
				muri.append(mi)
		print("ZIGZAG %s: %d mesh coi muri a pannelli, %d materiali" % [zona, muri.size(), materiali.size()])
		var punti := _punti(muri)
		var k := 0
		for pt in punti:
			cam.global_position = pt[0]
			cam.look_at(pt[1], Vector3.UP)
			for i in 10:
				await get_tree().process_frame
			# (a scena ferma: lampade che girano o sfarfallano uguali nei due scatti)
			get_tree().paused = true
			var dopo := await _scatto()
			_shader(vecchio)
			var prima := await _scatto()
			_shader(nuovo)
			get_tree().paused = false
			var r := _confronta(prima, dopo, cartella.path_join("%s_%02d" % [zona, k]))
			tot_chiari += r[0]
			tot_scuri += r[1]
			print("ZIGZAG %s_%02d: pixel più chiari %d, più scuri %d (su %d), luminosità %.1f" % [zona, k, r[0], r[1], r[2], r[3]])
			k += 1
		radice.queue_free()
		await get_tree().process_frame
	print("ZIGZAG FINE: più chiari %d, più scuri %d" % [tot_chiari, tot_scuri])
	get_tree().quit()


func _materiali(mi: MeshInstance3D) -> Array:
	var out := [mi.material_override]
	if mi.mesh:
		for s in mi.mesh.get_surface_count():
			out.append(mi.get_surface_override_material(s))
			out.append(mi.mesh.surface_get_material(s))
	return out.filter(func(m): return m != null)


func _shader(s: Shader) -> void:
	for m in materiali:
		m.shader = s


## Davanti ai muri: per le mesh più grandi, dal centro del box 2,2 m in fuori lungo l'asse più sottile (da tutte e due
## le parti), all'altezza di 1,6 m sopra il fondo del box, guardando un punto del muro a 1,6 m.
func _punti(muri: Array) -> Array:
	muri.sort_custom(func(x, y): return (x.global_transform * x.get_aabb()).get_volume() > (y.global_transform * y.get_aabb()).get_volume())
	var out := []
	for mi in muri:
		var b: AABB = mi.global_transform * mi.get_aabb()
		var c := b.get_center()
		var asse := Vector3.RIGHT if b.size.x < b.size.z else Vector3.BACK
		var y := b.position.y + 1.6
		for s: float in [-1.0, 1.0]:
			var occhio: Vector3 = Vector3(c.x, y, c.z) + asse * s * (2.2 + (b.size.x if asse == Vector3.RIGHT else b.size.z) * 0.5)
			var mira: Vector3 = Vector3(c.x, y + 0.2, c.z) + asse * s * (b.size.x if asse == Vector3.RIGHT else b.size.z) * 0.5
			out.append([occhio, mira])
		if out.size() >= PER_ZONA * 2:
			break
	return out


func _scatto() -> Image:
	for i in 4:
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _confronta(prima: Image, dopo: Image, nome: String) -> Array:
	var w := prima.get_width()
	var h := prima.get_height()
	var d := Image.create(w, h, false, Image.FORMAT_RGB8)
	var chiari := 0
	var scuri := 0
	var lum := 0.0
	for y in h:
		for x in w:
			var a := prima.get_pixel(x, y).get_luminance()
			var b := dopo.get_pixel(x, y).get_luminance()
			lum += b
			var df := (b - a) * 255.0
			if df > 2.0:
				chiari += 1
			elif df < -2.0:
				scuri += 1
			d.set_pixel(x, y, Color(clampf(-df * 8.0 / 255.0, 0, 1), clampf(df * 8.0 / 255.0, 0, 1), 0))
	if chiari + scuri > 0:
		d.save_jpg(nome + "_diff_x8.jpg", 0.85)
		dopo.save_jpg(nome + "_dopo.jpg", 0.85)
		prima.save_jpg(nome + "_prima.jpg", 0.85)
	return [chiari, scuri, w * h, lum / (w * h) * 255.0]
