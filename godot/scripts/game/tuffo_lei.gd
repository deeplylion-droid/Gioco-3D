class_name TuffoLei
extends SkeletonModifier3D
## Il tuffo di testa di lei nella fossa (tappa 8, versione A scelta dall'utente il 22 ottobre): quando la
## spruzzi si spinge sulle mani, salta, si gira verso la fossa ed entra di testa; scende verso il fondo e
## piega verso il condotto. Si calcola qui, sopra la posa "affacciata" dello scheletro (medusa.glb non cambia):
## - il corpo (campana, busto, testa) si muove rigido lungo una curva di chiavi, ruotando intorno alla campana:
##   salendo fa un quarto di giro verso destra (il lato lungo della fossa) e va a testa in giù (all'apice, così
##   le braccia girano in alto, sopra il bordo); poi cade quasi dritta e dopo l'entrata segue la curva;
## - le braccia: nella spinta le mani restano sul bordo (IK a due ossa), poi si allungano davanti alla testa;
## - i tentacoli sono tirati come corde: ogni punta scorre lungo la forma che il tentacolo aveva (sopra il
##   bordo, dove già passava) e poi lungo la scia della sua radice, così entrano in acqua dove è entrata lei
##   senza attraversare il bordo né il pavimento;
## - la campana si allarga (campana_schiaccia a 0) e si contrae nel salto (campana_contrai).
## Le chiavi sono nel sistema della medusa (+Z davanti a lei, +Y su), relative alla campana a riposo.
## Lo usa LeiSbuca: avvia(), poi t (secondi) a ogni fotogramma; punti() per sapere quando è tutta sotto.

## [tempo, spostamento della campana]: spinta, salto sopra la fossa, entrata, giù verso il fondo e il condotto.
## Lei sta in mezzo al lato lungo della fossa (3,2 m alla sua destra e sinistra, 1,4 m dietro): salta un po'
## verso sinistra e si tuffa verso destra (dalla parte del condotto), lungo la linea di mezzo della fossa.
const CHIAVI := [
	[0.0, Vector3(0.0, 0.0, 0.0)],
	[0.3, Vector3(0.0, 0.3, -0.02)],
	[0.6, Vector3(-0.7, 2.1, -0.05)],
	[0.8, Vector3(-0.5, 1.5, -0.08)],
	[1.0, Vector3(-0.25, 0.0, -0.15)],
	[1.3, Vector3(0.1, -1.4, -0.3)],
	[1.7, Vector3(0.9, -1.9, -0.8)],
	[2.3, Vector3(2.4, -2.0, -2.1)],
]
## Da quando (s) l'asse del corpo segue la curva (prima lo decidono il mezzo giro e la rotazione in avanti).
const SEGUE_DA := 0.7
const PASSO := 1.0 / 120.0

## Secondi dall'inizio del tuffo.
var t := 0.0

var _sk: Skeleton3D
var _m := Transform3D.IDENTITY          # la medusa (il suo sistema: +Z davanti)
var _g0: Array[Transform3D] = []        # pose globali (mondo) di partenza
var _c0 := Vector3.ZERO                 # la campana a riposo (mondo)
var _corpo := PackedInt32Array()        # le ossa che si muovono rigide col corpo
var _braccia: Array = []                # [spalla, gomito, mano] per lato
var _tent: Array = []                   # per tentacolo: {ossa, lung, forma, radice}
var _mesh_campana: Array[MeshInstance3D] = []
var _ultimi_punti := PackedVector3Array()
var _asse_segue := Basis.IDENTITY       # rotazione del corpo a SEGUE_DA
var _esclusi: Array[RID] = []
var _inclinazione := 0.0                # quanto è chinata in avanti la posa affacciata (rad, intorno a X)


