class_name Hud
extends CanvasLayer
## Interfaccia minima del graybox: mirino, testo di interazione ("[E] Raccogli ..."),
## messaggi brevi (oggetti, collezionabili) e l'indicatore del serbatoio dello zaino.
## Lo stile dell'interfaccia e dell'indicatore è ancora da decidere: qui è tutto provvisorio.

## Il giocatore da ascoltare (di solito il genitore).
@export var player: Player
## Secondi in cui resta visibile un messaggio.
@export var message_time := 2.5

var _prompt: Label
var _message: Label
var _hint: Label
var _banner: Label
## Il livello della scritta grande: sopra il nero delle fini (80), sotto il menu di pausa (100).
const LIVELLO_SCRITTA := 90
var strato_scritta: CanvasLayer
var _tank_bar: ProgressBar
var _msg_left := 0.0
var _hint_left := 0.0
var _banner_left := 0.0


func _ready() -> void:
	_build()
	if player == null:
		player = get_parent() as Player
	if player == null:
		return
	player.interaction_target_changed.connect(_on_target_changed)
	player.item_added.connect(_on_item_added)
	if player.water_pack:
		var pack := player.water_pack
		pack.tank_changed.connect(_on_tank_changed)
		pack.tank_empty.connect(func() -> void: show_message("Serbatoio vuoto: aspira con il tasto destro"))
		pack.tank_full.connect(func() -> void: show_message("Serbatoio pieno"))
		_on_tank_changed(pack.tank_amount, pack.tank_capacity)
	GameState.collectible_collected.connect(_on_collectible)


## Suggerimento su più righe in basso a sinistra (comandi, aiuti).
func show_hint(text: String, seconds := 8.0) -> void:
	_hint.text = tr(text)
	_hint.modulate.a = 1.0
	_hint_left = seconds


## Scritta grande al centro (per esempio "Fine della demo"). I testi di show_hint, show_banner e show_message si
## traducono qui (vedi Lingua).
## La scritta grande, la sua etichetta (per i test).
func banner_label() -> Label:
	return _banner


func show_banner(title: String, subtitle := "", seconds := 6.0) -> void:
	_banner.text = tr(title) + ("\n" + tr(subtitle) if subtitle != "" else "")
	_banner.modulate.a = 1.0
	_banner_left = seconds


func show_message(text: String) -> void:
	_message.text = tr(text)
	_message.modulate.a = 1.0
	_msg_left = message_time


func _process(delta: float) -> void:
	if _msg_left > 0.0:
		_msg_left -= delta
		_message.modulate.a = clampf(_msg_left / 0.5, 0.0, 1.0)
	if _hint_left > 0.0:
		_hint_left -= delta
		_hint.modulate.a = clampf(_hint_left / 1.0, 0.0, 1.0)
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.modulate.a = clampf(_banner_left / 1.5, 0.0, 1.0)
	if player and player.water_pack:
		var pack := player.water_pack
		_tank_bar.visible = pack.equipped and pack.tank_enabled and pack.tank_indicator == WaterPack.TankIndicator.HUD_BAR


func _on_target_changed(target: Interactable) -> void:
	if target == null:
		_prompt.text = ""
		return
	_prompt.text = "[%s]  %s" % [_key_name("interact"), Lingua.t(target.get_prompt(player))]


func _on_item_added(_id: StringName, item_name: String, total: int) -> void:
	show_message(tr("Raccolto: %s") % (tr(item_name) + ("" if total <= 1 else " (%d)" % total)))


func _on_collectible(collection: StringName, _entry: StringName, count: int, total: int) -> void:
	show_message("%s %d/%d" % [tr(String(collection).capitalize()), count, total])


func _on_tank_changed(amount: float, capacity: float) -> void:
	_tank_bar.max_value = capacity
	_tank_bar.value = amount


static func _key_name(action: StringName) -> String:
	for e in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k:
			return OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	return String(action)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.75)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-2, -2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)
	_prompt = _label(root, 0.56, 20)
	_message = _label(root, 0.82, 22)
	_message.modulate.a = 0.0
	# la scritta grande (la fine della demo) su un livello suo, sopra il nero delle fini (l'inseguimento lo mette al
	# livello 80) e sotto il menu di pausa (100): prima stava qui, al livello 1, e alla fine dell'inseguimento restava
	# sotto il nero (collaudo della v0.3.13). Il resto dell'interfaccia resta sotto.
	strato_scritta = CanvasLayer.new()
	strato_scritta.name = "StratoScritta"
	strato_scritta.layer = LIVELLO_SCRITTA
	add_child(strato_scritta)
	var sopra := Control.new()
	sopra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sopra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strato_scritta.add_child(sopra)
	_banner = _label(sopra, 0.3, 40)
	_banner.offset_top = -60
	_banner.offset_bottom = 60
	_banner.modulate.a = 0.0
	_hint = Label.new()
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 24
	_hint.offset_right = 900
	_hint.offset_top = -80
	_hint.offset_bottom = -24
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)
	_tank_bar = ProgressBar.new()
	_tank_bar.show_percentage = false
	_tank_bar.custom_minimum_size = Vector2(180, 10)
	_tank_bar.anchor_left = 1.0
	_tank_bar.anchor_right = 1.0
	_tank_bar.anchor_top = 1.0
	_tank_bar.anchor_bottom = 1.0
	_tank_bar.offset_left = -204
	_tank_bar.offset_right = -24
	_tank_bar.offset_top = -36
	_tank_bar.offset_bottom = -24
	_tank_bar.value = 100
	_tank_bar.visible = false
	# Indicatore provvisorio del serbatoio: l'aspetto vero è una scelta di design.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.07, 0.09, 0.65)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.75, 0.95, 0.9)
	fill.set_corner_radius_all(3)
	_tank_bar.add_theme_stylebox_override("background", bg)
	_tank_bar.add_theme_stylebox_override("fill", fill)
	root.add_child(_tank_bar)


func _label(root: Control, y_anchor: float, font_size: int) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y_anchor
	l.anchor_bottom = y_anchor
	l.offset_top = -20
	l.offset_bottom = 20
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l
