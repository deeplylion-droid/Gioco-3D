extends RefCounted
## Le misure dei tentacoli morbidi (MorbidezzaLei) per i test delle scene di lei: si registrano i fotogrammi (la posa che
## arriva e le ossa come escono), poi [method risultati] dà:
## - dentro: punti dei tentacoli (teste, punte, quarti e metà dei tratti) dentro le forme del mondo di più di 1 cm;
## - attraversa: tratti che attraversano la collisione vera (raggi sullo strato WORLD) entrando più di 1 cm;
## - salto: quanto le ossa vanno più veloci della posa (m/s; la posa si muove a passi di fisica: il suo massimo sugli
##   ultimi 5 fotogrammi);
## - stira: i tratti rispetto alla lunghezza di riposo (minimo e massimo);
## - scarto: quanto le ossa si staccano dalla posa (che la morbidezza lavori davvero);
## - costo: medio, 95% e massimo (ms), e il massimo dei primi 3 fotogrammi (quando lei compare).
## Non si contano i tentacoli la cui radice (che segue la posa) è dentro il mondo: il primo tratto non può evitarlo.
## E [method pelle] dà la pelle vera: i vertici dei tentacoli deformati come nella scheda (ossa x bind x vertice), uno
## ogni [constant PELLE_OGNI], dentro la collisione vera di più di 1 cm (un raggio dall'asse del loro osso al vertice).

const PELLE_OGNI := 3

var sk: Skeleton3D
var m: MorbidezzaLei
var catene: Array[PackedInt32Array] = []
var entrata: Array = []
var uscita: Array = []
var costi: Array = []
var dt: Array = []
var _prima: SkeletonModifier3D
var _attiva := false
# la pelle: per vertice 4 ossa (indice in _p_usate), 4 pesi, 4 posizioni bind x vertice; l'osso dell'asse, quello dopo
# (o -1: la punta), la catena e il posto nella catena
var _p_ossa := PackedInt32Array()
var _p_pesi := PackedFloat32Array()
var _p_bv := PackedVector3Array()
var _p_asse := PackedInt32Array()
var _p_catena := PackedInt32Array()
var _p_usate := PackedInt32Array()    # ossa dello scheletro che servono
var _p_indice := {}                     # osso -> indice in _p_usate
var _pose: Array = []                  # per fotogramma: Array[Transform3D] delle ossa usate (mondo)


func _init(scheletro: Skeleton3D, morbidezza: MorbidezzaLei) -> void:
	sk = scheletro
	m = morbidezza
	for b in sk.get_bone_count():
		if not sk.get_bone_name(b).begins_with("tentacolo_"):
			continue
		var p := sk.get_bone_parent(b)
		if p >= 0 and sk.get_bone_name(p).begins_with("tentacolo_"):
			continue
		var c := PackedInt32Array([b])
		var x := b
		while true:
			var dopo := -1
			for f in sk.get_bone_children(x):
				if sk.get_bone_name(f).begins_with("tentacolo_"):
					dopo = f
			if dopo < 0:
				break
			c.append(dopo)
			x = dopo
		catene.append(c)
	_pelle_di()


