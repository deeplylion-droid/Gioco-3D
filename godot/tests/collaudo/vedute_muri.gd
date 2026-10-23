extends Node
## Collaudo: per ogni materiale con almeno [AREA_MIN] m² di muro (facce verticali) in una scena, sceglie due punti
## dove sta il giocatore (pavimento sotto, occhi a 1,6 m) da cui il muro si vede di fronte a 2-3,5 m, senza niente
## in mezzo. Scrive la lista per giro.gd e un file con i materiali di ogni veduta.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/vedute_muri.gd \
##     <scena.tscn> <lista.txt> <materiali.json> [nodi da togliere, con la virgola]

const STATI := preload("res://tests/collaudo/stati.gd")
const AREA_MIN := 8.0

var _sig := {}   # firma -> {"info", "area", "tri": [[centro, normale, area, nodo]]}


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	Game.pause_on_focus_loss = false
	var livello := (load(a[1]) as PackedScene).instantiate()
	# [nodi da guardare]: solo i materiali sotto questi nodi di primo livello (la sala senza le altre zone)
	var solo := PackedStringArray(a[4].split(",")) if a.size() > 4 and a[4] != "" else PackedStringArray()
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 600:
		await get_tree().process_frame
	livello = get_tree().current_scene
	STATI.mostra_nascosti(livello)
	for i in 30:
		await get_tree().physics_frame
	for n in livello.find_children("*", "MeshInstance3D", true, false):
		var g := n as MeshInstance3D
		if g.mesh == null or not g.is_visible_in_tree():
			continue
		if not solo.is_empty() and not String(livello.get_path_to(g)).get_slice("/", 0) in solo:
			continue
		for s in g.mesh.get_surface_count():
			var m: Material = g.get_active_material(s)
			if m == null:
				continue
			var firma := _firma(m)
			if firma == "":
				continue
			var arr := g.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			var ii: PackedInt32Array = idx if idx != null else PackedInt32Array(range(v.size()))
			var t := g.global_transform
			if not _sig.has(firma):
				_sig[firma] = {"info": _info(m), "area": 0.0, "tri": [], "nodi": {}}
			var e: Dictionary = _sig[firma]
			e["nodi"][String(livello.get_path_to(g))] = true
			for k in range(0, ii.size(), 3):
				var p0 := t * v[ii[k]]
				var p1 := t * v[ii[k + 1]]
				var p2 := t * v[ii[k + 2]]
				var cr := (p1 - p0).cross(p2 - p0)
				var ar := cr.length() * 0.5
				if ar < 0.02 or absf(cr.y) / (ar * 2.0) > 0.3:
					continue
				e["area"] += ar
				if ar > 0.15 or e["tri"].size() < 400:
					e["tri"].append([(p0 + p1 + p2) / 3.0, -cr.normalized(), ar])
	var spazio := (livello as Node3D).get_world_3d().direct_space_state
	var righe := PackedStringArray(["luce 0"])
	var mappa := {}
	var k_sig := 0
	var chiavi := _sig.keys()
	chiavi.sort_custom(func(x, y): return float(_sig[x]["area"]) > float(_sig[y]["area"]))
	for firma in chiavi:
		var e: Dictionary = _sig[firma]
		if float(e["area"]) < AREA_MIN:
			continue
		k_sig += 1
		var tri: Array = e["tri"]
		tri.sort_custom(func(x, y): return float(x[2]) > float(y[2]))
		var scelte: Array = []
		for c in tri.slice(0, 600):
			if scelte.size() >= 2:
				break
			var centro: Vector3 = c[0]
			var nor: Vector3 = c[1]
			nor.y = 0.0
			if nor.length() < 0.5:
				continue
			nor = nor.normalized()
			for d in [2.5, 3.0, 2.0, 3.5]:
				var pos: Vector3 = centro + nor * float(d)
				var giu := PhysicsRayQueryParameters3D.create(Vector3(pos.x, centro.y + 0.3, pos.z), Vector3(pos.x, centro.y - 3.0, pos.z), Layers.WORLD)
				var h := spazio.intersect_ray(giu)
				if h.is_empty() or (h.normal as Vector3).y < 0.7:
					continue
				var occhio := (h.position as Vector3) + Vector3.UP * 1.6
				if absf(centro.y - occhio.y) > 1.3:
					continue
				# niente sopra la testa e niente in mezzo fra occhio e muro
				if not spazio.intersect_ray(PhysicsRayQueryParameters3D.create(occhio - Vector3.UP * 1.4, occhio + Vector3.UP * 0.3, Layers.WORLD)).is_empty():
					continue
				var vista := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(occhio, centro + nor * 0.05, Layers.WORLD))
				if not vista.is_empty():
					continue
				var lontano := false
				for sc in scelte:
					if (sc as Vector3).distance_to(occhio) < 3.0:
						lontano = true
				if lontano:
					continue
				scelte.append(occhio)
				var dir := centro - occhio
				var yaw := rad_to_deg(atan2(-dir.x, -dir.z))
				var pitch := rad_to_deg(atan2(dir.y, Vector2(dir.x, dir.z).length()))
				var nome := "m%02d_%d" % [k_sig, scelte.size()]
				righe.append("%s %.2f %.2f %.2f %.1f %.1f" % [nome, occhio.x, occhio.y, occhio.z, yaw, pitch])
				mappa[nome] = {"firma": firma, "muro": [snappedf(centro.x, 0.01), snappedf(centro.y, 0.01), snappedf(centro.z, 0.01)], "distanza": d}
				break
		if scelte.is_empty():
			mappa["m%02d_nessuna" % k_sig] = {"firma": firma}
	var f := FileAccess.open(a[2], FileAccess.WRITE)
	f.store_string("\n".join(righe) + "\n")
	f.close()
	var info := {}
	for firma in _sig:
		var e: Dictionary = _sig[firma]
		if float(e["area"]) >= AREA_MIN:
			info[firma] = {"info": e["info"], "area_verticale": snappedf(float(e["area"]), 0.1), "nodi": (e["nodi"] as Dictionary).keys().slice(0, 6)}
	var g2 := FileAccess.open(a[3], FileAccess.WRITE)
	g2.store_string(JSON.stringify({"vedute": mappa, "materiali": info}, " "))
	g2.close()
	print("VEDUTE: %d materiali, %d vedute" % [k_sig, righe.size() - 1])
	get_tree().quit()


