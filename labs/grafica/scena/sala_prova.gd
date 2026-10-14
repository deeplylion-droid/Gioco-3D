extends Node3D
## Scena di prova notturna, simile all'acquapark: sala rotonda con cupola di vetro,
## piscina vuota, colonne, balconata, corridoio laterale e piedistallo.
## La geometria è semplice e costruita da codice; luci, ombre, nebbia e
## materiali sono quelli veri del motore.

const TEX := "res://scena/texture/"
const R_SALA := 18.0           # raggio interno del muro
const H_SALA := 9.0            # altezza del soffitto
const R_CUPOLA := 8.0
const H_CUPOLA := 5.0
const CORRIDOIO_LARGO := 4.0
const CORRIDOIO_ALTO := 3.5
const CORRIDOIO_FINE := 34.0

var tempesta: Tempesta
var torcia: Torcia
var giocatore: CharacterBody3D
var neon: Array[Neon] = []
var emergenze: Array[LuceEmergenza] = []
var lampione: Neon
var env: Environment

var _mat := {}


func _ready() -> void:
	_crea_materiali()
	_crea_ambiente()
	_crea_sala()
	_crea_piscina()
	_crea_cupola()
	_crea_corridoio()
	_crea_piedistallo()
	_crea_oggetti()
	_crea_luci()
	_crea_effetti()
	_crea_giocatore()
	_crea_gi()
	if OS.get_cmdline_user_args().size() > 0:
		var c := preload("res://scena/cattura.gd").new()
		c.name = "Cattura"
		add_child(c)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_opzioni") and not has_node("MenuLayer"):
		apri_menu()
		get_viewport().set_input_as_handled()


