extends Node
## grafica-2 (collaudo finale 0.3.21, seconda parte): il giro dagli occhi della sala per parti. La sala intera sul
## renderer software non entra più in memoria nemmeno coi materiali semplici (giro.gd, 12,3 GB e poi ucciso): come
## scatti_lei_sbuca.gd si caricano solo le parti che servono, con gli stessi nomi sotto una radice nuova, con
## l'ambiente della sala (LookSala), e per ogni scatto si accendono solo le mesh entro SCATTI_RAGGIO m (di serie 22)
## dalla camera. Materiali veri, preset basso come giro.gd, e la luce bianca del collaudo sulla camera.
## Le righe della lista sono quelle semplici di giro.gd: nome x y z yaw pitch [fov] (camera agli occhi, gradi).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path godot --rendering-driver vulkan --resolution 640x360 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/giro_sala_parti_g2.gd <cartella> <lista>

const SALA := "res://scenes/sala_principale.tscn"
const PARTI_SERIE := ["Sala", "LuciSala", "Vasche", "Vasca", "Mascotte", "Polaroid", "Piscina", "Gioco/EnigmaAcquari"]

var PARTI: Array = Array(OS.get_environment("SCATTI_PARTI").split(",")) if OS.has_environment("SCATTI_PARTI") else PARTI_SERIE
var raggio := float(OS.get_environment("SCATTI_RAGGIO")) if OS.has_environment("SCATTI_RAGGIO") else 22.0
var _radice: Node3D
var _prima := {}


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella: String = a[1]
	var lista: String = a[2]
	DirAccess.make_dir_recursive_absolute(cartella)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("basso")
	_radice = Node3D.new()
	_radice.name = "SalaPerParti"
	# ogni mesh parte spenta appena entra nella scena: si compilano solo le pipeline di quelle che si accendono
	get_tree().node_added.connect(_aggiunto)
	var tutta := (load(SALA) as PackedScene).instantiate()
	var look: LookSala = null
	for percorso in PARTI:
		var n := tutta.get_node_or_null(NodePath(percorso)) as Node3D
		if n == null:
			print("manca ", percorso)
			continue
		var tr := _globale(n, tutta)
		var padre: Node3D = _radice
		var pezzi: PackedStringArray = String(percorso).split("/")
		for i in pezzi.size() - 1:
			var c := padre.get_node_or_null(NodePath(pezzi[i])) as Node3D
			if c == null:
				c = Node3D.new()
				c.name = pezzi[i]
				padre.add_child(c)
			padre = c
		n.get_parent().remove_child(n)
		n.transform = tr
		padre.add_child(n)
	tutta.free()
	for c in _radice.find_children("*", "LookSala", true, false):
		look = c
	for classe in ["VoxelGI", "LightmapGI", "ReflectionProbe", "GPUParticles3D", "CPUParticles3D", "FogVolume"]:
		for n in _radice.find_children("*", classe, true, false):
			n.get_parent().remove_child(n)
			n.free()
	var we := WorldEnvironment.new()
	we.environment = look.ambiente if look else (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment)
	we.camera_attributes = look.attributi_camera if look else null
	_radice.add_child(we)
	get_tree().root.add_child(_radice)
	get_tree().current_scene = _radice
	for i in 120:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.03
	cam.far = 150.0
	_radice.add_child(cam)
	cam.make_current()
	var luce := OmniLight3D.new()
	luce.omni_range = 18.0
	luce.light_energy = 1.6
	luce.omni_attenuation = 0.8
	cam.add_child(luce)
	var fatti := 0
	for r in FileAccess.get_file_as_string(lista).split("\n", false):
		var c := r.strip_edges().split(" ", false)
		if c.size() < 6 or c[0].begins_with("#"):
			continue
		cam.global_position = Vector3(float(c[1]), float(c[2]), float(c[3]))
		cam.rotation_degrees = Vector3(float(c[5]), float(c[4]), 0.0)
		cam.fov = float(c[6]) if c.size() > 6 else 75.0
		_accendi(cam.global_position)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join(c[0] + ".jpg"), 0.85)
		fatti += 1
		if fatti % 25 == 0:
			print("COLLAUDO: %d scatti" % fatti)
	print("COLLAUDO: finito, %d scatti" % fatti)
	get_tree().quit()


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


func _accendi(da: Vector3) -> void:
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		g.visible = bool(_prima[g]) and da.clamp(b.position, b.end).distance_to(da) < raggio
