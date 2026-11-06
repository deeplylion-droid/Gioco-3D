extends Node
## Scatti del portone della torre col gioco vero a parti (ricontrollo del collaudo su varchi-cielo, 6 novembre): la sala
## (Sala) e la torre (sala_torre.tscn, sotto la radice senza spostamenti, come SalaPrincipale._aggiungi_torre, col guscio
## provvisorio tolto), le mesh accese solo vicino alla camera, l'ambiente della sala senza GI e nebbia volumetrica e le
## luci del blackout. Le pose: dagli occhi del checkpoint del portone verso le due aperture trovate dal collaudo
## (cielo_fessure.gd), e la soglia come la vede chi entra e chi esce.
## Con CUBO=1 (e MAGENTA=1) le pose sono 6 direzioni a 90° (un cubo) dagli occhi di ogni checkpoint della torre e da
## un punto ogni tre della discesa (torre_percorso.json, 1 m sopra lo scivolo): i pixel magenta si contano dopo.
## Con VISTE="x,y,z,tx,ty,tz;..." (stampate da bordi_torre.gd) gli scatti ravvicinati dei buchi che si vedono.
## PARTI="Vasca,Piscina,Vasche" tiene anche quei figli di SalaPrincipale (senza, sotto la sala c'è il vuoto).
## TUNNEL=1 aggiunge il tunnel del viaggio sottomarino costruito (come nel gioco, dopo la torre).
## FILTRO=<testo> scatta solo le pose col testo nel nome; RAGGIO=<m> accende le mesh fino a quella distanza (60).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_portone_torre.gd <cartella> [prima]
##   (senza "prima" mette la lastra sotto la soglia come SalaPrincipale._completa_torre; con "prima" no)

const SALA := "res://scenes/sala_principale.tscn"
const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
const SALA_GD := preload("res://scripts/game/sala_principale.gd")
const OCCHI := Vector3(21.4, 1.59, -15.0)
const POSE := [
	["occhi_verso_giu", OCCHI, OCCHI + Vector3(-0.52, -0.654, -0.549), 70.0],
	["occhi_verso_su", OCCHI, OCCHI + Vector3(0.426, 0.337, 0.84), 70.0],
	["soglia_entrando", Vector3(17.6, 1.6, -15.0), Vector3(20.1, 0.0, -15.6), 75.0],
	["soglia_uscendo", Vector3(22.6, 1.6, -15.4), Vector3(20.1, 0.0, -15.0), 75.0],
	["soglia_vicino", Vector3(20.6, 0.5, -14.4), Vector3(20.1, 0.0, -15.6), 60.0],
	# i due checkpoint della torre dove i raggi verso l'alto non toccano niente (controllo_cielo.gd)
	["NEm3_su", Vector3(37.47, -1.41, -18.97), Vector3(37.47, -1.41, -18.97) + Vector3(0.45, 0.887, -0.099), 70.0],
	["NOm12_su", Vector3(27.05, -10.41, -21.41), Vector3(27.05, -10.41, -21.41) + Vector3(0.128, 0.904, 0.408), 70.0],
	# i cinque raggi della torre che controllo_cielo mette a parte (verso l'alto), al centro dello scatto
	["raggio_portone", Vector3(21.4, 1.6, -15.0), Vector3(21.4, 1.6, -15.0) + Vector3(0.425693, 0.3375, 0.839571), 40.0],
	["raggio_NEm3_a", Vector3(37.468, -1.4, -18.970), Vector3(37.468, -1.4, -18.970) + Vector3(0.45006, 0.8875, -0.098944), 40.0],
	["raggio_NEm3_b", Vector3(37.468, -1.4, -18.970), Vector3(37.468, -1.4, -18.970) + Vector3(0.29558, 0.620833, 0.726084), 40.0],
	["raggio_NOm12_a", Vector3(27.049, -10.4, -21.412), Vector3(27.049, -10.4, -21.412) + Vector3(0.127848, 0.904167, 0.4076), 40.0],
	["raggio_NOm12_b", Vector3(27.049, -10.4, -21.412), Vector3(27.049, -10.4, -21.412) + Vector3(0.685801, 0.3875, -0.616052), 40.0],
]

