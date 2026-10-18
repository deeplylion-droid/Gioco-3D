extends Node3D
## Scena di prova del movimento sugli scivoli (sala della torre, versione A): una piattaforma in
## alto, tre pezzi di scivolo spezzati che scendono nel vuoto e la piattaforma del fondo.
## - giallo: si parte dalla piattaforma, curva a sinistra, a fine pezzo il salto viene da sé;
## - rosso: lo si prende al volo (salto normale), curva a destra e finisce sul vuoto largo;
## - blu: troppo lontano per un salto normale, ci si arriva solo con la spinta del getto
##   (spruzzo tenuto verso il basso in aria); porta giù fino alla piattaforma del fondo.
## Sotto c'è il vuoto: cadendo si riparte dalla piattaforma in alto (checkpoint).
## Gli scivoli sono corpi statici nel gruppo "scivolo" (l'accordo con chi costruisce la sala):
## qui la forma è un canale a U costruito da una linea di punti (il fondo del canale).
## Il test è tests/test_scivoli.gd.

## Raggio del canale a U e angolo delle sponde (gradi dal fondo).
const RAGGIO := 1.1
const SPONDA := 84.0
## I pezzi: nome, colore e la linea del fondo (punti in metri, si scende verso -Z).
const PEZZI := [
	{"nome": "ScivoloGiallo", "colore": Color(0.95, 0.72, 0.1), "punti": [
		Vector3(0.0, 19.97, 1.0), Vector3(0.0, 19.8, -1.0), Vector3(0.0, 18.6, -4.5), Vector3(-1.2, 16.6, -9.5),
		Vector3(-3.2, 15.0, -14.0), Vector3(-4.2, 14.4, -17.0), Vector3(-4.6, 14.55, -18.6)]},
	{"nome": "ScivoloRosso", "colore": Color(0.85, 0.16, 0.12), "punti": [
		Vector3(-5.9, 12.0, -22.0), Vector3(-6.5, 10.8, -26.5), Vector3(-6.6, 9.6, -30.5),
		Vector3(-5.4, 8.2, -34.5), Vector3(-2.8, 7.0, -38.0), Vector3(0.2, 6.4, -40.3), Vector3(1.8, 6.55, -41.3)]},
	{"nome": "ScivoloBlu", "colore": Color(0.15, 0.4, 0.9), "punti": [
		Vector3(13.0, 3.9, -47.1), Vector3(17.0, 3.5, -49.1), Vector3(21.0, 2.8, -51.3),
		Vector3(24.6, 2.0, -54.3), Vector3(26.8, 1.2, -58.0), Vector3(27.6, 0.6, -62.0),
		Vector3(27.7, 0.5, -64.0)]},
]
## Il fondo: la piattaforma dove finisce lo scivolo blu.
const FONDO := Vector3(27.7, 0.5, -67.5)

var pezzi: Array[StaticBody3D] = []


func _ready() -> void:
	_ambiente()
	_piattaforma("PiattaformaAlta", Vector3(0.0, 20.0, 2.5), Vector3(4.0, 1.0, 5.0))
	_piattaforma("PiattaformaFondo", FONDO, Vector3(5.0, 1.0, 7.0))
	for d in PEZZI:
		pezzi.append(_scivolo(d.nome, d.colore, d.punti))
	_checkpoint("CheckpointAlto", 0, Vector3(0.0, 20.0, 3.5), Vector3(4.0, 2.0, 2.0), 0.0)
	_checkpoint("CheckpointFondo", 1, FONDO, Vector3(5.0, 2.0, 7.0), 180.0)
	var vuoto := KillZone.new()
	vuoto.name = "Vuoto"
	vuoto.cause = &"caduta"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300.0, 2.0, 300.0)
	cs.shape = box
	vuoto.add_child(cs)
	add_child(vuoto)
	vuoto.position = Vector3(10.0, -8.0, -30.0)


func _ambiente() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.035, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.6)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.06, 0.07)
	env.fog_density = 0.012
	we.environment = env
	add_child(we)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sole.light_energy = 0.9
	sole.shadow_enabled = true
	add_child(sole)
	# Rosso d'emergenza da sotto, come nella sala della torre.
	var rossa := OmniLight3D.new()
	rossa.light_color = Color(1.0, 0.18, 0.12)
	rossa.light_energy = 6.0
	rossa.omni_range = 40.0
	rossa.position = Vector3(8.0, -4.0, -35.0)
	add_child(rossa)


