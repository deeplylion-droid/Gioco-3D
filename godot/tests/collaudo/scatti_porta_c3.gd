extends Node
## Scatti della cima della scala di servizio verso la porta di C3 (segnalazione dell'utente sulla 0.3.21: "che è quella
## texture grigia sulla parete? sembra un glitch"). Le stesse pose in due modi:
## - "sala" (il gioco vero): la sala principale per parti (il corridoio C3 di Tecnici e la Risalita), con le
##   mesh accese solo vicino alla camera, come ricontrollo_area_bimbi.gd (la sala intera con
##   llvmpipe non ci sta in memoria);
## - "prova": la scena di prova della Risalita da sola (tests/scene/risalita_prova.tscn), dove oltre la porta di C3 non
##   c'è niente e si vede il cielo.
## In tutti e due l'ambiente di pozze_giro.gd (quello della sala senza GI, nebbia volumetrica e SSIL) e il blackout:
## cambia solo quello che c'è oltre la porta.
## Le pose: gli occhi a 1,6 m sulla strada di pozze_giro.gd (dalla cima della scala, Marker/CimaScala, alla porta di C3,
## Marker/PortaC3), ogni 0,75 m, guardando la porta.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_porta_c3.gd <cartella> sala|prova

const SALA := "res://scenes/sala_principale.tscn"
const PROVA := "res://tests/scene/risalita_prova.tscn"
const PARTI := ["Tecnici/Ambienti/Raccordo", "Risalita"]

var raggio := 20.0
var _cartella := ""
var _modo := "sala"
var _radice: Node3D
var _prima := {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "/tmp/scatti_porta_c3"
	_modo = a[2] if a.size() > 2 else "sala"
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	var cam := Camera3D.new()
	cam.fov = 75.0
	if _modo == "prova":
		var s := (load(PROVA) as PackedScene).instantiate() as Node3D
		get_tree().root.add_child(s)
		get_tree().current_scene = s
		_radice = s
		for i in 30:
			await get_tree().process_frame
		var pl := s.get_node_or_null(^"Player")
		if pl:
			pl.process_mode = Node.PROCESS_MODE_DISABLED
			for h in pl.find_children("*", "CanvasLayer", true, false):
				(h as CanvasLayer).visible = false
		s.add_child(cam)
	else:
		_radice = Node3D.new()
		_radice.name = "SalaPerScatti"
		var tutta := (load(SALA) as PackedScene).instantiate()
		for percorso in PARTI:
			var n := tutta.get_node_or_null(NodePath(percorso)) as Node3D
			if n == null:
				print("manca ", percorso)
				continue
			var tr := _globale(n, tutta)
			n.get_parent().remove_child(n)
			n.transform = tr
			if n.name == &"Risalita":
				n.set(&"a_richiesta", false)   # come nella scena di prova: senza i campioni dei materiali da compilare
			_radice.add_child(n)
		tutta.free()
		_luci_tecnici()
		_radice.add_child(cam)
		get_tree().root.add_child(_radice)
		get_tree().current_scene = _radice
		for i in 30:
			await get_tree().process_frame
	var we := WorldEnvironment.new()
	we.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	we.environment.sdfgi_enabled = false
	we.environment.volumetric_fog_enabled = false
	we.environment.ssil_enabled = false
	_radice.add_child(we)
	cam.make_current()
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	DirAccess.make_dir_recursive_absolute(_cartella)
	for i in 10:
		await get_tree().process_frame
	if OS.has_environment("LUCI"):
		for l in _radice.find_children("*", "Light3D", true, false):
			var lu := l as Light3D
			if lu.is_visible_in_tree() and lu.global_position.distance_to(Vector3(-22, 1, 38.45)) < 25.0:
				print("LUCE %s %s energia %.2f colore %s" % [_radice.get_path_to(lu), lu.global_position.snapped(Vector3.ONE * 0.1), lu.light_energy, lu.light_color])
	var ris := _radice.find_child("Risalita", true, false) as Node3D
	var m := ris.get_node(^"Marker")
	var cima := (m.get_node(^"CimaScala") as Node3D).global_position
	var c3 := (m.get_node(^"PortaC3") as Node3D).global_position
	var passi := int(ceil(cima.distance_to(c3) / 0.75))
	for k in passi:
		var occhio := cima.lerp(c3, float(k) / passi) + Vector3.UP * 1.6
		cam.global_position = occhio
		cam.look_at(Vector3(c3.x, occhio.y - 0.2, c3.z), Vector3.UP)
		if _modo == "sala":
			_accendi(occhio)
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(_cartella.path_join("%s_%02d.jpg" % [_modo, k]), 0.9)
		print("SCATTO %d da %s, a %.1f m dalla porta" % [k, occhio.snapped(Vector3.ONE * 0.01), Vector2(occhio.x - c3.x, occhio.z - c3.z).length()])
	print("memoria massima del processo %d MB" % (OS.get_static_memory_peak_usage() / 1048576))
	print("FINE")
	get_tree().quit()


## Le luci del corridoio C3 come le sistema tecnici.gd (_luci): le rosse del modello diventano luci d'emergenza, le altre
## si abbassano (nel modello sono in unità di Blender).
func _luci_tecnici() -> void:
	var r := _radice.get_node(^"Raccordo")
	var i := 0
	for l in r.find_children("LUCE_rossa_*", "Light3D", true, false):
		var le: Node3D = (load("res://addons/grafica/luce_emergenza.gd") as GDScript).new()
		le.set(&"modalita", 1 if i % 3 == 2 else 0)
		le.set(&"energia", 2.0)
		le.set(&"portata", 8.0)
		le.set(&"energia_nebbia", 0.4)
		le.set(&"ombre", i % 2 == 0)
		l.get_parent().add_child(le)
		le.global_position = (l as Node3D).global_position
		(l as Light3D).visible = false
		i += 1
	for l in r.find_children("LUCE_*", "Light3D", true, false):
		if l.visible and not String(l.name).begins_with("LUCE_rossa_"):
			l.light_energy = minf(l.light_energy, 2.0)
			if l is OmniLight3D:
				(l as OmniLight3D).omni_range = 6.0
			l.shadow_enabled = true


func _accendi(da: Vector3) -> void:
	var n_accese := 0
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		var vicino := da.clamp(b.position, b.end).distance_to(da) < raggio and bool(_prima[g])
		if vicino:
			n_accese += 1
		g.visible = vicino
	print("mesh accese %d di %d" % [n_accese, _prima.size()])


func _globale(n: Node3D, radice: Node) -> Transform3D:
	var t := n.transform
	var q := n.get_parent()
	while q and q != radice:
		if q is Node3D:
			t = (q as Node3D).transform * t
		q = q.get_parent()
	return t
