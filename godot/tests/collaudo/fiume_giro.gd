extends Node
## Collaudo del fiume lento nella 0.3.20 (lampade a gabbia al 20%, pile di scatoloni molto più sfalsate), col renderer
## vero, nella Risalita della scena di prova (ambiente della sala senza GI, nebbia volumetrica e SSIL; luci del
## blackout, come nel gioco; bambino del corridoio e oblò fermi). Fasi (secondo argomento, separate da virgole):
##  - strada: il giocatore vero cammina dall'ingresso del capannone alla fine della fila e al salvagente dell'imbarco,
##    e indietro; uno scatto ogni [constant OGNI] fotogrammi guardando avanti; a ogni fotogramma che cosa c'è fra 0,1 e
##    2 m sopra i piedi (collisioni e mesh) e se ci si ferma;
##  - anello: dagli occhi di chi sta seduto sulla ciambella, lungo il canale dall'imbarco all'anello e tutto l'anello,
##    ogni 10 gradi, guardando avanti; davanti a ogni paratia (prima del bivio) quanto si vede: luminosità della
##    paratia sullo schermo contro quella intorno (PARATIA:);
##  - cime: le cime delle pile vicino all'ingresso (trovate coi raggi), ravvicinati di fronte e dall'alto, con una
##    lampadina tecnica accanto alla camera.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/fiume_giro.gd <cartella> [fasi]

const OGNI := 20
const F := preload("res://scripts/risalita/fiume_gioco.gd")
var p: Player
var cart := ""
var fasi: PackedStringArray = []
var _k := 0
var ris: Node3D
var fiu: Node3D
var cam: Camera3D
var _mesh_zona: Array[MeshInstance3D] = []


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	fasi = (a[2] if a.size() > 2 else "strada,anello,cime").split(",")
	DirAccess.make_dir_recursive_absolute(cart)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> Image:
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	im.save_jpg(cart.path_join("%03d_%s.jpg" % [_k, nome]), 0.88)
	_k += 1
	return im


func L(v: Vector3) -> Vector3:
	return fiu.to_global(v)


func _px(im: Image, c: Camera3D, w: Vector3) -> Vector2:
	return c.unproject_position(w) * Vector2(im.get_size()) / get_viewport().get_visible_rect().size


func _lum(im: Image, px: Vector2, r: int) -> float:
	var s := 0.0
	var n := 0
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			var x := int(px.x) + dx
			var y := int(px.y) + dy
			if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
				s += im.get_pixel(x, y).get_luminance()
				n += 1
	return s / maxf(n, 1)


func _sopra(piedi: Vector3) -> Array:
	var c := CylinderShape3D.new()
	c.radius = 0.25
	c.height = 1.9
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = c
	q.transform = Transform3D(Basis(), piedi + Vector3.UP * 1.05)
	q.exclude = [p.get_rid()]
	var out := []
	for h in p.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var n = h.collider
		out.append("collisione " + (str(ris.get_path_to(n)) if n is Node and ris.is_ancestor_of(n) else str(n)))
	var box := AABB(piedi + Vector3(-0.25, 0.1, -0.25), Vector3(0.5, 1.9, 0.5))
	for m in _mesh_zona:
		if is_instance_valid(m) and m.is_visible_in_tree() and (m.global_transform * m.get_aabb()).intersects(box):
			out.append("mesh " + str(ris.get_path_to(m)))
	return out


func _cammina(punti: Array, nome: String) -> void:
	var fermo := 0
	var max_fermo := 0
	var prima := p.global_position
	var trovati := {}
	var f := 0
	for a: Vector3 in punti:
		Input.action_press(&"move_forward")
		for i in 60 * 30:
			p.look_at_point(Vector3(a.x, p.get_eye_position().y, a.z))
			await get_tree().physics_frame
			var piedi := p.global_position
			for s in _sopra(piedi):
				if not trovati.has(s):
					trovati[s] = piedi.snapped(Vector3.ONE * 0.01)
			fermo = fermo + 1 if piedi.distance_to(prima) < 0.004 else 0
			max_fermo = maxi(max_fermo, fermo)
			prima = piedi
			if f % OGNI == 0:
				await _scatto(nome)
			f += 1
			if Vector2(piedi.x - a.x, piedi.z - a.z).length() < 0.4 or fermo > 90:
				break
		if fermo > 90:
			print("FIUME: %s: FERMO in %s andando verso %s" % [nome, p.global_position.snapped(Vector3.ONE * 0.01), a.snapped(Vector3.ONE * 0.01)])
			break
	Input.action_release(&"move_forward")
	print("FIUME: %s: arrivato a %s (ultimo punto %s), fermo al più %d fotogrammi di fila" % [nome,
			p.global_position.snapped(Vector3.ONE * 0.01), (punti[-1] as Vector3).snapped(Vector3.ONE * 0.01), max_fermo])
	for s in trovati:
		print("FIUME:   fra 0,1 e 2 m sopra i piedi: %s (la prima volta coi piedi in %s)" % [s, trovati[s]])
	await _frames(20)


