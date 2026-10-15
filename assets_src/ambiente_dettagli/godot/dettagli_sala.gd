extends Node3D
## Monta il kit di dettagli nella sala principale leggendo posizionamento.json.
## Da attaccare a un Node3D in (0, 0, 0), allo stesso livello dei GLB della sala.
## I nodi con almeno `soglia_multimesh` istanze diventano un MultiMeshInstance3D (un draw call per superficie),
## gli altri sono copie normali. I pezzi piccoli si spengono da lontano e non fanno ombra.

@export_dir var cartella := "res://assets/ambiente_dettagli"
@export var usa_gltf := true   # true: gltf/<categoria>.gltf con le texture condivise; false: glb/<categoria>.glb
@export var soglia_multimesh := 6
@export var distanza_pezzi_piccoli := 30.0   # m: oltre, fogli, piastrelle, giocattoli e macchie non si disegnano
@export var ombre_pezzi_grandi := false

const PICCOLI := ["det_piastrella", "det_foglio", "det_carta", "det_vetri", "det_paperella", "det_secchiello", "det_paletta",
	"det_barchetta", "det_pistola", "det_pesce", "det_maschera", "det_ciabatta", "det_macchia", "det_incrostazione", "det_alghe"]


func _ready() -> void:
	var dati: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cartella.path_join("posizionamento.json")))
	var per_nodo := {}
	for p in dati.posti:
		var k: String = p.glb + "|" + p.nodo
		if not per_nodo.has(k):
			per_nodo[k] = []
		per_nodo[k].append(p)
	var scene := {}
	for k in per_nodo:
		var glb: String = k.get_slice("|", 0)
		if usa_gltf:
			glb = glb.replace("glb/", "gltf/").replace(".glb", ".gltf")
		var nome: String = k.get_slice("|", 1)
		if not scene.has(glb):
			scene[glb] = load(cartella.path_join(glb)).instantiate()
		var src := scene[glb].get_node_or_null(NodePath(nome)) as MeshInstance3D
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
			for i in posti.size():
				mm.set_instance_transform(i, _trasformazione(posti[i]))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = nome
			mmi.multimesh = mm
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
		s.free()


func _trasformazione(p: Dictionary) -> Transform3D:
	var b: Array = p.basis
	return Transform3D(Basis(Vector3(b[0][0], b[0][1], b[0][2]), Vector3(b[1][0], b[1][1], b[1][2]), Vector3(b[2][0], b[2][1], b[2][2])),
		Vector3(p.posizione[0], p.posizione[1], p.posizione[2]))


func _regola(g: GeometryInstance3D, piccolo: bool) -> void:
	if piccolo:
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = distanza_pezzi_piccoli
		g.visibility_range_end_margin = 2.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	elif not ombre_pezzi_grandi:
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
