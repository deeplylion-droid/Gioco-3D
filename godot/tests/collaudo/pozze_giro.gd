extends Node
## Collaudo della stanza delle pozze colorate (lavoro/stanza-pozze), col renderer vero e il giocatore vero, nella Risalita
## della scena di prova (ambiente della sala senza GI, nebbia volumetrica e SSIL, luci del blackout, come
## corridoio_giro.gd). Fasi (secondo argomento, separate da virgole; senza, tutte):
##  - giro: dall'infermeria alla porta nord, il cartello visto arrivando, poi il giro della passerella, la porta stagna
##    chiusa e la vista dal checkpoint d'ingresso; a ogni fotogramma che cosa c'è fra 0,1 e 2 m sopra i piedi;
##  - colori: il cartello alla luce del faretto da 1,5, 0,8 e 0,4 m, e le pozze turchese, viola e arancione dalla
##    passerella: il colore medio sullo schermo (COLORI:);
##  - ravvicinati: ogni oggetto dell'arredo, il cartello, il faretto, la lampada e le plafoniere, di fronte e di lato,
##    con il distacco dal muro e dal pavimento misurato sulla scatola della mesh (ARREDO:);
##  - stati: un colore sbagliato al terzo (turchese, viola, rosa: lampada, scarico, riempimento), poi risolta
##    (turchese, viola, arancione: porta aperta e verde, pozze vuote), dentro una pozza vuota e una piena, la vista dal
##    checkpoint a enigma risolto, e su per la scala di servizio fino alla porta di C3.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/pozze_giro.gd <cartella> [fasi]

const OGNI := 20
var p: Player
var cart := ""
var fasi: PackedStringArray = []
var _k := 0
var ris: Node3D
var st: Node3D
var e: Node3D
var inf: Node3D
var cam: Camera3D
var _mesh_zona: Array[MeshInstance3D] = []


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	fasi = (a[2] if a.size() > 2 else "giro,colori,ravvicinati,stati").split(",")
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


func S(v: Vector3) -> Vector3:
	return st.to_global(v)


func I(v: Vector3) -> Vector3:
	return inf.to_global(v)


# --- spazio libero sopra i piedi ----------------------------------------------------------------------

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
		out.append("collisione " + (str(n.get_path()) if n is Node else str(n)))
	# le mesh (anche senza collisione): la scatola contro il cilindro (come scatola), fra 0,1 e 2 m
	var box := AABB(piedi + Vector3(-0.25, 0.1, -0.25), Vector3(0.5, 1.9, 0.5))
	for m in _mesh_zona:
		if not is_instance_valid(m) or not m.is_visible_in_tree():
			continue
		var ab := m.global_transform * m.get_aabb()
		if ab.intersects(box):
			out.append("mesh " + str(st.get_path_to(m)) if st.is_ancestor_of(m) else "mesh " + str(ris.get_path_to(m)))
	return out


func _cammina(punti: Array, nome: String, accovacciato := false, ogni := OGNI) -> void:
	if accovacciato:
		Input.action_press(&"crouch")
		await _frames(30)
	var fermo := 0
	var max_fermo := 0
	var prima := p.global_position
	var trovati := {}
	var f := 0
	for k in punti.size():
		var a: Vector3 = punti[k]
		Input.action_press(&"move_forward")
		for i in 60 * 20:
			p.look_at_point(Vector3(a.x, p.get_eye_position().y, a.z))
			await get_tree().physics_frame
			var piedi := p.global_position
			for s in _sopra(piedi):
				if not trovati.has(s):
					trovati[s] = piedi.snapped(Vector3.ONE * 0.01)
			fermo = fermo + 1 if piedi.distance_to(prima) < 0.004 else 0
			max_fermo = maxi(max_fermo, fermo)
			prima = piedi
			if f % ogni == 0:
				await _scatto(nome)
			f += 1
			if Vector2(piedi.x - a.x, piedi.z - a.z).length() < 0.35 or fermo > 90:
				break
		if fermo > 90:
			print("POZZE: %s: FERMO in %s andando verso %s" % [nome, p.global_position.snapped(Vector3.ONE * 0.01), a.snapped(Vector3.ONE * 0.01)])
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"crouch")
	print("POZZE: %s: arrivato a %s (ultimo punto %s), fermo al più %d fotogrammi di fila" % [nome,
			p.global_position.snapped(Vector3.ONE * 0.01), (punti[-1] as Vector3).snapped(Vector3.ONE * 0.01), max_fermo])
	for s in trovati:
		print("POZZE:   fra 0,1 e 2 m sopra i piedi: %s (la prima volta coi piedi in %s)" % [s, trovati[s]])
	await _frames(20)


