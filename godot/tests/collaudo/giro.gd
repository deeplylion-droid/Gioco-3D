extends Node
## Collaudo del posizionamento (squadra collaudo): scatti dagli occhi del giocatore, da una lista di punti, in
## uno stato del capitolo (stati.gd). Serve un vero renderer; gli scatti sono piccoli e senza GI né effetti
## pesanti: servono a vedere gli oggetti, non la luce. Una luce bianca sulla camera fa vedere i posti bui.
## Uso (sotto il render.lock, con almeno 13,5 GB liberi):
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##       --resolution 640x360 --script res://tests/run.gd -- res://tests/collaudo/giro.gd \
##       <scena.tscn> <stato> <cartella> <lista dei punti> [nodi da togliere, separati da virgola] [fov]
## La lista (scritta da tools/collaudo/punti_giro.py, o a mano) ha una riga per scatto:
##   nome px py pz yaw pitch [fov]      (camera in p, yaw e pitch in gradi; yaw 0 guarda verso -z)
## Le righe che cominciano con "luce" cambiano l'energia della luce sulla camera (luce 0 la spegne).
## La riga "origine x y z" dice dove sta la scena dentro sala_principale (per esempio gli interni da soli:
## origine -9.7 0 40.9): le coordinate delle righe dopo restano quelle del mondo della sala.
## Le righe "mira nome cx cy cz distanza" fanno due scatti ravvicinati di un oggetto (nome_a e nome_b): la camera
## sta a quella distanza dal centro, dalla parte più libera (raggi sul mondo, 30 gradi più in alto), e di lato
## (70 gradi più in là), guardando il centro.
## Le righe "spazio nome px py pz qx qy qz" fanno due scatti dello spazio fra un oggetto (p) e la cosa più vicina
## (q), di traverso rispetto a p-q: uno da vicino (nome_v, 35 cm, campo di 40 gradi) e uno più largo (nome_l, 1,2 m).

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
	# COLLAUDO_OMBRE=0: niente ombre (meno pipeline sul renderer software: la sala intera non entra in memoria)
	var ombre := OS.get_environment("COLLAUDO_OMBRE") != "0"
	Grafica.imposta("ombre", 1 if ombre else 0)
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 0)
	var livello := (load(scena) as PackedScene).instantiate()
	for percorso in togli:
		var n := livello.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	# per la memoria: GI, sonde dei riflessi, particelle e volumi di nebbia non servono a vedere dove stanno gli
	# oggetti (la sala intera sul renderer software se no supera i 15 GB della macchina)
	var tolti := 0
	for classe in ["VoxelGI", "LightmapGI", "ReflectionProbe", "GPUParticles3D", "CPUParticles3D", "FogVolume"]:
		for n in livello.find_children("*", classe, true, false):
			if _nel_giocatore(n):
				continue   # le particelle dello zaino: il giocatore le usa nel suo _ready
			n.get_parent().remove_child(n)
			n.free()
			tolti += 1
	print("COLLAUDO: tolti %d nodi di GI, riflessi, particelle e nebbia" % tolti)
	if OS.get_environment("COLLAUDO_SEMPLICE") == "1":
		_materiali_semplici(livello)
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 30:
		await get_tree().process_frame
	get_tree().paused = false
	var p = GameState.player
	if not togli.is_empty() and p and is_instance_valid(p):
		# senza gli interni il giocatore (che parte nel corridoio) cadrebbe nel vuoto e morirebbe: si ferma subito
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.visible = false
	for i in 900:
		if p == null or not is_instance_valid(p) or p.input_enabled or p.process_mode == Node.PROCESS_MODE_DISABLED:
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
	luce.shadow_enabled = ombre
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
		if c[0] == "spazio":
			var pp := Vector3(float(c[2]), float(c[3]), float(c[4])) - origine
			var qq := Vector3(float(c[5]), float(c[6]), float(c[7])) - origine
			await _spazio(cam, c[1], pp, qq)
			fatti += 2
			continue
		if c[0] == "mira":
			await _mira(cam, c[1], Vector3(float(c[2]), float(c[3]), float(c[4])) - origine, float(c[5]))
			fatti += 2
			continue
		var pos := Vector3(float(c[1]), float(c[2]), float(c[3])) - origine
		cam.global_position = pos
		cam.rotation_degrees = Vector3(float(c[5]) if c.size() > 5 else 0.0, float(c[4]), 0.0)
		cam.fov = float(c[6]) if c.size() > 6 else fov
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
	var dirs := []   # [libero, direzione]
	for i in 16:
		var ang := TAU * i / 16.0
		for alto in [0.5, 0.15, 0.9]:
			var d := Vector3(cos(ang), alto, sin(ang)).normalized()
			var q := PhysicsRayQueryParameters3D.create(centro + d * 0.05, centro + d * (dist + 0.3), Layers.WORLD)
			var h := spazio.intersect_ray(q)
			var libero: float = dist + 0.3 if h.is_empty() else centro.distance_to(h.position)
			dirs.append([libero + alto * 0.05, d])
	dirs.sort_custom(func(x, y): return x[0] > y[0])
	var prima: Array = dirs[0]
	var seconda: Array = prima
	# di lato: la più libera fra quelle ad almeno 60 gradi dalla prima
	for x in dirs:
		if Vector2(x[1].x, x[1].z).angle_to(Vector2(prima[1].x, prima[1].z)) > deg_to_rad(60.0) or Vector2(x[1].x, x[1].z).angle_to(Vector2(prima[1].x, prima[1].z)) < -deg_to_rad(60.0):
			seconda = x
			break
	for k in 2:
		var scelta: Array = prima if k == 0 else seconda
		var d: Vector3 = scelta[1]
		var dd := minf(dist, maxf(float(scelta[0]) - 0.1, 0.25))
		cam.global_position = centro + d * dd
		cam.look_at(centro, Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD)
		cam.fov = 50.0
		for i in settle:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s_%s.jpg" % [nome, "a" if k == 0 else "b"]), 0.85)
	cam.fov = fov


