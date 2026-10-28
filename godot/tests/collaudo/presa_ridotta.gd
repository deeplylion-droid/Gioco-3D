extends Node
## La presa di lei alla fossa (tappa 8) nella sala ridotta (tests/scena_ridotta.gd: l'area bimbi con la fossa, LeiSbuca,
## il giocatore, luci e ambiente veri), così col renderer vero ci sta nella memoria della macchina. Crash della v0.3.14
## dopo il primo spavento: secondo l'utente crasha solo se la sequenza di morte arriva fino in fondo (5 s), non se la si
## salta. Qui la presa si fa nei due modi, "intera" e "saltata" (tenendo premuto skip come chi gioca), e a ogni fotogramma,
## dalla presa a 5 s dopo la ripartenza, si cerca un valore non finito (NaN o infinito: su una GPU vera può far crashare il
## driver senza errori, su llvmpipe no) nella camera, nei nodi e nelle ossa di lei, nelle luci; si contano errori e avvisi
## (ContaErrori di test_presa_vera) e si stampa ogni 0,25 s cosa succede (camera, fase di lei, glitch, thread, pipeline).
## Uso (sotto il render.lock; il preset di serie è "medio", con "alto" la sala su llvmpipe può non stare in memoria):
##   godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/presa_ridotta.gd intera
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path godot --rendering-driver vulkan --resolution 640x360 \
##     --script res://tests/run.gd -- res://tests/collaudo/presa_ridotta.gd <intera|saltata> [alto]

const LEVEL := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Polaroid", "Sala/Dettagli", "Sala/TorreScivoli", "Gioco/EnigmaAcquari", "Atmosfera"]
const Presa := preload("res://tests/test_presa_vera.gd")

var modo := "intera"
var p: Player
var lei: LeiSbuca
var _errori := Presa.ContaErrori.new()
var _non_finiti: PackedStringArray = []
var _passed := 0
var _failed := 0
var _t0 := 0


func _ready() -> void:
	OS.add_logger(_errori)
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	modo = "saltata" if args.has("saltata") else "intera"
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto" if args.has("alto") else "medio")
	GameState.reset_progress()
	var ridotta: String = load("res://tests/scena_ridotta.gd").riduci(LEVEL, TOGLI)
	get_tree().change_scene_to_file(ridotta)
	await _aspetta_giocatore()
	print("Sala ridotta (%s), renderer %s, sequenza %s" % [ridotta, RenderingServer.get_video_adapter_name(), modo])
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	_prendi_lei()
	await _frames(10)
	# dal punto della scia di test_tappa8 al checkpoint dell'area bimbi, poi verso di lei finché ti prende
	p.teleport(Vector3(-18.3, 0.0, 2.6), 0.0, 0.0)
	await _frames(5)
	await _cammina_verso(Vector3(-18.3, 0.0, -0.4), 600)
	await _frames(30)
	print("  checkpoint: %s" % String(GameState.snapshot.get("checkpoint", "")).get_file())
	Input.action_press(&"move_forward")
	for i in 900:
		if GameState.is_dying:
			break
		var occhio: Vector3 = lei.medusa.call(&"get_eye_position")
		var d := occhio - p.global_position
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	check(GameState.is_dying, "lei ti prende")
	_errori.attivo = true
	_t0 = Time.get_ticks_msec()
	var vecchia := get_tree().current_scene
	var seq := GameState.get_children().filter(func(n): return n is DeathSequence)
	var ds: DeathSequence = seq[0] if seq.size() == 1 else null
	var ultimo := -1.0
	while (get_tree().current_scene == vecchia or get_tree().current_scene == null) and Time.get_ticks_msec() - _t0 < 180000:
		var t := (Time.get_ticks_msec() - _t0) / 1000.0
		if modo == "saltata" and is_instance_valid(ds) and ds.elapsed > 0.1:
			Input.action_press(&"skip")
		_controlla("sequenza %.2f s (%.2f di gioco)" % [t, ds.elapsed if is_instance_valid(ds) else -1.0])
		var tg := ds.elapsed if is_instance_valid(ds) else t
		if tg - ultimo >= 0.25:
			ultimo = tg
			_stampa(ds)
		await get_tree().process_frame
	Input.action_release(&"skip")
	print("  (sala ricaricata dopo %.1f s)" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	await _aspetta_giocatore()
	_prendi_lei()
	var t1 := Time.get_ticks_msec()
	ultimo = -1.0
	while Time.get_ticks_msec() - t1 < 5000:
		_controlla("dopo la ripartenza %.2f s" % ((Time.get_ticks_msec() - t1) / 1000.0))
		var tr := (Time.get_ticks_msec() - t1) / 1000.0
		if tr - ultimo >= 1.0:
			ultimo = tr
			_stampa(null)
		await get_tree().process_frame
	_errori.attivo = false
	for e in _non_finiti.slice(0, 20):
		printerr("    ", e)
	check(_non_finiti.is_empty(), "nessun valore non finito in camera, lei e luci (%d)" % _non_finiti.size())
	for e in _errori.errori.slice(0, 30):
		printerr("    ", e)
	check(_errori.errori.is_empty(), "nessun errore del motore o degli script dalla presa a 5 s dopo (%d)" % _errori.errori.size())
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)


