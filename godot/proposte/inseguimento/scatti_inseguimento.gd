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
## Con "video" al posto degli scatti (e --write-movie file.avi --fixed-fps 24) la camera percorre la strada
## (inseguimento_<v>_percorso.json) dalla bocca all'uscita, con lei nelle sue pose.
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
		"spirale": b(60.0, 4.5, -30.0),
		# fari da cantiere sulle ringhiere delle passerelle: [posizione, dove puntano]
		"fari": [[b(48.0, 0.7, -18.8), b(50.5, 15.0, -22.6)], [b(60.0, 29.9, -22.8), b(65.5, 27.7, -25.6)],
				[b(76.5, 0.7, -18.8), b(69.5, 5.0, -28.6)], [b(43.0, 0.7, -18.8), b(46.5, 6.0, -33.4)]],
		# la scia rosa: la bava che lei ha lasciato sul bordo della vasca 1, dalla parte da cui arriva
		# [punti, appoggiata (falso: in verticale giù per il muro)]
		"bava": [[[b(53.5, 17.91, -21.49), b(50.09, 17.91, -21.49), b(50.09, 15.9, -21.49)], true],
				[[b(49.96, 17.5, -21.5), b(49.96, 17.6, -22.3), b(49.96, 17.4, -22.95)], false]],
		"1_primo_bivio": [b(50.9, 17.4, -20.55), b(56.5, 12.6, -22.6), 78.0, []],
		"2_lei_ti_raggiunge": [b(54.3, 12.9, -20.7), b(48.6, 17.6, -22.4), 52.0, [0]],
		"3_secondo_bivio": [b(65.5, 29.6, -23.8), b(65.5, 25.0, -24.2), 76.0, []],
		"4_grata": [b(44.6, 4.6, -32.3), b(51.0, 6.5, -32.4), 76.0, [2]],
		"5_sb1": [b(43.4, 4.4, -32.4), b(44.7, 9.0, -32.6), 66.0, [3]],
	},
	"B": {
		"fari": [[b(50.0, -3.9, -15.8), b(47.0, 15.0, -21.2)], [b(64.0, -3.9, -15.8), b(65.0, 22.6, -22.2)],
				[b(74.0, -3.9, -15.8), b(72.5, 9.0, -26.3)], [b(45.0, -3.9, -15.8), b(47.8, 0.0, -35.0)]],
		"1_partenza": [b(45.2, 14.4, -19.5), b(56.0, 15.6, -18.9), 74.0, []],
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
	dati = JSON.parse_string(FileAccess.get_file_as_string("res://proposte/inseguimento/inseguimento_%s_luci.json" % versione))
	var schiuma := _materiale_schiuma()
	for parte in ["struttura", "tubi", "prop"]:
		var glb: Node3D = (load("res://proposte/inseguimento/inseguimento_%s_%s.glb" % [versione, parte]) as PackedScene).instantiate()
		radice.add_child(glb)
		for m in glb.find_children("acqua*", "MeshInstance3D", true, false):
			# l'acqua bianca delle rapide nel canale, l'acqua torbida altrove
			(m as MeshInstance3D).material_override = schiuma if dati.get("schiuma", []).has(String(m.name)) else acqua
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.009
	env.environment.ambient_light_energy = 1.0
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	radice.add_child(env)
	_luci()
	for L in dati["lei"]:
		lei.append(_medusa(L))
	cam = Camera3D.new()
	radice.add_child(cam)
	cam.current = true
	if solo.has("video"):
		_video.call_deferred()
	else:
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
	for a in dati.get("arredi", []):
		_arredo(a)
	var soffitto: float = dati["info"]["limiti"][5]
	for ap in dati.get("appese", []):
		_appesa(bv(ap), ap[3], soffitto)
	for ne in dati.get("neon", []):
		_neon(bv(ne))
	for la in dati.get("lanterne", []):
		_lanterna(bv(la))
	for fa in dati.get("fari", []):
		_faro(bv(fa[0]), bv(fa[1]), Color(fa[2][0], fa[2][1], fa[2][2]) if fa.size() > 2 else Color(1.0, 0.88, 0.72))


var _fonti := {}


## Un oggetto vero del gioco (vedi arredo() in tools/blender/inseguimento_proposte.py): un nodo della sala
## pompe o del kit di dettagli, copiato e messo al suo posto.
func _arredo(a: Dictionary) -> void:
	var fonte: String = a["f"]
	if not _fonti.has(fonte):
		var percorso := "res://assets/ambienti_tecnici/sala_pompe.gltf" if fonte == "pompe" \
				else "res://assets/ambiente/dettagli/gltf/%s.gltf" % fonte.get_slice("/", 1)
		var sc: Node3D = (load(percorso) as PackedScene).instantiate()
		add_child(sc)
		sc.visible = false
		_fonti[fonte] = sc
	var src: Node3D = _fonti[fonte]
	var nomi: Array = a["n"] if a["n"] is Array else [a["n"]]
	var gruppo := Node3D.new()
	radice.add_child(gruppo)
	var scatola := AABB()
	var prima := true
	for nome in nomi:
		var n := src.find_child(nome, true, false) as Node3D
		if n == null:
			push_warning("arredo mancante: %s" % nome)
			continue
		var copia := n.duplicate() as Node3D
		gruppo.add_child(copia)
		copia.transform = src.global_transform.affine_inverse() * n.global_transform
		if String(a["a"]) == "origine":
			# i nodi del kit nel loro GLB sono messi in fila: conta solo l'origine del nodo
			copia.transform.origin = Vector3.ZERO
		for m in [copia] + copia.find_children("*", "MeshInstance3D", true, false):
			if m is MeshInstance3D:
				var ab: AABB = copia.transform * ((m as MeshInstance3D).get_aabb()) if m == copia \
						else copia.transform * ((m as MeshInstance3D).transform * (m as MeshInstance3D).get_aabb())
				scatola = ab if prima else scatola.merge(ab)
				prima = false
	var giro := Basis(Vector3.UP, deg_to_rad(float(a["ry"]))).scaled(Vector3.ONE * float(a.get("s", 1.0)))
	var p := bv(a["p"])
	match String(a["a"]):
		"origine":
			gruppo.transform = Transform3D(giro, p)
		_:
			# la scatola girata: il centro del fondo sul punto (o contro il muro)
			var sg := Transform3D(giro, Vector3.ZERO) * scatola
			var fondo := Vector3(sg.get_center().x, sg.position.y, sg.get_center().z)
			var t := p - fondo
			if String(a["a"]) == "muro" and a["nrm"] != null:
				var nrm := Vector3(a["nrm"][0], 0.0, -float(a["nrm"][1])).normalized()
				t += nrm * (absf(nrm.x) * sg.size.x + absf(nrm.z) * sg.size.z) * 0.5
			gruppo.transform = Transform3D(giro, t)


## Lampada industriale appesa al soffitto: cavo, paralume smaltato, lampadina; calda (sodio) o fredda.
func _appesa(p: Vector3, calda: bool, soffitto: float) -> void:
	var col := CALDO if calda else Color(0.8, 1.0, 0.92)
	var cavo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = soffitto - p.y
	cavo.mesh = cm
	var nero := StandardMaterial3D.new()
	nero.albedo_color = Color(0.05, 0.05, 0.05)
	cavo.material_override = nero
	cavo.position = Vector3(p.x, (soffitto + p.y) / 2.0, p.z)
	radice.add_child(cavo)
	var par := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.08
	cono.bottom_radius = 0.34
	cono.height = 0.24
	par.mesh = cono
	var smalto := StandardMaterial3D.new()
	smalto.albedo_color = Color(0.16, 0.3, 0.24)
	smalto.metallic = 0.6
	smalto.roughness = 0.45
	par.material_override = smalto
	par.position = p
	radice.add_child(par)
	_bulbo(p + Vector3(0, -0.1, 0), col, 0.07, 10.0)
	var l := SpotLight3D.new()
	l.light_color = col
	l.light_energy = 26.0
	l.spot_range = 26.0
	l.spot_angle = 64.0
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 1.2
	l.position = p + Vector3(0, -0.15, 0)
	l.rotation_degrees = Vector3(-90, 0, 0)
	radice.add_child(l)
	var o := OmniLight3D.new()
	o.light_color = col
	o.light_energy = 3.0
	o.omni_range = 12.0
	o.position = p + Vector3(0, -0.3, 0)
	radice.add_child(o)


## Plafoniera al neon (sotto un braccio o un balcone): la scatola col diffusore acceso e la sua luce.
func _neon(p: Vector3) -> void:
	var corpo := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(1.25, 0.09, 0.2)
	corpo.mesh = bx
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.95, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.85, 1.0, 0.95)
	m.emission_energy_multiplier = 5.0
	corpo.material_override = m
	corpo.position = p
	radice.add_child(corpo)
	var l := OmniLight3D.new()
	l.light_color = Color(0.85, 1.0, 0.95)
	l.light_energy = 3.5
	l.omni_range = 9.0
	l.shadow_enabled = true
	l.position = p + Vector3(0, -0.3, 0)
	radice.add_child(l)


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
func _faro(p: Vector3, mira: Vector3, col := Color(1.0, 0.88, 0.72)) -> void:
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
	mv.emission = col
	var l := SpotLight3D.new()
	l.light_color = col
	l.light_energy = 18.0
	l.spot_range = 40.0
	l.spot_angle = 20.0
	l.spot_attenuation = 0.5
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 0.8
	radice.add_child(l)
	l.position = p
	l.look_at(mira)