func _spazio(cam: Camera3D, nome: String, p: Vector3, q: Vector3) -> void:
	var spazio := cam.get_world_3d().direct_space_state
	var centro := (p + q) * 0.5
	var g := q - p
	g = g.normalized() if g.length() > 0.0001 else Vector3.UP
	# direzioni di traverso rispetto allo stacco, un po' dall'alto: la più libera
	var base := g.cross(Vector3.UP)
	if base.length() < 0.1:
		base = g.cross(Vector3.RIGHT)
	base = base.normalized()
	var migliore := -1.0
	var dir := base
	for i in 24:
		var d := base.rotated(g, TAU * i / 24.0)
		var q_ := PhysicsRayQueryParameters3D.create(centro + d * 0.03, centro + d * 1.5, Layers.WORLD)
		var h := spazio.intersect_ray(q_)
		var libero: float = 1.5 if h.is_empty() else centro.distance_to(h.position)
		libero += d.y * 0.2   # a parità, da sopra (come il giocatore)
		if libero > migliore:
			migliore = libero
			dir = d
	for k in 2:
		var dist := 0.35 if k == 0 else 1.2
		dist = minf(dist, maxf(migliore - 0.05, 0.12))
		cam.global_position = centro + dir * dist
		cam.look_at(centro, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
		cam.fov = 40.0 if k == 0 else 60.0
		for i in settle:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s_%s.jpg" % [nome, "v" if k == 0 else "l"]), 0.85)
	cam.fov = fov


var _colori := {}      # texture -> colore medio
var _semplici := {}    # colore (quantizzato) -> materiale


## COLLAUDO_SEMPLICE=1: ogni superficie prende un materiale semplice del colore medio del suo (albedo per la
## texture), e le texture si liberano. Così la sala intera entra nella memoria del renderer software: per vedere
## dove stanno gli oggetti bastano le forme e i colori.
func _materiali_semplici(radice: Node) -> void:
	var fatti := 0
	for n in radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			var mi := g as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var m: Material = mi.get_surface_override_material(i)
				if m == null:
					m = mi.mesh.surface_get_material(i)
				if g.material_override:
					m = g.material_override
				mi.set_surface_override_material(i, _semplice(m))
				mi.mesh.surface_set_material(i, null)
				fatti += 1
			g.material_override = null
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh and (g as MultiMeshInstance3D).multimesh.mesh:
			var mesh := (g as MultiMeshInstance3D).multimesh.mesh
			var m: Material = g.material_override if g.material_override else (mesh.surface_get_material(0) if mesh.get_surface_count() > 0 else null)
			g.material_override = _semplice(m)
			for i in mesh.get_surface_count():
				mesh.surface_set_material(i, null)
			fatti += 1
	print("COLLAUDO: %d superfici con materiale semplice, %d colori" % [fatti, _semplici.size()])


func _semplice(m: Material) -> Material:
	var c := Color(0.6, 0.6, 0.6)
	var trasp := false
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		c = b.albedo_color
		var t := b.albedo_texture
		if t:
			c *= _medio(t)
		trasp = b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and c.a < 0.95
		if b.emission_enabled:
			c = c.lerp(b.emission, 0.5)
	elif m is ShaderMaterial:
		c = Color(0.35, 0.55, 0.7, 0.6)   # acqua e simili
		trasp = true
	var k := Color(snappedf(c.r, 0.04), snappedf(c.g, 0.04), snappedf(c.b, 0.04), 0.6 if trasp else 1.0)
	if not _semplici.has(k):
		var s := StandardMaterial3D.new()
		s.albedo_color = k
		s.roughness = 0.8
		if trasp:
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s.cull_mode = BaseMaterial3D.CULL_DISABLED
		_semplici[k] = s
	return _semplici[k]


func _medio(t: Texture2D) -> Color:
	if _colori.has(t):
		return _colori[t]
	var c := Color(0.6, 0.6, 0.6)
	var img := t.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		while img.get_width() > 4 and img.get_height() > 4:
			img.shrink_x2()
		var somma := Color(0, 0, 0, 0)
		for y in img.get_height():
			for x in img.get_width():
				somma += img.get_pixel(x, y)
		c = somma / float(img.get_width() * img.get_height())
		c.a = 1.0
	_colori[t] = c
	return c


func _nel_giocatore(n: Node) -> bool:
	while n:
		if n is CharacterBody3D:
			return true
		n = n.get_parent()
	return false
