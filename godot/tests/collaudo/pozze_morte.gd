extends Node
## Collaudo 0.4.0, terza candidata (4b82e170): la scena di morte nelle pozze (modo MANO, piano B: la camera cade, è
## trascinata alta verso la pozza e a 0,95 s ha il viso 22 cm sopra il pelo, inclinata in giù), col renderer vero, nella
## stanza delle pozze vera costruita a pezzi come nella Risalita (come scatti_pozze_lei.gd della mascotte). Per ogni caso
## la stanza si rifà da capo (come alla ripartenza), lei esce dalla pozza scelta col giocatore in piedi sulla passerella
## davanti, e prende. Casi: sud (2_4) intera, sud breve (la seconda morte di fila allo stesso posto), angolo 4_4 dal lato
## sud, angolo 0_0 dal lato ovest, bordo ovest 0_2, bordo nord 2_0, bordo est 4_2.
## Ogni fotogramma della scena (PM: F): la camera, quanto sopra il pelo della pozza sotto di lei (e se è sopra
## l'impronta di una pozza: sotto il pelo vuol dire dentro il liquido), la distanza dal bordo della pozza di lei.
## Negli istanti scelti (PM: T) la scena si ferma (albero in pausa) e si guarda: se la camera è dentro una mesh vicina
## (14 raggi corti, il primo colpo dal retro della faccia: il bordino, il grigliato, i muri; e il braccio e i tentacoli
## di lei con la posa di quel fotogramma, mesh con lo scheletro cotte), quanto è vicina la faccia più vicina
## (piano vicino 0,03 m), e quanta parte dello schermo prendono lei e le mesh vicine (scatto con e senza: i pixel che
## cambiano). Scatti senza gli strati della scena di morte (nero, lampo, glitch) e uno con gli strati a 0,95 s.
## Uso: xvfb-run ... --script res://tests/run.gd -- res://tests/collaudo/pozze_morte.gd <cartella> [casi separati da virgola]

const STANZA := "res://scenes/risalita/stanza_pozze.tscn"
const R := 3.35
## [nome, pozza, giocatore (coordinate dell'enigma), breve]
const CASI := [
	["sud", "Pozza_2_4", Vector3(0, 0, R), false],
	["sud_breve", "Pozza_2_4", Vector3(0, 0, R), true],
	["angolo_4_4_lato_sud", "Pozza_4_4", Vector3(2.2, 0, R), false],
	["angolo_0_0_lato_ovest", "Pozza_0_0", Vector3(-R, 0, -2.2), false],
	["bordo_ovest_0_2", "Pozza_0_2", Vector3(-R, 0, 0), false],
	["bordo_nord_2_0", "Pozza_2_0", Vector3(0, 0, -R), false],
	["bordo_est_4_2", "Pozza_4_2", Vector3(R, 0, 0), false],
]
const ISTANTI := [0.15, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 1.0, 1.1, 1.3, 1.6, 1.9]
const ISTANTI_BREVE := [0.15, 0.3, 0.5, 0.7, 0.9, 0.95, 1.0, 1.05]
const SCATTI := [0.3, 0.5, 0.7, 0.95, 1.1, 1.6]
const SCATTI_BREVE := [0.5, 0.95, 1.05]

var g: Player
var poz: Node3D
var e: EnigmaPozze
var lei: LeiPozze
var acqua: AcquaDiLei
var cart := ""
var difetti: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _img() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _difetto(s: String) -> void:
	difetti.append(s)
	print("PM: DIFETTO " + s)


