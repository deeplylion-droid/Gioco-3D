extends RefCounted
## Controlla che nessuna Polaroid sia coperta o compenetrata da una mesh visibile (prova del
## 19 ottobre: una Polaroid "nascosta sotto un foglio di carta". La P08 sul bordo della vasca d'arrivo
## stava sotto un pannello di controsoffitto del kit di dettagli, che non ha collisioni e quindi non
## ferma lo snap; la P07 sulla scrivania della sala pompe stava sotto i fogli della v0.3.7).
## Per ogni Polaroid si prende la scatola sopra la foto (da SOPRA a ALTEZZA m nel suo sistema: la foto
## è spessa 3 mm) e si cercano i triangoli che la attraversano, in tutte le MeshInstance3D e MultiMeshInstance3D
## visibili (test esatto triangolo-scatola). Restituisce un elenco di righe
## "Polaroid08: det_pannello_controsoffitto (copia 12, 3.8 cm)", con fin dove arriva sopra la foto,
## vuoto se sono tutte libere. appoggio() dice quanto sta sopra la superficie che ha sotto.

## Quanto spazio libero serve sopra la foto (m).
const ALTEZZA := 0.06
## Da dove parte la scatola: appena sopra la faccia della foto.
const SOPRA := 0.0035
## Mezza larghezza e mezza lunghezza della Polaroid (il modello è 8,8 x 10,7 cm).
const MEZZA := Vector2(0.044, 0.0535)

## L'ultimo triangolo trovato da _tocca, nel sistema della Polaroid (per le sonde; con la variabile
## d'ambiente TRIANGOLI finisce nelle righe del risultato).
static var ultimo_triangolo := PackedVector3Array()


