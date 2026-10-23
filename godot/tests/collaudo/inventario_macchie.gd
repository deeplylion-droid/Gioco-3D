extends Node
## Collaudo: inventario delle macchie (decal e mesh di macchie/colature) di una scena: texture, quante, quanto
## grandi, quanto coprono, dove stanno. Scrive anche una lista per giro.gd con una veduta di fronte per ogni tipo
## (le più grandi), dagli occhi del giocatore.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/inventario_macchie.gd \
##     <scena.tscn> <uscita.json> <lista.txt> <prefisso> [nodi di primo livello da guardare, con la virgola]

const STATI := preload("res://tests/collaudo/stati.gd")
const PAROLE := ["macchia", "colatura", "colature", "ruggine", "rust", "decal", "muffa", "calcare", "alghe"]

var _tipi := {}   # texture -> {"decal": bool, "voci": [[pos, normale, w, h, alfa, nodo]]}


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	Game.pause_on_focus_loss = false
	var livello := (load(a[1]) as PackedScene).instantiate()
	var solo := PackedStringArray(a[5].split(",")) if a.size() > 5 and a[5] != "" else PackedStringArray()
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 600:
		await get_tree().process_frame
	livello = get_tree().current_scene
	STATI.mostra_nascosti(livello)
	for i in 30:
		await get_tree().physics_frame
	for n in livello.find_children("*", "Decal", true, false):
		var d := n as Decal
		if not _dentro(livello, d, solo) or d.texture_albedo == null:
			continue
		var y := d.global_basis.y.normalized()
		_aggiungi(d.texture_albedo.resource_path, true, d.global_position, y,
				d.size.x * d.global_basis.x.length(), d.size.z * d.global_basis.z.length(), d.albedo_mix, livello.get_path_to(d))
	for n in livello.find_children("*", "MeshInstance3D", true, false):
		var g := n as MeshInstance3D
		if g.mesh == null or not g.is_visible_in_tree() or not _dentro(livello, g, solo):
			continue
		for s in g.mesh.get_surface_count():
			var m := g.get_active_material(s)
			var t := _albedo(m)
			if t == "" or not _e_macchia(t):
				continue
			var ab := g.global_transform * g.mesh.get_aabb()
			var arr := g.mesh.surface_get_arrays(s)
			var nor := Vector3.ZERO
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			for v in ns:
				nor += v
			nor = (g.global_basis * nor).normalized() if nor.length() > 0.0 else Vector3.UP
			var lati := [ab.size.x, ab.size.y, ab.size.z]
			lati.sort()
			_aggiungi(t, false, ab.get_center(), nor, lati[2], lati[1], 1.0, livello.get_path_to(g))
	# i dettagli della sala (e della torre) ripetuti sono MultiMesh: una voce per istanza
	for n in livello.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null or not mmi.is_visible_in_tree() or not _dentro(livello, mmi, solo):
			continue
		var mm := mmi.multimesh
		var mat := mmi.material_override
		if mat == null:
			mat = mm.mesh.surface_get_material(0)
		var t := _albedo(mat)
		if t == "" or not _e_macchia(t):
			continue
		var arr := mm.mesh.surface_get_arrays(0)
		var nor0 := Vector3.ZERO
		if arr[Mesh.ARRAY_NORMAL] != null:
			for v in (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array):
				nor0 += v
		# senza schermo il MultiMesh non conserva le trasformazioni: dettagli_sala.gd le lascia nel meta
		var tr: Array = mmi.get_meta(&"trasformazioni", [])
		for i in mm.instance_count:
			var xf := mmi.global_transform * (tr[i] as Transform3D if i < tr.size() else mm.get_instance_transform(i))
			var ab := xf * mm.mesh.get_aabb()
			var lati := [ab.size.x, ab.size.y, ab.size.z]
			lati.sort()
			var nor := (xf.basis * nor0).normalized() if nor0.length() > 0.0 else Vector3.UP
			_aggiungi(t, false, ab.get_center(), nor, lati[2], lati[1], 1.0, NodePath("%s[%d]" % [livello.get_path_to(mmi), i]))
	var spazio := (livello as Node3D).get_world_3d().direct_space_state
	var righe := PackedStringArray(["luce 0"])
	var out := {}
	var k := 0
	var chiavi := _tipi.keys()
	chiavi.sort()
	for tex in chiavi:
		var e: Dictionary = _tipi[tex]
		var voci: Array = e["voci"]
		voci.sort_custom(func(x, z): return float(x[2]) * float(x[3]) > float(z[2]) * float(z[3]))
		var area := 0.0
		var muro := 0
		for v in voci:
			area += float(v[2]) * float(v[3])
			if absf((v[1] as Vector3).y) < 0.5:
				muro += 1
		k += 1
		var vedute := []
		for v in voci.slice(0, 80):
			if vedute.size() >= 2:
				break
			var p := _veduta(spazio, v[0], v[1], vedute)
			if p.is_empty():
				continue
			vedute.append(p[0])
			var nome := "%s_k%02d_%d" % [a[4], k, vedute.size()]
			righe.append("%s %.2f %.2f %.2f %.1f %.1f" % [nome, p[0].x, p[0].y, p[0].z, p[1], p[2]])
		var esempi := []
		for v in voci.slice(0, 8):
			esempi.append({"pos": [snappedf(v[0].x, 0.01), snappedf(v[0].y, 0.01), snappedf(v[0].z, 0.01)],
					"lato": [snappedf(v[2], 0.01), snappedf(v[3], 0.01)], "alfa": snappedf(v[4], 0.01), "nodo": String(v[5])})
		out["%s_k%02d" % [a[4], k]] = {"texture": tex, "decal": e["decal"], "quante": voci.size(), "sui_muri": muro,
				"area_m2": snappedf(area, 0.1), "vedute": vedute.size(), "esempi": esempi}
	var f := FileAccess.open(a[2], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	var f2 := FileAccess.open(a[3], FileAccess.WRITE)
	f2.store_string("\n".join(righe) + "\n")
	f2.close()
	print("MACCHIE: %d tipi, %d vedute" % [out.size(), righe.size() - 1])
	get_tree().quit()


func _dentro(livello: Node, n: Node, solo: PackedStringArray) -> bool:
	return solo.is_empty() or String(livello.get_path_to(n)).get_slice("/", 0) in solo


func _e_macchia(t: String) -> bool:
	var b := t.get_file().to_lower()
	for p in PAROLE:
		if p in b:
			return true
	return false


func _albedo(m: Material) -> String:
	if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture:
		return (m as BaseMaterial3D).albedo_texture.resource_path
	if m is ShaderMaterial and (m as ShaderMaterial).shader:
		for nome in ["albedo_tex", "texture_albedo", "albedo"]:
			var v = (m as ShaderMaterial).get_shader_parameter(nome)
			if v is Texture2D:
				return (v as Texture2D).resource_path
	return ""


## Un punto dove sta il giocatore, di fronte alla macchia a 2-3 m, con niente in mezzo: [occhio, yaw, pitch].
func _veduta(spazio: PhysicsDirectSpaceState3D, centro: Vector3, normale: Vector3, prese: Array) -> Array:
	var nor := normale
	nor.y = 0.0
	if nor.length() < 0.3:
		# macchia a terra o sul soffitto: si guarda da un lato
		nor = Vector3(1, 0, 0)
	nor = nor.normalized()
	for d in [2.5, 3.0, 2.0, 3.5]:
		for giro in [0.0, 0.5, -0.5]:
			var dir := nor.rotated(Vector3.UP, giro)
			var pos: Vector3 = centro + dir * float(d)
			var h := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pos.x, centro.y + 0.5, pos.z), Vector3(pos.x, centro.y - 4.0, pos.z), Layers.WORLD))
			if h.is_empty() or (h.normal as Vector3).y < 0.7:
				continue
			var occhio := (h.position as Vector3) + Vector3.UP * 1.6
			if absf(centro.y - occhio.y) > 2.5:
				continue
			if not spazio.intersect_ray(PhysicsRayQueryParameters3D.create(occhio - Vector3.UP * 1.4, occhio + Vector3.UP * 0.3, Layers.WORLD)).is_empty():
				continue
			if not spazio.intersect_ray(PhysicsRayQueryParameters3D.create(occhio, centro + normale.normalized() * 0.05, Layers.WORLD)).is_empty():
				continue
			var vicino := false
			for p in prese:
				if (p as Vector3).distance_to(occhio) < 3.0:
					vicino = true
			if vicino:
				continue
			var dd := centro - occhio
			return [occhio, rad_to_deg(atan2(-dd.x, -dd.z)), rad_to_deg(atan2(dd.y, Vector2(dd.x, dd.z).length()))]
	return []


func _aggiungi(tex: String, decal: bool, pos: Vector3, nor: Vector3, w: float, h: float, alfa: float, nodo: NodePath) -> void:
	if not _tipi.has(tex):
		_tipi[tex] = {"decal": decal, "voci": []}
	(_tipi[tex]["voci"] as Array).append([pos, nor, w, h, alfa, nodo])
