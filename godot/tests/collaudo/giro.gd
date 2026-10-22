extends Node
## Collaudo del posizionamento (squadra collaudo): scatti dagli occhi del giocatore, da una lista di punti, in
## uno stato del capitolo (stati.gd). Serve un vero renderer; gli scatti sono piccoli e senza GI né effetti
## pesanti: servono a vedere gli oggetti, non la luce. Una luce bianca sulla camera fa vedere i posti bui.
## Uso (sotto il render.lock, con almeno 13,5 GB liberi):
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##       --resolution 640x360 --script res://tests/run.gd -- res://tests/collaudo/giro.gd \
##       <scena.tscn> <stato> <cartella> <lista dei punti> [nodi da togliere, separati da virgola] [fov]
## La lista (scritta da tools/collaudo/punti_giro.py, o a mano) ha una riga per scatto:
##   nome px py pz yaw pitch      (camera in p, yaw e pitch in gradi; yaw 0 guarda verso -z)
## Le righe che cominciano con "luce" cambiano l'energia della luce sulla camera (luce 0 la spegne).
## La riga "origine x y z" dice dove sta la scena dentro sala_principale (per esempio gli interni da soli:
## origine -9.7 0 40.9): le coordinate delle righe dopo restano quelle del mondo della sala.
## Le righe "mira nome cx cy cz distanza" fanno due scatti ravvicinati di un oggetto (nome_a e nome_b): la camera
## sta a quella distanza dal centro, dalla parte più libera (raggi sul mondo, 30 gradi più in alto), e di lato
## (70 gradi più in là), guardando il centro.

const STATI := preload("res://tests/collaudo/stati.gd")

var scena := ""
var stato := "inizio"
var cartella := ""
var lista := ""
var togli := PackedStringArray()
var fov := 75.0
var settle := 4


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	var a := OS.get_cmdline_user_args()
	scena = a[1]
	stato = a[2]
	cartella = a[3]
	lista = a[4]
	if a.size() > 5 and a[5] != "":
		togli = a[5].split(",")
	if a.size() > 6:
		fov = float(a[6])
	if OS.get_environment("COLLAUDO_SETTLE") != "":
		settle = int(OS.get_environment("COLLAUDO_SETTLE"))
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("basso")
	Grafica.imposta("scala_rendering", 1.0)
	Grafica.imposta("ombre", 1)
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 0)
	var livello := (load(scena) as PackedScene).instantiate()
	for percorso in togli:
		var n := livello.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 30:
		await get_tree().process_frame
	get_tree().paused = false
	var p = GameState.player
	for i in 900:
		if p == null or not is_instance_valid(p) or p.input_enabled:
			break
		await get_tree().process_frame
	STATI.applica(livello, stato)
	for t in livello.find_children("*", "Tempesta", true, false):
		t.set(&"automatica", false)
	for i in 240:
		await get_tree().process_frame
	if p and is_instance_valid(p):
		var hud = p.get_node_or_null(^"HUD")
		if hud:
			hud.visible = false
		p.set_physics_process(false)
		p.set_process(false)
		p.visible = false
		var torcia = p.find_child("*orcia*", true, false)
		if torcia is Node3D:
			torcia.visible = false
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.03
	cam.far = 150.0
	livello.add_child(cam)
	cam.make_current()
	var luce := OmniLight3D.new()
	luce.omni_range = 18.0
	luce.light_energy = 1.6
	luce.omni_attenuation = 0.8
	luce.shadow_enabled = true
	cam.add_child(luce)
	var righe := FileAccess.get_file_as_string(lista).split("\n", false)
	var fatti := 0
	var origine := Vector3.ZERO
	for r in righe:
		var c := r.strip_edges().split(" ", false)
		if c.size() < 2 or c[0].begins_with("#"):
			continue
		if c[0] == "luce":
			luce.light_energy = float(c[1])
			luce.visible = luce.light_energy > 0.0
			continue
		if c[0] == "origine":
			origine = Vector3(float(c[1]), float(c[2]), float(c[3]))
			continue
		if c[0] == "mira":
			await _mira(cam, c[1], Vector3(float(c[2]), float(c[3]), float(c[4])) - origine, float(c[5]))
			fatti += 2
			continue
		var pos := Vector3(float(c[1]), float(c[2]), float(c[3])) - origine
		cam.global_position = pos
		cam.rotation_degrees = Vector3(float(c[5]) if c.size() > 5 else 0.0, float(c[4]), 0.0)
		for i in settle:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join(c[0] + ".jpg"), 0.8)
		fatti += 1
		if fatti % 50 == 0:
			print("COLLAUDO: %d scatti" % fatti)
	print("COLLAUDO: finito, %d scatti" % fatti)
	get_tree().quit()


func _mira(cam: Camera3D, nome: String, centro: Vector3, dist: float) -> void:
	var spazio := cam.get_world_3d().direct_space_state
	var migliore := -1.0
	var dir := Vector3.FORWARD
	for i in 16:
		var ang := TAU * i / 16.0
		for alto in [0.5, 0.15, 0.9]:
			var d := Vector3(cos(ang), alto, sin(ang)).normalized()
			var q := PhysicsRayQueryParameters3D.create(centro + d * 0.05, centro + d * (dist + 0.3), Layers.WORLD)
			var h := spazio.intersect_ray(q)
			var libero: float = dist + 0.3 if h.is_empty() else centro.distance_to(h.position)
			if libero > migliore + 0.01:
				migliore = libero
				dir = d
	for k in 2:
		var d := dir if k == 0 else dir.rotated(Vector3.UP, deg_to_rad(70.0))
		var dd := minf(dist, maxf(migliore - 0.1, 0.25)) if k == 0 else dist
		cam.global_position = centro + d * dd
		cam.look_at(centro, Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD)
		cam.fov = 50.0
		for i in settle:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s_%s.jpg" % [nome, "a" if k == 0 else "b"]), 0.85)
	cam.fov = fov