func apri_menu() -> MenuOpzioni:
	var layer := CanvasLayer.new()
	layer.name = "MenuLayer"
	layer.layer = 100
	var m := MenuOpzioni.new()
	layer.add_child(m)
	add_child(layer)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	m.chiuso.connect(func():
		layer.queue_free()
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	return m


# --- Materiali -----------------------------------------------------------------

func _pbr(nome: String, scala: float, rugosita := 1.0, tinta := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + nome + "_diff.jpg")
	m.albedo_color = tinta
	m.normal_enabled = true
	m.normal_texture = load(TEX + nome + "_nor_gl.jpg")
	m.roughness_texture = load(TEX + nome + "_rough.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = rugosita
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scala
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _colore(c: Color, rugosita := 0.5, metallo := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugosita
	m.metallic = metallo
	return m


func _crea_materiali() -> void:
	# Pavimento bagnato: rugosità bassa, così SSR e sonde riflettono le luci.
	_mat["pavimento"] = _pbr("dirty_tiles", 0.9, 0.3, Color(0.8, 0.82, 0.82))
	_mat["muro"] = _pbr("peeling_painted_wall", 0.28, 1.0, Color(0.75, 0.8, 0.8))
	_mat["soffitto"] = _pbr("concrete_floor_painted", 0.2, 1.0, Color(0.55, 0.57, 0.58))
	_mat["vasca"] = _pbr("blue_floor_tiles_01", 0.5, 0.6)
	_mat["ruggine"] = _pbr("green_metal_rust", 0.6, 1.0)
	_mat["bordo"] = _pbr("concrete_floor_painted", 0.5, 0.7, Color(0.85, 0.85, 0.8))
	_mat["cromo"] = _colore(Color(0.8, 0.8, 0.82), 0.18, 1.0)
	var acqua := StandardMaterial3D.new()
	acqua.albedo_color = Color(0.03, 0.045, 0.04)
	acqua.roughness = 0.03
	acqua.metallic_specular = 0.6
	var n := NoiseTexture2D.new()
	n.noise = FastNoiseLite.new()
	n.noise.frequency = 0.05
	n.as_normal_map = true
	n.bump_strength = 1.5
	n.seamless = true
	acqua.normal_enabled = true
	acqua.normal_texture = n
	acqua.normal_scale = 0.15
	acqua.uv1_triplanar = true
	acqua.uv1_world_triplanar = true
	acqua.uv1_scale = Vector3.ONE * 0.25
	_mat["acqua"] = acqua
	var vinile := StandardMaterial3D.new()
	vinile.albedo_color = Color(0.55, 0.6, 0.9)
	vinile.roughness = 0.28
	vinile.clearcoat_enabled = true
	vinile.clearcoat = 0.6
	vinile.clearcoat_roughness = 0.2
	_mat["vinile"] = vinile


# --- Ambiente ------------------------------------------------------------------

func _crea_ambiente() -> void:
	env = Environment.new()
	var cielo := ShaderMaterial.new()
	cielo.shader = preload("res://grafica/cielo_tempesta.gdshader")
	var sky := Sky.new()
	sky.sky_material = cielo
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.4
	env.ssr_enabled = true
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.2
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_energy = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set("glow_levels/1", 0.0)
	env.set("glow_levels/2", 0.4)
	env.set("glow_levels/3", 1.0)
	env.set("glow_levels/5", 0.6)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.024
	env.volumetric_fog_albedo = Color(0.72, 0.76, 0.8)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_detail_spread = 1.6
	env.volumetric_fog_gi_inject = 0.5
	env.volumetric_fog_ambient_inject = 0.12
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# --- Geometria -----------------------------------------------------------------

## Settore di anello solido (muri curvi, soffitto, balconata). Angoli in radianti.
func _anello(nome: String, r_in: float, r_out: float, y0: float, y1: float, a0: float, a1: float,
		mat: Material, collisione := true, segmenti := 0) -> MeshInstance3D:
	if segmenti <= 0:
		segmenti = maxi(int((a1 - a0) / TAU * 120.0), 2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segmenti:
		var aa := lerpf(a0, a1, float(i) / segmenti)
		var ab := lerpf(a0, a1, float(i + 1) / segmenti)
		var da := Vector3(cos(aa), 0, sin(aa))
		var db := Vector3(cos(ab), 0, sin(ab))
		# interno (normale verso il centro), esterno, sopra, sotto
		_quad(st, da * r_in + Vector3.UP * y0, db * r_in + Vector3.UP * y0, db * r_in + Vector3.UP * y1, da * r_in + Vector3.UP * y1, -da, -db)
		_quad(st, db * r_out + Vector3.UP * y0, da * r_out + Vector3.UP * y0, da * r_out + Vector3.UP * y1, db * r_out + Vector3.UP * y1, db, da)
		_quad(st, da * r_in + Vector3.UP * y1, db * r_in + Vector3.UP * y1, db * r_out + Vector3.UP * y1, da * r_out + Vector3.UP * y1, Vector3.UP, Vector3.UP)
		_quad(st, db * r_in + Vector3.UP * y0, da * r_in + Vector3.UP * y0, da * r_out + Vector3.UP * y0, db * r_out + Vector3.UP * y0, Vector3.DOWN, Vector3.DOWN)
	if a1 - a0 < TAU - 0.001:
		for a in [a0, a1]:
			var d := Vector3(cos(a), 0, sin(a))
			var n := Vector3(-sin(a), 0, cos(a)) * (-1.0 if a == a0 else 1.0)
			var p := [d * r_in + Vector3.UP * y0, d * r_out + Vector3.UP * y0, d * r_out + Vector3.UP * y1, d * r_in + Vector3.UP * y1]
			if a == a0:
				_quad(st, p[1], p[0], p[3], p[2], n, n)
			else:
				_quad(st, p[0], p[1], p[2], p[3], n, n)
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	if collisione:
		var corpo := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		corpo.add_child(cs)
		mi.add_child(corpo)
	return mi


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3) -> void:
	# a-b in basso, c-d in alto; ordine antiorario visto dal lato della normale.
	for v in [[a, na], [c, nb], [b, nb], [a, na], [d, na], [c, nb]]:
		st.set_normal(v[1])
		st.add_vertex(v[0])


func _box(nome: String, centro: Vector3, dim: Vector3, mat: Material, collisione := true, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var b := BoxMesh.new()
	b.size = dim
	mi.mesh = b
	mi.material_override = mat
	mi.position = centro
	parent.add_child(mi)
	if collisione:
		var corpo := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = dim
		cs.shape = sh
		corpo.add_child(cs)
		mi.add_child(corpo)
	return mi


func _cilindro(nome: String, base: Vector3, raggio: float, altezza: float, mat: Material, collisione := true, raggio_sopra := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var c := CylinderMesh.new()
	c.bottom_radius = raggio
	c.top_radius = raggio if raggio_sopra < 0.0 else raggio_sopra
	c.height = altezza
	c.radial_segments = 24
	mi.mesh = c
	mi.material_override = mat
	mi.position = base + Vector3.UP * altezza / 2
	add_child(mi)
	if collisione:
		var corpo := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = raggio
		sh.height = altezza
		cs.shape = sh
		corpo.add_child(cs)
		mi.add_child(corpo)
	return mi


func _crea_sala() -> void:
	var porta := asin((CORRIDOIO_LARGO / 2) / R_SALA)
	# Muro rotondo con l'apertura del corridoio (verso +X, angolo 0).
	_anello("Muro", R_SALA, R_SALA + 0.6, -0.4, H_SALA + 0.5, porta, TAU - porta, _mat["muro"])
	_anello("Architrave", R_SALA, R_SALA + 0.6, CORRIDOIO_ALTO, H_SALA + 0.5, -porta, porta, _mat["muro"], false, 4)
	# Soffitto ad anello intorno alla cupola.
	_anello("Soffitto", R_CUPOLA, R_SALA + 0.6, H_SALA, H_SALA + 0.6, 0.0, TAU, _mat["soffitto"], false)
	# Balconata con ringhiera.
	_anello("Balconata", 15.4, R_SALA, 4.5, 4.8, 0.0, TAU, _mat["soffitto"])
	_anello("Corrimano", 15.4, 15.5, 5.65, 5.72, 0.0, TAU, _mat["ruggine"], false)
	for i in 72:
		var a := TAU * i / 72.0
		_cilindro("Montante", Vector3(cos(a), 0, sin(a)) * 15.45 + Vector3.UP * 4.8, 0.025, 0.85, _mat["ruggine"], false)
	# Colonne sotto la balconata.
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0
		_cilindro("Colonna", Vector3(cos(a), 0, sin(a)) * 15.0, 0.38, H_SALA, _mat["ruggine"])
	# Pavimento intorno alla piscina (che va da x -7..7, z -4.5..4.5).
	var y := -0.25
	_box("Pavimento_N", Vector3(0, y, -12.0), Vector3(40, 0.5, 15), _mat["pavimento"])
	_box("Pavimento_S", Vector3(0, y, 12.0), Vector3(40, 0.5, 15), _mat["pavimento"])
	_box("Pavimento_O", Vector3(-13.5, y, 0), Vector3(13, 0.5, 9), _mat["pavimento"])
	_box("Pavimento_E", Vector3(13.5, y, 0), Vector3(13, 0.5, 9), _mat["pavimento"])


func _crea_piscina() -> void:
	var p := 2.0  # profondità
	_box("Fondo", Vector3(0, -p - 0.2, 0), Vector3(14.4, 0.4, 9.4), _mat["vasca"])
	_box("Vasca_N", Vector3(0, -p / 2, -4.6), Vector3(14.4, p, 0.2), _mat["vasca"])
	_box("Vasca_S", Vector3(0, -p / 2, 4.6), Vector3(14.4, p, 0.2), _mat["vasca"])
	_box("Vasca_O", Vector3(-7.1, -p / 2, 0), Vector3(0.2, p, 9.0), _mat["vasca"])
	_box("Vasca_E", Vector3(7.1, -p / 2, 0), Vector3(0.2, p, 9.0), _mat["vasca"])
	# Bordo in cemento chiaro.
	_box("Bordo_N", Vector3(0, 0.04, -4.85), Vector3(15.0, 0.08, 0.5), _mat["bordo"])
	_box("Bordo_S", Vector3(0, 0.04, 4.85), Vector3(15.0, 0.08, 0.5), _mat["bordo"])
	_box("Bordo_O", Vector3(-7.35, 0.04, 0), Vector3(0.5, 0.08, 9.2), _mat["bordo"])
	_box("Bordo_E", Vector3(7.35, 0.04, 0), Vector3(0.5, 0.08, 9.2), _mat["bordo"])
	# La pozza rimasta nella parte profonda.
	var pozza := _box("Pozza", Vector3(3.6, -p + 0.015, 0.3), Vector3(6.6, 0.03, 7.4), _mat["acqua"], false)
	pozza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Scaletta.
	for dz in [-0.3, 0.3]:
		_cilindro("Scaletta", Vector3(-6.75, -p, 2.5 + dz), 0.025, p + 0.9, _mat["cromo"], false)
	for k in 4:
		_box("Gradino", Vector3(-6.85, -p + 0.4 + k * 0.4, 2.5), Vector3(0.12, 0.03, 0.6), _mat["cromo"], false)


func _crea_cupola() -> void:
	var y0 := H_SALA + 0.6
	# Vetro: un ellissoide schiacciato, senza ombre (la luce del lampo ci passa).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anelli := 12
	var spicchi := 48
	for i in anelli:
		for j in spicchi:
			var v := []
			for d in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var t: float = (i + d[0]) / float(anelli) * PI / 2
				var a: float = (j + d[1]) / float(spicchi) * TAU
				var pos := Vector3(cos(a) * cos(t) * R_CUPOLA, sin(t) * H_CUPOLA + y0, sin(a) * cos(t) * R_CUPOLA)
				var nrm := Vector3(cos(a) * cos(t) / R_CUPOLA, sin(t) / H_CUPOLA, sin(a) * cos(t) / R_CUPOLA).normalized()
				v.append([pos, nrm])
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(-v[k][1])
				st.add_vertex(v[k][0])
	var vetro := MeshInstance3D.new()
	vetro.name = "Cupola"
	vetro.mesh = st.commit()
	var mv := ShaderMaterial.new()
	mv.shader = preload("res://grafica/vetro_cupola.gdshader")
	vetro.material_override = mv
	vetro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat["vetro"] = mv
	add_child(vetro)
	# Costoloni in metallo (fanno le ombre che si muovono a ogni lampo).
	for j in 16:
		var a := TAU * j / 16.0
		for i in 10:
			var t0 := i / 10.0 * PI / 2
			var t1 := (i + 1) / 10.0 * PI / 2
			var p0 := Vector3(cos(a) * cos(t0) * R_CUPOLA, sin(t0) * H_CUPOLA + y0, sin(a) * cos(t0) * R_CUPOLA)
			var p1 := Vector3(cos(a) * cos(t1) * R_CUPOLA, sin(t1) * H_CUPOLA + y0, sin(a) * cos(t1) * R_CUPOLA)
			_trave(p0, p1, 0.09, _mat["ruggine"])
	for t in [0.0, 0.35, 0.7, 1.05]:
		var r := cos(t) * R_CUPOLA
		var yy := sin(t) * H_CUPOLA + y0
		var segs := 40
		for k in segs:
			var a0 := TAU * k / segs
			var a1 := TAU * (k + 1) / segs
			_trave(Vector3(cos(a0) * r, yy, sin(a0) * r), Vector3(cos(a1) * r, yy, sin(a1) * r), 0.08, _mat["ruggine"])
	# Bordo della cupola: un tamburo corto sopra il soffitto.
	_anello("Tamburo", R_CUPOLA - 0.3, R_CUPOLA, H_SALA, y0 + 0.05, 0.0, TAU, _mat["ruggine"], false)


func _trave(a: Vector3, b: Vector3, spessore: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(spessore, spessore, a.distance_to(b) + spessore)
	mi.mesh = bm
	mi.material_override = mat
	add_child(mi)
	mi.global_transform = Transform3D(Basis.looking_at(b - a, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.FORWARD), (a + b) / 2)


func _crea_corridoio() -> void:
	var x0 := R_SALA - 0.5
	var lung := CORRIDOIO_FINE - x0
	var cx := x0 + lung / 2
	var w := CORRIDOIO_LARGO
	var h := CORRIDOIO_ALTO
	_box("Corr_Pavimento", Vector3(cx, -0.25, 0), Vector3(lung, 0.5, w + 0.6), _mat["pavimento"])
	_box("Corr_Soffitto", Vector3(cx, h + 0.2, 0), Vector3(lung, 0.4, w + 0.6), _mat["soffitto"])
	_box("Corr_Muro_N", Vector3(cx, h / 2, -w / 2 - 0.2), Vector3(lung, h, 0.4), _mat["muro"])
	_box("Corr_Muro_S", Vector3(cx, h / 2, w / 2 + 0.2), Vector3(lung, h, 0.4), _mat["muro"])
	_box("Corr_Fondo", Vector3(CORRIDOIO_FINE + 0.2, h / 2, 0), Vector3(0.4, h, w + 0.6), _mat["muro"])
	# Tubi lungo il soffitto.
	for z in [-1.5, -1.25]:
		var tubo := _cilindro("Tubo", Vector3.ZERO, 0.09, lung, _mat["ruggine"], false)
		tubo.rotation.z = PI / 2
		tubo.position = Vector3(cx, h - 0.25, z)
	# Una porta chiusa in fondo (con il maniglione).
	_box("Porta", Vector3(CORRIDOIO_FINE - 0.02, 1.1, 0), Vector3(0.08, 2.2, 1.3), _mat["ruggine"], false)
	_box("Maniglione", Vector3(CORRIDOIO_FINE - 0.1, 1.05, 0), Vector3(0.05, 0.06, 1.0), _mat["cromo"], false)


func _crea_piedistallo() -> void:
	var c := Vector3(0, 0, -11.0)
	_cilindro("Piedistallo", c, 1.5, 0.45, _mat["bordo"])
	_cilindro("Piedistallo2", c + Vector3.UP * 0.45, 1.15, 0.9, _mat["vasca"], true, 1.05)
	# La statua: base grezza Meshy della medusa, ridotta (strumenti/riduci_statua.py).
	var statua: Node3D = load("res://scena/modelli/statua_provvisoria.glb").instantiate()
	statua.name = "Statua"
	statua.scale = Vector3.ONE * 1.8
	add_child(statua)
	var box := AABB()
	for mi in statua.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		box = box.merge(m.global_transform * m.get_aabb()) if box.size != Vector3.ZERO else m.global_transform * m.get_aabb()
	statua.global_position = c + Vector3.UP * 1.35 - Vector3(box.get_center().x, box.position.y, box.get_center().z)
	# Lampione che ronza sopra la statua (zona 3 del capitolo).
	lampione = Neon.new()
	lampione.name = "Lampione"
	lampione.modalita = Neon.Modalita.GUASTO
	var palo := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.06
	pm.bottom_radius = 0.08
	pm.height = 5.5
	palo.mesh = pm
	palo.material_override = _mat["ruggine"]
	palo.position = Vector3(0, 2.75, 0)
	lampione.add_child(palo)
	var testa_l := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.9, 0.12, 0.35)
	testa_l.mesh = tb
	testa_l.material_override = _mat["ruggine"]
	testa_l.position = Vector3(-0.4, 5.5, 0)
	lampione.add_child(testa_l)
	var lente := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.6, 0.02, 0.22)
	lente.mesh = lb
	var ml := _colore(Color(1, 0.9, 0.7), 0.3)
	ml.emission_enabled = true
	ml.emission = Color(1.0, 0.78, 0.5)
	ml.emission_energy_multiplier = 8.0
	lente.material_override = ml
	lente.position = Vector3(-0.45, 5.43, 0)
	lente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lampione.add_child(lente)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.8, 0.58)
	spot.light_energy = 9.0
	spot.spot_range = 12.0
	spot.spot_angle = 38.0
	spot.spot_attenuation = 1.2
	spot.shadow_enabled = true
	spot.light_size = 0.15
	spot.light_volumetric_fog_energy = 1.5
	spot.position = Vector3(-0.45, 5.38, 0)
	lampione.add_child(spot)
	lampione.position = c + Vector3(2.4, 0, 1.2)
	add_child(lampione)
	spot.look_at(c + Vector3.UP * 2.6)


func _crea_oggetti() -> void:
	# Pochi giocattoli dai colori saturi (stile B): salvagenti, pallone, papera.
	var colori := [Color(0.9, 0.12, 0.08), Color(1.0, 0.55, 0.05), Color(0.1, 0.55, 0.95), Color(0.2, 0.8, 0.3)]
	var posti := [Vector3(-9, 0.12, 7), Vector3(9.5, 0.12, -6), Vector3(-1.5, -1.88, -2.5), Vector3(4.5, -1.9, 2.8), Vector3(22, 0.12, 1.2)]
	for i in posti.size():
		var s := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.28
		t.outer_radius = 0.5
		s.mesh = t
		s.material_override = _colore(colori[i % colori.size()], 0.35)
		s.position = posti[i]
		s.rotation = Vector3(randf_range(-0.15, 0.15), randf() * TAU, randf_range(-0.15, 0.15))
		add_child(s)
	var palla := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.35
	sp.height = 0.7
	palla.mesh = sp
	palla.material_override = _colore(Color(1.0, 0.85, 0.1), 0.3)
	palla.position = Vector3(-3.0, -1.65, 1.0)
	add_child(palla)
	# Cartellone colorato sulla balconata.
	var pannello := _box("Cartellone", Vector3(0, 5.25, -15.3), Vector3(5.2, 1.0, 0.08), _colore(Color(0.1, 0.35, 0.85), 0.6), false)
	pannello.rotation.y = 0.0
	var scritta := Label3D.new()
	scritta.text = "SPLASH ZONE"
	scritta.font_size = 160
	scritta.pixel_size = 0.0045
	scritta.modulate = Color(1.0, 0.85, 0.1)
	scritta.outline_modulate = Color(0.9, 0.2, 0.1)
	scritta.outline_size = 24
	scritta.shaded = true
	scritta.position = Vector3(0, 5.25, -15.25)
	add_child(scritta)
	# Cartello USCITA verde sopra il corridoio.
	var uscita := Label3D.new()
	uscita.text = "USCITA"
	uscita.font_size = 90
	uscita.pixel_size = 0.004
	uscita.modulate = Color(0.3, 1.0, 0.45)
	uscita.position = Vector3(R_SALA - 0.05, CORRIDOIO_ALTO + 0.45, 0)
	uscita.rotation.y = -PI / 2
	add_child(uscita)
	var luce_u := OmniLight3D.new()
	luce_u.light_color = Color(0.3, 1.0, 0.45)
	luce_u.light_energy = 0.35
	luce_u.omni_range = 3.0
	luce_u.position = Vector3(R_SALA - 0.4, CORRIDOIO_ALTO + 0.4, 0)
	add_child(luce_u)


func _crea_luci() -> void:
	# Luna attraverso la cupola: debolissima, ma disegna i costoloni sul pavimento.
	var luna := DirectionalLight3D.new()
	luna.name = "Luna"
	luna.light_color = Color(0.55, 0.65, 0.95)
	luna.light_energy = 0.7
	luna.shadow_enabled = true
	luna.light_angular_distance = 0.5
	luna.light_volumetric_fog_energy = 2.0
	luna.rotation = Vector3(deg_to_rad(-76), deg_to_rad(25), 0)
	add_child(luna)
	tempesta = Tempesta.new()
	tempesta.name = "Tempesta"
	tempesta.materiali = [_mat["vetro"]]
	add_child(tempesta)
	# Neon appesi sotto il soffitto, in vari stati.
	var modi := [Neon.Modalita.STABILE, Neon.Modalita.GUASTO, Neon.Modalita.MORENTE, Neon.Modalita.SFARFALLA,
		Neon.Modalita.STABILE, Neon.Modalita.SPENTO, Neon.Modalita.GUASTO, Neon.Modalita.MORENTE]
	for i in 8:
		var a := TAU * (i + 0.25) / 8.0
		var n := Neon.new()
		n.modalita = modi[i]
		n.lunghezza = 1.5
		n.position = Vector3(cos(a), 0, sin(a)) * 16.6 + Vector3.UP * 4.47  # sotto la balconata
		n.rotation.y = -a + PI / 2
		n.portata = 9.0
		n.energia_luce = 6.0
		add_child(n)
		neon.append(n)
	var modi_c := [Neon.Modalita.STABILE, Neon.Modalita.SFARFALLA, Neon.Modalita.MORENTE, Neon.Modalita.GUASTO]
	for i in 4:
		var n := Neon.new()
		n.modalita = modi_c[i]
		n.position = Vector3(20.5 + i * 3.6, CORRIDOIO_ALTO, 0)
		n.ombre = i == 0
		add_child(n)
		neon.append(n)
	# Luci d'emergenza rosse a parete, sotto la balconata e sopra.
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0 + 0.3
		var e := LuceEmergenza.new()
		e.modalita = LuceEmergenza.Modalita.PULSANTE if i % 3 == 1 else LuceEmergenza.Modalita.FISSA
		var dentro := -Vector3(cos(a), 0, sin(a))
		e.position = -dentro * (R_SALA - 0.02) + Vector3.UP * 7.2
		var tangente := dentro.cross(Vector3.UP).normalized()
		e.basis = Basis(tangente, dentro, tangente.cross(dentro))  # il "su" della lampada guarda la sala
		e.energia = 6.0
		e.portata = 14.0
		add_child(e)
		emergenze.append(e)
	var rot := LuceEmergenza.new()
	rot.modalita = LuceEmergenza.Modalita.ROTANTE
	rot.position = Vector3(CORRIDOIO_FINE - 0.35, 2.75, 0)
	_box("Mensola", Vector3(CORRIDOIO_FINE - 0.2, 2.72, 0), Vector3(0.4, 0.05, 0.3), _mat["ruggine"], false)
	rot.energia = 3.0
	add_child(rot)
	emergenze.append(rot)
	var rot2 := LuceEmergenza.new()
	rot2.modalita = LuceEmergenza.Modalita.ROTANTE
	rot2.position = Vector3(-11.0, 4.8, -11.0)
	rot2.energia = 3.0
	add_child(rot2)
	emergenze.append(rot2)
	# Sonda di riflessione della sala (per il pavimento bagnato).
	var sonda := ReflectionProbe.new()
	sonda.size = Vector3(37, 11, 37)
	sonda.position = Vector3(0, 4.5, 0)
	sonda.box_projection = true
	sonda.interior = true
	sonda.update_mode = ReflectionProbe.UPDATE_ONCE
	sonda.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(sonda)


func _crea_effetti() -> void:
	var polvere := Pulviscolo.new()
	polvere.volume = Vector3(30, 8, 30)
	polvere.position = Vector3(0, 4.0, 0)
	add_child(polvere)
	var polvere_c := Pulviscolo.new()
	polvere_c.volume = Vector3(16, 3.2, 4)
	polvere_c.densita = 2.0
	polvere_c.position = Vector3(26, 1.7, 0)
	add_child(polvere_c)
	var vapore := Vapore.new()
	vapore.position = Vector3(25.5, 0.0, 1.4)
	vapore.altezza = 3.2
	vapore.raggio = 0.35
	add_child(vapore)
	var vapore2 := Vapore.new()
	vapore2.position = Vector3(-6.2, -2.0, -3.6)
	vapore2.altezza = 3.0
	vapore2.portata = 0.7
	vapore2.a_sbuffi = true
	add_child(vapore2)
	# Nebbia bassa sul pavimento della sala.
	var nebbia := FogVolume.new()
	nebbia.size = Vector3(36, 2.2, 36)
	nebbia.position = Vector3(0, 0.4, 0)
	nebbia.shape = RenderingServer.FOG_VOLUME_SHAPE_CYLINDER
	var fm := FogMaterial.new()
	fm.density = 0.035
	fm.height_falloff = 1.2
	fm.edge_fade = 0.3
	fm.albedo = Color(0.8, 0.83, 0.86)
	nebbia.material = fm
	add_child(nebbia)
	for p in [Vector3(10, H_SALA, -6), Vector3(-9, H_SALA, 5.5), Vector3(-2.5, H_SALA, -11.6), Vector3(24, CORRIDOIO_ALTO, -1.1)]:
		var g := Gocce.new()
		g.position = p
		g.altezza = p.y
		add_child(g)
	# Pioggia sopra la cupola (si vede solo attraverso il vetro).
	var pioggia := GPUParticles3D.new()
	pioggia.add_to_group("grafica_particelle")
	pioggia.amount = 1500
	pioggia.lifetime = 0.45
	pioggia.position = Vector3(0, H_SALA + 16, 0)
	pioggia.visibility_aabb = AABB(Vector3(-10, -14, -10), Vector3(20, 16, 20))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 0.5, 9)
	pm.direction = Vector3(0.15, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 28.0
	pm.gravity = Vector3.ZERO
	pioggia.process_material = pm
	pioggia.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var q := QuadMesh.new()
	q.size = Vector2(0.015, 0.7)
	var mq := StandardMaterial3D.new()
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.albedo_color = Color(0.7, 0.75, 0.85, 0.25)
	mq.albedo_texture = PunteggioMorbido.texture()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mq.backlight_enabled = true
	mq.backlight = Color(1, 1, 1)
	q.material = mq
	pioggia.draw_pass_1 = q
	pioggia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pioggia)


func _crea_giocatore() -> void:
	giocatore = CharacterBody3D.new()
	giocatore.name = "Giocatore"
	giocatore.set_script(preload("res://scena/giocatore.gd"))
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	giocatore.add_child(cs)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position.y = 1.65
	cam.near = 0.05
	cam.far = 200.0
	giocatore.add_child(cam)
	torcia = Torcia.new()
	torcia.name = "Torcia"
	cam.add_child(torcia)
	giocatore.position = Vector3(5.0, 0.0, 13.0)
	add_child(giocatore)
	giocatore.imposta_vista(Vector3(5.0, 1.65, 13.0), 20.0, 8.0)


func _crea_gi() -> void:
	var gi := VoxelGI.new()
	gi.name = "VoxelGI_Sala"
	gi.size = Vector3(40, 15, 40)
	gi.position = Vector3(0, 5.0, 0)
	gi.subdiv = VoxelGI.SUBDIV_128
	add_child(gi)
	var gi2 := VoxelGI.new()
	gi2.name = "VoxelGI_Corridoio"
	gi2.size = Vector3(18, 5, 6)
	gi2.position = Vector3(26, 1.8, 0)
	gi2.subdiv = VoxelGI.SUBDIV_64
	add_child(gi2)


## Stato "dopo le pompe": corrente saltata, restano solo le luci d'emergenza.
func blackout(attivo: bool) -> void:
	for n in neon:
		if attivo:
			n.spegni(false)
		else:
			n.accendi()
	if attivo:
		lampione.spegni(false)
	else:
		lampione.accendi(Neon.Modalita.GUASTO)
