extends Node
## Strumento (non in CI): gli scatti dei muri vuoti trovati da cerca_muri.gd (docs/proposte/scarabocchi/muri.json),
## per ognuno uno dagli occhi del giocatore (dal punto della strada da cui si vede meglio) e uno da vicino (1,8 m davanti,
## di fronte). La sala principale renderizzata intera non ci sta nei 15 GB della macchina di prova: si carica con tutte
## le mesh spente e a ogni scatto si accendono solo quelle entro [constant RAGGIO] m dalla camera e dal muro (anche
## quelle che le stanze aggiungono dopo).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/strumenti/scatti_muri.gd <cartella> [scena] [nomi separati da virgole]

const MURI := "res://../docs/proposte/scarabocchi/muri.json"
const RAGGIO := 22.0

var _cartella := "user://scatti_muri"
var _accese := {}        # GeometryInstance3D -> vero (quelle che possono accendersi)
var _radice: Node
var _prima := {}         # GeometryInstance3D -> se era visibile (quelle nascoste dal gioco restano nascoste)


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Engine.set_meta(&"risalita_subito", true)
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		_cartella = a[1]
	var scena := a[2] if a.size() > 2 else ""
	var nomi: PackedStringArray = a[3].split(",") if a.size() > 3 else PackedStringArray()
	DirAccess.make_dir_recursive_absolute(_cartella)
	var muri: Array = JSON.parse_string(FileAccess.get_file_as_string(MURI))
	var per_scena := {}
	for m in muri:
		if (scena == "" or String(m["scena"]).get_file().get_basename() == scena) and (nomi.is_empty() or nomi.has(m["nome"])):
			if not per_scena.has(m["scena"]):
				per_scena[m["scena"]] = []
			per_scena[m["scena"]].append(m)
	get_tree().node_added.connect(_aggiunto)
	for s in per_scena:
		if not String(s).ends_with("sala_principale.tscn"):
			await _scena(s, per_scena[s])
			continue
		# la sala principale a parti: una zona alla volta
		var per_zona := {}
		for m in per_scena[s]:
			if not per_zona.has(m["zona"]):
				per_zona[m["zona"]] = []
			per_zona[m["zona"]].append(m)
		for z in per_zona:
			await _scena(s, per_zona[z])
	get_tree().quit()


## La scena da fotografare. La sala principale intera, renderizzata, non ci sta in memoria: per una zona se ne monta
## solo la parte, nella posizione che ha nella sala (le scene e i GLB di sala_principale.tscn), con le sue luci.
func _crea(percorso: String, zona: String) -> Node:
	if not percorso.ends_with("sala_principale.tscn"):
		return (load(percorso) as PackedScene).instantiate()
	var r := Node3D.new()
	r.name = "SalaAParti"
	r.scene_file_path = percorso
	var pezzi := []
	match zona:
		"interni":
			pezzi = [["res://scenes/interni/interni.tscn", "Interni", Transform3D(Basis.IDENTITY, Vector3(-9.7, 0, 40.9))]]
		"tecnici":
			pezzi = [["res://scenes/tecnici/tecnici.tscn", "Tecnici", Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), Vector3(0, -9.05, 1.36))]]
		"risalita", "fiume", "infermeria":
			pezzi = [["res://scenes/risalita/risalita.tscn", "Risalita", Transform3D()]]
		_:
			pezzi = [["res://scenes/sala/luci_sala.tscn", "LuciSala", Transform3D()]]
			for glb in ["sala_architettura", "sala_cupola", "sala_piscina", "sala_area_bimbi", "sala_torre_scivoli",
					"sala_oggetti", "sala_interattivi", "sala_vasca_centrale", "sala_luci"]:
				pezzi.append(["res://assets/ambiente/sala/%s.glb" % glb, glb, Transform3D()])
	for p in pezzi:
		var n := (load(p[0]) as PackedScene).instantiate() as Node3D
		n.name = p[1]
		n.transform = p[2]
		if &"giocatore_proprio" in n:
			n.set(&"giocatore_proprio", false)
		r.add_child(n)
	return r


