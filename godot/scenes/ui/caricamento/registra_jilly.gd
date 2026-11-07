extends Node
## La sequenza di Jilly per la schermata di caricamento (richiesta dell'utente del 7 novembre: «un loading screen
## personalizzato, con Jilly che ti guarda e sbatte l'occhio inclinando la testa»), registrata dal motore: Jilly vera
## (MedusaAffacciata, il modello e i materiali bagnati del gioco) affacciata alla vasca della sala, con le luci, i muri
## e l'ambiente della sala come all'inizio del gioco, vista dagli occhi di chi le sta davanti.
## Nel ciclo di [constant CICLO] secondi (due respiri dell'animazione "affacciata") l'occhio e la testa ti guardano,
## la testa si inclina di lato e torna dritta, e la palpebra si chiude due volte. Si registra un po' di più del ciclo
## ([constant CODA]): la coda si fonde con l'inizio (tools/caricamento/jilly_video.sh), così il video gira senza giunte
## anche dove il ciclo non torna da solo (l'acqua, le luci che sfarfallano).
## Come in giro_sala_parti_g2.gd si caricano solo le parti della sala che servono, sotto una radice nuova con gli
## stessi nomi, e si accendono solo le mesh vicine alla camera (la sala intera sul renderer software non entra in
## memoria).
## Uso (sotto il render.lock), col Movie Maker a 24 fotogrammi fissi:
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 24 --write-movie <cartella>/jilly.png --script res://tests/run.gd -- \
##     res://scenes/ui/caricamento/registra_jilly.gd
## Con SCATTI=<cartella> invece del video salva solo alcuni fotogrammi (per l'inquadratura).

const SALA := "res://scenes/sala_principale.tscn"
const PARTI := ["Sala", "LuciSala", "Vasca"]
## Secondi del ciclo: due respiri dell'animazione "affacciata" (4 s).
const CICLO := 8.0
## Secondi registrati dopo il ciclo, da fondere con l'inizio.
const CODA := 0.5
## Secondi di preparazione prima di registrare (lo scheletro, lo sguardo e le luci si assestano).
const PRIMA := 3.0
## Dove sta la camera (gli occhi di chi è davanti alla vasca) e dove guarda (a sinistra dell'occhio di Jilly, che
## così sta nella parte destra dello schermo, lasciando la sinistra ai comandi e al consiglio).
@export var camera := Vector3(-0.42, 1.52, 13.55)
@export var mira := Vector3(-0.62, 1.48, 11.9)
@export var fov := 46.0
## L'inclinazione massima della testa (gradi), verso la sua sinistra.
@export var inclinazione := 16.0
## Quanto la testa si gira verso la camera (0..1, LookAtModifier3D della MedusaAffacciata).
@export var segui_testa := 0.55
## Quando si chiude la palpebra (secondi nel ciclo).
@export var battiti := PackedFloat32Array([2.5, 6.7])
## La testa: comincia a inclinarsi, è inclinata, comincia a tornare, è dritta (secondi nel ciclo).
@export var tempi_testa := PackedFloat32Array([1.4, 3.0, 4.9, 6.5])

var _radice: Node3D
var _prima := {}
var _medusa: MedusaAffacciata
var _cam: Camera3D
var _inclina: Inclina
var _t := -PRIMA
var _battuti := {}


