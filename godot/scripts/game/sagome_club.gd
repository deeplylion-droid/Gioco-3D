class_name SagomeClub
extends Node3D
## Le sagome del club dei bambini della nave nelle condotte dell'inseguimento (scelta A dell'utente del 6 novembre,
## "Vasche delle condotte come giochi per bambini"; Jilly fra i disegni A). Le condotte erano il percorso avventura del
## club: le vasche le tappe, i bersagli il gioco "colpisci e apri". Ogni stagione i bambini facevano cartonati nuovi e
## lo staff li lasciava lì, i vecchi coi nuovi; poi la sala si è allagata.
## Dodici animali del mare di cartone ondulato da 5 mm, tagliati a mano, colorati a pastello sulla tempera bianca, con
## la manina del bambino al posto della firma, quattro per vasca e di tre età (slavati e gonfi d'acqua, riparati con lo
## scotch, uno nuovo per vasca). Sulla balena vecchia della vasca 1 la mascotte sorridente coi pesci, sul pesce palla
## della vasca 2 lei alta coi tentacoli sopra i bambini piccoli, sul pesce nuovo della vasca 3 solo il suo occhio.
## - vasca 1 e 3: in piedi sul bordo di piastrelle, girate verso l'acqua, col puntello di cartone dietro e un mattone sul
##   suo piede;
## - vasca 2: sulla passerella nord, dietro la ringhiera, legate con lo spago a due montanti (due fori per legatura).
## Le texture, il taglio e la posa li fanno assets_src/sagome_club/genera.py e posa.py (assets/sagome_club/posa.json,
## nelle coordinate della sala: i GLB della sala ci entrano senza spostamenti). Nessuna collisione: stanno fuori da dove
## si cammina e si scivola. Un filo di luce propria nei pastelli (come il disegno guida dei giocattoli, "pastelli
## fosforescenti"), così si leggono anche lontano dalle lampade da lavoro.

const DIR := "res://assets/sagome_club/"
const SPESSORE := 0.005
## Il filo di luce dei pastelli (0,1: come il disegno guida; a 0,3 sembrava uno schermo acceso).
const LUCE_PROPRIA := 0.1
const KRAFT := Color(0.5, 0.37, 0.24)
const BORDO_CARTONE := Color(0.42, 0.3, 0.19)
const SPAGO := Color(0.66, 0.56, 0.4)
const MATTONE := Color(0.5, 0.2, 0.13)

var posa: Dictionary = {}
var _retro: StandardMaterial3D
var _taglio: StandardMaterial3D


## I passi per costruirle dentro la sala [param sala] (uno per sagoma, poi i puntelli, i mattoni e lo spago), da
## mettere nella coda di costruzione della sala, come gli altri pezzi.
static func passi(sala: Node3D) -> Array:
	var s := SagomeClub.new()
	s.name = "SagomeClub"
	var out: Array = [func(): sala.add_child(s); s._prepara()]
	var quante := 12
	for i in quante:
		out.append(func(): s._sagoma(i))
	out.append(func(): s._accessori())
	return out


func _prepara() -> void:
	var f := FileAccess.open(DIR + "posa.json", FileAccess.READ)
	posa = JSON.parse_string(f.get_as_text()) if f else {}
	_retro = _materiale(KRAFT, 0.95)
	_taglio = _materiale(BORDO_CARTONE, 1.0)


## Le sagome, per i test.
func sagome() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in get_children():
		if c is MeshInstance3D and String(c.name).begins_with("Sagoma"):
			out.append(c)
	return out


func _sagoma(i: int) -> void:
	var lista: Array = posa.get("sagome", [])
	if i >= lista.size():
		return
	var d: Dictionary = lista[i]
	var punti: Array = d["punti"]
	var tri: Array = d["tri"]
	var uv: Array = d["uv"]
	var fronte := SurfaceTool.new()
	fronte.begin(Mesh.PRIMITIVE_TRIANGLES)
	var retro := SurfaceTool.new()
	retro.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(0, tri.size(), 3):
		var t: Array[Vector2] = []
		for j in 3:
			var p: Array = punti[int(tri[k + j])]
			t.append(Vector2(p[0], p[1]))
		var uvs := t.map(func(q: Vector2) -> Vector2: return Vector2(uv[0] + q.x * uv[1], uv[2] - q.y * uv[3]))
		_tri(fronte, [Vector3(t[0].x, t[0].y, SPESSORE), Vector3(t[1].x, t[1].y, SPESSORE), Vector3(t[2].x, t[2].y, SPESSORE)], Vector3.BACK, uvs)
		_tri(retro, [Vector3(t[0].x, t[0].y, 0), Vector3(t[1].x, t[1].y, 0), Vector3(t[2].x, t[2].y, 0)], Vector3.FORWARD, [])
	# i lati del taglio: il contorno (antiorario) e i fori (orari), la normale verso fuori dal cartone
	var lati := SurfaceTool.new()
	lati.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inizio := 0
	for n in d["anelli"]:
		for j in int(n):
			var a: Array = punti[inizio + j]
			var b: Array = punti[inizio + (j + 1) % int(n)]
			var pa := Vector2(a[0], a[1])
			var pb := Vector2(b[0], b[1])
			var e := (pb - pa).normalized()
			var nn := Vector3(e.y, -e.x, 0)
			var q := [Vector3(pa.x, pa.y, 0), Vector3(pb.x, pb.y, 0), Vector3(pb.x, pb.y, SPESSORE), Vector3(pa.x, pa.y, SPESSORE)]
			_tri(lati, [q[0], q[1], q[2]], nn, [])
			_tri(lati, [q[0], q[2], q[3]], nn, [])
		inizio += int(n)
	var mesh := ArrayMesh.new()
	fronte.commit(mesh)
	retro.commit(mesh)
	lati.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.name = "Sagoma_" + String(d["nome"])
	mi.mesh = mesh
	var faccia := StandardMaterial3D.new()
	var tex := load(DIR + String(d["nome"]) + ".png") as Texture2D
	faccia.albedo_texture = tex
	faccia.roughness = 0.95
	faccia.emission_enabled = true
	faccia.emission_texture = tex
	faccia.emission_energy_multiplier = LUCE_PROPRIA
	mi.set_surface_override_material(0, faccia)
	mi.set_surface_override_material(1, _retro)
	mi.set_surface_override_material(2, _taglio)
	mi.set_meta(&"vasca", int(d["vasca"]))
	mi.set_meta(&"eta", String(d["eta"]))
	add_child(mi)
	mi.transform = _xf(d["base"], d["origine"])


