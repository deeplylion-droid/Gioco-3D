extends Node
## Ricontrollo degli stendardi di grafica nelle condotte dell'inseguimento (StendardiInseguimento), fatto da enigmi
## (squadra che non li ha costruiti). La sala della torre intera, con le condotte, come scatti_sagome_club.gd.
## Gruppi:
## - "giro": dagli occhi del giocatore in piedi nell'acqua (1,65 m sopra il fondo), dal mezzo di ogni vasca, dal posto
##   davanti al bersaglio giusto e dall'angolo opposto, verso gli stendardi che si vedono da quella vasca;
## - "lei": lei su in ogni vasca e in ogni scolo; dagli occhi verso di lei e verso lo stendardo vicino, e la distanza
##   delle sue ossa dalla stoffa, dalle corde e dai bastoni (stampata);
## - "tubo": dentro il tubo che scende allo scolo 0, accovacciati, verso lo stendardo 3, e dallo scolo in su;
## - "vicino": le mollette, le corde ai capi dei bastoni e i nodi alle travi, da vicino (con SCATTI_LUCE=1).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/ricontrollo_stendardi.gd <cartella> [giro|lei|tubo|vicino]

## Dove guarda la faccia disegnata di ogni lenzuolo (assets_src/stendardi/stendardi.py, "girato").
const VERSO := {1: Vector3(0, 0, 1), 2: Vector3(-1, 0, 0), 3: Vector3(1, 0, 0), 4: Vector3(0, 0, 1)}
## Quali stendardi si vedono da quale vasca (LEGGIMI di grafica).
const DALLA_VASCA := {0: [1], 1: [2], 2: [3, 4]}

var _cartella := ""
var _cam: Camera3D
var _ins: SalaInseguimento
var _st: Node3D
var _luce := OS.get_environment("SCATTI_LUCE") == "1"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://ricontrollo_stendardi"
	var gruppo: String = a[2] if a.size() > 2 else "giro"
	DirAccess.make_dir_recursive_absolute(_cartella)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	_ins = torre.inseguimento as SalaInseguimento
	for i in 600:
		await get_tree().physics_frame
		if _ins.costruita:
			break
	for i in 30:
		await get_tree().physics_frame
	if _ins.lei:
		_ins.lei.visible = false
	_st = _ins.get_node_or_null(^"Stendardi") as Node3D
	if _st == null:
		print("MANCANO gli stendardi")
		get_tree().quit(1)
		return
	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.near = 0.02
	add_child(_cam)
	_cam.make_current()
	if _luce:
		var l := OmniLight3D.new()
		l.omni_range = 1.5
		l.light_energy = 0.6
		l.shadow_enabled = true
		_cam.add_child(l)
		l.position = Vector3(0.05, 0.08, 0)
	match gruppo:
		"giro":
			await _giro()
		"lei":
			await _lei()
		"tubo":
			await _tubo()
		_:
			await _vicino()
	print("FINE")
	get_tree().quit()


func _pezzo(nome: String) -> MeshInstance3D:
	return _st.find_child(nome, true, false) as MeshInstance3D


func _centro(nome: String) -> Vector3:
	var m := _pezzo(nome)
	return (m.global_transform * m.get_aabb()).get_center()


