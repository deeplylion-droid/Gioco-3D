extends Node
## Collaudo delle scatole colorate nei muri di pile del fiume (scenes/risalita/fiume.tscn, da solo, coi materiali veri e
## una luce d'ambiente come scatti_fiume_gioco.gd). Scatta:
## - le viste di scatti_fiume_gioco.gd dalla ciambella e a piedi (ingresso, piazza, imbarco, rami, approdo);
## - per N scatole colorate scelte lungo il fiume (le più vicine all'ingresso, alla piazza e sparse), due ravvicinati
##   della loro pila, uno per lato (davanti e dietro, lungo la profondità della pila), all'altezza della scatola;
## - un ravvicinato di lato (lungo il muro) per vedere le scatole di fianco.
## Scrive anche elenco.txt con le scatole guardate (posizione, colore) e i conteggi.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd \
##        -- res://tests/collaudo/scatti_scatole_fiume.gd <cartella> [quante scatole, 12]

const F := preload("res://scripts/risalita/fiume_gioco.gd")
const S := preload("res://tests/scatti_fiume_gioco.gd")
const VISTE := ["porta_ingresso", "piazza", "imbarco", "bivio1", "ramo", "bivio3", "approdo", "porta_approdo", "tiki"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var quante := int(a[2]) if a.size() > 2 else 12
	DirAccess.make_dir_recursive_absolute(out)
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.2, 0.18, 0.17)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.1
	e.ssao_enabled = true
	we.environment = e
	get_tree().root.add_child(we)
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(f)
	# (le pile si fanno a pezzi, con delle pause: si aspetta che ci siano)
	var col: MultiMeshInstance3D = null
	for i in 1200:
		await get_tree().process_frame
		col = f.find_child("PileScatoleColorate", true, false) as MultiMeshInstance3D
		if col:
			break
	for i in 30:
		await get_tree().process_frame
	var righe := PackedStringArray()
	for nome in ["PileCasse", "PileCartone", "PileScatole", "PileScatoleColorate"]:
		var m := f.find_child(nome, true, false) as MultiMeshInstance3D
		righe.append("%s: %d istanze" % [nome, m.multimesh.instance_count if m else -1])
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 200.0
	get_tree().root.add_child(cam)
	cam.make_current()
	var luce := OmniLight3D.new()
	luce.light_energy = 0.6
	luce.omni_range = 6.0
	cam.add_child(luce)
	var tutte := S.camere()
	for nome in VISTE:
		var c: Array = tutte[nome]
		await _scatta(cam, c[0], c[1], out.path_join("vista_%s.jpg" % nome))
	# le scatole colorate da guardare: le più vicine ai due punti allegri e altre sparse
	var mm := col.multimesh
	var scelte: Array[int] = []
	for q in F.PUNTI_ALLEGRI:
		var migliore := -1
		var dmin := INF
		for i in mm.instance_count:
			var p := (col.global_transform * mm.get_instance_transform(i)).origin
			var d := Vector2(p.x, p.z).distance_to(q)
			if d < dmin and not scelte.has(i):
				dmin = d
				migliore = i
		scelte.append(migliore)
	var passo := maxi(mm.instance_count / maxi(quante - 2, 1), 1)
	var i0 := passo / 2
	while scelte.size() < quante and i0 < mm.instance_count:
		if not scelte.has(i0):
			scelte.append(i0)
		i0 += passo
	var k := 0
	for i in scelte:
		k += 1
		var t := col.global_transform * mm.get_instance_transform(i)
		var c := t.origin
		var prof := (t.basis.z * Vector3(1, 0, 1)).normalized()
		var lungo := (t.basis.x * Vector3(1, 0, 1)).normalized()
		var tinta := mm.get_instance_color(i)
		righe.append("scatola %02d (istanza %d): %.2f %.2f %.2f, colore %s" % [k, i, c.x, c.y, c.z, tinta.to_html(false)])
		for lato: float in [1.0, -1.0]:
			var da: Vector3 = c + prof * lato * 1.9 + Vector3(0, 0.35, 0) + lungo * 0.5
			await _scatta(cam, da, c, out.path_join("scatola_%02d_%s.jpg" % [k, "davanti" if lato > 0 else "dietro"]))
		await _scatta(cam, c + lungo * 2.2 + prof * 0.6 + Vector3(0, 0.3, 0), c, out.path_join("scatola_%02d_fianco.jpg" % k))
	var fh := FileAccess.open(out.path_join("elenco.txt"), FileAccess.WRITE)
	fh.store_string("\n".join(righe) + "\n")
	fh.close()
	print("\n".join(righe))
	get_tree().quit()


func _scatta(cam: Camera3D, da: Vector3, verso: Vector3, file: String) -> void:
	cam.global_position = da
	cam.look_at(verso, Vector3.UP)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(file, 0.88)
