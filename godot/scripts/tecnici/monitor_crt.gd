class_name MonitorCrt
extends Node
## Il vecchio monitor a tubo della sala pompe (tappa 6): prima del risveglio mostra la sala
## grande ripresa da una telecamera (la medusa è ancora lì); dal blackout solo neve. Va a
## batteria: la sua luce resta anche al buio. Segue GameState.luci.

## La mesh dello schermo (SCHERMO_CRT del modello).
@export var schermo_path: NodePath
## Dove mettere la sua luce (empty LUCE_crt del modello).
@export var luce_path: NodePath
## L'immagine della telecamera (uno scatto vero della sala, in 4:3).
@export var immagine: Texture2D
@export var colore_luce := Color(0.62, 0.86, 0.95)
@export var energia_luce := 0.7

var _materiale: ShaderMaterial
var _luce: OmniLight3D
var _t := 0.0


func _ready() -> void:
	var schermo := get_node_or_null(schermo_path) as MeshInstance3D
	if schermo:
		_materiale = ShaderMaterial.new()
		_materiale.shader = preload("res://shaders/tecnici/crt.gdshader")
		_materiale.set_shader_parameter(&"immagine", immagine if immagine else _immagine_vuota())
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
		_luce.global_position = punto.global_position + Vector3(0, 0, 0)
	GameState.luci_cambiate.connect(_applica)
	_applica(GameState.luci)


## Solo neve (dal blackout in poi).
func mostra_neve() -> void:
	if _materiale:
		_materiale.set_shader_parameter(&"neve", 1.0)


func mostra_neve_attiva() -> bool:
	return _materiale != null and float(_materiale.get_shader_parameter(&"neve")) > 0.5


func _applica(fase: GameState.Luci) -> void:
	if _materiale == null:
		return
	_materiale.set_shader_parameter(&"neve", 1.0 if fase == GameState.Luci.BLACKOUT else 0.0)
	_materiale.set_shader_parameter(&"luminosita", 2.4 if fase == GameState.Luci.FLASH else 1.3)


func _process(delta: float) -> void:
	if _luce == null:
		return
	_t += delta
	# Il tubo tremola: con la neve di più.
	var k := 0.85 + 0.1 * sin(_t * 31.0) + 0.05 * sin(_t * 77.0)
	if mostra_neve_attiva():
		k = 0.7 + 0.3 * randf()
	_luce.light_energy = energia_luce * k


static func _immagine_vuota() -> Texture2D:
	var img := Image.create_empty(64, 48, false, Image.FORMAT_RGB8)
	img.fill(Color(0.08, 0.1, 0.1))
	return ImageTexture.create_from_image(img)
