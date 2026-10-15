extends CanvasLayer
## Guarda da vicino una Polaroid appena raccolta: la foto riempie lo schermo, un po' storta,
## il gioco resta in pausa finché non premi E, Spazio, Esc o un tasto del mouse.

var texture: Texture2D

var _t := 0.0
var _card: TextureRect
var _closing := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_card = TextureRect.new()
	_card.texture = texture
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.08
	_card.anchor_bottom = 0.88
	add_child(_card)
	var hint := Label.new()
	hint.text = "E · Spazio · clic per continuare"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -48
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.8))
	add_child(hint)
	get_tree().paused = true
	_layout()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var h := size.y * 0.8
	var w := h * (1024.0 / 1245.0)
	_card.offset_left = -w * 0.5
	_card.offset_right = w * 0.5
	_card.pivot_offset = Vector2(w * 0.5, h * 0.5)


func _process(delta: float) -> void:
	_t += delta
	# Entra ruotando un poco, come una foto presa in mano.
	var k := clampf(_t / 0.35, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 3.0)
	_card.rotation = lerpf(-0.18, -0.035, k)
	_card.scale = Vector2.ONE * lerpf(0.86, 1.0, k)
	_card.modulate.a = k


func _input(event: InputEvent) -> void:
	if _t < 0.3 or _closing:
		return
	var close: bool = event.is_action_pressed("interact") or event.is_action_pressed("skip") \
		or event.is_action_pressed("pause") or (event is InputEventMouseButton and event.pressed)
	if close:
		_closing = true
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		queue_free()
