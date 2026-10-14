@tool
extends Node3D
## Sala di prova notturna per il laboratorio dell'acqua, ispirata alla pianta decisa per la sala
## principale (una sola sala sotto la cupola): piscina a onde vuota al centro con la pozza torbida
## e lo scarico, area bimbi a sinistra con la vasca bassa che si riempie, a destra la vasca
## profonda d'arrivo dello scivolo con la torre. Luci d'emergenza rosse, neon, cupola con il
## temporale, nebbia. La geometria e' generata da codice (anche nell'editor) e non viene salvata
## nella scena: e' solo un banco di prova, la sala vera la costruisce il livello.

const WET_SHADER := preload("res://water/shaders/wet_surface.gdshader")
const SKY_SHADER := preload("res://demo/shaders/dome_sky.gdshader")

@export var hall_half := Vector2(18.0, 12.0)
@export var hall_height := 8.0
@export var rebuild := false:
	set(v):
		rebuild = false
		if is_inside_tree():
			_build()

# aree (min x, min z, max x, max z)
const WAVE := Rect2(-6.0, -6.0, 12.0, 12.0)
const KIDS := Rect2(-14.7, -3.2, 5.4, 6.4)
const LAND := Rect2(9.0, -7.0, 6.0, 10.0)
const WAVE_DRAIN := Vector2(0.0, -3.6)
const KIDS_FLOOR := -0.6
const KIDS_RIM := 0.5
const LAND_FLOOR := -2.6

var materials := {}
var neon_lights: Array[Node3D] = []
var red_lights: Array[Light3D] = []
var moon: SpotLight3D
var sky_material: ShaderMaterial
var slide_curve: Curve3D


func _ready() -> void:
	_build()