## I puntelli e i mattoni delle sagome sul bordo, e lo spago di quelle legate alla ringhiera.
func _accessori() -> void:
	var mattone := _materiale(MATTONE, 0.9)
	var k := 0
	for p in posa.get("puntelli", []):
		k += 1
		_scatola("Puntello%d" % k, p, _retro)
	k = 0
	for p in posa.get("mattoni", []):
		k += 1
		_scatola("Mattone%d" % k, p, mattone)
	var spago := _materiale(SPAGO, 0.85)
	k = 0
	for l in posa.get("legature", []):
		k += 1
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var v: Array = l["v"]
		var n: Array = l["n"]
		for j in range(0, v.size(), 9):
			var t := [Vector3(v[j], v[j + 1], v[j + 2]), Vector3(v[j + 3], v[j + 4], v[j + 5]), Vector3(v[j + 6], v[j + 7], v[j + 8])]
			_tri(st, t, Vector3(n[j], n[j + 1], n[j + 2]), [])
		# il nodo, dietro al cartone, sullo spago
		var c: Array = l["nodo"]
		_palla(st, Vector3(c[0], c[1], c[2]), 0.005)
		var mi := MeshInstance3D.new()
		mi.name = "Legatura%d" % k
		mi.mesh = st.commit()
		mi.material_override = spago
		add_child(mi)


func _scatola(nome: String, p: Dictionary, materiale: Material) -> void:
	var m := MeshInstance3D.new()
	m.name = nome
	var bm := BoxMesh.new()
	var s: Array = p["misura"]
	bm.size = Vector3(s[0], s[1], s[2])
	m.mesh = bm
	m.material_override = materiale
	add_child(m)
	m.transform = _xf(p["base"], p["centro"])


## Un triangolo con la faccia verso [param n] (in Godot la faccia davanti ha i vertici in senso orario).
static func _tri(st: SurfaceTool, t: Array, n: Vector3, uvs: Array) -> void:
	var ordine := [0, 1, 2]
	if (t[1] - t[0]).cross(t[2] - t[0]).dot(n) > 0.0:
		ordine = [0, 2, 1]
	for j in ordine:
		st.set_normal(n)
		if not uvs.is_empty():
			st.set_uv(uvs[j])
		st.add_vertex(t[j])


## Una pallina (il nodo dello spago) di raggio [param r] attorno a [param c].
static func _palla(st: SurfaceTool, c: Vector3, r: float) -> void:
	var anelli := 5
	var spicchi := 8
	var p := func(i: int, j: int) -> Vector3:
		var a := PI * i / anelli
		var b := TAU * j / spicchi
		return Vector3(sin(a) * cos(b), cos(a), sin(a) * sin(b))
	for i in anelli:
		for j in spicchi:
			var a: Vector3 = p.call(i, j)
			var b: Vector3 = p.call(i + 1, j)
			var c2: Vector3 = p.call(i + 1, j + 1)
			var d: Vector3 = p.call(i, j + 1)
			var nn := (a + b + c2 + d).normalized()
			_tri(st, [c + a * r, c + b * r, c + c2 * r], nn, [])
			_tri(st, [c + a * r, c + c2 * r, c + d * r], nn, [])


static func _xf(base: Array, origine: Array) -> Transform3D:
	var b := Basis(Vector3(base[0], base[1], base[2]), Vector3(base[3], base[4], base[5]), Vector3(base[6], base[7], base[8]))
	return Transform3D(b, Vector3(origine[0], origine[1], origine[2]))


static func _materiale(colore: Color, ruvido: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.roughness = ruvido
	return m
