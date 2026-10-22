extends SceneTree
## Prova dell'occhio ipnotico dello spot (shaders/spot/occhio_ipnotico.gdshader e scripts/spot/occhio_ipnotico.gd) sul
## modello vero di Jilly, come nel menu (medusa_statue.gd coi suoi materiali), con la camera davanti all'occhio.
## Uso: godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/spot/prova_occhio.gd -- \
##     <cartella> [video] [vhs]
## Senza "video" salva scatti a vari punti del progresso; con "video" il progresso va da 0 a 1 in 5 s (dopo 1 s fermo),
## da registrare col Movie Maker. Con "vhs" sopra c'è anche il filtro del nastro (shaders/spot/vhs.gdshader).

const SCATTI := [0.0, 0.3, 0.6, 0.72, 0.9, 0.96]

var occhio: ColorRect
var video := false
var t := 0.0
var cartella := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	cartella = a[0]
	video = a.has("video")
	var menu := (load("res://scenes/ui/menu_principale.tscn") as PackedScene).instantiate()
	# del menu si tiene solo la statua con le sue luci e l'ambiente
	var mondo := Node3D.new()
	root.add_child(mondo)
	for n in menu.get_children():
		if n is Node3D or n is WorldEnvironment:
			n.owner = null
			menu.remove_child(n)
			mondo.add_child(n)
	menu.free()
	_prepara.call_deferred(a.has("vhs"))


func _prepara(con_vhs: bool) -> void:
	for i in 10:
		await process_frame
	# l'occhio: la mesh col materiale dell'occhio
	var occhio_mesh: MeshInstance3D = null
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count() if m.mesh else 0:
			var mat := m.get_active_material(s)
			if mat and mat.resource_path.ends_with("medusa_occhio.tres"):
				occhio_mesh = m
	if occhio_mesh == null:
		push_error("occhio non trovato")
		quit(1)
		return
	# la mesh ha lo scheletro: il suo AABB è quello di riposo. L'occhio vero: il centro e il davanti dell'AABB di riposo,
	# portati dalla posa dell'osso della testa (l'occhio si muove con la testa)
	var sk := occhio_mesh.get_node(occhio_mesh.skeleton) as Skeleton3D
	var testa := -1
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).to_lower() in ["testa", "head"]:
			testa = i
	var riposo := occhio_mesh.get_aabb()
	# il vertice come lo disegna lo skinning: scheletro * posa dell'osso * bind pose della pelle
	var bind := Transform3D()
	var skin := occhio_mesh.skin
	for j in skin.get_bind_count():
		var nb := skin.get_bind_name(j)
		if (nb != &"" and sk.find_bone(nb) == testa) or (nb == &"" and skin.get_bind_bone(j) == testa):
			bind = skin.get_bind_pose(j)
	var xf := sk.global_transform * sk.get_bone_global_pose(testa) * bind
	var c := xf * riposo.get_center()
	var davanti := xf * (riposo.get_center() + Vector3(0, 0, riposo.size.z * 0.5))
	var verso := (davanti - c).normalized()
	var dim := (xf.basis * riposo.size).length() * 0.5
	print("occhio ", occhio_mesh.get_path(), " centro ", c, " davanti ", davanti, " diametro ~", dim)
	var bb := AABB(c - Vector3.ONE * dim * 0.5, Vector3.ONE * dim)
	var bersaglio := Node3D.new()
	root.add_child(bersaglio)
	bersaglio.global_position = davanti
	var cam := root.find_child("Camera", true, false) as Camera3D
	cam.fov = 30.0
	# l'occhio riempie lo schermo in altezza (bozza: "l'occhio di Jilly riempie lo schermo")
	cam.global_position = davanti + verso * dim * 2.2
	cam.look_at(davanti)
	var strato := CanvasLayer.new()
	root.add_child(strato)
	occhio = (load("res://scripts/spot/occhio_ipnotico.gd") as GDScript).new()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/spot/occhio_ipnotico.gdshader")
	mat.set_shader_parameter(&"dallo_schermo", true)
	occhio.material = mat
	occhio.set_anchors_preset(Control.PRESET_FULL_RECT)
	occhio.size = Vector2(1280, 720)
	occhio.set(&"camera", cam)
	occhio.set(&"bersaglio", bersaglio)
	strato.add_child(occhio)
	if con_vhs:
		var copia := BackBufferCopy.new()
		copia.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		strato.add_child(copia)
		var vhs := ColorRect.new()
		var mv := ShaderMaterial.new()
		mv.shader = load("res://shaders/spot/vhs.gdshader")
		mv.set_shader_parameter(&"dallo_schermo", true)
		vhs.material = mv
		vhs.size = Vector2(1280, 720)
		strato.add_child(vhs)
	if video:
		process_frame.connect(_passo)
	else:
		_scatti()


func _passo() -> void:
	t += 1.0 / 30.0
	occhio.set(&"progresso", clampf((t - 1.0) / 5.0, 0.0, 1.0))


func _scatti() -> void:
	DirAccess.make_dir_recursive_absolute(cartella)
	for p in SCATTI:
		occhio.set(&"progresso", p)
		for i in 12:
			await process_frame
		root.get_texture().get_image().save_jpg(cartella.path_join("occhio_%03d.jpg" % roundi(p * 100)), 0.9)
		print("salvato ", p)
	quit()
