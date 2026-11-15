class_name ScaricoPozza
extends MeshInstance3D
## Lo scarico di fondo di una pozza della stanza delle pozze colorate (0.4.0, decisione del coordinatore del 15
## novembre): una griglia tonda scura sul fondo, da cui passa lei (il corpo non sta in 1 m × 0,7 m d'acqua). Un anello
## di metallo scuro, il buco nero sotto e le sbarre parallele, tutto basso (1,4 cm) e appoggiato al fondo: l'origine è
## al centro, sul fondo. Niente scritte. Lo mette EnigmaPozze ([member EnigmaPozze.scarichi]), uno per pozza, figlio
## della pozza (si muove con lei); il modello è uno solo, fatto qui da codice e condiviso da tutti gli scarichi.

## Il diametro della griglia (m): il buco; l'anello sporge di [constant ANELLO] tutto intorno.
const DIAMETRO := 0.40
const ANELLO := 0.025
## Le altezze: l'anello, il buco (appena sopra, così non si sovrappongono) e la cima delle sbarre.
const ALTO_ANELLO := 0.008
const ALTO_BUCO := 0.0085
const ALTO_SBARRE := 0.014
## Le sbarre: quante, quanto larghe.
const SBARRE := 9
const LARGA := 0.014

static var _mesh: ArrayMesh


func _init() -> void:
	name = "Scarico"
	mesh = modello()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Il modello, fatto una volta: tre superfici (l'anello, il buco, le sbarre), dalle mesh primitive di Godot.
static func modello() -> ArrayMesh:
	if _mesh:
		return _mesh
	var r := DIAMETRO * 0.5
	_mesh = ArrayMesh.new()
	# l'anello: un disco basso, largo quanto il buco più il bordo
	_aggiungi(_cilindro(r + ANELLO, 0.0, ALTO_ANELLO), _materiale(Color(0.13, 0.13, 0.14), 0.45, 0.6))
	# il buco: nero, appena sopra l'anello
	_aggiungi(_cilindro(r, ALTO_ANELLO, ALTO_BUCO), _materiale(Color(0.012, 0.012, 0.014), 0.95, 0.0))
	# le sbarre, parallele, appoggiate sul buco e fino dentro l'anello
	var st := SurfaceTool.new()
	var passo := DIAMETRO / float(SBARRE + 1)
	for i in SBARRE:
		var x := -r + passo * (i + 1)
		var lunga := (sqrt(maxf(r * r - x * x, 0.0)) + ANELLO * 0.5) * 2.0
		var b := BoxMesh.new()
		b.size = Vector3(LARGA, ALTO_SBARRE - ALTO_BUCO, lunga)
		st.append_from(b, 0, Transform3D(Basis.IDENTITY, Vector3(x, (ALTO_BUCO + ALTO_SBARRE) * 0.5, 0.0)))
	_aggiungi(st, _materiale(Color(0.2, 0.2, 0.21), 0.4, 0.7))
	return _mesh


static func _aggiungi(st: SurfaceTool, mat: Material) -> void:
	st.set_material(mat)
	st.commit(_mesh)


static func _materiale(c: Color, ruvido: float, metallo: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = ruvido
	mat.metallic = metallo
	return mat


## Un cilindro senza il fondo (poggia sul fondo della pozza) di raggio [param r], da [param y0] a [param y1].
static func _cilindro(r: float, y0: float, y1: float) -> SurfaceTool:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = y1 - y0
	c.radial_segments = 40
	c.rings = 1
	c.cap_bottom = false
	var st := SurfaceTool.new()
	st.append_from(c, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, (y0 + y1) * 0.5, 0.0)))
	return st
