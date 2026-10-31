extends Node3D
## Schermata del titolo, il "manifesto" del gioco: solo la statua della medusa sul monumento,
## nella nebbia, con i fari della galleria e i lampi lontani; la camera sale piano dal piedistallo
## fino al viso. Il nome del gioco è provvisorio (GDD), quindi non è scritto: sopra il menu c'è
## solo, in piccolo, "Capitolo 1 · demo <versione>". Voci: Continua (solo se c'è un salvataggio valido: riparte
## dall'ultimo checkpoint, GameState.continue_from_disk), Nuova partita (porta alla schermata di caricamento della sala), Opzioni
## (menu dell'addon grafica), Comandi, Esci. Mouse, tastiera e joypad (azioni ui_*). F9 apre il menu di prova
## nascosto (MenuProva: partire da una parte del capitolo), che non è fra le voci.
## La calibrazione della luminosità del primo avvio la mostra Game, sopra il titolo.

const SCENA_CARICAMENTO := "res://scenes/ui/caricamento.tscn"
const SCENA_COMANDI := "res://scenes/ui/comandi.tscn"
const SCENA_OPZIONI := "res://addons/grafica/menu_opzioni.tscn"
const DOMANDA := preload("res://scripts/ui/menu/domanda_menu.gd")
## Il logo del gioco, la A: l'insegna del parco rovinata (scelta dell'utente del 22 ottobre;
## originale in docs/concept/logo/, disegnato da assets_src/logo/logo_jilly.py).
const LOGO := preload("res://assets/ui/logo/logo_jilly_jubilee.png")
## Dove sta il logo, nelle coordinate dell'interfaccia (1280x720): in alto a sinistra, sopra capitolo e
## voci, come nella prova vista dall'utente (docs/concept/logo/titolo_a.jpg).
const LOGO_RETTANGOLO := Rect2(91, 30, 431, 225)

@export var camera: Camera3D
@export var statua: Node3D
@export var tempesta: Tempesta

@export_group("Camera")
## Secondi della salita dal piedistallo al viso; poi la camera resta sul viso e respira appena.
@export var durata_salita := 40.0
## Distanza orizzontale dalla statua: all'inizio e alla fine.
@export var raggio := Vector2(7.6, 5.4)
## Angolo intorno alla statua (radianti, 0 = proprio davanti): all'inizio e alla fine.
@export var angolo := Vector2(-0.34, 0.04)
## Altezza della camera: all'inizio e alla fine.
@export var altezza := Vector2(0.7, 2.55)
## Altezza del punto guardato: all'inizio (la statua intera, con la faccia già dentro lo schermo:
## riscontro del 18 ottobre, prima si partiva dai tentacoli con la testa tagliata) e alla fine (viso).
@export var altezza_sguardo := Vector2(3.3, 4.6)
## Spostamento laterale del punto guardato (m, negativo = a sinistra): la statua resta a
## destra dell'inquadratura e il menu a sinistra.
@export var spostamento := -1.35

var _t := 0.0
var _lampo_finale := false
var _avviato := false
var _menu: VBoxContainer
var _voci: Array[Button] = []
var _voce_nuova: Button
var _voce_opzioni: Button
var _voce_comandi: Button
var _testata: Control
var _logo: TextureRect
var _sottomenu: CanvasLayer
var _pausa_fuoco := true
## La partenza da riga di comando (vedi [method _partenza_da_riga]) si fa una volta sola, al primo titolo.
static var _riga_fatta := false


func _ready() -> void:
	# Nel titolo niente pausa (né con Esc né quando la finestra perde il fuoco) e mouse libero.
	_pausa_fuoco = Game.pause_on_focus_loss
	Game.pause_on_focus_loss = false
	Game.release_mouse()
	_costruisci_interfaccia()
	_aggiorna_camera(0.0)
	# Si entra dal nero (anche tornando dal gioco), con la sigla pulita.
	var velo := Dissolvenza.di(get_tree())
	velo.nero()
	velo.schiarisci(2.4, 2)
	_audio(&"ferma_tutto")
	_audio(&"musica_titolo")
	_voci[0].grab_focus.call_deferred()
	_partenza_da_riga.call_deferred()