## Quota del fondo della piscina a onde (spiaggia a sud, parte profonda a nord, conca sullo scarico).
static func wave_floor_y(x: float, z: float) -> float:
	var t := clampf((5.8 - z) / 6.8, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var y := lerpf(-0.15, -1.6, t)
	var d2 := (x - WAVE_DRAIN.x) * (x - WAVE_DRAIN.x) + (z - WAVE_DRAIN.y) * (z - WAVE_DRAIN.y)
	y -= 0.3 * exp(-d2 / (2.0 * 1.7 * 1.7))
	return y


func _material(name: String, tex: String, scale: float, extra := {}, albedo_tex := "") -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WET_SHADER
	m.set_shader_parameter("albedo_tex", load("res://demo/textures/%s_albedo.jpg" % (albedo_tex if albedo_tex != "" else tex)))
	m.set_shader_parameter("normal_tex", load("res://demo/textures/%s_normal.jpg" % tex))
	m.set_shader_parameter("orh_tex", load("res://demo/textures/%s_orh.jpg" % tex))
	m.set_shader_parameter("uv_scale", scale)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	materials[name] = m
	return m


func _build() -> void:
	for c in get_children(true):
		if c.has_meta("generated"):
			c.queue_free()
	materials.clear()
	neon_lights.clear()
	red_lights.clear()

	var m_wave := _material("wave", "piastrelle_vasca_rotte", 1.0 / 1.2, {"roughness_scale": 0.85, "albedo_tint": Color(0.62, 0.7, 0.72), "base_wetness": 0.25})
	var m_land := _material("land", "piastrelle_vasca", 1.0 / 1.2, {"roughness_scale": 0.8, "albedo_tint": Color(0.42, 0.52, 0.6)})
	var m_kids := _material("kids", "piastrelle_vasca", 1.0 / 1.2, {"roughness_scale": 0.8, "albedo_tint": Color(0.7, 0.78, 0.8)})
	var m_checker := _material("checker", "piastrelle_muro", 1.0 / 1.2, {"base_wetness": 0.5, "albedo_tint": Color(0.85, 0.85, 0.85)}, "piastrelle_scacchi")
	var m_deck := _material("deck", "piastrelle_pavimento", 1.0 / 1.8, {
		"base_wetness": 0.35, "puddle_amount": 0.5, "puddle_scale": 0.06, "wet_darkening": 0.55,
		"albedo_tint": Color(0.62, 0.62, 0.6)})
	var m_wall := _material("wall_tiles", "piastrelle_muro", 1.0 / 1.2, {"base_wetness": 0.2, "albedo_tint": Color(0.62, 0.66, 0.64)})
	var m_plaster := _material("plaster", "intonaco", 1.0 / 2.5, {"albedo_tint": Color(0.55, 0.6, 0.55)})
	var m_metal := _material("metal", "metallo", 1.0, {"metallic": 0.85, "roughness_scale": 0.9})
	var m_rim := _material("rim", "piastrelle_pavimento", 1.0 / 0.9, {"base_wetness": 0.6, "albedo_tint": Color(0.75, 0.75, 0.72)})
	var m_dark_metal := _material("dark_metal", "metallo", 2.0, {"metallic": 0.7, "albedo_tint": Color(0.25, 0.25, 0.25), "roughness_scale": 0.8})

	var hx := hall_half.x
	var hz := hall_half.y
	var ft := 0.5

	# --- pavimento della sala (rettangoli intorno alle aperture) ---
	var deck_rects := [
		Rect2(-hx, -hz, 2 * hx, hz - 7.0),
		Rect2(-hx, 6.0, 2 * hx, hz - 6.0),
		Rect2(-hx, -7.0, hx - 15.0, 13.0),
		Rect2(-15.0, -7.0, 6.0, 3.5),
		Rect2(-15.0, 3.5, 6.0, 2.5),
		Rect2(-9.0, -7.0, 3.0, 13.0),
		Rect2(-6.0, -7.0, 12.0, 1.0),
		Rect2(6.0, -7.0, 3.0, 13.0),
		Rect2(9.0, 3.0, 6.0, 3.0),
		Rect2(15.0, -7.0, hx - 15.0, 13.0),
	]
	for i in deck_rects.size():
		var r: Rect2 = deck_rects[i]
		_box("Deck%d" % i, Vector3(r.get_center().x, -ft * 0.5, r.get_center().y), Vector3(r.size.x, ft, r.size.y), m_deck)

	# --- piscina a onde: fondo inclinato con la conca dello scarico ---
	_heightfield("WaveFloor", WAVE, 64, m_wave)
	var wall_t := 0.3
	_box("WaveWallN", Vector3(0, -1.2, WAVE.position.y - wall_t * 0.5), Vector3(WAVE.size.x + 2 * wall_t, 2.4, wall_t), m_wave)
	_box("WaveWallW", Vector3(WAVE.position.x - wall_t * 0.5, -1.2, 0), Vector3(wall_t, 2.4, WAVE.size.y), m_wave)
	_box("WaveWallE", Vector3(WAVE.end.x + wall_t * 0.5, -1.2, 0), Vector3(wall_t, 2.4, WAVE.size.y), m_wave)
	_box("WaveWallS", Vector3(0, -0.25, WAVE.end.y + wall_t * 0.5), Vector3(WAVE.size.x + 2 * wall_t, 0.5, wall_t), m_wave)
	_rim(WAVE, m_rim, true)
	# bocche della macchina delle onde sulla parete nord
	for gx in [-3.5, 0.0, 3.5]:
		_box("WaveGrate", Vector3(gx, -0.95, WAVE.position.y + 0.01), Vector3(1.4, 0.7, 0.04), m_dark_metal, false)
	# scarico con griglia
	var dy := wave_floor_y(WAVE_DRAIN.x, WAVE_DRAIN.y)
	var drain := _cyl("Drain", Vector3(WAVE_DRAIN.x, dy + 0.005, WAVE_DRAIN.y), 0.38, 0.03, m_dark_metal)
	drain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# scaletta
	for xx in [3.8, 4.4]:
		_cyl("LadderRail", Vector3(xx, -0.55, WAVE.position.y + 0.15), 0.025, 1.9, m_metal)
		_cyl_between("LadderTop", Vector3(xx, 0.4, WAVE.position.y + 0.15), Vector3(xx, 0.8, WAVE.position.y - 0.25), 0.025, m_metal)
		_cyl_between("LadderOut", Vector3(xx, 0.8, WAVE.position.y - 0.25), Vector3(xx, 0.0, WAVE.position.y - 0.55), 0.025, m_metal)

	# --- area bimbi: vasca bassa rialzata con il bordo a scacchi ---
	var kt := 0.3
	var kh := KIDS_RIM - KIDS_FLOOR
	var kc := KIDS.get_center()
	_box("KidsFloor", Vector3(kc.x, KIDS_FLOOR - 0.1, kc.y), Vector3(KIDS.size.x, 0.2, KIDS.size.y), m_kids)
	_box("KidsWallW", Vector3(KIDS.position.x - kt * 0.5, KIDS_FLOOR + kh * 0.5, kc.y), Vector3(kt, kh, KIDS.size.y + 2 * kt), m_checker)
	_box("KidsWallE", Vector3(KIDS.end.x + kt * 0.5, KIDS_FLOOR + kh * 0.5, kc.y), Vector3(kt, kh, KIDS.size.y + 2 * kt), m_checker)
	_box("KidsWallN", Vector3(kc.x, KIDS_FLOOR + kh * 0.5, KIDS.position.y - kt * 0.5), Vector3(KIDS.size.x, kh, kt), m_checker)
	_box("KidsWallS", Vector3(kc.x, KIDS_FLOOR + kh * 0.5, KIDS.end.y + kt * 0.5), Vector3(KIDS.size.x, kh, kt), m_checker)
	_box("KidsCapW", Vector3(KIDS.position.x - kt * 0.5, KIDS_RIM + 0.04, kc.y), Vector3(kt + 0.12, 0.08, KIDS.size.y + 2 * kt + 0.12), m_rim, false)
	_box("KidsCapE", Vector3(KIDS.end.x + kt * 0.5, KIDS_RIM + 0.04, kc.y), Vector3(kt + 0.12, 0.08, KIDS.size.y + 2 * kt + 0.12), m_rim, false)
	_box("KidsCapN", Vector3(kc.x, KIDS_RIM + 0.04, KIDS.position.y - kt * 0.5), Vector3(KIDS.size.x, 0.08, kt + 0.12), m_rim, false)
	_box("KidsCapS", Vector3(kc.x, KIDS_RIM + 0.04, KIDS.end.y + kt * 0.5), Vector3(KIDS.size.x, 0.08, kt + 0.12), m_rim, false)
	# bocchette che riempiono la vasca
	for z in [-1.6, 1.6]:
		_cyl_between("KidsSpout", Vector3(KIDS.position.x + 0.02, 0.3, z), Vector3(KIDS.position.x + 0.32, 0.3, z), 0.06, m_metal)

	# --- vasca d'arrivo dello scivolo (profonda) ---
	var lc := LAND.get_center()
	var lh := -LAND_FLOOR
	_box("LandFloor", Vector3(lc.x, LAND_FLOOR - 0.15, lc.y), Vector3(LAND.size.x, 0.3, LAND.size.y), m_land)
	_box("LandWallN", Vector3(lc.x, LAND_FLOOR * 0.5, LAND.position.y - wall_t * 0.5), Vector3(LAND.size.x + 2 * wall_t, lh, wall_t), m_land)
	_box("LandWallS", Vector3(lc.x, LAND_FLOOR * 0.5, LAND.end.y + wall_t * 0.5), Vector3(LAND.size.x + 2 * wall_t, lh, wall_t), m_land)
	_box("LandWallW", Vector3(LAND.position.x - wall_t * 0.5, LAND_FLOOR * 0.5, lc.y), Vector3(wall_t, lh, LAND.size.y), m_land)
	_box("LandWallE", Vector3(LAND.end.x + wall_t * 0.5, LAND_FLOOR * 0.5, lc.y), Vector3(wall_t, lh, LAND.size.y), m_land)
	_rim(LAND, m_rim, false)
	# canaletta con la griglia lungo il lato ovest
	_box("Gutter", Vector3(LAND.position.x - 0.6, 0.002, lc.y), Vector3(0.28, 0.01, LAND.size.y), m_dark_metal, false)
	for xx in [13.2, 13.8]:
		_cyl("LandLadder", Vector3(xx, -0.6, LAND.end.y - 0.15), 0.025, 1.9, m_metal)
		_cyl_between("LandLadderTop", Vector3(xx, 0.35, LAND.end.y - 0.15), Vector3(xx, 0.8, LAND.end.y + 0.25), 0.025, m_metal)
		_cyl_between("LandLadderOut", Vector3(xx, 0.8, LAND.end.y + 0.25), Vector3(xx, 0.0, LAND.end.y + 0.55), 0.025, m_metal)

	# --- torre dello scivolo e tubo che scende nella vasca d'arrivo ---
	for p in [Vector2(10.4, -11.0), Vector2(13.6, -11.0), Vector2(10.4, -8.6), Vector2(13.6, -8.6)]:
		_box("TowerPost", Vector3(p.x, 3.0, p.y), Vector3(0.22, 6.0, 0.22), m_metal)
	_box("TowerDeck", Vector3(12.0, 5.6, -9.8), Vector3(3.6, 0.15, 2.8), m_metal)
	slide_curve = Curve3D.new()
	slide_curve.add_point(Vector3(12.0, 5.75, -10.6), Vector3.ZERO, Vector3(-2.0, 0.0, 0.0))
	slide_curve.add_point(Vector3(7.6, 4.2, -10.4), Vector3(0.0, 0.6, -1.8), Vector3(0.0, -0.6, 1.8))
	slide_curve.add_point(Vector3(9.0, 2.3, -6.6), Vector3(-2.2, 0.4, 0.0), Vector3(2.2, -0.4, 0.0))
	slide_curve.add_point(Vector3(13.6, 1.0, -9.2), Vector3(1.4, 0.4, 1.4), Vector3(-1.2, -0.3, -1.2))
	slide_curve.add_point(Vector3(12.0, 0.35, -6.8), Vector3(0.0, 0.25, -1.4), Vector3.ZERO)
	var tube_mat := StandardMaterial3D.new()
	tube_mat.albedo_color = Color(0.55, 0.32, 0.18)
	tube_mat.roughness = 0.55
	tube_mat.metallic = 0.0
	var tube := MeshInstance3D.new()
	tube.mesh = TubeBuilder.build_tube(slide_curve, 0.62, 0.68, 20, 0.25, true)
	tube.material_override = tube_mat
	_add(tube, "SlideTube")

	# --- muri, soffitto, cupola ---
	var tile_h := 1.8
	var wt := 0.3
	for side in [["N", Vector3(0, 0, -hz - wt * 0.5), Vector3(hx * 2 + 2 * wt, 0, wt)],
			["S", Vector3(0, 0, hz + wt * 0.5), Vector3(hx * 2 + 2 * wt, 0, wt)],
			["W", Vector3(-hx - wt * 0.5, 0, 0), Vector3(wt, 0, hz * 2)],
			["E", Vector3(hx + wt * 0.5, 0, 0), Vector3(wt, 0, hz * 2)]]:
		var c: Vector3 = side[1]
		var s: Vector3 = side[2]
		_box("WallTiles" + side[0], c + Vector3(0, tile_h * 0.5, 0), Vector3(s.x, tile_h, s.z), m_wall)
		_box("WallPlaster" + side[0], c + Vector3(0, tile_h + (hall_height - tile_h) * 0.5, 0), Vector3(s.x, hall_height - tile_h, s.z), m_plaster)
	_ceiling_with_dome(m_plaster, m_metal)
	for p in [Vector2(-8.0, -9.5), Vector2(8.0, 9.5), Vector2(-8.0, 9.5), Vector2(17.0, 8.5), Vector2(-17.0, -8.5)]:
		_box("Column", Vector3(p.x, hall_height * 0.5, p.y), Vector3(0.7, hall_height, 0.7), m_plaster)

	_build_lights()


func _ceiling_with_dome(m_ceiling: Material, m_metal: Material) -> void:
	var hx := hall_half.x
	var hz := hall_half.y
	var r := 7.2
	# soffitto attorno all'apertura quadrata della cupola
	_box("CeilN", Vector3(0, hall_height + 0.2, -(hz + r) * 0.5), Vector3(hx * 2, 0.4, hz - r), m_ceiling, false)
	_box("CeilS", Vector3(0, hall_height + 0.2, (hz + r) * 0.5), Vector3(hx * 2, 0.4, hz - r), m_ceiling, false)
	_box("CeilW", Vector3(-(hx + r) * 0.5, hall_height + 0.2, 0), Vector3(hx - r, 0.4, 2 * r), m_ceiling, false)
	_box("CeilE", Vector3((hx + r) * 0.5, hall_height + 0.2, 0), Vector3(hx - r, 0.4, 2 * r), m_ceiling, false)
	# cupola di vetro: semisfera vista da dentro con il cielo in tempesta
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r * 1.42
	sm.height = r * 1.42
	sm.is_hemisphere = true
	sm.radial_segments = 48
	sm.rings = 16
	sm.flip_faces = true
	dome.mesh = sm
	dome.position = Vector3(0, hall_height, 0)
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	dome.material_override = sky_material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(dome, "Dome")
	# travi a croce sotto la cupola
	_box("DomeBeamX", Vector3(0, hall_height - 0.15, 0), Vector3(2 * r, 0.3, 0.3), m_metal, false)
	_box("DomeBeamZ", Vector3(0, hall_height - 0.15, 0), Vector3(0.3, 0.3, 2 * r), m_metal, false)


func _build_lights() -> void:
	var hx := hall_half.x
	var hz := hall_half.y
	var reds := [
		[Vector3(-hx + 0.12, 3.6, -4.0), Vector3(1, 0, 0), 2.4, true],
		[Vector3(-hx + 0.12, 3.4, 6.5), Vector3(1, 0, 0), 2.0, false],
		[Vector3(hx - 0.12, 3.3, -2.5), Vector3(-1, 0, 0), 2.4, true],
		[Vector3(5.5, 3.3, -hz + 0.12), Vector3(0, 0, 1), 2.2, true],
		[Vector3(-7.0, 3.3, hz - 0.12), Vector3(0, 0, -1), 2.0, false],
		[Vector3(11.5, 3.0, hz - 0.12), Vector3(0, 0, -1), 2.2, true],
	]
	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color(0.2, 0.0, 0.0)
	red_mat.emission_enabled = true
	red_mat.emission = Color(1.0, 0.05, 0.03)
	red_mat.emission_energy_multiplier = 14.0
	for r in reds:
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var d: Vector3 = r[1]
		bm.size = Vector3(0.28 if d.x == 0 else 0.12, 0.13, 0.28 if d.z == 0 else 0.12)
		body.mesh = bm
		body.material_override = red_mat
		body.position = r[0]
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(body, "RedLamp")
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.06, 0.035)
		l.light_energy = r[2]
		l.omni_range = 11.0
		l.omni_attenuation = 1.5
		l.shadow_enabled = r[3]
		l.light_volumetric_fog_energy = 1.6
		l.position = r[0] + d * 0.3
		_add(l, "RedLight")
		red_lights.append(l)

	# neon sul soffitto: luce ad area + tubo luminoso
	var neon_mat := StandardMaterial3D.new()
	neon_mat.albedo_color = Color(0.6, 0.7, 0.75)
	neon_mat.emission_enabled = true
	neon_mat.emission = Color(0.8, 0.92, 1.0)
	neon_mat.emission_energy_multiplier = 9.0
	for p in [Vector3(-12.0, hall_height - 0.6, -7.5), Vector3(12.0, hall_height - 0.6, 7.5), Vector3(-12.5, hall_height - 0.6, 6.0)]:
		var holder := Node3D.new()
		holder.position = p
		_add(holder, "Neon")
		var tube := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.035
		cm.height = 1.5
		cm.radial_segments = 12
		tube.mesh = cm
		tube.rotation_degrees = Vector3(0, 0, 90)
		tube.material_override = neon_mat
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(tube)
		var al := AreaLight3D.new()
		al.area_size = Vector2(1.5, 0.08)
		al.light_color = Color(0.82, 0.93, 1.0)
		al.light_energy = 2.2
		al.area_range = 13.0
		al.rotation_degrees = Vector3(-90, 0, 0)
		al.position = Vector3(0, -0.05, 0)
		al.light_volumetric_fog_energy = 0.6
		holder.add_child(al)
		holder.set_meta("light", al)
		holder.set_meta("tube", tube)
		neon_lights.append(holder)

	# luce fioca della notte attraverso la cupola (e lampi del temporale): un faretto dall'alto.
	# (Con una DirectionalLight3D con ombre llvmpipe produceva pixel NaN in questa scena.)
	moon = SpotLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.4
	moon.spot_range = 26.0
	moon.spot_angle = 38.0
	moon.spot_attenuation = 0.6
	moon.shadow_enabled = true
	moon.position = Vector3(1.5, hall_height + 9.0, 1.0)
	moon.rotation_degrees = Vector3(-88, 0, 0)
	moon.light_volumetric_fog_energy = 2.0
	_add(moon, "Moon")


