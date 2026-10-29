class_name NebbiaViolaProva
extends Node
## La nebbia viola di NotHuman (dell'utente) tradotta in Godot, per una prova nell'infermeria (richiesta del 29 ottobre):
## non è nel gioco. Due passaggi, come nell'originale (assets_src/nebbia_viola):
## - la nebbia: un quad a schermo intero figlio della camera (nebbia_viola.gdshader), prima del tone mapping;
## - il colore: uno shader sullo schermo in un CanvasLayer (colore_viola.gdshader), dopo il tone mapping.
## [member attiva] è l'interruttore. Le luci (fino a 4) e la forza si danno con [method imposta_luci] e [member forza].
## Per zona (richiesta dell'utente del 29 ottobre: "farla apparire gradualmente quando entri negli ambienti dove ci
## sarà"): le ZonaNebbiaViola dicono quando il giocatore entra ed esce, e [member quanto] sale e scende in
## [member durata] secondi (densità e colore insieme, niente scatti sulla soglia). Spenta del tutto ([member quanto] 0)
## il quad e il colore sono nascosti: non si disegnano. Dopo un salto della camera (checkpoint, teletrasporto) la zona
## nuova vale subito, senza dissolvenza.

const NEBBIA := preload("res://proposte/nebbia_viola/nebbia_viola.gdshader")
const COLORE := preload("res://proposte/nebbia_viola/colore_viola.gdshader")

## Accesa o spenta (nebbia e colore insieme).
@export var attiva := true:
	set(v):
		attiva = v
		_mostra()
## Quanta nebbia (0..1): sale e scende da sé verso quella della zona, in [member durata] secondi.
@export_range(0.0, 1.0) var quanto := 1.0:
	set(v):
		quanto = clampf(v, 0.0, 1.0)
		if _mat:
			_mat.set_shader_parameter(&"quanto", quanto)
		if colore_mat:
			colore_mat.set_shader_parameter(&"quanto", quanto)
		_mostra()
## I secondi per passare da spenta a piena (entrando) e viceversa (uscendo).
@export var durata := 3.0
## Oltre questo spostamento della camera in un fotogramma è un salto (checkpoint): la zona nuova vale subito.
const SALTO := 3.0
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
var _camera: Camera3D
## Le zone in cui è il giocatore adesso (a pezzi possono sovrapporsi): la nebbia c'è se ce n'è almeno una.
var _zone := {}
## Se non ci sono zone (prove fuori dal gioco), quanto resta quello dato a mano.
var _per_zone := false
var _ultima_pos := Vector3.INF
var _fotogramma_salto := -100


func _ready() -> void:
	add_to_group(&"nebbia_viola")


func _process(delta: float) -> void:
	if _camera and is_instance_valid(_camera):
		var pos := _camera.global_position
		if _ultima_pos != Vector3.INF and pos.distance_to(_ultima_pos) > SALTO:
			_fotogramma_salto = Engine.get_process_frames()
			quanto = _obiettivo()
		_ultima_pos = pos
	if _per_zone:
		quanto = move_toward(quanto, _obiettivo(), delta / maxf(durata, 0.01))


## Il giocatore entra in una zona ([param zona]) o ne esce. Subito dopo un salto della camera (o con [param subito]):
## senza dissolvenza, così ripartendo da un checkpoint nella zona la nebbia è già lì.
func zona(z: Object, dentro: bool, subito := false) -> void:
	_per_zone = true
	if dentro:
		_zone[z] = true
	else:
		_zone.erase(z)
	if subito or Engine.get_process_frames() - _fotogramma_salto < 10:
		quanto = _obiettivo()


func _obiettivo() -> float:
	return 1.0 if not _zone.is_empty() else (quanto if not _per_zone else 0.0)


func _mostra() -> void:
	var v := attiva and quanto > 0.0
	if _quad:
		_quad.visible = v
	if _strato:
		_strato.visible = v


## Mette la nebbia davanti a [param camera] e il colore sullo schermo.
func su(camera: Camera3D) -> void:
	_camera = camera
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
	quanto = quanto


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