func _costruisci() -> void:
	if is_instance_valid(poz):
		poz.queue_free()
		await _frames(3)
	poz = (load(STANZA) as PackedScene).instantiate() as Node3D
	poz.name = "StanzaPozze"
	poz.set(&"costruzione_a_pezzi", true)
	add_child(poz)
	await poz.call(&"costruisci_a_pezzi")
	e = poz.find_child("EnigmaPozze", true, false) as EnigmaPozze
	lei = e.lei
	acqua = lei.acqua
	acqua.prima_volta_dimostrativa = false
	lei.prima_attesa = 1000.0
	lei.pausa_min = 1000.0
	lei.pausa_max = 1000.0
	lei.letale = true
	acqua.letale = true


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1] if a.size() > 1 else OS.get_user_data_dir()
	var solo := (a[2].split(",") if a.size() > 2 else PackedStringArray())
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	Grafica.imposta("fov", 75.0)
	for caso in CASI:
		if not solo.is_empty() and not solo.has(String(caso[0])):
			continue
		await _caso(caso)
	print("PM: difetti %d" % difetti.size())
	for d in difetti:
		print("PM:   " + d)
	print("PM: finito")
	get_tree().quit()


func _caso(caso: Array) -> void:
	var nome: String = caso[0]
	var breve: bool = caso[3]
	await _costruisci()
	# (un giocatore nuovo a ogni caso, come alla ripartenza: la scena di morte lascia la camera spostata)
	if is_instance_valid(g):
		g.queue_free()
		await _frames(2)
	g = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(g)
	await get_tree().process_frame
	GameState.player = g
	g.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	g.water_pack.set_equipped(true, false)
	g.camera.make_current()
	print("PM: camera near %.3f, fov %.0f" % [g.camera.near, g.camera.fov])
	var t := e.find_child(String(caso[1]), false, false) as WaterTank
	if t == null:
		print("PM: %s: la pozza %s non c'è" % [nome, caso[1]])
		return
	GameState.is_dying = false
	g.input_enabled = true
	g.camera.make_current()
	var dove := e.to_global(caso[2] as Vector3) + Vector3(0, 0.05, 0)
	g.teleport(dove, g.yaw, 0.0)
	await _fisica(3)
	g.look_at_point(t.global_position + Vector3(0, 0.6, 0))
	await _frames(30)
	# (la morte intera: si azzera il conto delle morti allo stesso posto; la breve: lo si mette a 1, la prossima è la seconda)
	GameState.morti_al_checkpoint = 1 if breve else 0
	lei._t = -1000.0
	lei.luce_in = t
	var m := lei.uscita_di(t)
	var ok := acqua.chiama(m)
	print("PM: %s: chiamata dalla pozza %s, uscita %s %s, giocatore a %s (%.2f m dall'uscita)" % [nome, t.name,
			m.name if m else "-", m.global_position.snappedf(0.001) if m else "-", g.global_position.snappedf(0.01),
			_in_pianta(g.global_position, m.global_position) if m else -1.0])
	if not ok:
		_difetto("%s: lei non si chiama" % nome)
		return
	for i in 60 * 15:
		await get_tree().physics_frame
		if GameState.is_dying:
			break
	if not GameState.is_dying:
		_difetto("%s: nessuna presa (fase %s)" % [nome, AcquaDiLei.Fase.find_key(acqua.fase)])
		return
	var seq: CanvasLayer = GameState.get(&"_death_sequence")
	if seq.is_connected(&"finished", GameState._on_death_sequence_finished):
		seq.disconnect(&"finished", GameState._on_death_sequence_finished)
	print("PM: %s: presa, scena breve %s, durata %.2f, meta camera_morte %s" % [nome, seq.get(&"breve"), seq.get(&"duration"),
			AcquaDiLei._lei.get_meta(&"camera_morte") if AcquaDiLei._lei and AcquaDiLei._lei.has_meta(&"camera_morte") else "NO"])
	if bool(seq.get(&"breve")) != breve:
		_difetto("%s: scena breve %s, attesa %s" % [nome, seq.get(&"breve"), breve])
	var istanti: Array = ISTANTI_BREVE if bool(seq.get(&"breve")) else ISTANTI
	var scatti: Array = SCATTI_BREVE if bool(seq.get(&"breve")) else SCATTI
	var k := 0
	var dentro_liquido := 0
	var ultimo := -1.0
	var duration := float(seq.get(&"duration"))
	while is_instance_valid(seq) and not bool(seq.get(&"_done")):
		await get_tree().process_frame
		if not is_instance_valid(seq):
			break
		var el := float(seq.get(&"elapsed"))
		if el == ultimo:
			continue
		ultimo = el
		var cam := get_viewport().get_camera_3d()
		var cp := cam.global_position
		var sopra := cp.y - t.get_surface_global_y()
		var impronta := _pozza_sotto(cp)
		var su_liquido := ""
		if impronta:
			var dl := cp.y - impronta.get_surface_global_y()
			su_liquido = "sopra %s di %.3f" % [impronta.name, dl]
			if dl < cam.near + 0.01:
				dentro_liquido += 1
				_difetto("%s: a %.2f s la camera è dentro il liquido di %s (%.3f m dal pelo)" % [nome, el, impronta.name, dl])
		print("PM: F %s %.3f cam %s guarda %s; sopra il pelo di %s %.3f; dal centro della pozza in pianta %.3f; %s" % [nome, el,
				cp.snappedf(0.001), (-cam.global_basis.z).snappedf(0.01), t.name, sopra, _in_pianta(cp, t.global_position), su_liquido])
		if k < istanti.size() and el >= float(istanti[k]) - 0.001:
			var quando := float(istanti[k])
			k += 1
			get_tree().paused = true
			await _guarda(nome, quando, el, cam, t, seq, scatti.has(quando))
			get_tree().paused = false
		if el >= duration - 0.02:
			break
	print("PM: %s: fotogrammi con la camera dentro il liquido %d" % [nome, dentro_liquido])
	if is_instance_valid(seq):
		seq.queue_free()
	GameState.is_dying = false
	await _frames(3)


