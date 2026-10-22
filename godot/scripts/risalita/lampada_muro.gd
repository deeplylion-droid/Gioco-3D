class_name LampadaMuro
## La lampada d'emergenza rossa (il modello Meshy del fiume lento) montata a muro: la barra della sua staffa,
## sul retro del modello, poggia su una piastra fissata al muro. Prima il centro del modello stava a 5-15 cm
## dal muro e la staffa ci entrava fino a 16 cm (controllo di posizionamento severo del 22 ottobre).

const MODELLO := "res://assets/fiume_lento/lampada_emergenza.glb"
## La barra della staffa sul retro del modello (coordinate del modello, misurate sul GLB): larga 22 cm, da
## y -0,071 a -0,03, il retro a z 0,21. Il davanti col vetro guarda verso -Z.
const BARRA: Array[Vector3] = [Vector3(-0.11, -0.071, 0.21), Vector3(0.11, -0.071, 0.21),
		Vector3(-0.11, -0.03, 0.21), Vector3(0.11, -0.03, 0.21)]
const CENTRO_BARRA := Vector3(0.0, -0.05, 0.21)
const PIASTRA := Vector3(0.28, 0.1, 0.012)


## Mette la lampada in [param padre]: [param muro] è un punto della faccia del muro all'altezza della
## lampada, [param verso] dove guarda il vetro (in fuori dal muro, un po' in giù), tutto nelle coordinate di
## [param padre]. Ritorna la lampada; la piastra è sua figlia (un oggetto solo).
static func monta(padre: Node3D, muro: Vector3, verso: Vector3) -> Node3D:
	var n := Vector3(verso.x, 0.0, verso.z).normalized()   # dal muro verso la stanza
	var b := Basis.looking_at(verso.normalized(), Vector3.UP)
	# quanto la barra va verso il muro, per la lampada inclinata: la si appoggia alla piastra
	var verso_muro := 0.0
	for p in BARRA:
		verso_muro = maxf(verso_muro, (b * p).dot(-n))
	var pos := muro + n * (verso_muro + PIASTRA.z + 0.001)
	var l := (load(MODELLO) as PackedScene).instantiate() as Node3D
	l.transform = Transform3D(b, pos)
	padre.add_child(l)
	# la piastra sul muro, dietro il centro della barra
	var c := pos + b * CENTRO_BARRA
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
