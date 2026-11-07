extends Node
## Sonda della riga chiara a pelo d'acqua nel fiume lento (#130): rifà la camera di Giusto1 a 37 m (a sinistra) del
## collaudo di mascotte e trova per bisezione quale oggetto disegna la riga. Nasconde metà degli oggetti visibili e
## guarda se la riga c'è ancora: la misura è il contrasto fra i pixel della riga e quelli 14 px sopra, dopo che
## l'esposizione automatica si è assestata. Poi stampa il colpevole e salva gli scatti con e senza.
## Uso (sotto il render.lock): CARTELLA=<dir> xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##   --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/sonda_riga_fiume.gd

const PIXEL := [Vector2(467, 583), Vector2(125, 624), Vector2(800, 537)]


func _ready() -> void:
	_run.call_deferred()


func _contrasto() -> float:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var somma := 0.0
	for p: Vector2 in PIXEL:
		somma += img.get_pixelv(p).get_luminance() - img.get_pixelv(p + Vector2(0, -14)).get_luminance()
	return somma / PIXEL.size()


func _salva(nome: String) -> void:
	var cart := OS.get_environment("CARTELLA")
	if cart != "":
		get_viewport().get_texture().get_image().save_jpg(cart + "/" + nome + ".jpg", 0.9)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.BLACKOUT
	Grafica.applica_preset("alto")
	var we := WorldEnvironment.new()
	we.environment = load("res://addons/grafica/sala/ambiente_sala.tres") as Environment
	we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(we)
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	for i in 240:
		await get_tree().process_frame
	var t := f.find_child("Giusto1", true, false) as TrattoFiume
	var p := t.punto(37.0) + Vector3.UP * 1.65
	var d := t.direzione(37.0)
	d.y = 0.0
	var dir := d.normalized().rotated(Vector3.UP, deg_to_rad(70.0))
	cam.global_position = p
	cam.look_at(p + dir * 10.0 + Vector3.DOWN * 0.9, Vector3.UP)
	for i in 400:
		await get_tree().process_frame
	var base := await _contrasto()
	_salva("bis_com_e")
	print("SONDA camera %s" % cam.global_position.snapped(Vector3.ONE * 0.01))
	if OS.get_environment("PROVA") == "muro_due_facce":
		for g in f.find_children("*", "MeshInstance3D", true, false):
			var mi := g as MeshInstance3D
			var mt = mi.material_override if mi.material_override else (mi.mesh.surface_get_material(0) if mi.mesh else null)
			if mt and String(mt.resource_path).ends_with("mat_mosaico_blu.tres"):
				var nero := StandardMaterial3D.new()
				nero.albedo_color = Color(0.3, 0.0, 0.0)
				nero.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.material_override = nero
				print("SONDA muro a due facce: %s %s" % [mi.name, mi.global_transform * mi.get_aabb()])
		print("SONDA con i muri a due facce il contrasto è %.3f" % await _contrasto())
		_salva("bis_muro_due_facce")
		get_tree().quit()
		return
	var tutti: Array = []
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		if (n as GeometryInstance3D).is_visible_in_tree():
			tutti.append(n)
	print("SONDA contrasto della riga %.3f; oggetti visibili %d" % [base, tutti.size()])
	var soglia := base * 0.5
	var lista := tutti
	while lista.size() > 1:
		var meta := lista.slice(0, lista.size() / 2)
		for n in meta:
			(n as GeometryInstance3D).visible = false
		var c := await _contrasto()
		for n in meta:
			(n as GeometryInstance3D).visible = true
		lista = meta if c < soglia else lista.slice(lista.size() / 2)
		print("SONDA restano %d (contrasto senza la prima metà %.3f)" % [lista.size(), c])
	var g := lista[0] as GeometryInstance3D
	var mt = g.material_override
	if mt == null and g is MeshInstance3D and (g as MeshInstance3D).mesh:
		mt = (g as MeshInstance3D).mesh.surface_get_material(0)
	print("SONDA COLPEVOLE: %s (%s) aabb %s materiale %s shader %s" % [g.get_path(), g.get_class(), g.global_transform * g.get_aabb(),
			mt.resource_path if mt else "-", (mt as ShaderMaterial).shader.resource_path if mt is ShaderMaterial and (mt as ShaderMaterial).shader else "-"])
	g.visible = false
	print("SONDA senza il colpevole il contrasto è %.3f" % await _contrasto())
	_salva("bis_senza_colpevole")
	get_tree().quit()