func _pozza_sotto(q: Vector3) -> WaterTank:
	for u in e.pozze():
		var l := u.to_local(q)
		if absf(l.x) <= u.inner_size.x * 0.5 and absf(l.z) <= u.inner_size.z * 0.5:
			return u
	return null


static func _in_pianta(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _strati(seq: CanvasLayer, visibili: bool) -> void:
	seq.visible = visibili
	for c in seq.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = visibili


## Le mesh vicine alla camera: [nome, facce nel mondo (PackedVector3Array), di lei].
func _mesh_vicine(cp: Vector3, raggio: float) -> Array:
	var out: Array = []
	var lq := AcquaDiLei._lei
	var tutte: Array[Node] = poz.find_children("*", "MeshInstance3D", true, false)
	if lq and not poz.is_ancestor_of(lq):
		tutte.append_array(lq.find_children("*", "MeshInstance3D", true, false))
	for mi in tutte:
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		if m.get_parent() is WaterBody or String(m.name).begins_with("Acqua"):
			continue
		var di_lei := lq != null and (m == lq or lq.is_ancestor_of(m))
		var box := m.global_transform * m.get_aabb()
		if not box.grow(raggio).has_point(cp):
			continue
		var facce: PackedVector3Array
		if di_lei and m.skeleton != NodePath() and m.skin != null:
			var cotta := m.bake_mesh_from_current_skeleton_pose()
			facce = cotta.get_faces() if cotta else m.mesh.get_faces()
		else:
			facce = m.mesh.get_faces()
		var xf := m.global_transform
		var vic := PackedVector3Array()
		var r2 := (raggio + 0.3) * (raggio + 0.3)
		for i in range(0, facce.size(), 3):
			var a := xf * facce[i]
			if a.distance_squared_to(cp) > r2:
				continue
			vic.append(a)
			vic.append(xf * facce[i + 1])
			vic.append(xf * facce[i + 2])
		if not vic.is_empty():
			out.append([String(m.name) if di_lei else String(poz.get_path_to(m)), vic, di_lei])
	for mmi in poz.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (mmi as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null or not (mmi as Node3D).is_visible_in_tree():
			continue
		var facce := mm.mesh.get_faces()
		var vic := PackedVector3Array()
		for j in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
			var xf := (mmi as Node3D).global_transform * mm.get_instance_transform(j)
			if xf.origin.distance_to(cp) > raggio + 1.0:
				continue
			for i in range(0, facce.size(), 3):
				var a := xf * facce[i]
				if a.distance_to(cp) > raggio + 0.3:
					continue
				vic.append(a)
				vic.append(xf * facce[i + 1])
				vic.append(xf * facce[i + 2])
		if not vic.is_empty():
			out.append([String(poz.get_path_to(mmi)), vic, false])
	return out


const DIREZIONI := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
		Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, 1, 1), Vector3(-1, 1, -1),
		Vector3(-1, -1, 1), Vector3(-1, -1, -1)]


