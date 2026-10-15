class_name FpsCounter
extends CanvasLayer
## Contatore delle prestazioni in un angolo, acceso e spento con F3 (spento all'avvio):
## FPS, tempo del fotogramma (medio e peggiore dell'ultimo mezzo secondo) e preset grafico.

const AGGIORNA_OGNI := 0.5

var _label: Label
var _t := 0.0
var _frames := 0
var _worst := 0.0


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -360
	_label.offset_right = -14
	_label.offset_top = 10
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	if _t < AGGIORNA_OGNI:
		return
	var avg_ms := _t / float(_frames) * 1000.0
	var preset: String = str(Grafica.valore("preset")) if is_instance_valid(Grafica) else "?"
	var gi: String = ["nessuna", "VoxelGI", "SDFGI"][clampi(int(Grafica.valore("gi")), 0, 2)] if is_instance_valid(Grafica) else "?"
	_label.text = "%d FPS · %.1f ms (peggiore %.1f ms)\npreset %s · GI %s · %dx%d" % [
		Engine.get_frames_per_second(), avg_ms, _worst * 1000.0, preset, gi,
		get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
	_t = 0.0
	_frames = 0
	_worst = 0.0
