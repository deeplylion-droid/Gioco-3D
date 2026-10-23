class_name TentacoliControIMuri
extends SkeletonModifier3D
## I tentacoli della medusa non entrano nei muri: sopra la posa dell'animazione (la "affacciata" è fatta
## per il bordo della vasca centrale, e nella fossa dei bimbi i tentacoli più larghi del pozzo passavano
## dentro pareti e bordi), lungo ogni tratto del tentacolo, dalla radice alla punta, si controllano quattro
## sfere grosse quanto il nastro. Se una entra nella collisione del mondo, il tratto si sposta quanto basta per
## portarla fuori, a contatto con la superficie (per la via più corta che dà la fisica), tenendo la sua lunghezza. Il tratto dopo riparte dalla direzione
## dell'animazione: il tentacolo si appoggia sul bordo e ricade lungo la faccia esterna come nella posa, solo
## fuori dal muro. Dove non tocca niente la posa resta quella dell'animazione.
## Le pieghe si cercano con la fisica ogni [member ogni] fotogrammi (la posa "affacciata" cambia appena: solo
## il respiro) e subito se lei si sposta; negli altri fotogrammi si rimettono quelle trovate.
## Le ossa dei tentacoli sono "tentacolo_NN_MM" (medusa.glb): ogni catena si trova dai padri.

## Il raggio del tentacolo alla radice e alla punta (m): la sfera che si controlla lungo ogni tratto (i nastri
## sono larghi fino a 12-16 cm e attorcigliati).
@export var raggio_radice := 0.15
@export var raggio_punta := 0.08
## Quanto resta staccato dalla superficie dopo la spinta (m).
@export var stacco := 0.04
## Ogni quanti fotogrammi si cercano di nuovo le pieghe.
@export var ogni := 6
## Le collisioni da non contare (per esempio il coperchio invisibile della fossa).
var esclusi: Array[RID] = []
## Quanto è durato l'ultimo calcolo (microsecondi), per misurarlo.
var durata_usec := 0

var _catene: Array[PackedInt32Array] = []
# per ogni catena, per ogni tratto: la rotazione dalla direzione dell'animazione a quella piegata (vuoto: dritta)
var _giri: Array = []
var _conta := 0
var _dove := Transform3D()
var _sfera := SphereShape3D.new()
var _q := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	_q.shape = _sfera
	_q.collision_mask = Layers.WORLD
	_q.collide_with_areas = false


func _catene_di(sk: Skeleton3D) -> void:
	_catene.clear()
	for b in sk.get_bone_count():
		if not sk.get_bone_name(b).begins_with("tentacolo_"):
			continue
		var p := sk.get_bone_parent(b)
		if p >= 0 and sk.get_bone_name(p).begins_with("tentacolo_"):
			continue
		# la radice: si scende di figlio in figlio finché sono del tentacolo
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
	_giri.resize(_catene.size())
	_giri.fill([])


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or not is_inside_tree():
		return
	if _catene.is_empty():
		_catene_di(sk)
	var t0 := Time.get_ticks_usec()
	var sg := sk.global_transform
	# di nuovo con la fisica ogni tanto, o subito se lei si è spostata (sbuca, scivola, il tuffo)
	var cerca := _conta <= 0 or sg.origin.distance_to(_dove.origin) > 0.005 or not sg.basis.is_equal_approx(_dove.basis)
	var spazio: PhysicsDirectSpaceState3D = null
	if cerca:
		spazio = get_world_3d().direct_space_state
		if spazio == null:
			return
		_q.exclude = esclusi
		_conta = maxi(ogni, 1)
		_dove = sg
	_conta -= 1
	for k in _catene.size():
		var catena: PackedInt32Array = _catene[k]
		if not cerca and (_giri[k] as Array).is_empty():
			continue
		var n := catena.size()
		# le pose del mondo come le lascia l'animazione, e i punti: le teste delle ossa e la punta in fondo
		var g: Array[Transform3D] = []
		var p := PackedVector3Array()
		for b in catena:
			var t := sg * sk.get_bone_global_pose(b)
			g.append(t)
			p.append(t.origin)
		p.append(p[n - 1] + (p[n - 1] - p[n - 2]))
		var nuovi := PackedVector3Array([p[0]])
		var giri: Array = _giri[k]
		if cerca:
			giri = []
			var piegato := false
			for i in n:
				var d0 := p[i + 1] - p[i]
				var lungo := d0.length()
				var d := d0
				if lungo > 1e-5:
					_sfera.radius = lerpf(raggio_radice, raggio_punta, float(i) / maxf(n - 1, 1))
					for prova in 12:
						# il punto del tratto più dentro il muro e quanto va spostato (riportato alla fine del tratto)
						var spinta := Vector3.ZERO
						for f in [1.0, 0.75, 0.5, 0.25]:
							var via := _uscita(spazio, nuovi[i] + d * f)
							if via.length() / f > spinta.length():
								spinta = via / f
						if spinta == Vector3.ZERO:
							break
						piegato = true
						var fine := nuovi[i] + d + spinta + spinta.normalized() * stacco
						d = (fine - nuovi[i]).normalized() * lungo
				giri.append(Quaternion(d0.normalized(), d.normalized()) if lungo > 1e-5 else Quaternion.IDENTITY)
				nuovi.append(nuovi[i] + d)
			if not piegato:
				giri = []
			_giri[k] = giri
			if giri.is_empty():
				continue
		else:
			for i in n:
				nuovi.append(nuovi[i] + (giri[i] as Quaternion) * (p[i + 1] - p[i]))
		# le pose locali dal padre (già piegato): impostare le globali una per volta usa il padre di prima
		var padre := sk.get_bone_parent(catena[0])
		var padre_mondo := sg * sk.get_bone_global_pose(padre) if padre >= 0 else sg
		for i in n:
			var nuovo := Transform3D(Basis(giri[i] as Quaternion) * g[i].basis, nuovi[i])
			var locale := padre_mondo.affine_inverse() * nuovo
			sk.set_bone_pose_position(catena[i], locale.origin)
			sk.set_bone_pose_rotation(catena[i], locale.basis.get_rotation_quaternion())
			padre_mondo = nuovo
	durata_usec = Time.get_ticks_usec() - t0


## Se la sfera del tentacolo (raggio in _sfera) centrata in [param q] entra nella collisione del mondo, lo
## spostamento più corto che la porta a toccare la superficie (dalla fisica); se è fuori, zero.
func _uscita(spazio: PhysicsDirectSpaceState3D, q: Vector3) -> Vector3:
	_q.transform = Transform3D(Basis(), q)
	var punti := spazio.collide_shape(_q, 8)
	var via := Vector3.ZERO
	# a coppie: il punto della sfera più dentro e quello della superficie
	for k in range(0, punti.size() - 1, 2):
		var v: Vector3 = punti[k + 1] - punti[k]
		if v.length() > via.length():
			via = v
	return via
