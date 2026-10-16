extends SceneTree
## Conta le varianti di shader di una scena, per zona: ogni combinazione diversa di shader (o di
## caratteristiche di un BaseMaterial3D) e di formato dei vertici diventa una pipeline in più.
## Headless, leggero: godot --headless --path godot --script res://tests/conta_varianti.gd -- [scena]

var _per_zona := {}     # zona -> {firma: true}
var _tutte := {}        # firma -> [zone]
var _materiali := {}    # zona -> {materiale (rid): true}
static var _descr := {}  # firma breve -> descrizione leggibile


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 and args[0].begins_with("res://") or args.size() > 0 and args[0].begins_with("user://") else "res://scenes/sala_principale.tscn"
	var level := (load(path) as PackedScene).instantiate()
	if OS.get_cmdline_user_args().has("unifica"):
		print("VARIANTI unificati: ", load("res://scripts/rendering/unifica_materiali.gd").unifica(level))
		for d in level.find_children("*", "Node3D", true, false):
			var modelli = d.get(&"modelli")
			if modelli is Array:
				for ps in modelli:
					if ps is PackedScene:
						var inst := (ps as PackedScene).instantiate()
						load("res://scripts/rendering/unifica_materiali.gd").unifica(inst)
						inst.free()
	for c in level.get_children():
		if String(c.name) == "Sala":
			for cc in c.get_children():
				_visita(cc, "Sala/" + String(cc.name))
		else:
			_visita(c, String(c.name))
	print("VARIANTI zona;firme;materiali")
	var zone := _per_zona.keys()
	zone.sort()
	for z in zone:
		print("VARIANTI %s;%d;%d" % [z, _per_zona[z].size(), _materiali.get(z, {}).size()])
	var condivise := 0
	for f in _tutte:
		if _tutte[f].size() > 1:
			condivise += 1
	print("VARIANTI TOTALE;%d;condivise fra zone %d" % [_tutte.size(), condivise])
	if OS.get_cmdline_user_args().has("dettaglio"):
		for f in _tutte:
			var h: String = f.get_slice("|", 0).get_slice(":", 1)
			print("FIRMA %s | zone %s | %s" % [f, ",".join(_tutte[f]), _descr.get(h, "")])
	level.free()
	quit()


func _visita(n: Node, zona: String) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false) + ([n] if n is GeometryInstance3D else []):
		_geometria(g as GeometryInstance3D, zona)
	# I dettagli si creano all'avvio (MultiMesh): si contano i loro modelli.
	for d in n.find_children("*", "Node3D", true, false) + [n]:
		var modelli = d.get(&"modelli")
		if modelli is Array:
			for ps in modelli:
				if ps is PackedScene:
					var inst := (ps as PackedScene).instantiate()
					for g in inst.find_children("*", "GeometryInstance3D", true, false):
						_geometria(g as GeometryInstance3D, zona, not OS.get_cmdline_user_args().has("dettagli_come_mesh"))
					inst.free()


func _geometria(g: GeometryInstance3D, zona: String, multimesh := false) -> void:
	var mesh: Mesh = null
	if g is MeshInstance3D:
		mesh = (g as MeshInstance3D).mesh
	elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
		mesh = (g as MultiMeshInstance3D).multimesh.mesh
	if mesh == null:
		return
	for s in mesh.get_surface_count():
		var mat: Material = g.material_override
		if mat == null and g is MeshInstance3D:
			mat = (g as MeshInstance3D).get_surface_override_material(s)
		if mat == null:
			mat = mesh.surface_get_material(s)
		var fmt := 0
		if mesh is ArrayMesh:
			fmt = (mesh as ArrayMesh).surface_get_format(s) & 0xFFFF  # attributi presenti
		var firma := "%s|f%d|mm%d|sk%d" % [_firma_materiale(mat), fmt, int(multimesh or g is MultiMeshInstance3D),
			int(g is MeshInstance3D and (g as MeshInstance3D).skeleton != NodePath())]
		_aggiungi(zona, firma, mat)


func _aggiungi(zona: String, firma: String, mat: Material) -> void:
	if not _per_zona.has(zona):
		_per_zona[zona] = {}
		_materiali[zona] = {}
	_per_zona[zona][firma] = true
	if mat:
		_materiali[zona][mat.get_rid()] = true
	if not _tutte.has(firma):
		_tutte[firma] = []
	if not _tutte[firma].has(zona):
		_tutte[firma].append(zona)


static func _firma_materiale(m: Material) -> String:
	if m == null:
		return "nessuno"
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		return "shader:" + (sh.resource_path if sh and sh.resource_path != "" else str(sh.get_instance_id() if sh else 0))
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		var parti := PackedStringArray()
		for p in b.get_property_list():
			var nome: String = p.name
			var tipo: int = p.type
			if nome.begins_with("resource_") or nome == "script":
				continue
			var v = b.get(nome)
			if tipo == TYPE_BOOL or (tipo == TYPE_INT and (p.hint == PROPERTY_HINT_ENUM or nome.ends_with("_mode") or nome.ends_with("_channel"))):
				parti.append("%s=%s" % [nome, v])
			elif tipo == TYPE_OBJECT and v is Texture:
				parti.append(nome)
		var h := ",".join(parti).sha256_text().substr(0, 8)
		if OS.get_cmdline_user_args().has("dettaglio") and not _descr.has(h):
			_descr[h] = _sintesi(b)
		return "base:" + h
	return m.get_class()


static func _sintesi(b: BaseMaterial3D) -> String:
	var t := PackedStringArray()
	for nome in ["albedo_texture", "normal_texture", "orm_texture", "roughness_texture", "metallic_texture",
			"emission_texture", "ao_texture", "heightmap_texture", "detail_albedo", "subsurf_scatter_texture"]:
		if b.get(nome) != null:
			t.append(nome.get_slice("_", 0))
	var f := PackedStringArray()
	for nome in ["transparency", "cull_mode", "shading_mode", "vertex_color_use_as_albedo", "emission_enabled",
			"normal_enabled", "ao_enabled", "rim_enabled", "clearcoat_enabled", "subsurf_scatter_enabled",
			"backlight_enabled", "refraction_enabled", "detail_enabled", "texture_filter", "uv1_triplanar",
			"metallic_texture_channel", "roughness_texture_channel", "alpha_antialiasing_mode", "depth_draw_mode", "no_depth_test"]:
		var v = b.get(nome)
		if (v is bool and v) or (v is int and v != 0):
			f.append("%s=%s" % [nome, v])
	return "%s [%s] tex:%s" % [b.get_class(), ",".join(f), "+".join(t)]
