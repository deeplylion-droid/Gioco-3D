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
	if OS.has_environment("LUCE_TECNICA"):
		# solo tecnica, nel gioco non c'è: per vedere i pezzi al buio
		var o := OmniLight3D.new()
		o.light_energy = 1.2
		o.omni_range = 2.5
		c.add_child(o)
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

const F := preload("res://scripts/risalita/fiume_gioco.gd")
var fiume: Node3D

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
	for nome in ["BambinoCorridoioFiume"]:
		var b := ris.find_child(nome, true, false) as Node3D
		if b:
			b.process_mode = Node.PROCESS_MODE_DISABLED
			b.visible = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for i in 3600:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 300 and ris.get(&"pozze") != null and ris.get(&"fiume") != null:
			break
	st = ris.get(&"pozze") as Node3D
	inf = ris.get(&"infermeria") as Node3D
	fiume = ris.get(&"fiume") as Node3D
	e = st.get_node(^"EnigmaPozze") as Node3D
	for m in ris.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var ab := mi.global_transform * mi.get_aabb()
		if ab.size.x < 3.0 and ab.size.z < 3.0 and not String(mi.name).begins_with("Grigliato"):
			_mesh_zona.append(mi)
	print("RIC: pozze %s, fiume %s, mesh %d" % [st != null, fiume != null, _mesh_zona.size()])
	if "scala" in fasi:
		await _ric_scala()
	if "angolo" in fasi:
		await _ric_angolo()
	if "corridoio" in fasi:
		await _ric_corridoio()
	print("RIC: finito")
	get_tree().quit()