## Una camera libera con gli stessi attributi di quella del giocatore.
func _libera(da: Vector3, verso: Vector3, nome: String, fov := 70.0, luce := false) -> Array:
	var c := Camera3D.new()
	c.fov = fov
	c.near = 0.03
	c.attributes = cam.attributes
	get_tree().current_scene.add_child(c)
	c.global_position = da
	var su := Vector3.UP if absf((verso - da).normalized().y) < 0.98 else Vector3.FORWARD
	c.look_at(verso, su)
	c.current = true
	if luce:
		var o := OmniLight3D.new()
		o.light_energy = 1.0
		o.omni_range = 2.5
		c.add_child(o)
	await _frames(12)
	var im := await _scatto(nome)
	var ris_c := [im, c]
	return ris_c


func _chiudi(c: Camera3D) -> void:
	c.current = false
	c.queue_free()
	cam.current = true


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	p = GameState.player
	cam = p.get_viewport().get_camera_3d()
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.volumetric_fog_enabled = false
	env.environment.ssil_enabled = false
	get_tree().current_scene.add_child(env)
	ris = get_tree().current_scene.get_node(^"Risalita") as Node3D
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for i in 3600:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 300 and ris.get(&"fiume") != null:
			break
	fiu = ris.get(&"fiume") as Node3D
	for nome in ["BambinoCorridoioFiume"]:
		var b := ris.find_child(nome, true, false) as Node3D
		if b:
			b.process_mode = Node.PROCESS_MODE_DISABLED
			b.visible = false
	var zona := AABB(L(Vector3(-42.0, -1.0, -30.0)), Vector3(72.0, 8.0, 60.0))
	for m in fiu.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var ab := mi.global_transform * mi.get_aabb()
		if ab.intersects(zona) and ab.size.x < 4.0 and ab.size.z < 4.0:
			_mesh_zona.append(mi)
	print("FIUME: fiume in %s, mesh piccole %d, luci %s" % [fiu.global_position.snapped(Vector3.ONE * 0.01), _mesh_zona.size(), GameState.luci])
	if "strada" in fasi:
		await _strada()
	if "anello" in fasi:
		await _anello()
	if "cime" in fasi:
		await _cime()
	print("FIUME: finito")
	get_tree().quit()


func _strada() -> void:
	var m := fiu.get_node(^"Marker")
	var ingresso := (m.get_node(^"Ingresso") as Node3D).global_position
	var fine := (m.get_node(^"FineFila") as Node3D).global_position
	var imbarco := (m.get_node(^"Imbarco") as Node3D).global_position
	print("FIUME: ingresso %s, fine della fila %s, imbarco %s" % [ingresso.snapped(Vector3.ONE * 0.01), fine.snapped(Vector3.ONE * 0.01), imbarco.snapped(Vector3.ONE * 0.01)])
	p.teleport(ingresso + Vector3.UP * 0.05)
	await _frames(30)
	await _cammina([fine, imbarco], "andata")
	await _cammina([fine, ingresso], "ritorno")


