extends Node
## Collaudo della morbidezza (correzioni del 29 ottobre): lei che sbuca dalla fossa nella sala (LeiSbuca, tappa 8),
## dalla camera del giocatore 7 m davanti (come in test_morbidezza_sbuca), a 60 fps: salva ogni fotogramma della
## salita e del primo secondo affacciata in <cartella>/<nome>_NNNN.jpg e stampa i fotogrammi dove un punto dei
## tentacoli va più veloce (lo scatto a 35 m/s di test_morbidezza_sbuca a 60 fps), per farne poi i fogli.
## La sala intera, sul renderer software, non sta nei 15 GB della macchina (con la sua logica prepara e carica le altre
## zone): come proposte/nebbia_viola/scatti_sala.gd si caricano solo le parti che servono (la sala, le sue luci, le
## vasche e lei), con gli stessi nomi, così i percorsi di LeiSbuca (../../Sala, ../../Vasche) valgono ancora, con
## l'ambiente e gli attributi della camera della sala (LookSala) e un giocatore; e ogni mesh della sala parte spenta e
## si accendono solo quelle entro [member raggio] m dalla camera o dalla fossa (lei com'è).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scatti_lei_sbuca.gd <cartella> <nome> [preset]
## (SCATTI_RAGGIO: il raggio, di serie 22 m)

const SALA := "res://scenes/sala_principale.tscn"
const PARTI := ["Sala", "LuciSala", "Vasche", "Gioco/LeiSbuca"]

var raggio := float(OS.get_environment("SCATTI_RAGGIO")) if OS.has_environment("SCATTI_RAGGIO") else 22.0
var _cartella := ""
var _nome := "sbuca"
var _radice: Node3D
var _lei: Node
var _prima := {}         # GeometryInstance3D -> se era visibile (quelle nascoste dal gioco restano nascoste)
var _accese := {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_sbuca"
	_nome = a[2] if a.size() > 2 else "sbuca"
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(OS.get_cmdline_user_args()[3] if OS.get_cmdline_user_args().size() > 3 else "medio")
	var radice := Node3D.new()
	radice.name = "SalaPerSbuca"
	_radice = radice
	get_tree().node_added.connect(_aggiunto)
	var tutta := (load(SALA) as PackedScene).instantiate()
	var look: LookSala = null
	for percorso in PARTI:
		var n := tutta.get_node_or_null(NodePath(percorso)) as Node3D
		if n == null:
			print("manca ", percorso)
			continue
		var tr := _globale(n, tutta)
		# (lo stesso percorso sotto la radice nuova: "Gioco/LeiSbuca" va in un nodo "Gioco")
		var padre: Node3D = radice
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
		if n is LookSala:
			look = n
	tutta.free()
	if look == null:
		for c in radice.find_children("*", "LookSala", true, false):
			look = c
	var we := WorldEnvironment.new()
	we.environment = look.ambiente if look else (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment)
	we.camera_attributes = look.attributi_camera if look else null
	radice.add_child(we)
	_lei = radice.get_node(^"Gioco/LeiSbuca")
	var lei := _lei as LeiSbuca
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	radice.add_child(p)
	get_tree().root.add_child(radice)
	get_tree().current_scene = radice
	GameState.player = p
	for i in 30:
		await get_tree().process_frame
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for v in lei.vasche:
		var t := v as WaterTank
		t.fill = clampf((lei.livello_pieno - t.get_floor_global_y()) / t.inner_size.y, 0.0, t.max_fill)
	lei.distanza_presa = 0.0
	p.teleport(lei.punto_sbuca.global_position + lei.punto_sbuca.global_basis.z * 7.0 + Vector3(0, 0.1, 0), 0.0, 0.0)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.camera.make_current()
	_accendi(p.get_eye_position(), lei.punto_sbuca.global_position)
	for i in 120:
		await get_tree().process_frame
	lei.call(&"_ricomincia")
	for i in 3:
		await get_tree().process_frame
	var m := MorbidezzaLei.su(lei.medusa)
	DirAccess.make_dir_recursive_absolute(_cartella)
	lei.call(&"_sbuca")
	var durata := lei.durata_sbuca + 1.0
	var t := 0.0
	var f := 0
	var prima := PackedVector3Array()
	var veloci: Array = []
	while t < durata:
		# lo sguardo sul punto dove sale (un po' sopra la fossa), la camera come la girerebbe il giocatore
		p.look_at_point(lei.punto_sbuca.global_position + Vector3.UP * 1.6)
		p.camera.global_transform = p.get_aim_transform()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(_cartella.path_join("%s_%04d.jpg" % [_nome, f]), 0.9)
		var pt := m.punti() if m else PackedVector3Array()
		if pt.size() == prima.size() and f > 0:
			var mx := 0.0
			for i in pt.size():
				mx = maxf(mx, pt[i].distance_to(prima[i]) / get_process_delta_time())
			veloci.append([mx, f])
		prima = pt
		await get_tree().process_frame
		t += get_process_delta_time()
		f += 1
	veloci.sort_custom(func(x, y): return x[0] > y[0])
	print("FOTOGRAMMI %d; i più veloci (m/s, fotogramma): %s" % [f, str(veloci.slice(0, 8))])
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


## Ogni mesh della sala che entra nella scena parte spenta (se non è fra quelle accese, o di lei, o del giocatore).
func _aggiunto(n: Node) -> void:
	if n is GeometryInstance3D and _radice and _radice.is_ancestor_of(n) and not _accese.has(n) and _della_sala(n):
		if not _prima.has(n):
			_prima[n] = (n as GeometryInstance3D).visible
		(n as GeometryInstance3D).visible = false


func _della_sala(n: Node) -> bool:
	if _lei and _lei.is_ancestor_of(n):
		return false
	return not (GameState.player and is_instance_valid(GameState.player) and GameState.player.is_ancestor_of(n))


## Accende le mesh entro raggio m dalla camera o dalla fossa (e il resto spento; lei e il giocatore come sono).
func _accendi(da: Vector3, a: Vector3) -> void:
	_accese.clear()
	var n_accese := 0
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not _della_sala(g):
			continue
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		var vicino := (da.clamp(b.position, b.end).distance_to(da) < raggio or a.clamp(b.position, b.end).distance_to(a) < raggio) \
				and bool(_prima[g])
		if vicino:
			_accese[g] = true
			n_accese += 1
		g.visible = vicino
	print("mesh accese %d di %d" % [n_accese, _prima.size()])
