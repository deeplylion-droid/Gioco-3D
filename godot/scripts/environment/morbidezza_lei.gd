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
## - la collisione col mondo: ogni punto non entra nei muri, nel bordo, nel fondo (raggi dal punto prima, sullo strato
##   WORLD; [member esclusi] per i corpi da non contare, come il coperchio della fossa);
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
## Il raggio del tentacolo per le collisioni, alla radice e alla punta (m).
@export var raggio_radice := 0.07
@export var raggio_punta := 0.035
## La campana: pulsazione (forma campana_contrai, ampiezza e battiti al secondo) e deformazione col movimento.
@export var pulsa := 0.18
@export var pulsa_hz := 0.9
@export var allunga := 0.05
@export var schiaccia := 0.035
## Collisioni da non contare (per esempio il coperchio invisibile della fossa).
var esclusi: Array[RID] = []
## Le vasche (WaterTank) il cui pelo conta; vuoto: quelle entro 8 m, cercate all'inizio.
var vasche: Array = []
## Un'acqua in più, data da chi la conosce (la fossa dei bimbi): la pianta (x, z) e il pelo.
var acqua_pianta := Rect2()
var acqua_pelo := -INF
## Quanto è durato l'ultimo calcolo (microsecondi), per misurarlo.
var durata_usec := 0

const PASSO_MAX := 1.0 / 60.0

var _catene: Array[PackedInt32Array] = []
var _x: Array[PackedVector3Array] = []     # i punti (mondo): le teste delle ossa e la punta
var _v: Array[PackedVector3Array] = []     # le loro velocità
var _fase: PackedFloat32Array = []
var _pronte := false
var _ultimo_usec := 0
var _t := 0.0
var _verso := 1.0                          # 1: si accende, -1: si spegne
var _peso := 0.0                            # quanto ora (dissolvenza)
var _radici_prima := PackedVector3Array()
var _campana := -1
var _campana_v := Vector3.ZERO
var _campana_p := Vector3.ZERO
var _campana_a := 0.0                      # accelerazione lungo l'asse del corpo, smorzata
var _mesh_campana: Array = []              # [MeshInstance3D, indice contrai, indice schiaccia]
var _messo := {}                           # [mesh, indice] -> quanto ho aggiunto alla forma l'ultima volta
var _raggio := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_raggio.collision_mask = Layers.WORLD
	_raggio.collide_with_areas = false
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
	var ora := Time.get_ticks_usec()
	var dt := clampf((ora - _ultimo_usec) / 1e6, 0.0, 0.1) if _ultimo_usec > 0 else 0.0
	_ultimo_usec = ora
	_peso = clampf(_peso + _verso * dt / maxf(dissolvenza, 0.01), 0.0, 1.0)
	var w := _peso * quanto
	if w <= 0.0:
		# spento: la posa resta quella che arriva; le forme della campana tornano dove le ha messe chi anima
		_togli_forme()
		_pronte = false
		return
	var t0 := Time.get_ticks_usec()
	if _catene.is_empty():
		_catene_di(sk)
	var sg := sk.global_transform
	var spazio := get_world_3d().direct_space_state
	_raggio.exclude = esclusi
	# a passi di al più 1/60 s (la fisica dei punti resta stabile anche a pochi fotogrammi al secondo)
	var passi := maxi(1, ceili(dt / PASSO_MAX))
	var h := dt / passi
	_t += dt
	if not _pronte or _radici_prima.size() != _catene.size():
		_x.clear()
		_v.clear()
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
		tg.append(tg[n - 1] + (tg[n - 1] - tg[n - 2]))
		var lung := PackedFloat32Array()
		lung.resize(n + 1)
		for i in range(1, n + 1):
			lung[i] = tg[i].distance_to(tg[i - 1])
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
		var x: PackedVector3Array = _x[k]
		var v: PackedVector3Array = _v[k]
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
				var vi := v[i] + a * h
				pred[i] = x[i] + vi * h
			# la catena: ogni punto alla sua distanza dal punto prima (dalla radice), e fuori dai muri
			var corr := PackedVector3Array()
			corr.resize(n + 2)
			for i in range(1, n + 1):
				var f := float(i) / n
				var voluto := pred[i - 1] + (pred[i] - pred[i - 1]).normalized() * lung[i]
				# non troppo lontano dalla posa (nei movimenti velocissimi del tuffo)
				var lim := distacco_massimo * f
				var scarto := voluto - tg[i]
				if scarto.length() > lim:
					voluto = tg[i] + scarto.normalized() * lim
					voluto = pred[i - 1] + (voluto - pred[i - 1]).normalized() * lung[i]
				if spazio:
					var r := lerpf(raggio_radice, raggio_punta, f)
					var dir := voluto - pred[i - 1]
					_raggio.from = pred[i - 1]
					_raggio.to = voluto + dir.normalized() * r
					var colpo := spazio.intersect_ray(_raggio)
					if not colpo.is_empty():
						# si appoggia alla superficie (il tratto si accorcia: il tentacolo si piega lì)
						voluto = (colpo["position"] as Vector3) + (colpo["normal"] as Vector3) * r
				corr[i] = voluto - pred[i]
				pred[i] = voluto
			for i in range(1, n + 1):
				var nv := (pred[i] - x[i]) / h
				if i < n:
					nv -= corr[i + 1] / h * resa
				v[i] = nv
				x[i] = pred[i]
			x[0] = tg[0]
		_x[k] = x
		_v[k] = v
		# le ossa: ogni osso gira dalla direzione della posa a quella dei punti (col peso), dal padre già girato
		var padre := sk.get_bone_parent(catena[0])
		var padre_mondo := sg * sk.get_bone_global_pose(padre) if padre >= 0 else sg
		var testa := tg[0]
		for i in n:
			var d0 := tg[i + 1] - tg[i]
			var punto := tg[i + 1].lerp(x[i + 1], w)
			var d1 := punto - testa
			var giro := Quaternion.IDENTITY
			if d0.length() > 1e-5 and d1.length() > 1e-5:
				giro = Quaternion(d0.normalized(), d1.normalized())
			var nuovo := Transform3D(Basis(giro) * g[i].basis, testa)
			var locale := padre_mondo.affine_inverse() * nuovo
			sk.set_bone_pose_position(catena[i], locale.origin)
			sk.set_bone_pose_rotation(catena[i], locale.basis.get_rotation_quaternion())
			padre_mondo = nuovo
			testa = testa + d1.normalized() * d0.length()
	_pronte = true
	_campana_forme(sk, sg, dt, w)
	durata_usec = Time.get_ticks_usec() - t0


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
