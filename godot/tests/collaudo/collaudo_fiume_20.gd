extends Node
## Collaudo del fiume lento con le pile sfalsate e le lampade a gabbia al 20% (lavoro/corridoio-20, 2 novembre), dalla
## Risalita della scena di prova (come scatti_pile_fiume.gd: luci del blackout, ambiente della sala senza GI, nebbia
## volumetrica e SSIL). Fasi (secondo argomento, separate da virgole; senza, tutte):
##  - numeri: senza renderer anche. Ogni scatolone e ogni unità delle pile (le istanze dei MultiMesh) come scatola
##    orientata: l'appoggio misurato con raggi dai 4 angoli e dal centro della faccia di sotto (staccato se più di 1 cm,
##    appoggiato male se meno di 3 punti su 5 toccano), le compenetrazioni fra due scatole (più di 5 mm), il pesante
##    sotto (casse a terra), la strada libera fino a 2 m lungo il percorso a piedi; poi i buchi: dalla strada raggi a 360°
##    ogni 0,3° a 5 altezze, e quelli che passano oltre la fila davanti delle pile senza toccarne una (vanno a finire su
##    un muro, una roccia o una transenna dietro) sono un buco visibile; poi le lampade del fiume (energia, globo);
##  - giro: dagli occhi lungo la strada a piedi, ogni 2,5 m avanti, a sinistra e a destra, e dall'approdo alla porta;
##  - buchi: uno scatto dagli occhi verso ogni buco trovato dai numeri (servono i numeri nello stesso giro);
##  - vicino: i ravvicinati delle cime aperte e degli scatoloni caduti sopra il film, i più vicini alla strada;
##  - luci: le viste dalla ciambella ai bivi 1 e 3 e alle paratie, la sponda della colonna, l'approdo, e lungo il
##    corridoio delle pile verso la ciambella verde, con la luminosità media, mediana e del 10% più scuro.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/collaudo_fiume_20.gd <cartella> [fasi]

const F := preload("res://scripts/risalita/fiume_gioco.gd")
const STACCO := 0.01
const DENTRO := 0.005
const ALTEZZE := [0.4, 1.0, 1.6, 2.2, 2.8]

var _p: Player
var _cartella := ""
var _fasi: PackedStringArray = []
var fiume: Node3D
## Le scatole: [nome, indice, centro, assi (Basis con le mezze misure sulle colonne), aabb in pianta (Rect2)].
var _scatole: Array = []
var _griglia := {}
var _buchi: Array = []   # [da, verso, muro, u, altezza, cosa]
var _k := 0


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://collaudo_fiume_20"
	_fasi = (a[2] if a.size() > 2 else "numeri,giro,buchi,vicino,luci").split(",")
	DirAccess.make_dir_recursive_absolute(_cartella)
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	_p = GameState.player
	_p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := _p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	_p.camera.make_current()
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.volumetric_fog_enabled = false
	env.environment.ssil_enabled = false
	get_tree().current_scene.add_child(env)
	var ris := get_tree().current_scene.get_node(^"Risalita")
	for nome in ["BambinoCorridoioFiume"]:
		var b := ris.find_child(nome, true, false) as Node3D
		if b:
			b.process_mode = Node.PROCESS_MODE_DISABLED
			b.visible = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	ris.call(&"carica_subito")
	for i in 1800:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and ris.get(&"fiume") != null and i > 120:
			break
	fiume = ris.get(&"fiume") as Node3D
	for i in 30:
		await get_tree().physics_frame
	print("FIUME: luci %s, fiume in %s" % [GameState.luci, fiume.global_position.snapped(Vector3.ONE * 0.01)])
	if "numeri" in _fasi:
		_numeri()
	if "giro" in _fasi:
		await _giro()
	if "buchi" in _fasi:
		await _scatti_buchi()
	if "vicino" in _fasi:
		await _vicino()
	if "luci" in _fasi:
		await _luci()
	print("FIUME: finito")
	get_tree().quit()


