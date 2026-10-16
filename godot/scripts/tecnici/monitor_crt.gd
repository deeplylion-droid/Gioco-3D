class_name MonitorCrt
extends Node
## Il vecchio monitor a tubo della sala pompe (tappa 6): prima del risveglio mostra la sala
## grande ripresa da una telecamera di sorveglianza anni '90 (la medusa è ancora lì), a bassa
## risoluzione, con le righe del tubo e la sovrimpressione di telecamera, data e ora che corre;
## dal blackout solo neve. Va a batteria: la sua luce resta anche al buio. Segue GameState.luci.
## L'immagine e la sovrimpressione si compongono in un piccolo SubViewport 2D (320 x 240), che
## lo shader del tubo (shaders/tecnici/crt.gdshader) mostra sullo schermo del modello.
## Lo schermo del glTF (SCHERMO_CRT) è un rettangolo piatto qualche centimetro davanti al vetro
## bombato del tubo: da vicino sembrava un foglio nero attaccato sul televisore (riscontro E5
## dell'utente). Al suo posto va [member schermo_sul_vetro], una griglia appoggiata sul vetro che
## prepara il costruttore della sala con [method costruisci_schermo_sul_vetro]. Non la si calcola al
## caricamento: leggere le mesh dalla scheda video mentre la scena entra può bloccare il gioco
## (succedeva sul renderer Vulkan).

## La mesh dello schermo (SCHERMO_CRT del modello).
@export var schermo_path: NodePath
## Dove mettere la sua luce (empty LUCE_crt del modello).
@export var luce_path: NodePath
## Lo schermo appoggiato sul vetro bombato del televisore (costruisci_schermo_sul_vetro), nelle
## coordinate di SCHERMO_CRT. Vuoto = resta il rettangolo piatto del modello.
@export var schermo_sul_vetro: Mesh
## L'immagine della telecamera (uno scatto vero della sala, in 4:3).
@export var immagine: Texture2D
## Sovrimpressione: nome della telecamera, data e ora d'inizio (l'ora poi corre).
@export var telecamera := "CAM 3"
@export var data := "12-08-1997"
@export var ora_inizio := Vector3i(2, 47, 13)
@export var colore_luce := Color(0.62, 0.86, 0.95)
@export var energia_luce := 0.7

const LATO := Vector2i(320, 240)

## Quanti vertici dello schermo poggiano sul vetro del televisore (0 = è rimasto il rettangolo
## piatto del modello).
var vertici_sul_vetro := 0
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
		if schermo_sul_vetro:
			schermo.mesh = schermo_sul_vetro
			vertici_sul_vetro = int(schermo_sul_vetro.get_meta(&"vertici_sul_vetro", 0))
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


## Una griglia sul rettangolo dello schermo [param schermo] (stesse UV), con ogni vertice spinto
## indietro fin sul vetro del televisore [param modello] (un raggio contro la sua mesh), [param stacco]
## metri davanti. [param schermo_a_modello] porta le coordinate dello schermo in quelle del
## televisore. Legge le mesh: va chiamata dove si leggono senza la scheda video (il costruttore
## della sala, senza schermo). Null se meno di metà dei vertici trova il vetro. Nei metadati,
## "vertici_sul_vetro".
static func costruisci_schermo_sul_vetro(schermo: Mesh, modello: Mesh, schermo_a_modello: Transform3D,
		suddivisioni := Vector2i(16, 12), stacco := 0.002) -> ArrayMesh:
	if schermo == null or modello == null or schermo.get_surface_count() == 0:
		return null
	var arr := schermo.surface_get_arrays(0)
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	if vv.size() < 3 or uv.size() != vv.size():
		return null
	# Gli angoli del rettangolo, dalle UV.
	var angoli: Array[Vector3] = []
	for a in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var best := 0
		for i in uv.size():
			if uv[i].distance_squared_to(a) < uv[best].distance_squared_to(a):
				best = i
		angoli.append(vv[best])
	var n := (angoli[1] - angoli[0]).cross(angoli[2] - angoli[0]).normalized()
	var nn: Variant = arr[Mesh.ARRAY_NORMAL]
	if nn is PackedVector3Array and (nn as PackedVector3Array).size() > 0 and n.dot((nn as PackedVector3Array)[0]) < 0.0:
		n = -n
	var tri: TriangleMesh = modello.generate_triangle_mesh()
	if tri == null:
		return null
	var a_schermo := schermo_a_modello.affine_inverse()
	var punti := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normali := PackedVector3Array()
	var trovati := 0
	var nx := maxi(suddivisioni.x, 1)
	var ny := maxi(suddivisioni.y, 1)
	for j in ny + 1:
		for i in nx + 1:
			var s := float(i) / nx
			var t := float(j) / ny
			var p := angoli[0].lerp(angoli[1], s).lerp(angoli[2].lerp(angoli[3], s), t)
			# Dal davanti del rettangolo fino a 15 cm dietro: il primo punto del televisore è il vetro.
			var colpo: Dictionary = tri.intersect_segment(schermo_a_modello * (p + n * 0.05), schermo_a_modello * (p - n * 0.15))
			if not colpo.is_empty():
				p = a_schermo * (colpo.position as Vector3) + n * stacco
				trovati += 1
			punti.append(p)
			uvs.append(Vector2(s, t))
			normali.append(n)
	if trovati < (nx + 1) * (ny + 1) / 2:
		return null
	var indici := PackedInt32Array()
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			# Facce in senso orario viste da davanti (come vuole Godot).
			if (punti[b] - punti[a]).cross(punti[c] - punti[a]).dot(n) > 0.0:
				indici.append_array([a, c, b, b, c, d])
			else:
				indici.append_array([a, b, c, b, d, c])
	var nuovo := []
	nuovo.resize(Mesh.ARRAY_MAX)
	nuovo[Mesh.ARRAY_VERTEX] = punti
	nuovo[Mesh.ARRAY_NORMAL] = normali
	nuovo[Mesh.ARRAY_TEX_UV] = uvs
	nuovo[Mesh.ARRAY_INDEX] = indici
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, nuovo)
	mesh.resource_name = "SCHERMO_CRT_sul_vetro"
	mesh.set_meta(&"vertici_sul_vetro", trovati)
	return mesh


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
	# Un po' dentro dai bordi: gli angoli del tubo sono scuri (crt.gdshader) e coprivano la data.
	var cam := _scritta(telecamera, Vector2(34, 20))
	cam.name = "Nome"
	_rec = _scritta("● REC", Vector2(LATO.x - 96, 20))
	_ora = _scritta("", Vector2(34, LATO.y - 42))


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
