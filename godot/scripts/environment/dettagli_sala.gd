class_name DettagliSala
extends Node3D
## Monta il kit di dettagli della sala (ambienti-2, assets_src/ambiente_dettagli) leggendo
## posizionamento.json: detriti, cartelli, cavi, tubi, macchie... 1219 posti in tutto.
## Va su un Node3D in (0, 0, 0), allo stesso livello dei GLB della sala.
## I nodi con almeno `soglia_multimesh` istanze diventano un MultiMeshInstance3D (un draw call per
## superficie), gli altri sono copie normali. I pezzi piccoli si spengono da lontano, nessuno fa
## ombra e nessuno entra nel VoxelGI calcolato in anticipo (la luce la ricevono e basta).

## Cartella con posizionamento.json e le sottocartelle gltf/ (o glb/).
@export_dir var cartella := "res://assets/ambiente/dettagli"
## true: gltf/<categoria>.gltf con le texture condivise (pesa meno); false: glb/<categoria>.glb.
@export var usa_gltf := true
## I modelli del kit: messi qui si caricano insieme alla scena (nel thread del caricamento), se
## no si caricano al primo _ready.
@export var modelli: Array[PackedScene] = []
@export var soglia_multimesh := 6
## Oltre questa distanza (m) fogli, piastrelle, giocattoli e macchie non si disegnano.
@export var distanza_pezzi_piccoli := 30.0
@export var ombre_pezzi_grandi := false

## I tubi delle corse lungo i muri (per i gomiti che rientrano nel muro ai due capi, posti "det_tubo_rientro_inizio" e
## "_fine" con la "sorgente"): raggio e quota di ogni tubo nel pezzo (y in alto, z fuori dal muro), e quanto sta
## lontano dal muro il loro asse. Come nel kit (tools/blender/dettagli_kit.py).
const TUBI_CORSE := {
	"det_tubo_muro_7cm_2m": [0.085, [[0.035, 0.0]]],
	"det_tubo_muro_10cm_2m": [0.1, [[0.05, 0.0]]],
	"det_tubo_muro_16cm_2m": [0.13, [[0.08, 0.0]]],
	"det_tubi_paralleli_2m": [0.12, [[0.05, 0.0], [0.035, 0.14], [0.06, -0.17]]],
}

const PICCOLI := ["det_piastrella", "det_foglio", "det_carta", "det_vetri", "det_paperella", "det_secchiello", "det_paletta",
	"det_barchetta", "det_pistola", "det_pesce", "det_maschera", "det_ciabatta", "det_macchia", "det_incrostazione", "det_alghe"]