## Fotografa la posa di partenza (lei affacciata) e accende il tuffo. [param esclusi]: corpi da non contare
## come pavimento (il coperchio della fossa).
func avvia(medusa: Node3D, esclusi: Array[RID] = []) -> void:
	_esclusi = esclusi
	_sk = get_skeleton()
	if _sk == null:
		return
	_m = medusa.global_transform.orthonormalized()
	var sg := _sk.global_transform
	_g0.clear()
	for b in _sk.get_bone_count():
		_g0.append(sg * _sk.get_bone_global_pose(b))
	_c0 = _g0[_sk.find_bone("campana")].origin
	_corpo.clear()
	_tent.clear()
	_braccia.clear()
	for b in _sk.get_bone_count():
		var n := _sk.get_bone_name(b)
		if n.begins_with("tentacolo"):
			if n.ends_with("_01"):
				_tent.append(_catena(b))
		elif not _sotto_mano(b):
			# (le dita seguono la mano da sole: restano nella loro posa locale)
			_corpo.append(b)
	for lato in [".L", ".R"]:
		_braccia.append([_sk.find_bone("braccio" + lato), _sk.find_bone("avambraccio" + lato), _sk.find_bone("mano" + lato)])
	_mesh_campana.clear()
	for mi in medusa.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh is ArrayMesh and (mesh as ArrayMesh).get_blend_shape_count() > 0:
			_mesh_campana.append(mi)
		# Si sposta di qualche metro dentro lo scheletro: niente tagli dal culling.
		(mi as MeshInstance3D).extra_cull_margin = 8.0
	var a_loc := _m.basis.inverse() * _asse0()
	_inclinazione = atan2(a_loc.z, a_loc.y)
	_asse_segue = _rotazione_salto(SEGUE_DA)
	t = 0.0
	active = true


func ferma() -> void:
	active = false
	t = 0.0


## I punti di lei (mondo) che devono finire sott'acqua: la cima della testa, le punte delle dita medie e le
## punte dei tentacoli, nella posa di questo fotogramma.
func punti() -> PackedVector3Array:
	return _ultimi_punti


func _sotto_mano(b: int) -> bool:
	var p := _sk.get_bone_parent(b)
	while p >= 0:
		if _sk.get_bone_name(p).begins_with("mano"):
			return true
		p = _sk.get_bone_parent(p)
	return false


func _catena(radice: int) -> Dictionary:
	var ossa := PackedInt32Array([radice])
	while true:
		var figli := _sk.get_bone_children(ossa[ossa.size() - 1])
		if figli.is_empty():
			break
		ossa.append(figli[0])
	var giunti := PackedVector3Array()
	for b in ossa:
		giunti.append(_g0[b].origin)
	var lung := PackedFloat32Array()
	for i in ossa.size() - 1:
		lung.append(giunti[i].distance_to(giunti[i + 1]))
	var ultima := lung[lung.size() - 1] if lung.size() > 0 else 0.3
	lung.append(ultima)
	var punta := giunti[giunti.size() - 1] + _g0[ossa[ossa.size() - 1]].basis.y.normalized() * ultima
	# la forma di partenza dalla punta alla radice (esclusa): la strada che la punta ripercorre
	var forma := PackedVector3Array([punta])
	for i in range(giunti.size() - 1, 0, -1):
		forma.append(giunti[i])
	# La posa affacciata è fatta per la vasca centrale: qui qualche pezzo di tentacolo passa sotto il pavimento
	# o dentro il bordo della fossa. La strada che la punta ripercorre resta sopra (3 cm), così tirandolo non ci
	# entra; quei pezzi salgono sopra subito, nel fotogramma in cui la colpisci (passandoci piano spuntavano
	# fuori dal bordo).
	var fitta := PackedVector3Array([forma[0]])
	for i in range(1, forma.size()):
		var n := maxi(int(forma[i - 1].distance_to(forma[i]) / 0.05), 1)
		for j in range(1, n + 1):
			fitta.append(forma[i - 1].lerp(forma[i], float(j) / n))
	forma = fitta
	var alzata := PackedVector3Array()
	for q in forma:
		alzata.append(_sopra_il_pavimento(q))
	return {"ossa": ossa, "lung": lung, "forma": forma, "alzata": alzata, "radice": giunti[0], "scia": PackedVector3Array()}