func _prendi_lei() -> void:
	var level := get_tree().current_scene
	p = GameState.player
	lei = level.get_node_or_null(^"Gioco/LeiSbuca") as LeiSbuca
	if lei and not lei.abilitata:
		lei.abilitata = true


func _aspetta_giocatore() -> void:
	for i in 1200:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying and get_tree().current_scene:
			break
	await _frames(10)
	p = GameState.player
	p.input_enabled = true


## Un valore non finito (NaN o infinito) nella camera attiva, nei nodi e nelle ossa di lei, nelle luci di LeiSbuca.
func _controlla(quando: String) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and (not _finita(cam.global_transform) or not is_finite(cam.fov) or not is_finite(cam.near) or not is_finite(cam.far)):
		_segna("camera %s %s" % [cam.get_path(), cam.global_transform], quando)
	if not is_instance_valid(lei):
		return
	# (mentre la sala si ricarica, lei della sala vecchia è fuori dall'albero: si guarda solo quella nella scena)
	if not lei.is_inside_tree():
		return
	for n in lei.find_children("*", "Node3D", true, false):
		var n3 := n as Node3D
		if not n3.is_inside_tree():
			continue
		if not _finita(n3.global_transform):
			_segna("nodo %s" % n3.get_path(), quando)
			break
		if n3 is Light3D and not is_finite((n3 as Light3D).light_energy):
			_segna("luce %s energia %s" % [n3.get_path(), (n3 as Light3D).light_energy], quando)
	for sk in lei.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		for b in s.get_bone_count():
			if not _finita(s.get_bone_global_pose(b)):
				_segna("osso %s/%s" % [s.get_path(), s.get_bone_name(b)], quando)
				break


func _finita(t: Transform3D) -> bool:
	return t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite() and t.basis.z.is_finite()


func _segna(cosa: String, quando: String) -> void:
	if _non_finiti.size() < 200:
		_non_finiti.append("%s: %s" % [quando, cosa])
	if _non_finiti.size() == 1:
		printerr("  NON FINITO ", quando, ": ", cosa)


func _stampa(ds: DeathSequence) -> void:
	var cam := get_viewport().get_camera_3d()
	var occhio: Vector3 = lei.medusa.call(&"get_eye_position") if is_instance_valid(lei) and is_instance_valid(lei.medusa) else Vector3.ZERO
	var glitch: Array = ds.find_children("*", "JumpscareGlitch", true, false) if is_instance_valid(ds) else []
	var forza := -1.0
	if not glitch.is_empty() and (glitch[0] as JumpscareGlitch).visible:
		var r := (glitch[0] as Node).get_child(0) as ColorRect
		var v: Variant = (r.material as ShaderMaterial).get_shader_parameter(&"forza")
		forza = float(v) if v != null else 0.0
	var thread := 0
	for percorso in Game.get(&"_caricamenti"):
		if ResourceLoader.load_threaded_get_status(percorso) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			thread += 1
	print("  [%s] camera %s, dall'occhio %.2f m | lei fase %d visibile %s | glitch %.2f | nero %.2f | thread in corso %d | pipeline draw %d spec %d | errori %d" % [
		"%.2f" % ds.elapsed if is_instance_valid(ds) else "dopo", cam.global_position.snapped(Vector3.ONE * 0.01) if cam else Vector3.ZERO,
		cam.global_position.distance_to(occhio) if cam else -1.0, lei.fase if is_instance_valid(lei) else -1,
		lei.medusa.visible if is_instance_valid(lei) and is_instance_valid(lei.medusa) else false, forza,
		(ds.get(&"_black") as ColorRect).color.a if is_instance_valid(ds) else -1.0, thread,
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)), _errori.errori.size()])


func _cammina_verso(t: Vector3, max_frames: int) -> bool:
	Input.action_press(&"move_forward")
	var arrivato := false
	for i in max_frames:
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			arrivato = true
			break
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	return arrivato


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
