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
##   sopra il pavimento, con tutta la pelle: la sezione vera di ogni osso (un'ellisse, i tentacoli sono nastri larghi
##   e sottili: [constant SEZIONI]) girata come l'osso, e contro ogni faccia la sua misura in quella direzione più
##   [constant MARGINE]. Così un nastro appoggiato di piatto sta a filo, uno di taglio sta fuori di tutta la
##   larghezza. Si spinge fuori dalla faccia più vicina, così scivola senza scatti. Le lunghezze dei tratti sono
##   quelle di riposo delle ossa;
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
## Il raggio del tentacolo per le collisioni, alla radice e alla punta (m), per le ossa che non sono in
## [constant SEZIONI].
@export var raggio_radice := 0.07
@export var raggio_punta := 0.035
## La sezione vera delle ossa dei tentacoli, presa dalla pelle (tests/genera_sezioni_tentacoli.gd): per osso
## [angolo dall'asse X, mezza larghezza, mezzo spessore] nel piano X-Z dell'osso, in unità dello scheletro.
const SEZIONI := "res://assets/models/medusa/medusa_sezioni_tentacoli.json"
## Quanto la pelle resta staccata dal mondo, oltre la sua sezione (m).
const MARGINE := 0.01
## In più sopra le facce verso l'alto (pavimento, cima del bordo): le strisce di bava (BavaRosa) stanno 1,2 cm sopra il
## pavimento, e i tentacoli ci passano sopra, non sotto (collaudo, 23 ottobre).
const SOPRA := 0.015
## Di quanto si allargano le forme e la zona del tentacolo per cercare i contatti: più della sezione più larga (m).
const VICINO := 0.2
## La campana: pulsazione (forma campana_contrai, ampiezza e battiti al secondo) e deformazione col movimento.
@export var pulsa := 0.18
@export var pulsa_hz := 0.9
@export var allunga := 0.05
@export var schiaccia := 0.035
## Il pavimento per le collisioni: una lastra spessa 1 m con la cima a questa quota (-INF: niente), tranne nella pianta
## [member buco_pavimento].
var pavimento_y := -INF
var buco_pavimento := Rect2()
## Tiene i tentacoli dentro la fossa ([member fossa_pianta]) dove la posa li porta sotto il pavimento fuori dalla
## fossa: mentre lei sbuca (la posa sale da 2,3 m sotto, e i tentacoli stesi sul pavimento salirebbero attraverso il
## pavimento). Escono dal bordo man mano che la posa arriva su; quando si spegne il trattenere cala in mezzo secondo.
var trattieni := false
## La quota sotto cui si trattiene (-INF: [member pavimento_y]); per esempio il bordo di un pozzo più alto del pavimento.
var trattieni_y := -INF
## Quando lei compare, i punti dentro il mondo si fermano sul tratto dal punto prima (all'ultimo posto fuori) invece di
## uscire dalla faccia più vicina: per i posti pieni di grate e muri sottili (l'inseguimento). Nella fossa no: lì la
## partenza di prima è già pulita.
var partenza_sul_tratto := false
## La pianta della fossa (x, z), per [member trattieni]: un poligono convesso.
var fossa_pianta := PackedVector2Array():
	set(v):
		fossa_pianta = v
		_fossa_dentro = PackedVector2Array()
## Tubi ([da, a, raggio]) dove le forme non contano: per esempio il condotto, chiuso dalla parete di collisione.
var tunnel: Array = []
## Le vasche (WaterTank) il cui pelo conta; vuoto: quelle entro 8 m, cercate all'inizio.
var vasche: Array = []
## Un'acqua in più, data da chi la conosce (la fossa dei bimbi): la pianta (x, z) e il pelo.
var acqua_pianta := Rect2()
var acqua_pelo := -INF
## Quanto è durato l'ultimo calcolo (microsecondi), per misurarlo; e per parti (bersagli, passi, ossa), sommate.
var durata_usec := 0
var parti_usec := {"bersagli": 0, "passi": 0, "ossa": 0, "giri": 0, "conta_passi": 0, "conta_giri": 0}

const PASSO_MAX := 1.0 / 30.0
## Il passo più lungo per un tentacolo simulato a fotogrammi alterni (posa quasi ferma).
const PASSO_LENTO := 1.0 / 15.0

var _catene: Array[PackedInt32Array] = []
var _lunghezze: Array[PackedFloat32Array] = []   # per catena: la lunghezza di riposo di ogni tratto (mondo)
var _sez: Array[PackedVector3Array] = []   # per catena, per osso: [angolo, mezza larghezza, mezzo spessore] (mondo)
static var _sezioni_file := {}             # osso (nome) -> [angolo, larghezza, spessore], da SEZIONI (una volta)
# la sezione di ogni punto della catena che si sta muovendo, nel mondo: l'ellisse dell'osso prima (1) e di quello dopo
# (2), come due semiassi; e la misura più grande (con il margine). Il tratto i usa l'ellisse 1 del punto i.
var _s1a := PackedVector3Array()
var _s1b := PackedVector3Array()
var _s2a := PackedVector3Array()
var _s2b := PackedVector3Array()
var _smax := PackedFloat32Array()
# le forme in una griglia di celle di CELLA m (le forme vicine a ogni cella, allargate di VICINO), fatta una volta quando
# le forme cambiano: con tante forme (l'inseguimento) ogni punto guarda solo quelle della sua cella
const CELLA := 1.0
var _griglia := {}
var _griglia_ok := false
var _ssu := PackedFloat32Array()           # la misura verso l'alto (il pavimento), con il margine
var _forme: Array = []                     # [piani (Array[Plane], verso fuori), AABB, indice della faccia di sopra o -1,
                                           #  AABB allargata del raggio]
