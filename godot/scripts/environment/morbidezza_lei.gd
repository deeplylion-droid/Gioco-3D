class_name MorbidezzaLei
extends SkeletonModifier3D
## Il movimento secondario di lei (riscontro dell'utente sul tuffo della v0.3.11: "la parte inferiore del suo corpo
## non è snodata, tutti i tentacoli dovrebbero esser molto morbidi"). Sopra la posa che arriva (animazione, tuffo,
## tentacoli contro i muri), che prende come bersaglio senza cambiarla:
## - i tentacoli: ogni catena di ossa "tentacolo_NN_MM" è una fila di punti con inerzia, tirata verso la posa da una
##   molla che si allenta verso la punta; le punte seguono in ritardo, frustano e si smorzano. La lunghezza di ogni
##   tratto resta quella delle ossa (si segue il punto prima, come una catena) e la velocità tolta dalla catena si
##   rende al punto dopo (Müller e altri, "Fast simulation of inextensible hair and fur"), così niente scatti. Un'onda
##   scorre dalla radice alla punta. In acqua (sotto il pelo delle vasche vicine) il trascinamento è alto, la gravità
##   quasi zero e l'onda lenta: fluttuano; in aria frustano e pendono. Fra i due si passa piano, punto per punto;
## - la collisione col mondo: ogni punto e il mezzo di ogni tratto restano fuori dalle forme convesse date da chi
##   conosce il posto (pareti, fondo, bordo, griglia: [method aggiungi_forme_da], [method aggiungi_scatola]) e
##   sopra il pavimento, a un raggio dalla superficie; si spinge fuori dalla faccia più vicina, così scivola senza
##   scatti. Le lunghezze dei tratti sono quelle di riposo delle ossa;
## - la campana: pulsa (forme campana_contrai e campana_schiaccia, sommate a quelle che mette chi anima) e si
##   deforma col movimento: si allunga (contrai) quando accelera, si schiaccia quando frena o entra in acqua.
## [member quanto] da 0 (spento: la posa resta quella che arriva, identica) a 1; si accende e si spegne piano con
## [method accendi] e [method spegni]. Partenza dalla posa: i punti nascono dove sono le ossa, senza velocità; se la
## posa salta (una ripartenza, un teletrasporto) si ricomincia da lì.

## Quanto vale il movimento secondario (0: niente, la posa resta identica).
@export_range(0.0, 1.0) var quanto := 1.0
## In quanti secondi si accende o si spegne.
@export var dissolvenza := 0.4
## La molla verso la posa: alla radice e alla punta (1/s²). Alta: segue; bassa: morbido.
@export var molla_radice := 260.0
@export var molla_punta := 9.0
## Lo smorzamento della velocità (1/s): in aria e in acqua.
@export var smorza_aria := 2.2
@export var smorza_acqua := 7.0
## La gravità sulle punte: in aria e in acqua (m/s², verso il basso; in acqua quasi galleggiano).
@export var gravita_aria := 4.0
@export var gravita_acqua := 0.25
## Quanto della velocità tolta dalla catena si rende al punto dopo (0-1).
@export var resa := 0.9
## L'onda dalla radice alla punta: ampiezza alla punta (m), velocità (giri al secondo) in aria e in acqua, quante
## onde lungo il tentacolo.
@export var onda_ampiezza := 0.06
@export var onda_aria := 1.1
@export var onda_acqua := 0.45
@export var onde := 1.2
## Di quanto un punto può restare lontano dalla posa, alla punta (m): oltre si tira dentro (nei movimenti velocissimi).
@export var distacco_massimo := 0.9
## La velocità più alta di un punto rispetto alla posa (m/s): le correzioni non lo lanciano.
@export var velocita_massima := 12.0
## Il raggio del tentacolo per le collisioni, alla radice e alla punta (m).
@export var raggio_radice := 0.07
@export var raggio_punta := 0.035
## La campana: pulsazione (forma campana_contrai, ampiezza e battiti al secondo) e deformazione col movimento.
@export var pulsa := 0.18
@export var pulsa_hz := 0.9
@export var allunga := 0.05
@export var schiaccia := 0.035
## Il pavimento per le collisioni: una lastra con la cima a questa quota (-INF: niente), tranne nella pianta
## [member buco_pavimento].
var pavimento_y := -INF
var buco_pavimento := Rect2()
## Tubi ([da, a, raggio]) dove le forme non contano: per esempio il condotto, chiuso dalla parete di collisione.
var tunnel: Array = []
## Le vasche (WaterTank) il cui pelo conta; vuoto: quelle entro 8 m, cercate all'inizio.
var vasche: Array = []
## Un'acqua in più, data da chi la conosce (la fossa dei bimbi): la pianta (x, z) e il pelo.
var acqua_pianta := Rect2()
var acqua_pelo := -INF
## Quanto è durato l'ultimo calcolo (microsecondi), per misurarlo.
var durata_usec := 0