func _sopra_il_pavimento(q: Vector3) -> Vector3:
	var spazio := _sk.get_world_3d().direct_space_state if _sk.is_inside_tree() else null
	if spazio == null:
		return q
	# la superficie più alta entro 6 cm: vicino al bordo la corda passa sopra lo spigolo, non lo taglia
	var alto := -INF
	for o in [Vector2.ZERO, Vector2(0.06, 0), Vector2(-0.06, 0), Vector2(0, 0.06), Vector2(0, -0.06)]:
		var giu := PhysicsRayQueryParameters3D.create(Vector3(q.x + o.x, q.y + 3.0, q.z + o.y), Vector3(q.x + o.x, q.y - 0.01, q.z + o.y), Layers.WORLD)
		giu.exclude = _esclusi
		var r := spazio.intersect_ray(giu)
		if not r.is_empty():
			alto = maxf(alto, float(r.position.y))
	if alto < q.y:
		return q
	return Vector3(q.x, alto + 0.03, q.z)


## Dove sta la campana (mondo) al tempo s: spline di Catmull-Rom tra le chiavi, nel sistema della medusa.
func _campana(s: float) -> Vector3:
	var n := CHIAVI.size()
	if s >= CHIAVI[n - 1][0]:
		var a: Vector3 = CHIAVI[n - 2][1]
		var b: Vector3 = CHIAVI[n - 1][1]
		var v: Vector3 = (b - a) / (float(CHIAVI[n - 1][0]) - float(CHIAVI[n - 2][0]))
		return _c0 + _m.basis * (b + v * (s - float(CHIAVI[n - 1][0])))
	var i := 0
	while i < n - 2 and s > CHIAVI[i + 1][0]:
		i += 1
	var t0: float = CHIAVI[i][0]
	var t1: float = CHIAVI[i + 1][0]
	var u := clampf((s - t0) / (t1 - t0), 0.0, 1.0)
	var p0: Vector3 = CHIAVI[maxi(i - 1, 0)][1]
	var p1: Vector3 = CHIAVI[i][1]
	var p2: Vector3 = CHIAVI[i + 1][1]
	var p3: Vector3 = CHIAVI[mini(i + 2, n - 1)][1]
	var q: Vector3 = 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)
	return _c0 + _m.basis * q


## La rotazione del corpo (mondo) al tempo s, rispetto alla posa di partenza.
func _rotazione(s: float) -> Basis:
	if s <= SEGUE_DA:
		return _rotazione_salto(s)
	# dopo l'entrata l'asse (dalla campana alla testa) segue la curva: la testa va avanti (in 0,2 s, dalla
	# rotazione del salto, senza scatti)
	var avanti := (_campana(s + 0.02) - _campana(s - 0.02)).normalized()
	var asse := _asse_segue * _asse0()
	var segue := Basis(Quaternion(asse, avanti)) * _asse_segue
	var w := smoothstep(SEGUE_DA, SEGUE_DA + 0.2, s)
	return Basis(_rotazione_salto(minf(s, 0.65)).get_rotation_quaternion().slerp(segue.get_rotation_quaternion(), w))


func _rotazione_salto(s: float) -> Basis:
	# un quarto di giro verso destra (il lato lungo della fossa, verso il condotto) e in avanti fino a testa in
	# giù; nella spinta un po' indietro
	var giro := PI * 0.5 * smoothstep(0.22, 0.42, s)
	var avanti_rad := deg_to_rad(-10.0) * smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.3, 0.4, s)) \
			+ deg_to_rad(172.0) * smoothstep(0.35, 0.62, s) \
			- _inclinazione * smoothstep(0.25, 0.45, s)   # salendo si raddrizza (affacciata è chinata avanti)
	var locale := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, avanti_rad)
	return _m.basis * locale * _m.basis.inverse()


