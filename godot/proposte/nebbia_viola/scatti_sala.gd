extends Node
## Scatti della prova della nebbia viola (NebbiaViolaProva) nella sala principale, richiesta dell'utente del 29 ottobre
## ("me la fai vedere nella sala iniziale?"). La sala intera, renderizzata, non sta nei 15 GB della macchina di prova:
## come in tests/collaudo/giro_squalo.gd si carica solo quello che si vede (la sala, le sue luci, la vasca della medusa,
## la pozza e le vasche, la mascotte, gli scarabocchi) nella posizione che ha nella sala, con l'ambiente e gli attributi
## della camera della sala (LookSala). Per ogni vista, dagli occhi del giocatore (1,6 m): lo scatto senza nebbia e con
## ogni variante, e il costo misurato dal motore. L'alone della nebbia prende le 4 lampade più importanti della vista.
## Neanche così ci sta tutta (fuori memoria compilando le pipeline): come in tests/strumenti/scatti_muri.gd ogni mesh
## parte spenta e a ogni vista si accendono solo quelle entro [constant RAGGIO] m dalla camera e dal punto guardato.
## Le luci della sala come le trova il giocatore all'inizio (prima del risveglio).
## Uso (sotto il render.lock): tools/scatto_sicuro.sh res://proposte/nebbia_viola/scatti_sala.gd <cartella> \
##        ["nome:forza:lontano:oltre:cala,..."] [viste separate da virgole]

const SALA := "res://scenes/sala_principale.tscn"
## Le parti della sala che si vedono dalle viste (i percorsi nella scena della sala).
const PARTI := ["Sala", "LuciSala", "Vasca", "Piscina/Pozza", "Piscina/AcquaPozza", "Vasche", "Mascotte", "Scarabocchi"]
const CAMERE := {
	"ingresso": [Vector3(0.0, 1.6, 19.4), Vector3(0.0, 1.9, 0.0)],
	"medusa": [Vector3(2.6, 1.6, 15.2), Vector3(0.0, 1.3, 10.0)],
	"torre": [Vector3(-4.0, 1.6, 2.0), Vector3(19.8, 3.0, -15.0)],
}

const RAGGIO := 22.0

var _look: LookSala
var _radice: Node3D
var _prima := {}         # GeometryInstance3D -> se era visibile (quelle nascoste dal gioco restano nascoste)
var _accese := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var varianti: Array = []
	for t in (a[2] if a.size() > 2 else "B:1.2:4.5:1.8:0.8").split(","):
		var v := t.split(":")
		varianti.append([v[0], float(v[1]), float(v[2]), float(v[3]), float(v[4])])
	var viste: PackedStringArray = a[3].split(",") if a.size() > 3 else PackedStringArray(CAMERE.keys())
	DirAccess.make_dir_recursive_absolute(out)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO)
	var radice := Node3D.new()
	radice.name = "SalaPerNebbia"
	_radice = radice
	get_tree().node_added.connect(_aggiunto)
	var tutta := (load(SALA) as PackedScene).instantiate()
	for percorso in PARTI:
		var n := tutta.get_node_or_null(NodePath(percorso)) as Node3D
		if n == null:
			print("NEBBIA manca ", percorso)
			continue
		var tr := n.transform
		var padre := n.get_parent() as Node3D
		if padre != tutta and padre:
			tr = padre.transform * tr
		n.get_parent().remove_child(n)
		n.transform = tr
		radice.add_child(n)
		if n is LookSala:
			_look = n
	tutta.free()
	var we := WorldEnvironment.new()
	we.environment = _look.ambiente if _look else (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment)
	we.camera_attributes = _look.attributi_camera if _look else null
	radice.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 60.0
	radice.add_child(cam)
	get_tree().root.add_child(radice)
	cam.make_current()
	cam.global_position = Vector3(0, 1.6, 19.4)
	for i in 30:
		await get_tree().process_frame
	var nebbia := NebbiaViolaProva.new()
	add_child(nebbia)
	nebbia.su(cam)
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for nome in viste:
		var c: Array = CAMERE[nome]
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP)
		_accendi(c[0], c[1])
		nebbia.imposta_luci(_luci_della_vista(radice, cam))
		nebbia.attiva = false
		var senza := await _misura(vp)
		await _scatto(out.path_join("%s_senza.jpg" % nome))
		for v in varianti:
			nebbia.forza = v[1]
			nebbia.imposta(&"lontano", v[2])
			nebbia.imposta(&"oltre", v[3])
			nebbia.imposta(&"cala", v[4])
			nebbia.attiva = true
			var con := await _misura(vp)
			await _scatto(out.path_join("%s_nebbia_%s.jpg" % [nome, v[0]]))
			print("NEBBIA %s %s (forza %.2f, lontano %.1f, oltre %.1f, cala %.2f): disegno senza %.1f ms, con %.1f ms (costa %.1f ms; renderer software)" % [
					nome, v[0], v[1], v[2], v[3], v[4], senza, con, con - senza])
	print("NEBBIA pipeline: disegno %d, specializzazione %d" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)])
	print("memoria massima del processo %d MB" % (OS.get_static_memory_peak_usage() / 1048576))
	get_tree().quit()


## Ogni mesh che entra nella scena parte spenta (se non è fra quelle accese per la vista).
func _aggiunto(n: Node) -> void:
	if n is GeometryInstance3D and n != null and _radice and _radice.is_ancestor_of(n) and not _accese.has(n):
		if not _prima.has(n):
			_prima[n] = (n as GeometryInstance3D).visible
		(n as GeometryInstance3D).visible = false


## Accende le mesh entro RAGGIO dalla camera o dal punto guardato (e il resto spento).
func _accendi(da: Vector3, a: Vector3) -> void:
	_accese.clear()
	var n_accese := 0
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.get_parent() is Camera3D:
			continue
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		var vicino := (_distanza(b, da) < RAGGIO or _distanza(b, a) < RAGGIO) and bool(_prima[g])
		if vicino:
			_accese[g] = true
			n_accese += 1
		g.visible = vicino
	print("NEBBIA mesh accese %d di %d" % [n_accese, _prima.size()])


static func _distanza(b: AABB, p: Vector3) -> float:
	return p.clamp(b.position, b.end).distance_to(p)


## Le 4 lampade più importanti della vista: accese, davanti alla camera, entro 25 m; prima le più forti e vicine.
func _luci_della_vista(radice: Node, cam: Camera3D) -> Array:
	var avanti := -cam.global_transform.basis.z
	var tutte: Array = []
	for n in radice.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l is DirectionalLight3D or not l.is_visible_in_tree() or l.light_energy <= 0.0:
			continue
		var d := l.global_position - cam.global_position
		if d.length() > 25.0 or d.normalized().dot(avanti) < 0.35:
			continue
		tutte.append([l.light_energy / (1.0 + d.length() * 0.25), l])
	tutte.sort_custom(func(x, y): return x[0] > y[0])
	var scelte: Array = []
	for t in tutte.slice(0, 4):
		var l := t[1] as Light3D
		scelte.append([l.global_position, l.light_color, 0.18])
		print("NEBBIA luce %s energia %.2f colore %s a %s" % [l.get_path(), l.light_energy, l.light_color, l.global_position])
	return scelte


## Il tempo di disegno del motore (CPU + GPU), in media su 30 fotogrammi, dopo 20 per assestarsi.
func _misura(vp: RID) -> float:
	for i in 20:
		await get_tree().process_frame
	var s := 0.0
	for i in 30:
		await RenderingServer.frame_post_draw
		s += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return s / 30.0


func _scatto(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(file, 0.9)
	print("salvato ", file)
