extends SceneTree
## Scatti delle proposte per l'interno della sala della torre (fuori dal gioco: proposte/ non va nell'export).
## Carica proposte/torre/torre_<versione>.glb (fatto da tools/blender/torre_proposte.py), mette l'acqua torbida
## della sala sui piani "acqua_*", le luci (rosse d'emergenza ai muri, lampade da lavoro calde sulle pedane, la
## luce rosa di lei che sale dal pozzo del fondo) e l'ambiente della sala grande, poi fa gli scatti.
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --resolution 1600x900 \
##        --script res://proposte/torre/scatti_torre.gd -- <versione> <cartella> [scatti separati da virgole]

const ROSSO := Color(1.0, 0.035, 0.02)
const CALDO := Color(1.0, 0.66, 0.36)
const ROSA := Color(1.0, 0.32, 0.62)

## Coordinate di Blender (x, y, z) -> Godot (x, z, -y): qui tutto è scritto come in torre_proposte.py.
static func b(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)

## Per versione: luci e camere in coordinate di Blender.
## emergenza: lampeggianti rossi ai muri [pos, verso del muro]; lavoro: lampade calde [pos];
## lei: il centro del pozzo; scatti: nome -> [camera, punto guardato, campo visivo].
var VERSIONI := {
	# la seconda passata della A: tre GLB (struttura, scivoli, prop) e le luci in torre_A_luci.json
	"A": {
		"glb": ["torre_A_struttura", "torre_A_scivoli", "torre_A_prop"],
		"luci_json": "torre_A_luci",
		"scatti": {
			"1_cima": [b(27.3, 18.9, 1.75), b(34.5, 11.5, -4.0), 80.0],
			"2_meta": [b(34.4, 9.4, -4.25), b(27.0, 17.0, -13.0), 80.0],
			"3_fondo": [b(31.2, 10.9, -18.3), b(31.0, 16.5, 5.0), 84.0],
			"4_balconata": [b(29.0, 20.6, 0.9), b(31.0, 25.3, -0.9), 75.0],
		},
	},
	"A0": {
		"emergenza": [[b(20.9, 11.5, 3.2), Vector3.RIGHT], [b(39.6, 21.0, 1.0), Vector3.LEFT],
				[b(39.6, 9.5, -8.5), Vector3.LEFT], [b(20.9, 20.5, -11.0), Vector3.RIGHT],
				[b(30.0, 4.4, -15.0), Vector3.FORWARD], [b(35.0, 25.6, -17.5), Vector3.BACK]],
		"lavoro": [b(24.4, 17.2, 1.3), b(39.5, 13.6, -5.0), b(23.8, 16.4, -12.0), b(30.0, 24.6, -0.7)],
		"lei": b(31.0, 15.0, -20.0),
		# lampade industriali appese al soffitto nel vuoto centrale (lontane dagli scivoli e dai tubi), [pos, calda]
		"appese": [[b(29.2, 13.5, -3.0), true], [b(32.8, 16.8, -8.0), false], [b(31.5, 12.6, -12.0), true]],
		"scatti": {
			"1_cima": [b(25.6, 13.2, 1.7), b(36.0, 17.5, -3.0), 78.0],
			"2_meta": [b(36.6, 14.4, -4.6), b(26.0, 16.0, -14.0), 76.0],
			"3_fondo": [b(33.6, 9.2, -18.3), b(29.5, 17.5, -5.0), 80.0],
			"4_balconata": [b(37.6, 14.4, -4.6), b(30.0, 25.0, -1.4), 62.0],
		},
	},
}