const PASSO_MAX := 1.0 / 60.0

var _catene: Array[PackedInt32Array] = []
var _lunghezze: Array[PackedFloat32Array] = []   # per catena: la lunghezza di riposo di ogni tratto (mondo)
var _forme: Array = []                     # [piani (Array[Plane], verso fuori), AABB]
var _x: Array[PackedVector3Array] = []     # i punti (mondo): le teste delle ossa e la punta
var _v: Array[PackedVector3Array] = []     # le loro velocità
var _fase: PackedFloat32Array = []
var _pronte := false
var _t := 0.0
var _verso := 1.0                          # 1: si accende, -1: si spegne
var _peso := 0.0                            # quanto ora (dissolvenza)
var _radici_prima := PackedVector3Array()
var _tg_prima: Array[PackedVector3Array] = []
var _vp: Array[PackedVector3Array] = []     # la velocità della posa, media
var _campana := -1
var _campana_v := Vector3.ZERO
var _campana_p := Vector3.ZERO
var _campana_a := 0.0                      # accelerazione lungo l'asse del corpo, smorzata
var _mesh_campana: Array = []              # [MeshInstance3D, indice contrai, indice schiaccia]
var _messo := {}                           # [mesh, indice] -> quanto ho aggiunto alla forma l'ultima volta


func _ready() -> void:
	_peso = 0.0
	_verso = -1.0
	# sempre dopo gli altri modificatori dello scheletro, anche quelli messi dopo (il tuffo)
	var sk := get_parent()
	if sk:
		sk.child_entered_tree.connect(func(n):
			if n != self and n is SkeletonModifier3D:
				_in_fondo.call_deferred())


func _in_fondo() -> void:
	var sk := get_parent()
	if sk and get_index() != sk.get_child_count() - 1:
		sk.move_child(self, -1)


## Si accende piano (da dove sono le ossa adesso).
func accendi() -> void:
	_verso = 1.0
	if _peso <= 0.0:
		_pronte = false


## Si spegne piano: torna la posa che arriva.
func spegni() -> void:
	_verso = -1.0


## Spento subito, e si ricomincia dalla posa (una ripartenza).
func azzera() -> void:
	_verso = -1.0
	_peso = 0.0
	_pronte = false
	_togli_forme()


func _catene_di(sk: Skeleton3D) -> void:
	_catene.clear()
	for b in sk.get_bone_count():
		if not sk.get_bone_name(b).begins_with("tentacolo_"):
			continue
		var p := sk.get_bone_parent(b)
		if p >= 0 and sk.get_bone_name(p).begins_with("tentacolo_"):
			continue
		var catena := PackedInt32Array([b])
		var c := b
		while true:
			var dopo := -1
			for f in sk.get_bone_children(c):
				if sk.get_bone_name(f).begins_with("tentacolo_"):
					dopo = f
					break
			if dopo < 0:
				break
			catena.append(dopo)
			c = dopo
		if catena.size() >= 2:
			_catene.append(catena)
	_fase.resize(_catene.size())
	for k in _catene.size():
		_fase[k] = fmod(float(k) * 2.399963, TAU)   # angolo aureo: fasi sparse
	_campana = sk.find_bone("campana")
	_mesh_campana.clear()
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh as ArrayMesh
		if m == null:
			continue
		var ic := -1
		var isc := -1
		for i in m.get_blend_shape_count():
			match String(m.get_blend_shape_name(i)):
				"campana_contrai":
					ic = i
				"campana_schiaccia":
					isc = i
		if ic >= 0 or isc >= 0:
			_mesh_campana.append([mi, ic, isc])
	if vasche.is_empty():
		for n in sk.get_tree().get_nodes_in_group(&"water_tank") if sk.is_inside_tree() else []:
			vasche.append(n)
		if vasche.is_empty() and sk.is_inside_tree():
			for n in sk.get_tree().current_scene.find_children("*", "WaterTank", true, false):
				if (n as Node3D).global_position.distance_to(sk.global_position) < 8.0:
					vasche.append(n)


