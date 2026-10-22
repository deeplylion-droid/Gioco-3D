class_name LampadaMuro
## La lampada d'emergenza rossa (il modello Meshy del fiume lento) montata a muro: la barra della sua staffa,
## sul retro del modello, poggia su una piastra fissata al muro. Prima il centro del modello stava a 5-15 cm
## dal muro e la staffa ci entrava fino a 16 cm (controllo di posizionamento severo del 22 ottobre).

const MODELLO := "res://assets/fiume_lento/lampada_emergenza.glb"
## Il davanti col vetro guarda verso -Z; sul retro (+Z) la barra della staffa, larga 22 cm.
const PIASTRA := Vector3(0.28, 0.1, 0.012)
## I vertici del modello (si leggono una volta).
static var _vertici := PackedVector3Array()


## Mette la lampada in [param padre]: [param muro] è un punto della faccia del muro all'altezza della
## lampada, [param verso] dove guarda il vetro (in fuori dal muro, un po' in giù), tutto nelle coordinate di
## [param padre]. Ritorna la lampada; la piastra è sua figlia (un oggetto solo). Senza [param piastra] la staffa
## poggia direttamente su [param muro]. Con [param raggio_palo] la lampada va su un palo verticale: [param muro] è
## sul suo asse, e il punto della lampada più vicino all'asse sta 1 mm fuori dal palo.
static func monta(padre: Node3D, muro: Vector3, verso: Vector3, piastra := true, raggio_palo := 0.0) -> Node3D:
	var n := Vector3(verso.x, 0.0, verso.z).normalized()   # dal muro verso la stanza
	var b := Basis.looking_at(verso.normalized(), Vector3.UP)
	var l := (load(MODELLO) as PackedScene).instantiate() as Node3D
	if _vertici.is_empty():
		for mi in l.find_children("*", "MeshInstance3D", true, false):
			_vertici.append_array((mi as MeshInstance3D).mesh.get_faces())
	# il punto del modello più verso il muro (con la lampada inclinata è uno spigolo della barra): lì si appoggia
	# alla piastra, 1 mm davanti; la piastra sta dietro quel punto
	var verso_muro := -INF
	for v in _vertici:
		verso_muro = maxf(verso_muro, (b * v).dot(-n))
	var c := Vector3.ZERO
	var k := 0
	for v in _vertici:
		if (b * v).dot(-n) > verso_muro - 0.01:
			c += b * v
			k += 1
	c /= maxf(k, 1)
	if raggio_palo > 0.0:
		# la staffa centrata sull'asse del palo, poi la lampada contro il palo. Il profilo di dietro della lampada vista
		# dall'alto: per ogni posizione di lato davanti al palo, il suo punto più arretrato, sugli spigoli dei triangoli
		# (un lato lungo della staffa passa davanti all'asse coi vertici lontani). Ogni posizione chiede alla lampada di
		# stare abbastanza avanti da restare fuori dal palo; la più esigente tocca, 1 mm fuori. Prima la staffa stava
		# 1 mm davanti al palo solo nel suo punto più arretrato, uno spigolo 8 cm di lato: la lampada restava a 5 cm
		var t := n.cross(Vector3.UP).normalized()
		var r := raggio_palo + 0.001
		var o := muro - t * c.dot(t)
		o.y = muro.y
		const N := 40
		var dietro := PackedFloat32Array()
		dietro.resize(N + 1)
		dietro.fill(INF)
		var avanti := -INF
		for i in range(0, _vertici.size(), 3):
			for e in 3:
				var p := b * _vertici[i + e] + o - muro
				var q := b * _vertici[i + (e + 1) % 3] + o - muro
				var lp := p.dot(t)
				var lq := q.dot(t)
				if absf(lp) < r:
					avanti = maxf(avanti, sqrt(r * r - lp * lp) - p.dot(n))
				if maxf(lp, lq) < -r or minf(lp, lq) > r or absf(lq - lp) < 1e-6:
					continue
				var j0 := maxi(0, ceili((minf(lp, lq) + r) / (2.0 * r) * N))
				var j1 := mini(N, floori((maxf(lp, lq) + r) / (2.0 * r) * N))
				for j in range(j0, j1 + 1):
					var f := (-r + 2.0 * r * j / N - lp) / (lq - lp)
					dietro[j] = minf(dietro[j], lerpf(p.dot(n), q.dot(n), f))
		for j in N + 1:
			if dietro[j] < INF:
				var lat := -r + 2.0 * r * j / N
				avanti = maxf(avanti, sqrt(maxf(r * r - lat * lat, 0.0)) - dietro[j])
		l.transform = Transform3D(b, o + n * avanti)
		padre.add_child(l)
		return l
	var pos := muro + n * (verso_muro + (PIASTRA.z if piastra else 0.0) + 0.001)
	l.transform = Transform3D(b, pos)
	padre.add_child(l)
	if not piastra:
		return l
	c += pos
	c += n * ((muro - c).dot(n) + PIASTRA.z * 0.5)
	var mi := MeshInstance3D.new()
	mi.name = "Piastra"
	var bm := BoxMesh.new()
	bm.size = PIASTRA
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.07, 0.05)
	m.metallic = 0.4
	m.roughness = 0.6
	mi.material_override = m
	l.add_child(mi)
	mi.transform = l.transform.affine_inverse() * Transform3D(Basis.looking_at(-n, Vector3.UP), c)
	return l