## Per le prove (la prova su Windows nella CI, il collaudo), dopo il -- della riga di comando: --partenza=<id> parte
## subito da una partenza del menu di prova (MenuProva.PARTENZE: torre, inseguimento, tunnel...), --preset=<nome> mette
## prima quel preset grafico, --esci-dopo=<s> chiude il gioco dopo quei secondi, --resta=<s> lo chiude quei secondi dopo
## che si è arrivati (finita la schermata di caricamento e i caricamenti nel thread), --registro-prova=<file> scrive le
## righe PROVA anche in quel file, aperto e chiuso a ogni riga (il registro di Godot, se il gioco si chiude di colpo, può
## restare indietro). Ogni 5 s una riga con la memoria, la scena e dove è il giocatore. Senza, niente.
func _partenza_da_riga() -> void:
	if _riga_fatta:
		return
	_riga_fatta = true
	var partenza := ""
	var preset := ""
	var esci := 0.0
	var resta := 0.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--partenza="):
			partenza = a.get_slice("=", 1)
		elif a.begins_with("--preset="):
			preset = a.get_slice("=", 1)
		elif a.begins_with("--esci-dopo="):
			esci = a.get_slice("=", 1).to_float()
		elif a.begins_with("--resta="):
			resta = a.get_slice("=", 1).to_float()
		elif a.begins_with("--registro-prova="):
			_registro_prova = a.substr(17)
	if partenza == "" and esci <= 0.0 and resta <= 0.0:
		return
	if _registro_prova != "":
		var f := FileAccess.open(_registro_prova, FileAccess.WRITE)
		if f:
			f.close()
	if preset != "":
		Grafica.applica_preset(preset)
		_prova("PROVA: preset %s" % preset)
	var albero := get_tree()
	var conta := Timer.new()
	conta.wait_time = 5.0
	conta.process_mode = Node.PROCESS_MODE_ALWAYS
	var arrivato := [-1.0]
	# il picco della memoria video a ogni fotogramma: in tutto, e dall'arrivo (le righe ogni 5 s non lo vedono)
	var picco := [0, 0]
	albero.process_frame.connect(func() -> void:
		var v := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) >> 20
		picco[0] = maxi(int(picco[0]), v)
		if arrivato[0] >= 0.0:
			picco[1] = maxi(int(picco[1]), v))
	conta.timeout.connect(func() -> void:
		var sc := albero.current_scene
		var g := albero.get_first_node_in_group(&"player") as Node3D
		if arrivato[0] < 0.0 and sc and String(sc.name) != "Caricamento" and String(sc.name) != "MenuPrincipale" \
				and not Game.caricamenti_in_corso():
			arrivato[0] = Time.get_ticks_msec() / 1000.0
			_prova("PROVA: ARRIVATO a %d s, giocatore a %s" % [int(arrivato[0]), g.global_position if g else "-"])
		if resta > 0.0 and arrivato[0] >= 0.0 and Time.get_ticks_msec() / 1000.0 - arrivato[0] >= resta:
			_prova("PROVA: RESTATO %d s dopo l'arrivo, esco; picco video in tutto %d MB, dall'arrivo %d MB" % [int(resta),
					int(picco[0]), int(picco[1])])
			albero.quit()
		_prova("PROVA t=%d scena=%s caricamenti=%s pos=%s memoria=%d MB picco_video=%d MB video=%d MB texture=%d MB buffer=%d MB oggetti=%d fps=%d" % [
				Time.get_ticks_msec() / 1000, String(sc.name) if sc else "-", Game.caricamenti_in_corso(),
				g.global_position if g else "-", OS.get_static_memory_usage() >> 20, int(picco[0]),
				int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) >> 20,
				int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) >> 20,
				int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)) >> 20,
				int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Engine.get_frames_per_second())]))
	albero.root.add_child(conta)
	conta.start()
	if esci > 0.0:
		albero.create_timer(esci, true, false, true).timeout.connect(func() -> void:
			_prova("PROVA: esco dopo %s s" % esci)
			albero.quit())
	if partenza != "":
		_prova("PROVA: parto da %s -> %s" % [partenza, MenuProva.parti(albero, partenza)])