## L'asse del corpo a riposo: dalla campana alla testa.
func _asse0() -> Vector3:
	return (_g0[_sk.find_bone("testa")].origin - _c0).normalized()


func _process_modification() -> void:
	if _sk == null or _g0.is_empty():
		return
	var sg := _sk.global_transform
	var inv := sg.affine_inverse()
	var c := _campana(t)
	var r := _rotazione(t)
	var mondo: Array[Transform3D] = []
	mondo.resize(_g0.size())
	# il corpo, rigido intorno alla campana
	for b in _corpo:
		var g := _g0[b]
		mondo[b] = Transform3D(r * g.basis, c + r * (g.origin - _c0))
	_braccia_a(mondo, c, r)
	# i tentacoli, tirati lungo la loro forma e la scia della radice
	var punte := PackedVector3Array()
	for k in _tent:
		punte.append(_tentacolo(k, mondo, c, r))
	# Le pose locali le calcolo io, dal padre (anche lui calcolato qui): impostare le globali una per volta
	# dentro il modificatore usa la posa del padre di prima.
	var fatto := PackedByteArray()
	fatto.resize(_g0.size())
	for b in _sk.get_bone_count():
		if mondo[b] == Transform3D():
			continue
		fatto[b] = 1
		var padre := _sk.get_bone_parent(b)
		var locale: Transform3D
		if padre < 0:
			locale = inv * mondo[b]
		elif fatto[padre] == 1:
			locale = mondo[padre].affine_inverse() * mondo[b]
		else:
			locale = (sg * _sk.get_bone_global_pose(padre)).affine_inverse() * mondo[b]
		_sk.set_bone_pose_position(b, locale.origin)
		_sk.set_bone_pose_rotation(b, locale.basis.get_rotation_quaternion())
	# la campana: si allarga uscendo dall'acqua, si contrae nel salto
	var schiaccia := 1.0 - smoothstep(0.15, 0.5, t)
	var contrai := smoothstep(0.35, 0.55, t) * (1.0 - smoothstep(0.75, 1.1, t))
	for mi in _mesh_campana:
		var mesh := mi.mesh as ArrayMesh
		for i in mesh.get_blend_shape_count():
			match String(mesh.get_blend_shape_name(i)):
				"campana_schiaccia":
					mi.set_blend_shape_value(i, schiaccia)
				"campana_contrai":
					mi.set_blend_shape_value(i, contrai)
	# i punti per LeiSbuca: cima della testa, dita medie, punte dei tentacoli
	var asse := r * _asse0()
	_ultimi_punti = PackedVector3Array()
	var occhio := _sk.find_bone("occhio")
	_ultimi_punti.append(c + r * (_g0[occhio].origin - _c0) + asse * 0.35)
	for lato in [".L", ".R"]:
		# il dito medio segue la mano: la sua posa rispetto alla mano non cambia
		var dito := _sk.find_bone("medio_3" + lato)
		var mano := _sk.find_bone("mano" + lato)
		if dito >= 0 and mano >= 0:
			_ultimi_punti.append(mondo[mano] * (_g0[mano].affine_inverse() * _g0[dito].origin))
	_ultimi_punti.append_array(punte)