func _guarda(da: Vector3, verso: Vector3, nome: String, accovacciato := false) -> Image:
	p.teleport(da + Vector3.UP * 0.05)
	if accovacciato:
		Input.action_press(&"crouch")
	await _frames(30)
	p.look_at_point(verso)
	await _frames(8)
	var im := await _scatto(nome)
	Input.action_release(&"crouch")
	return im


## Una camera libera (per i ravvicinati), poi di nuovo quella del giocatore.
func _libera(da: Vector3, verso: Vector3, nome: String, fov := 50.0) -> Image:
	var c := Camera3D.new()
	c.fov = fov
	c.near = 0.02
	get_tree().current_scene.add_child(c)
	c.global_position = da
	var su := Vector3.UP if absf((verso - da).normalized().y) < 0.98 else Vector3.FORWARD
	c.look_at(verso, su)
	c.current = true
	await _frames(12)
	var im := await _scatto(nome)
	c.current = false
	c.queue_free()
	if cam:
		cam.current = true
	return im


func _media(im: Image, px: Vector2, r := 4) -> Color:
	var s := Color(0, 0, 0, 0)
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := int(px.x) + dx
			var y := int(px.y) + dy
			if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
				s += im.get_pixel(x, y)
				n += 1
	return s / maxf(n, 1)


func _c8(c: Color) -> String:
	return "(%d, %d, %d)" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]


# --- avvio ---------------------------------------------------------------------------------------------

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
	if not OS.has_environment("VERO"):
		env.environment.sdfgi_enabled = false
		env.environment.volumetric_fog_enabled = false
		env.environment.ssil_enabled = false
	get_tree().current_scene.add_child(env)
	ris = get_tree().current_scene.get_node(^"Risalita") as Node3D
	for nome in ["BambinoCorridoioFiume"]:
		var b := ris.find_child(nome, true, false) as Node3D
		if b:
			b.process_mode = Node.PROCESS_MODE_DISABLED
			b.visible = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for i in 3600:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 300 and ris.get(&"pozze") != null:
			break
	st = ris.get(&"pozze") as Node3D
	inf = ris.get(&"infermeria") as Node3D
	e = st.get_node(^"EnigmaPozze") as Node3D
	var zona := AABB(st.global_position + Vector3(-7.0, -1.5, -9.0), Vector3(36.0, 9.0, 16.0))
	for m in ris.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var ab := mi.global_transform * mi.get_aabb()
		if ab.intersects(zona) and ab.size.x < 3.0 and ab.size.z < 3.0 and not String(mi.name).begins_with("Grigliato"):
			_mesh_zona.append(mi)
	print("POZZE: stanza in %s, infermeria in %s, mesh nella zona %d, luci %s" % [st.global_position.snapped(Vector3.ONE * 0.01),
			inf.global_position.snapped(Vector3.ONE * 0.01), _mesh_zona.size(), GameState.luci])
	# la porta nord dell'infermeria si apre con la luce riaccesa e la keycard (come test_pozze_strada)
	var interr := inf.get_node_or_null(^"Interruttore")
	if interr:
		interr.set(&"powered", true)
	p.add_item(&"keycard", 1, "Keycard")
	p.teleport(I(Vector3(-1.0, 0.05, -1.0)))
	await _frames(60)
	if "giro" in fasi:
		await _giro()
	if "colori" in fasi:
		await _colori()
	if "ravvicinati" in fasi:
		await _ravvicinati()
	if "stati" in fasi:
		await _stati()
	if "scala" in fasi:
		await _scala()
	print("POZZE: finito")
	get_tree().quit()


