extends Node3D
## La torre degli scivoli "da nuova", per lo spot VHS della crociera (GDD, "Lo spot della crociera Jubilee",
## inquadratura 4: la camera scende in un tubo della torre, con gli schizzi). Solo per lo spot: il gioco non la usa.
## - la struttura e gli scivoli del gioco (assets/ambiente/torre/), senza i prop (niente giocattoli, scelta
##   dell'utente) e senza i cancelli a strisce sulle bocche dei tubi: il giorno dell'apertura sono tutti aperti;
## - materiali puliti: niente sporco nei colori dei vertici, le texture pulite di ambienti-1 se ci sono
##   (res://assets/spot/texture/, stessi nomi senza il prefisso del GLB);
## - tutte le luci da lavoro e i fari accesi e bianchi, le rosse d'emergenza spente;
## - nel tubo [member tubo] l'acqua che scorre sul fondo (acqua_scivolo_spot.gdshader), gli schizzi intorno alla
##   camera e il getto all'uscita;
## - [method posa_camera] dà la camera a [param s] metri lungo la discesa (prima sulla pedana, poi dentro il tubo,
##   poi fuori, scivolando sulla pedana): la regia dello spot la muove con quella.
## Le linee dei tubi vengono da torre_proposte.py A --gioco (assets/spot/torre_scivoli_linee.json, coordinate di
## Blender: (x, y, z) diventa (x, z, -y), come in SalaTorre).

const DIR := "res://assets/ambiente/torre/"
const LINEE := "res://assets/spot/torre_scivoli_linee.json"
const TEXTURE_PULITE := "res://assets/spot/texture/"
const SHADER_ACQUA := preload("res://shaders/spot/acqua_scivolo_spot.gdshader")
const R_TUBO := 0.5
## I nodi del gioco che nella torre nuova non ci sono: i cancelli a strisce delle bocche chiuse, i led e le lampade
## rosse sopra i cancelli, lo sporco.
const TOGLI: Array[String] = ["cancell", "bocca_chiusa", "sporco", "colatur", "ruggine", "polaroid"]

## Il tubo della discesa dello spot (nome nel JSON delle linee).
@export var tubo := "torre_scivolo_6-col"
## Metri di pedana prima della bocca e di volo dopo l'uscita, nel percorso della camera.
@export var prima := 2.5
@export var dopo := 3.0
## Altezza della camera sul fondo del tubo (seduti nel tubo da 1 m).
@export var altezza_camera := 0.42
@export var crea_schizzi := true

var linea := PackedVector3Array()     ## la linea del centro del tubo, a passi di circa 0,15 m (Godot)
var _s := PackedFloat32Array()       ## metri lungo la linea
var _materiali := {}
var _texture := {}
var _schizzi_camera: GPUParticles3D


func _ready() -> void:
	var struttura: Node
	for nome in ["torre_struttura", "torre_scivoli"]:
		var glb := (load(DIR + nome + ".glb") as PackedScene).instantiate()
		add_child(glb)
		if nome == "torre_struttura":
			struttura = glb
		_pulisci(glb)
		if nome == "torre_struttura" and not OS.has_environment("SPOT_PROVA_GRATE"):
			_togli_grate(glb)
	_linea()
	_sgombra_tubo(struttura)
	_acqua()
	_luci()
	_luce_uscita()
	if crea_schizzi:
		_schizzi()


# --- pulizia -------------------------------------------------------------------------------------------------

func _pulisci(radice: Node) -> void:
	for n in radice.find_children("*", "", true, false):
		var nome := String(n.name).to_lower()
		for t in TOGLI:
			if nome.contains(t) and n is Node3D:
				(n as Node3D).visible = false
				if n is CollisionObject3D:
					(n as CollisionObject3D).process_mode = Node.PROCESS_MODE_DISABLED
	for n in radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var acqua := String(mi.name).begins_with("acqua")
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m == null:
				continue
			if not _materiali.has(m):
				_materiali[m] = _pulito(m, acqua)
			mi.set_surface_override_material(i, _materiali[m])