## I vertici della pelle dei tentacoli (uno ogni PELLE_OGNI) con le loro ossa.
func _pelle_di() -> void:
	var dove := {}
	for k in catene.size():
		for i in catene[k].size():
			dove[catene[k][i]] = Vector2i(k, i)
	var usate := {}
	var n := 0
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		var skin := (mi as MeshInstance3D).skin
		if mesh == null or skin == null:
			continue
		var bind_osso := PackedInt32Array()
		for b in skin.get_bind_count():
			var nome := skin.get_bind_name(b)
			bind_osso.append(sk.find_bone(nome) if nome != "" else skin.get_bind_bone(b))
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			if a[Mesh.ARRAY_BONES] == null:
				continue
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bo = a[Mesh.ARRAY_BONES]
			var we = a[Mesh.ARRAY_WEIGHTS]
			var per: int = bo.size() / vs.size()
			for v in vs.size():
				var mig := -1
				var pm := 0.0
				for j in per:
					if float(we[v * per + j]) > pm:
						pm = float(we[v * per + j])
						mig = int(bo[v * per + j])
				if mig < 0 or not dove.has(bind_osso[mig]):
					continue
				n += 1
				if n % PELLE_OGNI != 0:
					continue
				var ki: Vector2i = dove[bind_osso[mig]]
				var c: PackedInt32Array = catene[ki.x]
				_p_asse.append(c[ki.y])
				_p_asse.append(c[ki.y + 1] if ki.y + 1 < c.size() else -1)
				_p_catena.append(ki.x)
				_p_catena.append(ki.y)
				# le 4 ossa più pesanti (le altre si buttano, i pesi si rinormalizzano)
				var lista := []
				for j in per:
					if float(we[v * per + j]) > 0.0:
						lista.append([float(we[v * per + j]), int(bo[v * per + j])])
				lista.sort_custom(func(x, y): return x[0] > y[0])
				lista = lista.slice(0, 4)
				var somma := 0.0
				for e in lista:
					somma += e[0]
				for j in 4:
					if j < lista.size():
						var osso := bind_osso[lista[j][1]]
						if not usate.has(osso):
							usate[osso] = _p_usate.size()
							_p_usate.append(osso)
						_p_ossa.append(usate[osso])
						_p_pesi.append(lista[j][0] / somma)
						_p_bv.append(skin.get_bind_pose(lista[j][1]) * vs[v])
					else:
						_p_ossa.append(0)
						_p_pesi.append(0.0)
						_p_bv.append(Vector3.ZERO)
	for b in _p_asse:
		if b >= 0 and not usate.has(b):
			usate[b] = _p_usate.size()
			_p_usate.append(b)
	_p_indice = usate


## Comincia a registrare (la posa dal modificatore prima della morbidezza, le ossa dopo).
func inizia() -> void:
	entrata.clear()
	uscita.clear()
	_pose.clear()
	costi.clear()
	dt.clear()
	_prima = sk.get_child(m.get_index() - 1) as SkeletonModifier3D
	if _prima and not _prima.modification_processed.is_connected(_su_entrata):
		_prima.modification_processed.connect(_su_entrata)
	if not m.modification_processed.is_connected(_su_uscita):
		m.modification_processed.connect(_su_uscita)
	_attiva = true


func ferma() -> void:
	_attiva = false
	if _prima and _prima.modification_processed.is_connected(_su_entrata):
		_prima.modification_processed.disconnect(_su_entrata)
	if m.modification_processed.is_connected(_su_uscita):
		m.modification_processed.disconnect(_su_uscita)


func _su_entrata() -> void:
	if _attiva:
		entrata.append(punti())


func _su_uscita() -> void:
	if _attiva:
		uscita.append(punti())
		var sg := sk.global_transform
		var ps: Array[Transform3D] = []
		for b in _p_usate:
			ps.append(sg * sk.get_bone_global_pose(b))
		_pose.append(ps)
		costi.append(m.durata_usec)
		dt.append(m.get_process_delta_time())


func lung_riposo(k: int, i: int) -> float:
	var c := catene[k]
	return sk.get_bone_rest(c[mini(i, c.size() - 1)]).origin.length() * sk.global_basis.get_scale().x


## I punti di tutte le catene (teste delle ossa e punta), nel mondo.
func punti() -> Array:
	var sg := sk.global_transform
	var out := []
	for k in catene.size():
		var c := catene[k]
		var pts := PackedVector3Array()
		for b in c:
			pts.append((sg * sk.get_bone_global_pose(b)).origin)
		var n := pts.size()
		var ultimo := sg * sk.get_bone_global_pose(c[n - 1])
		var allunga := ultimo.basis.y.length() / maxf(ultimo.basis.x.length(), 1e-6)
		pts.append(ultimo.origin + ultimo.basis.y.normalized() * lung_riposo(k, n) * allunga)
		out.append(pts)
	return out


## La scatola della forma in cui sta [param q] (o il pavimento), per gli esempi.
func _forma_di(q: Vector3) -> String:
	for fo in m.get(&"_forme"):
		var dm := -INF
		for pl: Plane in fo[0]:
			dm = maxf(dm, pl.distance_to(q))
		if dm < 0.0:
			return str(fo[1])
	return "pavimento"