# --- giro ----------------------------------------------------------------------------------------------

func _giro() -> void:
	# dall'infermeria verso la porta nord: il cartello si vede arrivando
	p.teleport(I(Vector3(0.6, 0.05, 1.2)))
	await _frames(20)
	await _cammina([I(Vector3(-1.2, 0, -1.2)), I(Vector3(-2.2, 0, -2.5)), I(Vector3(-2.2, 0, -3.9)), S(Vector3(0, 0, 3.4))], "arrivo")
	await _cammina([S(Vector3(-3.4, 0, 3.4)), S(Vector3(-3.4, 0, -3.4)), S(Vector3(3.4, 0, -3.4)), S(Vector3(3.4, 0, 3.4)),
			S(Vector3(0, 0, 3.4))], "passerella")
	await _cammina([S(Vector3(3.4, 0, 3.4)), S(Vector3(3.4, 0, -3.4)), S(Vector3(-3.4, 0, -3.4)), S(Vector3(-3.4, 0, 3.4)),
			S(Vector3(0, 0, 3.4))], "passerella_indietro")
	# la porta stagna chiusa con la lampada rossa
	await _guarda(S(Vector3(-1.7, 0, -2.9)), S(Vector3(-1.7, 1.3, -4.0)), "porta_chiusa")
	await _guarda(S(Vector3(0.0, 0, 3.4)), S(Vector3(-1.0, 1.4, -4.0)), "porta_dall_ingresso")
	# il checkpoint d'ingresso: dove si riparte, girati come il punto di ripartenza
	var r := st.get_node(^"Checkpoint/CheckpointIngresso/Ripartenza") as Node3D
	var fw := -r.global_basis.z
	await _guarda(r.global_position, r.global_position + fw * 4.0 + Vector3.UP * 1.5, "continua_ingresso")
	print("POZZE: ripartenza d'ingresso in %s (locale %s), verso %s" % [r.global_position.snapped(Vector3.ONE * 0.01),
			st.to_local(r.global_position).snapped(Vector3.ONE * 0.01), fw.snapped(Vector3.ONE * 0.01)])
	# le viste dagli angoli
	for v in [[Vector3(-3.4, 0, 3.4), Vector3(2.0, 0.0, -2.0)], [Vector3(3.4, 0, -3.4), Vector3(-2.0, 0.0, 2.0)],
			[Vector3(-3.4, 0, -3.4), Vector3(2.0, 0.0, 2.0)], [Vector3(3.4, 0, 3.4), Vector3(-2.0, 0.0, -2.0)]]:
		await _guarda(S(v[0]), S(v[1]), "angolo")
	# verso il soffitto e verso il muro dell'infermeria (la fascia sopra)
	await _guarda(S(Vector3(0, 0, -3.4)), S(Vector3(0, 3.0, 4.0)), "muro_sud_alto")
	await _guarda(S(Vector3(0, 0, 0.0)), S(Vector3(0.5, 3.6, -1.0)), "soffitto_dal_centro")


# --- colori --------------------------------------------------------------------------------------------

