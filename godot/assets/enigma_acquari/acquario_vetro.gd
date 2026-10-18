@tool
class_name AcquarioVetro
extends Node3D
## I vetri e l'acqua vista dai vetri di un acquario dell'enigma (sala principale, stile B scelto
## dall'utente il 18 ottobre). Va dentro un WaterTank (con build_walls = false), nella sua origine
## (il centro del fondo interno); il cilindro di vetro ha il diametro di inner_size.x e l'altezza di
## inner_size.y del WaterTank.
## - Volume: l'acqua vista dai vetri (acqua_acquario.gdshader), alta quanto il livello del WaterTank.
## - Vetri: vetro sporco con il calcare alla quota dell'acqua (vetro_acquario.gdshader).
## - Il pelo dell'acqua lo fa il WaterTankLink dell'addon acqua fratello ([member acqua]): qui gli si
##   dà un disco al posto del rettangolo e lo stile del colore giusto.
## Il colore segue il miscuglio del WaterTank (segnale mix_changed): giallo, blu, i miscugli fino al
## verde, il verde dell'enigma riuscito e il torbido, approvati dall'utente; l'acqua chiara dello zaino
## schiarisce verso l'acqua limpida.

const VOLUME_SHADER := preload("res://assets/enigma_acquari/acqua_acquario.gdshader")
const VETRO_SHADER := preload("res://assets/enigma_acquari/vetro_acquario.gdshader")
const STILI := {
	"giallo": preload("res://assets/enigma_acquari/acqua_giallo.tres"),
	"blu": preload("res://assets/enigma_acquari/acqua_blu.tres"),
	"verde": preload("res://assets/enigma_acquari/acqua_verde.tres"),
	"torbida": preload("res://assets/enigma_acquari/acqua_torbido.tres"),
	"chiara": preload("res://addons/acqua/presets/stile_1_limpida.tres"),
}

## Il pelo dell'acqua dell'addon (WaterTankLink, acqua_per_vasca.tscn) di questo acquario.
@export var acqua: Node3D
## Quanto è sporco il vetro (calcare e colature).
@export_range(0.0, 1.0) var sporco := 0.35

var _tank: Node3D
var _volume: MeshInstance3D
var _vol_mat: ShaderMaterial
var _vetro: MeshInstance3D
var _vetro_mat: ShaderMaterial
var _livello := -1.0
var _disco_fatto := false


func _ready() -> void:
	_tank = get_parent() as Node3D
	_costruisci()
	if _tank and _tank.has_signal(&"mix_changed"):
		_tank.connect(&"mix_changed", _su_mix)
	_su_mix(_tank.get(&"mix") if _tank and &"mix" in _tank else {})
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm and wm.has_signal(&"quality_changed"):
		# la WaterBody rifà la sua griglia quando cambia la qualità: si rimette il disco
		wm.connect(&"quality_changed", func(_q): _disco_fatto = false)


func _process(_delta: float) -> void:
	if _tank == null:
		return
	var l: float = _tank.call(&"get_level") if _tank.has_method(&"get_level") else 0.0
	if absf(l - _livello) > 0.0005:
		_livello = l
		var s := _dimensioni()
		_vol_mat.set_shader_parameter("level_local", l - s.y * 0.5)
		_volume.visible = l > 0.01
	if not _disco_fatto:
		_disco()


func _dimensioni() -> Vector3:
	return _tank.get(&"inner_size") if _tank and &"inner_size" in _tank else Vector3(1.1, 1.3, 1.1)


func _costruisci() -> void:
	for n in [_volume, _vetro]:
		if n:
			n.queue_free()
	var s := _dimensioni()
	var r := s.x * 0.5
	_volume = MeshInstance3D.new()
	_volume.name = "Volume"
	var cm := CylinderMesh.new()
	cm.top_radius = r - 0.005
	cm.bottom_radius = r - 0.005
	cm.height = s.y
	cm.radial_segments = 48
	_volume.mesh = cm
	_volume.position.y = s.y * 0.5
	_volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vol_mat = ShaderMaterial.new()
	_vol_mat.shader = VOLUME_SHADER
	_vol_mat.set_shader_parameter("box_size", s)
	_vol_mat.set_shader_parameter("cylinder", true)
	_volume.material_override = _vol_mat
	add_child(_volume, false, Node.INTERNAL_MODE_FRONT)
	_vetro = MeshInstance3D.new()
	_vetro.name = "Vetri"
	var cv := CylinderMesh.new()
	cv.top_radius = r + 0.012
	cv.bottom_radius = r + 0.012
	cv.height = s.y
	cv.radial_segments = 64
	cv.cap_top = false
	cv.cap_bottom = false
	_vetro.mesh = cv
	_vetro.position.y = s.y * 0.5
	_vetro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vetro_mat = ShaderMaterial.new()
	_vetro_mat.shader = VETRO_SHADER
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.noise = FastNoiseLite.new()
	nt.noise.frequency = 0.06
	nt.noise.fractal_octaves = 4
	nt.noise.seed = hash(str(get_path())) % 1000
	var st := NoiseTexture2D.new()
	st.seamless = true
	st.width = 256
	st.height = 256
	st.noise = FastNoiseLite.new()
	st.noise.frequency = 0.05
	st.noise.fractal_octaves = 3
	_vetro_mat.set_shader_parameter("noise_tex", nt)
	_vetro_mat.set_shader_parameter("streak_tex", st)
	_vetro_mat.set_shader_parameter("grime", sporco)
	var mf: float = _tank.get(&"max_fill") if _tank and &"max_fill" in _tank else 0.94
	_vetro_mat.set_shader_parameter("waterline_local", s.y * mf - s.y * 0.5)
	_vetro.material_override = _vetro_mat
	add_child(_vetro, false, Node.INTERNAL_MODE_FRONT)


