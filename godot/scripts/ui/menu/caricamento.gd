extends Control
## Schermata di caricamento: carica la sala principale in un thread (ResourceLoader a thread),
## con la barra di avanzamento, i comandi e un consiglio. Quando la sala è pronta lo schermo
## si scurisce, la sala entra in scena e appare con una dissolvenza dal nero.

const SCENA_SALA := "res://scenes/sala_principale.tscn"
const SCENA_TITOLO := "res://scenes/ui/menu_principale.tscn"

## La scena da caricare.
@export_file("*.tscn") var scena := SCENA_SALA
## Secondi minimi a schermo, per fare in tempo a leggere il consiglio.
@export var tempo_minimo := 2.5
## Frame da aspettare a schermo nero dopo l'ingresso della sala (shader, ombre, GI).
@export var frame_di_assestamento := 8

## Consigli: tra graffe le azioni della InputMap, sostituite con i tasti veri.
const CONSIGLI := [
	"Lo zaino-pompa aspira l'acqua con il {suck} e la spruzza con il {spray}.",
	"Il getto d'acqua fa girare le turbine e preme i pulsanti anche da lontano.",
	"Serbatoio vuoto? Cerca una pozza o una vasca e aspira l'acqua.",
	"Cerca lo zaino-pompa alla postazione dei bagnini.",
	"Le Polaroid sparse per l'acquapark raccontano un pezzo di quello che è successo a bordo.",
	"Con {torcia} accendi e spegni la torcia.",
	"Non serve salvare: il gioco lo fa da solo, spesso, mentre avanzi.",
	"La scena della morte si salta tenendo premuto {skip}.",
	"Con {pause} metti in pausa: da lì cambi la grafica e rivedi i comandi.",
	"Se il buio è troppo fitto o troppo chiaro, ricalibra la luminosità dalle opzioni.",
]

enum Fase { CARICAMENTO, INGRESSO, ERRORE }

var fase := Fase.CARICAMENTO
## Avanzamento mostrato (0..1): segue quello vero, ma senza scatti.
var avanzamento := 0.0

