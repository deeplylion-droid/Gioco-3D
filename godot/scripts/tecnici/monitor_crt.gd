class_name MonitorCrt
extends Node
## Il vecchio monitor a tubo della sala pompe (tappa 6): prima del risveglio mostra la sala
## grande ripresa da una telecamera di sorveglianza anni '90 (la medusa è ancora lì), a bassa
## risoluzione, con le righe del tubo e la sovrimpressione di telecamera, data e ora che corre;
## dal blackout solo neve. Va a batteria: la sua luce resta anche al buio. Segue GameState.luci.
## L'immagine e la sovrimpressione si compongono in un piccolo SubViewport 2D (320 x 240), che
## lo shader del tubo (shaders/tecnici/crt.gdshader) mostra sullo schermo del modello.
## Lo schermo del glTF (SCHERMO_CRT) è un rettangolo piatto qualche centimetro davanti al vetro
## bombato del tubo: da vicino sembrava un foglio nero attaccato sul televisore (riscontro E5
## dell'utente). Al suo posto va [member schermo_sul_vetro], lo schermo che riempie il vetro dentro
## la cornice, che prepara il costruttore della sala con [method costruisci_schermo_sul_vetro]. Non la si calcola al
## caricamento: leggere le mesh dalla scheda video mentre la scena entra può bloccare il gioco
## (succedeva sul renderer Vulkan).

## La mesh dello schermo (SCHERMO_CRT del modello).
@export var schermo_path: NodePath
## Dove mettere la sua luce (empty LUCE_crt del modello).
@export var luce_path: NodePath
## Lo schermo appoggiato sul vetro bombato del televisore (costruisci_schermo_sul_vetro), nelle
## coordinate di SCHERMO_CRT. Vuoto = resta il rettangolo piatto del modello.
@export var schermo_sul_vetro: Mesh
## L'immagine della telecamera (uno scatto vero della sala, in 4:3).
@export var immagine: Texture2D
## Sovrimpressione: nome della telecamera, data e ora d'inizio (l'ora poi corre).
@export var telecamera := "CAM 3"
@export var data := "12-08-1997"
@export var ora_inizio := Vector3i(2, 47, 13)
@export var colore_luce := Color(0.62, 0.86, 0.95)
@export var energia_luce := 0.7

const LATO := Vector2i(320, 240)

## Quanti vertici dello schermo poggiano sul vetro del televisore (0 = è rimasto il rettangolo
## piatto del modello).
var vertici_sul_vetro := 0
var _materiale: ShaderMaterial
var _luce: OmniLight3D
var _vista: SubViewport
var _ora: Label
var _rec: Label
var _t := 0.0
var _secondi := 0.0
var _ultimo_secondo := -1


func _ready() -> void:
	_componi()
	var schermo := get_node_or_null(schermo_path) as MeshInstance3D
	if schermo:
		if schermo_sul_vetro:
			schermo.mesh = schermo_sul_vetro
			vertici_sul_vetro = int(schermo_sul_vetro.get_meta(&"vertici_sul_vetro", 0))
		_materiale = ShaderMaterial.new()
		_materiale.shader = preload("res://shaders/tecnici/crt.gdshader")
		if schermo_sul_vetro:
			_materiale.set_shader_parameter(&"raggio_angoli", schermo_sul_vetro.get_meta(&"raggio_uv", Vector2.ZERO))
		_materiale.set_shader_parameter(&"immagine", _vista.get_texture())
		schermo.material_override = _materiale
	var punto := get_node_or_null(luce_path) as Node3D
	if punto:
		_luce = OmniLight3D.new()
		_luce.name = "LuceMonitor"
		_luce.light_color = colore_luce
		_luce.light_energy = energia_luce
		_luce.omni_range = 2.6
		_luce.omni_attenuation = 1.4
		_luce.shadow_enabled = false
		_luce.light_volumetric_fog_energy = 0.3
		# Va a batteria: il blackout non la spegne.
		_luce.set_meta(&"risveglio_ignora", true)
		add_child(_luce)
		_luce.global_position = punto.global_position
	_secondi = ora_inizio.x * 3600.0 + ora_inizio.y * 60.0 + ora_inizio.z
	GameState.luci_cambiate.connect(_applica)
	_applica(GameState.luci)