var versione := "A"
var cartella := "user://torre"
var solo := PackedStringArray()
var radice: Node3D
var cam: Camera3D


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: versione = a[0]
	if a.size() > 1: cartella = a[1]
	if a.size() > 2: solo = a[2].split(",")
	DirAccess.make_dir_recursive_absolute(cartella)
	radice = Node3D.new()
	root.add_child(radice)
	var v: Dictionary = VERSIONI[versione]
	var acqua: Material = load("res://assets/materials/sala/acqua_torbida.tres")
	for nome in v.get("glb", ["torre_" + versione]):
		var glb: Node3D = (load("res://proposte/torre/%s.glb" % nome) as PackedScene).instantiate()
		radice.add_child(glb)
		for m in glb.find_children("acqua*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = acqua
	if v.has("luci_json"):
		_luci_da_json(JSON.parse_string(FileAccess.get_file_as_string("res://proposte/torre/%s.json" % v["luci_json"])))
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.012
	env.environment.ambient_light_energy = 1.0
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	radice.add_child(env)
	for e in v.get("emergenza", []):
		_emergenza(e[0], e[1])
	for p in v.get("lavoro", []):
		_lampada(p)
	if v.has("lei"):
		_lei(v["lei"])
	for ap in v.get("appese", []):
		_appesa(ap[0], ap[1])
	cam = Camera3D.new()
	radice.add_child(cam)
	cam.current = true
	_scatta.call_deferred(v["scatti"])


static func bv(a: Array) -> Vector3:
	return b(a[0], a[1], a[2])


func _luci_da_json(d: Dictionary) -> void:
	var versi := {"e": Vector3.RIGHT, "o": Vector3.LEFT, "n": Vector3.FORWARD, "s": Vector3.BACK}
	for e in d["emergenza"]:
		_emergenza(bv(e[0]), versi[e[1]])
	for p in d["lavoro"]:
		_lampada(bv(p))
	for f in d["fari"]:
		_faro(bv(f[0]), bv(f[1]))
	for g in d["gocce"]:
		_gocce(bv(g))
	_lei(bv(d["lei"]))
	_catena(bv(d["lei"]))


func _catena(fondo: Vector3) -> void:
	# una catena appesa al centro del soffitto con tre grappoli di lampade da cantiere (gabbie calde): illumina
	# il vuoto e gli scivoli tutt'intorno, così i colori si leggono anche lontano dai fari
	var cavo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	var basso := fondo.y + 6.0
	cm.height = 14.0 - basso
	cavo.mesh = cm
	var nero := StandardMaterial3D.new()
	nero.albedo_color = Color(0.06, 0.06, 0.06)
	nero.metallic = 0.8
	cavo.material_override = nero
	cavo.position = Vector3(fondo.x + 1.2, (14.0 + basso) / 2.0, fondo.z)
	radice.add_child(cavo)
	for y in [9.0, -3.0, basso]:
		for k in 3:
			var a := TAU * k / 3.0
			var p := Vector3(fondo.x + 1.2 + cos(a) * 0.35, y - 0.1 * k, fondo.z + sin(a) * 0.35)
			var bulbo := MeshInstance3D.new()
			var sf := SphereMesh.new()
			sf.radius = 0.08
			sf.height = 0.16
			bulbo.mesh = sf
			var m := StandardMaterial3D.new()
			m.emission_enabled = true
			m.emission = CALDO
			m.emission_energy_multiplier = 9.0
			bulbo.material_override = m
			bulbo.position = p
			radice.add_child(bulbo)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.62)
		l.light_energy = 6.0
		l.omni_range = 15.0
		l.omni_attenuation = 0.8
		l.shadow_enabled = true
		l.light_volumetric_fog_energy = 0.6
		l.position = Vector3(fondo.x + 1.2, y - 0.2, fondo.z)
		radice.add_child(l)


func _faro(p: Vector3, mira: Vector3) -> void:
	# faro da cantiere sul traliccio: scatola nera col vetro acceso, luce bianca calda verso gli scivoli di fronte
	var corpo := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.45, 0.35, 0.2)
	corpo.mesh = bx
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.08)
	corpo.material_override = m
	radice.add_child(corpo)
	corpo.position = p
	corpo.look_at(mira)
	var vetro := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.3)
	vetro.mesh = q
	var mv := StandardMaterial3D.new()
	mv.emission_enabled = true
	mv.emission = Color(1.0, 0.9, 0.75)
	mv.emission_energy_multiplier = 12.0
	vetro.material_override = mv
	corpo.add_child(vetro)
	vetro.position = Vector3(0, 0, -0.11)
	vetro.rotation_degrees = Vector3(0, 180, 0)
	var l := SpotLight3D.new()
	l.light_color = Color(1.0, 0.88, 0.72)
	l.light_energy = 16.0
	l.spot_range = 30.0
	l.spot_angle = 24.0
	l.spot_attenuation = 0.6
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 0.8
	radice.add_child(l)
	l.position = p
	l.look_at(mira)


func _gocce(p: Vector3) -> void:
	# acqua che gocciola dalla bocca di uno scivolo
	var g := CPUParticles3D.new()
	var sf := SphereMesh.new()
	sf.radius = 0.012
	sf.height = 0.05
	g.mesh = sf
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.8, 0.85, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	g.material_override = m
	g.amount = 40
	g.lifetime = 2.0
	g.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	g.emission_box_extents = Vector3(0.3, 0.02, 0.3)
	g.direction = Vector3.DOWN
	g.initial_velocity_min = 0.2
	g.initial_velocity_max = 0.6
	g.gravity = Vector3(0, -9.8, 0)
	g.position = p
	radice.add_child(g)


func _emergenza(p: Vector3, verso: Vector3) -> void:
	# la plafoniera rossa a gabbia sul muro e la sua luce
	var corpo := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.16, 0.3, 0.3) if absf(verso.x) > 0.5 else Vector3(0.3, 0.3, 0.16)
	corpo.mesh = bx
	var m := StandardMaterial3D.new()
	m.albedo_color = ROSSO
	m.emission_enabled = true
	m.emission = ROSSO
	m.emission_energy_multiplier = 6.0
	corpo.material_override = m
	corpo.position = p
	radice.add_child(corpo)
	var l := OmniLight3D.new()
	l.light_color = ROSSO
	l.light_energy = 3.5
	l.omni_range = 7.5
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 1.5
	l.position = p + verso * 0.4
	radice.add_child(l)