## Il file di --registro-prova (vuoto: nessuno).
static var _registro_prova := ""


## Una riga PROVA: nel registro di Godot e, se c'è, nel file della prova (aperto e chiuso subito: resta anche se il gioco
## si chiude di colpo).
static func _prova(riga: String) -> void:
	print(riga)
	if _registro_prova == "":
		return
	var f := FileAccess.open(_registro_prova, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line("%s %s" % [Time.get_time_string_from_system(), riga])
		f.close()


func _exit_tree() -> void:
	Game.pause_on_focus_loss = _pausa_fuoco


func _process(delta: float) -> void:
	_t += delta
	_aggiorna_camera(delta)
	if not _lampo_finale and _t > durata_salita * 0.93 and tempesta:
		# Quando la camera arriva al viso, un lampo vicino.
		_lampo_finale = true
		tempesta.lampo_ora(1.35, 0.7, PI * 0.8)
	if _avviato:
		return
	# Il mouse resta libero anche se qualcuno lo cattura (per esempio Game alla fine della
	# calibrazione della luminosità).
	if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not is_instance_valid(_sottomenu) and get_viewport().gui_get_focus_owner() == null:
		_voci[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_sottomenu):
		return  # opzioni e comandi gestiscono da soli Esc
	# il menu di prova nascosto (F9, non è fra le voci né nei comandi): partire da una parte del capitolo
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).keycode == MenuProva.TASTO:
		get_viewport().set_input_as_handled()
		apri_prova()
		return
	# Nel titolo Esc non apre la pausa di Game.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


# --- Voci del menu ------------------------------------------------------------------------

## Nuova partita. Con un salvataggio valido prima la domanda "Ricominciare da capo?" (scelta A dell'utente del 25
## ottobre: il focus parte su No, e B o Esc valgono No); senza, si parte subito. Il salvataggio di prima si sostituisce
## solo al primo checkpoint vero (GameState.capture_snapshot).
func nuova_partita() -> void:
	if _avviato or is_instance_valid(_sottomenu):
		return
	if GameState.has_save():
		_chiedi_nuova_partita()
		return
	_avvia_nuova_partita()


func _chiedi_nuova_partita() -> void:
	var d: CanvasLayer = DOMANDA.new("Ricominciare da capo?", "Il salvataggio verrà sostituito")
	d.name = "DomandaNuovaPartita"
	_sottomenu = d
	add_child(d)
	_menu.visible = false
	_testata.visible = false
	_logo.visible = false
	d.connect(&"risposta", func(si: bool):
		_sottomenu = null
		if si:
			_avvia_nuova_partita()
			return
		_menu.visible = true
		_testata.visible = true
		_logo.visible = true
		_voce_nuova.grab_focus.call_deferred())


func _avvia_nuova_partita() -> void:
	if _avviato:
		return
	_avviato = true
	for v in _voci:
		v.disabled = true
	GameState.reset_progress()
	_audio(&"ferma_musica", [0.9])
	await Dissolvenza.di(get_tree()).scurisci(0.9)
	# lo spot VHS della crociera (GDD, "Lo spot della crociera Jubilee"), poi il risveglio: si salta tenendo premuto un
	# tasto, alla fine il lettore passa da solo al caricamento. Il titolo sotto si ferma e non si disegna più.
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false
	LettoreSpot.avvia(get_tree(), SCENA_CARICAMENTO)


