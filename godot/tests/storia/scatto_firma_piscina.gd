extends Node
## Scatto del disegno della piscina dei giocattoli (col cartone e le fascette) dagli occhi del giocatore: per vedere che
## la firma del bambino con la scatola (0.5.0) è dritta e in basso a destra. Solo la sala, senza le zone pesanti (sul
## renderer software la sala intera non entra in memoria), con le sue luci; la camera a 1,6 m sopra il pavimento davanti
## al cartone, a 1,8 m. Due scatti: da lontano e da vicino alla firma.
## Uso (sotto il lock, con almeno 13,5 GB liberi):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/storia/scatto_firma_piscina.gd <cartella>

const SALA := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var cartella := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "/tmp"
	# una radice nuova con gli stessi nomi, solo con sala, luci, atmosfera e piscina (e Polaroid, a cui punta
	# l'enigma): la logica della sala, che prepara e carica le altre zone, resta fuori (è lei che riempie la memoria)
	var tutta := (load(SALA) as PackedScene).instantiate() as Node3D
	var lv := Node3D.new()
	lv.name = "SalaPerScatto"
	for nome in ["Sala", "LuciSala", "Atmosfera", "Piscina", "Polaroid"]:
		var n := tutta.get_node_or_null(NodePath(nome))
		if n:
			n.owner = null
			tutta.remove_child(n)
			lv.add_child(n)
	tutta.free()
	get_tree().root.add_child(lv)
	# (subito, prima del primo disegno: accese solo le mesh entro 20 m dal disegno, come negli scatti della sala per
	# parti; la memoria del renderer software la prende la preparazione dei materiali)
	var centro := Vector3(-17.0, 1.79, -14.67)
	for g in lv.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		var aabb := gi.global_transform * gi.get_aabb()
		if aabb.get_center().distance_to(centro) - aabb.size.length() * 0.5 > 20.0:
			gi.visible = false
	for i in 120:
		await get_tree().process_frame
	var past: MeshInstance3D = null
	for m in lv.find_children("Pastelli", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
		if mat and mat.albedo_texture and "disegno_piscina" in mat.albedo_texture.resource_path:
			past = m
	if past == null:
		print("SCATTO: niente disegno della piscina")
		get_tree().quit(1)
		return
	var c := past.global_position
	var n := past.global_basis.z.normalized()
	var space := lv.get_world_3d().direct_space_state
	var occhio := c + n * 1.8
	var giu := space.intersect_ray(PhysicsRayQueryParameters3D.create(occhio, occhio + Vector3.DOWN * 6.0))
	if giu:
		occhio.y = (giu.position as Vector3).y + 1.6
	print("SCATTO: disegno in %s, normale %s, occhio %s" % [c, n, occhio])
	var cam := Camera3D.new()
	lv.add_child(cam)
	cam.fov = 70
	cam.global_position = occhio
	cam.look_at(c, Vector3.UP)
	cam.make_current()
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella + "/firma_piscina_lontano.jpg", 0.9)
	# vicino: l'angolo in basso a destra del foglio (visto da davanti, la destra è -X del foglio girato verso di noi)
	var q := past.mesh as QuadMesh
	var destra := past.global_basis.x.normalized()
	var angolo := c + destra * q.size.x * 0.4 - Vector3.UP * q.size.y * 0.4
	cam.global_position = angolo + n * 0.5 + Vector3.UP * 0.1
	cam.look_at(angolo, Vector3.UP)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella + "/firma_piscina_vicino.jpg", 0.9)
	print("SCATTO: fatti")
	get_tree().quit()
