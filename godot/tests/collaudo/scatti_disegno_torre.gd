extends Node
## Il disegno guida dei giocattoli sulla struttura di gioco dell'area bimbi (la torre con lo scivolo e il secchio gigante;
## nota dell'utente del 4 novembre: "Puoi però spostare il disegno guida sulla torre con lo scivolo e il secchio gigante,
## in un punto facilmente raggiungibile e ben visibile"): gli scatti dagli occhi del giocatore, per scegliere il punto e
## per il collaudo. La sala intera, sul renderer software, non sta nei 15 GB della macchina: come
## tests/collaudo/scatti_lei_sbuca.gd (lavoro/collaudo-morbidezza-leggera) si caricano solo le parti che servono (la sala,
## le sue luci, la piscina con l'enigma e le Polaroid) con gli stessi nomi, con l'ambiente e gli attributi della camera
## della sala (LookSala); ogni mesh della sala parte spenta e si accendono solo quelle entro [member raggio] m dalla
## camera.
## Le viste: VISTE qui sotto ("giro": attorno alla struttura; "disegno": quelle del punto scelto e del muro della piscina).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_disegno_torre.gd <cartella> [giro|disegno] [luci]
## luci: "prima" (di serie: prima del risveglio, com'è la sala quando si fa l'enigma, tappa 5) o "blackout".

const SALA := "res://scenes/sala_principale.tscn"
const PARTI := ["Sala", "LuciSala", "Piscina", "Polaroid"]
## La struttura (sala_struttura_gioco): x da -18,3 a -9,7, z da -20,7 a -14,3; la scala da x -14,95 (in basso) a
## -16,25 (in cima, 1,24 m), z da -16,55 a -14,45; la pedana verde a 1,24 m (x -18,15..-16,25, z -16,55..-14,65).
## [nome, occhi, verso] (gli occhi a 1,65 m da terra).
const VISTE := {
	"giro": [
		["g1_da_sud_lontano", Vector3(-14.0, 1.65, -4.5), Vector3(-15.0, 1.6, -16.5)],
		["g2_da_sud_est", Vector3(-8.5, 1.65, -12.0), Vector3(-15.0, 1.6, -16.5)],
		["g3_piede_scala", Vector3(-13.2, 1.65, -14.6), Vector3(-16.5, 1.5, -15.5)],
		["g4_pedana_verde_da_sud", Vector3(-17.0, 1.65, -12.3), Vector3(-17.2, 1.7, -14.7)],
		["g5_da_ovest", Vector3(-22.0, 1.65, -15.5), Vector3(-17.5, 1.6, -17.0)],
		["g6_da_est_scivolo", Vector3(-6.5, 1.65, -15.0), Vector3(-12.5, 1.5, -18.0)],
		["g7_in_cima_scala", Vector3(-16.6, 1.24 + 1.65, -15.4), Vector3(-17.6, 1.24 + 1.0, -16.0)],
		["g8_da_nord_est", Vector3(-9.5, 1.65, -23.5), Vector3(-14.5, 1.6, -18.5)],
		["g9_piede_scala_verso_nord", Vector3(-13.6, 1.65, -14.6), Vector3(-14.2, 2.1, -17.45)],
		["g10_torre_arancio_da_sud", Vector3(-14.0, 1.65, -9.0), Vector3(-14.2, 2.0, -17.45)],
	],
	"disegno": [],
}

var raggio := float(OS.get_environment("SCATTI_RAGGIO")) if OS.has_environment("SCATTI_RAGGIO") else 22.0
var _cartella := ""
var _gruppo := "giro"
var _radice: Node3D
var _prima := {}
var _accese := {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_disegno_torre"
	_gruppo = a[2] if a.size() > 2 else "giro"
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	var radice := Node3D.new()
	radice.name = "SalaPerDisegno"
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
		n.get_parent().remove_child(n)
		n.transform = tr
		radice.add_child(n)
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
	var cam := Camera3D.new()
	cam.fov = 75.0
	radice.add_child(cam)
	get_tree().root.add_child(radice)
	get_tree().current_scene = radice
	cam.make_current()
	for i in 20:
		await get_tree().process_frame
	var luci := OS.get_cmdline_user_args()[3] if OS.get_cmdline_user_args().size() > 3 else "prima"
	GameState.imposta_luci(GameState.Luci.BLACKOUT if luci == "blackout" else GameState.Luci.PRIMA_DEL_RISVEGLIO)
	DirAccess.make_dir_recursive_absolute(_cartella)
	var viste: Array = VISTE.get(_gruppo, [])
	if _gruppo == "disegno":
		viste = _viste_disegno()
	for v in viste:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		_accendi(cam.global_position)
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(_cartella.path_join("%s_%s.jpg" % [luci, v[0]]), 0.9)
		print("SCATTO ", v[0])
	print("memoria massima del processo %d MB" % (OS.get_static_memory_peak_usage() / 1048576))
	print("FINE")
	get_tree().quit()


## Le viste del disegno sulla struttura (dove l'ha messo EnigmaGiocattoli) e del muro della piscina dove stava.
func _viste_disegno() -> Array:
	var out := []
	var d := _radice.find_child("Disegno", true, false) as Node3D
	if d:
		var c := d.global_position
		var n := d.global_basis.z.normalized()
		var lato := n.cross(Vector3.UP).normalized()
		var terra := Vector3(c.x, 0.0, c.z)
		# (davanti alla pedana, a sud-ovest, c'è un fungo: le viste da lontano sono da sud e da sud-est)
		out.append(["d1_da_sud_est_4m", terra + n * 4.0 - lato * 2.5 + Vector3(0, 1.65, 0), c])
		out.append(["d2_davanti_1m", terra + n * 0.9 - lato * 0.3 + Vector3(0, 1.65, 0), c])
		out.append(["d3_di_sbieco", terra + n * 3.0 - lato * 4.0 + Vector3(0, 1.65, 0), c])
		out.append(["d4_dal_percorso_lontano", Vector3(-14.0, 1.65, -9.0), c])
		out.append(["d5_attacchi_da_vicino", terra + n * 0.45 + lato * 0.35 + Vector3(0, c.y - 0.05, 0), c + lato * 0.3])
		out.append(["d6_di_lato_distacco", c + n * 0.12 + lato * 0.9, c])
	var e := _radice.find_child("EnigmaGiocattoli", true, false) as Node3D
	if e:
		# il muro ovest della parte profonda, dove stava (a -6,97, -0,8, -0,2 nel sistema dell'enigma)
		out.append(["d7_muro_piscina", e.to_global(Vector3(-3.5, 0.9, -0.2)), e.to_global(Vector3(-6.97, -0.8, -0.2))])
	return out


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
	if n is GeometryInstance3D and _radice and _radice.is_ancestor_of(n) and not _accese.has(n):
		if not _prima.has(n):
			_prima[n] = (n as GeometryInstance3D).visible
		(n as GeometryInstance3D).visible = false


func _accendi(da: Vector3) -> void:
	_accese.clear()
	var n_accese := 0
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		var vicino := da.clamp(b.position, b.end).distance_to(da) < raggio and bool(_prima[g])
		if vicino:
			_accese[g] = true
			n_accese += 1
		g.visible = vicino
	print("mesh accese %d di %d" % [n_accese, _prima.size()])
