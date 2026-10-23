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

var sk: Skeleton3D
var m: MorbidezzaLei
var catene: Array[PackedInt32Array] = []
var entrata: Array = []
var uscita: Array = []
var costi: Array = []
var dt: Array = []
var _prima: SkeletonModifier3D
var _attiva := false


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


## Comincia a registrare (la posa dal modificatore prima della morbidezza, le ossa dopo).
func inizia() -> void:
	entrata.clear()
	uscita.clear()
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
							esempi.append("dentro f%d k%d i%d %s di %.3f" % [f, k, i, q, d])
				if _attraversa(pu[i - 1], pu[i]) and _profondo(pu[i - 1], pu[i]):
					n_attr += 1
					if esempi.size() < 6:
						esempi.append("attraversa f%d k%d i%d %s -> %s" % [f, k, i, pu[i - 1], pu[i]])
				if i < pu.size() - 1:
					var lr := lung_riposo(k, i)
					if lr > 0.02:
						var rap := pu[i].distance_to(pu[i - 1]) / lr
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
	return r
