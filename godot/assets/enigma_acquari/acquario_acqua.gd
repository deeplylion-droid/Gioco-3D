@tool
class_name AcquarioAcqua
extends Node3D
## L'acqua di un acquario dell'enigma (sala principale): il volume colorato visto dai vetri
## (acqua_acquario.gdshader), il pelo dell'acqua con una WaterBody dell'addon acqua (increspature,
## gorgo dello scarico) e i vetri sporchi. Il nodo sta al centro del FONDO interno della vasca;
## `inner_size` è l'interno dei vetri (larghezza X, altezza Y, profondità Z).
## Il riempimento va da 0 (vuoto) a 1 (pieno fino a `inner_size.y - margine`).

const VOLUME_SHADER := preload("res://assets/enigma_acquari/acqua_acquario.gdshader")
const VETRO_SHADER := preload("res://assets/enigma_acquari/vetro_acquario.gdshader")

@export var inner_size := Vector3(1.6, 1.2, 0.6):
	set(v):
		inner_size = v
		_rebuild()
## Lo stile dell'acqua (gli stessi WaterStyle dell'addon: absorption, turbidity, scatter_color...).
@export var style: WaterStyle:
	set(v):
		style = v
		_apply_style()
@export_range(0.0, 1.0, 0.001) var fill := 0.85:
	set(v):
		fill = v
		_apply_level()
## Il vetro: forma "box" (vasca) o "cilindro" (inner_size.x = diametro).
@export_enum("box", "cilindro") var forma := 0:
	set(v):
		forma = v
		_rebuild()
## Cubemap propria per i riflessi del pelo (costa memoria): serve agli acquari bassi, che si guardano
## da sopra; negli alti il pelo non si vede.
@export var riflessi_propri := false
@export var vetri := true:
	set(v):
		vetri = v
		_rebuild()
@export_range(0.0, 1.0) var sporco_vetro := 0.35:
	set(v):
		sporco_vetro = v
		if _vetro_mat:
			_vetro_mat.set_shader_parameter("grime", v)

var _body: WaterBody
var _volume: MeshInstance3D
var _vol_mat: ShaderMaterial
var _vetro: MeshInstance3D
var _vetro_mat: ShaderMaterial


func _ready() -> void:
	_rebuild()


func livello_mondo() -> float:
	return global_position.y + _level_local()


func _level_local() -> float:
	return clampf(fill, 0.0, 1.0) * (inner_size.y - 0.06)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for n in [_body, _volume, _vetro]:
		if n:
			n.queue_free()
	var cil := forma == 1
	# il volume visto dai vetri
	_volume = MeshInstance3D.new()
	_volume.name = "Volume"
	if cil:
		var cm := CylinderMesh.new()
		cm.top_radius = inner_size.x * 0.5 - 0.005
		cm.bottom_radius = cm.top_radius
		cm.height = inner_size.y
		cm.radial_segments = 48
		_volume.mesh = cm
	else:
		var bm := BoxMesh.new()
		bm.size = inner_size - Vector3(0.01, 0.0, 0.01)
		_volume.mesh = bm
	_volume.position.y = inner_size.y * 0.5
	_volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vol_mat = ShaderMaterial.new()
	_vol_mat.shader = VOLUME_SHADER
	_vol_mat.set_shader_parameter("box_size", inner_size)
	_vol_mat.set_shader_parameter("cylinder", cil)
	_volume.material_override = _vol_mat
	add_child(_volume, false, Node.INTERNAL_MODE_FRONT)
	# il pelo dell'acqua
	_body = WaterBody.new()
	_body.name = "Superficie"
	_body.size = Vector2(inner_size.x, inner_size.z)
	# vasche piccole: niente cubemap propria (prende i riflessi della sala) e increspature leggere
	_body.capture_env_cubemap = riflessi_propri
	_body.ripple_max_resolution = 128
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	if cil:
		_disco.call_deferred()
	# i vetri
	if vetri:
		_vetro = MeshInstance3D.new()
		_vetro.name = "Vetri"
		if cil:
			var cv := CylinderMesh.new()
			cv.top_radius = inner_size.x * 0.5 + 0.012
			cv.bottom_radius = cv.top_radius
			cv.height = inner_size.y
			cv.radial_segments = 64
			cv.cap_top = false
			cv.cap_bottom = false
			_vetro.mesh = cv
		else:
			var bv := BoxMesh.new()
			bv.size = inner_size + Vector3(0.024, 0.0, 0.024)
			_vetro.mesh = bv
		_vetro.position.y = inner_size.y * 0.5
		_vetro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_vetro_mat = ShaderMaterial.new()
		_vetro_mat.shader = VETRO_SHADER
		var nt := NoiseTexture2D.new()
		nt.seamless = true
		nt.noise = FastNoiseLite.new()
		nt.noise.frequency = 0.06
		nt.noise.fractal_octaves = 4
		nt.noise.seed = randi() % 1000
		var st := NoiseTexture2D.new()
		st.seamless = true
		st.width = 256
		st.height = 256
		st.noise = FastNoiseLite.new()
		st.noise.frequency = 0.05
		st.noise.fractal_octaves = 3
		_vetro_mat.set_shader_parameter("noise_tex", nt)
		_vetro_mat.set_shader_parameter("streak_tex", st)
		_vetro_mat.set_shader_parameter("grime", sporco_vetro)
		_vetro.material_override = _vetro_mat
		add_child(_vetro, false, Node.INTERNAL_MODE_FRONT)
	_apply_style()
	_apply_level()


## Nel cilindro il pelo dell'acqua è un disco (la WaterBody fa un rettangolo): stessa densità di
## vertici della griglia della WaterBody, per le increspature e il gorgo.
func _disco() -> void:
	var surf := _body.get_surface() if _body else null
	if surf == null:
		return
	var r := inner_size.x * 0.5 - 0.004
	var anelli := 24
	var spicchi := 64
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for a in anelli:
		var r0 := r * float(a) / anelli
		var r1 := r * float(a + 1) / anelli
		for k in spicchi:
			var t0 := TAU * k / spicchi
			var t1 := TAU * (k + 1) / spicchi
			var p00 := Vector3(cos(t0) * r0, 0, sin(t0) * r0)
			var p01 := Vector3(cos(t1) * r0, 0, sin(t1) * r0)
			var p10 := Vector3(cos(t0) * r1, 0, sin(t0) * r1)
			var p11 := Vector3(cos(t1) * r1, 0, sin(t1) * r1)
			for v in [p00, p11, p10, p00, p01, p11]:
				st.add_vertex(v)
	surf.mesh = st.commit()


func _apply_style() -> void:
	var st := style if style else WaterStyle.new()
	if _body:
		_body.style = st
	if _vol_mat:
		_vol_mat.set_shader_parameter("absorption", st.absorption)
		_vol_mat.set_shader_parameter("turbidity", st.turbidity)
		_vol_mat.set_shader_parameter("scatter_color", st.scatter_color)
		_vol_mat.set_shader_parameter("scatter_ambient", st.scatter_ambient)


func _apply_level() -> void:
	if not _body:
		return
	var l := _level_local()
	_body.bottom = global_position.y if is_inside_tree() else 0.0
	_body.max_level = global_position.y + inner_size.y
	_body.level = global_position.y + l
	_vol_mat.set_shader_parameter("level_local", l - inner_size.y * 0.5)
	_volume.visible = fill > 0.002
	if _vetro_mat:
		_vetro_mat.set_shader_parameter("waterline_local", (inner_size.y - 0.06) * 0.85 - inner_size.y * 0.5)
