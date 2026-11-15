class_name RiepilogoCapitolo
extends CanvasLayer
## Il riepilogo dopo «FINE DEL CAPITOLO 1» (build 0.5.0, «La storia»): le Polaroid trovate su 16, il tempo di gioco e
## le morti (GameState.tempo_gioco e morti_totali). Niente crediti. Si torna al titolo con un tasto dopo almeno
## [constant TASTO_DOPO] secondi, o da soli dopo [constant DA_SOLO] secondi. Lo stile è quello della scritta di fine
## capitolo (Hud: testo bianco col contorno nero, al centro); lo ritocca la build 3.

signal finito

## Dopo quanti secondi un tasto riporta al titolo.
const TASTO_DOPO := 4.0
## Dopo quanti secondi si torna al titolo da soli.
const DA_SOLO := 25.0
## Sopra la scritta della fine (Hud.LIVELLO_SCRITTA, 90), sotto il menu di pausa (100).
const LIVELLO := 95

var polaroid := 0
var tempo := 0.0
var morti := 0
var _t := 0.0
var _fatto := false
var _invito: Label
var righe: Array[Label] = []


## Crea il riepilogo coi contatori di adesso e lo mette in [param genitore].
static func mostra(genitore: Node) -> RiepilogoCapitolo:
	var r := RiepilogoCapitolo.new()
	r.name = "RiepilogoCapitolo"
	r.polaroid = PolaroidPhoto.quante_trovate()
	r.tempo = GameState.tempo_gioco
	r.morti = GameState.morti_totali
	genitore.add_child(r)
	return r


func _ready() -> void:
	layer = LIVELLO
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 1)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	var testi := [
		tr("Polaroid trovate: %d su %d") % [polaroid, PolaroidPhoto.NOMI_RACCOLTA.size()],
		tr("Tempo: %s") % GameState.tempo_leggibile(tempo),
		tr("Morti: %d") % morti,
	]
	for i in testi.size():
		righe.append(_label(fondo, 0.4 + 0.08 * i, 34, testi[i]))
	_invito = _label(fondo, 0.8, 18, tr("Premi un tasto per tornare al titolo"))
	_invito.modulate.a = 0.0


func _label(root: Control, y: float, size: int, testo: String) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y
	l.anchor_bottom = y
	l.offset_top = -24
	l.offset_bottom = 24
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = testo
	root.add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	if _t >= TASTO_DOPO:
		_invito.modulate.a = minf(1.0, (_t - TASTO_DOPO) / 1.0)
	if _t >= DA_SOLO:
		_al_titolo()


func _unhandled_input(event: InputEvent) -> void:
	if _t < TASTO_DOPO or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		_al_titolo()


## Quanto manca perché un tasto riporti al titolo (per i test).
func pronto_al_tasto() -> bool:
	return _t >= TASTO_DOPO


func _al_titolo() -> void:
	if _fatto:
		return
	_fatto = true
	finito.emit()
	Game.return_to_title()