func _piattaforma(nome: String, cima: Vector3, dim: Vector3) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = nome
	corpo.position = cima - Vector3(0.0, dim.y * 0.5, 0.0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dim
	cs.shape = box
	corpo.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = dim
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.34, 0.36)
	mat.roughness = 0.8
	bm.material = mat
	mi.mesh = bm
	corpo.add_child(mi)
	add_child(corpo)


## Un checkpoint: [param piedi] è anche il punto di ripartenza (si guarda verso il suo -Z).
func _checkpoint(nome: String, ordine: int, piedi: Vector3, dim: Vector3, gradi: float) -> void:
	var cp := Checkpoint.new()
	cp.name = nome
	cp.order = ordine
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dim
	cs.shape = box
	cs.position.y = dim.y * 0.5
	cp.add_child(cs)
	add_child(cp)
	cp.position = piedi
	cp.rotation_degrees.y = gradi


## Un pezzo di scivolo: un canale a U lungo la linea [param punti] (il fondo), solido da tutte e
## due le parti, nel gruppo "scivolo", con i piloni che lo reggono.
func _scivolo(nome: String, colore: Color, punti: Array) -> StaticBody3D:
	var linea := _campiona(punti, 0.3)
	var colonne := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anelli: Array[PackedVector3Array] = []
	for i in linea.size():
		var t := (linea[mini(i + 1, linea.size() - 1)] - linea[maxi(i - 1, 0)]).normalized()
		var lato := t.cross(Vector3.UP).normalized()
		var su := lato.cross(t).normalized()
		var anello := PackedVector3Array()
		for k in colonne + 1:
			var a := deg_to_rad(lerpf(-SPONDA, SPONDA, float(k) / colonne))
			anello.append(linea[i] + lato * sin(a) * RAGGIO + su * (1.0 - cos(a)) * RAGGIO)
		anelli.append(anello)
	for i in anelli.size() - 1:
		for k in colonne:
			var a := anelli[i][k]
			var b := anelli[i][k + 1]
			var c := anelli[i + 1][k]
			var d := anelli[i + 1][k + 1]
			for v in [a, c, b, b, c, d]:
				st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var corpo := StaticBody3D.new()
	corpo.name = nome
	corpo.add_to_group(Player.SLIDE_GROUP)
	corpo.set_meta(&"superficie", Player.SURFACE_SLIDE)
	corpo.set_meta(&"bagnato", true)
	var cs := CollisionShape3D.new()
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(mesh.get_faces())
	forma.backface_collision = true
	cs.shape = forma
	corpo.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colore
	mat.roughness = 0.25
	mat.clearcoat_enabled = true
	mat.clearcoat = 1.0
	mat.clearcoat_roughness = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	corpo.add_child(mi)
	# Piloni grigi ogni tanto, fino in fondo al vuoto.
	for i in range(0, linea.size(), 14):
		var pilone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var alto := linea[i].y + 10.0
		cm.top_radius = 0.12
		cm.bottom_radius = 0.12
		cm.height = alto
		cm.radial_segments = 8
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.4, 0.42, 0.45)
		pm.metallic = 0.6
		pm.roughness = 0.5
		cm.material = pm
		pilone.mesh = cm
		corpo.add_child(pilone)
		pilone.position = linea[i] - Vector3(0.0, alto * 0.5 + 0.05, 0.0)
	add_child(corpo)
	return corpo


## La linea del fondo: Catmull-Rom tra i punti, un campione ogni [param passo] metri circa.
static func _campiona(punti: Array, passo: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in punti.size() - 1:
		var p0: Vector3 = punti[maxi(i - 1, 0)]
		var p1: Vector3 = punti[i]
		var p2: Vector3 = punti[i + 1]
		var p3: Vector3 = punti[mini(i + 2, punti.size() - 1)]
		var n := maxi(2, ceili(p1.distance_to(p2) / passo))
		for k in n:
			var t := float(k) / n
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(punti[punti.size() - 1])
	return out
