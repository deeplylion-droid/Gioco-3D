extends Node
## Scatti dal motore dagli occhi del giocatore in piedi sul fondo della piscina a onde vuota, dove si spingono i
## giocattoli (EnigmaGiocattoli), per i ricontrolli della nebbia (la nebbia viola della sala, ZonaNebbiaViola, come
## la crea sala_principale.gd).
## La sala intera, sul renderer software, non sta nei 15 GB della macchina: come scatti_lei_sbuca.gd si caricano solo
## le parti che servono ([constant PARTI], o SCATTI_PARTI separate da virgole), con gli stessi nomi, l'ambiente e gli
## attributi della camera della sala (LookSala) e un giocatore; ogni mesh parte spenta e si accendono quelle entro
## [member raggio] m dalla camera.
## Da ogni punto di [constant SCATTI] uno scatto dopo [member attesa] s (la nebbia sale piano entrando nella zona).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_piscina_vuota.gd <cartella> [buio] [preset]
## "buio": col blackout (altrimenti le luci normali). SCATTI_RAGGIO: il raggio, di serie 30 m.

const SALA := "res://scenes/sala_principale.tscn"
const PARTI := ["Sala", "LuciSala", "Piscina", "Atmosfera"]
## La zona della nebbia viola della sala (sala_principale.gd, NEBBIA_SALA).
const NEBBIA_SALA := AABB(Vector3(-20.0, -3.5, -24.0), Vector3(40.0, 22.5, 44.0))
## [nome, dove sta sul fondo (x, z), dove guarda]
const SCATTI := [
	["centro_ovest", Vector2(0.0, 1.5), Vector3(-6.97, -0.8, -0.2)],
	["centro_est", Vector2(0.0, 1.5), Vector3(7.0, -0.6, 1.5)],
	["cerchi", Vector2(1.0, -2.4), Vector3(-3.0, -1.8, 1.6)],
	["pallone", Vector2(2.6, 1.8), Vector3(3.9, -1.85, 3.3)],
	["paperella_balena", Vector2(-2.2, 1.2), Vector3(-3.9, -1.85, 1.6)],
	["su_verso_sala", Vector2(-1.0, 3.0), Vector3(2.0, 3.0, 10.0)],
	# (in piedi sul pavimento della sala, guardando il pavimento alla stessa distanza: il confronto)
	["pavimento_sala", Vector2(13.0, 6.4), Vector3(13.0, 0.0, 0.6)],
]

var raggio := float(OS.get_environment("SCATTI_RAGGIO")) if OS.has_environment("SCATTI_RAGGIO") else 30.0
var attesa := 4.0
var _cartella := ""
var _radice: Node3D
var _accese := {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_piscina_vuota"
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var buio := a.size() > 2 and a[2] == "buio"
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(a[3] if a.size() > 3 else "medio")
	var parti: Array = PARTI
	if OS.has_environment("SCATTI_PARTI"):
		parti = Array(OS.get_environment("SCATTI_PARTI").split(","))
	_radice = Node3D.new()
	_radice.name = "SalaPerPiscina"
	get_tree().node_added.connect(_aggiunto)
	var tutta := (load(SALA) as PackedScene).instantiate()
	for percorso in parti:
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
	var look: LookSala = null
	for c in _radice.find_children("*", "LookSala", true, false):
		look = c
	var we := WorldEnvironment.new()
	we.environment = look.ambiente if look else (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment)
	we.camera_attributes = look.attributi_camera if look else null
	_radice.add_child(we)
	# la nebbia viola della sala, come in sala_principale.gd
	var z := ZonaNebbiaViola.new()
	z.name = "NebbiaViola"
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = NEBBIA_SALA.size
	cs.shape = b
	cs.position = NEBBIA_SALA.get_center()
	z.add_child(cs)
	z.quota = 0.0
	z.luci = [^"../Sala", ^"../LuciSala"]
	_radice.add_child(z)
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	_radice.add_child(p)
	get_tree().root.add_child(_radice)
	get_tree().current_scene = _radice
	GameState.player = p
	for i in 30:
		await get_tree().process_frame
	if buio:
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var pozza := _radice.get_node_or_null(^"Piscina/Pozza") as WaterTank
	if pozza:
		pozza.fill = 0.0
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.camera.make_current()
	DirAccess.make_dir_recursive_absolute(_cartella)
	var spazio := _radice.get_world_3d().direct_space_state
	# (prima nella zona finché la nebbia è piena. Il giocatore è fermo, senza fisica: la zona se ne accorge solo con un
	# salto, quindi parte da fuori e salta dentro; senza, ai primi scatti la nebbia era ancora a 0)
	p.global_position = Vector3(0.0, 60.0, 80.0)
	for i in 3:
		await get_tree().process_frame
	p.global_position = Vector3(0.0, -2.1, 1.5)
	_accendi(p.get_eye_position())
	var t0 := 0.0
	while t0 < NebbiaViola.DURATA + 2.0:
		await get_tree().process_frame
		t0 += get_process_delta_time()
	for s in SCATTI:
		var xz: Vector2 = s[1]
		var h: Dictionary = spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(xz.x, 3.0, xz.y), Vector3(xz.x, -5.0, xz.y), Layers.WORLD))
		var fondo: float = (h.position as Vector3).y if not h.is_empty() else -2.05
		p.global_position = Vector3(xz.x, fondo, xz.y)
		var occhio := p.get_eye_position()
		_accendi(occhio)
		p.camera.global_transform = Transform3D(Basis.looking_at((s[2] as Vector3) - occhio, Vector3.UP), occhio)
		var t := 0.0
		while t < attesa:
			await get_tree().process_frame
			t += get_process_delta_time()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(_cartella.path_join("%s.jpg" % s[0]), 0.9)
		var nv: Variant = Grafica.get(&"nebbia_viola")
		print("scatto %s: occhi a (%.2f, %.2f, %.2f), fondo a %.2f; pozza piena %.2f; nebbia viola %s" % [s[0], occhio.x,
				occhio.y, occhio.z, fondo, pozza.fill if pozza else -1.0, str(nv.get(&"quanto")) if nv else "-"])
	print("memoria massima del processo %d MB" % (OS.get_static_memory_peak_usage() / 1048576))
	print("FINE")
	get_tree().quit()


## La posizione di [param n] nella scena [param tutta] (non ancora nell'albero).
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


## Ogni mesh della sala che entra nella scena parte spenta (si accendono poi quelle vicine alla camera).
func _aggiunto(n: Node) -> void:
	if n is GeometryInstance3D and _radice and _radice.is_ancestor_of(n) and not _accese.has(n):
		(n as GeometryInstance3D).set_meta(&"era_visibile", (n as GeometryInstance3D).visible)
		(n as GeometryInstance3D).visible = false


## Accende le mesh entro [member raggio] m da [param occhio] (quelle che il gioco teneva nascoste restano nascoste) e
## spegne le altre.
func _accendi(occhio: Vector3) -> void:
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.has_meta(&"era_visibile"):
			continue
		var vicino := g.get_aabb().size == Vector3.ZERO or (g.global_transform * g.get_aabb()).grow(raggio).has_point(occhio)
		g.visible = bool(g.get_meta(&"era_visibile")) and vicino
		if g.visible:
			_accese[g] = true
