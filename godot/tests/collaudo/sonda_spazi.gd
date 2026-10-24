extends Node
## Collaudo e progetto: la geometria della sala principale (con la Risalita caricata) dentro un box, per cercare lo
## spazio libero dietro un muro (per esempio la vasca dietro un oblò). Scrive, come geometria.gd, <uscita>.bin (i
## triangoli nel mondo, float32 x 9) e <uscita>.json (le mesh: nodo, box, dove stanno i loro triangoli, visibile o
## no), più le forme di collisione del mondo che toccano il box (<uscita>_forme.json: nodo, box, classe).
## Uso (sotto il render.lock):
##   godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_spazi.gd \
##       <uscita senza estensione> <x0> <y0> <z0> <x1> <y1> <z1>

var uscita := ""
var box := AABB()


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	uscita = a[1]
	var lo := Vector3(float(a[2]), float(a[3]), float(a[4]))
	var hi := Vector3(float(a[5]), float(a[6]), float(a[7]))
	box = AABB(lo, hi - lo)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and get_tree().current_scene:
			break
	for i in 60:
		await get_tree().physics_frame
	var livello := get_tree().current_scene
	var bin := FileAccess.open(uscita + ".bin", FileAccess.WRITE)
	var voci := []
	var tri := 0
	for n in livello.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or (GameState.player and GameState.player.is_ancestor_of(mi)):
			continue
		var b := mi.global_transform * mi.mesh.get_aabb()
		if not b.intersects(box):
			continue
		var w: PackedVector3Array = mi.global_transform * mi.mesh.get_faces()
		var buf := PackedFloat32Array()
		buf.resize(w.size() * 3)
		for k in w.size():
			buf[k * 3] = w[k].x
			buf[k * 3 + 1] = w[k].y
			buf[k * 3 + 2] = w[k].z
		bin.store_buffer(buf.to_byte_array())
		voci.append({"nodo": String(livello.get_path_to(mi)), "istanza": -1, "visibile": mi.is_visible_in_tree(), "acqua": false,
				"box": [b.position.x, b.position.y, b.position.z, b.size.x, b.size.y, b.size.z], "da": tri, "n": w.size() / 3})
		tri += w.size() / 3
	bin.close()
	var f := FileAccess.open(uscita + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"mesh": voci}))
	f.close()
	var forme := []
	for c in livello.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		if cs.shape == null or cs.disabled:
			continue
		var co := cs.get_parent() as CollisionObject3D
		if co == null or co is Area3D:
			continue
		var b: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
		if b.intersects(box) and b.size.length() < 400.0:
			forme.append({"nodo": String(livello.get_path_to(cs)), "box": [b.position.x, b.position.y, b.position.z, b.size.x, b.size.y, b.size.z],
					"classe": cs.shape.get_class()})
	f = FileAccess.open(uscita + "_forme.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"forme": forme}))
	f.close()
	print("SONDA: %d mesh, %d triangoli, %d forme nel box" % [voci.size(), tri, forme.size()])
	get_tree().quit()