var _x: Array[PackedVector3Array] = []     # i punti (mondo): le teste delle ossa e la punta
var _v: Array[PackedVector3Array] = []     # le loro velocità
var _fase: PackedFloat32Array = []
var _pronte := false
var _t := 0.0
var _verso := 1.0                          # 1: si accende, -1: si spegne
var _peso := 0.0                            # quanto ora (dissolvenza)
var _radici_prima := PackedVector3Array()
var _tg_prima: Array[PackedVector3Array] = []
var _bers: Array = []                      # per catena: i bersagli della molla fatti l'ultima volta, e la posa di allora
var _bers_posa: Array = []
var _trattieni_k := 0.0
var _fossa_dentro := PackedVector2Array()
var _dt_acc := PackedFloat32Array()        # per catena: il tempo da quando si è simulata l'ultima volta
var _fotogrammi := 0
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
	# le sezioni si leggono qui, con la scena, non quando lei compare (sarebbe un fotogramma lungo)
	_leggi_sezioni()
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


## Si accende piano (da dove sono le ossa adesso); [param subito]: tutta e subito (quando lei compare: prima non si
## vedeva, e i tentacoli devono già poggiare sul bordo).
func accendi(subito := false) -> void:
	_verso = 1.0
	if _peso <= 0.0:
		_pronte = false
	if subito:
		_peso = 1.0


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
		var scena := sk.get_tree().current_scene if sk.is_inside_tree() else null
		if vasche.is_empty() and scena:
			for n in scena.find_children("*", "WaterTank", true, false):
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
	# le sezioni (dal file, o un cerchio col raggio di prima)
	_leggi_sezioni()
	_sez.clear()
	for catena in _catene:
		var n := catena.size()
		var sz := PackedVector3Array()
		for j in n:
			var e = _sezioni_file.get(sk.get_bone_name(catena[j]))
			if e is Array and e.size() >= 3:
				sz.append(Vector3(float(e[0]), float(e[1]) * scala, float(e[2]) * scala))
			else:
				var r := lerpf(raggio_radice, raggio_punta, (float(j) + 0.5) / n)
				sz.append(Vector3(0.0, r, r))
		_sez.append(sz)


static func _leggi_sezioni() -> void:
	if _sezioni_file.is_empty() and FileAccess.file_exists(SEZIONI):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SEZIONI))
		if d is Dictionary and d.has("ossa"):
			_sezioni_file = d["ossa"]


## Le sezioni dei punti della catena [param k] nel mondo (_s1a, _s1b, _s2a, _s2b, _smax), con gli assi delle ossa della
## posa [param g] girati come i tratti dei punti [param x] rispetto a quelli della posa [param tg] (vuoto: la posa).
func _sezioni_qui(k: int, n: int, g: Array[Transform3D], tg: PackedVector3Array, x: PackedVector3Array) -> void:
	_s1a.resize(n + 1)
	_s1b.resize(n + 1)
	_s2a.resize(n + 1)
	_s2b.resize(n + 1)
	_smax.resize(n + 1)
	_ssu.resize(n + 1)
	var sz: PackedVector3Array = _sez[k]
	var ea := PackedVector3Array()
	var eb := PackedVector3Array()
	ea.resize(n)
	eb.resize(n)
	for j in n:
		var b := g[j].basis
		var ex := b.x.normalized()
		var ez := b.z.normalized()
		if x.size() == n + 1:
			var d0 := tg[j + 1] - tg[j]
			var d1 := x[j + 1] - x[j]
			if d0.length_squared() > 1e-10 and d1.length_squared() > 1e-10:
				var q := Quaternion(d0.normalized(), d1.normalized())
				ex = q * ex
				ez = q * ez
		var e := sz[j]
		var c := cos(e.x)
		var s := sin(e.x)
		ea[j] = (ex * c + ez * s) * e.y
		eb[j] = (ez * c - ex * s) * e.z
	for i in n + 1:
		var j1 := maxi(i - 1, 0)
		var j2 := mini(i, n - 1)
		_s1a[i] = ea[j1]
		_s1b[i] = eb[j1]
		_s2a[i] = ea[j2]
		_s2b[i] = eb[j2]
		_smax[i] = maxf(maxf(sz[j1].y, sz[j1].z), maxf(sz[j2].y, sz[j2].z)) + MARGINE + SOPRA
		_ssu[i] = sqrt(maxf(ea[j1].y * ea[j1].y + eb[j1].y * eb[j1].y, ea[j2].y * ea[j2].y + eb[j2].y * eb[j2].y)) + MARGINE + SOPRA


