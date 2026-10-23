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
var _raggio := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_raggio.collision_mask = Layers.WORLD
	_raggio.collide_with_areas = false
	_raggio.hit_back_faces = false   # solo entrando in una superficie (da un punto che la tocca si esce)
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
		# la punta: lungo l'asse dell'ultimo osso (Y), lunga come il tratto prima
		tg.append(tg[n - 1] + g[n - 1].basis.y.normalized() * tg[n - 1].distance_to(tg[n - 2]))
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
				if spazio:
					var r := lerpf(raggio_radice, raggio_punta, f)
					voluto = _scivola(spazio, x[i], voluto, r)
					# dall'altra parte di una superficie rispetto alla posa (ci è finito dietro alla posa, che a tratti
					# la passa): torna sulla superficie, dalla parte della posa
					_raggio.from = tg[i]
					_raggio.to = voluto
					var dietro := spazio.intersect_ray(_raggio)
					if not dietro.is_empty():
						voluto = (dietro["position"] as Vector3) + (dietro["normal"] as Vector3) * minf(r, (dietro["position"] as Vector3).distance_to(tg[i]))
					# di nuovo alla sua distanza dal punto prima, se di lì ci arriva senza passare il mondo
					var giusto := pred[i - 1] + (voluto - pred[i - 1]).normalized() * lung[i]
					if not _colpo(spazio, x[i], giusto, r) and not _colpo(spazio, tg[i], giusto, 0.0):
						voluto = giusto
				corr[i] = voluto - pred[i]
				pred[i] = voluto
			# all'indietro: dove un punto è rimasto fermo contro il mondo, quelli prima gli vanno incontro (se possono
			# senza passare il mondo), così il tentacolo non si allunga in un tratto solo
			if spazio:
				for i in range(n - 1, 0, -1):
					var d := pred[i] - pred[i + 1]
					var l := d.length()
					if l > lung[i + 1] * 1.15:
						var verso := pred[i + 1] + d / l * lung[i + 1] * 1.15
						var r := lerpf(raggio_radice, raggio_punta, float(i) / n)
						if not _colpo(spazio, pred[i], verso, r) and not _colpo(spazio, tg[i], verso, 0.0):
							corr[i] += verso - pred[i]
							pred[i] = verso
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
		for i in range(1, n + 1):
			xo[i] = tg[i].lerp(x[i], w)
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


## Il punto che va da [param da] (dov'era, fuori dal mondo) a [param a]: se tocca una superficie scivola sul suo
## piano, a [param r] da lei (come un corpo che striscia, senza scatti); se poi tocca ancora si ferma lì.
func _scivola(spazio: PhysicsDirectSpaceState3D, da: Vector3, a: Vector3, r: float) -> Vector3:
	var d := a - da
	var ld := d.length()
	if ld < 1e-5:
		return a
	# dal punto un po' indietro: una superficie che già tocca conta (all'indietro le superfici si vedono di schiena)
	_raggio.from = da - d / ld * r * 0.5
	_raggio.to = a + d / ld * r
	var c := spazio.intersect_ray(_raggio)
	if c.is_empty():
		return a
	var nrm := c["normal"] as Vector3
	var piano := (c["position"] as Vector3) + nrm * r
	var su := a - nrm * (a - piano).dot(nrm)
	# il secondo tratto, sul piano
	var d2 := su - da
	var l2 := d2.length()
	if l2 < 1e-5:
		return da
	_raggio.to = su + d2 / l2 * r
	var c2 := spazio.intersect_ray(_raggio)
	if c2.is_empty():
		return su
	return da + d2 / l2 * clampf(da.distance_to(c2["position"]) - r, 0.0, l2)


## Vero se andando da [param a] a [param b] (e [param r] oltre) si entra in una superficie.
func _colpo(spazio: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, r: float) -> bool:
	var d := b - a
	var l := d.length()
	if l < 1e-5:
		return false
	_raggio.from = a
	_raggio.to = b + d / l * r
	return not spazio.intersect_ray(_raggio).is_empty()


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
