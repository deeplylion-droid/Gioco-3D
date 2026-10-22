extends Node
## Prova del blocco del pool di thread (segnalato da mascotte il 21 ottobre: gli scatti Vulkan restano
## fermi per sempre a 3 GB mentre caricano la sala; i worker del WorkerThreadPool aspettano un mutex del
## thread principale, che aspetta loro). Carica la sala come gli scatti (load() sul thread principale) o
## come il gioco (argomento "thread": ResourceLoader.load_threaded_request, come la schermata di
## caricamento), poi la mette in scena e disegna qualche fotogramma. Un thread di guardia stampa ogni
## 5 s da quanto il thread principale è fermo e la memoria.
## Uso (sotto flock /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 \
##     --script res://tests/run.gd -- res://tests/prova_blocco_pool.gd [thread|incrocio] [torre] [togli] [solo_carica]

const LEVEL := "res://scenes/sala_principale.tscn"

var _battito := 0
var _fase := "inizio"
var _guardia: Thread
var _fine := false


func _ready() -> void:
	_guardia = Thread.new()
	_guardia.start(_guarda)
	_run.call_deferred()


func _guarda() -> void:
	var ultimo := -1
	var fermo := 0.0
	while not _fine:
		OS.delay_msec(5000)
		var b := _battito
		fermo = fermo + 5.0 if b == ultimo else 0.0
		ultimo = b
		print("[guardia] fase %s, battito %d, fermo da %.0f s, memoria %.1f GB" % [_fase, b, fermo,
				OS.get_static_memory_usage() / 1e9])


func _process(_delta: float) -> void:
	_battito += 1


func _run() -> void:
	Game.pause_on_focus_loss = false
	var args := OS.get_cmdline_user_args()
	print("worker_pool/max_threads: %s, processori: %d" % [ProjectSettings.get_setting("threading/worker_pool/max_threads"),
			OS.get_processor_count()])
	var t0 := Time.get_ticks_msec()
	var pacchetto: PackedScene
	if args.has("incrocio"):
		# la torre nel pool (come la precarica) e intanto la sala con load() sul thread principale
		_fase = "incrocio"
		ResourceLoader.load_threaded_request("res://scenes/sala/torre/sala_torre.tscn", "PackedScene")
		await get_tree().process_frame
		pacchetto = load(LEVEL)
		print("torre: stato %d" % ResourceLoader.load_threaded_get_status("res://scenes/sala/torre/sala_torre.tscn"))
	elif args.has("thread"):
		_fase = "load_threaded"
		ResourceLoader.load_threaded_request(LEVEL, "PackedScene")
		while ResourceLoader.load_threaded_get_status(LEVEL) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		pacchetto = ResourceLoader.load_threaded_get(LEVEL)
	else:
		_fase = "load"
		pacchetto = load(LEVEL)
	print("caricata in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if args.has("solo_carica"):
		_fine = true
		_guardia.wait_to_finish()
		get_tree().quit()
		return
	_fase = "instantiate"
	var level := pacchetto.instantiate()
	if args.has("togli"):
		# per la memoria di llvmpipe: senza interni e tecnici
		for percorso in ["Interni", "Tecnici"]:
			var n := level.get_node_or_null(NodePath(percorso))
			if n:
				n.get_parent().remove_child(n)
				n.free()
	_fase = "add_child"
	print("=== ADD_CHILD ===")
	get_tree().root.add_child(level)
	print("=== DOPO ADD_CHILD ===")
	get_tree().current_scene = level
	_fase = "fotogrammi"
	for i in 120:
		await get_tree().process_frame
	if args.has("torre"):
		_fase = "torre"
		var portone = level.get(&"portone")
		portone.call(&"apri")
		var t1 := Time.get_ticks_msec()
		while level.get(&"sala_torre") == null and Time.get_ticks_msec() - t1 < 600000:
			await get_tree().process_frame
		print("torre: %s in %.1f s" % [level.get(&"sala_torre") != null, (Time.get_ticks_msec() - t1) / 1000.0])
	print("FINE in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_fine = true
	_guardia.wait_to_finish()
	get_tree().quit()