## Continua dall'ultimo checkpoint salvato su disco, con la schermata di caricamento.
func continua() -> void:
	if _avviato or is_instance_valid(_sottomenu) or not GameState.has_save():
		return
	_avviato = true
	for v in _voci:
		v.disabled = true
	_audio(&"ferma_musica", [0.9])
	await Dissolvenza.di(get_tree()).scurisci(0.6)
	if not GameState.continue_from_disk():
		# (il salvataggio si è guastato nel frattempo: si resta nel titolo)
		_avviato = false
		for v in _voci:
			v.disabled = false
		Dissolvenza.di(get_tree()).schiarisci(0.6)


func apri_opzioni() -> void:
	_apri(SCENA_OPZIONI, ^"Menu", _voce_opzioni)


func apri_comandi() -> void:
	_apri(SCENA_COMANDI, ^"Comandi", _voce_comandi)


func esci() -> void:
	Game.esci()


## Il menu di prova nascosto (MenuProva): sceglie da dove partire; "Inizio" è la nuova partita normale.
func apri_prova() -> void:
	if _avviato or is_instance_valid(_sottomenu):
		return
	var m := MenuProva.new()
	m.name = "MenuProva"
	_sottomenu = m
	add_child(m)
	_menu.visible = false
	m.chiuso.connect(func():
		_sottomenu = null
		_menu.visible = true
		_voci[0].grab_focus.call_deferred())
	m.scelta.connect(_parti_prova)


func _parti_prova(id: String) -> void:
	if is_instance_valid(_sottomenu):
		_sottomenu.queue_free()
	_sottomenu = null
	if id == "inizio":
		nuova_partita()
		return
	_avviato = true
	for v in _voci:
		v.disabled = true
	_audio(&"ferma_musica", [0.9])
	await Dissolvenza.di(get_tree()).scurisci(0.6)
	if not MenuProva.parti(get_tree(), id):
		# (il file non c'è: si resta nel titolo)
		_avviato = false
		for v in _voci:
			v.disabled = false
		_menu.visible = true
		Dissolvenza.di(get_tree()).schiarisci(0.6)


## Chiama l'autoload Audio (addons/audio) se c'è: il titolo funziona anche senza.
func _audio(metodo: StringName, argomenti := []) -> void:
	var audio := get_node_or_null(^"/root/Audio")
	if audio and audio.has_method(metodo):
		audio.callv(metodo, argomenti)


func _apri(scena: String, controllo: NodePath, voce: Button) -> void:
	if _avviato or is_instance_valid(_sottomenu):
		return
	_sottomenu = load(scena).instantiate()
	add_child(_sottomenu)
	# Sotto opzioni e comandi restano solo la statua e la nebbia.
	_menu.visible = false
	_testata.visible = false
	_logo.visible = false
	_sottomenu.get_node(controllo).connect(&"chiuso", func():
		_sottomenu = null
		_menu.visible = true
		_testata.visible = true
		_logo.visible = true
		voce.grab_focus.call_deferred())


## Le voci del menu (per i test e gli screenshot).
func voci() -> Array[Button]:
	return _voci


func sottomenu() -> CanvasLayer:
	return _sottomenu if is_instance_valid(_sottomenu) else null


# --- Camera -------------------------------------------------------------------------------

func _aggiorna_camera(_delta: float) -> void:
	if camera == null or statua == null:
		return
	var k := clampf(_t / maxf(durata_salita, 0.01), 0.0, 1.0)
	var s := k * k * (3.0 - 2.0 * k)
	# Finita la salita, un respiro appena percettibile.
	var dopo := maxf(_t - durata_salita, 0.0)
	var respiro := smoothstep(0.0, 6.0, dopo)
	var a := lerpf(angolo.x, angolo.y, s) + sin(dopo * 0.11) * 0.035 * respiro
	var h := lerpf(altezza.x, altezza.y, s) + sin(dopo * 0.23) * 0.06 * respiro
	var r := lerpf(raggio.x, raggio.y, s)
	var centro := statua.global_position
	var pos := centro + Vector3(sin(a) * r, h, cos(a) * r)
	var guarda := centro + Vector3(0.0, lerpf(altezza_sguardo.x, altezza_sguardo.y, s), 0.0)
	var avanti := guarda - pos
	avanti.y = 0.0
	guarda += avanti.normalized().cross(Vector3.UP) * spostamento
	camera.look_at_from_position(pos, guarda, Vector3.UP)