## Le forme vicine alla cella del punto [param p] (con poche forme, tutte quelle date).
func _forme_in(p: Vector3, forme: Array) -> Array:
	if _forme.size() <= 24:
		return forme
	if not _griglia_ok:
		_griglia.clear()
		for fo in _forme:
			var g: AABB = fo[3]
			var a := Vector3i((g.position / CELLA).floor())
			var b := Vector3i((g.end / CELLA).floor())
			for x in range(a.x, b.x + 1):
				for y in range(a.y, b.y + 1):
					for z in range(a.z, b.z + 1):
						var k := Vector3i(x, y, z)
						if not _griglia.has(k):
							_griglia[k] = []
						_griglia[k].append(fo)
		_griglia_ok = true
	return _griglia.get(Vector3i((p / CELLA).floor()), [])


## La misura della pelle al punto [param i] verso [param nrm] (le due ellissi, la più grande), più il margine (e
## [constant SOPRA] verso l'alto).
func _sup(nrm: Vector3, i: int) -> float:
	var u := nrm.dot(_s1a[i])
	var v := nrm.dot(_s1b[i])
	var s1 := u * u + v * v
	u = nrm.dot(_s2a[i])
	v = nrm.dot(_s2b[i])
	return sqrt(maxf(s1, u * u + v * v)) + MARGINE + (SOPRA if nrm.y > 0.7 else 0.0)