func _colori() -> void:
	var c := I(Vector3(-2.95, 1.5, -3.2))
	var quad := I(Vector3(-2.95, 1.73 - 0.405, -3.2 + 0.0085))
	var lato := (I(Vector3(1, 0, 0)) - I(Vector3.ZERO)).normalized()
	for d in [1.5, 0.8, 0.45]:
		var da := I(Vector3(-2.95, 0, -3.2 + d))
		var im := await _guarda(da, c, "cartello_%.1fm" % d, d < 0.6)
		var righe := []
		for k in [-1, 0, 1]:
			var w: Vector3 = quad + lato * (0.092 * float(k))
			if cam.is_position_behind(w):
				continue
			righe.append("%+d: %s" % [k, _c8(_media(im, cam.unproject_position(w), 3 if d > 1.0 else 6))])
		righe.append("smalto: %s" % _c8(_media(im, cam.unproject_position(I(Vector3(-2.95, 1.73 - 0.37, -3.19))), 3)))
		print("COLORI: cartello da %.2f m (x -1, 0, +1 lungo l'asse x dell'infermeria): %s" % [d, ", ".join(righe)])
	# il cartello come si vede venendo verso la porta e in diagonale
	await _guarda(I(Vector3(-1.4, 0, -1.6)), c, "cartello_diagonale")
	await _guarda(I(Vector3(-2.2, 0, -0.2)), I(Vector3(-2.2, 1.5, -3.2)), "porta_nord_da_dentro")
	# le pozze giuste dalla passerella sud e da ovest
	for c2 in ["turchese", "viola", "arancione", "rosa", "bianco_latte"]:
		var t := _pozza_sud(c2)
		var su := Vector3(t.global_position.x, t.get_surface_global_y(), t.global_position.z)
		var im := await _guarda(S(Vector3(st.to_local(t.global_position).x, 0, 3.4)), su, "pozza_%s" % c2)
		print("COLORI: pozza %s dalla passerella sud, al centro: %s" % [c2, _c8(_media(im, cam.unproject_position(su), 8))])
	await _guarda(S(Vector3(-3.4, 0, 0.0)), S(Vector3(0, 0, 0)), "pozze_da_ovest")


func _pozza_sud(c: String) -> WaterTank:
	var migliore: WaterTank = null
	for t: WaterTank in e.call(&"pozze_del_colore", c):
		if migliore == null or t.position.z > migliore.position.z:
			migliore = t
	return migliore


# --- ravvicinati ---------------------------------------------------------------------------------------