func _lunghezze_di(sk: Skeleton3D) -> void:
	_lunghezze.clear()
	var scala := sk.global_basis.get_scale().x
	for catena in _catene:
		var n := catena.size()
		var l := PackedFloat32Array()
		l.resize(n + 1)
		for i in range(1, n):
			l[i] = sk.get_bone_rest(catena[i]).origin.length() * scala
		l[n] = l[n - 1]
		_lunghezze.append(l)


## Il pelo dell'acqua sopra il punto (o -INF se non c'è acqua lì).
func _pelo(p: Vector3) -> float:
	if acqua_pianta.has_point(Vector2(p.x, p.z)):
		return acqua_pelo
	for v in vasche:
		if is_instance_valid(v) and (v as WaterTank).catches_point(Vector3(p.x, (v as WaterTank).get_floor_global_y() + 0.05, p.z)):
			return (v as WaterTank).get_surface_global_y()
	return -INF


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or not is_inside_tree():
		return
	# il tempo del gioco (non quello vero: col Movie Maker o in pausa il tempo vero corre diverso)
	var fisica := sk.modifier_callback_mode_process == Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS
	var dt := clampf(get_physics_process_delta_time() if fisica else get_process_delta_time(), 0.0, 0.1)
	_peso = clampf(_peso + _verso * dt / maxf(dissolvenza, 0.01), 0.0, 1.0)
	var w := _peso * quanto
	if w <= 0.0:
		# spento: la posa resta quella che arriva; le forme della campana tornano dove le ha messe chi anima
		_togli_forme()
		_pronte = false
		durata_usec = 0
		return
	var t0 := Time.get_ticks_usec()
	if _catene.is_empty():
		_catene_di(sk)
	if _lunghezze.size() != _catene.size():
		_lunghezze_di(sk)
	var sg := sk.global_transform
	# a passi di al più 1/60 s (la fisica dei punti resta stabile anche a pochi fotogrammi al secondo)
	var passi := maxi(1, ceili(dt / PASSO_MAX))
	var h := dt / passi
	_t += dt
	if not _pronte or _radici_prima.size() != _catene.size():
		_x.clear()
		_v.clear()
		_tg_prima.clear()
		_vp.clear()
		_radici_prima.resize(_catene.size())
	for k in _catene.size():
		var catena: PackedInt32Array = _catene[k]
		var n := catena.size()
		# il bersaglio: le teste delle ossa come le lascia la posa, e la punta
		var g: Array[Transform3D] = []
		var tg := PackedVector3Array()
		for b in catena:
			var tr := sg * sk.get_bone_global_pose(b)
			g.append(tr)
			tg.append(tr.origin)
		# le lunghezze: quelle di riposo delle ossa (la posa del tuffo a tratti ne allunga una di colpo, fino a quasi
		# quattro volte: qui restano giuste)
		var lung: PackedFloat32Array = _lunghezze[k]
		# la punta: lungo l'asse dell'ultimo osso (Y)
		tg.append(tg[n - 1] + g[n - 1].basis.y.normalized() * lung[n])
		# partenza dalla posa, o la posa è saltata (ripartenza, teletrasporto)
		if not _pronte or tg[0].distance_to(_radici_prima[k]) > 1.0:
			if _x.size() <= k:
				_x.append(tg.duplicate())
				var zero := PackedVector3Array()
				zero.resize(n + 1)
				_v.append(zero)
			else:
				_x[k] = tg.duplicate()
				var zero := PackedVector3Array()
				zero.resize(n + 1)
				_v[k] = zero
		_radici_prima[k] = tg[0]
		# la velocità della posa, punto per punto
		var vp := PackedVector3Array()
		vp.resize(n + 1)
		# (media sugli ultimi 50 ms: la posa del tuffo si muove a ogni passo della fisica, non a ogni fotogramma)
		if _tg_prima.size() <= k:
			_tg_prima.append(tg)
			var zero := PackedVector3Array()
			zero.resize(n + 1)
			_vp.append(zero)
		elif (_tg_prima[k] as PackedVector3Array).size() == n + 1 and dt > 0.0:
			var media := 1.0 - exp(-dt / 0.05)
			for i in n + 1:
				_vp[k][i] = _vp[k][i].lerp((tg[i] - _tg_prima[k][i]) / dt, media)
			_tg_prima[k] = tg
		vp = _vp[k]
		var x: PackedVector3Array = _x[k]
		var v: PackedVector3Array = _v[k]
		# le forme vicine a questo tentacolo (le altre non si guardano)
		var zona := AABB(tg[0], Vector3.ZERO)
		for q in tg:
			zona = zona.expand(q)
		for q in x:
			zona = zona.expand(q)
		zona = zona.grow(distacco_massimo + raggio_radice + 0.3)
		var forme: Array = []
		for fo in _forme:
			if (fo[1] as AABB).intersects(zona):
				forme.append(fo)
		# l'onda: di traverso al tentacolo, che scorre verso la punta
		var asse := (tg[n] - tg[0]).normalized()
		var lato := asse.cross(Vector3.UP)
		if lato.length() < 0.1:
			lato = asse.cross(Vector3.RIGHT)
		lato = lato.normalized()
		var lato2 := asse.cross(lato).normalized()
		for passo in passi:
			var pred := PackedVector3Array()
			pred.resize(n + 1)
			pred[0] = tg[0]
			for i in range(1, n + 1):
				var f := float(i) / n
				var acqua := clampf((_pelo(x[i]) - x[i].y) / 0.2 + 0.5, 0.0, 1.0)
				var giri := lerpf(onda_aria, onda_acqua, acqua)
				var fase := TAU * (giri * _t - onde * f) + _fase[k]
				var bersaglio := tg[i] + (lato * sin(fase) + lato2 * 0.5 * cos(fase * 0.7)) * onda_ampiezza * f * f
				var k_molla := lerpf(molla_radice, molla_punta, pow(f, 0.6))
				var smorza := lerpf(smorza_aria, smorza_acqua, acqua)
				var grav := lerpf(gravita_aria, gravita_acqua, acqua) * f
				var a := (bersaglio - x[i]) * k_molla - v[i] * smorza + Vector3(0, -grav, 0)
				# troppo lontano dalla posa (nei movimenti velocissimi del tuffo): una molla in più, dura, che la riprende
				var fuori := x[i] - tg[i]
				var lim := distacco_massimo * f
				if fuori.length() > lim:
					a -= fuori.normalized() * (fuori.length() - lim) * 400.0
				var vi := v[i] + a * h
				# non più veloce della posa di velocita_massima (la molla dura, a passi corti, lo lancerebbe)
				vi = vp[i] + (vi - vp[i]).limit_length(velocita_massima)
				pred[i] = x[i] + vi * h
			# la catena: ogni punto alla sua distanza dal punto prima (dalla radice), e fuori dai muri
			var corr := PackedVector3Array()
			corr.resize(n + 2)
			for i in range(1, n + 1):
				var f := float(i) / n
				var voluto := pred[i - 1] + (pred[i] - pred[i - 1]).normalized() * lung[i]
				# mai oltre il doppio (rete di sicurezza: la molla dura di sopra di solito basta)
				var lim := 2.0 * distacco_massimo * f
				var scarto := voluto - tg[i]
				if scarto.length() > lim:
					voluto = tg[i] + scarto.normalized() * lim
					voluto = pred[i - 1] + (voluto - pred[i - 1]).normalized() * lung[i]
				voluto = _fuori(voluto, lerpf(raggio_radice, raggio_punta, f), forme, x[i])
				corr[i] = voluto - pred[i]
				pred[i] = voluto
			# i tratti: anche il loro mezzo resta fuori dalle forme (non tagliano lo spigolo del bordo)
			_tratti_fuori(pred, n, forme, corr)
			for i in range(1, n + 1):
				var nv := (pred[i] - x[i]) / h
				if i < n:
					nv -= corr[i + 1] / h * resa
				# le correzioni (catena, distacco, mondo) diventano velocità: a passi corti sarebbero enormi; si limita
				# quanto va più veloce della posa (che nel tuffo a tratti corre)
				v[i] = vp[i] + (nv - vp[i]).limit_length(velocita_massima)
				x[i] = pred[i]
			x[0] = tg[0]
		_x[k] = x
		_v[k] = v
		# i punti come escono: fra la posa e i punti simulati (col peso); i punti non passano il mondo (scivolano)
		var xo := PackedVector3Array()
		xo.resize(n + 1)
		xo[0] = tg[0]
		# (anche la posa, dove entra nel mondo, ne esce piano con la dissolvenza: niente scatto all'inizio)
		for i in range(1, n + 1):
			var posa := tg[i]
			if w < 1.0:
				posa = posa.lerp(_fuori(posa, lerpf(raggio_radice, raggio_punta, float(i) / n), forme), w)
			xo[i] = posa.lerp(x[i], w)
		# le ossa: ogni osso parte dal suo punto e gira dalla direzione della posa verso il punto dopo (dal padre già
		# girato); la lunghezza può cambiare di poco (dove tocca), la pelle si allunga o si accorcia lì
		var padre := sk.get_bone_parent(catena[0])
		var padre_mondo := sg * sk.get_bone_global_pose(padre) if padre >= 0 else sg
		for i in n:
			var d0 := tg[i + 1] - tg[i]
			var d1 := xo[i + 1] - xo[i]
			var giro := Quaternion.IDENTITY
			if d0.length() > 1e-5 and d1.length() > 1e-5:
				giro = Quaternion(d0.normalized(), d1.normalized())
			var nuovo := Transform3D(Basis(giro) * g[i].basis, xo[i])
			var locale := padre_mondo.affine_inverse() * nuovo
			sk.set_bone_pose_position(catena[i], locale.origin)
			sk.set_bone_pose_rotation(catena[i], locale.basis.get_rotation_quaternion())
			if i == n - 1 and d0.length() > 1e-5:
				# l'ultimo osso non ha figli che lo tirano: si allunga o si accorcia lui, così la punta è dove il punto
				var sc := sk.get_bone_pose_scale(catena[i])
				sk.set_bone_pose_scale(catena[i], Vector3(sc.x, sc.y * d1.length() / d0.length(), sc.z))
			padre_mondo = nuovo
	_pronte = true
	_campana_forme(sk, sg, dt, w)
	durata_usec = Time.get_ticks_usec() - t0