func _tex(t: Texture2D) -> String:
	return t.resource_path if t and t.resource_path != "" else ""


func _firma(m: Material) -> String:
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		var al := _tex(b.albedo_texture)
		return ("std|" + al + "|" + _tex(b.normal_texture)) if al != "" else ""
	if m is ShaderMaterial and (m as ShaderMaterial).shader:
		var sm := m as ShaderMaterial
		var tt := PackedStringArray()
		for u in sm.shader.get_shader_uniform_list():
			var val = sm.get_shader_parameter(u.name)
			if val is Texture2D and _tex(val) != "" and not "shader_tex" in _tex(val):
				tt.append(_tex(val))
		tt.sort()
		return ("sh|" + sm.shader.resource_path + "|" + ",".join(tt)) if tt.size() else ""
	return ""


func _info(m: Material) -> Dictionary:
	var d := {"nome": m.resource_name}
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		d["albedo"] = _tex(b.albedo_texture)
		d["normal"] = _tex(b.normal_texture) if b.normal_enabled else ""
		d["normal_scale"] = b.normal_scale
		d["roughness"] = _tex(b.roughness_texture)
		d["uv1_scale"] = b.uv1_scale.x
		d["triplanare"] = b.uv1_triplanar
		d["colore"] = b.albedo_color.to_html()
	elif m is ShaderMaterial:
		var sm := m as ShaderMaterial
		d["shader"] = sm.shader.resource_path
		var par := {}
		for u in sm.shader.get_shader_uniform_list():
			var val = sm.get_shader_parameter(u.name)
			par[u.name] = _tex(val) if val is Texture2D else str(val)
		d["parametri"] = par
	return d