func _vertici(nome: String) -> PackedVector3Array:
	var m := _pezzo(nome)
	var out := PackedVector3Array()
	for s in m.mesh.get_surface_count():
		for p in (m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(m.global_transform * p)
	return out


func _occhi(v: int) -> Vector3:
	var d: Dictionary = _ins.dati["vasche"][v]
	var r: Array = d["rett"]
	return Vector3((r[0] + r[2]) * 0.5, float(d["fondo"]) + 1.65, -(r[1] + r[3]) * 0.5)


## Tre posti dove si sta in piedi nella vasca [param v]: il mezzo, davanti al bersaglio giusto, l'angolo opposto.
func _posti(v: int) -> Array:
	var c := _occhi(v)
	var p: Dictionary = _ins.dati["paratie"][v * 2]
	var bers := _ins.b(p["bersaglio"])
	var verso := Vector3(bers.x - c.x, 0, bers.z - c.z)
	var davanti := c + verso * 0.55
	var opposto := c - verso.normalized() * 1.9
	return [["mezzo", c], ["davanti_al_bersaglio", davanti], ["angolo_opposto", opposto]]


func _giro() -> void:
	for v in 3:
		for p in _posti(v):
			for s in DALLA_VASCA[v]:
				var c := _centro("stendardo_%d" % s)
				await _scatto("v%d_%s_verso_stendardo_%d" % [v + 1, p[0], s], p[1], c)
		# tutto intorno dal mezzo, per vedere bocche, paratie, bersagli e lampade insieme agli stendardi
		var o := _occhi(v)
		for k in 4:
			var ang := TAU * k / 4.0
			await _scatto("v%d_intorno_%d" % [v + 1, k * 90], o, o + Vector3(sin(ang), 0.1, -cos(ang)))


func _ossa() -> PackedVector3Array:
	var out := PackedVector3Array()
	var sk := _ins.lei.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return out
	for i in sk.get_bone_count():
		out.append(sk.global_transform * sk.get_bone_global_pose(i).origin)
	return out


## La distanza minima fra le ossa di lei e ogni pezzo degli stendardi (stoffa, corde, bastoni, mollette).
func _distanze_da_lei(dove: String) -> void:
	var ossa := _ossa()
	var testa := ossa[0]
	var basso := ossa[0]
	for o in ossa:
		if o.y > testa.y:
			testa = o
		if o.y < basso.y:
			basso = o
	print("LEI %s: %d ossa, la più alta a %s, la più bassa a %s" % [dove, ossa.size(), testa, basso])
	for m in _st.find_children("stendardo_*", "MeshInstance3D", true, false):
		var vv := _vertici(String(m.name))
		var dmin := 1e9
		for o in ossa:
			for p in vv:
				dmin = minf(dmin, o.distance_to(p))
		if dmin < 3.0:
			print("   %s: osso più vicino a %.2f m" % [m.name, dmin])


func _lei() -> void:
	var stati := []
	for v in 3:
		stati.append(["vasca_%d" % v, _ins.call(&"_posto_vasca", v) as Vector3, _occhi(v), DALLA_VASCA[v]])
	for k in 3:
		var d: Dictionary = _ins.dati["scolo"][k]
		var r: Array = d["rett"]
		var occhi := Vector3((r[0] + r[2]) * 0.5, float(d["fondo"]) + 1.65, -(r[1] + r[3]) * 0.5)
		stati.append(["scolo_%d" % k, _ins.call(&"_posto_scolo", k) as Vector3, occhi, [1, 2, 3, 4]])
	for s in stati:
		_ins.call(&"_lei_sale", s[0], s[1], 1.2 if String(s[0]).begins_with("scolo") else 1.6)
		for i in 150:
			await get_tree().physics_frame
		_distanze_da_lei(s[0])
		var occhi: Vector3 = s[2]
		var su: Vector3 = s[1]
		await _scatto("%s_lei_su" % s[0], occhi, Vector3(su.x, occhi.y + 1.5, su.z))
		for k in s[3]:
			var c := _centro("stendardo_%d" % k)
			if c.distance_to(occhi) < 16.0:
				await _scatto("%s_lei_su_verso_stendardo_%d" % [s[0], k], occhi, c)
		# da più lontano, per vedere lei e lo stendardo insieme
		var indietro := occhi + (occhi - Vector3(su.x, occhi.y, su.z)).normalized() * 1.5
		await _scatto("%s_lei_su_da_dietro" % s[0], indietro, Vector3(su.x, occhi.y + 2.5, su.z))
		_ins.lei.visible = false
		_ins.lei_stato = SalaInseguimento.Lei.VIA
		for i in 20:
			await get_tree().physics_frame


func _tubo() -> void:
	var linea: Array = _ins.dati["tubi"]["ins_A_scolo_0"]
	var n := linea.size()
	var c3 := _centro("stendardo_3")
	for i in [n - 9, n - 6, n - 4, n - 2, n - 1]:
		var p := _ins.b(linea[i])
		var q := _ins.b(linea[mini(i + 1, n - 1)])
		var avanti := (q - p).normalized() if i < n - 1 else (p - _ins.b(linea[i - 1])).normalized()
		var occhi := p + Vector3.UP * 0.9
		await _scatto("tubo_%02d_avanti" % i, occhi, occhi + avanti * 3.0 + Vector3.UP * 0.6)
		await _scatto("tubo_%02d_verso_stendardo_3" % i, occhi, c3)
	# in piedi nello scolo 0, sotto lo stendardo
	var d: Dictionary = _ins.dati["scolo"][0]
	var r: Array = d["rett"]
	var occhi := Vector3((r[0] + r[2]) * 0.5, float(d["fondo"]) + 1.65, -(r[1] + r[3]) * 0.5)
	await _scatto("scolo0_in_piedi_in_su", occhi, occhi + Vector3(0.6, 3.0, 0.2))
	await _scatto("scolo0_in_piedi_verso_tubo", occhi, _ins.b(linea[n - 1]) + Vector3.UP * 0.5)
	# di lato, da fuori: il fondo del lenzuolo sopra lo sbocco del tubo e lo scolo
	var fondo := Vector3(c3.x, -22.7, c3.z)
	await _scatto("scolo0_di_lato", fondo + Vector3(-1.5, -1.0, -5.5), fondo + Vector3(-0.5, -1.2, 0))


func _vicino() -> void:
	for s in range(1, 5):
		var V: Vector3 = VERSO[s]
		var lato := V.cross(Vector3.UP).normalized()
		# le mollette: la prima, quella di mezzo e l'ultima, davanti, di lato e da sotto
		var nm := 0
		while _pezzo("stendardo_%d_molletta%d" % [s, nm]) != null:
			nm += 1
		for i in [0, nm / 2, nm - 1]:
			var c := _centro("stendardo_%d_molletta%d" % [s, i])
			await _scatto("st%d_molletta%d_davanti" % [s, i], c + V * 0.28 + Vector3.UP * 0.04 + lato * 0.06, c)
			await _scatto("st%d_molletta%d_di_lato" % [s, i], c + lato * 0.22 + V * 0.05 + Vector3.UP * 0.02, c)
			await _scatto("st%d_molletta%d_da_dietro" % [s, i], c - V * 0.25 - Vector3.UP * 0.06, c)
		# le corde ai capi del bastone
		var bv := _vertici("stendardo_%d_bastone" % s)
		var b0 := bv[0]
		var b1 := bv[0]
		for p in bv:
			if p.dot(lato) < b0.dot(lato):
				b0 = p
			if p.dot(lato) > b1.dot(lato):
				b1 = p
		var asse_y := _centro("stendardo_%d_bastone" % s).y
		for e in [["a", b0], ["b", b1]]:
			var capo: Vector3 = e[1]
			capo.y = asse_y
			var fuori := (capo - _centro("stendardo_%d_bastone" % s)).normalized()
			fuori.y = 0
			fuori = fuori.normalized()
			await _scatto("st%d_capo_%s_davanti" % [s, e[0]], capo + V * 0.3 + fuori * 0.1 + Vector3.UP * 0.05, capo + Vector3.UP * 0.02)
			await _scatto("st%d_capo_%s_da_sotto_fuori" % [s, e[0]], capo + fuori * 0.25 - Vector3.UP * 0.12 + V * 0.08, capo + Vector3.UP * 0.02)
		# i nodi alle travi (le travi vanno lungo z): da sotto, di traverso alla trave e lungo la trave
		for e in ["a", "b"]:
			var cv := _vertici("stendardo_%d_corda_%s" % [s, e])
			var somma := Vector3.ZERO
			var k := 0
			for p in cv:
				if p.y > -6.2:
					somma += p
					k += 1
			var nodo := somma / maxf(k, 1)
			nodo.y = -6.6
			await _scatto("st%d_nodo_%s_da_sotto" % [s, e], nodo + Vector3(0.25, -0.55, 0.2), nodo)
			await _scatto("st%d_nodo_%s_di_traverso" % [s, e], nodo + Vector3(0.75, 0.0, 0.12), nodo + Vector3(0.2, 0.25, 0))
			await _scatto("st%d_nodo_%s_lungo_la_trave" % [s, e], nodo + Vector3(0.08, -0.06, 0.32), nodo + Vector3(0, -0.01, 0))


func _scatto(nome: String, da: Vector3, verso: Vector3) -> void:
	_cam.global_position = da
	_cam.look_at(verso, Vector3.UP if absf((verso - da).normalized().y) < 0.98 else Vector3.FORWARD)
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var suff := "_luce" if _luce else ""
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join(nome + suff + ".jpg"), 0.88)
	print("SCATTO ", nome)