## Le grate tonde che nel gioco chiudono le bocche dei tubi decorativi (torre_a.py, chiusa_bocca: un anello rosso e
## sbarre d'acciaio, fusi nella mesh della struttura): il giorno dell'apertura i tubi sono aperti. Si tolgono i
## triangoli (tutti, tranne la vetroresina dei tubi) che stanno tutti nel disco della grata.
func _togli_grate(radice: Node) -> void:
	var dati: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "torre_gioco.json"))
	# il disco di ogni grata: centro e asse dalla linea del tubo più vicina (il tubo pende: l'asse non è orizzontale)
	var linee: Array = []
	for e in JSON.parse_string(FileAccess.get_file_as_string(LINEE)):
		var l := PackedVector3Array()
		for q in e["punti"]:
			l.append(SalaTorre.b(q))
		linee.append(l)
	var dischi: Array = []      # [centro, asse]
	for bc in dati["bocche_chiuse"]:
		if not bc["tubo"]:
			continue
		var p := Vector3(bc["pos"][0], float(bc["pos"][2]) + 0.55, -bc["pos"][1])
		var migliore := INF
		var disco := []
		for l in linee:
			for i in (l as PackedVector3Array).size() - 1:
				var c := Geometry3D.get_closest_point_to_segment(p, l[i], l[i + 1])
				if c.distance_to(p) < migliore:
					migliore = c.distance_to(p)
					disco = [c, (l[i + 1] - l[i]).normalized()]
		if migliore < 0.5:
			dischi.append(disco)
	var tolti := 0
	for n in radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mesh := mi.mesh as ArrayMesh
		if mesh == null:
			continue
		var nuova := ArrayMesh.new()
		var cambiata := false
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			var nome_m := String(m.resource_name).to_lower() if m else ""
			var arr := mesh.surface_get_arrays(i)
			# tutto tranne la vetroresina dei tubi (la grata, il suo anello e quel che la reggeva)
			if not nome_m.contains("tsc_") and arr[Mesh.ARRAY_INDEX] != null:
				var vert: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var tieni := PackedInt32Array()
				for t in range(0, idx.size(), 3):
					var dentro := false
					for d in dischi:
						if _nel_disco(mi.global_transform * vert[idx[t]], d) and _nel_disco(mi.global_transform * vert[idx[t + 1]], d) \
								and _nel_disco(mi.global_transform * vert[idx[t + 2]], d):
							dentro = true
							break
					if dentro:
						tolti += 1
					else:
						tieni.append_array([idx[t], idx[t + 1], idx[t + 2]])
				if tieni.size() != idx.size():
					cambiata = true
					arr[Mesh.ARRAY_INDEX] = tieni
			nuova.add_surface_from_arrays(mesh.surface_get_primitive_type(i), arr)
			nuova.surface_set_material(i, m)
			nuova.surface_set_name(i, mesh.surface_get_name(i))
		if cambiata:
			var over: Array = []
			for i in mesh.get_surface_count():
				over.append(mi.get_surface_override_material(i))
			mi.mesh = nuova
			for i in over.size():
				mi.set_surface_override_material(i, over[i])
	print("spot torre: triangoli delle grate tolti ", tolti)


## Dentro il tubo della discesa non c'è niente: si tolgono i triangoli della struttura (non la vetroresina) con i tre
## vertici a meno di 47 cm dalla linea del centro (la culla su cui il tubo poggia alla pedana, a fine tubo, entrava
## 6 cm sopra il fondo e si vedeva come un rettangolo contro la luce).
func _sgombra_tubo(radice: Node) -> void:
	var box := AABB(linea[0], Vector3.ZERO)
	for q in linea:
		box = box.expand(q)
	box = box.grow(0.6)
	var tolti := 0
	for n in radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mesh := mi.mesh as ArrayMesh
		if mesh == null or not (mi.global_transform * mesh.get_aabb()).intersects(box):
			continue
		var nuova := ArrayMesh.new()
		var cambiata := false
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			var arr := mesh.surface_get_arrays(i)
			if m and not String(m.resource_name).to_lower().contains("tsc_") and arr[Mesh.ARRAY_INDEX] != null:
				var vert: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var tieni := PackedInt32Array()
				for t in range(0, idx.size(), 3):
					if _nel_tubo(mi.global_transform * vert[idx[t]], box) and _nel_tubo(mi.global_transform * vert[idx[t + 1]], box) \
							and _nel_tubo(mi.global_transform * vert[idx[t + 2]], box):
						tolti += 1
					else:
						tieni.append_array([idx[t], idx[t + 1], idx[t + 2]])
				if tieni.size() != idx.size():
					cambiata = true
					arr[Mesh.ARRAY_INDEX] = tieni
			nuova.add_surface_from_arrays(mesh.surface_get_primitive_type(i), arr)
			nuova.surface_set_material(i, m)
		if cambiata:
			var over: Array = []
			for i in mesh.get_surface_count():
				over.append(mi.get_surface_override_material(i))
			mi.mesh = nuova
			for i in over.size():
				mi.set_surface_override_material(i, over[i])
	print("spot torre: triangoli dentro il tubo tolti ", tolti)