func _ready() -> void:
	var testo := FileAccess.get_file_as_string(cartella.path_join("posizionamento.json"))
	var dati = JSON.parse_string(testo) if not testo.is_empty() else null
	if not (dati is Dictionary) or not (dati as Dictionary).has("posti"):
		push_warning("DettagliSala: posizionamento.json mancante o illeggibile in " + cartella)
		return
	var pronti := {}
	for ps in modelli:
		if ps:
			pronti[ps.resource_path.get_file().get_basename()] = ps
	var per_nodo := {}
	for p in dati.posti:
		var k: String = p.glb + "|" + p.nodo
		if not per_nodo.has(k):
			per_nodo[k] = []
		per_nodo[k].append(p)
	var scene := {}
	for k in per_nodo:
		var glb: String = k.get_slice("|", 0)
		var nome: String = k.get_slice("|", 1)
		if usa_gltf:
			glb = glb.replace("glb/", "gltf/").replace(".glb", ".gltf")
		if not scene.has(glb):
			var ps: PackedScene = pronti.get(glb.get_file().get_basename(), null)
			if ps == null:
				ps = load(cartella.path_join(glb)) as PackedScene
			scene[glb] = ps.instantiate() if ps else null
			if scene[glb]:
				# I materiali del kit sullo stesso shader dove si può (stesso aspetto, meno pipeline).
				UnificaMateriali.unifica(scene[glb])
		if scene[glb] == null:
			continue
		if nome.begins_with("det_tubo_rientro"):
			_gomiti(scene[glb], nome, per_nodo[k])
			continue
		var src := (scene[glb] as Node).get_node_or_null(NodePath(nome)) as MeshInstance3D
		if src == null:
			push_warning("dettaglio mancante: " + nome)
			continue
		var piccolo := false
		for pre in PICCOLI:
			if nome.begins_with(pre):
				piccolo = true
		var posti: Array = per_nodo[k]
		if posti.size() >= soglia_multimesh:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = src.mesh
			mm.instance_count = posti.size()
			var tr: Array[Transform3D] = []
			for i in posti.size():
				tr.append(_trasformazione(posti[i]))
				mm.set_instance_transform(i, tr[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = nome
			mmi.multimesh = mm
			# le trasformazioni anche qui: senza schermo (il renderer finto) il MultiMesh non le conserva, e il controllo
			# di posizionamento le legge da qui
			mmi.set_meta(&"trasformazioni", tr)
			_regola(mmi, piccolo)
			add_child(mmi)
		else:
			for p in posti:
				var copia := MeshInstance3D.new()
				copia.name = nome
				copia.mesh = src.mesh
				copia.transform = _trasformazione(p)
				_regola(copia, piccolo)
				add_child(copia)
	for s in scene.values():
		if s:
			(s as Node).free()


## I gomiti ai capi delle corse di tubi: il tubo della corsa va avanti 8 cm, gira di 90 gradi verso il muro e ci entra,
## con un rosone sul muro (prima le corse finivano a mezz'aria: controllo di posizionamento del 22 ottobre sera).
## "_fine" sta dopo la fine dell'ultimo pezzo (verso +X), "_inizio" prima del primo (verso -X).
func _gomiti(scena: Node, nome: String, posti: Array) -> void:
	var cache := {}
	for p in posti:
		var sorgente := String(p.get("sorgente", ""))
		if not TUBI_CORSE.has(sorgente):
			push_warning("gomito senza tubo: " + sorgente)
			continue
		if not cache.has(sorgente):
			var src := scena.get_node_or_null(NodePath(sorgente)) as MeshInstance3D
			if src == null:
				continue
			cache[sorgente] = _mesh_gomito(src.mesh, TUBI_CORSE[sorgente], nome.ends_with("_inizio"))
		var g := MeshInstance3D.new()
		g.name = nome
		g.mesh = cache[sorgente]
		g.transform = _trasformazione(p)
		_regola(g, false)
		add_child(g)


static func _mesh_gomito(src: Mesh, dati: Array, inizio: bool) -> ArrayMesh:
	var c: float = dati[0]
	var am := ArrayMesh.new()
	for t in dati[1]:
		var r: float = t[0]
		var yv: float = t[1]
		# il materiale: la superficie del pezzo più piccola in altezza che contiene la quota del tubo
		var mat: Material = null
		var alto := INF
		for s in src.get_surface_count():
			var vs: PackedVector3Array = src.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var lo := INF
			var hi := -INF
			for v in vs:
				lo = minf(lo, v.y)
				hi = maxf(hi, v.y)
			if lo - 0.005 <= yv and yv <= hi + 0.005 and hi - lo < alto:
				alto = hi - lo
				mat = src.surface_get_material(s)
		# l'asse: dritto 8 cm, poi un quarto di cerchio di raggio c verso il muro, fino al muro
		var a := 0.08
		var asse := PackedVector3Array([Vector3(0.0, yv, c)])
		for i in range(0, 13):
			var th := PI / 2.0 * i / 12.0
			asse.append(Vector3(a + c * sin(th), yv, c * cos(th)))
		asse.append(Vector3(a + c, yv, -0.004))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tubo(st, asse, r, inizio)
		# il rosone sul muro
		var ros := PackedVector3Array([Vector3(a + c, yv, 0.012), Vector3(a + c, yv, -0.002)])
		_tubo(st, ros, r + 0.025, inizio, true)
		st.generate_normals()
		st.set_material(mat)
		st.commit(am)
	return am


## Un tubo di raggio [param r] lungo [param asse] (che sta in un piano orizzontale), con i tappi se [param tappi].
## [param specchio]: specchiato in X (il gomito dell'inizio della corsa).
static func _tubo(st: SurfaceTool, asse: PackedVector3Array, r: float, specchio: bool, tappi := false) -> void:
	const SEG := 14
	var anelli: Array[PackedVector3Array] = []
	for i in asse.size():
		var tg := (asse[mini(i + 1, asse.size() - 1)] - asse[maxi(i - 1, 0)]).normalized()
		var lato := tg.cross(Vector3.UP).normalized()
		var anello := PackedVector3Array()
		for k in SEG:
			var ang := TAU * k / SEG
			anello.append(asse[i] + lato * cos(ang) * r + Vector3.UP * sin(ang) * r)
		anelli.append(anello)
	var tri := func(p0: Vector3, p1: Vector3, p2: Vector3):
		# (Godot: davanti in senso orario; specchiato, il verso si inverte)
		if specchio:
			for q in [p0, p1, p2]:
				st.add_vertex(Vector3(-q.x, q.y, q.z))
		else:
			for q in [p0, p2, p1]:
				st.add_vertex(q)
	for i in anelli.size() - 1:
		for k in SEG:
			var k2 := (k + 1) % SEG
			tri.call(anelli[i][k], anelli[i + 1][k], anelli[i][k2])
			tri.call(anelli[i][k2], anelli[i + 1][k], anelli[i + 1][k2])
	if tappi:
		for i in [0, anelli.size() - 1]:
			for k in SEG:
				var k2 := (k + 1) % SEG
				if i == 0:
					tri.call(asse[i], anelli[i][k2], anelli[i][k])
				else:
					tri.call(asse[i], anelli[i][k], anelli[i][k2])


func _trasformazione(p: Dictionary) -> Transform3D:
	var b: Array = p.basis
	return Transform3D(Basis(Vector3(b[0][0], b[0][1], b[0][2]), Vector3(b[1][0], b[1][1], b[1][2]), Vector3(b[2][0], b[2][1], b[2][2])),
		Vector3(p.posizione[0], p.posizione[1], p.posizione[2]))


func _regola(g: GeometryInstance3D, piccolo: bool) -> void:
	g.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if piccolo:
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = distanza_pezzi_piccoli
		g.visibility_range_end_margin = 2.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	elif not ombre_pezzi_grandi:
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
