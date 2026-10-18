extends Node
## Scatti delle proposte per l'inseguimento I1 e il finale SB1 (fuori dal gioco: proposte/ non va nell'export).
## Carica proposte/inseguimento/inseguimento_<v>_{struttura,tubi,prop}.glb (tools/blender/inseguimento_proposte.py),
## l'acqua torbida sui piani "acqua_*", le luci di inseguimento_<v>_luci.json (niente torcia: rosse d'emergenza,
## lampade da lavoro calde, la lampada verde sopra la paratia giusta e la rossa guasta sopra la sbagliata, che
## illuminano il loro bersaglio, la verde dell'uscita) e lei, la medusa vera, nelle pose di luci["lei"], col suo
## bagliore rosa. Ogni scatto mostra solo le pose di lei che gli servono, girate verso la camera.
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --resolution 1600x900 \
##        --script res://tests/run.gd -- res://proposte/inseguimento/scatti_inseguimento.gd <versione> <cartella> [scatti]
## (con run.gd perché la medusa usa l'autoload GameState)

const ROSSO := Color(1.0, 0.035, 0.02)
const CALDO := Color(1.0, 0.66, 0.36)
const ROSA := Color(1.0, 0.32, 0.62)
const VERDE := Color(0.25, 1.0, 0.45)

## Coordinate di Blender (x, y, z) -> Godot (x, z, -y).
static func b(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)

## Per versione, gli scatti: nome -> [camera, punto guardato, campo visivo, pose di lei visibili].
var VERSIONI := {
	"A": {
		# fari da cantiere sulle ringhiere delle passerelle: [posizione, dove puntano]
		"fari": [[b(48.0, 0.7, -18.8), b(50.5, 15.0, -22.6)], [b(60.0, 29.9, -22.8), b(65.5, 27.7, -25.6)],
				[b(76.5, 0.7, -18.8), b(69.5, 5.0, -28.6)], [b(43.0, 0.7, -18.8), b(46.5, 6.0, -33.4)]],
		# la scia rosa: la bava che lei ha lasciato sul bordo della vasca 1, dalla parte da cui arriva
		# [punti, appoggiata (falso: in verticale giù per il muro)]
		"bava": [[[b(53.5, 17.91, -21.49), b(50.09, 17.91, -21.49), b(50.09, 15.9, -21.49)], true],
				[[b(49.96, 17.5, -21.5), b(49.96, 17.6, -22.3), b(49.96, 17.4, -22.95)], false]],
		"1_primo_bivio": [b(51.0, 15.0, -20.6), b(55.0, 15.0, -20.4), 74.0, []],
		"2_lei_ti_raggiunge": [b(54.3, 12.9, -20.7), b(48.6, 17.6, -22.4), 52.0, [0]],
		"3_secondo_bivio": [b(65.5, 29.6, -23.8), b(65.5, 25.0, -24.2), 76.0, []],
		"4_grata": [b(44.6, 4.6, -32.3), b(51.0, 6.5, -32.4), 76.0, [2]],
		"5_sb1": [b(43.4, 4.4, -32.4), b(44.7, 9.0, -32.6), 66.0, [3]],
	},
	"B": {
		"fari": [[b(50.0, -3.9, -15.8), b(47.0, 15.0, -21.2)], [b(64.0, -3.9, -15.8), b(65.0, 22.6, -22.2)],
				[b(74.0, -3.9, -15.8), b(72.5, 9.0, -26.3)], [b(45.0, -3.9, -15.8), b(47.8, 0.0, -35.0)]],
		"1_rapide": [b(54.3, 15.1, -19.9), b(64.5, 22.3, -21.4), 72.0, []],
		"2_lei_ti_raggiunge": [b(63.0, 21.6, -20.5), b(57.0, 17.0, -23.0), 74.0, [0]],
		"3_bivio_2": [b(76.6, 12.0, -24.0), b(70.0, 9.0, -25.8), 76.0, [1]],
		"4_grata": [b(44.0, 0.9, -34.1), b(45.2, 4.6, -32.4), 76.0, [2]],
		"5_sb1": [b(41.4, -2.2, -30.95), b(45.9, -1.9, -33.8), 66.0, [3]],
	},
}