## La testa inclinata di lato: un giro intorno a dove guarda la testa, dopo lo sguardo.
class Inclina extends SkeletonModifier3D:
	var osso := -1
	var avanti_osso := Vector3.FORWARD
	var angolo := 0.0

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or osso < 0 or absf(angolo) < 1e-5:
			return
		var g := sk.get_bone_global_pose(osso)
		var avanti := (g.basis.orthonormalized() * avanti_osso).normalized()
		g.basis = Basis(avanti, angolo) * g.basis
		sk.set_bone_global_pose(osso, g)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	_radice = Node3D.new()
	_radice.name = "SetJilly"
	get_tree().node_added.connect(_aggiunto)
	var tutta := (load(SALA) as PackedScene).instantiate()
	for percorso in PARTI:
		var n := tutta.get_node_or_null(NodePath(percorso)) as Node3D
		if n == null:
			continue
		var tr := _globale(n, tutta)
		n.get_parent().remove_child(n)
		n.transform = tr
		_radice.add_child(n)
	tutta.free()
	var look: LookSala = null
	for c in _radice.find_children("*", "LookSala", true, false):
		look = c
	for classe in ["VoxelGI", "LightmapGI", "GPUParticles3D", "CPUParticles3D", "WaterDripEmitter"]:
		for n in _radice.find_children("*", classe, true, false):
			n.get_parent().remove_child(n)
			n.free()
	var we := WorldEnvironment.new()
	we.environment = look.ambiente if look else (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment)
	we.camera_attributes = look.attributi_camera if look else null
	_radice.add_child(we)
	_medusa = _radice.get_node(^"Vasca/Medusa") as MedusaAffacciata
	_medusa.gocce = false
	_cam = Camera3D.new()
	_cam.fov = fov
	_cam.near = 0.05
	_cam.far = 80.0
	_radice.add_child(_cam)
	get_tree().root.add_child(_radice)
	get_tree().current_scene = _radice
	_cam.global_position = camera
	_cam.look_at(mira)
	_cam.make_current()
	_accendi(camera)
	for i in 3:
		await get_tree().process_frame
	_accendi(camera)
	# lo sguardo sulla camera, la testa un po' verso di lei, e l'inclinazione dopo tutto il resto
	var b = _medusa.get(&"_bersaglio")
	if b is Node3D:
		(b as Node3D).global_position = camera
	_medusa.segui_con_la_testa(segui_testa, 0.01)
	var sk := _medusa.get_model_instance().find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_inclina = Inclina.new()
	_inclina.name = "InclinaTesta"
	_inclina.osso = sk.find_bone("testa")
	var rb := sk.get_bone_global_rest(_inclina.osso).basis
	var av := MedusaAffacciata._asse(rb, Vector3.BACK)
	var asse := Vector3.ZERO
	asse[av.x] = float(av.y)
	_inclina.avanti_osso = asse
	sk.add_child(_inclina)
	var scatti := OS.get_environment("SCATTI")
	if scatti != "":
		DirAccess.make_dir_recursive_absolute(scatti)


func _process(delta: float) -> void:
	if _inclina == null:
		return
	_t += delta
	var c := fposmod(_t, CICLO) if _t >= 0.0 else _t + CICLO
	# la testa: si inclina, resta, torna dritta (curve morbide)
	var k := 0.0
	if c >= tempi_testa[0] and c < tempi_testa[1]:
		k = _morbido(inverse_lerp(tempi_testa[0], tempi_testa[1], c))
	elif c >= tempi_testa[1] and c < tempi_testa[2]:
		k = 1.0
	elif c >= tempi_testa[2] and c < tempi_testa[3]:
		k = 1.0 - _morbido(inverse_lerp(tempi_testa[2], tempi_testa[3], c))
	_inclina.angolo = deg_to_rad(inclinazione) * k
	# la palpebra: una volta per battito e per giro del ciclo
	for i in battiti.size():
		var giro := floori((_t - battiti[i]) / CICLO)
		if c >= battiti[i] and not _battuti.has(Vector2i(i, giro)) and c < battiti[i] + 0.2:
			_battuti[Vector2i(i, giro)] = true
			_medusa.chiudi_occhio(0.04)
	var scatti := OS.get_environment("SCATTI")
	if scatti != "":
		for s in [0.5, 2.6, 3.5, 5.5]:
			if _t >= s and _t - delta < s:
				_salva.call_deferred(scatti.path_join("jilly_%04.1f.png" % s))
		if _t > 5.6:
			get_tree().quit()
	elif _t >= CICLO + CODA:
		get_tree().quit()


func _salva(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(file)


static func _morbido(x: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(x, 0.0, 1.0))


static func _globale(n: Node3D, tutta: Node) -> Transform3D:
	var tr := n.transform
	var q := n.get_parent()
	while q and q != tutta:
		if q is Node3D:
			tr = (q as Node3D).transform * tr
		q = q.get_parent()
	if tutta is Node3D:
		tr = (tutta as Node3D).transform * tr
	return tr


func _aggiunto(n: Node) -> void:
	if n is GeometryInstance3D and _radice and _radice.is_ancestor_of(n):
		if not _prima.has(n):
			_prima[n] = (n as GeometryInstance3D).visible
		(n as GeometryInstance3D).visible = false


## Accende le mesh entro 30 m dalla camera (e Jilly tutta).
func _accendi(da: Vector3) -> void:
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		g.visible = bool(_prima[g]) and (da.clamp(b.position, b.end).distance_to(da) < 30.0 or _medusa.is_ancestor_of(g))