## La misura della pelle del tratto [param i] (l'osso i - 1) verso [param nrm], più il margine.
func _sup_tratto(nrm: Vector3, i: int) -> float:
	var u := nrm.dot(_s1a[i])
	var v := nrm.dot(_s1b[i])
	return sqrt(u * u + v * v) + MARGINE + (SOPRA if nrm.y > 0.7 else 0.0)


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
	# a passi di al più 1/30 s (la fisica dei punti resta stabile anche a pochi fotogrammi al secondo)
	var passi := maxi(1, ceili(dt / PASSO_MAX - 0.01))     # (- 0,01: 1/30 diviso 1/30 a volte fa 1,0000001)
	var h := dt / passi
	_fotogrammi += 1
	_trattieni_k = move_toward(_trattieni_k, 1.0 if trattieni else 0.0, dt * 2.0) if _pronte else (1.0 if trattieni else 0.0)
	_t += dt
	if not _pronte or _radici_prima.size() != _catene.size():
		# (un posto per catena; vuoto: da fare)
		var nc := _catene.size()
		_x.clear()
		_x.resize(nc)
		_v.clear()
		_v.resize(nc)
		_tg_prima.clear()
		_vp.clear()
		_bers.clear()
		_bers_posa.clear()
		for k in nc:
			_bers.append(PackedVector3Array())
			_bers_posa.append(PackedVector3Array())
		_radici_prima.resize(nc)
		_pronte = true
	var partite := 0
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
				# (al più 15 m/s: quando la posa salta, all'inizio del tuffo, la media non deve lanciare i punti)
				_vp[k][i] = _vp[k][i].lerp((tg[i] - _tg_prima[k][i]) / dt, media).limit_length(15.0)
			_tg_prima[k] = tg
		vp = _vp[k]
		# con la posa quasi ferma (lei affacciata) ogni tentacolo si simula un fotogramma sì e uno no, a turno (metà dei
		# tentacoli per fotogramma), col tempo di tutti e due: le ossa si scrivono sempre, dai punti dell'ultima volta
		if _dt_acc.size() != _catene.size():
			_dt_acc.resize(_catene.size())
		_dt_acc[k] += dt
		var dt_k: float = _dt_acc[k]
		if passi == 1 and not (_x[k] as PackedVector3Array).is_empty() \
				and (k + _fotogrammi) % 2 == 1 and dt_k < 0.1 and _quasi_ferma(tg, _bers_posa[k]):
			var xs: PackedVector3Array = (_x[k] as PackedVector3Array).duplicate()
			xs[0] = tg[0]
			var us := Time.get_ticks_usec()
			_scrivi_ossa(sk, sg, catena, n, g, tg, xs, w, [])
			parti_usec["ossa"] += Time.get_ticks_usec() - us
			continue
		_dt_acc[k] = 0.0
		var passi_k := passi
		var h_k := h
		if passi == 1:
			passi_k = maxi(1, ceili(dt_k / PASSO_LENTO - 0.01))
			h_k = dt_k / passi_k
		# le forme vicine a questo tentacolo (le altre non si guardano)
		var zona := AABB(tg[0], Vector3.ZERO)
		for q in tg:
			zona = zona.expand(q)
		if (_x[k] as PackedVector3Array).size() == n + 1:
			for q in _x[k]:
				zona = zona.expand(q)
		# (le punte in un fotogramma si muovono al più qualche decina di cm: oltre non serve guardare)
		zona = zona.grow(VICINO + 0.25)
		var forme: Array = []
		for fo in _forme:
			if (fo[1] as AABB).intersects(zona):
				forme.append(fo)
		# partenza dalla posa, o la posa è saltata (ripartenza, teletrasporto)
		if (_x[k] as PackedVector3Array).is_empty() or tg[0].distance_to(_radici_prima[k]) > 1.0:
			# (accendendosi piano, al più 9 catene per fotogramma: le altre restano la posa, che è quasi tutto)
			if w < 0.5 and partite >= 9:
				_x[k] = PackedVector3Array()
				continue
			partite += 1
			_sezioni_qui(k, n, g, tg, PackedVector3Array())
			_x[k] = _partenza(tg, n, forme, lung)
			var zero := PackedVector3Array()
			zero.resize(n + 1)
			_v[k] = zero
			# (in questo fotogramma solo la partenza: così quando lei compare non c'è un fotogramma lungo)
			_radici_prima[k] = tg[0]
			_dt_acc[k] = 0.0
			var u_p := Time.get_ticks_usec()
			_scrivi_ossa(sk, sg, catena, n, g, tg, _x[k], w, [])
			parti_usec["ossa"] += Time.get_ticks_usec() - u_p
			continue
		_radici_prima[k] = tg[0]
		var x: PackedVector3Array = _x[k]
		var v: PackedVector3Array = _v[k]
		_sezioni_qui(k, n, g, tg, x)
		# vicino al mondo, nei movimenti veloci (lo strappo del tuffo) un passo non deve portare un punto più in là di
		# 12 cm: se no passerebbe il bordo da parte a parte (è largo 30 cm). Lì il fotogramma si divide, fino a 3 passi
		if not forme.is_empty():
			# (solo i punti veloci la cui strada in questo fotogramma tocca una forma)
			var vmax := 0.0
			for i in range(1, n + 1):
				var vi := maxf(vp[i].length(), v[i].length())
				if vi * dt_k <= 0.12 or vi <= vmax:
					continue
				var strada := AABB(x[i], Vector3.ZERO).expand(x[i] + (v[i] if v[i].length() > vp[i].length() else vp[i]) * dt_k)
				for fo in forme:
					if (fo[3] as AABB).intersects(strada):
						vmax = vi
						break
			var servono := mini(3, ceili(vmax * dt_k / 0.12 - 0.01))
			if servono > passi_k:
				passi_k = servono
				h_k = dt_k / passi_k
		# l'onda: di traverso al tentacolo, che scorre verso la punta
		var asse := (tg[n] - tg[0]).normalized()
		var lato := asse.cross(Vector3.UP)
		if lato.length() < 0.1:
			lato = asse.cross(Vector3.RIGHT)
		lato = lato.normalized()
		var lato2 := asse.cross(lato).normalized()
		# i bersagli e quanto è in acqua ogni punto: una volta per fotogramma (non cambiano fra un passo e l'altro)
		var u0 := Time.get_ticks_usec()
		# (rifatti solo se la posa ha cambiato forma di più di 5 cm da quando si sono fatti; se no quelli di prima,
		# spostati come la posa: con lei affacciata la posa si muove appena, nel tuffo si sposta quasi tutta insieme)
		var tgf: PackedVector3Array
		var rifai := (_bers_posa[k] as PackedVector3Array).size() != n + 1 or (_trattieni_k > 0.0 and _trattieni_k < 1.0)
		if not rifai:
			var cp: PackedVector3Array = _bers_posa[k]
			# (spostati come la posa, rispetto alla radice: valgono finché nessun punto si è mosso più di 5 cm così)
			var spost := tg[0] - cp[0]
			for i in n + 1:
				if (cp[i] + spost).distance_squared_to(tg[i]) > 0.0025:
					rifai = true
					break
		if rifai:
			tgf = _bersagli(tg, n, _vicine(tg, forme))
			_bers[k] = tgf.duplicate()
			_bers_posa[k] = tg.duplicate()
		else:
			tgf = (_bers[k] as PackedVector3Array).duplicate()
			var cp: PackedVector3Array = _bers_posa[k]
			for i in n + 1:
				tgf[i] += tg[i] - cp[i]
			tgf[0] = tg[0]
		# (il distacco si misura dai bersagli senza onda: dalla posa fuori dal mondo, o trattenuta nella fossa)
		var rif := tgf.duplicate()
		var in_acqua := PackedFloat32Array()
		in_acqua.resize(n + 1)
		for i in range(1, n + 1):
			var f := float(i) / n
			var acqua := clampf((_pelo(x[i]) - x[i].y) / 0.2 + 0.5, 0.0, 1.0)
			in_acqua[i] = acqua
			var giri := lerpf(onda_aria, onda_acqua, acqua)
			var fase := TAU * (giri * _t - onde * f) + _fase[k]
			rif[i] = tgf[i]
			tgf[i] += (lato * sin(fase) + lato2 * 0.5 * cos(fase * 0.7)) * onda_ampiezza * f * f
		var u1 := Time.get_ticks_usec()
		parti_usec["bersagli"] += u1 - u0
		parti_usec["conta_passi"] += passi_k
		for passo in passi_k:
			var pred := PackedVector3Array()
			pred.resize(n + 1)
			pred[0] = tg[0]
			for i in range(1, n + 1):
				var f := float(i) / n
				var acqua := in_acqua[i]
				var bersaglio := tgf[i]
				var k_molla := lerpf(molla_radice, molla_punta, pow(f, 0.6))
				var smorza := lerpf(smorza_aria, smorza_acqua, acqua)
				var grav := lerpf(gravita_aria, gravita_acqua, acqua) * f
				var a := (bersaglio - x[i]) * k_molla - v[i] * smorza + Vector3(0, -grav, 0)
				# troppo lontano dalla posa (nei movimenti velocissimi del tuffo): una molla in più, dura, che la riprende
				var fuori := x[i] - rif[i]
				var lim := distacco_massimo * f
				if fuori.length() > lim:
					a -= fuori.normalized() * (fuori.length() - lim) * 400.0
				var vi := v[i] + a * h_k
				# non più veloce della posa di velocita_massima (la molla dura, a passi corti, lo lancerebbe)
				vi = vp[i] + (vi - vp[i]).limit_length(velocita_massima)
				pred[i] = x[i] + vi * h_k
			# la catena: ogni punto alla sua distanza dal punto prima (dalla radice), e fuori dai muri
			var corr := PackedVector3Array()
			corr.resize(n + 2)
			for i in range(1, n + 1):
				var f := float(i) / n
				var voluto := pred[i - 1] + (pred[i] - pred[i - 1]).normalized() * lung[i]
				# mai oltre il doppio (rete di sicurezza: la molla dura di sopra di solito basta)
				var lim := 2.0 * distacco_massimo * f
				var scarto := voluto - rif[i]
				if scarto.length() > lim:
					voluto = rif[i] + scarto.normalized() * lim
					voluto = pred[i - 1] + (voluto - pred[i - 1]).normalized() * lung[i]
				voluto = _fuori(voluto, lerpf(raggio_radice, raggio_punta, f), forme, x[i], false, i)
				corr[i] = voluto - pred[i]
				pred[i] = voluto
			# poi, dove tocca il mondo, a giri: le lunghezze (i due capi di ogni tratto si vengono incontro, la
			# radice resta), i punti fuori dalle forme, i tratti fuori dalle forme (non tagliano lo spigolo del bordo); fino a
			# tre giri, finché qualcosa si muove di più di un millimetro.
			# Così un tentacolo sul bordo trova da solo come starci sopra con le sue lunghezze
			var ug := Time.get_ticks_usec()
			# (solo le forme che toccano davvero il tentacolo adesso: lontano dai muri niente giri)
			var tocca := _vicine(pred, forme)
			if not tocca.is_empty():
				for giro in 3:
					parti_usec["conta_giri"] += 1
					var prima_giro := pred.duplicate()
					for i in range(1, n + 1):
						var d := pred[i] - pred[i - 1]
						var l := d.length()
						if l < 1e-6:
							continue
						var e := d * ((l - lung[i]) / l)
						if i == 1:
							pred[i] -= e
						else:
							pred[i - 1] += e * 0.5
							pred[i] -= e * 0.5
					_tratti_fuori(pred, n, tocca, PackedVector3Array())
					for i in range(1, n + 1):
						pred[i] = _fuori(pred[i], lerpf(raggio_radice, raggio_punta, float(i) / n), tocca, Vector3.INF, false, i)
					# fermo: nessun tocco e lunghezze giuste, gli altri giri non servono
					var mosso := 0.0
					for i in range(1, n + 1):
						mosso = maxf(mosso, prima_giro[i].distance_squared_to(pred[i]))
					# (il terzo giro solo se il secondo ha mosso ancora più di 5 mm: lo strappo del tuffo sul bordo)
					if mosso < (1e-6 if giro == 0 else 2.5e-5):
						break
			parti_usec["giri"] += Time.get_ticks_usec() - ug
			for i in range(1, n + 1):
				var nv := (pred[i] - x[i]) / h_k
				if i < n:
					nv -= corr[i + 1] / h_k * resa
				# le correzioni (catena, distacco, mondo) diventano velocità: a passi corti sarebbero enormi; si limita
				# quanto va più veloce della posa (che nel tuffo a tratti corre)
				v[i] = vp[i] + (nv - vp[i]).limit_length(velocita_massima)
				x[i] = pred[i]
			x[0] = tg[0]
		_x[k] = x
		_v[k] = v
		var u2 := Time.get_ticks_usec()
		parti_usec["passi"] += u2 - u1
		_scrivi_ossa(sk, sg, catena, n, g, tg, x, w, forme)
		parti_usec["ossa"] += Time.get_ticks_usec() - u2
	_pronte = true
	_campana_forme(sk, sg, dt, w)
	durata_usec = Time.get_ticks_usec() - t0


