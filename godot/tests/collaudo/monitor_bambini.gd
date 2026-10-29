extends Node
## Collaudo dei bambini (squadra collaudo): un nodo che, aggiunto alla scena da una sonda, guarda a ogni fotogramma
## tutti i Bambino visibili e scrive in <cartella>/bambini.csv:
## - dove sta, la modalità, lo stato del BambinoSfuggita (se c'è);
## - i piedi (LeftFoot/RightFoot e le punte LeftToeBase/RightToeBase): l'altezza del più basso sul pavimento sotto
##   (raggio della fisica) e quanto scivola quando è a terra (velocità orizzontale sotto i 3 cm);
## - cosa tocca: una scatola grande come il bambino, 2 cm più stretta e 6 cm sopra il pavimento, contro la fisica;
## - la Polaroid 13 (distanza dal riquadro) e lei all'oblò (se è visibile insieme al bambino);
## - quando sparisce: se era nell'inquadratura e non coperto (sparito davanti alla camera);
## - le pipeline compilate in quel fotogramma.
## Ogni mezzo secondo mentre si vede, uno scatto dalla camera del giocatore e uno ravvicinato dei piedi (da una
## SubViewport con la sua camera, nello stesso mondo: la camera del giocatore non cambia).

var cart := ""
var _csv: FileAccess
var _ev: FileAccess
var _prima := {}          # instance id -> [visibile, piedi prima]
var _pip := 0
var _sv: SubViewport
var _cam: Camera3D
var _scatto_t := 0.0
var _n := 0
var _t0 := 0


func _init(cartella: String) -> void:
	cart = cartella
	name = "MonitorBambini"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(cart.path_join("piedi"))
	_csv = FileAccess.open(cart.path_join("bambini.csv"), FileAccess.WRITE)
	_csv.store_line("t;bambino;stato;modalita;x;y;z;piede_alto_cm;scivola_ms;scivola_basso_ms;tocca;p13_cm;lei_visibile;pipeline;sotto")
	_ev = FileAccess.open(cart.path_join("eventi.txt"), FileAccess.WRITE)
	_t0 = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() != "headless":
		_sv = SubViewport.new()
		_sv.size = Vector2i(480, 270)
		_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_cam = Camera3D.new()
		_cam.fov = 40.0
		_cam.near = 0.02
		_sv.add_child(_cam)
		add_child(_sv)


func _t() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


func evento(s: String) -> void:
	_ev.store_line("%.2f %s" % [_t(), s])
	_ev.flush()
	print("BAMBINI: %.2f %s" % [_t(), s])


