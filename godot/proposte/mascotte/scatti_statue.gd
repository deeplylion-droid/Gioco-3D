extends Node
## Proposte di posizione delle statue-mascotte: le monta al volo nella sala principale (non tocca la
## scena) e fa gli scatti dal punto di vista del giocatore. Tutta la cartella proposte/ è esclusa
## dall'export.
## Uso (sotto render.lock, con almeno 13,5 GB liberi):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##     --resolution 1600x900 --script res://tests/run.gd -- res://proposte/mascotte/scatti_statue.gd <cartella> \
##     "<statue>" "<scatti>" [frame di attesa]
## <statue>: "modello@x,z@gradi;..." con modello = statua_squalo_A, statua_polpo_A, statua_polpo_B
##   (in assets/models/mascotte/). La y la trova un raggio verso il pavimento; gradi = rotazione su Y
##   (0 = la statua guarda verso +Z, cioè verso l'ingresso a sud della sala).
##   Oggetti da parete: "muro=<percorso res:// senza prefisso>@ox,oy,oz@dx,dy,dz": un raggio da o lungo d
##   trova la parete; l'oggetto (davanti verso +Z, retro a z = 0) ci si appoggia, girato come la parete.
##   Un quarto campo facoltativo "@m" lo scosta di m metri (le piastrelle sporgono dalla collisione).
## <scatti>: "nome:px,py,pz:lx,ly,lz[:i,j];..." il giocatore coi piedi in p guarda verso l; i,j = indici
##   delle sole statue visibili in quello scatto (di serie tutte). Il nome "pianta"
##   fa invece una vista dall'alto ortografica (p = centro, l.x = lato in metri) con una luce in più.
## Variabili: SCATTI_LUCI=BLACKOUT (ritorno al buio), SCATTI_TORCIA=0 (senza torcia), SCATTI_TOGLI.

const LEVEL := "res://scenes/sala_principale.tscn"
var out_dir := "user://scatti_statue"
var statue := ""
var scatti := ""
var settle := 90
var level: Node
var p: Player
var montate: Array[Node3D] = []


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out_dir = a[1]
	statue = a[2]
	scatti = a[3]
	if a.size() > 4:
		settle = int(a[4])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _v(t: String) -> Vector3:
	var c := t.split(",")
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 1)
	level = (load(LEVEL) as PackedScene).instantiate()
	var togli := PackedStringArray(["Interni"])
	togli.append_array(OS.get_environment("SCATTI_TOGLI").split(",", false))
	for percorso in togli:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _frames(10)
	get_tree().paused = false
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for t in level.find_children("*", "Tempesta", true, false):
		(t as Tempesta).automatica = false
	if OS.get_environment("SCATTI_LUCI") == "BLACKOUT":
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
		await _frames(5)
	var lamp := level.get_node_or_null("Vasca/Sfarfallio")
	if lamp and lamp.has_method("turn_on") and OS.get_environment("SCATTI_LUCI") != "BLACKOUT":
		lamp.turn_on()
	p.stand_eye_height = 1.7
	await _frames(5)
	_monta_statue()
	var luce := p.find_child("*orcia*", true, false)
	if luce and luce is Node3D:
		(luce as Node3D).visible = OS.get_environment("SCATTI_TORCIA") != "0"
	for s in scatti.split(";", false):
		var c := s.split(":")
		for i in montate.size():
			montate[i].visible = c.size() < 4 or str(i) in c[3].split(",")
		if c[0].begins_with("pianta"):
			await _pianta(c[0], _v(c[1]), _v(c[2]).x)
			continue
		p.teleport(_v(c[1]), 0.0, 0.0)
		p.set_physics_process(false)
		p.velocity = Vector3.ZERO
		p.look_at_point(_v(c[2]))
		await _frames(settle)
		p.look_at_point(_v(c[2]))
		await _frames(2)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(c[0] + ".jpg"), 0.92)
		print("salvato ", c[0])
	get_tree().quit()


## Le statue: appoggiate al pavimento trovato da un raggio; si controlla che il loro ingombro
## (un cilindro poco sopra il pavimento) non tocchi niente.
func _monta_statue() -> void:
	var spazio := (level as Node3D).get_world_3d().direct_space_state
	for s in statue.split(";", false):
		var c := s.split("@")
		if c[0].begins_with("muro="):
			_monta_a_muro(spazio, c[0].substr(5), _v(c[1]), _v(c[2]), float(c[3]) if c.size() > 3 else 0.003)
			continue
		var xz := c[1].split(",")
		var x := float(xz[0])
		var z := float(xz[1])
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 3.0, z), Vector3(x, -6.0, z))
		var hit := spazio.intersect_ray(q)
		var y := 0.0
		if hit:
			y = (hit.position as Vector3).y
		else:
			print("ATTENZIONE ", c[0], ": nessun pavimento sotto (", x, ", ", z, ")")
		var st := (load("res://assets/models/mascotte/%s.glb" % c[0]) as PackedScene).instantiate() as Node3D
		level.add_child(st)
		montate.append(st)
		st.global_position = Vector3(x, y, z)
		st.rotation.y = deg_to_rad(float(c[2]))
		# ingombro: il basamento ha raggio circa 0,55 m (statua alta 2,3 m)
		var cil := CylinderShape3D.new()
		cil.radius = 0.6
		cil.height = 2.0
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = cil
		sq.transform = Transform3D(Basis(), Vector3(x, y + 1.15, z))
		sq.exclude = [p.get_rid()]
		var tocca := spazio.intersect_shape(sq, 8)
		var nomi := PackedStringArray()
		for t in tocca:
			nomi.append(str((t.collider as Node).get_path()))
		print("STATUA ", c[0], " in (%.2f, %.2f, %.2f) " % [x, y, z],
			"libera" if nomi.is_empty() else "TOCCA " + ", ".join(nomi))


func _monta_a_muro(spazio: PhysicsDirectSpaceState3D, percorso: String, o: Vector3, d: Vector3, scosta: float) -> void:
	var q := PhysicsRayQueryParameters3D.create(o, o + d.normalized() * 25.0)
	q.exclude = [p.get_rid()]
	var hit := spazio.intersect_ray(q)
	var ob := (load("res://" + percorso) as PackedScene).instantiate() as Node3D
	level.add_child(ob)
	montate.append(ob)
	if not hit:
		print("ATTENZIONE ", percorso, ": nessuna parete da ", o, " verso ", d)
		ob.global_position = o
		return
	var n: Vector3 = hit.normal
	var pos: Vector3 = hit.position + n * scosta
	ob.global_transform = Transform3D(Basis.looking_at(-n, Vector3.UP), pos)
	print("MURO ", percorso, " su ", (hit.collider as Node).get_path(), " in ", pos, " normale ", n)


func _pianta(nome: String, centro: Vector3, lato: float) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = lato
	cam.near = 0.05
	cam.far = 30.0
	level.add_child(cam)
	cam.global_position = centro
	cam.rotation = Vector3(deg_to_rad(-90), 0, 0)   # guarda in basso, con il nord (-Z) in alto
	cam.make_current()
	var sole := DirectionalLight3D.new()
	sole.rotation = Vector3(deg_to_rad(-80), deg_to_rad(20), 0)
	sole.light_energy = 3.0
	level.add_child(sole)
	await _frames(settle)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(nome + ".jpg"), 0.92)
	print("salvato ", nome)
	sole.queue_free()
	cam.queue_free()
	p.camera.make_current()
