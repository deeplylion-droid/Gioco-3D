extends Node
## Collaudo della correzione dei raggi nella crepa (RaggioSicuro, lavoro/raggi-crepa): nella sala intera, in uno stato
## del capitolo (stati.gd, come sonda_polaroid.gd), con la risalita e la torre caricate come più avanti nel gioco,
## scrive in un JSON dove sono finiti gli oggetti che cercano un appoggio coi raggi, per confrontare due commit:
##  - le Polaroid (posizione e rotazione);
##  - le pozze (WaterPuddle) e i galleggianti (WaterBobber), se ci sono;
##  - la griglia del fondo delle medusine (tutti i punti) e il punto più profondo;
##  - i vertici delle bave rosa (BavaRosa, appoggiate con _a_terra);
##  - tutti i Node3D del livello (posizione), per vedere se si è mosso altro (Posa).
## Misura anche il tempo: il fotogramma più lungo e i 10 più lunghi da quando si gioca (risalita e torre caricate), e quanto costa rifare la
## griglia delle medusine (_costruisci_griglia, 5 volte) e l'appoggio di ogni Polaroid (_snap).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/confronto_raggi.gd \
##        <stato> <file.json>

const LEVEL := "res://scenes/sala_principale.tscn"
const STATI := preload("res://tests/collaudo/stati.gd")
var _tempi: Array[float] = []
var _t_prima := 0
var _misura := false


func _ready() -> void:
	_run.call_deferred()


func _process(_d: float) -> void:
	if not _misura:
		return
	var t := Time.get_ticks_usec()
	if _t_prima > 0:
		_tempi.append((t - _t_prima) / 1000.0)
	_t_prima = t


func _passa(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.00001), snappedf(v.y, 0.00001), snappedf(v.z, 0.00001)]


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var stato := a[1]
	var uscita := a[2]
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.reset_progress()
	process_priority = -1000
	get_tree().change_scene_to_file(LEVEL)
	for i in 900:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene
	var p := GameState.player
	for i in 3600:
		if p.input_enabled:
			break
		await get_tree().physics_frame
	# il tempo dei fotogrammi, da quando si gioca (non il caricamento della sala, che è dietro lo schermo nero)
	_misura = true
	STATI.applica(level, stato.trim_suffix("_banco"))
	var ris := level.get_node_or_null(^"Risalita")
	if ris and ris.get(&"fiume") == null and ris.has_method(&"carica_subito"):
		ris.call(&"carica_subito")
	if level.has_method(&"_carica_torre"):
		level.call(&"_carica_torre")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		var lavori := level.has_method(&"lavori_in_corso") and bool(level.call(&"lavori_in_corso"))
		if not lavori and not Game.caricamenti_in_corso() and level.get(&"sala_torre") != null \
				and (ris == null or ris.get(&"fiume") != null):
			break
	await get_tree().create_timer(3.0).timeout
	STATI.mostra_nascosti(level)
	await _passa(30)
	_misura = false
	var out := {"stato": stato, "polaroid": {}, "pozze": {}, "galleggianti": {}, "medusine": {}, "bava": {}, "nodi": {}, "tempi": {}}
	for f in level.find_children("*", "PolaroidPhoto", true, false):
		var n := f as Node3D
		out.polaroid[str(level.get_path_to(n))] = {"foto": int(f.get(&"photo")), "pos": _v(n.global_position),
			"x": _v(n.global_basis.x), "y": _v(n.global_basis.y), "z": _v(n.global_basis.z), "visibile": n.is_visible_in_tree()}
	for f in level.find_children("*", "WaterPuddle", true, false):
		out.pozze[str(level.get_path_to(f))] = _v((f as Node3D).global_position)
	for f in level.find_children("*", "WaterBobber", true, false):
		out.galleggianti[str(level.get_path_to(f))] = _v((f as Node3D).global_position)
	for f in level.find_children("*", "Medusine", true, false):
		var g: PackedFloat32Array = f.get(&"_griglia")
		var lista := []
		for y in g:
			lista.append(snappedf(y, 0.00001))
		out.medusine[str(level.get_path_to(f))] = {"g_min": [f.get(&"_g_min").x, f.get(&"_g_min").y], "g_n": [f.get(&"_g_n").x, f.get(&"_g_n").y],
			"profondo": [f.get(&"_profondo").x, f.get(&"_profondo").y], "griglia": lista}
	for f in level.find_children("*", "BavaRosa", true, false):
		var vs := []
		for m in f.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh:
				for s in mi.mesh.get_surface_count():
					for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
						vs.append(_v(mi.global_transform * (v as Vector3)))
		out.bava[str(level.get_path_to(f))] = vs
	for f in level.find_children("*", "Node3D", true, false):
		out.nodi[str(level.get_path_to(f))] = _v((f as Node3D).global_position)
	# i tempi
	var ordinati := _tempi.duplicate()
	ordinati.sort()
	ordinati.reverse()
	out.tempi["fotogrammi"] = _tempi.size()
	out.tempi["piu_lunghi_ms"] = ordinati.slice(0, 10)
	for f in level.find_children("*", "Medusine", true, false):
		if f.get(&"vasca") == null:
			continue
		var us := []
		for i in (30 if stato.ends_with("_banco") else 5):
			var t := Time.get_ticks_usec()
			f.call(&"_costruisci_griglia")
			us.append((Time.get_ticks_usec() - t) / 1000.0)
		out.tempi["griglia_medusine_ms " + str(level.get_path_to(f))] = us
	var snap := []
	for k in (30 if stato.ends_with("_banco") else 1):
		for f in level.find_children("*", "PolaroidPhoto", true, false):
			if not f.has_method(&"_snap") or not bool(f.get(&"snap_to_surface")):
				continue
			var prima := (f as Node3D).global_position
			var t := Time.get_ticks_usec()
			f.call(&"_snap")
			snap.append([int(f.get(&"photo")), (Time.get_ticks_usec() - t) / 1000.0, snappedf(((f as Node3D).global_position - prima).length() * 1000.0, 0.001)])
	# e Posa: quanto costa un raggio di appoggio (Posa._raggio), 2000 volte in giro per la sala
	if stato.ends_with("_banco"):
		var t := Time.get_ticks_usec()
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		for i in 2000:
			var q := Vector3(rng.randf_range(-25, 25), 3.0, rng.randf_range(-25, 25))
			Posa._raggio(level, q, q + Vector3.DOWN * 6.0, [] as Array[RID])
		out.tempi["posa_raggio_2000_ms"] = (Time.get_ticks_usec() - t) / 1000.0
	out.tempi["snap_polaroid_ms_e_spostamento_mm"] = snap
	var fa := FileAccess.open(uscita, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out))
	fa.close()
	print("CONFRONTO: stato %s: %d Polaroid, %d pozze, %d galleggianti, %d medusine, %d bave, %d nodi; fotogramma più lungo %.1f ms" % [stato,
		out.polaroid.size(), out.pozze.size(), out.galleggianti.size(), out.medusine.size(), out.bava.size(), out.nodi.size(),
		ordinati[0] if ordinati.size() else 0.0])
	get_tree().quit()
