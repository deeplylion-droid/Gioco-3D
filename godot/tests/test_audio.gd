extends Node
## Test dell'audio: autoload "Audio", bus ed effetti, stream del catalogo (si caricano, i loop
## si ripetono), volumi salvati in settings.cfg, collegamenti automatici con la sala principale
## (segnali e suoni che partono davvero), monitor, paratie e cancelli stagni delle tappe 5-6, la
## fossa e il morso della tappa 8, la piscina a onde della tappa 5 (gorgo, piscina vuota, pulsante
## della botola col lampeggiante e il bi-bu, micro medusine), il portone della sala della torre, i
## nomi dei suoni chiesti dagli script, scheda nel menu delle opzioni, morte e ripartenza.
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
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var pila := ""
		for bt in script_backtraces:
			if bt:
				pila += bt.format()
		_mutex.lock()
		errori.append({"tipo": error_type, "file": file, "riga": line, "codice": code, "motivo": rationale,
			"funzione": function, "pila": pila})
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
	# Con gli interni si parte dal risveglio nel corridoio: si aspetta che finisca.
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	# punto di partenza del giocatore: valido qualunque sia la pianta della sala
	var partenza := p.global_position
	var sguardo_partenza := p.yaw
	var c: Dictionary = audio.get(&"collegati")
	print("  collegati: ", c)
	for tipo in ["Tempesta", "Player", "WaterPack", "UnderwaterEffect", "Turbine", "HingedHatch",
			"KidSighting", "FlickerLight", "WaterDripEmitter", "sigla", "GameState", "PiscinaOnde"]:
		check(int(c.get(tipo, 0)) >= 1, "collegato: %s" % tipo)
	check(int(c.get("MedusaStatue", 0)) + int(c.get("MedusaAffacciata", 0)) >= 1, "collegata la medusa")
	check(int(c.get("PolaroidPhoto", 0)) >= 9, "collegate le 9 Polaroid della demo")
	check(int(c.get("WaterButton", 0)) >= 2, "collegati i pulsanti")
	check(int(c.get("Gocce", 0)) >= 3, "collegate le gocce")
	check(int(c.get("WaterTank", 0)) >= 3, "collegate le vasche")
	check(int(c.get("luci_neon", 0)) >= 20, "i neon della sala ronzano (%d)" % int(c.get("luci_neon", 0)))
	check(int(c.get("luci_emergenza", 0)) >= 10, "le luci d'emergenza ronzano")
	var storm: Tempesta = level.find_children("*", "Tempesta", true, false)[0]
	check(storm.tuono.get_connections().size() >= 1, "il tuono della tempesta è collegato")
	check(p.footstep.get_connections().size() >= 1, "i passi del giocatore sono collegati")
	check(p.water_pack.spray_started.get_connections().size() >= 1, "lo zaino è collegato")
	var jingle: WaterButton = level.get_node("Vasca/PulsanteSigla")
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
	# passi veri: si cammina dal punto di partenza
	var passi0 := _conta(&"passo_bagnato") + _conta(&"passo_piastrelle")
	p.teleport(partenza, sguardo_partenza, 0.0)
	Input.action_press(&"move_forward")
	await _frames(70)
	Input.action_release(&"move_forward")
	check(_conta(&"passo_bagnato") + _conta(&"passo_piastrelle") >= passi0 + 2, "camminando si sentono i passi (%d)" %
		(_conta(&"passo_bagnato") + _conta(&"passo_piastrelle") - passi0))
	# ogni superficie ha il suo passo; la sala è bagnata (WetSurfaceConverter)
	for prova in [[&"generico", &"passo_bagnato"], [&"metallo", &"passo_metallo"], [&"acqua", &"passo_acqua"],
			[&"scala", &"passo_scala"]]:
		var prima := _conta(prova[1])
		p.footstep.emit(prova[0], false, 1.0)
		check(_conta(prova[1]) > prima, "superficie %s: %s" % [prova[0], prova[1]])
	var atterraggi := _conta(&"atterraggio_bagnato")
	p.landed.emit(&"generico", false, 7.0)
	check(_conta(&"atterraggio_bagnato") > atterraggi, "atterraggio sul bagnato")
	var lamp: FlickerLight = level.get_node("Vasca/Sfarfallio")
	if not lamp.is_on:
		lamp.turn_on()
	await _frames(3)
	check(_conta(&"faro_acceso") >= 1, "il faro della statua si accende con il suo colpo")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(20.0)
	# davanti al pulsante della sigla (guarda verso +Z), a 3,5 m, sul pavimento
	var davanti := jingle.global_position + jingle.global_basis.z.normalized() * 3.5
	davanti.y = 0.0
	p.teleport(davanti, 0.0, 0.0)
	p.look_at_point(jingle.global_position + Vector3(0, 0.12, 0))
	await _frames(3)
	Input.action_press(&"spray")
	# Il getto B parte dopo un attimo di carica (WaterPack.spray_delay).
	await _frames(40 + int(p.water_pack.spray_delay * 60.0))
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
	# sul bordo est della vasca d'arrivo, puntando l'acqua
	var vasca: WaterTank = level.get_node("Vasche/VascaArrivo")
	var centro := vasca.global_position
	var mezza := vasca.inner_size.x * 0.5
	p.water_pack.set_tank_amount(0.0)
	p.teleport(Vector3(centro.x + mezza + 0.7, 0.0, centro.z), 0.0, 0.0)
	p.look_at_point(Vector3(centro.x + mezza - 1.6, vasca.get_surface_global_y(), centro.z))
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

	print("Sala pompe e camera delle onde (tappe 5-6)")
	var tecnici := [&"pompe_ruggito_loop", &"pompa_avvio", &"corrente_salta", &"crt_neve_loop",
		&"plastica_piega_lontano", &"tonfo_acqua_lontano", &"paratia_scende_loop", &"maniglione_bloccato",
		&"porta_ponte_apre"]
	check(tecnici.all(func(n): return audio.call(&"stream_di", n) != null), "ci sono i 9 suoni delle tappe 5-6")
	var monitor: Node = _primo("MonitorCrt")
	var paratie := level.find_children("*", "Paratia", true, false)
	check(monitor != null and int(c.get("MonitorCrt", 0)) >= 1, "collegato: MonitorCrt")
	check(paratie.size() >= 2 and int(c.get("Paratia", 0)) >= paratie.size(),
		"collegate le paratie (%d)" % int(c.get("Paratia", 0)))
	if monitor:
		var neve := _loop_su(monitor.get_node_or_null(monitor.get(&"schermo_path")), &"crt_neve_loop")
		check(neve != null and not neve.is_suonando(), "prima del blackout il monitor non fruscia")
		monitor.call(&"mostra_neve")
		await _frames(20)
		check(neve != null and neve.is_suonando(), "con la neve il monitor fruscia")
	if not paratie.is_empty():
		var par: Node = paratie[0]
		var catena := _loop_su(par.get_node_or_null(par.get(&"pannello_path")), &"paratia_scende_loop")
		# I cancelli stagni sono chiusi finché non arriva il giocatore (riscontro v0.3.1, punto 6): la si
		# apre come al passaggio, col suo colpo metallico, poi si fa scendere come al risveglio.
		var aperture := _conta(&"cancello_stagno_apre")
		if par.has_method(&"apri") and not bool(par.get(&"is_aperta")):
			par.call(&"apri")
			for i in 300:
				if bool(par.get(&"is_aperta")):
					break
				await get_tree().physics_frame
			await _frames(10)
		check(_conta(&"cancello_stagno_apre") == aperture + 1, "aprendosi il cancello stagno fa il suo colpo metallico")
		check(catena != null and not catena.is_suonando(), "la paratia alzata tace")
		var tonfi := _conta(&"porta_chiusa")
		par.call(&"chiudi")
		await _frames(30)
		check(catena != null and catena.is_suonando(), "la paratia scende con motore e catene")
		for i in 600:
			if bool(par.get(&"is_chiusa")):
				break
			await get_tree().physics_frame
		await _frames(60)
		check(_conta(&"porta_chiusa") > tonfi, "in fondo la paratia sbatte")
		check(catena != null and not catena.is_suonando(), "chiusa, la paratia tace")
	# Come li chiamerà il risveglio: tre motori sulle pompe e i suoni lontani in 3D.
	var pompe := level.find_children("*", "Pompa", true, false)
	if not pompe.is_empty():
		var motore: AudioLoop = audio.call(&"crea_loop", &"pompe_ruggito_loop", pompe[0])
		motore.volume = 1.0
		await _frames(10)
		check(motore.is_suonando() and (motore.player.stream as AudioStreamOggVorbis).loop,
			"il ruggito delle pompe gira in loop")
		motore.volume = 0.0
		var lontano: Node = audio.call(&"suona", &"plastica_piega_lontano", Vector3(0, 0.6, 10))
		check(lontano is AudioStreamPlayer3D and (lontano as AudioStreamPlayer3D).unit_size >= 30.0,
			"la plastica lontana arriva dalla vasca e si sente anche dalla sala pompe")
		lontano.call(&"stop")
	# I cancelli stagni della camera delle onde (prova della v0.3.1): li suona lo script dei
	# cancelli, un suono per cancello; l'animazione segue CANCELLO_STAGNO_PARTE e _ARRIVA.
	var costanti: Dictionary = (audio.get_script() as GDScript).get_script_constant_map()
	var arriva := float(costanti.get("CANCELLO_STAGNO_ARRIVA", 0.0))
	var cancelli = audio.call(&"stream_di", &"cancello_stagno_apre")
	var varianti_ok: bool = cancelli is AudioStreamRandomizer and (cancelli as AudioStreamRandomizer).streams_count == 2
	if varianti_ok:
		for i in 2:
			varianti_ok = varianti_ok and (cancelli as AudioStreamRandomizer).get_stream(i).get_length() > arriva + 0.5
	check(varianti_ok and arriva > float(costanti.get("CANCELLO_STAGNO_PARTE", 9.0)),
		"il cancello stagno ha due varianti che durano oltre il colpo a fine corsa (%.2f s)" % arriva)
	var cancello: Node = audio.call(&"suona", &"cancello_stagno_apre", Vector3(0, 1.2, 4.0))
	check(cancello is AudioStreamPlayer3D and (cancello as AudioStreamPlayer3D).unit_size >= 5.0
		and (cancello as AudioStreamPlayer3D).volume_db >= 2.0, "il cancello stagno è forte, pieno fino a circa 6 m")
	if cancello:
		cancello.call(&"stop")

	print("Area bimbi: lei (tappa 8)")
	var suoni_lei := [&"fossa_ribolle_loop", &"lei_sbuca", &"lei_scivola_sotto", &"morso"]
	check(suoni_lei.all(func(n): return audio.call(&"stream_di", n) != null), "ci sono i 4 suoni della tappa 8")
	var lei: Node = _primo("LeiSbuca")
	check(lei != null and int(c.get("LeiSbuca", 0)) >= 1, "collegato: LeiSbuca")
	if lei:
		var punto: Node = lei.get(&"punto_sbuca")
		var fossa: AudioLoop = null
		if punto:
			for h in punto.get_children():
				fossa = _loop_su(h, &"fossa_ribolle_loop") if fossa == null else fossa
		var vasca_bimbi: Node = (lei.get(&"vasche") as Array)[0] if not (lei.get(&"vasche") as Array).is_empty() else null
		check(fossa != null and fossa.volume == 0.0, "la fossa tace finché l'acqua non risale")
		if fossa and vasca_bimbi:
			# Come fa la scena al buio: l'acqua risale nelle vasche basse (qui a mano, luci di prima).
			var era: bool = lei.get(&"abilitata")
			var fill0 := float(vasca_bimbi.get(&"fill"))
			lei.set(&"abilitata", true)
			for i in 30:
				vasca_bimbi.set(&"fill", fill0 + 0.002 * (i + 1))
				await get_tree().process_frame
			check(fossa.volume > 0.5 and fossa.is_suonando(), "mentre l'acqua risale la fossa ribolle")
			await _frames(40)
			check(fossa.volume == 0.0, "quando smette di salire, la fossa si calma")
			vasca_bimbi.set(&"fill", fill0)
			lei.set(&"abilitata", era)
		# Se resta affacciata più a lungo di lei_sbuca (aspetta che la guardi bene), riparte piano il
		# suo respiro col rantolo, un pezzo di lei_sbuca ripetuto; quando va sotto smette.
		var respiri := _conta(&"lei_respiro")
		var fase0 = lei.get(&"fase")
		lei.set(&"fase", LeiSbuca.Fase.GUARDA)
		await _frames(300)
		check(_conta(&"lei_respiro") == respiri, "finché dura lei_sbuca il respiro non riparte")
		await _frames(330)
		check(_conta(&"lei_respiro") >= respiri + 2, "affacciata a lungo, il respiro riparte e continua (%d giri)" % (_conta(&"lei_respiro") - respiri))
		lei.set(&"fase", LeiSbuca.Fase.SCIVOLA)
		await _frames(10)
		var dopo := _conta(&"lei_respiro")
		await _frames(240)
		check(_conta(&"lei_respiro") == dopo, "quando scivola sotto il respiro smette")
		lei.set(&"fase", fase0)
	# Quando ti prende lei: il morso subito, lo stinger quando la fauce si chiude (lampo rosso).
	var morsi := _conta(&"morso")
	var stinger := _conta(&"stinger_morte")
	audio.call(&"_su_morte", &"medusa")
	await _frames(5)
	check(_conta(&"morso") == morsi + 1 and _conta(&"stinger_morte") == stinger,
		"ti prende lei: il morso parte subito, lo stinger aspetta")
	var colpo: float = (audio.get_script() as Script).get_script_constant_map().get("MORSO_COLPO", 1.0)
	await _frames(int(colpo * 60.0) + 5)
	check(_conta(&"stinger_morte") == stinger + 1, "lo stinger arriva quando la fauce si chiude")
	audio.call(&"_su_ripartenza")
	(audio.get(&"_stinger") as AudioStreamPlayer).stop()

	print("Piscina a onde (tappa 5) e portone della torre")
	var suoni_nuovi := [&"piscina_svuota_loop", &"piscina_vuota", &"pulsante_botola_attiva",
		&"pulsante_botola_lampeggiante_loop", &"pulsante_botola_bibu", &"medusina_aspirata",
		&"medusine_sparate", &"portone_torre_apre"]
	check(suoni_nuovi.all(func(n): return audio.call(&"stream_di", n) != null),
		"ci sono gli 8 suoni scelti il 16 ottobre (piscina, pulsante, medusine, portone)")
	# le micro medusine: una entra nell'ugello, poi esce col getto
	var med: Node = _primo("Medusine")
	var am: Object = _attivo_di(med)
	check(med != null and am != null, "collegate: le micro medusine")
	if med and am:
		var aspirate := _conta(&"medusina_aspirata")
		var sparate := _conta(&"medusine_sparate")
		if med.has_signal(&"aspirata") and med.has_signal(&"sparata"):
			med.emit_signal(&"aspirata", (med as Node3D).global_position)
			await _frames(2)
			med.emit_signal(&"sparata", (med as Node3D).global_position)
			await _frames(2)
		else:
			var lista: Array = med.get(&"_medusine")
			if not lista.is_empty():
				var m0 = lista[0]
				var stato0: int = m0.stato
				m0.stato = int(am.get(&"nello_zaino"))
				await _frames(2)
				m0.stato = int(am.get(&"in_volo"))
				await _frames(2)
				m0.stato = stato0
				await _frames(2)
		check(_conta(&"medusina_aspirata") > aspirate, "una medusina aspirata: i tintinnii che scendono nel tubo")
		check(_conta(&"medusine_sparate") > sparate, "le medusine sparate via: la cascata di tintinnii")
	var piscina: Node = _primo("PiscinaOnde")
	var ap: Object = _attivo_di(piscina)
	check(piscina != null and ap != null, "collegata: la piscina a onde")
	if piscina and ap:
		var vasca_p: WaterTank = piscina.get(&"vasca")
		var gorgo: AudioLoop = ap.get(&"gorgo")
		var lamp_botola: AudioLoop = ap.get(&"lampeggiante")
		var pieno0 := vasca_p.fill
		check(gorgo != null and gorgo.volume == 0.0, "il gorgo tace finché l'acqua non scende")
		for i in 30:
			vasca_p.take_water(0.4)
			await _frames(1)
		check(gorgo.volume > 0.5 and gorgo.is_suonando(), "mentre il livello scende il gorgo suona")
		await _frames(45)
		check(gorgo.volume == 0.0, "quando smette di scendere il gorgo tace")
		# si svuota: l'ultimo sorso, poi il pulsante si attiva (scatto e jingle) e il lampeggiante gira
		var vuote := _conta(&"piscina_vuota")
		var svuotate := _conta(&"vasca_svuotata")
		var attivazioni := _conta(&"pulsante_botola_attiva")
		var bibu := _conta(&"pulsante_botola_bibu")
		vasca_p.take_water(vasca_p.capacity_liters * 2.0)
		await _frames(10)
		check(_conta(&"piscina_vuota") == vuote + 1 and _conta(&"vasca_svuotata") == svuotate,
			"a piscina vuota l'ultimo sorso (e non il suono delle vasche)")
		# il pulsante può attivarsi qualche secondo dopo (dopo l'ultimo sorso)
		for i in 360:
			if bool(piscina.get(&"attivo")):
				break
			await _frames(1)
		await _frames(2)
		check(bool(piscina.get(&"attivo")) and _conta(&"pulsante_botola_attiva") == attivazioni + 1,
			"il pulsante della botola si attiva con lo scatto e il jingle")
		await _frames(20)
		check(lamp_botola != null and lamp_botola.volume > 0.5 and lamp_botola.is_suonando(), "il lampeggiante gira")
		check(_conta(&"pulsante_botola_bibu") == bibu, "insieme al jingle niente bi-bu")
		await _frames(100)
		check(_conta(&"pulsante_botola_bibu") == bibu, "niente bi-bu ripetuto a ogni lampo (prova della v0.3.2)")
		# colpito col getto: il lampeggiante si ferma e i bi-bu smettono
		var bottone: WaterButton = piscina.get(&"pulsante")
		bottone.powered = true
		await _frames(5)
		check(lamp_botola.volume == 0.0, "colpito il pulsante, il lampeggiante si ferma")
		var bibu_dopo := _conta(&"pulsante_botola_bibu")
		await _frames(110)
		check(_conta(&"pulsante_botola_bibu") == bibu_dopo, "colpito il pulsante, niente più bi-bu")
		# com'era: pulsante spento, piscina piena
		bottone.powered = false
		piscina.call(&"load_state", {"attivo": false})
		vasca_p.fill = pieno0
		await _frames(30)
		check(lamp_botola.volume == 0.0 and not bool(ap.get(&"gira")), "a pulsante spento il lampeggiante tace")
	# il portone della sala della torre: quello vero se c'è nella sala, se no uno finto col segnale
	var portone: Node = _primo("PortoneTorre")
	var finto: Node3D = null
	if portone == null:
		finto = Node3D.new()
		finto.name = "PortoneFinto"
		finto.add_user_signal("apertura_iniziata")
		level.add_child(finto)
		audio.call(&"_collega_portone_torre", finto)
		portone = finto
	else:
		check(int(c.get("PortoneTorre", 0)) >= 1, "collegato: PortoneTorre")
	var portoni := _conta(&"portone_torre_apre")
	portone.emit_signal(&"apertura_iniziata")
	await _frames(2)
	check(_conta(&"portone_torre_apre") == portoni + 1, "il portone della torre si apre col suo suono")
	if finto:
		finto.queue_free()

	print("Nomi dei suoni negli script del gioco")
	var mancanti := _suoni_mancanti("res://scripts") + _suoni_mancanti("res://addons/audio")
	check(mancanti.is_empty(), "tutti i suoni chiesti dagli script esistono %s" % str(mancanti))

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
		# dell'audio: nei suoi file, nei server audio o con addons/audio nella pila GDScript
		var testo: String = "%s %s %s %s" % [e["file"], e["codice"], e["motivo"], e["pila"]]
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


