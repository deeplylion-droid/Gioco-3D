@tool
extends EditorExportPlugin
## Ogni GLB estrae le sue texture: la sala e la torre, per esempio, hanno decine di immagini uguali
## (stessi materiali), importate con le stesse impostazioni in file identici byte per byte. Nel pacchetto
## del gioco ne resta una copia sola: per i doppioni si scrive soltanto il file .import, che rimanda ai
## dati della prima copia. Il gioco carica gli stessi byte di prima, cambia solo il peso del pacchetto.
## I file esclusi dai filtri del preset non contano (né come doppioni né come copia che resta).
## Si confrontano i file importati (.ctex), non le immagini sorgenti: due immagini uguali importate con
## impostazioni diverse (per esempio un limite di risoluzione) restano tutte e due.
## Con il comando EXPORT_DOPPIONI_ELENCO nell'ambiente scrive l'elenco in quel file (per i test).

## sorgente del doppione -> sorgente della copia che resta
var _doppioni := {}
var _import_copia := {}


func _get_name() -> String:
	return "EsportaSenzaDoppioni"


func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	_doppioni.clear()
	_import_copia.clear()
	var formato := "s3tc" if features.has("s3tc") or not features.has("etc2") else "etc2"
	var per_hash := {}
	var tutti: Array[String] = []
	_cerca(tutti, "res://")
	tutti.sort()
	for sorgente in tutti:
		if _escluso(sorgente):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(sorgente + ".import") != OK or cfg.get_value("remap", "importer", "") != "texture":
			continue
		var dati := _dati(cfg, formato)
		if dati == "" or not FileAccess.file_exists(dati):
			continue
		var h := FileAccess.get_md5(dati) + str(FileAccess.get_size(dati))
		if per_hash.has(h):
			_doppioni[sorgente] = per_hash[h]
		else:
			per_hash[h] = sorgente
	var elenco := OS.get_environment("EXPORT_DOPPIONI_ELENCO")
	if elenco != "":
		var f := FileAccess.open(elenco, FileAccess.WRITE)
		for s in _doppioni:
			f.store_line("%s\t%s" % [s, _doppioni[s]])
	print("EsportaSenzaDoppioni: %d texture doppie lasciate fuori dal pacchetto" % _doppioni.size())


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if not _doppioni.has(path):
		return
	var copia: String = _doppioni[path]
	var testo := FileAccess.get_file_as_string(copia + ".import")
	var remap := _solo_remap(testo)
	if remap == "":
		return
	# l'uid resta quello del doppione: chi lo carica per uid trova il suo .import
	var uid := ConfigFile.new()
	uid.load(path + ".import")
	var u: String = uid.get_value("remap", "uid", "")
	if u != "":
		remap = _cambia_uid(remap, u)
	skip()
	add_file(path + ".import", remap.to_utf8_buffer(), false)


func _dati(cfg: ConfigFile, formato: String) -> String:
	for k in ["path." + formato, "path"]:
		if cfg.has_section_key("remap", k):
			return cfg.get_value("remap", k)
	return ""


## La sezione [remap] del file .import (quella che legge il gioco esportato), con la riga dell'uid.
func _solo_remap(testo: String) -> String:
	var righe := testo.split("\n")
	var out := PackedStringArray()
	var dentro := false
	for r in righe:
		if r.begins_with("["):
			dentro = r.strip_edges() == "[remap]"
		if dentro:
			out.append(r)
	return "\n".join(out).strip_edges() + "\n"


func _cambia_uid(remap: String, uid: String) -> String:
	var out := PackedStringArray()
	for r in remap.split("\n"):
		out.append('uid="%s"' % uid if r.begins_with("uid=") else r)
	return "\n".join(out)


func _escluso(sorgente: String) -> bool:
	var rel := sorgente.trim_prefix("res://")
	for filtro in get_export_preset().get_exclude_filter().split(",", false):
		if rel.match(filtro.strip_edges()):
			return true
	return false


func _cerca(out: Array[String], dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_cerca(out, dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import"):
			out.append(dir.path_join(f.trim_suffix(".import")))