## Il lampioncino del percorso sulla sponda (il palo e la gabbia sono nel GLB): la luce calda che fa leggere
## il canale al buio.
func _lanterna(p: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = 2.2
	l.omni_range = 6.0
	l.omni_attenuation = 1.2
	l.light_volumetric_fog_energy = 0.8
	l.position = p
	radice.add_child(l)


## L'acqua bianca delle rapide: schiuma che corre, a strisce e a chiazze, un po' luminosa per leggersi al buio.
func _materiale_schiuma() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
float rumore(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
varying vec3 mondo;
void vertex() {
	mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += 0.05 * sin(mondo.x * 3.1 + TIME * 4.0) * cos(mondo.z * 2.7 + TIME * 3.3);
}
void fragment() {
	vec2 q = mondo.xz * 2.4;
	float n = rumore(q * 1.3 + vec2(TIME * 0.7, TIME * 1.1)) * 0.55 + rumore(q * 3.7 - vec2(TIME * 1.6, TIME * 0.4)) * 0.3
		+ rumore(q * 9.0 + TIME * 2.0) * 0.15;
	float bianco = smoothstep(0.5, 0.78, n) * 0.85 + smoothstep(0.62, 0.66, n) * 0.15;
	vec3 acqua = vec3(0.05, 0.22, 0.24);
	ALBEDO = mix(acqua, vec3(0.92, 0.97, 0.98), bianco);
	ROUGHNESS = mix(0.08, 0.7, bianco);
	EMISSION = vec3(0.12, 0.18, 0.2) * bianco;
	NORMAL_MAP = normalize(vec3(rumore(q * 5.0 + TIME) - 0.5, rumore(q * 5.0 - TIME) - 0.5, 1.0)) * 0.5 + 0.5;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


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
		if nome in ["fari", "bava", "spirale"]:
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


## Il video del percorso: la camera segue la strada 3 m dietro e 2 m sopra chi scivola (fuori dai tubi chiusi),
## guardando qualche metro avanti; lei è in tutte le sue pose, girata verso la camera.
func _video() -> void:
	var pp: Array = JSON.parse_string(FileAccess.get_file_as_string("res://proposte/inseguimento/inseguimento_%s_percorso.json" % versione))
	var punti := PackedVector3Array()
	for q in pp:
		var su := 0.25 if String(q["cosa"]) in ["tubo", "canale"] else 1.6
		var p := b(q["x"], q["y"], q["z"] + su)
		if punti.is_empty() or punti[punti.size() - 1].distance_to(p) > 0.3:
			punti.append(p)
	# lunghezze lungo il percorso
	var lung := PackedFloat32Array([0.0])
	for i in range(1, punti.size()):
		lung.append(lung[i - 1] + punti[i].distance_to(punti[i - 1]))
	var tot := lung[lung.size() - 1]
	var dove := func(s_: float) -> Vector3:
		s_ = clampf(s_, 0.0, tot)
		var i := 1
		while i < lung.size() - 1 and lung[i] < s_:
			i += 1
		var t := (s_ - lung[i - 1]) / maxf(lung[i] - lung[i - 1], 0.001)
		return punti[i - 1].lerp(punti[i], t)
	for m in lei:
		m.visible = true
	cam.fov = 78.0
	var vel := 4.5
	var s_ := 5.0       # la bocca è dentro il muro della torre: si parte poco dopo
	var guarda: Vector3 = dove.call(9.0)
	cam.position = dove.call(0.0) + Vector3(0, 2.0, 0)
	while s_ < tot:
		s_ += vel / 24.0
		# un poco dietro e sopra chi scivola: fuori dai tubi chiusi, così si vede la sala
		var p: Vector3 = dove.call(s_ - 3.0) + Vector3(0, 2.0, 0)
		if VERSIONI[versione].has("spirale"):
			# attorno al serbatoio la spirale ha i giri uno sopra l'altro: la camera sta di fuori, di lato
			var cs: Vector3 = VERSIONI[versione]["spirale"]
			var r := Vector3(p.x - cs.x, 0, p.z - cs.z)
			if r.length() < 6.5 and p.y < -26.0:
				p = dove.call(s_ - 1.5) + r.normalized() * 2.8 + Vector3(0, 0.4, 0)
		cam.position = cam.position.lerp(p, 0.5)
		guarda = guarda.lerp(dove.call(s_ + 5.0), 0.12)
		if guarda.distance_to(cam.position) > 0.2:
			cam.look_at(guarda)
		for m in lei:
			var d := cam.position - m.position
			m.rotation = Vector3(0, atan2(d.x, d.z), 0)
		await get_tree().process_frame
	# l'ultima immagine: SB1, ferma due secondi verso lei che sbuca
	var sb1 := lei[lei.size() - 1]
	for i in 48:
		cam.look_at(sb1.position + Vector3(0, 0.8, 0))
		await get_tree().process_frame
	get_tree().quit()
