extends RefCounted
## Sonda (solo sul branch lavoro/sonda-load, non va unita): ogni load() e ResourceLoader.load() degli script passa di
## qui (tools/sonda_load_codemod.py li riscrive). Stampa una riga per caricamento:
##   SONDA_LOAD|ms|thread (main o altro)|in cache prima (1/0)|il thread lo sta caricando (1/0)|percorso|dove|fase|fotogramma
## fase (solo sul thread principale): caricamento (la schermata di caricamento), ripartenza (morte o Continua),
## avvio (il livello c'è da meno di 2 s), gioco (si gioca: qui un caricamento lungo è uno scatto che si sente).
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
	print("SONDA_LOAD|%.2f|%s|%d|%d|%s|%s|%s|%d" % [ms, "main" if main else "altro", int(in_cache), int(nel_thread), percorso, dove,
			_fase() if main else "-", Engine.get_process_frames()])
	return r


static var _giocatore: Object = null
static var _da := 0


static func _fase() -> String:
	var albero := Engine.get_main_loop() as SceneTree
	if albero == null or albero.root == null:
		return "avvio"
	var scena := albero.current_scene
	if scena and scena.scene_file_path.contains("caricamento"):
		return "caricamento"
	var gs := albero.root.get_node_or_null(^"GameState")
	if gs == null:
		return "avvio"
	if bool(gs.call(&"is_restoring")) or bool(gs.get(&"_ripartenza_in_corso")) or bool(gs.get(&"is_dying")):
		return "ripartenza"
	var p: Object = gs.get(&"player")
	if p == null or not is_instance_valid(p) or not (p as Node).is_inside_tree():
		return "avvio"
	if p != _giocatore:
		_giocatore = p
		_da = Engine.get_process_frames()
	return "avvio" if Engine.get_process_frames() - _da < 120 else "gioco"