func _ray(da: Vector3, a: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(da, a)
	q.exclude = [p.get_rid()]
	return p.get_world_3d().direct_space_state.intersect_ray(q)


func _ric_scala() -> void:
	e.call(&"load_state", {"stato": 2, "tolti": ["turchese", "viola", "arancione"]})
	await _frames(240)
	var nastro := ris.get_node(^"NastroCimaScala") as Node3D
	var strisce := 0
	var max_gap := 0.0
	for mi: MeshInstance3D in nastro.get_children():
		var ab := mi.global_transform * mi.get_aabb()
		var c := ab.get_center()
		if ab.size.y < 0.01:
			# nastro: sotto, il pavimento (in 5 punti lungo la striscia)
			strisce += 1
			for f: float in [0.02, 0.25, 0.5, 0.75, 0.98]:
				var pt := ab.position + Vector3(ab.size.x * f if ab.size.x > ab.size.z else ab.size.x * 0.5, 0.0, ab.size.z * f if ab.size.z >= ab.size.x else ab.size.z * 0.5)
				var h := _ray(pt + Vector3.UP * 0.05, pt + Vector3.DOWN * 0.3)
				var gap: float = (pt.y - (h["position"] as Vector3).y) if h else 9.0
				max_gap = maxf(max_gap, absf(gap))
				if absf(gap) > 0.002:
					print("RIC: NASTRO %s distacco %.4f m in %s" % [mi.name, gap, pt.snapped(Vector3.ONE * 0.001)])
		else:
			# fascia: dietro, il muro (verso la faccia sottile), in 7 punti
			var asse := Vector3.RIGHT if ab.size.x < ab.size.z else Vector3.BACK
			for s: float in [-1.0, 1.0]:
				var lungo := Vector3.BACK if asse == Vector3.RIGHT else Vector3.RIGHT
				var L := ab.size.z if asse == Vector3.RIGHT else ab.size.x
				for f: float in [0.01, 0.15, 0.3, 0.5, 0.7, 0.85, 0.99]:
					var pt := c + lungo * (f - 0.5) * L
					var faccia := pt + asse * s * (ab.size.x if asse == Vector3.RIGHT else ab.size.z) * 0.5
					var h := _ray(c + lungo * (f - 0.5) * L, faccia + asse * s * 0.2)
					if h:
						var d := (h["position"] as Vector3).distance_to(faccia)
						print("RIC: FASCIA %s lato %d f %.2f: muro a %.4f m dalla faccia (%s)" % [mi.name, int(s), f, d, (h["collider"] as Node).name])
			print("RIC: fascia %s box %s %s" % [mi.name, ab.position.snapped(Vector3.ONE * 0.001), ab.size.snapped(Vector3.ONE * 0.001)])
	print("RIC: strisce di nastro %d, distacco massimo dal pavimento %.4f m" % [strisce, max_gap])
	# le lampade rosse vicino alla cima: la mesh, il fondo, il muro dietro
	var cima := (ris.get_node(^"Marker/CimaScala") as Node3D).global_position
	var c3 := (ris.get_node(^"Marker/PortaC3") as Node3D).global_position
	for n in ris.find_children("*", "OmniLight3D", true, false):
		var l := n as OmniLight3D
		if l.light_color.r > 0.9 and l.light_color.g < 0.3 and l.global_position.distance_to(cima) < 8.0:
			var mesh: MeshInstance3D = null
			for m in ris.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				if mi.global_position.distance_to(l.global_position) < 0.6 and (mesh == null or mi.global_position.distance_to(l.global_position) < mesh.global_position.distance_to(l.global_position)):
					mesh = mi
			var ab := mesh.global_transform * mesh.get_aabb() if mesh else AABB(l.global_position, Vector3.ZERO)
			var pav := _ray(ab.get_center(), ab.get_center() + Vector3.DOWN * 4.0)
			var fondo := ab.position.y - ((pav["position"] as Vector3).y if pav else 0.0)
			var muro := ""
			for d: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
				var h := _ray(ab.get_center(), ab.get_center() + d * 0.6)
				if h:
					var faccia: float = absf(d.dot(ab.get_center() - (h["position"] as Vector3))) - absf(d.dot(ab.size)) * 0.5
					muro += " %s: %.4f" % [d, faccia]
			print("RIC: LAMPADA %s mesh %s fondo a %.3f m dal pavimento, box %s %s, muro dietro%s" % [ris.get_path_to(l), mesh.name if mesh else "-",
					fondo, ab.position.snapped(Vector3.ONE * 0.001), ab.size.snapped(Vector3.ONE * 0.001), muro])
			var verso := l.global_position + Vector3(0, -0.05, 0)
			await _libera(verso + Vector3(0, -0.5, 0) + (cima - verso).normalized() * Vector3(1, 0, 1) * 0.6, verso, "lampada_%s_sotto" % l.name, 45.0)
			await _libera(verso + Vector3(0, 0.05, 0) + (Vector3(1, 0, 0) if absf(l.global_basis.z.z) > 0.5 else Vector3(0, 0, 1)) * 0.45, verso, "lampada_%s_lato" % l.name, 45.0)
	# da vicino: nastro (prima, in mezzo, ultima del tratto e del corridoio) e fascia (capi e mezzo)
	var figli := nastro.get_children()
	for k in [0, 3, figli.size() - 3, figli.size() - 1]:
		var mi := figli[clampi(k, 0, figli.size() - 1)] as MeshInstance3D
		var ab := mi.global_transform * mi.get_aabb()
		var c := ab.get_center()
		if ab.size.y < 0.01:
			var lungo := Vector3.RIGHT if ab.size.x > ab.size.z else Vector3.BACK
			var L := maxf(ab.size.x, ab.size.z)
			await _libera(c + lungo * L * 0.5 + Vector3(0, 0.12, 0) + lungo.cross(Vector3.UP) * 0.25, c + lungo * L * 0.5, "nastro_%s_capo" % mi.name, 40.0)
			await _libera(c + Vector3(0, 0.08, 0) + lungo.cross(Vector3.UP) * 0.3, c, "nastro_%s_radente" % mi.name, 40.0)
		else:
			var asse := Vector3.RIGHT if ab.size.x < ab.size.z else Vector3.BACK
			var lungo := Vector3.BACK if asse == Vector3.RIGHT else Vector3.RIGHT
			var L := ab.size.z if asse == Vector3.RIGHT else ab.size.x
			var fuori := -asse if _ray(c, c + asse * 0.3) else asse
			for f: float in [0.0, 0.5, 1.0]:
				var pt := c + lungo * (f - 0.5) * L
				await _libera(pt + fuori * 0.3 + lungo * (0.2 if f < 0.5 else -0.2) + Vector3(0, 0.06, 0), pt, "fascia_%s_%.1f" % [mi.name, f], 40.0)
	# il giro: dalla ripartenza della stanza risolta su per la scala fino alla porta di C3, dagli occhi, e indietro
	var porta := e.get(&"porta") as Node3D
	var oltre := porta.global_position - porta.global_basis.z * 1.5
	var punti := [porta.global_position + porta.global_basis.z * 0.6, oltre, Vector3(cima.x, cima.y, oltre.z), cima, c3]
	var rp := st.get_node(^"Checkpoint/CheckpointRisolto/Ripartenza") as Node3D
	p.teleport(rp.global_position + Vector3.UP * 0.05)
	await _frames(30)
	await _cammina(punti, "scala_su", false, 12)
	var giu := punti.duplicate()
	giu.reverse()
	await _cammina(giu.slice(1), "scala_giu", false, 12)
	# a ogni passo della cima, quello che c'è sopra la testa (raggi in su da 0 a 2 m sul tratto e sul corridoio)
	var basso := 9.0
	for xx in range(int((cima.x - 1.0) * 10), int((c3.x + 0.6) * 10), 2):
		for zz in range(int((cima.z - 4.0) * 10), int((cima.z + 1.2) * 10), 2):
			var pt := Vector3(xx / 10.0, cima.y + 0.05, zz / 10.0)
			var pav := _ray(pt + Vector3.UP * 0.3, pt + Vector3.DOWN * 0.5)
			if not pav:
				continue
			var y0: float = (pav["position"] as Vector3).y
			for m in _mesh_zona:
				var ab := m.global_transform * m.get_aabb()
				if ab.has_point(Vector3(pt.x, ab.get_center().y, pt.z)) and ab.position.y > y0 + 0.02 and ab.position.y < y0 + 2.0:
					basso = minf(basso, ab.position.y - y0)
					print("RIC: SOPRA in %s: %s a %.3f m" % [pt.snapped(Vector3.ONE * 0.1), ris.get_path_to(m), ab.position.y - y0])
	print("RIC: cima della scala: la cosa più bassa sopra il pavimento a %.3f m" % basso)


func _ric_angolo() -> void:
	var G := func(v: Vector3) -> Vector3: return fiume.to_global(v)
	# la pila dell'angolo: la collisione della colonna
	var col: CollisionShape3D = null
	for c in fiume.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		var lp := fiume.to_local(cs.global_position)
		if cs.shape is BoxShape3D and Vector2(lp.x, lp.z).distance_to(F.ANGOLO_PILA) < 0.3:
			col = cs
	if col:
		var b := (col.shape as BoxShape3D).size
		var lp := fiume.to_local(col.global_position)
		print("RIC: PILA ANGOLO collisione %s centro %s, base a %.3f m" % [b.snapped(Vector3.ONE * 0.001), lp.snapped(Vector3.ONE * 0.001), lp.y - b.y * 0.5])
		# il muro nord: dalla faccia nord della pila
		for f: float in [-0.4, 0.0, 0.4]:
			for h: float in [0.3, 1.0, 1.8]:
				var da: Vector3 = col.global_transform * Vector3(f * b.x, h - b.y * 0.5, -b.z * 0.5 - 0.005)
				var r := _ray(da, da + col.global_basis.z * -0.6)
				var r2 := _ray(col.global_transform * Vector3(f * b.x, h - b.y * 0.5, b.z * 0.5 + 0.005), col.global_transform * Vector3(f * b.x, h - b.y * 0.5, b.z * 0.5 + 0.6))
				print("RIC: PILA ANGOLO f %.1f h %.1f: verso -z %s, verso +z %s" % [f, h,
						("%.3f m (%s)" % [(r["position"] as Vector3).distance_to(da), (r["collider"] as Node).name]) if r else "niente entro 60 cm",
						("%.3f m (%s)" % [(r2["position"] as Vector3).distance_to(col.global_transform * Vector3(f * b.x, h - b.y * 0.5, b.z * 0.5 + 0.005)), (r2["collider"] as Node).name]) if r2 else "niente"])
	else:
		print("RIC: PILA ANGOLO: collisione non trovata")
	# le scatole vere della pila (MultiMesh): le istanze entro la colonna e il loro punto più basso
	var basse := 9.0
	var n := 0
	for mm in fiume.find_children("Pile*", "MultiMeshInstance3D", true, false):
		var mmi := mm as MultiMeshInstance3D
		for i in mmi.multimesh.instance_count:
			var t := mmi.multimesh.get_instance_transform(i)
			var lp := fiume.to_local(mmi.global_transform * t.origin)
			if lp.x > -29.6 and lp.x < -28.2 and lp.z > -28.4 and lp.z < -27.1:
				n += 1
				var ab := (mmi.global_transform * t) * mmi.multimesh.mesh.get_aabb()
				basse = minf(basse, fiume.to_local(ab.position).y)
	print("RIC: PILA ANGOLO: %d scatole/unità, la più bassa a %.4f m" % [n, basse])
	# la nicchia: punti dentro, visti dalla soglia e dalla strada (raggi sulle collisioni)
	var nicchia := []
	for x in [-30.25, -30.0, -29.75, -29.58]:
		for z in [-28.5, -28.15, -27.8, -27.4]:
			for y in [0.25, 0.7, 1.1]:
				nicchia.append(G.call(Vector3(x, y, z)))
	var punti_occhio := [["soglia", Vector3(F.INGRESSO_X, 1.6, F.Z0 - 0.15)], ["soglia_dentro", Vector3(F.INGRESSO_X, 1.6, F.Z0 + 0.4)],
			["strada_1m", Vector3(F.INGRESSO_X, 1.6, F.Z0 + 1.0)], ["strada_2m", Vector3(F.INGRESSO_X, 1.6, F.Z0 + 2.0)],
			["strada_4m", Vector3(F.INGRESSO_X, 1.6, F.Z0 + 4.0)], ["strada_2m_ovest", Vector3(F.INGRESSO_X - 0.8, 1.6, F.Z0 + 2.0)],
			["accovacciato_1m", Vector3(F.INGRESSO_X, 0.9, F.Z0 + 1.0)]]
	for po in punti_occhio:
		var occhio: Vector3 = G.call(po[1])
		var visti := 0
		var quali := []
		for q: Vector3 in nicchia:
			if not _ray(occhio, q):
				visti += 1
				quali.append(fiume.to_local(q).snapped(Vector3.ONE * 0.01))
		if quali:
			print("RIC: NICCHIA da %s visti: %s" % [po[0], quali])
		print("RIC: NICCHIA da %s: %d punti su %d visibili (senza muri né pile in mezzo)" % [po[0], visti, nicchia.size()])
	# scatti dagli occhi: dalla soglia girandosi a sinistra, dalla strada, e la pila da vicino
	for po in [["soglia_avanti", Vector3(F.INGRESSO_X, 0, F.Z0 - 0.15), Vector3(F.INGRESSO_X, 1.3, F.Z0 + 5.0)],
			["soglia_sinistra", Vector3(F.INGRESSO_X, 0, F.Z0 - 0.15), Vector3(-30.0, 0.9, -27.7)],
			["dentro_sinistra", Vector3(F.INGRESSO_X, 0, F.Z0 + 0.5), Vector3(-30.0, 0.9, -27.7)],
			["strada_2m_sinistra", Vector3(F.INGRESSO_X, 0, F.Z0 + 2.0), Vector3(-30.0, 0.9, -27.7)],
			["strada_4m_indietro", Vector3(F.INGRESSO_X, 0, F.Z0 + 4.0), Vector3(-29.0, 1.0, -28.0)]]:
		await _guarda(G.call(po[1]), G.call(po[2]), "angolo_" + po[0])
	# lo spazio fra la pila e il muro nord: dall'alto, guardando giù, e radente lungo il muro
	await _libera(G.call(Vector3(-28.9, 5.9, -28.3)), G.call(Vector3(-28.9, 0.0, -28.35)), "pila_muro_nord_dall_alto", 60.0)
	await _libera(G.call(Vector3(-27.6, 1.2, -28.45)), G.call(Vector3(-29.4, 1.0, -28.4)), "pila_muro_nord_radente", 60.0)
	await _libera(G.call(Vector3(-27.6, 0.25, -28.45)), G.call(Vector3(-29.4, 0.15, -28.4)), "pila_muro_nord_radente_basso", 60.0)
	await _libera(G.call(Vector3(-28.0, 0.25, -26.8)), G.call(Vector3(-28.9, 0.05, -27.5)), "pila_angolo_base", 50.0)
	await _libera(G.call(Vector3(-28.05, 1.4, -28.45)), G.call(Vector3(-28.6, 1.2, -28.55)), "pila_angolo_muro_nord", 50.0)
	await _libera(G.call(Vector3(-28.0, 2.6, -27.0)), G.call(Vector3(-28.9, 1.6, -28.0)), "pila_angolo_alto", 60.0)
	await _libera(G.call(Vector3(-29.0, 1.6, -26.3)), G.call(Vector3(-30.0, 0.8, -27.9)), "nicchia_da_dentro", 60.0)


func _ric_corridoio() -> void:
	var da := Vector3(F.INGRESSO_X, 0, F.Z0 + 1.0)
	var dir := (F.FINE_FILA - da).normalized()
	var lungo := da.distance_to(F.FINE_FILA)
	var punti := []
	for f: float in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]:
		punti.append(fiume.to_global(da + dir * lungo * f))
	p.teleport(fiume.to_global(Vector3(F.INGRESSO_X, 0.05, F.Z0 - 0.3)))
	await _frames(30)
	await _cammina(punti, "corridoio", false, 25)
	for k in 4:
		var q: Vector3 = da + dir * lungo * [0.08, 0.35, 0.62, 0.9][k]
		await _guarda(fiume.to_global(q), fiume.to_global(q + dir * 8.0 + Vector3(0, 1.3, 0)), "corridoio_%d" % (k + 1))