## Da dove partono i punti quando lei compare: i bersagli (la posa fuori dal mondo, sopra il bordo dove ci passa
## sotto), poi tre giri come in un passo (lunghezze, tratti, punti): già il primo fotogramma è pulito, senza un
## assestamento lungo (sarebbe uno scatto proprio quando sbuca).
func _partenza(tg: PackedVector3Array, n: int, forme: Array, lung: PackedFloat32Array) -> PackedVector3Array:
	var pt := _bersagli(tg, n, _vicine(tg, forme))
	# dalla radice in giù: dove un punto, o il tratto che ci arriva, è dentro il mondo (la posa mette una punta sotto una
	# grata o dentro un muro sottile), il punto si ferma sul tratto, all'ultimo posto fuori, invece di uscire dalla faccia
	# più vicina (che può essere quella dall'altra parte)
	if partenza_sul_tratto and not forme.is_empty():
		for i in range(1, n + 1):
			var r := lerpf(raggio_radice, raggio_punta, float(i) / n)
			var ultimo := 0.0
			for k in range(1, 9):
				var q := pt[i - 1].lerp(pt[i], k / 8.0)
				if _fuori(q, r, forme, Vector3.INF, false, i).distance_squared_to(q) > 1e-6:
					pt[i] = pt[i - 1].lerp(pt[i], ultimo)
					break
				ultimo = k / 8.0
	# tre giri come in un passo: le lunghezze (i bersagli possono avvicinare due punti, trattenuti nella fossa sullo
	# stesso bordo), i tratti e i punti fuori dal mondo, dalla parte dov'erano prima del giro (un muro sottile non si passa)
	for giro in 3:
		var prima := pt.duplicate()
		for i in range(1, n + 1):
			var d := pt[i] - pt[i - 1]
			var l := d.length()
			if l < 1e-6:
				continue
			var e := d * ((l - lung[i]) / l)
			if i == 1:
				pt[i] -= e
			else:
				pt[i - 1] += e * 0.5
				pt[i] -= e * 0.5
		_tratti_fuori(pt, n, forme, PackedVector3Array())
		for i in range(1, n + 1):
			# (al primo giro dalla parte del punto prima, che è già fuori: dove la posa mette una punta sotto una grata o
			# dentro un muro sottile, esce dalla parte giusta e non da quella più vicina)
			pt[i] = _fuori(pt[i], lerpf(raggio_radice, raggio_punta, float(i) / n), forme, pt[i - 1] if giro == 0 and partenza_sul_tratto else prima[i], false, i)
	return pt


