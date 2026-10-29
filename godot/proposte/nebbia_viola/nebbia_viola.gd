class_name NebbiaViolaProva
extends Node
## La nebbia viola di NotHuman (dell'utente) tradotta in Godot, per una prova nell'infermeria (richiesta del 29 ottobre):
## non è nel gioco. Due passaggi, come nell'originale (assets_src/nebbia_viola):
## - la nebbia: un quad a schermo intero figlio della camera (nebbia_viola.gdshader), prima del tone mapping;
## - il colore: uno shader sullo schermo in un CanvasLayer (colore_viola.gdshader), dopo il tone mapping.
## [member attiva] è l'interruttore. Le luci (fino a 4) e la forza si danno con [method imposta_luci] e [member forza].

const NEBBIA := preload("res://proposte/nebbia_viola/nebbia_viola.gdshader")
const COLORE := preload("res://proposte/nebbia_viola/colore_viola.gdshader")

## Accesa o spenta (nebbia e colore insieme).
@export var attiva := true:
	set(v):
		attiva = v
		if _quad:
			_quad.visible = v
		if _strato:
			_strato.visible = v
## La luce di tutta la nebbia. L'originale è tarato su AgX con esposizione 2,6 ("con esposizione 1, circa 2,5").
@export var forza := 2.2:
	set(v):
		forza = v
		if _mat:
			_mat.set_shader_parameter(&"forza", v)
## Il pavimento (y).
@export var quota := 0.0:
	set(v):
		quota = v
		if _mat:
			_mat.set_shader_parameter(&"quota", v)

var _quad: MeshInstance3D
var _mat: ShaderMaterial
var _strato: CanvasLayer
var colore_mat: ShaderMaterial


## Mette la nebbia davanti a [param camera] e il colore sullo schermo.
func su(camera: Camera3D) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = NEBBIA
	_mat.set_shader_parameter(&"rumore_tex", _rumore())
	_mat.set_shader_parameter(&"forza", forza)
	_mat.set_shader_parameter(&"quota", quota)
	_quad = MeshInstance3D.new()
	_quad.name = "NebbiaViola"
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	_quad.mesh = q
	_quad.material_override = _mat
	_quad.extra_cull_margin = 16384.0
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(_quad)
	_quad.position = Vector3(0, 0, -1)
	_strato = CanvasLayer.new()
	_strato.name = "ColoreViola"
	_strato.layer = 0
	add_child(_strato)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colore_mat = ShaderMaterial.new()
	colore_mat.shader = COLORE
	r.material = colore_mat
	_strato.add_child(r)
	attiva = attiva


## Un valore dello shader della nebbia (lontano, oltre, cala, densita, strato...).
func imposta(nome: StringName, valore: Variant) -> void:
	_mat.set_shader_parameter(nome, valore)


## Le lampade (fino a 4): [posizione, colore, forza]; senza colore, il rosa caldo dell'originale.
func imposta_luci(luci: Array) -> void:
	var pos := PackedVector3Array()
	var col := PackedVector3Array()
	for l in luci.slice(0, 4):
		pos.append(l[0])
		var c: Color = l[1] if l.size() > 1 and l[1] != null else Color(1.0, 0.5, 0.62)
		var f: float = l[2] if l.size() > 2 else 0.18
		col.append(Vector3(c.r, c.g, c.b) * f)
	while pos.size() < 4:
		pos.append(Vector3.ZERO)
		col.append(Vector3.ZERO)
	_mat.set_shader_parameter(&"luci_pos", pos)
	_mat.set_shader_parameter(&"luci_col", col)
	_mat.set_shader_parameter(&"n_luci", mini(luci.size(), 4))


## Il rumore della nebbia: 256 x 256 valori a caso, e nel verde gli stessi spostati di (37, 17), come nell'originale.
static func _rumore() -> ImageTexture:
	var n := 256
	var r := PackedByteArray()
	r.resize(n * n)
	var s := 1234567
	for i in r.size():
		s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
		r[i] = s >> 24
	var d := PackedByteArray()
	d.resize(n * n * 4)
	for y in n:
		for x in n:
			var i := (y * n + x) * 4
			d[i] = r[y * n + x]
			d[i + 1] = r[((y - 17 + n) % n) * n + ((x - 37 + n) % n)]
			d[i + 3] = 255
	return ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, d))