func L(v: Vector3) -> Vector3:
	return fiume.to_global(v)


func _strada() -> Array[Vector3]:
	var m := fiume.get_node(^"Marker")
	var out: Array[Vector3] = []
	var punti: Array[Vector3] = []
	for nome in ["Ingresso", "FineFila", "Imbarco"]:
		punti.append(fiume.to_local((m.get_node(NodePath(nome)) as Node3D).global_position))
	for k in punti.size() - 1:
		var l := punti[k].distance_to(punti[k + 1])
		var n := maxi(1, int(ceil(l / 0.5)))
		for i in n:
			out.append(punti[k].lerp(punti[k + 1], float(i) / n))
	out.append(punti[-1])
	return out


func _strada_approdo() -> Array[Vector3]:
	var m := fiume.get_node(^"Marker")
	var a := fiume.to_local((m.get_node(^"Approdo") as Node3D).global_position)
	var b := fiume.to_local((m.get_node(^"PortaPersonale") as Node3D).global_position)
	var out: Array[Vector3] = []
	var n := maxi(1, int(ceil(a.distance_to(b) / 0.5)))
	for i in n + 1:
		out.append(a.lerp(b, float(i) / n))
	return out


# --- numeri ------------------------------------------------------------------------------------------------

func _raccogli() -> void:
	_scatole.clear()
	_griglia.clear()
	for c in fiume.get_children():
		if not c is MultiMeshInstance3D or not String(c.name).begins_with("Pile"):
			continue
		var mm := (c as MultiMeshInstance3D).multimesh
		var nome := String(c.name)
		var ab := mm.mesh.get_aabb()
		if nome == "PileCartone" or nome == "PileCartoneAperte":
			# il bancale soltanto: gli scatoloni sono a parte
			ab = AABB(Vector3(-0.6, 0.0, -0.5), Vector3(1.2, F.PILA_BANCALE, 1.0))
		var xf0 := fiume.global_transform.affine_inverse() * (c as Node3D).global_transform
		for i in mm.instance_count:
			var t := xf0 * mm.get_instance_transform(i)
			var centro := t * ab.get_center()
			var assi := Basis(t.basis.x.normalized() * ab.size.x * 0.5, t.basis.y.normalized() * ab.size.y * 0.5,
					t.basis.z.normalized() * ab.size.z * 0.5)
			var r := Rect2(Vector2(centro.x, centro.z), Vector2.ZERO)
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						var v: Vector3 = centro + assi.x * sx + assi.y * sy + assi.z * sz
						r = r.expand(Vector2(v.x, v.z))
			var k := _scatole.size()
			_scatole.append([nome, i, centro, assi, r])
			for gx in range(floori(r.position.x), floori(r.end.x) + 1):
				for gz in range(floori(r.position.y), floori(r.end.y) + 1):
					var key := Vector2i(gx, gz)
					if not _griglia.has(key):
						_griglia[key] = []
					_griglia[key].append(k)


func _vicine(r: Rect2) -> Array:
	var out := {}
	for gx in range(floori(r.position.x), floori(r.end.x) + 1):
		for gz in range(floori(r.position.y), floori(r.end.y) + 1):
			for k in _griglia.get(Vector2i(gx, gz), []):
				out[k] = true
	return out.keys()


## Il raggio da [param o] verso [param d] (unitario) contro la scatola k: la distanza, o -1.
func _raggio_scatola(o: Vector3, d: Vector3, k: int) -> float:
	var c: Vector3 = _scatole[k][2]
	var assi: Basis = _scatole[k][3]
	var tmin := -INF
	var tmax := INF
	for a in 3:
		var asse: Vector3 = assi[a]
		var h := asse.length()
		var u := asse / h
		var e := u.dot(c - o)
		var f := u.dot(d)
		if absf(f) > 1e-9:
			var t1 := (e + h) / f
			var t2 := (e - h) / f
			if t1 > t2:
				var s := t1
				t1 = t2
				t2 = s
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax or tmax < 0.0:
				return -1.0
		elif -e - h > 0.0 or -e + h < 0.0:
			return -1.0
	return tmin if tmin >= 0.0 else -1.0