## Le forme di [param forme] la cui scatola (allargata del raggio) tocca quella dei punti [param pt].
func _vicine(pt: PackedVector3Array, forme: Array) -> Array:
	if forme.is_empty():
		return forme
	var bb := AABB(pt[0], Vector3.ZERO)
	for q in pt:
		bb = bb.expand(q)
	var out := []
	for fo in forme:
		if (fo[3] as AABB).intersects(bb):
			out.append(fo)
	return out


## Vero se la posa [param tg] è a meno di 1 cm, punto per punto, da [param prima].
func _quasi_ferma(tg: PackedVector3Array, prima: PackedVector3Array) -> bool:
	if prima.size() != tg.size():
		return false
	for i in tg.size():
		if prima[i].distance_squared_to(tg[i]) > 1e-4:
			return false
	return true


## Le ossa di una catena dai suoi punti [param x] (col peso [param w], fra la posa e i punti).
func _scrivi_ossa(sk: Skeleton3D, sg: Transform3D, catena: PackedInt32Array, n: int, g: Array[Transform3D],
		tg: PackedVector3Array, x: PackedVector3Array, w: float, forme: Array) -> void:
	# i punti come escono: fra la posa e i punti simulati (col peso); i punti non passano il mondo (scivolano)
	var xo := PackedVector3Array()
	xo.resize(n + 1)
	xo[0] = tg[0]
	# (anche la posa, dove entra nel mondo, ne esce piano con la dissolvenza: niente scatto all'inizio)
	for i in range(1, n + 1):
		var posa := tg[i]
		if w < 1.0:
			posa = posa.lerp(_fuori(posa, lerpf(raggio_radice, raggio_punta, float(i) / n), forme, Vector3.INF, false, i if not forme.is_empty() else -1), w)
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


## I bersagli della molla: la posa fuori dal mondo, punto per punto (la radice resta dov'è); e dove un tratto della posa
## passa attraverso una forma bassa (il bordo: nella posa affacciata alcuni tentacoli ci passano sotto, a filo del
## pavimento) i suoi due capi salgono sopra la forma, così la molla porta il tentacolo sul bordo invece che dentro.
func _bersagli(tg: PackedVector3Array, n: int, forme: Array) -> PackedVector3Array:
	var out := tg.duplicate()
	# trattenuti nella fossa (mentre lei sale): i punti della posa sotto il pavimento fuori dalla fossa si cercano dentro
	# la fossa, alla stessa quota; avvicinandosi al pavimento (negli ultimi 50 cm) tornano piano al loro posto
	if _trattieni_k > 0.0 and fossa_pianta.size() >= 3:
		if _fossa_dentro.is_empty():
			var ins := Geometry2D.offset_polygon(fossa_pianta, -(VICINO * 0.5 + 0.05))
			_fossa_dentro = ins[0] if not ins.is_empty() else fossa_pianta
		for i in range(1, n + 1):
			var q := out[i]
			var sotto := (trattieni_y if trattieni_y > -INF else pavimento_y) - q.y
			var q2 := Vector2(q.x, q.z)
			if sotto <= 0.0 or Geometry2D.is_point_in_polygon(q2, _fossa_dentro):
				continue
			var c := q2
			var dm := INF
			for j in _fossa_dentro.size():
				var e := Geometry2D.get_closest_point_to_segment(q2, _fossa_dentro[j], _fossa_dentro[(j + 1) % _fossa_dentro.size()])
				if e.distance_squared_to(q2) < dm:
					dm = e.distance_squared_to(q2)
					c = e
			var k := clampf(sotto / 0.5, 0.0, 1.0) * _trattieni_k
			out[i] = Vector3(lerpf(q.x, c.x, k), q.y, lerpf(q.z, c.y, k))
	for i in range(1, n + 1):
		out[i] = _fuori(out[i], lerpf(raggio_radice, raggio_punta, float(i) / n), forme, Vector3.INF, true, i)
	for i in range(1, n + 1):
		for fo in forme:
			var su: int = fo[2]
			if su < 0:
				continue
			var cima: Plane = fo[0][su]
			if not _tratto_dentro(out[i - 1], out[i], fo[0], 0.0):
				continue
			var y := cima.d / cima.normal.y      # la quota della cima (normale in su: y = d)
			if i - 1 > 0:
				out[i - 1].y = maxf(out[i - 1].y, y + _sup(Vector3.UP, i - 1))
			out[i].y = maxf(out[i].y, y + _sup(Vector3.UP, i))
	return out