# --- Interfaccia --------------------------------------------------------------------------

func _costruisci_interfaccia() -> void:
	# La scritta piccola sotto il post-processing (livello 40): ha la grana della pellicola.
	var manifesto := CanvasLayer.new()
	manifesto.name = "Manifesto"
	manifesto.layer = 40
	add_child(manifesto)
	var fondo := Control.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	manifesto.add_child(fondo)
	# Ombra a sinistra, per leggere le voci sopra la scena.
	var ombra := TextureRect.new()
	ombra.texture = StileMenu.sfumatura(
		PackedColorArray([Color(0, 0, 0, 0.82), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0)]),
		PackedFloat32Array([0.0, 0.42, 1.0]))
	ombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ombra.stretch_mode = TextureRect.STRETCH_SCALE
	ombra.anchor_right = 0.6
	ombra.anchor_bottom = 1.0
	ombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.add_child(ombra)

	# Il logo, sotto il post-processing come la scritta piccola: prende la grana della pellicola.
	_logo = TextureRect.new()
	_logo.name = "Logo"
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_logo.position = LOGO_RETTANGOLO.position
	_logo.size = LOGO_RETTANGOLO.size
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.add_child(_logo)

	# Capitolo e versione, in piccolo, appena sopra le voci (allineati al loro testo).
	var testata := HBoxContainer.new()
	testata.name = "Testata"
	testata.position = Vector2(84, 270)
	testata.add_theme_constant_override("separation", 14)
	fondo.add_child(testata)
	_testata = testata
	var linea := ColorRect.new()
	linea.color = StileMenu.ROSSO
	linea.custom_minimum_size = Vector2(72, 3)
	linea.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	testata.add_child(linea)
	var versione := StileMenu.etichetta("", StileMenu.barlow(), 18, StileMenu.TESTO_SPENTO)
	versione.name = "Versione"
	Lingua.segui(versione, func():
		versione.text = Lingua.t("Capitolo 1 · demo %s") % ProjectSettings.get_setting("application/config/version", ""))
	testata.add_child(versione)

	# Voci del menu sopra il post-processing (livello 100), nitide.
	var livello := CanvasLayer.new()
	livello.name = "Interfaccia"
	livello.layer = 100
	add_child(livello)
	var radice := Control.new()
	radice.name = "Radice"
	radice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# I clic a vuoto si fermano qui: non arrivano a Game, che catturerebbe il mouse.
	radice.mouse_filter = Control.MOUSE_FILTER_STOP
	radice.theme = StileMenu.tema()
	livello.add_child(radice)
	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.position = Vector2(56, 318)
	_menu.custom_minimum_size.x = 400
	_menu.add_theme_constant_override("separation", 4)
	radice.add_child(_menu)
	# Continua solo se c'è un salvataggio da cui ripartire: è la prima voce, sopra Nuova partita
	if GameState.has_save():
		_voci.append(_voce("Continua", "Continua", continua))
	_voce_nuova = _voce("NuovaPartita", "Nuova partita", nuova_partita)
	_voci.append(_voce_nuova)
	_voce_opzioni = _voce("Opzioni", "Opzioni", apri_opzioni)
	_voci.append(_voce_opzioni)
	_voce_comandi = _voce("Comandi", "Comandi", apri_comandi)
	_voci.append(_voce_comandi)
	_voci.append(_voce("Esci", "Esci", esci))
	StileMenu.collega_voci(_voci)


func _voce(nome: String, testo: String, azione: Callable) -> Button:
	var b := StileMenu.voce(testo)
	b.name = nome
	b.pressed.connect(azione)
	_menu.add_child(b)
	return b
