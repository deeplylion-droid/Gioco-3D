extends Node
## Misura la memoria di una scena frame per frame sul renderer vero (anche Vulkan software):
## RSS del processo (anonima e condivisa, cioè la "memoria video" di llvmpipe), memoria video
## secondo Godot e compilazioni delle pipeline. Serve a capire dove va la memoria.
## Uso (sotto /home/user/tools/render.lock, una misura alla volta):
##   xvfb-run -a godot --path godot --rendering-driver vulkan --resolution 640x360 \
##     --script res://tests/run.gd -- res://tests/misura_memoria.gd <file.csv> [scena] [opzioni]
## Opzioni separate da virgole: gi0 (GI spenta), smaa (SMAA al posto del TAA), medio/basso/ultra
## (preset), senza_interni, senza_dettagli, senza_medusa, togli=Nodo+Nodo/Figlio (tolti prima di
## entrare in scena), frames=N (quanti frame misurare, 40), limite=GB (sopra si chiude da sola, 13).

var out_path := "user://misura_memoria.csv"
var scene_path := "res://scenes/sala_principale.tscn"
var opts := PackedStringArray()
var frames := 40
var limit_kb := 13 * 1024 * 1024
var _f: FileAccess
var _t0 := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[1] != "":
		out_path = args[1]
	if args.size() > 2 and args[2] != "":
		scene_path = args[2]
	if args.size() > 3:
		opts = args[3].split(",", false)
	for o in opts:
		if o.begins_with("frames="):
			frames = int(o.get_slice("=", 1))
		elif o.begins_with("limite="):
			limit_kb = int(float(o.get_slice("=", 1)) * 1024 * 1024)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	var preset := "alto"
	for p in ["basso", "medio", "ultra"]:
		if opts.has(p):
			preset = p
	Grafica.applica_preset(preset)
	if opts.has("gi0"):
		Grafica.imposta("gi", 0)
	if opts.has("smaa"):
		Grafica.imposta("antialiasing", 2)
	_f = FileAccess.open(out_path, FileAccess.WRITE)
	_f.store_line("fase;frame;ms;anon_mb;shmem_mb;rss_mb;video_mb;texture_mb;buffer_mb;pipe_mesh;pipe_surface;pipe_draw;pipe_spec;pipe_canvas;statica_mb;oggetti;risorse;nodi;orfani")
	_t0 = Time.get_ticks_msec()
	_log("inizio", 0)
	var ps := load(scene_path) as PackedScene
	_log("caricata", 0)
	var level := ps.instantiate()
	var togli := PackedStringArray()
	for o in opts:
		match o:
			"senza_interni":
				togli.append("Interni")
			"senza_dettagli":
				togli.append("Sala/Dettagli")
			"senza_medusa":
				togli.append("Vasca/Medusa")
		if o.begins_with("togli="):
			togli.append_array(o.get_slice("=", 1).split("+", false))
	# imposta=Nodo:proprieta:valore+...: cambia proprietà prima di entrare in scena.
	for o in opts:
		if o.begins_with("imposta="):
			for item in o.get_slice("=", 1).split("+", false):
				var parts := item.split(":")
				var target := level.get_node_or_null(NodePath(parts[0]))
				if target and parts.size() == 3:
					target.set(StringName(parts[1]), str_to_var(parts[2]))
					print("MISURA impostato ", item)
	for path in togli:
		var n := level.get_node_or_null(NodePath(path))
		if n:
			n.get_parent().remove_child(n)
			n.free()
			print("MISURA tolto ", path)
		else:
			print("MISURA non trovato ", path)
	if opts.has("unifica"):
		var n: int = load("res://scripts/rendering/unifica_materiali.gd").unifica(level)
		for d in level.find_children("*", "Node3D", true, false):
			var modelli = d.get(&"modelli")
			if modelli is Array:
				for ps2 in modelli:
					if ps2 is PackedScene:
						var inst := (ps2 as PackedScene).instantiate()
						n += load("res://scripts/rendering/unifica_materiali.gd").unifica(inst)
						inst.free()
		print("MISURA materiali unificati: ", n)
	_log("istanziata", 0)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	_log("in_scena", 0)
	# camera=x,y,z,gx,gy,gz: il giocatore si sposta lì e guarda il punto (dopo il risveglio).
	for o in opts:
		if o.begins_with("camera="):
			var v := o.get_slice("=", 1).split_floats(",")
			await get_tree().process_frame
			var p := GameState.player
			if p and v.size() == 6:
				for i in 400:
					if p.input_enabled:
						break
					await get_tree().process_frame
				p.teleport(Vector3(v[0], v[1], v[2]), 0.0, 0.0)
				p.look_at_point(Vector3(v[3], v[4], v[5]))
				print("MISURA camera ", v)
	for i in frames:
		await get_tree().process_frame
		if not _log("frame", i + 1):
			return
	_f.close()
	# Chiudere la scena sul renderer software può durare minuti: la misura è scritta, basta così.
	print("MISURA fine")
	OS.kill(OS.get_process_id())


func _log(phase: String, frame: int) -> bool:
	# /proc dichiara lunghezza 0: si legge riga per riga.
	var st := ""
	var fs := FileAccess.open("/proc/self/status", FileAccess.READ)
	if fs:
		while true:
			var l := fs.get_line()
			if fs.eof_reached() and l == "":
				break
			st += l + "\n"
			if st.length() > 8000:
				break
		fs.close()
	var anon := _kb(st, "RssAnon:")
	var shmem := _kb(st, "RssShmem:")
	var rss := _kb(st, "VmRSS:")
	var line := "%s;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d" % [phase, frame, Time.get_ticks_msec() - _t0,
		anon / 1024, shmem / 1024, rss / 1024,
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0),
		int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)),
		int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))]
	_f.store_line(line)
	_f.flush()
	print("MISURA ", line)
	if anon + shmem > limit_kb:
		print("MISURA oltre il limite: mi fermo")
		_f.close()
		OS.kill(OS.get_process_id())
		return false
	return true


static func _kb(status: String, key: String) -> int:
	var i := status.find(key)
	if i < 0:
		return 0
	return status.substr(i + key.length()).strip_edges().split(" ")[0].to_int()

