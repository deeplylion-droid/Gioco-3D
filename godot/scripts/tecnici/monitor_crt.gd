class_name MonitorCrt
extends Node
## Il vecchio monitor a tubo della sala pompe (tappa 6): prima del risveglio mostra la sala
## grande ripresa da una telecamera di sorveglianza anni '90 (la medusa è ancora lì), a bassa
## risoluzione, con le righe del tubo e la sovrimpressione di telecamera, data e ora che corre;
## dal blackout solo neve. Va a batteria: la sua luce resta anche al buio. Segue GameState.luci.
## L'immagine e la sovrimpressione si compongono in un piccolo SubViewport 2D (320 x 240), che
## lo shader del tubo (shaders/tecnici/crt.gdshader) mostra sullo schermo del modello.

## La mesh dello schermo (SCHERMO_CRT del modello).
@export var schermo_path: NodePath
## Dove mettere la sua luce (empty LUCE_crt del modello).
@export var luce_path: NodePath
## L'immagine della telecamera (uno scatto vero della sala, in 4:3).
@export var immagine: Texture2D
## Sovrimpressione: nome della telecamera, data e ora d'inizio (l'ora poi corre).
@export var telecamera := "CAM 3"
@export var data := "12-08-1997"
@export var ora_inizio := Vector3i(2, 47, 13)
@export var colore_luce := Color(0.62, 0.86, 0.95)
@export var energia_luce := 0.7

const LATO := Vector2i(320, 240)

var _materiale: ShaderMaterial
var _luce: OmniLight3D
var _vista: SubViewport
var _ora: Label
var _rec: Label
var _t := 0.0
var _secondi := 0.0
var _ultimo_secondo := -1


func _ready() -> void:
	_componi()
	var schermo := get_node_or_null(schermo_path) as MeshInstance3D
	if schermo:
		_materiale = ShaderMaterial.new()
		_materiale.shader = preload("res://shaders/tecnici/crt.gdshader")
		_materiale.set_shader_parameter(&"immagine", _vista.get_texture())
		schermo.material_override = _materiale
	var punto := get_node_or_null(luce_path) as Node3D
	if punto:
		_luce = OmniLight3D.new()
		_luce.name = "LuceMonitor"
		_luce.light_color = colore_luce
		_luce.light_energy = energia_luce
		_luce.omni_range = 2.6
		_luce.omni_attenuation = 1.4
		_luce.shadow_enabled = false
		_luce.light_volumetric_fog_energy = 0.3
		# Va a batteria: il blackout non la spegne.
		_luce.set_meta(&"risveglio_ignora", true)
		add_child(_luce)
		_luce.global_position = punto.global_position
	_secondi = ora_inizio.x * 3600.0 + ora_inizio.y * 60.0 + ora_inizio.z
	GameState.luci_cambiate.connect(_applica)
	_applica(GameState.luci)


## L'immagine della telecamera con la sovrimpressione, in un SubViewport 2D piccolo.
func _componi() -> void:
	_vista = SubViewport.new()
	_vista.name = "Telecamera"
	_vista.size = LATO
	_vista.disable_3d = true
	_vista.transparent_bg = false
	_vista.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vista)
	var fondo := ColorRect.new()
	fondo.color = Color(0.05, 0.06, 0.06)
	fondo.size = Vector2(LATO)
	_vista.add_child(fondo)
	if immagine:
		var img := TextureRect.new()
		img.texture = immagine
		img.size = Vector2(LATO)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_vista.add_child(img)
	var cam := _scritta(telecamera, Vector2(10, 6))
	cam.name = "Nome"
	_rec = _scritta("● REC", Vector2(LATO.x - 70, 6))
	_ora = _scritta("", Vector2(10, LATO.y - 26))


func _scritta(testo: String, dove: Vector2) -> Label:
	var l := Label.new()
	l.text = testo
	l.position = dove
	l.add_theme_font_size_override(&"font_size", 15)
	l.add_theme_color_override(&"font_color", Color(0.92, 0.95, 0.9))
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override(&"outline_size", 4)
	_vista.add_child(l)
	return l


## Solo neve (dal blackout in poi).
func mostra_neve() -> void:
	if _materiale:
		_materiale.set_shader_parameter(&"neve", 1.0)


func mostra_neve_attiva() -> bool:
	return _materiale != null and float(_materiale.get_shader_parameter(&"neve")) > 0.5


## Il testo della data e dell'ora come compare adesso sul monitor.
func sovrimpressione() -> String:
	return _ora.text if _ora else ""


func _applica(fase: GameState.Luci) -> void:
	if _materiale == null:
		return
	_materiale.set_shader_parameter(&"neve", 1.0 if fase == GameState.Luci.BLACKOUT else 0.0)
	_materiale.set_shader_parameter(&"luminosita", 2.4 if fase == GameState.Luci.FLASH else 1.3)


func _process(delta: float) -> void:
	_t += delta
	_secondi += delta
	var s := int(_secondi) % 86400
	if s != _ultimo_secondo and _ora:
		# L'ora corre: si ridisegna la sovrimpressione una volta al secondo.
		_ultimo_secondo = s
		_ora.text = "%s  %02d:%02d:%02d" % [data, s / 3600, (s / 60) % 60, s % 60]
		_rec.visible = s % 2 == 0
		_vista.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _luce == null:
		return
	# Il tubo tremola: con la neve di più.
	var k := 0.85 + 0.1 * sin(_t * 31.0) + 0.05 * sin(_t * 77.0)
	if mostra_neve_attiva():
		k = 0.7 + 0.3 * randf()
	_luce.light_energy = energia_luce * k
