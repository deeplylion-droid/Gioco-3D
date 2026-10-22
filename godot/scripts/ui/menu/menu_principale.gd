extends Node3D
## Schermata del titolo, il "manifesto" del gioco: solo la statua della medusa sul monumento,
## nella nebbia, con i fari della galleria e i lampi lontani; la camera sale piano dal piedistallo
## fino al viso. Il nome del gioco è provvisorio (GDD), quindi non è scritto: sopra il menu c'è
## solo, in piccolo, "Capitolo 1 · demo <versione>". Voci: Nuova partita (porta alla schermata di caricamento della sala), Opzioni
## (menu dell'addon grafica), Comandi, Esci. Mouse, tastiera e joypad (azioni ui_*).
## La calibrazione della luminosità del primo avvio la mostra Game, sopra il titolo.

const SCENA_CARICAMENTO := "res://scenes/ui/caricamento.tscn"
const SCENA_COMANDI := "res://scenes/ui/comandi.tscn"
const SCENA_OPZIONI := "res://addons/grafica/menu_opzioni.tscn"
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
var _testata: Control
var _logo: TextureRect
var _sottomenu: CanvasLayer
var _pausa_fuoco := true


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
	# Nel titolo Esc non apre la pausa di Game.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


# --- Voci del menu ------------------------------------------------------------------------

func nuova_partita() -> void:
	if _avviato or is_instance_valid(_sottomenu):
		return
	_avviato = true
	for v in _voci:
		v.disabled = true
	GameState.reset_progress()
	_audio(&"ferma_musica", [0.9])
	await Dissolvenza.di(get_tree()).scurisci(0.9)
	get_tree().change_scene_to_file(SCENA_CARICAMENTO)


func apri_opzioni() -> void:
	_apri(SCENA_OPZIONI, ^"Menu", _voci[1])


func apri_comandi() -> void:
	_apri(SCENA_COMANDI, ^"Comandi", _voci[2])


func esci() -> void:
	Game.esci()


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
	var versione := StileMenu.etichetta(
		"Capitolo 1 · demo %s" % ProjectSettings.get_setting("application/config/version", ""),
		StileMenu.barlow(), 18, StileMenu.TESTO_SPENTO)
	versione.name = "Versione"
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
	_voci.append(_voce("NuovaPartita", "Nuova partita", nuova_partita))
	_voci.append(_voce("Opzioni", "Opzioni", apri_opzioni))
	_voci.append(_voce("Comandi", "Comandi", apri_comandi))
	_voci.append(_voce("Esci", "Esci", esci))
	StileMenu.collega_voci(_voci)


func _voce(nome: String, testo: String, azione: Callable) -> Button:
	var b := StileMenu.voce(testo)
	b.name = nome
	b.pressed.connect(azione)
	_menu.add_child(b)
	return b