## Lo schermo che riempie il vetro del televisore [param modello] dentro la cornice: si tirano raggi
## su una griglia fitta attorno al rettangolo [param schermo] del modello (un po' più grande) e si tiene
## solo il vetro, cioè la zona attaccata al centro dove la superficie scende piano (la cornice ha un
## gradino e la faccia storta). Ogni vertice sta [param stacco] metri davanti al vetro: segue la
## bombatura, resta incassato nella cornice e ne prende la forma con gli angoli tondi. Prima era una
## griglia sul rettangolo del modello, più piccolo del vetro e con gli angoli vivi: di lato e da vicino
## sembrava un foglio appoggiato sopra (riscontro della v0.3.5). L'immagine (UV) copre tutto il vetro;
## gli angoli tondi li taglia lo shader (metadato "raggio_uv"), con l'orlo che si spegne.
## [param schermo_a_modello] porta le coordinate dello schermo in quelle del televisore. Legge le mesh:
## va chiamata dove si leggono senza la scheda video (il costruttore della sala). Null se il vetro non
## si trova. Nei metadati, "vertici_sul_vetro".
static func costruisci_schermo_sul_vetro(schermo: Mesh, modello: Mesh, schermo_a_modello: Transform3D,
		suddivisioni := Vector2i(96, 80), stacco := 0.0015) -> ArrayMesh:
	if schermo == null or modello == null or schermo.get_surface_count() == 0:
		return null
	var arr := schermo.surface_get_arrays(0)
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	if vv.size() < 3 or uv.size() != vv.size():
		return null
	# Gli angoli del rettangolo, dalle UV.
	var angoli: Array[Vector3] = []
	for a in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var best := 0
		for i in uv.size():
			if uv[i].distance_squared_to(a) < uv[best].distance_squared_to(a):
				best = i
		angoli.append(vv[best])
	var n := (angoli[1] - angoli[0]).cross(angoli[2] - angoli[0]).normalized()
	var nn: Variant = arr[Mesh.ARRAY_NORMAL]
	if nn is PackedVector3Array and (nn as PackedVector3Array).size() > 0 and n.dot((nn as PackedVector3Array)[0]) < 0.0:
		n = -n
	var tri: TriangleMesh = modello.generate_triangle_mesh()
	if tri == null:
		return null
	var a_schermo := schermo_a_modello.affine_inverse()
	var centro := (angoli[0] + angoli[3]) * 0.5
	var ex := angoli[1] - angoli[0]
	var ey := angoli[2] - angoli[0]
	const LARGO := 1.4          # la griglia dei raggi copre il rettangolo del modello ingrandito così
	var nx := maxi(suddivisioni.x, 8)
	var ny := maxi(suddivisioni.y, 8)
	var passo := maxf(ex.length() * LARGO / nx, ey.length() * LARGO / ny)
	# 1. I raggi: dove colpiscono, quanto sono indietro e quanto la superficie guarda davanti.
	var colpi := PackedVector3Array()
	var fondo := PackedFloat32Array()
	var dritta := PackedFloat32Array()
	colpi.resize((nx + 1) * (ny + 1))
	fondo.resize(colpi.size())
	dritta.resize(colpi.size())
	for j in ny + 1:
		for i in nx + 1:
			var k := j * (nx + 1) + i
			var p := centro + ex * ((float(i) / nx - 0.5) * LARGO) + ey * ((float(j) / ny - 0.5) * LARGO)
			var colpo: Dictionary = tri.intersect_segment(schermo_a_modello * (p + n * 0.08), schermo_a_modello * (p - n * 0.2))
			dritta[k] = -1.0
			if colpo.is_empty():
				continue
			var q := a_schermo * (colpo.position as Vector3)
			colpi[k] = q
			fondo[k] = (q - centro).dot(n)
			dritta[k] = absf((a_schermo.basis * (colpo.normal as Vector3)).normalized().dot(n))
	# 2. Il vetro: dal centro, ai vicini dove la superficie guarda davanti e non fa gradini.
	var vetro := PackedByteArray()
	vetro.resize(colpi.size())
	var k0 := (ny / 2) * (nx + 1) + nx / 2
	if dritta[k0] < 0.8:
		return null
	vetro[k0] = 1
	var coda: Array[int] = [k0]
	while not coda.is_empty():
		var k: int = coda.pop_back()
		var i := k % (nx + 1)
		var j := k / (nx + 1)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var i2: int = i + d.x
			var j2: int = j + d.y
			if i2 < 0 or j2 < 0 or i2 > nx or j2 > ny:
				continue
			var k2 := j2 * (nx + 1) + i2
			if vetro[k2] or dritta[k2] < 0.8 or absf(fondo[k2] - fondo[k]) > passo * 0.45:
				continue
			vetro[k2] = 1
			coda.append(k2)
	# 3. Il rettangolo del vetro (un passo dentro) e il raggio dei suoi angoli tondi: lungo la diagonale
	# da ogni angolo del rettangolo, quanto manca prima di arrivare sul vetro.
	var i0 := nx
	var i1 := 0
	var j0 := ny
	var j1 := 0
	var sul_vetro := 0
	for k in colpi.size():
		if vetro[k]:
			sul_vetro += 1
			i0 = mini(i0, k % (nx + 1))
			i1 = maxi(i1, k % (nx + 1))
			j0 = mini(j0, k / (nx + 1))
			j1 = maxi(j1, k / (nx + 1))
	i0 += 1
	i1 -= 1
	j0 += 1
	j1 -= 1
	if sul_vetro < 64 or i1 - i0 < 8 or j1 - j0 < 8:
		return null
	var manca := 0.0
	for ang in [Vector2i(i0, j0), Vector2i(i1, j0), Vector2i(i0, j1), Vector2i(i1, j1)]:
		var dx := 1 if ang.x == i0 else -1
		var dy := 1 if ang.y == j0 else -1
		var t := 0
		while t < mini(i1 - i0, j1 - j0) / 2 and not vetro[(ang.y + dy * t) * (nx + 1) + ang.x + dx * t]:
			t += 1
		manca += t / 4.0
	# un angolo tondo di raggio r lascia fuori r (1 - 1/√2) lungo la diagonale; un passo in più di margine
	var raggio := (manca + 1.0) / (1.0 - sqrt(0.5))
	# 4. Fuori dal vetro (sotto il labbro della cornice) i punti stanno alla profondità del vetro più vicino:
	# lì lo shader taglia l'angolo tondo, e quello che resta è nascosto dalla cornice.
	var coda2: Array[int] = []
	for k in colpi.size():
		if vetro[k]:
			coda2.append(k)
	var pieno := vetro.duplicate()
	while not coda2.is_empty():
		var nuovi: Array[int] = []
		for k in coda2:
			var i := k % (nx + 1)
			for d in [1, -1, nx + 1, -(nx + 1)]:
				var k2: int = k + d
				if k2 < 0 or k2 >= colpi.size() or (absi(d) == 1 and (k2 % (nx + 1)) != i + d) or pieno[k2]:
					continue
				pieno[k2] = 1
				fondo[k2] = fondo[k]
				var i2 := k2 % (nx + 1)
				var j2 := k2 / (nx + 1)
				colpi[k2] = centro + ex * ((float(i2) / nx - 0.5) * LARGO) + ey * ((float(j2) / ny - 0.5) * LARGO)
				colpi[k2] += n * (fondo[k2] - (colpi[k2] - centro).dot(n))
				nuovi.append(k2)
		coda2 = nuovi
	# 5. La mesh: la griglia sul rettangolo del vetro.
	var punti := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normali := PackedVector3Array()
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			punti.append(colpi[j * (nx + 1) + i] + n * stacco)
			uvs.append(Vector2(float(i - i0) / (i1 - i0), float(j - j0) / (j1 - j0)))
			normali.append(n)
	var lx := i1 - i0 + 1
	var indici := PackedInt32Array()
	for j in j1 - j0:
		for i in i1 - i0:
			var a := j * lx + i
			var b := a + 1
			var c := a + lx
			var d := c + 1
			# Facce in senso orario viste da davanti (come vuole Godot).
			if (punti[b] - punti[a]).cross(punti[c] - punti[a]).dot(n) > 0.0:
				indici.append_array([a, c, b, b, c, d])
			else:
				indici.append_array([a, b, c, b, d, c])
	var nuovo := []
	nuovo.resize(Mesh.ARRAY_MAX)
	nuovo[Mesh.ARRAY_VERTEX] = punti
	nuovo[Mesh.ARRAY_NORMAL] = normali
	nuovo[Mesh.ARRAY_TEX_UV] = uvs
	nuovo[Mesh.ARRAY_INDEX] = indici
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, nuovo)
	mesh.resource_name = "SCHERMO_CRT_sul_vetro"
	mesh.set_meta(&"vertici_sul_vetro", sul_vetro)
	# il raggio degli angoli in UV, per lo shader (raggio_angoli)
	mesh.set_meta(&"raggio_uv", Vector2(raggio / (i1 - i0), raggio / (j1 - j0)))
	return mesh


