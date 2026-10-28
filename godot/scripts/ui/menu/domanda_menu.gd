extends CanvasLayer
## Una domanda con Sì e No sopra il titolo (livello 100, come Comandi e Opzioni), nello stile del menu. Per ora una sola:
## "Ricominciare da capo?" prima di una Nuova partita quando c'è un salvataggio (scelta A dell'utente del 25 ottobre).
## Il focus parte su No, per non perdere il salvataggio per sbaglio. Il clic, Invio, Spazio o A del joypad scelgono la
## voce col focus; B del joypad, Esc o la pausa valgono No. Si risponde una volta sola, poi si chiude da sola.

signal risposta(si: bool)

var domanda := ""
var nota := ""
var voce_si: Button
var voce_no: Button
var _risposto := false


func _init(testo_domanda := "", testo_nota := "") -> void:
	domanda = testo_domanda
	nota = testo_nota


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var radice := Control.new()
	radice.name = "Domanda"
	radice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# i clic a vuoto si fermano qui: non arrivano al titolo sotto
	radice.mouse_filter = Control.MOUSE_FILTER_STOP
	radice.theme = StileMenu.tema()
	add_child(radice)
	var fondo := ColorRect.new()
	fondo.color = Color(StileMenu.FONDO, 0.86)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radice.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radice.add_child(centro)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 520
	col.add_theme_constant_override("separation", 10)
	centro.add_child(col)
	var titolo := StileMenu.etichetta(domanda.to_upper(), StileMenu.oswald(600, 4), 40)
	titolo.name = "Titolo"
	col.add_child(titolo)
	var linea := ColorRect.new()
	linea.color = StileMenu.ROSSO
	linea.custom_minimum_size = Vector2(64, 3)
	linea.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(linea)
	var testo := StileMenu.etichetta(nota, StileMenu.barlow(), 22, StileMenu.TESTO_VOCE)
	testo.name = "Nota"
	col.add_child(testo)
	var spazio := Control.new()
	spazio.custom_minimum_size.y = 14
	col.add_child(spazio)
	voce_si = _voce("Si", "Sì", true)
	col.add_child(voce_si)
	voce_no = _voce("No", "No", false)
	col.add_child(voce_no)
	StileMenu.collega_voci([voce_si, voce_no])
	voce_no.grab_focus.call_deferred()


func _voce(nome: String, testo: String, si: bool) -> Button:
	var b := StileMenu.voce(testo, 26)
	b.name = nome
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 220
	b.pressed.connect(rispondi.bind(si))
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		rispondi(false)


## La risposta (una volta sola: un doppio clic o Invio ripetuto non contano due volte).
func rispondi(si: bool) -> void:
	if _risposto:
		return
	_risposto = true
	voce_si.disabled = true
	voce_no.disabled = true
	risposta.emit(si)
	queue_free()
