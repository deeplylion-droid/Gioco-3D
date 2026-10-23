extends Node
## Collaudo: inventario dei materiali (per trovare quelli dei muri). Per ogni materiale delle mesh di una scena:
## texture, scala delle UV, triplanare, forza del normal (o i parametri dello shader), dove sta, e quanta area
## copre in verticale (muri) e in orizzontale.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/inventario_muri.gd \
##     <scena.tscn> <uscita.json> [fotogrammi da aspettare]

const STATI := preload("res://tests/collaudo/stati.gd")

var _mat := {}


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	Game.pause_on_focus_loss = false
	var livello := (load(a[1]) as PackedScene).instantiate()
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	var attesa := int(a[3]) if a.size() > 3 else 240
	for i in attesa:
		await get_tree().process_frame
	STATI.mostra_nascosti(livello)
	for i in 30:
		await get_tree().process_frame
	for n in livello.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var mesh: Mesh = null
		var xs: Array[Transform3D] = []
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
			xs.append(g.global_transform)
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
			var mm := (g as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			for i in mini(mm.instance_count, 2000):
				xs.append(g.global_transform * mm.get_instance_transform(i))
		if mesh == null:
			continue
		var percorso := String(livello.get_path_to(g))
		for s in mesh.get_surface_count():
			var m: Material = g.material_override
			if m == null and g is MeshInstance3D:
				m = (g as MeshInstance3D).get_active_material(s)
			if m == null:
				m = mesh.surface_get_material(s)
			if m == null:
				continue
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			var ii: PackedInt32Array = idx if idx != null else PackedInt32Array(range(v.size()))
			var av := 0.0
			var ao := 0.0
			var cv := Vector3.ZERO
			var maxv := 0.0
			var maxp := Vector3.ZERO
			var maxn := Vector3.ZERO
			for t in xs:
				for k in range(0, ii.size(), 3):
					var p0 := t * v[ii[k]]
					var cr := (t * v[ii[k + 1]] - p0).cross(t * v[ii[k + 2]] - p0)
					var ar := cr.length() * 0.5
					if ar <= 0.0:
						continue
					var ny := absf(cr.y) / (ar * 2.0)
					if ny < 0.35:
						av += ar
						cv += (p0 * ar)
						if ar > maxv:
							maxv = ar
							maxp = (p0 + t * v[ii[k + 1]] + t * v[ii[k + 2]]) / 3.0
							maxn = cr.normalized()
					else:
						ao += ar
			var chiave := "%s|%d" % [m.resource_path if m.resource_path != "" else m.resource_name, m.get_instance_id()]
			if not _mat.has(chiave):
				_mat[chiave] = {"materiale": _descrivi(m), "nodi": [], "area_verticale": 0.0, "area_orizzontale": 0.0,
						"punto": [], "normale": [], "max": 0.0}
			var e: Dictionary = _mat[chiave]
			if e["nodi"].size() < 12:
				e["nodi"].append(percorso + ("#%d" % s))
			e["area_verticale"] += av
			e["area_orizzontale"] += ao
			if maxv > float(e["max"]):
				e["max"] = maxv
				e["punto"] = [snappedf(maxp.x, 0.01), snappedf(maxp.y, 0.01), snappedf(maxp.z, 0.01)]
				e["normale"] = [snappedf(maxn.x, 0.01), snappedf(maxn.y, 0.01), snappedf(maxn.z, 0.01)]
	var out := FileAccess.open(a[2], FileAccess.WRITE)
	out.store_string(JSON.stringify(_mat.values(), " "))
	out.close()
	print("INVENTARIO: %d materiali" % _mat.size())
	get_tree().quit()


func _tex(t: Texture2D) -> String:
	if t == null:
		return ""
	return t.resource_path if t.resource_path != "" else ("%s %dx%d" % [t.resource_name if t.resource_name != "" else t.get_class(), t.get_width(), t.get_height()])


func _descrivi(m: Material) -> Dictionary:
	var d := {"nome": m.resource_name, "file": m.resource_path, "classe": m.get_class()}
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		d["albedo"] = _tex(b.albedo_texture)
		d["colore"] = b.albedo_color.to_html()
		d["normal"] = _tex(b.normal_texture) if b.normal_enabled else ""
		d["normal_scale"] = b.normal_scale
		d["roughness_tex"] = _tex(b.roughness_texture)
		d["roughness"] = b.roughness
		d["ao"] = _tex(b.ao_texture) if b.ao_enabled else ""
		d["uv1_scale"] = [b.uv1_scale.x, b.uv1_scale.y, b.uv1_scale.z]
		d["triplanare"] = b.uv1_triplanar
		d["triplanare_mondo"] = b.uv1_world_triplanar
		d["detail"] = _tex(b.detail_albedo) if b.detail_enabled else ""
	elif m is ShaderMaterial:
		var sm := m as ShaderMaterial
		d["shader"] = sm.shader.resource_path if sm.shader else ""
		var par := {}
		if sm.shader:
			for u in sm.shader.get_shader_uniform_list():
				var val = sm.get_shader_parameter(u.name)
				if val is Texture2D:
					par[u.name] = _tex(val)
				elif val is float or val is int or val is Vector2 or val is Vector3 or val is Color or val is bool:
					par[u.name] = str(val)
		d["parametri"] = par
	return d