func _guarda(nome: String, quando: float, el: float, cam: Camera3D, t: WaterTank, seq: CanvasLayer, scatta: bool) -> void:
	await _fisica(1)
	var cp := cam.global_position
	var vicine := _mesh_vicine(cp, 0.6)
	# dentro: per ogni mesh, quanti dei 14 raggi corti colpiscono prima il retro di una faccia
	var piu_vicina := INF
	var chi_vicina := ""
	var righe: Array[String] = []
	for v in vicine:
		var facce: PackedVector3Array = v[1]
		var retro := 0
		var colpi := 0
		for d0 in DIREZIONI:
			var d: Vector3 = (d0 as Vector3).normalized()
			var best := 0.6
			var best_retro := false
			for i in range(0, facce.size(), 3):
				var p = Geometry3D.ray_intersects_triangle(cp, d, facce[i], facce[i + 1], facce[i + 2])
				if p == null:
					continue
				var dist := cp.distance_to(p)
				if dist < best:
					best = dist
					var n := (facce[i + 1] - facce[i]).cross(facce[i + 2] - facce[i])
					best_retro = n.dot(d) > 0.0
			if best < 0.6:
				colpi += 1
				if best_retro:
					retro += 1
				if best < piu_vicina:
					piu_vicina = best
					chi_vicina = v[0]
		if colpi > 0:
			righe.append("%s%s: %d/14 raggi la colpiscono, %d dal retro" % [v[0], " (lei)" if v[2] else "", colpi, retro])
		if retro >= 10:
			_difetto("%s: a %.2f s la camera è dentro %s%s (%d raggi su 14 dal retro)" % [nome, el, v[0], " (lei)" if v[2] else "", retro])
	print("PM: T %s %.2f (%.3f) cam %s; sopra il pelo %.3f; faccia più vicina %.3f m (%s); mesh entro 0,6 m: %s" % [nome, quando, el,
			cp.snappedf(0.001), cp.y - t.get_surface_global_y(), piu_vicina, chi_vicina, "; ".join(righe) if not righe.is_empty() else "nessuna"])
	if piu_vicina < cam.near * 1.5:
		_difetto("%s: a %.2f s una faccia di %s a %.3f m dalla camera (piano vicino %.3f)" % [nome, el, chi_vicina, piu_vicina, cam.near])
	if not scatta:
		return
	_strati(seq, false)
	var base := await _img()
	base.save_jpg(cart.path_join("%s_%03d.jpg" % [nome, int(round(quando * 100))]), 0.9)
	# quanto schermo prendono lei (ogni sua mesh) e le mesh vicine (entro 1,5 m, senza il liquido): una seconda vista con la
	# stessa camera che disegna solo quelle (strato 20, sfondo trasparente), i pixel pieni
	var lq := AcquaDiLei._lei
	var quota_lei := -1.0
	var parti: Array[String] = []
	if lq:
		var sue: Array[GeometryInstance3D] = []
		for mi in lq.find_children("*", "GeometryInstance3D", true, false):
			if (mi as GeometryInstance3D).is_visible_in_tree():
				sue.append(mi)
		quota_lei = await _copertura(sue, cam)
		for n in sue:
			var q1 := await _copertura([n], cam)
			if q1 > 0.005:
				parti.append("%s %.0f %%" % [n.name, q1 * 100.0])
			if quando >= 0.94 and q1 > 0.5:
				_difetto("%s: a %.2f s %s (lei) prende più di metà schermo (%.0f %%)" % [nome, quando, n.name, q1 * 100.0])
	var da_coprire: Array[GeometryInstance3D] = []
	var nomi_vicine: Array[String] = []
	for mi in poz.find_children("*", "GeometryInstance3D", true, false):
		var gi := mi as GeometryInstance3D
		if not gi.is_visible_in_tree() or (lq and (gi == lq or lq.is_ancestor_of(gi))) or gi.get_parent() is WaterBody:
			continue
		if String(gi.name) == "Superficie" or String(gi.get_parent().name) == "Acqua":
			continue
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			var box := gi.global_transform * (gi as MeshInstance3D).get_aabb()
			if box.grow(1.5).has_point(cp):
				da_coprire.append(gi)
	var quota_vicine := 0.0
	var peggio := ""
	for n in da_coprire:
		var q2 := await _copertura([n], cam)
		if q2 > quota_vicine:
			quota_vicine = q2
			peggio = String(poz.get_path_to(n))
	print("PM: S %s %.2f: schermo preso da lei %.0f %% (%s); la mesh vicina che ne prende di più %s %.0f %% (su %d entro 1,5 m, senza il liquido)" % [nome,
			quando, quota_lei * 100.0, ", ".join(parti), peggio, quota_vicine * 100.0, da_coprire.size()])
	if quando >= 0.94 and quota_vicine > 0.5:
		_difetto("%s: a %.2f s %s prende più di metà schermo (%.0f %%)" % [nome, quando, peggio, quota_vicine * 100.0])
	if is_equal_approx(quando, 0.95):
		_strati(seq, true)
		var con := await _img()
		con.save_jpg(cart.path_join("%s_%03d_con_effetti.jpg" % [nome, int(round(quando * 100))]), 0.9)
	_strati(seq, true)


