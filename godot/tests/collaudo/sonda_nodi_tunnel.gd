extends Node
## Ricontrollo dei passi lunghi del tunnel (#149, enigmi): tutto quello che la costruzione mette in scena, con tutte le
## proprietà salvabili di ogni nodo (non una scelta): trasformazione nel mondo, visibilità, strati, maschere, luci
## (colore, energia, portata, attenuazione, ombre, maschere...), collisioni (strati, maschere, forme coi loro dati),
## mesh (i dati di ogni superficie, coi materiali e i loro parametri), MultiMesh (le istanze). Le risorse si scrivono
## come impronta md5 del loro contenuto (ricorsivo), con il percorso se vengono da un file.
## Una riga per nodo: il percorso coi nomi (i nomi automatici @Classe@N senza il numero), la classe, le proprietà.
## Modi:
##   prova pezzi|subito <file>: la scena di prova del tunnel (scenes/test/sottomarino_prova.tscn), costruito a pezzi
##     (6 ms per fotogramma, come la sonda di ambienti-2) o tutto insieme;
##   gioco inseguimento|tunnel <prefisso>: il gioco vero dalla partenza F9; quando il tunnel è costruito e pronto
##     scrive <prefisso>_tunnel.txt e, se c'è, <prefisso>_torre.txt (la sala della torre con le condotte).
## Di quello che si muove da solo (i gommoni che galleggiano, lei, i corpi rigidi) non si scrive la posizione.
## Uso: godot --headless --path godot --script res://tests/run.gd -- <questo> <modo> ...

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"
const SALTA := ["script", "transform", "position", "rotation", "rotation_degrees", "quaternion", "basis", "scale",
		"global_transform", "global_position", "global_rotation", "global_rotation_degrees", "global_basis",
		"unique_name_in_owner", "scene_file_path", "editor_description", "process_mode", "process_priority",
		"process_physics_priority", "process_thread_group", "process_thread_group_order", "process_thread_messages",
		"physics_interpolation_mode", "auto_translate_mode", "multiplayer"]
var _cache := {}
var _in_corso := {}
var _radice: Node


func _ready() -> void:
	_run.call_deferred()


static func _nome(n: Node) -> String:
	var s := String(n.name)
	if s.begins_with("@"):
		var parti := s.split("@")
		return "@" + (parti[1] if parti.size() > 1 else "")
	return s


