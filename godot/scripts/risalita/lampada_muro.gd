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
## poggia direttamente su [param muro] (su un palo, col suo collare).
static func monta(padre: Node3D, muro: Vector3, verso: Vector3, piastra := true) -> Node3D:
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
