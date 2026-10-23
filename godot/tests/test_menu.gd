extends Node
## Test del titolo, del caricamento e del menu di pausa:
## il titolo è la scena principale e si carica (statua, piedistallo, lampi); le voci ci sono e si
## scorrono con la tastiera (anche dall'ultima alla prima); Esc nel titolo non apre la pausa; la
## calibrazione della luminosità sopra il titolo lo ferma e poi gli ridà il focus; Comandi e
## Opzioni si aprono e si chiudono con Esc; Nuova partita passa al caricamento a thread e arriva
## alla sala con la dissolvenza dal nero; nel menu di pausa ci sono Comandi e Torna al titolo.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_menu.gd
## Con "solo_titolo" dopo il percorso del test si ferma prima di caricare la sala (più leggero).

const TITOLO := "res://scenes/ui/menu_principale.tscn"
const CARICAMENTO := "res://scenes/ui/caricamento.tscn"
const SALA := "res://scenes/sala_principale.tscn"
## Secondi massimi (veri) per caricare la sala.
const ATTESA_MASSIMA := 300.0

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Grafica.salva_su_disco = false
	print("Il titolo")
	check(ProjectSettings.get_setting("application/run/main_scene") == TITOLO, "il titolo è la scena principale del progetto")
	get_tree().change_scene_to_file(TITOLO)
	await _frames(5)
	var menu := get_tree().current_scene
	check(menu != null and menu.scene_file_path == TITOLO, "la scena del titolo si carica")
	if menu == null or menu.scene_file_path != TITOLO:
		_fine()
		return
	var medusa := menu.get_node_or_null("Statua/Medusa") as MedusaStatue
	check(medusa != null and medusa.get_model_instance() != null, "la statua della medusa c'è")
	if medusa and medusa.get_model_instance():
		# La medusa finita (lavoro/medusa 6585aa6): mani nuove, occhio con la venatura, strappo nascosto.
		var mod := medusa.get_model_instance()
		check(mod.scale.is_equal_approx(Vector3.ONE), "la statua ha la sua grandezza vera (4,5 m, nessuna scala)")
		var mani := mod.find_child("Medusa_Mani", true, false) as MeshInstance3D
		var mm := mani.get_surface_override_material(0) if mani else null
		check(mm != null and mm.resource_name == "M_mani", "le mani nuove hanno il vinile della medusa")
		var occhio := mod.find_child("Medusa_Occhio", true, false) as MeshInstance3D
		var om := occhio.get_surface_override_material(0) as ShaderMaterial if occhio else null
		check(om != null and om.shader.resource_path.ends_with("medusa_occhio.gdshader"), "l'occhio usa lo shader con la venatura")
		var strappo := mod.find_child("Medusa_Strappo", true, false) as MeshInstance3D
		var sm := strappo.get_surface_override_material(0) as BaseMaterial3D if strappo else null
		check(strappo != null and not strappo.visible and sm != null and sm.vertex_color_use_as_albedo
				and sm.albedo_color.is_equal_approx(Color(0.74, 0.8, 1.0)), "lo strappo della fauce è nascosto e ha la tinta della pelle")
	var piedistallo := menu.get_node_or_null("Statua/Piedistallo")
	check(piedistallo != null and piedistallo.find_child("amb_piedistallo", true, false) is MeshInstance3D,
		"c'è il piedistallo della sala")
	check(menu.get_node_or_null("Tempesta") is Tempesta, "ci sono i lampi della tempesta")
	check(not _scrive_il_nome(menu), "il nome provvisorio del gioco non è scritto sul titolo")
	# Il logo A (scelta dell'utente del 22 ottobre): in alto a sinistra, dentro lo schermo, sopra capitolo e
	# voci senza toccarli, e visibile anche a 16:10.
	var logo := menu.find_child("Logo", true, false) as TextureRect
	check(logo != null and logo.texture != null and logo.texture.resource_path.ends_with("logo_jilly_jubilee.png"),
		"c'è il logo del gioco")
	if logo:
		var r_logo := logo.get_global_rect()
		var schermo := Rect2(Vector2.ZERO, Vector2(1280, 720))
		var testata := menu.find_child("Testata", true, false) as Control
		var voci_menu := menu.find_child("Menu", true, false) as Control
		check(schermo.encloses(r_logo), "il logo sta tutto nello schermo (%s)" % r_logo)
		check(testata != null and not r_logo.intersects(testata.get_global_rect())
				and voci_menu != null and not r_logo.intersects(voci_menu.get_global_rect()),
			"il logo non copre capitolo e voci")
		check(r_logo.end.x < 640, "il logo resta nella metà sinistra, la statua a destra")
		check(logo.texture.get_width() >= 2 * int(r_logo.size.x), "il logo ha risoluzione per 1920x1080 e oltre")
	var versione := menu.find_child("Versione", true, false) as Label
	var attesa := "Capitolo 1 · demo %s" % ProjectSettings.get_setting("application/config/version")
	check(versione != null and versione.text == attesa,
		"in piccolo capitolo e versione (%s)" % (versione.text if versione else "-"))
	var voci: Array = menu.call(&"voci")
	var nomi := []
	for v in voci:
		nomi.append(String(v.name))
	check(nomi == ["NuovaPartita", "Opzioni", "Comandi", "Esci"], "le voci sono Nuova partita, Opzioni, Comandi, Esci")
	check(voci.size() == 4 and voci[0].text == "NUOVA PARTITA", "testo della prima voce: %s" % (voci[0].text if voci.size() > 0 else "-"))
	await _frames(2)
	check(_focus() == voci[0], "Nuova partita ha il focus")
	var audio := get_node_or_null(^"/root/Audio")
	if audio:
		var conteggio: Dictionary = audio.get(&"conteggio")
		check(int(conteggio.get(&"sigla_pulita", 0)) >= 1, "nel titolo parte la sigla pulita")

	print("Tastiera e joypad (azioni ui_*)")
	await _premi(&"ui_down")
	check(_focus() == voci[1], "giù: Opzioni")
	await _premi(&"ui_up")
	await _premi(&"ui_up")
	check(_focus() == voci[3], "su dalla prima voce: si passa a Esci")
	await _premi(&"ui_down")
	check(_focus() == voci[0], "giù dall'ultima voce: si torna a Nuova partita")
	await _premi(&"pause")
	check(not get_tree().paused and not Game.is_paused(), "Esc nel titolo non apre la pausa")

	print("Calibrazione della luminosità al primo avvio, sopra il titolo")
	Game.call(&"_show_calibration")
	await _frames(3)
	check(get_tree().paused, "la calibrazione ferma il titolo")
	var cal: CalibrazioneLuminosita = null
	for n in Game.find_children("*", "Control", true, false):
		if n is CalibrazioneLuminosita:
			cal = n
	check(cal != null, "la calibrazione è aperta")
	if cal:
		# Deve stare sopra tutti i livelli del titolo, se no il menu la copre e non si può confermare.
		var livello_cal := (cal.owner as CanvasLayer).layer if cal.owner is CanvasLayer else 0
		var livello_titolo := -1000
		for l in menu.find_children("*", "CanvasLayer", true, false):
			livello_titolo = maxi(livello_titolo, (l as CanvasLayer).layer)
		check(livello_cal > livello_titolo, "la calibrazione sta sopra il menu del titolo (%d > %d)" % [livello_cal, livello_titolo])
		# Come il giocatore: Conferma ha il focus e si preme con Invio.
		var conferma := _pulsante(cal, "Conferma")
		check(conferma != null and _focus() == conferma, "Conferma ha il focus")
		await _premi(&"ui_accept")
		await _frames(3)
		if get_tree().paused:
			check(false, "Invio conferma la calibrazione")
			cal.conferma()
	await _frames(5)
	check(not get_tree().paused, "confermata la calibrazione, il titolo riparte")
	check(bool(Grafica.valore("calibrato")), "la calibrazione è segnata come fatta")
	check(_focus() == voci[0], "il titolo riprende il focus")

	print("Comandi")
	voci[2].pressed.emit()
	await _frames(3)
	var sotto: CanvasLayer = menu.call(&"sottomenu")
	var comandi := sotto.get_node_or_null("Comandi") as SchermataComandi if sotto else null
	check(comandi != null, "Comandi apre la schermata dei comandi")
	if comandi:
		var elenco := comandi.find_child("Elenco", true, false) as GridContainer
		check(elenco != null and elenco.get_child_count() == SchermataComandi.RIGHE.size() * 2,
			"ci sono tutte le righe dei comandi")
		check(_focus() == comandi.find_child("Indietro", true, false), "Indietro ha il focus")
	check(SchermataComandi.nomi_tasti([&"move_forward", &"move_left", &"move_back", &"move_right"]) == PackedStringArray(["W", "A", "S", "D"]),
		"muoversi: W A S D, dalla InputMap")
	check(SchermataComandi.nomi_tasti([&"sprint"]) == PackedStringArray(["Maiusc"]), "correre: Maiusc")
	check(SchermataComandi.nomi_tasti([&"crouch"]) == PackedStringArray(["Ctrl"]), "abbassarsi: Ctrl")
	check(SchermataComandi.nomi_tasti([&"jump"]) == PackedStringArray(["Spazio"]), "saltare: Spazio")
	check(SchermataComandi.nomi_tasti([&"torcia"]) == PackedStringArray(["F"]), "torcia: F")
	check(SchermataComandi.nomi_tasti([&"interact"]) == PackedStringArray(["E"]), "usare: E")
	check(SchermataComandi.nomi_tasti([&"spray"]) == PackedStringArray(["Tasto sinistro"]), "spruzzare: tasto sinistro")
	check(SchermataComandi.nomi_tasti([&"suck"]) == PackedStringArray(["Tasto destro"]), "aspirare: tasto destro")
	check(SchermataComandi.nomi_tasti([&"pause"]) == PackedStringArray(["Esc"]), "pausa: Esc")
	await _premi(&"ui_cancel")
	await _frames(2)
	check(menu.call(&"sottomenu") == null, "Esc chiude i comandi")
	check(_focus() == voci[2], "il focus torna su Comandi")
	check(not get_tree().paused, "e la pausa resta chiusa")

	print("Opzioni")
	voci[1].pressed.emit()
	await _frames(3)
	sotto = menu.call(&"sottomenu")
	check(sotto != null and sotto.get_node_or_null("Menu") is MenuOpzioni, "Opzioni apre il menu dell'addon grafica")
	await _premi(&"ui_cancel")
	await _frames(2)
	check(menu.call(&"sottomenu") == null, "Esc chiude le opzioni")
	check(_focus() == voci[1], "il focus torna su Opzioni")

	if OS.get_cmdline_user_args().has("solo_titolo"):
		_fine()
		return

	print("Nuova partita: caricamento a thread e sala")
	GameState.snapshot = {"scene": "res://finta.tscn"}
	voci[0].pressed.emit()
	var car: Node = null
	for i in 400:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == CARICAMENTO:
			car = s
			break
	check(car != null, "Nuova partita porta alla schermata di caricamento")
	check(GameState.snapshot.is_empty(), "i progressi in memoria ripartono da zero")
	if car == null:
		_fine()
		return
	check(car.find_child("Barra", true, false) is ProgressBar, "c'è la barra di avanzamento")
	var consiglio := car.find_child("Consiglio", true, false) as Label
	check(consiglio != null and consiglio.text != "" and not consiglio.text.contains("{"), "c'è un consiglio: %s" % (consiglio.text if consiglio else "-"))
	check(car.find_child("Elenco", true, false) is GridContainer, "ci sono i comandi")
	check(not _scrive_il_nome(car), "il nome provvisorio non è scritto nel caricamento")
	await _premi(&"pause")
	check(not get_tree().paused, "Esc durante il caricamento non apre la pausa")
	var t0 := Time.get_ticks_msec()
	var a_meta := false
	var arrivato := false
	while (Time.get_ticks_msec() - t0) / 1000.0 < ATTESA_MASSIMA:
		await get_tree().process_frame
		if is_instance_valid(car) and car.is_inside_tree():
			var av := float(car.get(&"avanzamento"))
			if av > 0.05 and av < 0.95:
				a_meta = true
		var s := get_tree().current_scene
		if s and s.scene_file_path == SALA and GameState.player and is_instance_valid(GameState.player):
			arrivato = true
			break
	check(a_meta, "la barra avanza mentre carica")
	check(arrivato, "si arriva alla sala (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if not arrivato:
		_fine()
		return
	check(Dissolvenza.presente(get_tree()), "la sala entra dal nero")
	for i in 600:
		if not Dissolvenza.presente(get_tree()):
			break
		await get_tree().process_frame
	check(not Dissolvenza.presente(get_tree()), "la dissolvenza dal nero finisce")
	check(not get_tree().paused and Game.pause_on_focus_loss, "si gioca: niente pausa, la pausa automatica è di nuovo attiva")

	print("Menu di pausa")
	Game.set_paused(true)
	await _frames(3)
	var overlay := Game.get_node("PauseOverlay") as CanvasLayer
	var b_comandi := _pulsante(overlay, "Comandi")
	var b_titolo := _pulsante(overlay, "Torna al titolo")
	check(_pulsante(overlay, "Riprendi") != null and _pulsante(overlay, "Opzioni") != null
		and _pulsante(overlay, "Esci dal gioco") != null, "le voci di prima ci sono ancora")
	check(b_comandi != null, "c'è Comandi")
	check(b_titolo != null, "c'è Torna al titolo")
	if b_comandi:
		b_comandi.pressed.emit()
		await _frames(3)
		check(Game.find_child("Comandi", true, false) is SchermataComandi and not overlay.visible, "Comandi apre la schermata sopra la pausa")
		await _premi(&"ui_cancel")
		await _frames(3)
		check(Game.find_child("Comandi", true, false) == null, "Esc chiude i comandi")
		check(overlay.visible and get_tree().paused, "e si torna al menu di pausa")
	if b_titolo:
		b_titolo.pressed.emit()
		for i in 300:
			await get_tree().process_frame
			var s := get_tree().current_scene
			if s and s.scene_file_path == TITOLO:
				break
		var s := get_tree().current_scene
		check(s != null and s.scene_file_path == TITOLO, "Torna al titolo riporta al titolo")
		check(not get_tree().paused and not overlay.visible, "senza la pausa")
		await _frames(5)
		check(s != null and _focus() == s.call(&"voci")[0], "con il focus su Nuova partita")
	await _test_riserva_caricamento()
	_fine()


## Se il caricamento nel thread fallisce, la sala si carica di seguito (riserva) invece di fermarsi
## sull'errore. Qui il thread "fallisce" perché il risultato lo si prende prima noi: il caricamento
## trova allora lo stato INVALID_RESOURCE, come quando il thread non ce la fa.
func _test_riserva_caricamento() -> void:
	print("Caricamento: la riserva se il thread fallisce")
	const LEGGERA := "res://scenes/test/scivoli_prova.tscn"
	var car: Node = (load(CARICAMENTO) as PackedScene).instantiate()
	car.set(&"scena", LEGGERA)
	car.set(&"tempo_minimo", 999.0)   # resta nella schermata: qui non si entra nella scena
	get_tree().root.add_child(car)
	var t0 := Time.get_ticks_msec()
	while ResourceLoader.load_threaded_get_status(LEGGERA) == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
			and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	ResourceLoader.load_threaded_get(LEGGERA)
	await _frames(5)
	check(car.get(&"fase") == 0 and car.get(&"_pacchetto") is PackedScene,
		"il thread fallisce: la scena si carica lo stesso e si va avanti, senza errore")
	car.queue_free()
	await _frames(2)


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)  # aspetta i caricamenti nel thread


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


## Vero se un'etichetta della scena scrive il nome provvisorio del gioco (GDD).
func _scrive_il_nome(radice: Node) -> bool:
	for l in radice.find_children("*", "Label", true, false):
		if (l as Label).text.to_lower().contains("lagoon"):
			return true
	return false


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _pulsante(radice: Node, testo: String) -> Button:
	for b in radice.find_children("*", "Button", true, false):
		if (b as Button).text == testo:
			return b
	return null


## Preme e rilascia un'azione come farebbe un tasto (passa dalla GUI e da _unhandled_input).
func _premi(azione: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = azione
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(1)
	var su := InputEventAction.new()
	su.action = azione
	su.pressed = false
	Input.parse_input_event(su)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
