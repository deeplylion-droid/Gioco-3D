extends Node
## Test dell'audio: autoload "Audio", bus ed effetti, stream del catalogo (si caricano, i loop
## si ripetono), volumi salvati in settings.cfg, collegamenti automatici con la sala principale
## (segnali e suoni che partono davvero), scheda nel menu delle opzioni, morte e ripartenza.
## Alla fine controlla che l'audio non abbia prodotto errori (un Logger li raccoglie tutti).
## In headless il driver audio è "Dummy": i player suonano senza uscire dalle casse.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_audio.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const Catalogo := preload("res://addons/audio/catalogo.gd")
const IMPOSTAZIONI_PROVA := "user://test_audio_settings.cfg"

var audio: Node
var level: Node
var p: Player
var _passed := 0
var _failed := 0
var _logger: RaccoltaErrori


## Raccoglie errori e avvisi del motore e degli script (può essere chiamato da altri thread).
class RaccoltaErrori extends Logger:
	var errori: Array = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		errori.append({"tipo": error_type, "file": file, "riga": line, "codice": code, "motivo": rationale,
			"funzione": function})
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func copia() -> Array:
		_mutex.lock()
		var c := errori.duplicate()
		_mutex.unlock()
		return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_logger = RaccoltaErrori.new()
	OS.add_logger(_logger)
	audio = get_node_or_null(^"/root/Audio")
	if audio == null:
		# L'autoload non è ancora in project.godot: lo si crea come farebbe Godot.
		audio = load("res://addons/audio/audio.gd").new()
		audio.name = "Audio"
		get_tree().root.add_child(audio)
		await get_tree().process_frame
	audio.set(&"salva_su_disco", false)
	# In headless il driver è "Dummy": si forza la riproduzione vera per provare anche i player.
	AudioLoop.forza_riproduzione(true)

	print("Bus ed effetti")
	for b in ["Master", "Musica", "Ambiente", "Effetti", "Mondo", "Interfaccia"]:
		check(AudioServer.get_bus_index(b) >= 0, "c'è il bus %s" % b)
	for b in ["Musica", "Ambiente", "Effetti"]:
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(b)) == &"Mondo", "%s passa per Mondo" % b)
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Mondo")) == &"Master", "Mondo va nel Master")
	check(_ha_effetto("Effetti", "AudioEffectReverb"), "riverbero della sala sul bus Effetti")
	check(_ha_effetto("Mondo", "AudioEffectLowPassFilter"), "passa-basso (sott'acqua e pausa) sul bus Mondo")

	print("Stream del catalogo")
	var file := 0
	var rotti := 0
	var loop_ok := true
	var byte := 0
	var non_pronti := 0
	for nome in Catalogo.SUONI:
		for percorso in Catalogo.SUONI[nome]:
			var s := load(percorso) as AudioStream
			file += 1
			if s == null or s.get_length() <= 0.0:
				rotti += 1
				printerr("  non si carica: ", percorso)
			elif String(nome).ends_with("_loop") and not (s as AudioStreamOggVorbis).loop:
				loop_ok = false
				printerr("  loop non attivo: ", percorso)
			var f := FileAccess.open(percorso, FileAccess.READ)
			if f:
				byte += f.get_length()
		if audio.call(&"stream_di", nome) == null:
			non_pronti += 1
			printerr("  stream non pronto: ", nome)
	check(non_pronti == 0, "%d suoni pronti da suonare" % Catalogo.SUONI.size())
	check(file >= 100 and rotti == 0, "%d file OGG si caricano (%d rotti)" % [file, rotti])
	check(loop_ok, "i fondi e i suoni continui sono in loop")
	check(byte > 0 and byte < 40 * 1024 * 1024, "dimensione totale %.1f MB (meno di 40)" % (byte / 1048576.0))
	var r = audio.call(&"stream_di", &"passo_bagnato")
	check(r is AudioStreamRandomizer and (r as AudioStreamRandomizer).streams_count >= 4, "le varianti dei passi si alternano")

	print("Volumi e settings.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("grafica", "preset", "alto")
	cfg.save(IMPOSTAZIONI_PROVA)
	audio.set(&"percorso_impostazioni", IMPOSTAZIONI_PROVA)
	audio.set(&"salva_su_disco", true)
	audio.call(&"imposta_volume", "musica", 0.5)
	var vdb := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Musica"))
	check(absf(vdb - linear_to_db(0.5)) < 0.2, "il volume della musica cambia il bus (%.1f dB)" % vdb)
	audio.call(&"salva_impostazioni")
	cfg = ConfigFile.new()
	cfg.load(IMPOSTAZIONI_PROVA)
	check(is_equal_approx(float(cfg.get_value("audio", "musica", -1.0)), 0.5), "salvato in [audio]")
	check(cfg.get_value("grafica", "preset", "") == "alto", "le altre sezioni restano")
	audio.call(&"imposta_volume", "musica", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Musica")), "a zero il bus è muto")
	audio.call(&"ripristina_volumi")
	audio.call(&"carica_impostazioni")
	audio.set(&"salva_su_disco", false)
	audio.set(&"percorso_impostazioni", "user://settings.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IMPOSTAZIONI_PROVA))

	print("La sala principale")
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	level = get_tree().current_scene
	p = GameState.player
	var c: Dictionary = audio.get(&"collegati")
	print("  collegati: ", c)
	for tipo in ["Tempesta", "Player", "WaterPack", "Torcia", "UnderwaterEffect", "Turbine", "HingedHatch",
			"BucketWheel", "MedusaStatue", "KidSighting", "FlickerLight", "StuckInflatable", "WaterDripEmitter",
			"sigla", "GameState"]:
		check(int(c.get(tipo, 0)) >= 1, "collegato: %s" % tipo)
	check(int(c.get("PolaroidPhoto", 0)) >= 10, "collegate le 10 Polaroid")
	check(int(c.get("WaterButton", 0)) >= 2, "collegati i pulsanti")
	check(int(c.get("Gocce", 0)) >= 3, "collegate le gocce")
	check(int(c.get("WaterTank", 0)) >= 3, "collegate le vasche")
	check(int(c.get("luci_neon", 0)) >= 20, "i neon della sala ronzano (%d)" % int(c.get("luci_neon", 0)))
	check(int(c.get("luci_emergenza", 0)) >= 10, "le luci d'emergenza ronzano")
	var storm: Tempesta = level.find_children("*", "Tempesta", true, false)[0]
	check(storm.tuono.get_connections().size() >= 1, "il tuono della tempesta è collegato")
	check(p.footstep.get_connections().size() >= 1, "i passi del giocatore sono collegati")
	check(p.water_pack.spray_started.get_connections().size() >= 1, "lo zaino è collegato")
	var jingle: WaterButton = level.get_node("Statua/PulsanteSigla")
	check(jingle.pressed.get_connections().size() >= 2, "il pulsante della sigla suona la sigla")

	print("Fondi")
	await _frames(90)
	var fondi: Dictionary = audio.get(&"_fondi")
	for k in [&"pioggia_cupola_loop", &"vento_loop", &"nave_loop"]:
		var l: AudioLoop = fondi.get(k)
		check(l != null and l.volume > 0.5 and l.is_suonando(), "suona il fondo %s" % k)

	print("Tuono, passi, zaino, sigla")
	var n0 := _conta(&"tuono_vicino") + _conta(&"tuono_lontano")
	storm.tuono.emit(1.0, 0.8)
	await _frames(2)
	check(_conta(&"tuono_vicino") + _conta(&"tuono_lontano") > n0, "il tuono suona quando arriva")
	var passi0 := _conta(&"passo_bagnato") + _conta(&"passo_piastrelle")
	p.teleport(Vector3(-2.5, 0, 18.0), 0.0, 0.0)
	Input.action_press(&"move_forward")
	await _frames(70)
	Input.action_release(&"move_forward")
	check(_conta(&"passo_bagnato") + _conta(&"passo_piastrelle") >= passi0 + 3, "camminando si sentono i passi (%d)" %
		(_conta(&"passo_bagnato") + _conta(&"passo_piastrelle") - passi0))
	check(_conta(&"faro_acceso") >= 1, "il faro della statua si accende con il suo colpo")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(0.0, 0, 14.6), 0.0, 0.0)
	p.look_at_point(jingle.global_position + Vector3(0, 0.12, 0))
	await _frames(3)
	Input.action_press(&"spray")
	await _frames(40)
	check(_conta(&"zaino_getto_inizio") >= 1, "parte il getto")
	var zaino := _zaino()
	check(zaino != null and zaino.get(&"getto").is_suonando(), "il getto suona finché si spruzza")
	check(zaino != null and zaino.get(&"impatto").is_suonando(), "si sente dove il getto colpisce")
	check(jingle.powered, "il getto preme il pulsante della sigla")
	check(_conta(&"pulsante_premuto") >= 1, "il pulsante fa il suo 'ciunk'")
	Input.action_release(&"spray")
	await _frames(70)
	check(bool(audio.call(&"sigla_in_corso")), "la sigla rovinata suona dal piedistallo")
	check(_conta(&"zaino_getto_fine") >= 1, "il getto si chiude")
	p.water_pack.set_tank_amount(0.0)
	p.teleport(Vector3(-8.3, 0, 2.0), 0.0, 0.0)
	p.look_at_point(Vector3(-10.6, -0.22, 2.0))
	await _frames(3)
	Input.action_press(&"suck")
	await _frames(30)
	check(_conta(&"zaino_aspira_inizio") >= 1 and zaino.get(&"aspira").is_suonando(), "l'aspirazione suona")
	Input.action_release(&"suck")
	await _frames(10)

	print("Pausa e sott'acqua")
	get_tree().paused = true
	await _frames_sempre(40)
	var im := AudioServer.get_bus_index("Mondo")
	check(AudioServer.is_bus_effect_enabled(im, 0) and float(audio.get(&"_lpf_attuale")) < 3000.0,
		"in pausa il mondo si sente ovattato")
	get_tree().paused = false
	await _frames(90)
	check(float(audio.get(&"_lpf_attuale")) > 15000.0, "tolta la pausa torna limpido")
	var tuffi := _conta(&"tuffo")
	var effetto := p.get_node("Head/Camera3D/EffettoSottacqua")
	effetto.entered_water.emit()
	check(_conta(&"tuffo") > tuffi, "entrando in acqua: il tuffo")

	print("Menu delle opzioni")
	var menu: CanvasLayer = load("res://addons/grafica/menu_opzioni.tscn").instantiate()
	get_tree().root.add_child(menu)
	await _frames(3)
	var schede := menu.find_children("*", "TabContainer", true, false)
	var scheda: Node = schede[0].get_node_or_null(^"Audio") if not schede.is_empty() else null
	check(scheda != null and scheda.get_child_count() > 0 and scheda.get_child(0) is PannelloAudio,
		"il menu delle opzioni ha la scheda Audio")
	menu.queue_free()
	var pannello: Control = load("res://addons/audio/pannello_audio.tscn").instantiate()
	add_child(pannello)
	await _frames(2)
	check(pannello.find_children("*", "HSlider", true, false).size() == 4, "il pannello ha i 4 cursori")
	pannello.queue_free()

	print("Morte e ripartenza")
	var giocatori := int((audio.get(&"collegati") as Dictionary).get("Player", 0))
	var vecchio := p.get_instance_id()
	GameState.kill_player(&"test")
	await _frames(5)
	check(_conta(&"stinger_morte") >= 1, "alla morte parte lo stinger")
	await _frames(60)
	check(float(audio.get(&"_offset")[&"Effetti"]) < -3.0, "durante la morte il mondo si abbassa")
	var seq := GameState.get_children().filter(func(x): return x is DeathSequence)
	if not seq.is_empty():
		seq[0].skip()
	for i in 400:
		await get_tree().process_frame
		var g = GameState.player
		if is_instance_valid(g) and g.get_instance_id() != vecchio and not GameState.is_dying:
			break
	await _frames(60)
	check(int((audio.get(&"collegati") as Dictionary).get("Player", 0)) > giocatori, "dopo la ripartenza si ricollega")
	check(float(audio.get(&"_offset")[&"Effetti"]) > -3.0, "dopo la ripartenza il mondo torna al suo volume")

	print("Errori")
	var errori_audio := 0
	var altri := 0
	for e in _logger.copia():
		var testo: String = "%s %s %s" % [e["file"], e["codice"], e["motivo"]]
		var nostro: bool = testo.contains("addons/audio") or testo.contains("audio_stream") or \
			testo.contains("audio_server") or e["tipo"] == Logger.ERROR_TYPE_SCRIPT
		if nostro:
			errori_audio += 1
			printerr("  ", e["file"], ":", e["riga"], " ", e["codice"], " ", e["motivo"])
		elif e["tipo"] != Logger.ERROR_TYPE_WARNING:
			altri += 1
	check(errori_audio == 0, "nessun errore dall'audio (%d)" % errori_audio)
	if altri > 0:
		print("  (altri %d errori non dell'audio, per esempio texture dei GLB non estratte)" % altri)
	# Si ferma tutto qualche fotogramma prima di uscire: niente riproduzioni appese alla chiusura.
	AudioLoop.forza_riproduzione(false)
	audio.call(&"ferma_tutto")
	await _frames_sempre(3)
	OS.delay_msec(400)       # il thread audio libera le riproduzioni fermate
	await _frames_sempre(3)
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _zaino() -> Object:
	for a in audio.get(&"_attivi"):
		if a.get(&"pack") == p.water_pack:
			return a
	return null


func _conta(nome: StringName) -> int:
	return int((audio.get(&"conteggio") as Dictionary).get(nome, 0))


func _ha_effetto(bus: String, classe: String) -> bool:
	var i := AudioServer.get_bus_index(bus)
	for k in AudioServer.get_bus_effect_count(i):
		if AudioServer.get_bus_effect(i, k).is_class(classe):
			return true
	return false


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


## Come _frames, ma va avanti anche con il gioco in pausa.
func _frames_sempre(n: int) -> void:
	for i in n:
		await get_tree().process_frame