func dentro(q: Vector3) -> float:
	return (m.call(&"_fuori", q, 0.0, m.get(&"_forme")) as Vector3).distance_to(q)


func _profondo(a: Vector3, b: Vector3) -> bool:
	for k in 9:
		if dentro(a.lerp(b, (k + 1) / 10.0)) > 0.01:
			return true
	return false


func _attraversa(a: Vector3, b: Vector3) -> bool:
	if a.distance_to(b) < 1e-4:
		return false
	var q := PhysicsRayQueryParameters3D.create(a, b, Layers.WORLD)
	q.hit_back_faces = false
	q.collide_with_areas = false
	return not sk.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## I risultati dal fotogramma [param da] (stampati con [param nome]).
func risultati(nome: String, da := 0) -> Dictionary:
	var nf := mini(uscita.size(), entrata.size()) if not entrata.is_empty() else uscita.size()
	var n_dentro := 0
	var n_attr := 0
	var radice_dentro := 0
	var salto := 0.0
	var stira_min := 10.0
	var stira_max := 0.0
	var scarto := 0.0
	var esempi := []
	var dove_min := ""
	for f in range(da, nf):
		var u: Array = uscita[f]
		for k in u.size():
			var pu: PackedVector3Array = u[k]
			if dentro(pu[0]) > 0.005:
				radice_dentro += 1
				continue
			if not entrata.is_empty() and f < entrata.size():
				var pe: PackedVector3Array = entrata[f][k]
				for i in pu.size():
					scarto = maxf(scarto, pe[i].distance_to(pu[i]))
			for i in range(1, pu.size()):
				for t in [0.0, 0.25, 0.5, 0.75]:
					var q := pu[i].lerp(pu[i - 1], t)
					var d := dentro(q)
					if d > 0.01:
						n_dentro += 1
						if esempi.size() < 3:
							esempi.append("dentro f%d k%d i%d %s di %.3f, in %s" % [f, k, i, q, d, _forma_di(q)])
				if _attraversa(pu[i - 1], pu[i]) and _profondo(pu[i - 1], pu[i]):
					n_attr += 1
					if esempi.size() < 6:
						esempi.append("attraversa f%d k%d i%d %s -> %s" % [f, k, i, pu[i - 1], pu[i]])
				if i < pu.size() - 1:
					var lr := lung_riposo(k, i)
					if lr > 0.02:
						var rap := pu[i].distance_to(pu[i - 1]) / lr
						if rap < stira_min:
							var rp := -1.0
							if not entrata.is_empty() and f < entrata.size():
								var pe2: PackedVector3Array = entrata[f][k]
								rp = pe2[i].distance_to(pe2[i - 1]) / lr
							dove_min = "tratto più corto f%d k%d i%d %.2f (nella posa %.2f) %s -> %s" % [f, k, i, rap, rp, pu[i - 1], pu[i]]
						stira_min = minf(stira_min, rap)
						stira_max = maxf(stira_max, rap)
				if f > da and not entrata.is_empty():
					var mu := pu[i].distance_to((uscita[f - 1][k] as PackedVector3Array)[i])
					var me := 0.0
					for g in range(maxi(f - 5, 1), f + 1):
						me = maxf(me, (entrata[g][k] as PackedVector3Array)[i].distance_to((entrata[g - 1][k] as PackedVector3Array)[i]))
					salto = maxf(salto, (mu - me) / maxf(float(dt[f]), 1.0 / 60.0))
	var c := costi.slice(da).filter(func(x): return x > 0)
	c.sort()
	var somma := 0.0
	for x in c:
		somma += x
	var primi: Array = costi.slice(0, 3).filter(func(x): return x > 0)
	var r := {
		"fotogrammi": nf - da, "dentro": n_dentro, "attraversa": n_attr, "radice_dentro": radice_dentro,
		"salto": salto, "stira_min": stira_min, "stira_max": stira_max, "scarto": scarto,
		"medio": somma / maxf(c.size(), 1) / 1000.0,
		"p95": (c[mini(c.size() - 1, int(c.size() * 0.95))] / 1000.0) if not c.is_empty() else 0.0,
		"massimo": (c.back() / 1000.0) if not c.is_empty() else 0.0,
		"primi": (primi.max() / 1000.0) if not primi.is_empty() else 0.0,
	}
	print("  %s: %d fotogrammi; dentro %d, attraversa %d (radice nel mondo, non contati: %d); salto %.1f m/s; tratti %.2f-%.2f; dalla posa al più %.2f m; costo medio %.2f, 95%% %.2f, massimo %.2f, primi fotogrammi %.2f ms" % [
		nome, r["fotogrammi"], n_dentro, n_attr, radice_dentro, salto, stira_min, stira_max, scarto, r["medio"], r["p95"], r["massimo"], r["primi"]])
	for e in esempi:
		print("    ", e)
	if dove_min != "":
		print("    ", dove_min)
	return r