## L'immagine della telecamera con la sovrimpressione, in un SubViewport 2D piccolo.
func _componi() -> void:
	_vista = SubViewport.new()
	_vista.name = "Telecamera"
	_vista.size = LATO
	_vista.disable_3d = true
	_vista.transparent_bg = false
	_vista.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vista)
	var fondo := ColorRect.new()
	fondo.color = Color(0.05, 0.06, 0.06)
	fondo.size = Vector2(LATO)
	_vista.add_child(fondo)
	if immagine:
		var img := TextureRect.new()
		img.texture = immagine
		img.size = Vector2(LATO)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_vista.add_child(img)
	# Un po' dentro dai bordi: gli angoli del tubo sono scuri (crt.gdshader) e coprivano la data.
	var cam := _scritta(telecamera, Vector2(34, 20))
	cam.name = "Nome"
	_rec = _scritta("● REC", Vector2(LATO.x - 96, 20))
	_ora = _scritta("", Vector2(34, LATO.y - 42))


func _scritta(testo: String, dove: Vector2) -> Label:
	var l := Label.new()
	l.text = testo
	l.position = dove
	l.add_theme_font_size_override(&"font_size", 15)
	l.add_theme_color_override(&"font_color", Color(0.92, 0.95, 0.9))
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override(&"outline_size", 4)
	_vista.add_child(l)
	return l