func _ravvicinati() -> void:
	var gruppi := []   # [nome, Array di MeshInstance3D]
	var arredo := st.get_node(^"ArredoPozze")
	for n in arredo.find_children("*", "MeshInstance3D", true, false):
		gruppi.append([String(arredo.get_path_to(n)), [n]])
	for nome in ["LampeggianteErrore", "Plafoniera1", "Plafoniera3", "PortaStagna"]:
		var n := st.get_node_or_null(NodePath(nome))
		if n:
			gruppi.append([nome, n.find_children("*", "MeshInstance3D", true, false)])
	var lastra := inf.find_child("CartelloPozze", true, false)
	var faretto := inf.find_child("FarettoCartelloPozze", true, false)
	print("ARREDO: %d mesh nell'arredo" % arredo.find_children("*", "MeshInstance3D", true, false).size())
	for g in gruppi:
		var ms: Array = g[1]
		if ms.is_empty():
			continue
		var ab := AABB()
		var primo := true
		for m: MeshInstance3D in ms:
			var b := st.global_transform.affine_inverse() * (m.global_transform * m.get_aabb())
			ab = b if primo else ab.merge(b)
			primo = false
		# il muro più vicino (facce interne a ±4)
		var muri := {"ovest": ab.position.x + 4.0, "est": 4.0 - ab.end.x, "nord": ab.position.z + 4.0, "sud": 4.0 - ab.end.z}
		var vicino := "ovest"
		for k in muri:
			if muri[k] < muri[vicino]:
				vicino = k
		var normale: Vector3 = {"ovest": Vector3.RIGHT, "est": Vector3.LEFT, "nord": Vector3.BACK, "sud": Vector3.FORWARD}[vicino]
		var centro := ab.get_center()
		var dim := maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
		print("ARREDO: %s: scatola locale da %s a %s; muro %s a %.1f cm, pavimento a %.1f cm (soffitto a %.1f cm)" % [g[0],
				ab.position.snapped(Vector3.ONE * 0.001), ab.end.snapped(Vector3.ONE * 0.001), vicino, muri[vicino] * 100.0,
				ab.position.y * 100.0, (3.6 - ab.end.y) * 100.0])
		var dist := clampf(dim * 1.6, 0.45, 2.2)
		var lat := normale.cross(Vector3.UP)
		await _libera(S(centro + normale * dist + Vector3.UP * 0.05), S(centro), "rav_%s_fronte" % String(g[0]).get_file())
		await _libera(S(centro + normale * (dist * 0.35) + lat * dist), S(centro - lat * 0.2), "rav_%s_lato" % String(g[0]).get_file())
	# cartello e faretto
	for coppia in [["cartello", lastra], ["faretto", faretto]]:
		var n := coppia[1] as Node3D
		if n == null:
			print("ARREDO: ERRORE manca %s" % coppia[0])
			continue
		var ms := n.find_children("*", "MeshInstance3D", true, false)
		if n is MeshInstance3D:
			ms.append(n)
		var ab := AABB()
		var primo := true
		for m: MeshInstance3D in ms:
			var b := inf.global_transform.affine_inverse() * (m.global_transform * m.get_aabb())
			ab = b if primo else ab.merge(b)
			primo = false
		print("ARREDO: %s (infermeria locale): da %s a %s; dal muro nord (z -3,2) %.1f cm, dal soffitto (y 3) %.1f cm" % [coppia[0],
				ab.position.snapped(Vector3.ONE * 0.001), ab.end.snapped(Vector3.ONE * 0.001), (ab.position.z + 3.2) * 100.0,
				(3.0 - ab.end.y) * 100.0])
		var cc := ab.get_center()
		await _libera(I(cc + Vector3(0, -0.1 if coppia[0] == "faretto" else 0.0, 0.7)), I(cc), "rav_%s_fronte" % coppia[0])
		await _libera(I(cc + Vector3(0.5, 0.0, 0.18)), I(cc + Vector3(-0.1, 0, 0)), "rav_%s_lato_est" % coppia[0])
		await _libera(I(cc + Vector3(-0.22, 0.0, 0.18)), I(cc + Vector3(0.1, 0, 0)), "rav_%s_lato_ovest" % coppia[0])
	# il faretto e il cartello dal basso e l'insieme
	await _libera(I(Vector3(-2.7, 1.0, -2.2)), I(Vector3(-2.95, 2.6, -2.8)), "rav_faretto_dal_basso")


# --- stati ---------------------------------------------------------------------------------------------

func _zaino() -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)


func _togli(c: String, nome: String) -> void:
	_zaino()
	var t := _pozza_sud(c)
	p.teleport(S(Vector3(st.to_local(t.global_position).x, 0.05, 3.4)))
	await _frames(20)
	var su := Vector3(t.global_position.x, t.get_surface_global_y(), t.global_position.z)
	p.look_at_point(su)
	await _frames(5)
	var prima := p.water_pack.tank_amount
	Input.action_press(&"suck")
	for i in 30:
		await get_tree().physics_frame
		if i % 10 == 0:
			await _scatto("%s_aspira_%s" % [nome, c])
	Input.action_release(&"suck")
	var dopo := p.water_pack.tank_amount
	p.look_at_point(S(Vector3(st.to_local(t.global_position).x * 0.5, -0.6, 0.0)))
	for i in 60 * 8:
		await get_tree().physics_frame
		if i % 20 == 0:
			await _scatto("%s_gorgo_%s" % [nome, c])
		if c in (e.get(&"tolti") as Array) or int(e.get(&"stato")) != 0:
			break
	print("POZZE: %s: aspirato da %s (zaino da %.1f a %.1f L), tolti %s, stato %d" % [nome, c, prima, dopo, e.get(&"tolti"), int(e.get(&"stato"))])