func _anello() -> void:
	var fl := fiu.find_child("FiumeLento", true, false) as Node3D
	var LF := func(v: Vector3) -> Vector3: return fl.to_global(v)
	print("FIUME: FiumeLento in %s (fiume %s)" % [fl.global_position.snapped(Vector3.ONE * 0.01), fiu.global_position.snapped(Vector3.ONE * 0.01)])
	var occhio := F.ACQUA + 1.0
	var paratie := {}
	for n in fiu.find_children("Paratia*", "", true, false):
		if n is Node3D and String(n.name).length() == 8:
			paratie[String(n.name)] = n
	print("FIUME: paratie %s" % [paratie.keys()])
	# il canale dall'imbarco verso nord, poi l'anello in senso orario
	var punti := []
	for z in [-4.0, -10.0, -16.0, -21.0]:
		punti.append([Vector3(0, occhio, z), Vector3(0, occhio, z - 5.0), "canale_z%d" % int(-z)])
	for g in range(0, 271, 10):
		var a: Vector3 = F.anello(float(g)) + Vector3(0, occhio, 0)
		var b: Vector3 = F.anello(float(g) + 12.0) + Vector3(0, occhio, 0)
		punti.append([a, b, "anello_%03d" % g])
	for q in punti:
		var r := await _libera(LF.call(q[0]), LF.call(q[1]), q[2], 75.0)
		_chiudi(r[1])
	# davanti a ogni paratia, da 30, 20 e 10 gradi prima
	for nome in ["Paratia1", "Paratia2", "Paratia3"]:
		if not paratie.has(nome):
			continue
		var par := paratie[nome] as Node3D
		var gp := {"Paratia1": 90.0, "Paratia2": 180.0, "Paratia3": 270.0}[nome] as float
		for prima in [30.0, 20.0, 10.0]:
			var da: Vector3 = LF.call(F.anello(gp - prima) + Vector3(0, occhio, 0))
			var verso := par.global_position + Vector3.UP * 0.8
			var r := await _libera(da, verso, "%s_da_%d_gradi" % [nome, int(prima)], 75.0)
			var im := r[0] as Image
			var c := r[1] as Camera3D
			var centro := _px(im, c, verso)
			var dentro := _lum(im, centro, 14)
			var fuori := (_lum(im, centro + Vector2(70, 0), 10) + _lum(im, centro - Vector2(70, 0), 10) + _lum(im, centro + Vector2(0, -60), 10)) / 3.0
			print("PARATIA: %s da %d gradi prima (%.1f m): sullo schermo %.3f, intorno %.3f, media dello schermo %.3f" % [nome, int(prima),
					da.distance_to(verso), dentro, fuori, _lum(im, Vector2(im.get_width() / 2.0, im.get_height() / 2.0), 300)])
			_chiudi(c)


func _cime() -> void:
	var m := fiu.get_node(^"Marker")
	var ingresso := (m.get_node(^"Ingresso") as Node3D).global_position
	var fine := (m.get_node(^"FineFila") as Node3D).global_position
	var dir := (fine - ingresso)
	dir.y = 0
	dir = dir.normalized()
	var lato := dir.cross(Vector3.UP)
	# le unità aperte delle pile (il MultiMesh PileCartoneAperte): la cima di ognuna, le più vicine alla strada
	var cime := []
	for mm in fiu.find_children("PileCartoneAperte", "MultiMeshInstance3D", true, false):
		var mmi := mm as MultiMeshInstance3D
		var ab := mmi.multimesh.mesh.get_aabb()
		for i in mmi.multimesh.instance_count:
			var t := mmi.global_transform * mmi.multimesh.get_instance_transform(i)
			var top := t * Vector3(ab.get_center().x, ab.end.y, ab.get_center().z)
			var lungo := dir.dot(top - ingresso)
			var di_lato := absf(lato.dot(top - ingresso))
			if lungo > -1.0 and lungo < 22.0 and di_lato < 6.0:
				cime.append(top)
	cime.sort_custom(func(x, y): return x.distance_to(ingresso) < y.distance_to(ingresso))
	print("FIUME: cime aperte vicino all'ingresso: %d, le prime %s" % [cime.size(), cime.slice(0, 8).map(func(v): return v.snapped(Vector3.ONE * 0.01))])
	var k := 0
	for c: Vector3 in cime.slice(0, 8):
		var verso_strada := (ingresso + dir * dir.dot(c - ingresso)) - c
		verso_strada.y = 0
		verso_strada = verso_strada.normalized()
		var r := await _libera(c + verso_strada * 1.0 + Vector3.UP * 0.6, c, "cima_%d_davanti" % k, 60.0, true)
		_chiudi(r[1])
		r = await _libera(c + Vector3.UP * 1.1 + verso_strada * 0.2, c, "cima_%d_dall_alto" % k, 60.0, true)
		_chiudi(r[1])
		r = await _libera(c + verso_strada * 1.2 + lato * 0.6 + Vector3.UP * 0.25, c, "cima_%d_di_lato" % k, 60.0, true)
		_chiudi(r[1])
		k += 1
	# e dagli occhi, dalla strada, guardando in su le cime
	for s in [1.0, 4.0, 7.0, 10.0]:
		p.teleport(ingresso + dir * s + Vector3.UP * 0.05)
		await _frames(20)
		for l in [-1.0, 1.0]:
			p.look_at_point(ingresso + dir * s + lato * l * 3.0 + Vector3.UP * 2.6)
			await _frames(8)
			await _scatto("cime_dagli_occhi_%d_%s" % [int(s), "sx" if l < 0 else "dx"])
