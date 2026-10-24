extends Node
## Nessuna istanza di un MultiMesh del gioco ha la base specchiata (determinante < 0). Godot non gira il verso delle facce
## per le istanze specchiate di un MultiMesh: si vedono rovesciate, col dentro al posto del fuori (le pile di scatoloni
## del fiume, riscontro dell'utente sulla v0.3.12: "da una parte le scatole sono ok e dall'altra sono vuote").
## E le facce delle mesh dei MultiMesh girano come vuole Godot (davanti in senso orario vista da fuori, cioè col
## prodotto vettoriale dei lati contro la normale dei vertici): con le facce girate al contrario la mesh si vede rovesciata
## anche con le istanze giuste (era la causa vera delle pile).
## Guarda la sala principale con le stanze della Risalita caricate subito (interni, tecnici, fiume, infermeria) e la
## sala della torre, e per ogni istanza sbagliata dice il nodo e l'indice.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_multimesh_specchiati.gd

const SALA := "res://scenes/sala_principale.tscn"
const TORRE := "res://scenes/sala/torre/sala_torre.tscn"

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file(SALA)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene
	# le stanze della Risalita e il resto si costruiscono a pezzi: qualche secondo
	var ris := level.get_node_or_null(^"Risalita")
	for i in 60 * 30:
		await get_tree().physics_frame
		var f = ris.get(&"fiume") if ris else null
		if f == null or bool((f as Node).get(&"costruita")):
			break
	await _secondi(1.0)
	_controlla(level, "sala principale")
	var torre := (load(TORRE) as PackedScene).instantiate()
	add_child(torre)
	await _secondi(1.0)
	_controlla(torre, "sala della torre")
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _controlla(radice: Node, nome: String) -> void:
	var sbagliate := PackedStringArray()
	var istanze := 0
	var mmi := radice.find_children("*", "MultiMeshInstance3D", true, false)
	for n in mmi:
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm == null or mm.transform_format != MultiMesh.TRANSFORM_3D:
			continue
		for i in mm.instance_count:
			istanze += 1
			if mm.get_instance_transform(i).basis.determinant() < 0.0:
				sbagliate.append("%s [%d]" % [radice.get_path_to(n), i])
	check(mmi.size() > 0 or nome == "sala della torre", "%s: %d MultiMesh con %d istanze" % [nome, mmi.size(), istanze])
	var girate := PackedStringArray()
	for n in mmi:
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null:
			continue
		for sf in mm.mesh.get_surface_count():
			# a doppia faccia (cull_disabled) il verso non conta: le medusine, il film delle pile
			var mat: Material = (n as MultiMeshInstance3D).material_override
			if mat == null:
				mat = mm.mesh.surface_get_material(sf)
			if _doppia_faccia(mat):
				continue
			var a := mm.mesh.surface_get_arrays(sf)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nr = a[Mesh.ARRAY_NORMAL]
			if nr == null or (nr as PackedVector3Array).is_empty() or (mm.mesh is ArrayMesh and (mm.mesh as ArrayMesh).surface_get_primitive_type(sf) != Mesh.PRIMITIVE_TRIANGLES):
				continue
			var idx = a[Mesh.ARRAY_INDEX]
			var ind := PackedInt32Array(idx) if idx != null and not (idx as PackedInt32Array).is_empty() else PackedInt32Array(range(v.size()))
			var contro := 0
			var tot := 0
			for t in range(0, ind.size() - 2, 3):
				var g := (v[ind[t + 1]] - v[ind[t]]).cross(v[ind[t + 2]] - v[ind[t]])
				var nn: Vector3 = (nr as PackedVector3Array)[ind[t]] + (nr as PackedVector3Array)[ind[t + 1]] + (nr as PackedVector3Array)[ind[t + 2]]
				if g.length() < 1e-9 or nn.length() < 1e-6:
					continue
				tot += 1
				if g.dot(nn) > 0.0:
					contro += 1
			if tot > 0 and contro * 2 > tot:
				girate.append("%s superficie %d (%d su %d)" % [radice.get_path_to(n), sf, contro, tot])
	check(girate.is_empty(), "%s: le facce delle mesh dei MultiMesh girano come vuole Godot (%d girate: %s)" % [nome, girate.size(), ", ".join(girate.slice(0, 10))])
	check(sbagliate.is_empty(), "%s: nessuna istanza di MultiMesh specchiata (%d: %s)" % [nome, sbagliate.size(), ", ".join(sbagliate.slice(0, 10))])


static func _doppia_faccia(m: Material) -> bool:
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
	if m is ShaderMaterial and (m as ShaderMaterial).shader:
		return (m as ShaderMaterial).shader.code.contains("cull_disabled")
	return false


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)