## Aggiunge una forma convessa del mondo (punti nel mondo) contro cui i tentacoli non entrano.
func aggiungi_convesso(punti: PackedVector3Array) -> void:
	var piani: Array[Plane] = []
	var nn := punti.size()
	for a in nn:
		for b in range(a + 1, nn):
			for c in range(b + 1, nn):
				var nrm := (punti[b] - punti[a]).cross(punti[c] - punti[a])
				if nrm.length() < 1e-6:
					continue
				var pl := Plane(nrm.normalized(), punti[a])
				var sopra := 0
				var sotto := 0
				for q in punti:
					var d := pl.distance_to(q)
					if d > 1e-4:
						sopra += 1
					elif d < -1e-4:
						sotto += 1
				if sopra > 0 and sotto > 0:
					continue
				if sopra > 0:
					pl = -pl
				var doppio := false
				for e in piani:
					if e.normal.dot(pl.normal) > 0.9999 and absf(e.d - pl.d) < 1e-4:
						doppio = true
						break
				if not doppio:
					piani.append(pl)
	if piani.size() < 4:
		return
	var bb := AABB(punti[0], Vector3.ZERO)
	for q in punti:
		bb = bb.expand(q)
	_forme.append([piani, bb])


## Aggiunge una scatola (il suo centro e i suoi assi in [param xf], mezze misure [param mezzo]).
func aggiungi_scatola(xf: Transform3D, mezzo: Vector3) -> void:
	var punti := PackedVector3Array()
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				punti.append(xf * Vector3(sx * mezzo.x, sy * mezzo.y, sz * mezzo.z))
	aggiungi_convesso(punti)