## Ogni mesh che entra nella scena parte spenta (se non è nella zona dello scatto).
func _aggiunto(n: Node) -> void:
	if n is GeometryInstance3D and _radice and _radice.is_ancestor_of(n) and not _accese.has(n):
		_prima[n] = (n as GeometryInstance3D).visible
		(n as GeometryInstance3D).visible = false


func _scena(percorso: String, muri: Array) -> void:
	# le luci come le trova il giocatore: la sala e gli interni all'inizio, il resto dopo il blackout (LUCI per provare)
	var fase := GameState.Luci.PRIMA_DEL_RISVEGLIO if percorso.ends_with("sala_principale.tscn") else GameState.Luci.BLACKOUT
	if OS.get_environment("LUCI") != "":
		fase = int(OS.get_environment("LUCI")) as GameState.Luci
	GameState.imposta_luci(fase)
	_radice = _crea(percorso, String(muri[0]["zona"]))
	add_child(_radice)
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		if not _prima.has(n):
			_prima[n] = (n as GeometryInstance3D).visible
		(n as GeometryInstance3D).visible = false
	await _frames(5)
	if _radice.has_method(&"costruisci"):
		_radice.call(&"costruisci")
	var r := _radice.get_node_or_null(^"Risalita")
	if r:
		r.call(&"carica_subito")
		r.process_mode = Node.PROCESS_MODE_DISABLED
		for nome in ["fiume", "infermeria"]:
			var n = r.get(nome)
			if n is Node3D:
				(n as Node3D).visible = true
	await _frames(10)
	# (la torre e il tunnel nel gioco stanno nella sala: il suo ambiente, se la scena non ne ha uno)
	if _radice.find_children("*", "WorldEnvironment", true, false).is_empty():
		var look := LookSala.new()
		var we := WorldEnvironment.new()
		we.environment = look.ambiente
		we.camera_attributes = look.attributi_camera
		look.free()
		_radice.add_child(we)
	var cam := Camera3D.new()
	cam.near = 0.05
	cam.far = 60.0
	add_child(cam)
	cam.current = true
	for m in muri:
		var c := _vec(m["centro"])
		var n := _vec(m["normale"])
		var occhi := _vec(m["occhi"])
		for vista in [["occhi", occhi, 75.0], ["vicino", c + n * 1.8 + Vector3.UP * 0.15, 65.0]]:
			cam.global_position = vista[1]
			cam.fov = vista[2]
			cam.look_at(c, Vector3.UP)
			_accendi(cam.global_position, c)
			await _frames(25)
			if OS.has_environment("DIAG"):
				var luci := _radice.find_children("*", "Light3D", true, false).filter(func(l): return (l as Light3D).is_visible_in_tree())
				print("DIAG cam %s attuale %s accese %d luci %d ambiente %s" % [cam.global_position, get_viewport().get_camera_3d().get_path(),
						_accese.size(), luci.size(), str(get_viewport().world_3d.environment)])
			var img := get_viewport().get_texture().get_image()
			var file := "%s/%s_%s.jpg" % [_cartella, m["nome"], vista[0]]
			img.save_jpg(file, 0.9)
			print("SCATTO ", file, "  memoria libera ", _memoria(), " MB")
	cam.queue_free()
	_radice.queue_free()
	_radice = null
	_accese.clear()
	_prima.clear()
	await _frames(10)


## Accende le mesh entro RAGGIO dalla camera o dal muro (e il resto spento).
func _accendi(da: Vector3, a: Vector3) -> void:
	_accese.clear()
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var b := g.global_transform * g.get_aabb()
		var vicino := _distanza(b, da) < RAGGIO or _distanza(b, a) < RAGGIO
		vicino = vicino and bool(_prima.get(g, true))
		if vicino:
			_accese[g] = true
		g.visible = vicino


static func _distanza(b: AABB, p: Vector3) -> float:
	var q := p.clamp(b.position, b.end)
	return q.distance_to(p)


static func _vec(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]))


static func _memoria() -> int:
	var f := FileAccess.open("/proc/meminfo", FileAccess.READ)
	if f == null:
		return -1
	for riga in f.get_as_text().split("\n"):
		if riga.begins_with("MemAvailable"):
			return int(riga.split(" ", false)[1]) / 1024
	return -1
