class_name CalibrazioneLuminosita
extends Control
## Schermata di calibrazione della luminosità, tipica degli horror:
## tre simboli su fondo nero; si regola finché quello di sinistra si vede appena,
## quello centrale si intuisce e quello di destra non si vede.
## Disegna da sé con la gamma scelta (sta sopra il post-processing).

signal chiusa

## Livelli dei tre simboli (valori sRGB su fondo nero).
const LIVELLI := [0.05, 0.022, 0.008]

var _gamma := 1.0
var _area: Control
var _cursore: HSlider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_gamma = float(Grafica.valore("luminosita"))
	var nero := ColorRect.new()
	nero.color = Color.BLACK
	nero.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(nero)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 80
	col.offset_right = -80
	col.offset_top = 50
	col.offset_bottom = -50
	col.add_theme_constant_override("separation", 18)
	add_child(col)
	var titolo := Label.new()
	titolo.text = "Luminosità"
	titolo.add_theme_font_size_override("font_size", 30)
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(titolo)
	var spiega := Label.new()
	spiega.text = "Regola finché il simbolo di sinistra si vede appena e quello di destra non si vede.\nIl gioco è pensato per essere buio: non schiarirlo più del necessario."
	spiega.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spiega.add_theme_color_override("font_color", Color(0.7, 0.72, 0.74))
	col.add_child(spiega)
	_area = Control.new()
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_area.draw.connect(_disegna)
	col.add_child(_area)
	var riga := HBoxContainer.new()
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	riga.add_theme_constant_override("separation", 16)
	var meno := Label.new()
	meno.text = "Più scuro"
	riga.add_child(meno)
	_cursore = HSlider.new()
	_cursore.min_value = 0.6
	_cursore.max_value = 1.8
	_cursore.step = 0.01
	_cursore.value = _gamma
	_cursore.custom_minimum_size.x = 480
	_cursore.value_changed.connect(func(v): _gamma = v; _area.queue_redraw())
	riga.add_child(_cursore)
	var piu := Label.new()
	piu.text = "Più chiaro"
	riga.add_child(piu)
	col.add_child(riga)
	var bottoni := HBoxContainer.new()
	bottoni.alignment = BoxContainer.ALIGNMENT_CENTER
	bottoni.add_theme_constant_override("separation", 12)
	var pred := Button.new()
	pred.text = "Predefinito"
	pred.pressed.connect(func(): _cursore.value = 1.0)
	bottoni.add_child(pred)
	var ok := Button.new()
	ok.text = "Conferma"
	ok.custom_minimum_size.x = 140
	ok.pressed.connect(conferma)
	bottoni.add_child(ok)
	col.add_child(bottoni)
	ok.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_chiudi()
	elif event.is_action_pressed("ui_left"):
		_cursore.value -= 0.02
	elif event.is_action_pressed("ui_right"):
		_cursore.value += 0.02


func conferma() -> void:
	Grafica.imposta("luminosita", _gamma)
	Grafica.imposta("calibrato", true)
	_chiudi()


func imposta_gamma(g: float) -> void:
	_cursore.value = g


func _chiudi() -> void:
	chiusa.emit()
	queue_free()


func _disegna() -> void:
	var s := _area.size
	var lato := minf(s.x / 4.0, s.y * 0.8)
	for i in 3:
		var centro := Vector2(s.x * (0.2 + 0.3 * i), s.y * 0.5)
		var v := pow(LIVELLI[i], 1.0 / _gamma)
		_simbolo(centro, lato, Color(v, v, v))


## Un occhio stilizzato (richiama la mascotte), disegnato con forme semplici.
func _simbolo(c: Vector2, lato: float, col: Color) -> void:
	var r := lato * 0.42
	var punti := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		punti.append(c + Vector2(cos(a) * r, sin(a) * r * 0.55 * (1.0 if k <= 16 else 1.0)))
	_area.draw_colored_polygon(punti, col)
	_area.draw_circle(c, r * 0.36, Color.BLACK)
	_area.draw_circle(c, r * 0.22, col)