## Aggiunge le forme di collisione (scatole e convesse) sotto [param radice] che toccano [param zona], tranne i
## corpi in [param salta].
func aggiungi_forme_da(radice: Node, zona: AABB, salta: Array = []) -> void:
	for cs in radice.find_children("*", "CollisionShape3D", true, false):
		var c3 := cs as CollisionShape3D
		if c3.disabled or c3.get_parent() in salta or c3 in salta:
			continue
		var punti := PackedVector3Array()
		if c3.shape is ConvexPolygonShape3D:
			for q in (c3.shape as ConvexPolygonShape3D).points:
				punti.append(c3.global_transform * q)
		elif c3.shape is BoxShape3D:
			var m := (c3.shape as BoxShape3D).size * 0.5
			aggiungi_scatola(c3.global_transform, m)
			continue
		else:
			continue
		var bb := AABB(punti[0], Vector3.ZERO)
		for q in punti:
			bb = bb.expand(q)
		if bb.intersects(zona):
			aggiungi_convesso(punti)


## Il punto [param p] fuori dal mondo (a [param r] da tutto): il pavimento (lastra con la cima a [member pavimento_y]
## fuori da [member buco_pavimento]) e le forme. Si spinge fuori dalla faccia da cui è entrato (dov'era, [param da]:
## così da una parete sottile non esce dall'altra parte), o se non si sa dalla più vicina: continuo, e il punto
## scivola. Nei [member tunnel] resta dentro il tubo, e alla bocca le forme non contano.
func _fuori(p: Vector3, r: float, forme: Array, da := Vector3.INF) -> Vector3:
	for t in tunnel:
		var a: Vector3 = t[0]
		var asse: Vector3 = (t[1] as Vector3) - a
		var la := asse.length()
		asse /= la
		var R: float = t[2]
		var lungo := (p - a).dot(asse)
		var radiale := (p - a) - asse * lungo
		var rho := radiale.length()
		if lungo >= 0.0 and lungo <= la and rho < R:
			if rho > R - r:
				p = a + asse * lungo + radiale / rho * (R - r)
			return p
		if lungo > -r and rho < R - r:
			return p
	for giro in 2:
		var mosso := false
		if p.y < pavimento_y + r and p.y > pavimento_y - 0.3 and not buco_pavimento.has_point(Vector2(p.x, p.z)):
			p.y = pavimento_y + r
			mosso = true
		for fo in forme:
			if not (fo[1] as AABB).grow(r).has_point(p):
				continue
			var meglio: Plane
			var dm := -INF
			for pl: Plane in fo[0]:
				var d := pl.distance_to(p)
				if d > dm:
					dm = d
					meglio = pl
			if dm >= r:
				continue
			# dalla faccia da cui veniva (quella che dov'era aveva più lontana), se dov'era stava fuori
			if da != Vector3.INF:
				var dprima := -INF
				for pl: Plane in fo[0]:
					var d0 := pl.distance_to(da)
					if d0 > dprima:
						dprima = d0
						if d0 >= r - 1e-4:
							meglio = pl
				if dprima >= r - 1e-4:
					dm = meglio.distance_to(p)
			p += meglio.normal * (r - dm)
			mosso = true
		if not mosso:
			break
	return p