func _nel_tubo(q: Vector3, box: AABB) -> bool:
	if not box.has_point(q):
		return false
	for i in linea.size() - 1:
		if Geometry3D.get_closest_point_to_segment(q, linea[i], linea[i + 1]).distance_to(q) < R_TUBO - 0.03:
			return true
	return false


static func _nel_disco(q: Vector3, d: Array) -> bool:
	var c: Vector3 = d[0]
	var v: Vector3 = d[1]
	var r := q - c
	var lungo := r.dot(v)
	var lato := (r - v * lungo).length()
	return absf(lungo) < 0.15 and lato < 0.8


func _pulito(m: BaseMaterial3D, acqua: bool) -> BaseMaterial3D:
	var n := m.duplicate() as BaseMaterial3D
	n.vertex_color_use_as_albedo = false
	for prop in [&"albedo_texture", &"normal_texture", &"roughness_texture", &"metallic_texture", &"ao_texture"]:
		var t := n.get(prop) as Texture2D
		if t:
			n.set(prop, _texture_pulita(t))
	var nome := String(m.resource_name).to_lower().trim_prefix("m_amb_")
	if acqua:
		# le vasche di raccolta piene e chiare
		n.albedo_color = Color(0.45, 0.8, 0.92, 0.55)
		n.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		n.roughness = 0.05
		n.metallic = 0.0
	elif nome.begins_with("tsc_") or nome.begins_with("scivolo"):
		# la vetroresina nuova: lucida, e un po' di luce passa dalla parete (dentro il tubo non è buio)
		n.roughness = 0.18
		n.albedo_color = _vivo(n.albedo_color, n.albedo_texture)
		n.emission_enabled = true
		n.emission = n.albedo_color
		n.emission_texture = n.albedo_texture
		n.emission_energy_multiplier = 0.1
	# le lampade rosse d'emergenza spente: la torre è aperta, è giorno
	if n.emission_enabled and m.emission.r > 0.6 and m.emission.g < 0.3 and m.emission.b < 0.3:
		n.emission_enabled = false
	return n


## La vetroresina nuova ha i colori pieni: il colore medio della texture, più saturo, diventa la tinta del materiale.
static func _vivo(base: Color, tex: Texture2D) -> Color:
	if tex == null:
		return base
	var img := tex.get_image()
	if img == null:
		return base
	if img.is_compressed():
		img.decompress()
	img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	var medio := img.get_pixel(0, 0)
	var vivo := Color.from_hsv(medio.h, minf(medio.s * 2.2 + 0.15, 0.9), minf(medio.v, 0.95))
	# la tinta moltiplica la texture: si divide per il medio, così il risultato ha il colore vivo
	return Color(vivo.r / maxf(medio.r, 0.05), vivo.g / maxf(medio.g, 0.05), vivo.b / maxf(medio.b, 0.05)).clamp(Color.BLACK, Color(4, 4, 4))


func _texture_pulita(t: Texture2D) -> Texture2D:
	var file := t.resource_path.get_file()
	if file == "":
		return t
	if _texture.has(file):
		return _texture[file]
	var resto := file
	for g in ["torre_struttura_", "torre_scivoli_"]:
		if file.begins_with(g):
			resto = file.substr(g.length())
	var nuova := t
	if ResourceLoader.exists(TEXTURE_PULITE + resto):
		nuova = load(TEXTURE_PULITE + resto) as Texture2D
	_texture[file] = nuova
	return nuova


# --- luci ----------------------------------------------------------------------------------------------------