## Vero se il tratto da [param a] a [param b] passa dentro la forma convessa (piani [param piani]) allargata di [param r].
func _tratto_dentro(a: Vector3, b: Vector3, piani: Array, r: float) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	for pl: Plane in piani:
		var da := pl.distance_to(a) - r
		var db := pl.distance_to(b) - r
		if da >= 0.0 and db >= 0.0:
			return false
		if da < 0.0 and db < 0.0:
			continue
		var tc := da / (da - db)
		if da >= 0.0:
			t0 = maxf(t0, tc)
		else:
			t1 = minf(t1, tc)
		if t0 >= t1:
			return false
	return t0 < t1


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
	# la faccia di sopra, se c'è (orizzontale): da lì si esce dalle forme basse, come il bordo
	var sopra := -1
	if bb.size.y < 0.6:                    # solo le forme basse (il bordo), non le pareti alte della fossa
		for i in piani.size():
			if piani[i].normal.y > 0.99:
				sopra = i
	# (la scatola allargata di VICINO, per cercare le forme vicine, e di 8 e 13 cm per i punti con la pelle più sottile)
	_forme.append([piani, bb, sopra, bb.grow(VICINO), bb.grow(0.08), bb.grow(0.13)])
	_griglia_ok = false


## Toglie tutte le forme del mondo (per esempio quando lei cambia posto, nell'inseguimento).
func togli_forme_mondo() -> void:
	_forme.clear()
	_griglia_ok = false
	for k in _bers.size():
		_bers[k] = PackedVector3Array()
		_bers_posa[k] = PackedVector3Array()


## Aggiunge una forma convessa già fatta: i suoi piani (verso fuori) e la sua scatola, nel mondo (i piani si fanno
## prima, per esempio in un generatore: farli dai punti costa).
func aggiungi_piani(piani: Array[Plane], bb: AABB) -> void:
	if piani.size() < 4:
		return
	var sopra := -1
	if bb.size.y < 0.6:
		for i in piani.size():
			if piani[i].normal.y > 0.99:
				sopra = i
	_forme.append([piani, bb, sopra, bb.grow(VICINO), bb.grow(0.08), bb.grow(0.13)])
	_griglia_ok = false


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


## La morbidezza sullo scheletro della medusa [param medusa] (quella che c'è, o una nuova, in fondo ai modificatori).
static func su(medusa: Node) -> MorbidezzaLei:
	var sks := medusa.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return null
	var sk := sks[0] as Skeleton3D
	for c in sk.get_children():
		if c is MorbidezzaLei:
			return c
	var m := MorbidezzaLei.new()
	m.name = "Morbidezza"
	sk.add_child(m)
	return m


## Il punto [param p] fuori dal mondo (a [param r] da tutto): il pavimento (lastra con la cima a [member pavimento_y]
## fuori da [member buco_pavimento]) e le forme. Si spinge fuori dalla faccia da cui è entrato (dov'era, [param da]:
## così da una parete sottile non esce dall'altra parte), o se non si sa dalla più vicina: continuo, e il punto
## scivola. Nei [member tunnel] resta dentro il tubo, e alla bocca le forme non contano.
func _fuori(p: Vector3, r: float, forme: Array, da := Vector3.INF, alto := false, ip := -1) -> Vector3:
	# (con [param ip], il punto della catena che si muove: la pelle vera, contro ogni faccia la sua misura lì)
	var rmax := _smax[ip] if ip >= 0 else r
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
			if rho > R - rmax:
				p = a + asse * lungo + radiale / rho * maxf(R - rmax, 0.0)
			return p
		if lungo > -rmax and rho < R - rmax:
			return p
	var r_su := _ssu[ip] if ip >= 0 else r
	var scatola := (4 if rmax <= 0.08 else (5 if rmax <= 0.13 else 3)) if ip >= 0 else 3
	for giro in 2:
		var mosso := false
		if p.y < pavimento_y + r_su and p.y > pavimento_y - 1.0 and not buco_pavimento.has_point(Vector2(p.x, p.z)):
			p.y = pavimento_y + r_su
			mosso = true
		for fo in (_forme_in(p, forme) if ip >= 0 and not forme.is_empty() else forme):
			var meglio: Plane
			var dm := -INF
			var rf := r
			if ip >= 0:
				# (la scatola della forma allargata almeno della misura più grande di questo punto)
				if not (fo[scatola] as AABB).has_point(p):
					continue
				# la faccia da cui è più fuori, ognuna con la misura della pelle verso di lei (_sup, scritta qui: è il
				# pezzo che gira di più); una faccia da cui è fuori basta, e si smette
				var gm := -INF
				var fuori := false
				var a1 := _s1a[ip]
				var b1 := _s1b[ip]
				var a2 := _s2a[ip]
				var b2 := _s2b[ip]
				for pl: Plane in fo[0]:
					var d := pl.distance_to(p)
					if d >= rmax:
						fuori = true
						break
					var nn := pl.normal
					var u1 := nn.dot(a1)
					var v1 := nn.dot(b1)
					var u2 := nn.dot(a2)
					var v2 := nn.dot(b2)
					var rp := sqrt(maxf(u1 * u1 + v1 * v1, u2 * u2 + v2 * v2)) + MARGINE + (SOPRA if nn.y > 0.7 else 0.0)
					var gg := d - rp
					if gg >= 0.0:
						fuori = true
						break
					if gg > gm:
						gm = gg
						meglio = pl
						rf = rp
				if fuori:
					continue
				dm = meglio.distance_to(p)
			else:
				if not (fo[3] as AABB).has_point(p):
					continue
				for pl: Plane in fo[0]:
					var d := pl.distance_to(p)
					if d > dm:
						dm = d
						meglio = pl
				if dm >= r:
					continue
			# dalla faccia da cui veniva (quella che dov'era aveva più lontana), se dov'era stava fuori
			if da != Vector3.INF:
				var gprima := -INF
				var scelta: Plane
				var rs := rf
				for pl: Plane in fo[0]:
					var rp := _sup(pl.normal, ip) if ip >= 0 else r
					var g0 := pl.distance_to(da) - rp
					if g0 > gprima:
						gprima = g0
						scelta = pl
						rs = rp
				if gprima >= -1e-4:
					meglio = scelta
					rf = rs
					dm = meglio.distance_to(p)
			if alto:
				var cima := _da_sopra(fo, p, meglio)
				if cima != meglio:
					meglio = cima
					rf = _sup(meglio.normal, ip) if ip >= 0 else r
					dm = meglio.distance_to(p)
			p += meglio.normal * (rf - dm)
			mosso = true
		if not mosso:
			break
	return p