## I tratti fuori dalle forme: dove un tratto entra in una forma (allargata del raggio: il tratto tagliato contro le
## facce) il suo punto di mezzo lì dentro esce dalla faccia più vicina, e lo spostamento va ai due capi secondo dove
## sta (alla radice, che segue la posa, no). Così anche lo spigolo del bordo non si taglia.
func _tratti_fuori(pt: PackedVector3Array, n: int, forme: Array, corr: PackedVector3Array) -> void:
	if forme.is_empty():
		return
	for i in range(1, n + 1):
		var r := lerpf(raggio_radice, raggio_punta, (float(i) - 0.5) / n)
		for fo in forme:
			var a := pt[i - 1]
			var b := pt[i]
			var bb := AABB(a, Vector3.ZERO).expand(b).grow(r)
			if not (fo[1] as AABB).intersects(bb):
				continue
			var t0 := 0.0
			var t1 := 1.0
			for pl: Plane in fo[0]:
				var da := pl.distance_to(a) - r
				var db := pl.distance_to(b) - r
				if da >= 0.0 and db >= 0.0:
					t0 = 2.0
					break
				if da < 0.0 and db < 0.0:
					continue
				var tc := da / (da - db)
				if da >= 0.0:
					t0 = maxf(t0, tc)
				else:
					t1 = minf(t1, tc)
				if t0 >= t1:
					break
			# solo se entra ed esce in mezzo (un capo dentro: ci pensa il punto, o è la radice che segue la posa)
			if t0 >= t1 or t0 <= 0.0 or t1 >= 1.0:
				continue
			var t := (t0 + t1) * 0.5
			if t < 0.02 or t > 0.98:
				continue                       # ai capi ci pensa il punto stesso
			var m := a.lerp(b, t)
			var nel_tubo := false
			for tu in tunnel:
				if Geometry3D.get_closest_point_to_segment(m, tu[0], tu[1]).distance_to(m) < float(tu[2]):
					nel_tubo = true
			if nel_tubo:
				continue
			var meglio: Plane
			var dm := -INF
			for pl: Plane in fo[0]:
				var d := pl.distance_to(m)
				if d > dm:
					dm = d
					meglio = pl
			var c := meglio.normal * (r - dm)
			var sa := Vector3.ZERO
			var sb := Vector3.ZERO
			if i == 1:
				sb = c / maxf(t, 0.5)
			else:
				var w := (1.0 - t) * (1.0 - t) + t * t
				sa = c * (1.0 - t) / w
				sb = c * t / w
			pt[i - 1] += sa
			pt[i] += sb
			if not corr.is_empty():
				corr[i - 1] += sa
				corr[i] += sb