func _appesa(p: Vector3, calda: bool) -> void:
	# cavo dal soffitto (14 m), paralume a cono smaltato e lampadina; luce calda (sodio) o fredda (neon)
	var col := CALDO if calda else Color(0.78, 1.0, 0.9)
	var cavo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 14.0 - p.y
	cavo.mesh = cm
	var nero := StandardMaterial3D.new()
	nero.albedo_color = Color(0.05, 0.05, 0.05)
	cavo.material_override = nero
	cavo.position = Vector3(p.x, (14.0 + p.y) / 2.0, p.z)
	radice.add_child(cavo)
	var par := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.08
	cono.bottom_radius = 0.32
	cono.height = 0.22
	par.mesh = cono
	var smalto := StandardMaterial3D.new()
	smalto.albedo_color = Color(0.18, 0.32, 0.26)
	smalto.metallic = 0.6
	smalto.roughness = 0.45
	par.material_override = smalto
	par.position = p
	radice.add_child(par)
	var bulbo := MeshInstance3D.new()
	var sf := SphereMesh.new()
	sf.radius = 0.07
	sf.height = 0.14
	bulbo.mesh = sf
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 10.0
	bulbo.material_override = m
	bulbo.position = p + Vector3(0, -0.1, 0)
	radice.add_child(bulbo)
	var l := SpotLight3D.new()
	l.light_color = col
	l.light_energy = 24.0
	l.spot_range = 24.0
	l.spot_angle = 62.0
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 1.2
	l.position = p + Vector3(0, -0.15, 0)
	l.rotation_degrees = Vector3(-90, 0, 0)
	radice.add_child(l)
	var o := OmniLight3D.new()
	o.light_color = col
	o.light_energy = 3.0
	o.omni_range = 12.0
	o.position = p + Vector3(0, -0.25, 0)
	radice.add_child(o)


func _lampada(p: Vector3) -> void:
	# lampada da lavoro a gabbia, legata alla ringhiera: luce calda che scende sulla pedana
	var bulbo := MeshInstance3D.new()
	var sf := SphereMesh.new()
	sf.radius = 0.09
	sf.height = 0.18
	bulbo.mesh = sf
	var m := StandardMaterial3D.new()
	m.albedo_color = CALDO
	m.emission_enabled = true
	m.emission = CALDO
	m.emission_energy_multiplier = 8.0
	bulbo.material_override = m
	bulbo.position = p
	radice.add_child(bulbo)
	var l := OmniLight3D.new()
	l.light_color = CALDO
	l.light_energy = 4.0
	l.omni_range = 8.0
	l.shadow_enabled = true
	l.position = p + Vector3(0, -0.15, 0)
	radice.add_child(l)


func _lei(p: Vector3) -> void:
	# la luce di lei sale dal pozzo: un fondo rosa acceso giù nel buio e un fascio verso l'alto
	var fondo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 1.7
	cil.bottom_radius = 1.7
	cil.height = 0.05
	fondo.mesh = cil
	var m := StandardMaterial3D.new()
	m.albedo_color = ROSA
	m.emission_enabled = true
	m.emission = ROSA
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fondo.material_override = m
	fondo.position = p + Vector3(0, -5.0, 0)
	radice.add_child(fondo)
	var o := OmniLight3D.new()
	o.light_color = ROSA
	o.light_energy = 14.0
	o.omni_range = 10.0
	o.light_volumetric_fog_energy = 3.0
	o.position = p + Vector3(0, -0.8, 0)
	radice.add_child(o)
	var s := SpotLight3D.new()
	s.light_color = ROSA
	s.light_energy = 22.0
	s.spot_range = 30.0
	s.spot_angle = 16.0
	s.shadow_enabled = true
	s.light_volumetric_fog_energy = 4.0
	s.position = p + Vector3(0, -2.5, 0)
	var dentro := OmniLight3D.new()
	dentro.light_color = ROSA
	dentro.light_energy = 10.0
	dentro.omni_range = 4.0
	dentro.position = p + Vector3(0, -3.5, 0)
	radice.add_child(dentro)
	s.rotation_degrees = Vector3(90, 0, 0)
	radice.add_child(s)


func _scatta(scatti: Dictionary) -> void:
	for nome in scatti:
		if solo.size() and not solo.has(nome):
			continue
		var s: Array = scatti[nome]
		cam.fov = s[2]
		cam.position = s[0]
		cam.look_at(s[1])
		for i in 90:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_jpg(cartella.path_join("torre_%s_%s.jpg" % [versione, nome]), 0.92)
		print("scatto ", nome)
	OS.kill(OS.get_process_id())