func _stati() -> void:
	# 1. sbagliato al terzo: turchese, viola, poi rosa
	for c in ["turchese", "viola", "rosa"]:
		await _togli(c, "sbagliato")
	p.teleport(S(Vector3(-0.6, 0.05, 3.4)))
	await _frames(2)
	p.look_at_point(S(Vector3(-0.6, 1.0, -4.0)))
	var acceso := 0
	var luce := st.get_node(^"LampeggianteErrore/Luce") as Light3D
	for i in 60 * 7:
		await get_tree().physics_frame
		if luce.visible:
			acceso += 1
		if i < 90 and i % 4 == 0 or i >= 90 and i % 20 == 0:
			await _scatto("sbagliato_lampada_ricarica")
		if int(e.get(&"stato")) == 0 and i > 100:
			break
	print("POZZE: sbagliato: lampada accesa %d fotogrammi, stato alla fine %d, tolti %s" % [acceso, int(e.get(&"stato")), e.get(&"tolti")])
	await _guarda(S(Vector3(0.0, 0, 3.4)), S(Vector3(0, 0, 0)), "sbagliato_dopo")
	# 2. risolta
	for c in ["turchese", "viola", "arancione"]:
		await _togli(c, "risolta")
	await _guarda(S(Vector3(-1.7, 0, -2.6)), S(Vector3(-1.7, 1.3, -4.0)), "risolta_porta")
	for i in 60 * 3:
		await get_tree().physics_frame
		if i % 12 == 0:
			await _scatto("risolta_porta_si_apre")
	print("POZZE: risolta: stato %d, porta aperta %s" % [int(e.get(&"stato")), (e.get(&"porta") as Node).get(&"e_aperta")])
	await _guarda(S(Vector3(0.0, 0, 3.4)), S(Vector3(0, 0, 0)), "risolta_pozze")
	await _guarda(S(Vector3(-3.4, 0, 3.4)), S(Vector3(1.0, -0.5, -1.0)), "risolta_pozze_angolo")
	var t := _pozza_sud("turchese")
	await _guarda(S(Vector3(st.to_local(t.global_position).x, 0, 3.4)), t.global_position, "risolta_pozza_vuota_giu")
	# dentro una pozza vuota, poi fuori saltando verso la passerella
	await _dentro(t, "vuota")
	var r := _pozza_sud("rosa")
	await _dentro(r, "piena")
	# la vista dal checkpoint a enigma risolto
	var rp := st.get_node(^"Checkpoint/CheckpointRisolto/Ripartenza") as Node3D
	await _guarda(rp.global_position, rp.global_position - rp.global_basis.z * 4.0 + Vector3.UP * 1.5, "continua_risolto")
	await _guarda(rp.global_position, rp.global_position + rp.global_basis.z * 4.0 + Vector3.UP * 1.5, "continua_risolto_dietro")
	print("POZZE: ripartenza a enigma risolto in %s (locale %s), verso %s" % [rp.global_position.snapped(Vector3.ONE * 0.01),
			st.to_local(rp.global_position).snapped(Vector3.ONE * 0.01), (-rp.global_basis.z).snapped(Vector3.ONE * 0.01)])
	# 3. oltre la porta stagna, su per la scala fino alla porta di C3
	var porta := e.get(&"porta") as Node3D
	var m := ris.get_node(^"Marker")
	var punti := [porta.global_position + porta.global_basis.z * 0.8, porta.global_position - porta.global_basis.z * 1.5]
	for nome in ["CimaScala", "PortaC3"]:
		var mk := m.get_node_or_null(NodePath(nome)) as Node3D
		if mk:
			punti.append(mk.global_position)
	print("POZZE: strada della scala %s" % [punti.map(func(v): return v.snapped(Vector3.ONE * 0.01))])
	p.teleport(S(Vector3(-1.7, 0.05, -2.4)))
	await _frames(20)
	await _cammina(punti, "scala")
	# e in giù, guardando dove si mette il piede
	var giu := punti.duplicate()
	giu.reverse()
	await _cammina(giu, "scala_in_giu")


