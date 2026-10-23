class_name RisorseNodi
## I file di risorse (scene, modelli, materiali, texture, shader) che usa una parte del livello già costruita:
## le scene dei nodi istanziati e le risorse nelle proprietà dei nodi, con quelle dentro (i materiali delle mesh,
## le loro texture...). Serve a caricare quei file in un thread prima di costruire la parte, così il suo _ready
## (che li carica con load()) non ferma il gioco (risalita_gioco.gd).


## I materiali delle geometrie di [param radice] (con i next_pass), per chiave dello shader ([method chiave_shader]):
## aggiunge a [param out] chiave -> materiale (il primo trovato).
static func materiali_per_shader(radice: Node, out: Dictionary) -> void:
	for n in [radice] + radice.find_children("*", "GeometryInstance3D", true, false):
		if not n is GeometryInstance3D:
			continue
		var g := n as GeometryInstance3D
		var mats: Array = [g.material_override, g.material_overlay]
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			for i in (g as MeshInstance3D).mesh.get_surface_count():
				mats.append((g as MeshInstance3D).get_active_material(i))
		for m in mats:
			while m:
				var k := chiave_shader(m)
				if k != "" and not out.has(k):
					out[k] = m
				m = (m as Material).next_pass


## Quello che decide lo shader di un materiale: per un BaseMaterial3D le funzioni, i flag e i modi accesi (come la
## chiave di Godot: due materiali con la stessa chiave usano lo stesso shader), per uno ShaderMaterial il suo shader.
static func chiave_shader(m: Material) -> String:
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		return ("sh:" + (sh.resource_path if sh.resource_path != "" else str(sh.code.hash()))) if sh else ""
	if not m is BaseMaterial3D:
		return ""
	var b := m as BaseMaterial3D
	var f := [b.get_class(), b.transparency, b.shading_mode, b.cull_mode, b.blend_mode, b.depth_draw_mode, b.diffuse_mode,
		b.specular_mode, b.billboard_mode, b.texture_filter, b.texture_repeat, b.roughness_texture_channel,
		b.metallic_texture_channel, b.emission_operator, b.detail_blend_mode, b.alpha_antialiasing_mode,
		b.distance_fade_mode, b.proximity_fade_enabled, b.vertex_color_use_as_albedo, b.vertex_color_is_srgb,
		b.depth_test, b.stencil_mode]
	for i in BaseMaterial3D.FEATURE_MAX:
		f.append(int(b.get_feature(i)))
	for i in BaseMaterial3D.FLAG_MAX:
		f.append(int(b.get_flag(i)))
	return str(f)


## Aggiunge a [param out] (percorso -> true) i file usati da [param radice] e dai suoi discendenti.
static func raccogli(radice: Node, out: Dictionary) -> void:
	var viste := {}
	for n in [radice] + radice.find_children("*", "", true, false):
		if n.scene_file_path != "":
			out[n.scene_file_path] = true
		_proprieta(n, out, viste)


static func _proprieta(o: Object, out: Dictionary, viste: Dictionary) -> void:
	if o is Mesh:
		# (non le proprietà: copierebbero tutti i vertici) solo i materiali delle superfici
		for i in (o as Mesh).get_surface_count():
			_valore((o as Mesh).surface_get_material(i), out, viste)
		return
	if o is Texture or o is Image or o is Shape3D or o is Animation or o is AudioStream:
		return
	for pr in o.get_property_list():
		if pr.type != TYPE_OBJECT and pr.type != TYPE_ARRAY and pr.type != TYPE_DICTIONARY:
			continue
		if pr.name == "script" or pr.name == "owner":
			continue
		_valore(o.get(pr.name), out, viste)


static func _valore(v: Variant, out: Dictionary, viste: Dictionary) -> void:
	if v is Array:
		for x in v:
			_valore(x, out, viste)
	elif v is Dictionary:
		for x in (v as Dictionary).values():
			_valore(x, out, viste)
	elif v is Resource and not (v is Script):
		var r := v as Resource
		if viste.has(r):
			return
		viste[r] = true
		var p := r.resource_path
		if p.begins_with("res://") and not p.contains("::"):
			out[p] = true
		_proprieta(r, out, viste)
