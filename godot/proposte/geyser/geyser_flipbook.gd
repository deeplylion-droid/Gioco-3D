class_name GeyserFlipbook
extends GeyserMesh
## Proposta V2 del geyser della fossa (dopo la v0.3.5): la stessa simulazione della V1 (assets_src/geyser/simula.py)
## resa in Cycles come flipbook (assets_src/geyser/flipbook.py e flipbook_atlante.py: colore con l'alfa e normali)
## su un cartellone verticale che guarda la camera. Più dettaglio e una luce più bella della V1 a parità di costo
## (due triangoli), ma da ogni lato si vede la stessa colonna. Gocce, nebbiolina, pioggia, anello di schiuma e onde
## sull'acqua della fossa come la V1. Acqua piena: non si vede attraverso.

const SHADER_FLIPBOOK := preload("res://proposte/geyser/acqua_flipbook.gdshader")
const COLORE := preload("res://proposte/geyser/flipbook_colore.png")
const NORMALI := preload("res://proposte/geyser/flipbook_normali.png")
const FOTOGRAMMI := 78
## Come flipbook.py: largo LARGO, alto ALTO, a partire da Z_BASSO sopra la base del getto.
const LARGO := 6.0
const ALTO := 8.0
const Z_BASSO := 0.5

var _cartellone: MeshInstance3D
var _mf: ShaderMaterial


func _ready() -> void:
	top_level = true
	gocce = 110
	copre = 0.33   # come la V1 con la stessa simulazione: la colonna supera i 2,6 m a circa un terzo di secondo
	var q := QuadMesh.new()
	q.size = Vector2(LARGO, ALTO)
	_mf = ShaderMaterial.new()
	_mf.shader = SHADER_FLIPBOOK
	_mf.set_shader_parameter(&"colore", COLORE)
	_mf.set_shader_parameter(&"normali", NORMALI)
	_mf.set_shader_parameter(&"fotogrammi", FOTOGRAMMI)
	_mf.set_shader_parameter(&"alto_cartellone", ALTO)
	_cartellone = MeshInstance3D.new()
	_cartellone.name = "Cartellone"
	_cartellone.mesh = q
	_cartellone.material_override = _mf
	_cartellone.layers = LIVELLO_ACQUA
	_cartellone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cartellone.position = Vector3(0, Z_BASSO + ALTO / 2.0, 0)
	_cartellone.custom_aabb = AABB(Vector3(-4, -4.5, -4), Vector3(8, 9, 8))
	_cartellone.visible = false
	add_child(_cartellone)
	_crea_particelle()
	_crea_anello()
	set_process(false)


func scoppia(pavimento: Vector3, acque: Array = [], punti := PackedVector3Array()) -> void:
	_cartellone.visible = true
	super(pavimento, acque, punti)


func durata() -> float:
	return FOTOGRAMMI / FPS


func _aggiorna() -> void:
	var x := _t * FPS
	_cartellone.visible = x < FOTOGRAMMI - 1
	_mf.set_shader_parameter(&"fotogramma", clampf(round(x), 0.0, FOTOGRAMMI - 1.0))
	# fino a sopra il bordo della vasca (a 0,5 m dal fondo del cartellone) e un po' più su
	_mf.set_shader_parameter(&"affonda", _affonda() * 1.1)
	var k := clampf(_t / 2.6, 0.0, 1.0)
	_anello.scale = Vector3.ONE * (1.0 + 0.9 * sqrt(k))
	_anello_mat.set_shader_parameter(&"vita", k)
	_anello.visible = _t < 2.6