func _dentro(t: WaterTank, nome: String) -> void:
	var fondo := t.global_position + Vector3(0, 0.05, 0)
	p.teleport(fondo)
	await _frames(40)
	var y0 := p.global_position.y
	await _scatto("dentro_%s_avanti" % nome)
	p.look_at_point(S(Vector3(st.to_local(t.global_position).x, 0.3, 4.0)))
	await _frames(6)
	await _scatto("dentro_%s_verso_passerella" % nome)
	print("POZZE: dentro la pozza %s (%s): piedi a %.2f (pavimento %.2f), in acqua %s" % [nome, t.fill_pigment, y0,
			st.global_position.y, p.is_in_water()])
	# avanti e salto, verso sud
	var uscito := false
	Input.action_press(&"move_forward")
	for i in 60 * 4:
		p.look_at_point(S(Vector3(st.to_local(t.global_position).x, 1.2, 4.0)))
		if i % 30 == 5:
			Input.action_press(&"jump")
		if i % 30 == 9:
			Input.action_release(&"jump")
		await get_tree().physics_frame
		if i % 15 == 0:
			await _scatto("dentro_%s_esce" % nome)
		if st.to_local(p.global_position).z > 2.85 and p.global_position.y > st.global_position.y - 0.05:
			uscito = true
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"jump")
	print("POZZE: dalla pozza %s si esce saltando: %s, fine %s (locale %s)" % [nome, uscito, p.global_position.snapped(Vector3.ONE * 0.01),
			st.to_local(p.global_position).snapped(Vector3.ONE * 0.01)])
	await _frames(20)


## Solo la strada della scala, con la stanza già risolta (come Continua dal checkpoint 15): dalla ripartenza oltre la
## porta stagna, lungo le rampe verso est, in cima verso sud nel corridoio e fino alla porta di C3; poi in giù.
func _scala() -> void:
	e.call(&"load_state", {"stato": 2, "tolti": ["turchese", "viola", "arancione"]})
	await _frames(30)
	# la porta stagna aperta: il cardine (a ovest del vano) dalla stanza e dal pianerottolo
	await _frames(200)
	for h in [0.3, 1.05, 1.9]:
		await _libera(S(Vector3(-1.75, h + 0.1, -3.2)), S(Vector3(-2.2, h, -4.05)), "cardine_dalla_stanza_%.1f" % h, 60.0)
		await _libera(S(Vector3(-1.6, h + 0.1, -5.3)), S(Vector3(-2.2, h, -4.3)), "cardine_dal_pianerottolo_%.1f" % h, 60.0)
	await _libera(S(Vector3(-1.7, 1.6, -2.4)), S(Vector3(-1.7, 1.1, -5.0)), "porta_aperta_dalla_stanza", 70.0)
	await _libera(S(Vector3(-0.9, 1.6, -5.6)), S(Vector3(-1.9, 1.0, -4.0)), "porta_aperta_dal_pianerottolo", 70.0)
	var rp := st.get_node(^"Checkpoint/CheckpointRisolto/Ripartenza") as Node3D
	p.teleport(rp.global_position + Vector3.UP * 0.05)
	await _frames(30)
	await _scatto("scala_ripartenza")
	var porta := e.get(&"porta") as Node3D
	var m := ris.get_node(^"Marker")
	var cima := (m.get_node(^"CimaScala") as Node3D).global_position
	var c3 := (m.get_node(^"PortaC3") as Node3D).global_position
	var oltre := porta.global_position - porta.global_basis.z * 1.5
	var punti := [porta.global_position + porta.global_basis.z * 0.6, oltre, Vector3(cima.x, cima.y, oltre.z), cima, c3]
	print("POZZE: strada della scala %s" % [punti.map(func(v): return v.snapped(Vector3.ONE * 0.01))])
	await _cammina(punti, "scala_su", false, 15)
	var giu := punti.duplicate()
	giu.reverse()
	await _cammina(giu.slice(1), "scala_giu", false, 15)