## La pelle vera dal fotogramma [param da], un fotogramma ogni [param ogni]: i vertici dentro la collisione vera (strato
## WORLD) di più di [param tolleranza], cercati con un raggio dall'asse del loro osso (che sta fuori) al vertice. I
## vertici del primo osso (la radice segue il corpo) si contano a parte. Stampa le tre entrate più profonde.
## [param esclusi]: i RID delle collisioni che non si vedono (il coperchio della fossa).
func pelle(nome: String, da := 0, ogni := 2, tolleranza := 0.01, esclusi: Array[RID] = []) -> Dictionary:
	var spazio := sk.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = Layers.WORLD
	q.hit_back_faces = false
	q.collide_with_areas = false
	q.exclude = esclusi
	var nv := _p_asse.size() / 2
	var dentro := 0
	var dentro_radice := 0
	var massimo := 0.0
	var peggiori := []
	for f in range(da, _pose.size(), ogni):
		var ps: Array = _pose[f]
		for v in nv:
			var pos := Vector3.ZERO
			for j in 4:
				var w := _p_pesi[v * 4 + j]
				if w > 0.0:
					pos += ((ps[_p_ossa[v * 4 + j]] as Transform3D) * _p_bv[v * 4 + j]) * w
			var a_t: Transform3D = ps[_indice(_p_asse[v * 2])]
			var b_osso := _p_asse[v * 2 + 1]
			var fine: Vector3
			if b_osso >= 0:
				fine = (ps[_indice(b_osso)] as Transform3D).origin
			else:
				fine = a_t.origin + a_t.basis.y.normalized() * lung_riposo(_p_catena[v * 2], _p_catena[v * 2 + 1] + 1) \
						* a_t.basis.y.length() / maxf(a_t.basis.x.length(), 1e-6)
			var asse := Geometry3D.get_closest_point_to_segment(pos, a_t.origin, fine)
			if asse.distance_to(pos) < 1e-4:
				continue
			q.from = asse
			q.to = pos
			var hit := spazio.intersect_ray(q)
			if hit.is_empty():
				continue
			var d := (hit["position"] as Vector3).distance_to(pos)
			if d <= tolleranza:
				continue
			if _p_catena[v * 2 + 1] == 0:
				dentro_radice += 1
				continue
			dentro += 1
			massimo = maxf(massimo, d)
			peggiori.append([d, f, _p_catena[v * 2], _p_catena[v * 2 + 1], pos, (hit["collider"] as Node).name if hit["collider"] else ""])
	peggiori.sort_custom(func(x, y): return x[0] > y[0])
	print("  %s, pelle vera: %d vertici dentro il mondo di più di %.0f cm (al più %.1f cm), %d del primo osso (radice) a parte; %d vertici per fotogramma" % [
		nome, dentro, tolleranza * 100.0, massimo * 100.0, dentro_radice, nv])
	for e in peggiori.slice(0, 3):
		print("    pelle dentro di %.1f cm: f%d tentacolo %d osso %d %s in %s" % [e[0] * 100.0, e[1], e[2], e[3], e[4], e[5]])
	return {"pelle_dentro": dentro, "pelle_massimo": massimo, "pelle_radice": dentro_radice}


func _indice(osso: int) -> int:
	return _p_indice[osso]