## Le forme basse (il bordo, alto 45 cm) si lasciano da sopra: un punto a meno di mezzo metro sotto la cima esce in
## alto, così un tentacolo che nella posa passa sotto il bordo ci si appoggia sopra (spingendo di lato resterebbe
## a cavallo, da tutte e due le parti). Vale per i bersagli della molla e per la partenza, non per i punti: la molla
## li porta su piano, senza salti.
func _da_sopra(fo: Array, p: Vector3, meglio: Plane) -> Plane:
	var i: int = fo[2]
	if i < 0:
		return meglio
	var cima: Plane = fo[0][i]
	if cima.distance_to(p) > -0.5:
		return cima
	return meglio


## I tratti fuori dalle forme: dove un tratto entra in una forma (allargata del raggio: il tratto tagliato contro le
## facce) il suo punto di mezzo lì dentro esce dalla faccia più vicina, e lo spostamento va ai due capi secondo dove
## sta (alla radice, che segue la posa, no). Così anche lo spigolo del bordo non si taglia.
func _tratti_fuori(pt: PackedVector3Array, n: int, forme: Array, corr: PackedVector3Array) -> void:
	if forme.is_empty():
		return
	for i in range(1, n + 1):
		# (la pelle del tratto: la sezione dell'osso i - 1, contro ogni faccia la sua misura in quella direzione)
		var sa1 := _s1a[i]
		var sb1 := _s1b[i]
		var rmax := maxf(sa1.length(), sb1.length()) + MARGINE + SOPRA
		for fo in _forme_in((pt[i - 1] + pt[i]) * 0.5, forme):
			var a := pt[i - 1]
			var b := pt[i]
			var bb := AABB(a, Vector3.ZERO).expand(b).grow(rmax)
			if not (fo[1] as AABB).intersects(bb):
				continue
			# (prima con la misura più grande: se così non tocca, la pelle non tocca)
			if not _tratto_dentro(a, b, fo[0], rmax):
				continue
			var t0 := 0.0
			var t1 := 1.0
			for pl: Plane in fo[0]:
				var nn := pl.normal
				var u := nn.dot(sa1)
				var w0 := nn.dot(sb1)
				var r := sqrt(u * u + w0 * w0) + MARGINE + (SOPRA if nn.y > 0.7 else 0.0)
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
			if t0 >= t1:
				continue
			var t := clampf((t0 + t1) * 0.5, 0.05, 0.95)
			var m := a.lerp(b, t)
			# (tutti e due i capi dentro, a meno del raggio: ci pensano i punti, a meno che il mezzo non sia più dentro
			# di tutti e due, cioè il tratto taglia lo spigolo, come la punta fra la cima del bordo e la fossa)
			if t0 <= 0.0 and t1 >= 1.0:
				t = 0.5
				m = a.lerp(b, 0.5)
				var dma := -INF
				var dmb := -INF
				var dmm := -INF
				for pl: Plane in fo[0]:
					var r := _sup_tratto(pl.normal, i)
					dma = maxf(dma, pl.distance_to(a) - r)
					dmb = maxf(dmb, pl.distance_to(b) - r)
					dmm = maxf(dmm, pl.distance_to(m) - r)
				if dmm > minf(dma, dmb) - 0.005:
					continue
			var nel_tubo := false
			for tu in tunnel:
				if Geometry3D.get_closest_point_to_segment(m, tu[0], tu[1]).distance_to(m) < float(tu[2]):
					nel_tubo = true
			if nel_tubo:
				continue
			var meglio: Plane
			var gm := -INF
			for pl: Plane in fo[0]:
				var gg := pl.distance_to(m) - _sup_tratto(pl.normal, i)
				if gg > gm:
					gm = gg
					meglio = pl
			var c := meglio.normal * -gm
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