func _process(delta: float) -> void:
	var sc := get_tree().current_scene
	if sc == null:
		return
	var pip := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE))
	var nuove := pip - _pip
	_pip = pip
	var cam := get_viewport().get_camera_3d()
	if _sv and _sv.world_3d == null:
		_sv.world_3d = get_viewport().find_world_3d()
	var p13 := _polaroid(sc, 13)
	var lei_oblo := false
	for o in sc.find_children("*", "ObloLei", true, false):
		var lei = o.get(&"lei")
		if lei is Node3D and is_instance_valid(lei) and (lei as Node3D).is_visible_in_tree() and int(o.get(&"stato")) in [1, 2, 3] \
				and cam and cam.is_position_in_frustum((lei as Node3D).global_position):
			lei_oblo = true
	var visti := {}
	for b in sc.find_children("*", "Bambino", true, false):
		var bn := b as Bambino
		var id := bn.get_instance_id()
		var vis := bn.is_visible_in_tree()
		visti[id] = true
		var prima: Array = _prima.get(id, [false, {}, Vector3.ZERO])
		var nome := String(bn.get_parent().name) if bn.get_parent() else String(bn.name)
		if vis and not prima[0]:
			evento("%s compare in %s (pipeline in questo fotogramma %d, lei all'oblò visibile %s)" % [nome, bn.global_position.snapped(Vector3.ONE * 0.01), nuove, lei_oblo])
		if not vis and prima[0]:
			evento("%s sparisce in %s: %s" % [nome, (prima[2] as Vector3).snapped(Vector3.ONE * 0.01), _davanti(cam, prima[2], bn)])
		if not vis:
			_prima[id] = [false, {}, prima[2]]
			continue
		var sf = bn.get_parent()
		var stato := String(BambinoSfuggita.Stato.keys()[sf.stato]) if sf is BambinoSfuggita else "-"
		var mod := String(Bambino.Modalita.keys()[int(bn.get(&"modalita"))]) if bn.get(&"modalita") != null else "-"
		var piedi := _piedi(bn)
		var basso := 99.0
		var scivola := 0.0
		var basso_k := ""
		var sotto := ""
		var spazio := bn.get_world_3d().direct_space_state
		for k in piedi:
			var q: Vector3 = piedi[k]
			var h := _pavimento(spazio, q)
			var alto := q.y - h
			if alto < basso:
				basso = alto
				basso_k = k
				sotto = _sotto
			if alto < 0.03 and (prima[1] as Dictionary).has(k) and delta > 0.0:
				var d: Vector3 = q - (prima[1] as Dictionary)[k]
				scivola = maxf(scivola, Vector2(d.x, d.z).length() / delta)
		# il piede più basso, se è a meno di 1,5 cm: quanto si muove in orizzontale (piantato: ~0)
		var scivola_basso := -1.0
		if basso_k != "" and basso < 0.015 and (prima[1] as Dictionary).has(basso_k) and delta > 0.0:
			var db: Vector3 = (piedi[basso_k] as Vector3) - (prima[1] as Dictionary)[basso_k]
			# (come test_bambini_passi: solo se non sale e non scende, cioè è piantato)
			if absf(db.y) / delta < 0.1:
				scivola_basso = Vector2(db.x, db.z).length() / delta
		var tocca := _tocca(bn, spazio)
		var p13d := -1.0
		if p13:
			p13d = _dist_aabb(_aabb(bn), _aabb(p13)) * 100.0
		_csv.store_line("%.3f;%s;%s;%s;%.3f;%.3f;%.3f;%.1f;%.2f;%.2f;%s;%.0f;%s;%d;%s" % [_t(), nome, stato, mod, bn.global_position.x, bn.global_position.y,
			bn.global_position.z, basso * 100.0 if basso < 90 else -1.0, scivola, scivola_basso, tocca, p13d, lei_oblo, nuove, sotto])
		_prima[id] = [true, piedi, _aabb(bn).get_center()]
		# gli scatti
		_scatto_t -= delta
		if _sv and _scatto_t <= 0.0 and _n < 60:
			_scatto_t = 0.15 if stato == "SCAPPA" or mod == "SCAPPA" else 0.5
			_scatti(bn, nome, stato)
	for id in _prima.keys():
		if not visti.has(id) and _prima[id][0]:
			evento("bambino liberato mentre si vedeva in %s: %s" % [(_prima[id][2] as Vector3).snapped(Vector3.ONE * 0.01), _davanti(cam, _prima[id][2], null)])
			_prima[id] = [false, {}, _prima[id][2]]


func _scatti(bn: Bambino, nome: String, stato: String) -> void:
	var c := _aabb(bn)
	var avanti := -bn.global_transform.basis.z
	var lato := bn.global_transform.basis.x.normalized()
	var piede := Vector3(c.get_center().x, c.position.y + 0.05, c.get_center().z)
	# da dietro (dove passa il giocatore, quindi libero), un po' di lato e basso; di lato a 0,9 m nei corridoi stretti
	# finiva dentro il muro
	var dietro := Vector3(avanti.x, 0, avanti.z).normalized()
	var da := piede + dietro * 1.0 + lato * 0.25 + Vector3.UP * 0.18
	_cam.look_at_from_position(da, piede, Vector3.UP)
	await RenderingServer.frame_post_draw
	var base := "%03d_%s_%s" % [_n, nome, stato]
	_n += 1
	var im := _sv.get_texture().get_image()
	if im:
		im.save_jpg(cart.path_join("piedi").path_join(base + "_piedi.jpg"), 0.88)
	var im2 := get_viewport().get_texture().get_image()
	if im2:
		im2.save_jpg(cart.path_join("piedi").path_join(base + "_occhi.jpg"), 0.85)