func _luci() -> void:
	var luci: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "torre_luci.json"))
	# le lampade da lavoro: luce piena e bianca su ogni piano
	for l in luci["lavoro"]:
		var o := OmniLight3D.new()
		o.position = SalaTorre.b(l) + Vector3(0, 0.3, 0)
		o.light_color = Color(1.0, 0.95, 0.86)
		o.light_energy = 3.0
		o.omni_range = 16.0
		o.shadow_enabled = true
		add_child(o)
	# i fari sui tralicci: puntati in basso verso il centro della torre
	for f in luci["fari"]:
		var p := SalaTorre.b(f[0] if f[0] is Array else f)
		var s := SpotLight3D.new()
		add_child(s)
		s.global_position = p
		s.look_at(Vector3(31.0, p.y - 8.0, -15.0) if absf(p.x - 31.0) > 0.5 else p + Vector3(0, -1, 0.01))
		s.light_color = Color(1.0, 0.97, 0.9)
		s.light_energy = 8.0
		s.spot_range = 30.0
		s.spot_angle = 40.0
		s.shadow_enabled = true


# --- il tubo e l'acqua ---------------------------------------------------------------------------------------

func _linea() -> void:
	var dati: Array = JSON.parse_string(FileAccess.get_file_as_string(LINEE))
	var p := PackedVector3Array()
	for e in dati:
		if e["nome"] == tubo:
			for q in e["punti"]:
				p.append(SalaTorre.b(q))
	assert(p.size() >= 2, "tubo dello spot non trovato: " + tubo)
	# Catmull-Rom come tubo_scivolo di ambiente_kit.py (passi di 0,3 m), poi a metà
	var e := PackedVector3Array([p[0] + (p[0] - p[1])]) + p + PackedVector3Array([p[-1] + (p[-1] - p[-2])])
	for i in range(1, e.size() - 2):
		var n := maxi(2, int(e[i].distance_to(e[i + 1]) / 0.15))
		for k in n:
			linea.append(_cr(e[i - 1], e[i], e[i + 1], e[i + 2], float(k) / n))
	linea.append(p[-1])
	_s.append(0.0)
	for i in range(1, linea.size()):
		_s.append(_s[-1] + linea[i].distance_to(linea[i - 1]))


static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


## Lunghezza del tubo (m).
func lunghezza() -> float:
	return _s[-1]


## Punto e tangente della linea del centro a [param s] metri dalla bocca (fuori dal tubo prosegue dritta).
func punto(s: float) -> Vector3:
	if s <= 0.0:
		return linea[0] + _tangente(0.0) * s
	if s >= _s[-1]:
		return linea[-1] + _tangente(_s[-1]) * (s - _s[-1])
	return _dentro(s)


func _tangente(s: float) -> Vector3:
	var a := clampf(s - 0.3, 0.0, _s[-1] - 0.6)
	return (_dentro(a + 0.6) - _dentro(a)).normalized()


func _dentro(s: float) -> Vector3:
	var i := clampi(_s.bsearch(s) - 1, 0, linea.size() - 2)
	return linea[i].lerp(linea[i + 1], clampf((s - _s[i]) / maxf(_s[i + 1] - _s[i], 1e-5), 0.0, 1.0))


## Il "giù" nel tubo a [param s]: il basso perpendicolare alla tangente (lì scorre l'acqua).
func _giu(s: float) -> Vector3:
	var t := _tangente(s)
	return (Vector3.DOWN - t * Vector3.DOWN.dot(t)).normalized()


## La camera di chi scende, a [param s] metri dalla bocca: da -[member prima] (sulla pedana, seduti davanti alla bocca)
## a lunghezza() + [member dopo] (fuori, sulla pedana d'arrivo). Guarda avanti lungo il tubo.
func posa_camera(s: float) -> Transform3D:
	var pos := punto(s) + _giu(s) * (R_TUBO - altezza_camera)
	var avanti := punto(s + 1.6) + _giu(s + 1.6) * (R_TUBO - altezza_camera - 0.05)
	return Transform3D.IDENTITY.looking_at(avanti - pos, Vector3.UP).translated(pos)