## Il pelo dell'acqua del WaterTankLink diventa un disco grande quanto il vetro.
func _disco() -> void:
	if acqua == null or not acqua.has_method(&"get_surface"):
		return
	var surf := acqua.call(&"get_surface") as MeshInstance3D
	if surf == null:
		return
	var r := _dimensioni().x * 0.5 - 0.004
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
	_disco_fatto = true


func _su_mix(m: Dictionary) -> void:
	var stile := stile_per(m)
	if _vol_mat:
		_vol_mat.set_shader_parameter("absorption", stile.absorption)
		_vol_mat.set_shader_parameter("turbidity", stile.turbidity)
		_vol_mat.set_shader_parameter("scatter_color", stile.scatter_color)
		_vol_mat.set_shader_parameter("scatter_ambient", stile.scatter_ambient)
	if acqua and &"style" in acqua:
		acqua.set(&"style", stile)


## Lo stile dell'acqua per un miscuglio (WaterMix): tra blu, verde e giallo secondo la parte di
## giallo, il verde e il torbido dell'enigma, e verso l'acqua limpida quanto più c'è acqua chiara.
static func stile_per(m: Dictionary) -> WaterStyle:
	var g := float(m.get("giallo", 0.0))
	var b := float(m.get("blu", 0.0))
	var pesi := {}
	if g + b > 0.0:
		var x := g / (g + b)
		var verde := 2.0 / 3.0
		if x <= verde:
			pesi["blu"] = (g + b) * (1.0 - x / verde)
			pesi["verde"] = (g + b) * (x / verde)
		else:
			pesi["verde"] = (g + b) * (1.0 - (x - verde) / (1.0 - verde))
			pesi["giallo"] = (g + b) * ((x - verde) / (1.0 - verde))
	for k in ["verde", "torbida"]:
		if m.has(k):
			pesi[k] = float(pesi.get(k, 0.0)) + float(m[k])
	var tot := 0.0
	for k in pesi:
		tot += float(pesi[k])
	pesi["chiara"] = maxf(1.0 - tot, 0.0)
	return _mescola_stili(pesi)


static func _mescola_stili(pesi: Dictionary) -> WaterStyle:
	var tot := 0.0
	for k in pesi:
		tot += float(pesi[k])
	var out := WaterStyle.new()
	if tot <= 0.0:
		return STILI["chiara"]
	var campi_v := [&"absorption"]
	var campi_c := [&"scatter_color", &"foam_color", &"scum_color", &"underwater_fog_color"]
	var campi_f := [&"turbidity", &"scatter_ambient", &"roughness", &"wave_strength_a", &"wave_strength_b",
			&"wave_speed", &"refraction_strength", &"reflection_strength", &"foam_shore_amount",
			&"foam_shore_width", &"foam_ripple_amount", &"scum_amount", &"caustics_strength", &"caustics_scale"]
	for c in campi_v:
		out.set(c, Vector3.ZERO)
	for c in campi_c:
		out.set(c, Color(0, 0, 0))
	for c in campi_f:
		out.set(c, 0.0)
	for k in pesi:
		var w := float(pesi[k]) / tot
		if w <= 0.0:
			continue
		var s: WaterStyle = STILI[k]
		for c in campi_v:
			out.set(c, (out.get(c) as Vector3) + (s.get(c) as Vector3) * w)
		for c in campi_c:
			out.set(c, (out.get(c) as Color) + (s.get(c) as Color) * w)
		for c in campi_f:
			out.set(c, float(out.get(c)) + float(s.get(c)) * w)
	return out