## Quanto entrano le due scatole una nell'altra (asse separatore di profondità minima), 0 se non si toccano.
func _dentro(i: int, j: int) -> float:
	var ci: Vector3 = _scatole[i][2]
	var cj: Vector3 = _scatole[j][2]
	var ai: Basis = _scatole[i][3]
	var aj: Basis = _scatole[j][3]
	var assi: Array[Vector3] = []
	for a in 3:
		assi.append(ai[a].normalized())
		assi.append(aj[a].normalized())
	for a in 3:
		for b in 3:
			var x := ai[a].normalized().cross(aj[b].normalized())
			if x.length() > 1e-4:
				assi.append(x.normalized())
	var minimo := INF
	for u in assi:
		var ri := absf(ai.x.dot(u)) + absf(ai.y.dot(u)) + absf(ai.z.dot(u))
		var rj := absf(aj.x.dot(u)) + absf(aj.y.dot(u)) + absf(aj.z.dot(u))
		var p := ri + rj - absf((cj - ci).dot(u))
		if p <= 0.0:
			return 0.0
		minimo = minf(minimo, p)
	return minimo


func _numeri() -> void:
	_raccogli()
	var conta := {}
	for s in _scatole:
		conta[s[0]] = conta.get(s[0], 0) + 1
	print("NUMERI: scatole e unità delle pile: %s" % str(conta))
	# 1. gli appoggi
	var staccati := []
	var male := []
	var affondati := []
	for k in _scatole.size():
		var s: Array = _scatole[k]
		var c: Vector3 = s[2]
		var assi: Basis = s[3]
		# la faccia di sotto: l'asse più verticale
		var giu := 0
		for a in 3:
			if absf(assi[a].normalized().y) > absf(assi[giu].normalized().y):
				giu = a
		var vg: Vector3 = assi[giu] * (-1.0 if assi[giu].y > 0.0 else 1.0)
		var o1: Vector3 = assi[(giu + 1) % 3] * 0.85
		var o2: Vector3 = assi[(giu + 2) % 3] * 0.85
		var punti := [c + vg, c + vg + o1 + o2, c + vg + o1 - o2, c + vg - o1 + o2, c + vg - o1 - o2]
		var vicine := _vicine(s[4])
		var toccano := 0
		var min_gap := INF
		var gaps := []
		for q: Vector3 in punti:
			var da := q + Vector3.UP * 0.03
			var meglio := da.y   # il pavimento della banchina a quota 0
			for j in vicine:
				if j == k:
					continue
				var t := _raggio_scatola(da, Vector3.DOWN, j)
				if t >= 0.0:
					meglio = minf(meglio, t)
			# (l'appoggio è a da.y - meglio: il pavimento o la faccia di sopra della scatola più alta lì sotto)
			var gap := q.y - (da.y - meglio)
			gaps.append(gap)
			min_gap = minf(min_gap, gap)
			if absf(gap) <= STACCO:
				toccano += 1
		var dove := c.snapped(Vector3.ONE * 0.01)
		if min_gap < -STACCO:
			affondati.append([s[0], s[1], dove, -min_gap])
		if min_gap > STACCO:
			staccati.append([s[0], s[1], dove, min_gap])
		elif toccano < 3 and absf(gaps[0]) > STACCO:
			male.append([s[0], s[1], dove, toccano, gaps.map(func(g): return snappedf(g, 0.001))])
	print("NUMERI: appoggi: %d staccati (più di %d cm), %d appoggiati male (meno di 3 punti su 5 e il centro staccato), %d affondati in quello sotto (più di %d cm)" % [
			staccati.size(), roundi(STACCO * 100), male.size(), affondati.size(), roundi(STACCO * 100)])
	for x in affondati:
		print("NUMERI:   affondato %s #%d in %s: %.1f cm dentro quello che ha sotto" % [x[0], x[1], x[2], x[3] * 100.0])
	for x in staccati:
		print("NUMERI:   staccato %s #%d in %s: %.1f cm sopra quello che ha sotto" % [x[0], x[1], x[2], x[3] * 100.0])
	for x in male:
		print("NUMERI:   appoggiato male %s #%d in %s: %d punti su 5 (stacchi %s)" % x)
	# 2. le compenetrazioni
	var dentro := []
	for i in _scatole.size():
		for j in _vicine(_scatole[i][4]):
			if j <= i:
				continue
			if not (_scatole[i][4] as Rect2).intersects(_scatole[j][4]):
				continue
			var p := _dentro(i, j)
			if p > DENTRO:
				dentro.append([_scatole[i][0], _scatole[i][1], _scatole[j][0], _scatole[j][1], (_scatole[i][2] as Vector3).snapped(Vector3.ONE * 0.01), p])
	print("NUMERI: compenetrazioni fra scatole (più di %d mm): %d" % [roundi(DENTRO * 1000), dentro.size()])
	for x in dentro.slice(0, 40):
		print("NUMERI:   %s #%d dentro %s #%d in %s: %.1f cm" % [x[0], x[1], x[2], x[3], x[4], x[5] * 100.0])
	# 3. il pesante sotto: le casse a terra (le unità di casse a 0, le casse sciolte nei due piani di sotto)
	var casse_alte := 0
	for s in _scatole:
		var basso: float = (s[2] as Vector3).y - absf((s[3] as Basis).x.y) - absf((s[3] as Basis).y.y) - absf((s[3] as Basis).z.y)
		if s[0] == "PileCasse" and basso > 0.01:
			casse_alte += 1
		if s[0] == "PileCasseSciolte" and basso > 0.41:
			casse_alte += 1
	print("NUMERI: casse (le più pesanti) non a terra: %d" % casse_alte)
	# 4. la strada libera fino a 2 m: lungo il percorso a piedi un cilindro di 25 cm, fra 0,1 e 2 m sopra il pavimento
	var ingombri := {}
	for q in _strada() + _strada_approdo():
		var box := AABB(q + Vector3(-0.25, 0.1, -0.25), Vector3(0.5, 1.9, 0.5))
		for j in _vicine(Rect2(q.x - 0.3, q.z - 0.3, 0.6, 0.6)):
			var s: Array = _scatole[j]
			var c: Vector3 = s[2]
			var assi: Basis = s[3]
			var ext := Vector3(absf(assi.x.x) + absf(assi.y.x) + absf(assi.z.x), absf(assi.x.y) + absf(assi.y.y) + absf(assi.z.y),
					absf(assi.x.z) + absf(assi.y.z) + absf(assi.z.z))
			if AABB(c - ext, ext * 2.0).intersects(box):
				ingombri["%s #%d" % [s[0], s[1]]] = q.snapped(Vector3.ONE * 0.01)
		var cil := CylinderShape3D.new()
		cil.radius = 0.25
		cil.height = 1.9
		var qp := PhysicsShapeQueryParameters3D.new()
		qp.shape = cil
		qp.transform = Transform3D(Basis(), L(q) + Vector3.UP * 1.05)
		for h in fiume.get_world_3d().direct_space_state.intersect_shape(qp, 8):
			var n = h.collider
			ingombri["collisione " + (str(fiume.get_path_to(n)) if n is Node and fiume.is_ancestor_of(n) else str(n))] = q.snapped(Vector3.ONE * 0.01)
	print("NUMERI: sulla strada a piedi, fra 0,1 e 2 m: %d cose" % ingombri.size())
	for x in ingombri:
		print("NUMERI:   %s (la prima volta coi piedi in %s)" % [x, ingombri[x]])
	# 5. i buchi visti dalla strada
	_cerca_buchi()
	# 6. le lampade del fiume
	var luci := {}
	for l in fiume.find_children("*", "Light3D", true, false):
		var li := l as Light3D
		var k := "%s %.2f" % [li.get_class(), li.light_energy]
		luci[k] = luci.get(k, 0) + 1
	print("NUMERI: luci del fiume (tipo energia: quante): %s" % str(luci))
	var globi := {}
	for g in fiume.find_children("globo", "MeshInstance3D", true, false):
		var m := (g as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		var k := "%.2f" % (m.emission_energy_multiplier if m and m.emission_enabled else 0.0)
		globi[k] = globi.get(k, 0) + 1
	print("NUMERI: globi delle lampade a gabbia (emissione: quanti): %s" % str(globi))


## Vero se la forma di collisione colpita è una colonna delle pile (le BoxShape3D messe da _pile: 1,2 x 1,0 o 0,6 x 0,5/1,0,
## in piedi sulla banchina).
func _e_pila(h: Dictionary) -> bool:
	var co := h.get("collider") as CollisionObject3D
	if co == null:
		return false
	var owner_id := co.shape_find_owner(h["shape"])
	var cs := co.shape_owner_get_owner(owner_id) as CollisionShape3D
	if cs == null or not cs.shape is BoxShape3D:
		return false
	var sz := (cs.shape as BoxShape3D).size
	var y0 := cs.transform.origin.y - sz.y * 0.5
	return absf(y0) < 0.02 and ((absf(sz.x - 1.2) < 0.01 and absf(sz.z - 1.0) < 0.01) or (absf(sz.x - 0.6) < 0.01 and (absf(sz.z - 0.5) < 0.01 or absf(sz.z - 1.0) < 0.01)))


func _cerca_buchi() -> void:
	var muri: Array = fiume.call(&"_muri_pile")
	var spazio := fiume.get_world_3d().direct_space_state
	var visti := {}
	var raggi := 0
	for strada in [_strada(), _strada_approdo()]:
		for i in range(0, strada.size(), 2):
			var q: Vector3 = strada[i]
			for h in ALTEZZE:
				var o := L(q + Vector3.UP * h)
				for gg in 1200:
					var ang := deg_to_rad(gg * 0.3)
					var d := Vector3(sin(ang), 0.0, cos(ang))
					var dg := fiume.global_basis * d
					var par := PhysicsRayQueryParameters3D.create(o, o + dg * 30.0)
					par.exclude = [_p.get_rid()]
					var hit := spazio.intersect_ray(par)
					raggi += 1
					if hit.is_empty() or _e_pila(hit):
						continue
					var hl := fiume.to_local(hit["position"])
					for im in muri.size():
						var m: Array = muri[im]
						var a: Vector2 = m[0]
						var b: Vector2 = m[1]
						var n: Vector2 = m[2]
						var fronte: int = m[3] if m.size() > 3 else 0
						var dd := (b - a).normalized()
						var lungo := a.distance_to(b)
						var p2 := Vector2(hl.x, hl.z)
						var u := (p2 - a).dot(dd)
						var w := (p2 - a).dot(n)
						var wq := (Vector2(q.x, q.z) - a).dot(n)
						if u < 0.3 or u > lungo - 0.3:
							continue
						# dalla strada (davanti alla fila verso la strada) a dietro la fila davanti
						var buco := false
						if fronte == 0:
							buco = wq < 0.0 and w > F.PILA_STACCO + F.PILA_PROFONDO + 0.05 and w < 4.0
						else:
							buco = wq > 2.4 and w < F.PILA_STACCO + F.PILA_PROFONDO + F.PILA_FRA_FILE + F.PILA_RIENTRO - 0.05 and w > -1.5
						if not buco:
							continue
						var cosa: String = str(fiume.get_path_to(hit["collider"])) if hit["collider"] is Node and fiume.is_ancestor_of(hit["collider"]) else str(hit["collider"])
						var chiave := "%d:%d:%.1f" % [im, roundi(u / 0.3), h]
						if not visti.has(chiave):
							visti[chiave] = [q, hl, im, u, h, cosa, 0]
						visti[chiave][6] += 1
	_buchi = visti.values()
	_buchi.sort_custom(func(x, y): return [x[2], x[3], x[4]] < [y[2], y[3], y[4]])
	print("NUMERI: buchi visti dalla strada: %d raggi, %d punti dove un raggio passa oltre la fila davanti senza toccare una pila" % [raggi, _buchi.size()])
	for b in _buchi:
		print("NUMERI:   muro %d a %.1f m lungo il muro, a %.1f m d'altezza: dalla strada in %s si vede %s in %s (%d raggi)" % [
				b[2], b[3], b[4], (b[0] as Vector3).snapped(Vector3.ONE * 0.1), b[5], (b[1] as Vector3).snapped(Vector3.ONE * 0.1), b[6]])


# --- scatti ------------------------------------------------------------------------------------------------

func _guarda(occhio: Vector3, punto: Vector3) -> void:
	_p.global_position = occhio - Vector3.UP * (_p.get_eye_position().y - _p.global_position.y)
	_p.look_at_point(punto)
	_p.camera.global_transform = _p.get_aim_transform()
	_p.camera.make_current()


func _salva(nome: String) -> Image:
	await _frames(24)
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	im.save_jpg(_cartella.path_join("%03d_%s.jpg" % [_k, nome]), 0.88)
	_k += 1
	return im


func _luminosita(im: Image) -> String:
	var v := PackedFloat32Array()
	var w := im.get_width()
	var h := im.get_height()
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := im.get_pixel(x, y)
			v.append((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0)
	var s := 0.0
	for x in v:
		s += x
	var ord := Array(v)
	ord.sort()
	return "media %.1f, mediana %.1f, 10%% %.1f" % [s / v.size(), ord[ord.size() / 2], ord[ord.size() / 10]]


func _giro() -> void:
	for strade in [["strada", _strada(), 5], ["approdo", _strada_approdo(), 5]]:
		var s: Array[Vector3] = strade[1]
		for i in range(0, s.size(), strade[2]):
			var q: Vector3 = s[i]
			var dopo: Vector3 = s[mini(i + 1, s.size() - 1)]
			var avanti := (dopo - q) if i < s.size() - 1 else (q - s[i - 1])
			avanti.y = 0.0
			avanti = avanti.normalized()
			for v in [["avanti", 0.0], ["sinistra", 60.0], ["destra", -60.0]]:
				var dir := avanti.rotated(Vector3.UP, deg_to_rad(v[1]))
				_guarda(L(q + Vector3.UP * 1.6), L(q + Vector3.UP * 1.3 + dir * 5.0))
				await _salva("%s_%02d_%s" % [strade[0], i / strade[2], v[0]])


func _scatti_buchi() -> void:
	for b in _buchi.slice(0, 40):
		var q: Vector3 = b[0]
		var hl: Vector3 = b[1]
		_guarda(L(q + Vector3.UP * 1.6), L(Vector3(hl.x, b[4], hl.z)))
		await _salva("buco_muro%d_%.1fm_h%.1f" % [b[2], b[3], b[4]])


func _vicino() -> void:
	if _scatole.is_empty():
		_raccogli()
	var strada := _strada()
	# le cime aperte (unità senza film in cima) e gli scatoloni caduti sopra il film (di lato, su un'unità chiusa)
	var aperte := []
	var cadute := []
	for s in _scatole:
		var c: Vector3 = s[2]
		var d := INF
		for q in strada:
			d = minf(d, Vector2(q.x - c.x, q.z - c.z).length())
		if s[0] == "PileCartoneAperte":
			aperte.append([d, s])
		elif (s[0] == "PileScatole" or s[0] == "PileScatoleColorate") and absf((s[3] as Basis).z.normalized().y) > 0.9:
			# di lato (l'asse della profondità in verticale)
			cadute.append([d, s])
	aperte.sort_custom(func(x, y): return x[0] < y[0])
	cadute.sort_custom(func(x, y): return x[0] < y[0])
	print("VICINO: %d cime aperte e %d scatoloni di lato (caduti); scatto i più vicini alla strada" % [aperte.size(), cadute.size()])
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.02
	get_tree().current_scene.add_child(cam)
	for gruppo in [["aperta", aperte.slice(0, 14)], ["caduto", cadute.slice(0, 14)]]:
		for e in gruppo[1]:
			var s: Array = e[1]
			var c: Vector3 = s[2]
			var cima := c.y + (2.0 if gruppo[0] == "aperta" else 0.0)
			if gruppo[0] == "aperta":
				# il bancale: la cima aperta è a 0,95-1,35 m sopra
				cima = c.y + 1.2
			# dalla strada più vicina, 1,4 m dalla cima, appena sopra
			var q: Vector3 = strada[0]
			for p in strada:
				if Vector2(p.x - c.x, p.z - c.z).length() < Vector2(q.x - c.x, q.z - c.z).length():
					q = p
			var verso := Vector3(q.x - c.x, 0, q.z - c.z).normalized()
			for lato in [0.0, 40.0]:
				var da := Vector3(c.x, cima, c.z) + verso.rotated(Vector3.UP, deg_to_rad(lato)) * 1.4 + Vector3.UP * 0.45
				cam.global_position = L(da)
				cam.look_at(L(Vector3(c.x, cima - 0.1, c.z)), Vector3.UP)
				cam.make_current()
				await _salva("%s_%s%d_%s" % [gruppo[0], s[0], s[1], "fronte" if lato == 0.0 else "lato"])
	cam.queue_free()


func _luci() -> void:
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 200.0
	get_tree().current_scene.add_child(cam)
	var viste := {
		"bivio1": [F.anello(62.0) + Vector3(0, 0.6, 0), F.anello(90.0) + Vector3(0, 1.6, 0)],
		"paratia1": [F.anello(45.0) + Vector3(0, 0.6, 0), F.anello(55.0) + Vector3(0, 1.0, 0)],
		"bivio1_vicino": [F.anello(75.0) + Vector3(0, 0.6, 0), F.anello(90.0) + Vector3(0, 1.4, 0)],
		"bivio3": [F.anello(238.0) + Vector3(0, 0.6, 0), F.anello(229.0, F.R - 2.2) + Vector3(0, 1.8, 0)],
		"paratia3": [F.anello(222.0) + Vector3(0, 0.6, 0), F.anello(232.0) + Vector3(0, 1.0, 0)],
		"bivio3_avanti": [F.anello(242.0) + Vector3(0, 0.6, 0), F.anello(262.0) + Vector3(0, 1.0, 0)],
		"sponda_colonna": [F.anello(214.0) + Vector3(0, 0.6, 0), F.anello(224.4, 21.0) + Vector3(0, 1.4, 0)],
		"approdo": [Vector3(-29.6, 0.6, 0.0), Vector3(-40.0, 0.8, 0.0)],
		"porta_approdo": [Vector3(F.X0 + 2.5, 1.6, F.APPRODO.y), Vector3(F.X0 - 2.0, 1.4, F.APPRODO.y)],
		"piazza": [Vector3(F.INGRESSO_X, 1.7, F.Z0 + 1.0), Vector3(-3.6, 0.6, -3.6)],
		"imbarco": [Vector3(-2.3, 0.6, -2.3), Vector3(0.0, 0.9, -13.0)],
	}
	var da := Vector3(F.INGRESSO_X, 0, F.Z0 + 1.0)
	var dir := (F.FINE_FILA - da).normalized()
	var lungo := da.distance_to(F.FINE_FILA)
	for k in 4:
		var p: Vector3 = da + dir * lungo * [0.08, 0.35, 0.62, 0.9][k]
		viste["corridoio_%d" % (k + 1)] = [p + Vector3(0, 1.6, 0), p + dir * 8.0 + Vector3(0, 1.3, 0)]
	for nome in viste:
		var v: Array = viste[nome]
		cam.global_position = L(v[0])
		cam.look_at(L(v[1]), Vector3.UP)
		cam.make_current()
		var im := await _salva("luci_" + nome)
		print("LUCI: %s: %s" % [nome, _luminosita(im)])
	cam.queue_free()
