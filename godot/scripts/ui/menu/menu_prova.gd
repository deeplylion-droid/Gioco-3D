class_name MenuProva
extends CanvasLayer
## Il menu di prova nascosto del titolo (scelta B dell'utente, 24 ottobre: "non posso provare e riprovare le stesse
## cose"): si apre con [constant TASTO] (F9) nella schermata del titolo, non è fra le voci né nei comandi, e fa partire
## la partita da una delle parti del capitolo come se il giocatore avesse fatto tutto quello che viene prima.
##
## Ogni partenza è un'istantanea vera di GameState (quella di un checkpoint: stato degli oggetti "persist", oggetti
## raccolti, inventario, acqua, luci, Polaroid), scritta da tests/genera_partenze_prova.gd in
## [constant CARTELLA] (<id>.json). Partire da lì è come ripartire dopo una morte (GameState.prepara_ripresa, poi la
## schermata di caricamento): torre, condotte e tunnel si caricano col loro sistema di sempre, e da lì in poi morte e
## ripartenze sono quelle del gioco.

const TASTO := KEY_F9
const CARTELLA := "res://assets/prova/"
const SCENA_CARICAMENTO := "res://scenes/ui/caricamento.tscn"
## Le partenze, in ordine: id (il file), nome nel menu, il checkpoint (la chiave persist), cosa viene prima. "inizio" è
## la nuova partita normale (niente file).
const PARTENZE := [
	{"id": "inizio", "nome": "Inizio", "nota": "nuova partita"},
	{"id": "risalita", "nome": "Risalita", "nota": "dopo la sala generatori"},
	{"id": "fiume", "nome": "Fiume lento", "nota": "all'ingresso del fiume"},
	{"id": "torre", "nome": "Torre degli scivoli", "nota": "oltre il portone"},
	{"id": "inseguimento", "nome": "Inseguimento", "nota": "le condotte, dal fondo della torre"},
	{"id": "tunnel", "nome": "Tunnel sottomarino", "nota": "dopo SB1, all'ingresso del tunnel"},
]

## Si sceglie una partenza (l'id). Il titolo fa partire "inizio" con la sua nuova partita.
signal scelta(id: String)
signal chiuso

var _voci: Array[Button] = []


## Le partenze che ci sono davvero: "inizio" sempre, le altre se c'è il loro file.
static func disponibili() -> Array:
	return PARTENZE.filter(func(p): return p["id"] == "inizio" or FileAccess.file_exists(CARTELLA + p["id"] + ".json"))


## L'istantanea della partenza [param id] (vuota se non c'è o non è leggibile).
static func istantanea(id: String) -> Dictionary:
	var percorso: String = CARTELLA + id + ".json"
	if not FileAccess.file_exists(percorso):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(percorso))
	return d if d is Dictionary else {}


## Parte dalla partenza [param id] (non "inizio"): l'istantanea in GameState, poi la schermata di caricamento.
static func parti(albero: SceneTree, id: String) -> bool:
	var d := istantanea(id)
	if d.is_empty():
		return false
	GameState.prepara_ripresa(d)
	albero.change_scene_to_file(SCENA_CARICAMENTO)
	return true


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.72)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override(&"separation", 10)
	add_child(box)
	var titolo := Label.new()
	titolo.text = "Partenza di prova"
	titolo.add_theme_font_size_override(&"font_size", 30)
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(titolo)
	for p in disponibili():
		var b := Button.new()
		b.text = "%s  ·  %s" % [p["nome"], p["nota"]]
		b.add_theme_font_size_override(&"font_size", 22)
		b.pressed.connect(func(): scelta.emit(String(p["id"])))
		box.add_child(b)
		_voci.append(b)
	var esci := Button.new()
	esci.text = "Indietro"
	esci.add_theme_font_size_override(&"font_size", 20)
	esci.pressed.connect(chiudi)
	box.add_child(esci)
	_voci.append(esci)
	# centrato davvero (il preset centra l'angolo in alto a sinistra)
	box.position -= box.get_combined_minimum_size() * 0.5
	_voci[0].grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause") \
			or (event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == TASTO):
		get_viewport().set_input_as_handled()
		chiudi()


func chiudi() -> void:
	chiuso.emit()
	queue_free()
