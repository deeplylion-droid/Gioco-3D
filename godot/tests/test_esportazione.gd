extends Node
## Test automatico: i filtri di esclusione dei preset di esportazione (export_presets.cfg) non lasciano
## fuori dal pacchetto niente che serva al gioco.
## 1. nessuna risorsa che resta nel pacchetto (scene, materiali, modelli importati) dipende da un file
##    escluso (ResourceLoader.get_dependencies, senza caricare niente);
## 2. nessuno script che resta nel pacchetto nomina un file escluso ("res://...").
## (Le texture doppie le toglie il plugin EsportaSenzaDoppioni al momento dell'esportazione, con un
## rimando alla copia che resta: lo controlla tools/verifica_pck.py sul pacchetto vero.)
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_esportazione.gd

var _passed := 0
var _failed := 0
var _filtri := {}


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _run() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	for s in cfg.get_sections():
		if cfg.has_section_key(s, "exclude_filter"):
			_filtri[cfg.get_value(s, "name")] = (cfg.get_value(s, "exclude_filter") as String).split(",", false)
	check(not _filtri.is_empty(), "ci sono i preset (%s)" % ", ".join(_filtri.keys()))
	var file: Array[String] = []
	_cerca(file, "res://")
	for preset in _filtri:
		var filtri: PackedStringArray = _filtri[preset]
		print("Preset ", preset)
		var dentro := file.filter(func(f): return not _escluso(f, filtri))
		var risorse_rotte := PackedStringArray()
		var script_rotti := PackedStringArray()
		for f: String in dentro:
			if f.get_extension() == "gd":
				for m in RegEx.create_from_string("res://[^\"'\\s]+").search_all(FileAccess.get_file_as_string(f)):
					var p := m.get_string()
					if _escluso(p, filtri) and FileAccess.file_exists(p):
						script_rotti.append("%s -> %s" % [f, p])
			elif ResourceLoader.exists(f):
				for dep in ResourceLoader.get_dependencies(f):
					var p := dep.get_slice("::", 2) if dep.contains("::") else dep
					if p.begins_with("uid://"):
						var id := ResourceUID.text_to_id(p)
						p = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else p
					if _escluso(p, filtri):
						risorse_rotte.append("%s -> %s" % [f, p])
		for r in risorse_rotte:
			printerr("    ", r)
		for r in script_rotti:
			printerr("    ", r)
		check(risorse_rotte.is_empty(), "%d file nel pacchetto: nessuna risorsa usa un file escluso" % dentro.size())
		check(script_rotti.is_empty(), "nessuno script nomina un file escluso")
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _escluso(p: String, filtri: PackedStringArray) -> bool:
	var rel := p.trim_prefix("res://")
	for f in filtri:
		if rel.match(f.strip_edges()):
			return true
	return false


func _cerca(out: Array[String], dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_cerca(out, dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		if not (f.ends_with(".import") or f.ends_with(".uid")):
			out.append(dir.path_join(f))