static func coperte(radice: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var geo := radice.find_children("*", "GeometryInstance3D", true, false)
	for f in radice.find_children("*", "PolaroidPhoto", true, false):
		out.append_array(coperta(f as Node3D, geo))
	return out


## Che cosa copre la Polaroid [param pf], tra le GeometryInstance3D [param geo].
static func coperta(pf: Node3D, geo: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var box := AABB(Vector3(-MEZZA.x, SOPRA, -MEZZA.y), Vector3(MEZZA.x * 2.0, ALTEZZA - SOPRA, MEZZA.y * 2.0))
	var mondo := pf.global_transform * box
	for g in geo:
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree() or pf.is_ancestor_of(gi):
			continue
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			var mi := gi as MeshInstance3D
			if (mi.global_transform * mi.mesh.get_aabb()).intersects(mondo):
				var h := _tocca(mi.mesh, pf.global_transform.affine_inverse() * mi.global_transform, box)
				if h >= 0.0:
					out.append("%s: %s (%.1f cm) %s" % [pf.name, mi.name, h * 100.0, str(ultimo_triangolo) if OS.has_environment("TRIANGOLI") else ""])
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm.mesh == null:
				continue
			var copie := _copie(gi as MultiMeshInstance3D)
			for i in copie.size():
				var t := gi.global_transform * copie[i]
				if (t * mm.mesh.get_aabb()).intersects(mondo):
					var h := _tocca(mm.mesh, pf.global_transform.affine_inverse() * t, box)
					if h >= 0.0:
						out.append("%s: %s (copia %d, %.1f cm)" % [pf.name, gi.name, i, h * 100.0])
	return out


## Le trasformazioni delle copie di una MultiMesh. Senza renderer vero (--headless, come nella CI) il
## motore non le tiene: per i dettagli della sala (DettagliSala) si rileggono da posizionamento.json.
static func _copie(mmi: MultiMeshInstance3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var det := mmi.get_parent() as DettagliSala
	if det and RenderingServer.get_rendering_device() == null:
		var dati = JSON.parse_string(FileAccess.get_file_as_string(det.cartella.path_join("posizionamento.json")))
		for p in dati.posti:
			if p.nodo == String(mmi.name):
				out.append(det._trasformazione(p))
		return out
	for i in mmi.multimesh.instance_count:
		out.append(mmi.multimesh.get_instance_transform(i))
	return out


## Fin dove arrivano sopra la foto (m) i triangoli della mesh (portati nel sistema della Polaroid con
## `t`) che attraversano `box`; -1 se nessuno la attraversa.
static func _tocca(mesh: Mesh, t: Transform3D, box: AABB) -> float:
	var alto := -1.0
	var facce := mesh.get_faces()
	for i in range(0, facce.size(), 3):
		var a := t * facce[i]
		var b := t * facce[i + 1]
		var c := t * facce[i + 2]
		if not AABB(a, Vector3.ZERO).expand(b).expand(c).intersects(box) or not _triangolo_in_scatola(a, b, c, box):
			continue
		alto = maxf(alto, _altezza_dentro(a, b, c, box))
		ultimo_triangolo = PackedVector3Array([a, b, c])
	return alto


## Test esatto triangolo-scatola (assi separatori: le 3 facce della scatola, la normale del triangolo
## e i 9 prodotti tra i lati).
static func _triangolo_in_scatola(a: Vector3, b: Vector3, c: Vector3, box: AABB) -> bool:
	var m := box.get_center()
	var e := box.size * 0.5
	var v := [a - m, b - m, c - m]
	var lati := [v[1] - v[0], v[2] - v[1], v[0] - v[2]]
	var assi: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK, (lati[0] as Vector3).cross(lati[1])]
	for u in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		for l in lati:
			assi.append((u as Vector3).cross(l))
	for ax in assi:
		if ax.length_squared() < 1e-14:
			continue
		var p0: float = ax.dot(v[0])
		var p1: float = ax.dot(v[1])
		var p2: float = ax.dot(v[2])
		var r := e.x * absf(ax.x) + e.y * absf(ax.y) + e.z * absf(ax.z)
		if minf(p0, minf(p1, p2)) > r or maxf(p0, maxf(p1, p2)) < -r:
			return false
	return true


## Il punto più alto del triangolo dentro l'impronta della scatola (vertici dentro, oppure dove le
## verticali degli angoli lo attraversano), limitato alla scatola.
static func _altezza_dentro(a: Vector3, b: Vector3, c: Vector3, box: AABB) -> float:
	var h := -INF
	for v in [a, b, c]:
		if v.x >= box.position.x and v.x <= box.end.x and v.z >= box.position.z and v.z <= box.end.z:
			h = maxf(h, v.y)
	for k in 5:
		var q := box.get_center() if k == 4 else box.get_endpoint([0, 1, 4, 5][k])
		var x = Geometry3D.ray_intersects_triangle(Vector3(q.x, 10.0, q.z), Vector3.DOWN, a, b, c)
		if x != null:
			h = maxf(h, (x as Vector3).y)
	# un bordo sottile che passa senza vertici dentro e senza toccare le verticali: il suo vertice più alto
	if h == -INF:
		h = maxf(a.y, maxf(b.y, c.y))
	return clampf(h, box.position.y, box.end.y)


## Quanto sta sopra (m) la superficie visibile sotto un punto della foto (il centro, se no
## [param punto] nel suo sistema), lungo il suo -y (INF se entro 30 cm non c'è niente: galleggia).
static func appoggio(radice: Node, f: Node3D, punto := Vector3.ZERO, meshes: Array = []) -> float:
	var meglio := INF
	var zona := f.global_transform * AABB(punto + Vector3(-0.01, -0.3, -0.01), Vector3(0.02, 0.31, 0.02))
	if meshes.is_empty():
		meshes = radice.find_children("*", "MeshInstance3D", true, false)
	for g in meshes:
		var mi := g as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or f.is_ancestor_of(mi):
			continue
		if not (mi.global_transform * mi.mesh.get_aabb()).intersects(zona):
			continue
		var t := Transform3D(Basis(), -punto) * f.global_transform.affine_inverse() * mi.global_transform
		var facce := mi.mesh.get_faces()
		for i in range(0, facce.size(), 3):
			var a := t * facce[i]
			var b := t * facce[i + 1]
			var c := t * facce[i + 2]
			if maxf(a.x, maxf(b.x, c.x)) < 0.0 or minf(a.x, minf(b.x, c.x)) > 0.0 \
					or maxf(a.z, maxf(b.z, c.z)) < 0.0 or minf(a.z, minf(b.z, c.z)) > 0.0 \
					or minf(a.y, minf(b.y, c.y)) > 0.01 or maxf(a.y, maxf(b.y, c.y)) < -0.3:
				continue
			var h = Geometry3D.ray_intersects_triangle(Vector3(0, 0.01, 0), Vector3.DOWN, a, b, c)
			if h != null:
				meglio = minf(meglio, -(h as Vector3).y)
	return meglio