func _md5(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	h.update(b)
	return h.finish().hex_encode().substr(0, 12)


func _f(x: float) -> String:
	var s := "%.4f" % x
	return "0.0000" if s == "-0.0000" else s


func _val(v: Variant, prof := 0) -> String:
	match typeof(v):
		TYPE_NIL:
			return "nil"
		TYPE_FLOAT:
			return _f(v)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR, TYPE_QUATERNION, TYPE_PLANE:
			var out: PackedStringArray = []
			var n := 4 if typeof(v) in [TYPE_VECTOR4, TYPE_COLOR, TYPE_QUATERNION, TYPE_PLANE] else (3 if typeof(v) == TYPE_VECTOR3 else 2)
			for i in n:
				out.append(_f(v[i]) if typeof(v) != TYPE_PLANE else _f([v.normal.x, v.normal.y, v.normal.z, v.d][i]))
			return "(" + ",".join(out) + ")"
		TYPE_BASIS:
			return "[%s %s %s]" % [_val(v.x), _val(v.y), _val(v.z)]
		TYPE_TRANSFORM3D:
			return "[%s %s]" % [_val(v.basis), _val(v.origin)]
		TYPE_AABB:
			return "[%s %s]" % [_val(v.position), _val(v.size)]
		TYPE_OBJECT:
			if v == null or not is_instance_valid(v):
				return "nil"
			if v is Node:
				return "nodo:" + (str(_radice.get_path_to(v)) if _radice and (v as Node).is_inside_tree() and _radice.is_inside_tree() else String((v as Node).name))
			if v is Resource:
				return _risorsa(v, prof)
			return "oggetto:" + (v as Object).get_class()
		TYPE_ARRAY, TYPE_DICTIONARY:
			if prof > 4:
				return "..."
			# (gli oggetti dentro, per esempio i materiali, con la loro impronta e non col loro numero di istanza)
			var out: PackedStringArray = []
			if typeof(v) == TYPE_ARRAY:
				if (v as Array).size() > 4000:
					return "md5:" + _md5(var_to_bytes(v))
				for x in v:
					out.append(_val(x, prof + 1))
				var testo := "[" + ",".join(out) + "]"
				return testo if (v as Array).size() <= 8 else "%d:md5:%s" % [(v as Array).size(), _md5(testo.to_utf8_buffer())]
			var chiavi := (v as Dictionary).keys()
			chiavi.sort_custom(func(x, y): return str(x) < str(y))
			for k in chiavi:
				out.append("%s:%s" % [str(k), _val(v[k], prof + 1)])
			return "{md5:" + _md5(",".join(out).to_utf8_buffer()) + "}"
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return "%d:md5:%s" % [v.size(), _md5(var_to_bytes(v))]
	return str(v)


## Una risorsa: il percorso (se da file) e l'impronta del contenuto (le proprietà salvabili, e per le mesh i dati di
## ogni superficie).
func _risorsa(r: Resource, prof: int) -> String:
	var id := r.get_instance_id()
	if _cache.has(id):
		return _cache[id]
	if _in_corso.has(id) or prof > 6:
		return r.get_class() + ":ciclo"
	_in_corso[id] = true
	var parti: PackedStringArray = [r.get_class()]
	if r is Texture2D and not (r is ImageTexture or r is NoiseTexture2D or r is GradientTexture1D or r is GradientTexture2D):
		parti.append("%dx%d" % [(r as Texture2D).get_width(), (r as Texture2D).get_height()])
	elif r is ImageTexture:
		var img := (r as ImageTexture).get_image()
		parti.append("%dx%d:%s" % [img.get_width(), img.get_height(), _md5(img.get_data()) if img.get_width() * img.get_height() <= 1 << 20 else "grande"])
	elif r is Mesh and not (r is PrimitiveMesh):
		var m := r as Mesh
		for i in m.get_surface_count():
			parti.append("s%d:%s:%s" % [i, _md5(var_to_bytes(m.surface_get_arrays(i))), _val(m.surface_get_material(i), prof + 1)])
		if m is ArrayMesh:
			parti.append("aabb:" + _val((m as ArrayMesh).custom_aabb) + " forme:%d" % (m as ArrayMesh).get_blend_shape_count())
	else:
		for p in r.get_property_list():
			var nome := String(p.name)
			if not (int(p.usage) & PROPERTY_USAGE_STORAGE) or nome in ["script", "resource_local_to_scene", "resource_name", "resource_path", "resource_scene_unique_id"]:
				continue
			parti.append("%s=%s" % [nome, _val(r.get(nome), prof + 1)])
	var testo := " ".join(parti)
	var out := "%s%s#%s" % [r.get_class(), "(" + r.resource_path + ")" if r.resource_path != "" and not r.resource_path.contains("::") else "", _md5(testo.to_utf8_buffer())]
	_in_corso.erase(id)
	_cache[id] = out
	return out


func _si_muove(via: String, n: Node) -> bool:
	if via.begins_with("Gommoni/") or via.begins_with("LeiTunnel") or via.contains("/Lei") or via.begins_with("Lei"):
		return true
	var x := n
	while x and x != _radice:
		if x is RigidBody3D or x is CharacterBody3D or x is AnimatableBody3D:
			return true
		x = x.get_parent()
	return false


func _scrivi(radice: Node, file: String) -> void:
	_radice = radice
	var righe: PackedStringArray = []
	var ordine: PackedStringArray = []
	for n in radice.find_children("*", "", true, false):
		var percorso: PackedStringArray = []
		var x: Node = n
		while x != radice:
			percorso.append(_nome(x))
			x = x.get_parent()
		percorso.reverse()
		var via := "/".join(percorso)
		ordine.append(via)
		var r := "%s %s" % [via, n.get_class()]
		var muove := _si_muove(via, n)
		if n is Node3D and not muove:
			r += " mondo=%s" % _val((n as Node3D).global_transform)
		for p in n.get_property_list():
			var nome := String(p.name)
			if not (int(p.usage) & PROPERTY_USAGE_STORAGE) or nome in SALTA:
				continue
			if muove and nome in ["linear_velocity", "angular_velocity", "sleeping", "velocity"]:
				continue
			r += " %s=%s" % [nome, _val(n.get(nome))]
		righe.append(r)
	righe.sort()
	var testo := "\n".join(righe)
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string(testo)
	f.close()
	var f2 := FileAccess.open(file.get_basename() + "_ordine.txt", FileAccess.WRITE)
	f2.store_string("\n".join(ordine))
	f2.close()
	print("NODI %s: %d nodi, md5 %s (ordine %s) -> %s" % [radice.name, righe.size(), testo.md5_text(), "\n".join(ordine).md5_text(), file])


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var dove := a[1] if a.size() > 1 else "prova"
	var modo := a[2] if a.size() > 2 else "pezzi"
	var file := a[3] if a.size() > 3 else "user://nodi"
	var t0 := Time.get_ticks_msec()
	if dove == "prova":
		get_tree().change_scene_to_file(LEVEL)
		for i in 600:
			await get_tree().process_frame
			if GameState.player and is_instance_valid(GameState.player):
				break
		for i in 10:
			await get_tree().process_frame
		var sott := get_tree().current_scene.get_node("SalaSottomarino") as SalaSottomarino
		if modo == "subito":
			sott.costruisci()
		else:
			await sott.costruisci_a_pezzi(6.0)
		for i in 5:
			await get_tree().process_frame
		_scrivi(sott, file)
	else:
		MenuProva.parti(get_tree(), modo)
		var tun: Node3D = null
		while Time.get_ticks_msec() - t0 < 900000:
			await get_tree().process_frame
			var s := get_tree().current_scene
			tun = s.get(&"sala_sottomarino") if s and &"sala_sottomarino" in s else null
			if is_instance_valid(tun) and bool(tun.get(&"costruita")) and AttesaZone.e_pronta(&"tunnel") and GameState.player and GameState.player.input_enabled:
				break
		for i in 30:
			await get_tree().process_frame
		# (ATTESA_IN_PIU=secondi: si aspetta ancora, per vedere cosa cambia da solo col tempo nelle condotte)
		var in_piu := float(OS.get_environment("ATTESA_IN_PIU")) if OS.has_environment("ATTESA_IN_PIU") else 0.0
		var ta := Time.get_ticks_msec()
		while Time.get_ticks_msec() - ta < in_piu * 1000.0:
			await get_tree().process_frame
		var s := get_tree().current_scene
		print("NODI: tunnel costruito e pronto dopo %.1f s (checkpoint %s)" % [(Time.get_ticks_msec() - t0) / 1000.0, GameState.snapshot.get("checkpoint", "")])
		if is_instance_valid(tun):
			_scrivi(tun, file + "_tunnel.txt")
		var torre: Node = s.get(&"sala_torre") if s and &"sala_torre" in s else null
		if is_instance_valid(torre):
			_scrivi(torre, file + "_torre.txt")
		else:
			print("NODI: la torre non c'è")
	print("NODI: FINE dopo %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit()