## I punti dei tentacoli come sono adesso (mondo), per sapere se è tutta sotto; vuoto se è spenta.
func punti() -> PackedVector3Array:
	var out := PackedVector3Array()
	if _peso * quanto <= 0.0 or not _pronte:
		return out
	for x in _x:
		for i in range(1, x.size()):
			out.append(x[i])
	return out


## La campana pulsa e si deforma col movimento: si allunga (contrai) accelerando lungo il corpo, si schiaccia frenando.
func _campana_forme(sk: Skeleton3D, sg: Transform3D, dt: float, w: float) -> void:
	if _campana < 0 or _mesh_campana.is_empty():
		return
	var c := sg * sk.get_bone_global_pose(_campana)
	var p := c.origin
	if dt > 0.0 and _campana_p != Vector3.ZERO:
		var vel := (p - _campana_p) / dt
		var acc := (vel - _campana_v) / dt
		var su := c.basis.y.normalized()
		_campana_a = lerpf(_campana_a, clampf(acc.dot(su) / 30.0, -1.0, 1.0), clampf(dt * 8.0, 0.0, 1.0))
		_campana_v = vel
	_campana_p = p
	var battito := 0.5 + 0.5 * sin(TAU * pulsa_hz * _t)
	var contrai := pulsa * battito * battito + maxf(_campana_a, 0.0) * allunga * 10.0
	var piatta := maxf(-_campana_a, 0.0) * schiaccia * 10.0
	_togli_forme()
	for e in _mesh_campana:
		var mi := e[0] as MeshInstance3D
		if not is_instance_valid(mi):
			continue
		for coppia in [[e[1], contrai], [e[2], piatta]]:
			var i: int = coppia[0]
			if i < 0:
				continue
			var prima := mi.get_blend_shape_value(i)
			var dopo := clampf(prima + float(coppia[1]) * w, 0.0, 1.0)
			mi.set_blend_shape_value(i, dopo)
			_messo[[mi, i]] = [dopo - prima, dopo]


## Toglie quello che avevo aggiunto alle forme della campana (chi anima le rimette ogni fotogramma; se no restano).
func _togli_forme() -> void:
	for chiave in _messo:
		var mi := chiave[0] as MeshInstance3D
		var m: Array = _messo[chiave]
		# solo se nessuno l'ha rimessa dopo di me (il tuffo le riscrive ogni fotogramma)
		if is_instance_valid(mi) and is_equal_approx(mi.get_blend_shape_value(chiave[1]), float(m[1])):
			mi.set_blend_shape_value(chiave[1], clampf(float(m[1]) - float(m[0]), 0.0, 1.0))
	_messo.clear()
