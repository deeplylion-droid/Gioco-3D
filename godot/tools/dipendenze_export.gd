extends SceneTree
## Quali file del progetto carica davvero il gioco: parte dalla scena principale, dagli autoload, dalle
## risorse del project.godot e da ogni percorso "res://..." scritto negli script e nelle scene raggiunte, e
## segue le dipendenze (ResourceLoader.get_dependencies) fino in fondo. Stampa le cartelle con dentro
## file che il gioco non raggiunge mai, con il loro peso: sono quelle da escludere dall'export.
## I percorsi costruiti a pezzi negli script (per esempio "res://audio/" + nome) non si vedono: per
## questo ogni cartella di cui lo script usa un prefisso letterale ("res://cartella/") conta come usata.
## Uso: godot --headless --path godot --script res://tools/dipendenze_export.gd [-- --tutti]

const SALTA := ["res://.godot", "res://tests", "res://tools", "res://audio/anteprima"]

var _visti := {}
var _prefissi := {}
var _coda: Array[String] = []


func _initialize() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://project.godot")
	_aggiungi(String(cfg.get_value("application", "run/main_scene", "")))
	for k in cfg.get_section_keys("autoload") if cfg.has_section("autoload") else []:
		_aggiungi(String(cfg.get_value("autoload", k)).trim_prefix("*"))
	# gli script con class_name si usano anche solo per nome (Paratia, Ladder...): tutti dentro
	var classi := ConfigFile.new()
	if classi.load("res://.godot/global_script_class_cache.cfg") == OK:
		for c in classi.get_value("", "list", []):
			_aggiungi(String(c.get("path", "")))
	# ogni stringa res:// nel project.godot (icone, bus audio, temi...)
	_cerca_percorsi(FileAccess.get_file_as_string("res://project.godot"))
	while not _coda.is_empty():
		var p: String = _coda.pop_back()
		if p.ends_with(".gd") or p.ends_with(".tscn") or p.ends_with(".tres") or p.ends_with(".gdshader") \
				or p.ends_with(".gdshaderinc") or p.ends_with(".json") or p.ends_with(".cfg"):
			_cerca_percorsi(FileAccess.get_file_as_string(p))
		if ResourceLoader.exists(p):
			for d in ResourceLoader.get_dependencies(p):
				var dp: String = d.get_slice("::", 2) if d.contains("::") else d
				if dp.begins_with("uid://"):
					var id := ResourceUID.text_to_id(dp)
					dp = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
				_aggiungi(dp)
	var tutti := []
	_elenca("res://", tutti)
	var per_cartella := {}
	for f in tutti:
		var usato: bool = _visti.has(f) or _visti.has(f.trim_suffix(".import")) or _prefisso_usato(f)
		var dir: String = f.get_base_dir()
		if not per_cartella.has(dir):
			per_cartella[dir] = [0, 0, 0, 0]   # usati, non usati, byte usati, byte non usati
		var peso := _peso(f)
		var c: Array = per_cartella[dir]
		if usato:
			c[0] += 1; c[2] += peso
		else:
			c[1] += 1; c[3] += peso
	print("raggiunti dal gioco: %d file" % _visti.size())
	var righe := []
	for dir in per_cartella:
		var c: Array = per_cartella[dir]
		if c[1] > 0:
			righe.append([c[3], dir, c[0], c[1]])
	righe.sort_custom(func(a, b): return a[0] > b[0])
	for r in righe:
		print("%8.1f MB non usati  %s  (%d usati, %d no)" % [r[0] / 1e6, r[1], r[2], r[3]])
	if "--tutti" in OS.get_cmdline_user_args():
		for f in tutti:
			if not (_visti.has(f) or _visti.has(f.trim_suffix(".import")) or _prefisso_usato(f)):
				print("NON USATO ", f)
	quit()


func _aggiungi(p: String) -> void:
	if p == "" or not p.begins_with("res://") or _visti.has(p):
		return
	if p.ends_with("/"):
		_prefissi[p] = true
		return
	_visti[p] = true
	_coda.append(p)


func _cerca_percorsi(testo: String) -> void:
	var re := RegEx.new()
	re.compile("res://[^\"'\\s)\\]]*")
	for m in re.search_all(testo):
		var p := m.get_string()
		if p.ends_with("/"):
			_prefissi[p] = true
		elif FileAccess.file_exists(p) or ResourceLoader.exists(p):
			_aggiungi(p)
		else:
			# un pezzo di percorso ("res://audio/tecnici/" + nome): conta come prefisso
			_prefissi[p] = true


func _prefisso_usato(f: String) -> bool:
	for pre in _prefissi:
		if f.begins_with(pre) and (pre.ends_with("/") or pre.length() > 12):
			return true
	return false


func _elenca(dir: String, out: Array) -> void:
	for s in SALTA:
		if dir.begins_with(s):
			return
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".uid"):
			continue
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		_elenca(dir.path_join(sub), out)


func _peso(f: String) -> int:
	# per i file importati conta il file importato (quello che finisce nel PCK)
	if FileAccess.file_exists(f + ".import"):
		var cfg := ConfigFile.new()
		if cfg.load(f + ".import") == OK:
			var dest := String(cfg.get_value("remap", "path", ""))
			if dest == "":
				for k in cfg.get_section_keys("remap") if cfg.has_section("remap") else []:
					if String(k).begins_with("path"):
						dest = String(cfg.get_value("remap", k))
						break
			if dest != "" and FileAccess.file_exists(dest):
				var fa := FileAccess.open(dest, FileAccess.READ)
				return fa.get_length() if fa else 0
		return 0
	if f.ends_with(".import"):
		return 0
	var fa2 := FileAccess.open(f, FileAccess.READ)
	return fa2.get_length() if fa2 else 0