var versione := "A"
var cartella := "user://inseguimento"
var solo := PackedStringArray()
var radice: Node3D
var cam: Camera3D
var lei: Array[Node3D] = []
var dati: Dictionary


func _ready() -> void:
	var a := OS.get_cmdline_user_args().slice(1)
	if a.size() > 0: versione = a[0]
	if a.size() > 1: cartella = a[1]
	if a.size() > 2: solo = a[2].split(",")
	DirAccess.make_dir_recursive_absolute(cartella)
	radice = Node3D.new()
	add_child(radice)
	var acqua: Material = load("res://assets/materials/sala/acqua_torbida.tres")
	for parte in ["struttura", "tubi", "prop"]:
		var glb: Node3D = (load("res://proposte/inseguimento/inseguimento_%s_%s.glb" % [versione, parte]) as PackedScene).instantiate()
		radice.add_child(glb)
		for m in glb.find_children("acqua*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = acqua
	dati = JSON.parse_string(FileAccess.get_file_as_string("res://proposte/inseguimento/inseguimento_%s_luci.json" % versione))
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.014
	env.environment.ambient_light_energy = 1.0
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	radice.add_child(env)
	_luci()
	for L in dati["lei"]:
		lei.append(_medusa(L))
	cam = Camera3D.new()
	radice.add_child(cam)
	cam.current = true
	_scatta.call_deferred(VERSIONI[versione])
	for f in VERSIONI[versione].get("fari", []):
		_faro(f[0], f[1])
	for bv_ in VERSIONI[versione].get("bava", []):
		var bava := BavaRosa.new()
		bava.punti = PackedVector3Array(bv_[0])
		bava.larghezza = 0.2
		bava.emissione = 2.5
		bava.opacita = 0.9
		bava.appoggia = false
		radice.add_child(bava)


static func bv(a: Array) -> Vector3:
	return b(a[0], a[1], a[2])


func _luci() -> void:
	for e in dati["emergenza"]:
		_emergenza(bv(e))
	for p in dati["lavoro"]:
		_lampada(bv(p))
	for i in dati["paratie"].size():
		var pa: Array = dati["paratie"][i]
		_paratia(bv(pa[0]), pa[1] == "verde", bv(dati["bersagli"][i]), bv(pa[2]))
	for u in dati["uscita"]:
		_uscita(bv(u))


## Il bulbo acceso e la sua luce.
func _bulbo(p: Vector3, col: Color, r: float, forza: float) -> void:
	var bulbo := MeshInstance3D.new()
	var sf := SphereMesh.new()
	sf.radius = r
	sf.height = r * 2.0
	bulbo.mesh = sf
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = forza
	bulbo.material_override = m
	bulbo.position = p
	radice.add_child(bulbo)


func _emergenza(p: Vector3) -> void:
	_bulbo(p, ROSSO, 0.14, 6.0)
	var l := OmniLight3D.new()
	l.light_color = ROSSO
	l.light_energy = 3.5
	l.omni_range = 8.0
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 1.5
	l.position = p
	radice.add_child(l)


func _lampada(p: Vector3) -> void:
	_bulbo(p, CALDO, 0.09, 8.0)
	var l := OmniLight3D.new()
	l.light_color = CALDO
	l.light_energy = 4.0
	l.omni_range = 8.0
	l.shadow_enabled = true
	l.position = p + Vector3(0, -0.15, 0)
	radice.add_child(l)


## La lampada sopra la paratia: verde sulla giusta (fascio pieno sul bersaglio), rossa e debole sulla sbagliata.
## Così al buio il bersaglio da colpire è il cerchio giallo illuminato di verde.
func _paratia(p: Vector3, giusta: bool, bersaglio: Vector3, verso: Vector3) -> void:
	var col := VERDE if giusta else ROSSO
	_bulbo(p, col, 0.1, 9.0 if giusta else 4.0)
	var o := OmniLight3D.new()
	o.light_color = col
	o.light_energy = 2.0 if giusta else 1.0
	o.omni_range = 4.5
	o.position = p
	radice.add_child(o)
	var s := SpotLight3D.new()
	s.light_color = col
	s.light_energy = 14.0 if giusta else 2.5
	s.spot_range = 6.0
	s.spot_angle = 22.0
	s.shadow_enabled = true
	s.light_volumetric_fog_energy = 2.0
	radice.add_child(s)
	s.position = p
	s.look_at(bersaglio)
	if giusta:
		# l'anello di led verdi attorno al bersaglio della giusta: al buio si vede anche da lontano
		var anello := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.47
		t.outer_radius = 0.55
		t.rings = 48
		anello.mesh = t
		var m := StandardMaterial3D.new()
		m.albedo_color = VERDE
		m.emission_enabled = true
		m.emission = VERDE
		m.emission_energy_multiplier = 6.0
		anello.material_override = m
		radice.add_child(anello)
		anello.position = bersaglio + verso * 0.02
		# il toro sta nel piano XZ: il suo asse Y va lungo il verso della paratia
		anello.basis = Basis(Quaternion(Vector3.UP, verso.normalized()))
		var o2 := OmniLight3D.new()
		o2.light_color = VERDE
		o2.light_energy = 1.5
		o2.omni_range = 3.0
		o2.position = bersaglio + verso * 0.6
		radice.add_child(o2)


func _uscita(p: Vector3) -> void:
	_bulbo(p, VERDE, 0.12, 8.0)
	var l := OmniLight3D.new()
	l.light_color = VERDE
	l.light_energy = 3.0
	l.omni_range = 7.0
	l.position = p + Vector3(0.4, -0.3, 0)
	radice.add_child(l)


## Faro da cantiere legato alla ringhiera: scatola nera col vetro acceso, luce bianca calda.
func _faro(p: Vector3, mira: Vector3) -> void:
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
	l.light_energy = 18.0
	l.spot_range = 40.0
	l.spot_angle = 20.0
	l.spot_attenuation = 0.5
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 0.8
	radice.add_child(l)
	l.position = p
	l.look_at(mira)


## Lei, la medusa vera (stessi materiali della sala grande), col bagliore rosa che si vede da lontano.
func _medusa(L: Array) -> Node3D:
	var m := MedusaAffacciata.new()
	m.model = load("res://assets/models/medusa/medusa.glb")
	m.bell_material = load("res://assets/models/medusa/medusa_campana.tres")
	m.material_map = {
		"M_capelli": load("res://assets/models/medusa/medusa_capelli_bagnata.tres"),
		"M_ciocche": load("res://assets/models/medusa/medusa_ciocche_bagnata.tres"),
		"M_mani": load("res://assets/models/medusa/medusa_mani_bagnata.tres"),
		"M_occhio_bulbo": load("res://assets/models/medusa/medusa_occhio.tres"),
		"M_orbita": load("res://assets/models/medusa/medusa_orbita_bagnata.tres"),
		"M_pelle": load("res://assets/models/medusa/medusa_pelle_bagnata.tres"),
		"M_tentacoli": load("res://assets/models/medusa/medusa_tentacoli_bagnata.tres"),
	}
	m.animazione = StringName(L[4])
	m.position = bv(L)
	radice.add_child(m)
	var o := OmniLight3D.new()
	o.light_color = ROSA
	o.light_energy = 6.0
	o.omni_range = 9.0
	o.light_volumetric_fog_energy = 3.0
	o.shadow_enabled = true
	o.position = Vector3(0, 2.4, 0.9)
	m.add_child(o)
	m.visible = false
	return m


func _scatta(scatti: Dictionary) -> void:
	for nome in scatti:
		if nome in ["fari", "bava"]:
			continue
		if solo.size() and not solo.has(nome):
			continue
		var s: Array = scatti[nome]
		cam.fov = s[2]
		cam.position = s[0]
		cam.look_at(s[1])
		for i in lei.size():
			lei[i].visible = s[3].has(i)
			# girata verso chi la guarda
			var d := cam.position - lei[i].position
			lei[i].rotation = Vector3(0, atan2(d.x, d.z), 0)
		for i in 90:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_jpg(cartella.path_join("inseguimento_%s_%s.jpg" % [versione, nome]), 0.92)
		print("scatto ", nome)
	OS.kill(OS.get_process_id())
