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