## Braccia: nella spinta le mani restano dove sono (sul bordo), poi si allungano davanti alla testa.
func _braccia_a(mondo: Array[Transform3D], c: Vector3, r: Basis) -> void:
	var w := smoothstep(0.3, 0.55, t)
	var asse := r * _asse0()
	for lato in _braccia:
		var bs: int = lato[0]
		var bg: int = lato[1]
		var bm: int = lato[2]
		if bs < 0 or bg < 0 or bm < 0:
			continue
		var s0 := _g0[bs].origin
		var e0 := _g0[bg].origin
		var h0 := _g0[bm].origin
		var a := s0.distance_to(e0)
		var b := e0.distance_to(h0)
		var s := mondo[bs].origin
		# 1) la mano sul bordo (IK a due ossa, il gomito dalla parte di prima)
		var gomito_rigido := c + r * (e0 - _c0)
		var target := h0
		var d := clampf(s.distance_to(target), 0.05, a + b - 0.001)
		var u := (target - s).normalized()
		var polo := gomito_rigido - s
		polo = (polo - u * polo.dot(u)).normalized()
		var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
		var e_ik := s + a * (u * cos_a + polo * sqrt(1.0 - cos_a * cos_a))
		var h_ik := s + u * d
		# 2) braccia tese davanti alla testa, un poco verso l'asse del corpo
		var e_tesa := s + asse * a
		var h_tesa := e_tesa + asse * b
		var e := e_ik.lerp(e_tesa, w)
		var h := h_ik.lerp(h_tesa, w)
		mondo[bs] = _punta(_g0[bs], s, e)
		mondo[bg] = _punta(_g0[bg], e, h)
		var dir0 := (h0 - e0).normalized()
		var mano_tesa := Basis(Quaternion(dir0, (h - e).normalized())) * _g0[bm].basis
		mondo[bm] = Transform3D(_g0[bm].basis.slerp(mano_tesa, w), h)


## Un osso che parte da [param da] e punta verso [param verso], girato il meno possibile da come era.
func _punta(g: Transform3D, da: Vector3, verso: Vector3) -> Transform3D:
	var dir0 := g.basis.y.normalized()
	var dir := verso - da
	if dir.length_squared() < 1e-8:
		return Transform3D(g.basis, da)
	return Transform3D(Basis(Quaternion(dir0, dir.normalized())) * g.basis, da)


## Un tentacolo: la radice segue il corpo; i giunti stanno lungo la forma di partenza e la scia della radice,
## alle loro distanze dalla radice. Restituisce la punta (mondo).
func _tentacolo(k: Dictionary, mondo: Array[Transform3D], c: Vector3, r: Basis) -> Vector3:
	var ossa: PackedInt32Array = k["ossa"]
	var lung: PackedFloat32Array = k["lung"]
	var radice_0: Vector3 = k["radice"]
	# la scia della radice, campionata a passo fisso (uguale a ogni frequenza dei fotogrammi)
	var scia: PackedVector3Array = k["scia"]
	var serve := int(t / PASSO)
	while scia.size() <= serve:
		var s := scia.size() * PASSO
		scia.append(_campana(s) + _rotazione(s) * (radice_0 - _c0))
	k["scia"] = scia
	var strada := PackedVector3Array(k["alzata"])
	for i in serve + 1:
		strada.append(scia[i])
	strada.append(c + r * (radice_0 - _c0))
	# lunghezze cumulate lungo la strada
	var cum := PackedFloat32Array([0.0])
	for i in range(1, strada.size()):
		cum.append(cum[i - 1] + strada[i].distance_to(strada[i - 1]))
	var totale := cum[cum.size() - 1]
	var giunti := PackedVector3Array()
	var dist := 0.0
	for i in ossa.size() + 1:
		giunti.append(_su_strada(strada, cum, totale - dist))
		if i < lung.size():
			dist += lung[i]
	for i in ossa.size():
		mondo[ossa[i]] = _punta(_g0[ossa[i]], giunti[i], giunti[i + 1])
	return giunti[giunti.size() - 1]


func _su_strada(strada: PackedVector3Array, cum: PackedFloat32Array, s: float) -> Vector3:
	if s <= 0.0:
		return strada[0]
	var lo := 0
	var hi := cum.size() - 1
	if s >= cum[hi]:
		return strada[hi]
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var seg := cum[hi] - cum[lo]
	return strada[lo].lerp(strada[hi], (s - cum[lo]) / seg if seg > 1e-6 else 0.0)