## L'oggetto dell'audio che segue [param nodo] (AudioPiscina, AudioMedusine...), o null.
func _attivo_di(nodo: Node) -> Object:
	if nodo == null:
		return null
	for a in audio.get(&"_attivi"):
		if a is Object and a.get(&"n") == nodo:
			return a
	return null


func _zaino() -> Object:
	for a in audio.get(&"_attivi"):
		if a.get(&"pack") == p.water_pack:
			return a
	return null


## I nomi di suono scritti negli script (suona, crea_loop, ...) che non sono nel catalogo.
func _suoni_mancanti(cartella: String) -> Array:
	var modi := [
		# suona(&"x"), _suona(&"x"), a.crea_loop(&"x", ...)
		RegEx.create_from_string("(?:^|[^a-z0-9_])_?(?:suona|crea_loop|crea_loop_2d)\\(\\s*&\"([a-z0-9_]+)\""),
		# audio.call(&"suona", &"x", ...)
		RegEx.create_from_string("call\\(\\s*&\"(?:suona|crea_loop|crea_loop_2d)\"\\s*,\\s*&\"([a-z0-9_]+)\""),
		# suona_limitato(chiave, intervallo, &"x", ...)
		RegEx.create_from_string("suona_limitato\\([^,]*,[^,]*,\\s*&\"([a-z0-9_]+)\""),
	]
	var mancanti := []
	for f in _file_gd(cartella):
		for riga in FileAccess.get_file_as_string(f).split("\n"):
			for re in modi:
				for m in (re as RegEx).search_all(riga):
					var nome := m.get_string(1)
					if not Catalogo.SUONI.has(StringName(nome)):
						mancanti.append("%s: %s" % [f.get_file(), nome])
	return mancanti


func _file_gd(cartella: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(cartella):
		if f.ends_with(".gd"):
			out.append(cartella.path_join(f))
	for d in DirAccess.get_directories_at(cartella):
		out.append_array(_file_gd(cartella.path_join(d)))
	return out


## Il primo nodo della sala con questa classe (class_name), o null.
func _primo(classe: String) -> Node:
	var trovati := level.find_children("*", classe, true, false)
	return trovati[0] if not trovati.is_empty() else null


## Il loop dell'audio con questo suono tra i figli di [param n], o null.
func _loop_su(n: Node, nome: StringName) -> AudioLoop:
	if n == null:
		return null
	var s: AudioStream = audio.call(&"stream_di", nome)
	for l in n.find_children("*", "AudioLoop", false, false):
		if (l as AudioLoop).player and (l as AudioLoop).player.stream == s:
			return l
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