func _acqua() -> void:
	# un nastro sul fondo del tubo, largo 100 gradi, 1 cm sopra la parete interna
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const LATI := 8
	const MEZZO := deg_to_rad(50.0)
	var r := R_TUBO - 0.012
	# (finisce 40 cm prima della bocca: oltre, contro la luce in fondo, il bordo del nastro si vedeva come una ciotola)
	var n_acqua := _s.bsearch(lunghezza() - 0.4)
	for i in n_acqua:
		var t := _tangente(_s[i])
		var g := _giu(_s[i])
		var l := t.cross(g).normalized()
		for k in LATI + 1:
			var a := lerpf(-MEZZO, MEZZO, float(k) / LATI)
			st.set_uv(Vector2(float(k) / LATI, _s[i]))
			st.set_normal(-(g * cos(a) + l * sin(a)))
			st.add_vertex(linea[i] + (g * cos(a) + l * sin(a)) * r)
	for i in n_acqua - 1:
		for k in LATI:
			var a := i * (LATI + 1) + k
			var b := a + LATI + 1
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	var mi := MeshInstance3D.new()
	mi.name = "AcquaTubo"
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_ACQUA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## La luce in fondo al tubo: un disco bianco acceso appena fuori dalla bocca d'uscita (copre la pedana e la colonna
## che si vedrebbero; l'inquadratura finisce prima dello sbocco, sulla luce, scelta del coordinatore del 23 ottobre),
## e una luce che entra nel tubo e illumina gli ultimi metri.
func _luce_uscita() -> void:
	var fine := lunghezza()
	var t := _tangente(fine)
	var disco := MeshInstance3D.new()
	disco.name = "LuceUscita"
	var cm := CylinderMesh.new()
	cm.top_radius = R_TUBO + 0.2
	cm.bottom_radius = R_TUBO + 0.2
	cm.height = 0.002
	disco.mesh = cm
	var m := StandardMaterial3D.new()
	# (acceso davvero: l'emissione sopra la soglia del bagliore; con unshaded restava grigio)
	m.albedo_color = Color(0.0, 0.0, 0.0)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(1.0, 0.97, 0.9)
	m.emission_energy_multiplier = 9.0
	disco.material_override = m
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disco)
	# il cilindro ha l'asse Y: lo si gira lungo il tubo
	disco.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, t)), punto(fine - 0.03))
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.96, 0.88)
	o.light_energy = 6.0
	o.omni_range = 7.0
	add_child(o)
	o.global_position = punto(fine - 0.3)


# --- schizzi -------------------------------------------------------------------------------------------------

func _goccia() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.9, 0.97, 1.0, 0.75)
	m.albedo_texture = _tex_goccia()
	m.vertex_color_use_as_albedo = true
	q.material = m
	return q


func _tex_goccia() -> Texture2D:
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	g.gradient = gr
	g.width = 32
	g.height = 32
	return g


func _particelle(quante: int, vita: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = quante
	p.lifetime = vita
	p.draw_pass_1 = _goccia()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	return p


func _schizzi() -> void:
	# intorno alla camera: gocce che saltano dall'acqua del fondo e restano indietro (la camera le porta con sé
	# con [method segui_camera])
	_schizzi_camera = _particelle(220, 0.55)
	_schizzi_camera.name = "SchizziCamera"
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.28, 0.02, 0.5)
	pm.direction = Vector3(0, 1, 0.2)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	_schizzi_camera.process_material = pm
	_schizzi_camera.local_coords = false
	add_child(_schizzi_camera)
	# all'uscita: il getto che esce dal tubo e cade sulla pedana
	var uscita := _particelle(600, 0.9)
	uscita.name = "GettoUscita"
	var pu := ParticleProcessMaterial.new()
	pu.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pu.emission_sphere_radius = 0.25
	pu.direction = Vector3(0, 0, -1)
	pu.spread = 18.0
	pu.initial_velocity_min = 2.5
	pu.initial_velocity_max = 4.5
	pu.gravity = Vector3(0, -9.8, 0)
	pu.scale_min = 0.8
	pu.scale_max = 2.0
	uscita.process_material = pu
	add_child(uscita)
	var t := _tangente(lunghezza())
	uscita.global_transform = Transform3D.IDENTITY.looking_at(t, Vector3.UP).translated(
			punto(lunghezza()) + _giu(lunghezza()) * (R_TUBO - 0.12))


## Gli schizzi seguono la camera a [param s] metri dalla bocca (davanti a lei, sul fondo del tubo).
func segui_camera(s: float) -> void:
	if _schizzi_camera == null:
		return
	var a := clampf(s + 0.9, 0.0, lunghezza())
	_schizzi_camera.emitting = s > -0.3 and s < lunghezza()
	var t := _tangente(a)
	_schizzi_camera.global_transform = Transform3D.IDENTITY.looking_at(-t, Vector3.UP).translated(
			punto(a) + _giu(a) * (R_TUBO - 0.06))
