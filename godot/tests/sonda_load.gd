extends RefCounted
## Sonda (solo sul branch lavoro/sonda-load, non va unita): ogni load() e ResourceLoader.load() degli script passa di
## qui (tools/sonda_load_codemod.py li riscrive). Stampa una riga per caricamento:
##   SONDA_LOAD|ms|thread (main o altro)|in cache prima (1/0)|il thread lo sta caricando (1/0)|percorso|dove
## Solo sul thread principale si misura anche se il thread di caricamento ha in corso quel percorso.

static var _main_id := OS.get_main_thread_id()


## [param dove] prima (lo mette il codemod): poi gli argomenti di load() com'erano.
static func da(dove: String, percorso: String, tipo := "", modo := ResourceLoader.CACHE_MODE_REUSE) -> Resource:
	var main := OS.get_thread_caller_id() == _main_id
	var in_cache := ResourceLoader.has_cached(percorso)
	var nel_thread := false
	if main:
		nel_thread = ResourceLoader.load_threaded_get_status(percorso) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
	var t := Time.get_ticks_usec()
	var r := ResourceLoader.load(percorso, tipo, modo)
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	print("SONDA_LOAD|%.2f|%s|%d|%d|%s|%s" % [ms, "main" if main else "altro", int(in_cache), int(nel_thread), percorso, dove])
	return r