var raggio := 60.0
var _radice: Node3D
var _prima := {}
var _cp_sala: Array = []
var _tunnel: Node3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella: String = a[1] if a.size() > 1 else "/tmp/scatti_portone_torre"
	var senza := a.has("prima")
	DirAccess.make_dir_recursive_absolute(cartella)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	_radice = Node3D.new()
	_radice.name = "SalaPerScatti"
	var tutta := (load(SALA) as PackedScene).instantiate()
	var n := tutta.get_node(^"Sala") as Node3D
	var tr := n.transform
	# i checkpoint della sala (la strada principale), fuori dall'albero: la posizione dalla catena dei nodi
	for c in tutta.find_children("*", "Checkpoint", true, false):
		var sp: Node3D = (c as Checkpoint).spawn_point if (c as Checkpoint).spawn_point else c as Node3D
		var xf := Transform3D.IDENTITY
		var nn: Node = sp
		while nn != null and nn != tutta:
			if nn is Node3D:
				xf = (nn as Node3D).transform * xf
			nn = nn.get_parent()
		_cp_sala.append(["sala_" + String(c.name), xf.origin + Vector3.UP * 1.6])
	n.get_parent().remove_child(n)
	n.transform = tr
	_radice.add_child(n)
	# PARTI="Vasca,Piscina,..." tiene anche questi figli della sala (per il cubo della strada principale)
	if OS.has_environment("PARTI"):
		for nome in OS.get_environment("PARTI").split(","):
			var altro := tutta.get_node_or_null(NodePath(nome)) as Node3D
			if altro:
				var t2 := altro.transform
				altro.get_parent().remove_child(altro)
				altro.transform = t2
				_radice.add_child(altro)
	tutta.free()
	var guscio := _radice.find_child("sala_torre_guscio", true, false)
	if guscio:
		guscio.free()
	var torre := (load(TORRE) as PackedScene).instantiate() as Node3D
	_radice.add_child(torre)
	if OS.has_environment("TUNNEL"):
		# il tunnel del viaggio sottomarino, figlio della radice come SalaPrincipale._metti_sottomarino
		_tunnel = (load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene).instantiate() as Node3D
		_tunnel.name = "SalaSottomarino"
		_radice.add_child(_tunnel)
	var we := WorldEnvironment.new()
	we.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	we.environment.sdfgi_enabled = false
	we.environment.volumetric_fog_enabled = false
	we.environment.ssil_enabled = false
	if OS.has_environment("MAGENTA"):
		# per la diagnosi: lo sfondo magenta pieno (un buco verso lo sfondo è magenta), luce e riflessi ancora dal cielo
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = Color(1.0, 0.0, 1.0)
		we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		we.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_radice.add_child(we)
	var cam := Camera3D.new()
	cam.near = 0.02
	_radice.add_child(cam)
	get_tree().root.add_child(_radice)
	get_tree().current_scene = _radice
	if not senza:
		SALA_GD.chiudi_soglia_torre(torre, _radice.find_child("sala_pavimento", true, false) as MeshInstance3D)
	if _tunnel:
		_tunnel.call(&"costruisci")
	for i in 60:
		await get_tree().process_frame
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	cam.make_current()
	if OS.has_environment("RAGGIO"):
		raggio = float(OS.get_environment("RAGGIO"))
	var pose: Array = POSE
	if OS.has_environment("CUBO"):
		pose = _pose_cubo(torre)
	if OS.has_environment("VISTE"):
		# VISTE="x,y,z,tx,ty,tz;..." (da bordi_torre.gd): scatti da quei punti verso quei punti, con una lampadina sulla camera
		pose = []
		for vv in OS.get_environment("VISTE").split(";"):
			var f := vv.split_floats(",")
			pose.append(["buco_%02d" % pose.size(), Vector3(f[0], f[1], f[2]), Vector3(f[3], f[4], f[5]), 50.0])
		var o := OmniLight3D.new()
		o.omni_range = 6.0
		o.light_energy = 1.5
		cam.add_child(o)
	for v in pose:
		if OS.has_environment("SOLO_RAGGI") and not String(v[0]).begins_with("raggio_"):
			continue
		if OS.has_environment("FILTRO") and not String(v[0]).contains(OS.get_environment("FILTRO")):
			continue
		cam.fov = float(v[3])
		cam.global_position = v[1]
		var su := Vector3.UP if absf(((v[2] as Vector3) - (v[1] as Vector3)).normalized().y) < 0.95 else Vector3.RIGHT
		cam.look_at(v[2], su)
		_accendi(cam.global_position)
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s%s.jpg" % ["prima_" if senza else "", v[0]]), 0.9)
		print("SCATTO ", v[0])
	print("memoria massima del processo %d MB" % (OS.get_static_memory_peak_usage() / 1048576))
	print("FINE")
	get_tree().quit()


## PUNTI="torre,discesa,sala,tunnel" (tutti se manca) sceglie i gruppi di punti.
func _pose_cubo(torre: Node) -> Array:
	var gruppi := OS.get_environment("PUNTI").split(",") if OS.has_environment("PUNTI") else \
			PackedStringArray(["torre", "discesa", "sala", "tunnel"])
	var punti: Array = []
	if gruppi.has("torre"):
		for c in torre.find_children("*", "Checkpoint", true, false):
			punti.append([String(c.name), (c as Checkpoint).get_spawn_transform().origin + Vector3.UP * 1.6])
	if gruppi.has("sala"):
		punti.append_array(_cp_sala)
	if gruppi.has("tunnel") and _tunnel:
		for c in _tunnel.find_children("*", "Checkpoint", true, false):
			punti.append(["tunnel_" + String(c.name), (c as Checkpoint).get_spawn_transform().origin + Vector3.UP * 1.6])
	var percorso: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ambiente/torre/torre_percorso.json"))
	var k := 0
	for q: Dictionary in percorso:
		if not gruppi.has("discesa") or (q["cosa"] != "scivolo" and q["cosa"] != "pedana"):
			continue
		if k % 3 == 0:
			punti.append(["discesa%02d" % k, SalaTorre.b([q["x"], q["y"], q["z"]]) + Vector3.UP * 1.0])
		k += 1
	var dirs := {"est": Vector3(1, 0, 0.001), "ovest": Vector3(-1, 0, 0.001), "nord": Vector3(0.001, 0, -1),
			"sud": Vector3(0.001, 0, 1), "su": Vector3(0.001, 1, 0.002), "giu": Vector3(0.001, -1, 0.002)}
	var out: Array = []
	for p: Array in punti:
		for d: String in dirs:
			out.append(["cubo_%s_%s" % [p[0], d], p[1], (p[1] as Vector3) + dirs[d], 90.0])
	return out


func _accendi(da: Vector3) -> void:
	for nn in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := nn as GeometryInstance3D
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		g.visible = da.clamp(b.position, b.end).distance_to(da) < raggio and bool(_prima[g])