var _vero := 0.0
var _pacchetto: PackedScene
var _trascorso := 0.0
var _barra: ProgressBar
var _percento: Label
var _stato: Label
var _consiglio: Label
var _torna: Button
var _pausa_fuoco := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pausa_fuoco = Game.pause_on_focus_loss
	Game.pause_on_focus_loss = false
	# Schermata 2D: senza grana e aberrazione il testo si legge meglio.
	Grafica.post_processing_visibile(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_costruisci()
	var err := Game.carica_in_thread(scena, "PackedScene")
	if err != OK:
		_riserva()
	if Dissolvenza.presente(get_tree()):
		Dissolvenza.di(get_tree()).schiarisci(0.6)


func _exit_tree() -> void:
	Game.pause_on_focus_loss = _pausa_fuoco
	Grafica.post_processing_visibile(true)


func _unhandled_input(event: InputEvent) -> void:
	# Durante il caricamento Esc non apre la pausa; dopo un errore riporta al titolo.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if fase == Fase.ERRORE:
			_torna_al_titolo()


func _process(delta: float) -> void:
	_trascorso += delta
	if fase != Fase.CARICAMENTO or Game.uscendo:
		return
	var p := []
	var st := ResourceLoader.load_threaded_get_status(scena, p)
	if not p.is_empty():
		_vero = maxf(_vero, float(p[0]))
	match st:
		ResourceLoader.THREAD_LOAD_LOADED:
			_vero = 1.0
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			if _pacchetto == null:
				_riserva()
			if _pacchetto == null:
				return
			st = ResourceLoader.THREAD_LOAD_LOADED
	# Al massimo il 60% al secondo: la barra scorre senza salti.
	avanzamento = move_toward(avanzamento, _vero, delta * 0.6)
	_barra.value = avanzamento
	_percento.text = "%d%%" % roundi(avanzamento * 100.0)
	if st == ResourceLoader.THREAD_LOAD_LOADED and avanzamento >= 1.0 and _trascorso >= tempo_minimo:
		_entra()


## Riserva: se il caricamento nel thread non parte o fallisce, la sala si carica qui, di seguito
## (la barra si ferma un attimo). Solo se non riesce neanche così si mostra l'errore.
func _riserva() -> void:
	push_warning("Caricamento: il thread non ce la fa (%s), carico la sala subito" % scena)
	_pacchetto = load(scena) as PackedScene
	if _pacchetto == null:
		_errore("Il caricamento della sala non è riuscito.")
	else:
		_vero = 1.0


func _entra() -> void:
	fase = Fase.INGRESSO
	_stato.text = "Pronto"
	var pacchetto := _pacchetto if _pacchetto else ResourceLoader.load_threaded_get(scena) as PackedScene
	if pacchetto == null:
		_errore("Il caricamento della sala non è riuscito.")
		return
	var velo := Dissolvenza.di(get_tree())
	# Mentre la sala si prepara lo schermo resta nero, con una scritta per le attese lunghe.
	await velo.scurisci(0.7, "Preparazione della sala…")
	Game.pause_on_focus_loss = _pausa_fuoco
	Game.capture_mouse()
	get_tree().change_scene_to_packed(pacchetto)
	velo.schiarisci(1.6, frame_di_assestamento)


func _errore(testo: String) -> void:
	fase = Fase.ERRORE
	_stato.text = testo
	_stato.add_theme_color_override("font_color", StileMenu.ROSSO.lightened(0.25))
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_torna.visible = true
	_torna.grab_focus()


func _torna_al_titolo() -> void:
	get_tree().change_scene_to_file(SCENA_TITOLO)


# --- Interfaccia --------------------------------------------------------------------------

func _costruisci() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = StileMenu.tema()
	var fondo := ColorRect.new()
	fondo.color = StileMenu.FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	# Un riflesso d'acqua appena accennato in basso.
	var riflesso := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.offsets = PackedFloat32Array([0.0, 1.0])
	g.gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(StileMenu.CIANO.darkened(0.55), 0.22)])
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	g.width = 4
	g.height = 128
	riflesso.texture = g
	riflesso.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	riflesso.stretch_mode = TextureRect.STRETCH_SCALE
	riflesso.anchor_top = 0.55
	riflesso.anchor_right = 1.0
	riflesso.anchor_bottom = 1.0
	add_child(riflesso)

	var margini := MarginContainer.new()
	margini.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margini.add_theme_constant_override("margin_left", 84)
	margini.add_theme_constant_override("margin_right", 84)
	margini.add_theme_constant_override("margin_top", 62)
	margini.add_theme_constant_override("margin_bottom", 54)
	add_child(margini)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margini.add_child(col)

	var testata := HBoxContainer.new()
	testata.add_theme_constant_override("separation", 14)
	# Il nome del gioco è provvisorio (GDD): nella testata solo il capitolo.
	testata.add_child(StileMenu.etichetta("CAPITOLO 1", StileMenu.oswald(600, 6), 26, StileMenu.TESTO_SPENTO))
	col.add_child(testata)
	var spazio := Control.new()
	spazio.custom_minimum_size.y = 48
	col.add_child(spazio)

	var centro := HBoxContainer.new()
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.add_theme_constant_override("separation", 80)
	col.add_child(centro)
	var sx := VBoxContainer.new()
	sx.add_theme_constant_override("separation", 14)
	sx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.add_child(sx)
	sx.add_child(_intestazione("COMANDI"))
	sx.add_child(SchermataComandi.crea_elenco(18, 8))
	var dx := VBoxContainer.new()
	dx.add_theme_constant_override("separation", 14)
	dx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dx.size_flags_stretch_ratio = 0.85
	centro.add_child(dx)
	dx.add_child(_intestazione("CONSIGLIO"))
	_consiglio = StileMenu.etichetta(consiglio(CONSIGLI.pick_random()), StileMenu.barlow(), 23, StileMenu.TESTO)
	_consiglio.name = "Consiglio"
	_consiglio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_consiglio.custom_minimum_size.x = 380
	dx.add_child(_consiglio)
	_torna = StileMenu.voce("Torna al titolo", 24)
	_torna.name = "TornaAlTitolo"
	_torna.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_torna.visible = false
	_torna.pressed.connect(_torna_al_titolo)
	dx.add_child(_torna)

	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 12)
	# Una lucina rossa che pulsa piano, come le luci d'emergenza: il gioco sta lavorando.
	var spia := Panel.new()
	var tondo := StyleBoxFlat.new()
	tondo.bg_color = StileMenu.ROSSO
	tondo.set_corner_radius_all(5)
	tondo.shadow_color = Color(StileMenu.ROSSO, 0.5)
	tondo.shadow_size = 6
	spia.add_theme_stylebox_override("panel", tondo)
	spia.custom_minimum_size = Vector2(10, 10)
	spia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	riga.add_child(spia)
	var pulsa := create_tween().set_loops()
	pulsa.tween_property(spia, ^"modulate:a", 0.2, 0.7).set_trans(Tween.TRANS_SINE)
	pulsa.tween_property(spia, ^"modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	_stato = StileMenu.etichetta("Caricamento della sala…", StileMenu.barlow(), 18, StileMenu.TESTO_SPENTO)
	_stato.name = "Stato"
	_stato.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.add_child(_stato)
	_percento = StileMenu.etichetta("0%", StileMenu.oswald(500, 2), 20, StileMenu.CIANO)
	_percento.name = "Percento"
	riga.add_child(_percento)
	col.add_child(riga)
	var spazio2 := Control.new()
	spazio2.custom_minimum_size.y = 8
	col.add_child(spazio2)
	_barra = ProgressBar.new()
	_barra.name = "Barra"
	_barra.min_value = 0.0
	_barra.max_value = 1.0
	_barra.step = 0.0
	_barra.show_percentage = false
	_barra.custom_minimum_size.y = 4
	col.add_child(_barra)


## Il testo di un consiglio con i tasti veri al posto delle azioni tra graffe.
static func consiglio(testo: String) -> String:
	var i := testo.find("{")
	while i >= 0:
		var j := testo.find("}", i)
		var azione := testo.substr(i + 1, j - i - 1)
		var nomi := SchermataComandi.nomi_tasti([StringName(azione)])
		for k in nomi.size():
			# Dentro una frase "Tasto destro" diventa "tasto destro"; Spazio, E, Invio restano.
			if nomi[k].begins_with("Tasto ") or nomi[k].begins_with("Rotellina"):
				nomi[k] = nomi[k].to_lower()
		var tasti := " o ".join(nomi) if nomi.size() <= 2 else ", ".join(nomi.slice(0, -1)) + " o " + nomi[-1]
		testo = testo.substr(0, i) + tasti + testo.substr(j + 1)
		i = testo.find("{")
	return testo


func _intestazione(testo: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(StileMenu.etichetta(testo, StileMenu.oswald(500, 5), 21, StileMenu.TESTO))
	var linea := ColorRect.new()
	linea.color = StileMenu.ROSSO
	linea.custom_minimum_size = Vector2(48, 2)
	linea.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(linea)
	return v
