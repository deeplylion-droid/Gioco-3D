extends Node
## Collaudo: quanta memoria video prende ogni zona (per chi gioca con una scheda da 4 GB), da confrontare fra due
## versioni. Senza disegnare (headless): conta quello che va nella scheda, cioè le texture uniche come sono importate
## (compresse o no, mipmap comprese; RGB8 contata come RGBA8, com'è nella scheda) e i buffer delle mesh e delle
## multimesh uniche (stima: vertici, indici, pesi delle ossa, forme). Non conta i buffer del disegno (schermo,
## ombre, nebbia, riflessi), che dipendono da risoluzione e qualità. Le texture si trovano da qualunque risorsa raggiungibile dai nodi (materiali, anche i
## parametri degli shader, mesh, particelle, ambiente, decal), non solo dai materiali standard.
## Zone:
##   sala          la sala principale come all'avvio (le stanze della Risalita non ancora caricate)
##   risalita      la sala principale con le stanze della Risalita caricate subito
##   torre         la sala della torre da sola
##   inseguimento  la sala dell'inseguimento da sola
##   tutto         la sala con le stanze e la torre insieme (il massimo che può stare in memoria nella demo)
##   res://...     una scena o un modello qualunque, da solo (per esempio quelli che si caricano durante il gioco)
## Stampa: i totali, le parti (figli diretti) più pesanti e le texture più grandi, con chi le usa.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/memoria_video.gd <zona>

const SALA := "res://scenes/sala_principale.tscn"
const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
const INSEGUIMENTO := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"

var _visti := {}          # instance id -> true (risorse già guardate in questo conteggio)
var _texture := {}        # instance id -> [MB, descrizione, {parti}]
var _mesh := {}           # instance id -> MB
var _parte := ""


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var zona: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "sala"
	var radici: Array[Node] = []
	if zona in ["sala", "risalita", "tutto"]:
		if zona != "sala":
			Engine.set_meta(&"risalita_subito", true)
		get_tree().change_scene_to_file(SALA)
		for i in 600:
			await get_tree().process_frame
			if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
				break
		for i in 60:
			await get_tree().process_frame
		radici.append(get_tree().current_scene)
	if zona in ["torre", "inseguimento", "tutto"] or zona.begins_with("res://"):
		var file := zona if zona.begins_with("res://") else (TORRE if zona != "inseguimento" else INSEGUIMENTO)
		var n := (load(file) as PackedScene).instantiate()
		get_tree().root.add_child(n)
		for i in 30:
			await get_tree().process_frame
		radici.append(n)
	# per parte (figli diretti delle radici): quello che porta in più rispetto alle parti già contate non si sa
	# dire (le texture condivise); qui ogni parte si conta da sola, il totale le conta una volta sola
	var parti := []
	for r in radici:
		for c in r.get_children():
			_visti.clear()
			var t0 := _texture.duplicate()
			var m0 := _mesh.duplicate()
			_texture.clear()
			_mesh.clear()
			_parte = "%s/%s" % [r.name, c.name]
			_nodo(c)
			parti.append([_parte, _somma(_texture), _somma(_mesh), _texture.size()])
			# rimette insieme al totale
			for k in _texture:
				if t0.has(k):
					(t0[k][2] as Dictionary).merge(_texture[k][2])
				else:
					t0[k] = _texture[k]
			m0.merge(_mesh)
			_texture = t0
			_mesh = m0
	var tex_mb := _somma(_texture)
	var mesh_mb := _somma(_mesh)
	print("ZONA %s: texture %.0f MB (%d uniche), mesh %.0f MB (%d uniche), totale %.0f MB" % [zona, tex_mb, _texture.size(),
		mesh_mb, _mesh.size(), tex_mb + mesh_mb])
	var non_compresse := 0.0
	for k in _texture:
		if String(_texture[k][1]).contains("non compressa"):
			non_compresse += float(_texture[k][0])
	print("  di cui texture non compresse: %.0f MB" % non_compresse)
	parti.sort_custom(func(a, b): return a[1] + a[2] > b[1] + b[2])
	print("PARTI (ognuna da sola) | texture MB | mesh MB | texture")
	for p in parti.slice(0, 15):
		if p[1] + p[2] >= 1.0:
			print("  %s | %.0f | %.0f | %d" % p)
	var lista := _texture.keys()
	lista.sort_custom(func(a, b): return _texture[a][0] > _texture[b][0])
	print("TEXTURE PIÙ GRANDI | MB | com'è | usata da")
	for k in lista.slice(0, 25):
		var usa: Array = (_texture[k][2] as Dictionary).keys()
		print("  %.1f | %s | %s" % [_texture[k][0], _texture[k][1], ", ".join(usa.slice(0, 3)) + (" e altre %d" % (usa.size() - 3) if usa.size() > 3 else "")])
	print("memoria statica di Godot (RAM) %.0f MB" % (OS.get_static_memory_usage() / 1e6))
	get_tree().quit()


