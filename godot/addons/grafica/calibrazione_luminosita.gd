class_name CalibrazioneLuminosita
extends Control
## Schermata di calibrazione della luminosità, tipica degli horror:
## tre simboli su fondo nero; si regola finché quello di sinistra si vede appena,
## quello centrale si intuisce e quello di destra non si vede.
## Disegna da sé con la gamma scelta (sta sopra il post-processing).
## Sotto i simboli c'è una seconda prova (scelta A dell'utente, 4 novembre): uno scatto vero del corridoio delle pile del
## fiume, con le lampade al 20%, preso col preset di serie e la luminosità a 1,0, schiarito o scurito col cursore
## come i simboli; si regola finché la scatola in fondo si vede appena. La luce del gioco non cambia.

signal chiusa

## Livelli dei tre simboli (valori sRGB su fondo nero).
const LIVELLI := [0.05, 0.022, 0.008]
## Lo scatto della seconda prova (1280x720, senza perdita: i livelli bui devono restare esatti).
const PROVA := "res://addons/grafica/prova_luminosita.png"
## La stessa gamma del post-processing (post_processing.gdshader), sui valori sRGB dello scatto.
const SHADER_PROVA := """shader_type canvas_item;
uniform float gamma = 1.0;
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(pow(max(t.rgb, vec3(0.0)), vec3(1.0 / gamma)), t.a);
}
"""

var _gamma := 1.0
var _area: Control
var _cursore: HSlider
var _prova: TextureRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gamma = float(Grafica.valore("luminosita"))
	var nero := ColorRect.new()
	nero.color = Color.BLACK
	nero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(nero)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 80
	col.offset_right = -80
	col.offset_top = 50
	col.offset_bottom = -50
	col.add_theme_constant_override("separation", 12)
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
	_area.size_flags_stretch_ratio = 0.7
	_area.draw.connect(_disegna)
	col.add_child(_area)
	if ResourceLoader.exists(PROVA):
		_prova = TextureRect.new()
		_prova.name = "Prova"
		_prova.texture = load(PROVA)
		_prova.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_prova.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_prova.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_prova.size_flags_stretch_ratio = 2.0
		var sh := Shader.new()
		sh.code = SHADER_PROVA
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter(&"gamma", _gamma)
		_prova.material = m
		col.add_child(_prova)
		var dice := Label.new()
		dice.name = "DiceProva"
		dice.text = "Regola finché vedi appena la scatola in fondo."
		dice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dice.add_theme_color_override("font_color", Color(0.7, 0.72, 0.74))
		col.add_child(dice)
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
	_cursore.value_changed.connect(_cambia)
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
	ok.focus_neighbor_top = ok.get_path_to(pred)
	ok.focus_neighbor_bottom = ok.get_path_to(pred)
	pred.focus_neighbor_top = pred.get_path_to(ok)
	pred.focus_neighbor_bottom = pred.get_path_to(ok)
	_cursore.focus_mode = Control.FOCUS_NONE
	ok.grab_focus.call_deferred()


func _cambia(v: float) -> void:
	_gamma = v
	_area.queue_redraw()
	if _prova:
		(_prova.material as ShaderMaterial).set_shader_parameter(&"gamma", _gamma)


## Sinistra e destra (frecce, croce e levetta del joypad) muovono sempre il cursore, prima dei pulsanti: se no la
## navigazione del focus se le prende e il cursore col joypad non si muove (o si muove solo a volte). Tenute premute, il
## cursore continua a scorrere. Su e giù passano da Conferma a Predefinito.
const PASSO := 0.02
const RITARDO_RIPETI := 0.35
const OGNI_RIPETI := 0.05
var _tenuto := 0.0
var _verso := 0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_chiudi()
		return
	for a: StringName in [&"ui_left", &"ui_right"]:
		if event.is_action(a):
			get_viewport().set_input_as_handled()
			if event.is_action_pressed(a, false):
				var v := -1 if a == &"ui_left" else 1
				_cursore.value += PASSO * v
				_verso = v
				_tenuto = -RITARDO_RIPETI
			elif event.is_action_released(a):
				_verso = 0
			return


func _process(delta: float) -> void:
	if _verso == 0:
		return
	if not Input.is_action_pressed(&"ui_left" if _verso < 0 else &"ui_right"):
		_verso = 0
		return
	_tenuto += delta
	while _tenuto >= OGNI_RIPETI:
		_tenuto -= OGNI_RIPETI
		_cursore.value += PASSO * _verso


func conferma() -> void:
	Grafica.imposta("luminosita", _gamma)
	Grafica.imposta("calibrato", true)
	_chiudi()


func imposta_gamma(g: float) -> void:
	_cursore.value = g


func _chiudi() -> void:
	chiusa.emit()
	# Se è la scena .tscn (CanvasLayer + Control), si chiude tutta.
	if owner is CanvasLayer:
		owner.queue_free()
	else:
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