func _add(n: Node, nm: String) -> void:
	n.name = nm
	n.set_meta("generated", true)
	add_child(n, true)


func _heightfield(nm: String, r: Rect2, res: int, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in res:
		for i in res:
			var x0 := r.position.x + r.size.x * float(i) / res
			var x1 := r.position.x + r.size.x * float(i + 1) / res
			var z0 := r.position.y + r.size.y * float(j) / res
			var z1 := r.position.y + r.size.y * float(j + 1) / res
			var a := Vector3(x0, wave_floor_y(x0, z0), z0)
			var b := Vector3(x1, wave_floor_y(x1, z0), z0)
			var c := Vector3(x1, wave_floor_y(x1, z1), z1)
			var d := Vector3(x0, wave_floor_y(x0, z1), z1)
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(d)
	st.generate_normals()
	var mi := _mesh_node(nm, st.commit(), mat, true)
	return mi


func _rim(r: Rect2, mat: Material, skip_south: bool) -> void:
	var w := 0.35
	var h := 0.06
	var c := r.get_center()
	_box("RimN", Vector3(c.x, h * 0.5, r.position.y - w * 0.5), Vector3(r.size.x + 2 * w, h, w), mat)
	if not skip_south:
		_box("RimS", Vector3(c.x, h * 0.5, r.end.y + w * 0.5), Vector3(r.size.x + 2 * w, h, w), mat)
	_box("RimW", Vector3(r.position.x - w * 0.5, h * 0.5, c.y), Vector3(w, h, r.size.y), mat)
	_box("RimE", Vector3(r.end.x + w * 0.5, h * 0.5, c.y), Vector3(w, h, r.size.y), mat)


func _mesh_node(nm: String, mesh: Mesh, mat: Material, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	_add(mi, nm)
	if collide and not Engine.is_editor_hint():
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _box(nm: String, center: Vector3, size: Vector3, mat: Material, collide := true) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh_node(nm, bm, mat, false)
	mi.position = center
	if collide and not Engine.is_editor_hint():
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _cyl(nm: String, center: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	var mi := _mesh_node(nm, cm, mat, false)
	mi.position = center
	return mi


func _cyl_between(nm: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := _cyl(nm, (a + b) * 0.5, radius, a.distance_to(b), mat)
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 1e-4:
		mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	return mi