## Solo neve (dal blackout in poi).
func mostra_neve() -> void:
	if _materiale:
		_materiale.set_shader_parameter(&"neve", 1.0)


func mostra_neve_attiva() -> bool:
	return _materiale != null and float(_materiale.get_shader_parameter(&"neve")) > 0.5


## Il testo della data e dell'ora come compare adesso sul monitor.
func sovrimpressione() -> String:
	return _ora.text if _ora else ""


func _applica(fase: GameState.Luci) -> void:
	if _materiale == null:
		return
	_materiale.set_shader_parameter(&"neve", 1.0 if fase == GameState.Luci.BLACKOUT else 0.0)
	_materiale.set_shader_parameter(&"luminosita", 2.4 if fase == GameState.Luci.FLASH else 1.3)


func _process(delta: float) -> void:
	_t += delta
	_secondi += delta
	var s := int(_secondi) % 86400
	if s != _ultimo_secondo and _ora:
		# L'ora corre: si ridisegna la sovrimpressione una volta al secondo.
		_ultimo_secondo = s
		_ora.text = "%s  %02d:%02d:%02d" % [data, s / 3600, (s / 60) % 60, s % 60]
		_rec.visible = s % 2 == 0
		_vista.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _luce == null:
		return
	# Il tubo tremola: con la neve di più.
	var k := 0.85 + 0.1 * sin(_t * 31.0) + 0.05 * sin(_t * 77.0)
	if mostra_neve_attiva():
		k = 0.7 + 0.3 * randf()
	_luce.light_energy = energia_luce * k