func _somma(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		var v = d[k]
		s += float(v[0]) if v is Array else float(v)
	return s


func _nodo(n: Node) -> void:
	for pr in n.get_property_list():
		if pr["type"] != TYPE_OBJECT:
			continue
		var v = n.get(pr["name"])
		if v is Resource:
			_risorsa(v)
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(s)
			if m:
				_risorsa(m)
	for c in n.get_children():
		_nodo(c)


func _risorsa(r: Resource) -> void:
	var id := r.get_instance_id()
	if _visti.has(id):
		if r is Texture2D and _texture.has(id):
			_texture[id][2][_parte] = true
		return
	_visti[id] = true
	if r is PackedScene or r is Script or r is Animation or r is AudioStream:
		return
	if r is Texture:
		_tex(r as Texture)
	elif r is Mesh:
		_mesh_mb(r as Mesh)
		for s in (r as Mesh).get_surface_count():
			var m := (r as Mesh).surface_get_material(s)
			if m:
				_risorsa(m)
		return
	elif r is MultiMesh:
		var mm := r as MultiMesh
		_mesh[id] = mm.instance_count * (48 + (16 if mm.use_colors else 0) + (16 if mm.use_custom_data else 0)) / 1e6
	for pr in r.get_property_list():
		if pr["type"] != TYPE_OBJECT:
			continue
		var v = r.get(pr["name"])
		if v is Resource:
			_risorsa(v)
		elif v is Array:
			for e in v:
				if e is Resource:
					_risorsa(e)


func _tex(t: Texture) -> void:
	var id := t.get_instance_id()
	var mb := 0.0
	var com := ""
	if t is Texture2D and not (t is ViewportTexture) and not (t is AnimatedTexture):
		var img := (t as Texture2D).get_image()
		if img:
			mb = img.get_data_size() / 1e6
			# (nella scheda RGB8 non c'è: Godot la carica come RGBA8, un quarto in più)
			if img.get_format() == Image.FORMAT_RGB8:
				mb *= 4.0 / 3.0
			com = "%dx%d %s%s%s" % [img.get_width(), img.get_height(), _formato(img.get_format()),
				"" if img.is_compressed() else " non compressa", "" if img.has_mipmaps() else " senza mipmap"]
		else:
			com = "%dx%d (immagine non leggibile)" % [(t as Texture2D).get_width(), (t as Texture2D).get_height()]
	elif t is TextureLayered:
		var tl := t as TextureLayered
		for i in tl.get_layers():
			var img := tl.get_layer_data(i)
			if img:
				mb += img.get_data_size() / 1e6
		com = "%dx%d x%d strati %s" % [tl.get_width(), tl.get_height(), tl.get_layers(), _formato(tl.get_format())]
	elif t is Texture3D:
		var t3 := t as Texture3D
		for img in t3.get_data():
			mb += (img as Image).get_data_size() / 1e6
		com = "3D %dx%dx%d %s" % [t3.get_width(), t3.get_height(), t3.get_depth(), _formato(t3.get_format())]
	else:
		com = t.get_class()
	var nome := t.resource_path.get_file() if t.resource_path != "" else ("(%s senza file)" % t.get_class())
	_texture[id] = [mb, "%s, %s" % [nome, com], {_parte: true}]


func _formato(f: int) -> String:
	return ClassDB.class_get_enum_constants("Image", "Format")[f].trim_prefix("FORMAT_") if f >= 0 else "?"


## I buffer di una mesh come vanno nella scheda (stima): posizione 12 byte, normale e tangente 8, UV 8 (e 8 la
## seconda), colore 4, ossa e pesi 16, indici 2 o 4 byte; le forme (blend shape) di nuovo posizione e normale.
func _mesh_mb(m: Mesh) -> void:
	var byte := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		if a.size() <= Mesh.ARRAY_INDEX or a[Mesh.ARRAY_VERTEX] == null:
			continue
		var nv := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var passo := 12 + 8
		if a[Mesh.ARRAY_TEX_UV] != null:
			passo += 8
		if a[Mesh.ARRAY_TEX_UV2] != null:
			passo += 8
		if a[Mesh.ARRAY_COLOR] != null:
			passo += 4
		if a[Mesh.ARRAY_BONES] != null:
			passo += 16
		byte += nv * passo
		if a[Mesh.ARRAY_INDEX] != null:
			byte += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() * (2 if nv < 65536 else 4)
		if m is ArrayMesh:
			byte += (m as ArrayMesh).get_blend_shape_count() * nv * 20
	_mesh[m.get_instance_id()] = byte / 1e6