static func _cambiati(a: Image, b: Image) -> float:
	var w := a.get_width()
	var h := a.get_height()
	var n := 0
	var tot := 0
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			tot += 1
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.12:
				n += 1
	return float(n) / maxf(float(tot), 1.0)


var _sv: SubViewport
var _strati_detti := false
var _svc: Camera3D


## La parte dello schermo presa da [param nodi] da soli, visti dalla camera [param cam] (senza chi li copre).
func _copertura(nodi: Array, cam: Camera3D) -> float:
	if _sv == null:
		_sv = SubViewport.new()
		_sv.size = Vector2i(get_viewport().get_visible_rect().size / 2.0)
		_sv.transparent_bg = true
		_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_sv.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_sv)
		_svc = Camera3D.new()
		_svc.cull_mask = 1 << 19
		var en := Environment.new()
		en.background_mode = Environment.BG_CLEAR_COLOR
		_svc.environment = en
		_sv.add_child(_svc)
		_svc.current = true
	_svc.global_transform = cam.global_transform
	_svc.fov = cam.fov
	_svc.near = cam.near
	_svc.far = cam.far
	var strati := {}
	# (chi ha già lo strato 20, per esempio il liquido delle pozze con tutti gli strati, lo perde intanto)
	for v in get_tree().root.find_children("*", "VisualInstance3D", true, false):
		var vi := v as VisualInstance3D
		if vi.layers & (1 << 19) and not nodi.has(vi):
			strati[vi] = vi.layers
			vi.layers = vi.layers & ~(1 << 19)
	for n in nodi:
		strati[n] = (n as VisualInstance3D).layers
		(n as VisualInstance3D).layers = 1 << 19
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _sv.get_texture().get_image()
	for n in strati:
		(n as VisualInstance3D).layers = strati[n]
	if not _strati_detti:
		_strati_detti = true
		print("PM: con lo strato 20 già acceso: %s" % [strati.keys().filter(func(x): return not nodi.has(x)).map(func(x): return String(x.name)).slice(0, 12)])
	var w := img.get_width()
	var h := img.get_height()
	var pieni := 0
	var tot := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			tot += 1
			if img.get_pixel(x, y).a > 0.1:
				pieni += 1
	return float(pieni) / maxf(tot, 1)