func _piedi(bn: Bambino) -> Dictionary:
	var out := {}
	for sk in bn.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		if not s.is_visible_in_tree():
			continue
		for nome in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
			var i := s.find_bone(nome)
			if i >= 0:
				out[String(s.get_path()) + nome] = s.global_transform * s.get_bone_global_pose(i).origin
	return out


var _sotto := ""


func _pavimento(spazio: PhysicsDirectSpaceState3D, q: Vector3) -> float:
	var r := PhysicsRayQueryParameters3D.create(q + Vector3.UP * 0.4, q + Vector3.DOWN * 1.5)
	var p := GameState.player
	if p and is_instance_valid(p):
		r.exclude = [p.get_rid()]
	var h := spazio.intersect_ray(r)
	_sotto = String(h.collider.name) if not h.is_empty() and h.collider else "-"
	return (h.position as Vector3).y if not h.is_empty() else -INF


func _aabb(n: Node3D) -> AABB:
	var bb := AABB()
	var primo := true
	for m in n.find_children("*", "VisualInstance3D", true, false):
		var vi := m as VisualInstance3D
		if not vi.is_visible_in_tree() or vi is Light3D:
			continue
		var b := vi.global_transform * vi.get_aabb()
		bb = b if primo else bb.merge(b)
		primo = false
	return bb


func _tocca(bn: Bambino, spazio: PhysicsDirectSpaceState3D) -> String:
	var bb := _aabb(bn)
	var nota := ""
	if bb.size.y < 0.1:
		# (la scatola delle mesh è piatta: allora una scatola di 34 cm dai piedi alla testa)
		var h := maxf(bn.punto_testa().y - bn.global_position.y + 0.08, 0.3)
		bb = AABB(bn.global_position + Vector3(-0.17, 0, -0.17), Vector3(0.38, h, 0.38))
		nota = "[scatola dalla testa] "
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(bb.size.x - 0.04, 0.05), maxf(bb.size.y - 0.08, 0.05), maxf(bb.size.z - 0.04, 0.05))
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis(), bb.get_center() + Vector3.UP * 0.02)
	var p := GameState.player
	if p and is_instance_valid(p):
		q.exclude = [p.get_rid()]
	q.collide_with_areas = false
	var nomi: PackedStringArray = []
	for h in spazio.intersect_shape(q, 8):
		var co = h.collider
		if co is Node:
			nomi.append(String((co as Node).name))
	return nota + (",".join(nomi) if nomi.size() else "niente")


func _polaroid(sc: Node, foto: int) -> Node3D:
	for f in sc.find_children("*", "PolaroidPhoto", true, false):
		if int(f.get(&"photo")) == foto and (f as Node3D).is_visible_in_tree():
			return f
	return null


func _dist_aabb(a: AABB, b: AABB) -> float:
	var d := Vector3.ZERO
	for i in 3:
		var lo: float = maxf(a.position[i], b.position[i])
		var hi: float = minf(a.end[i], b.end[i])
		d[i] = maxf(0.0, lo - hi)
	return d.length()


## Se il punto [param q] era nell'inquadratura e niente lo copriva (raggio dalla camera): allora è sparito davanti.
func _davanti(cam: Camera3D, q: Vector3, bn: Node) -> String:
	if cam == null:
		return "camera assente"
	if not cam.is_position_in_frustum(q):
		return "fuori dall'inquadratura (bene)"
	var r := PhysicsRayQueryParameters3D.create(cam.global_position, q)
	var p := GameState.player
	if p and is_instance_valid(p):
		r.exclude = [p.get_rid()]
	var h := cam.get_world_3d().direct_space_state.intersect_ray(r)
	if not h.is_empty() and (h.position as Vector3).distance_to(q) > 0.25:
		return "nell'inquadratura ma coperto da %s (bene)" % (h.collider.name if h.collider else "?")
	return "NELL'INQUADRATURA E NON COPERTO, a %.1f m" % cam.global_position.distance_to(q)
