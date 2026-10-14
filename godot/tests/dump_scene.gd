extends SceneTree
## Stampa l'albero di una scena importata (nomi, tipi, posizioni, AABB delle mesh).
## Uso: godot --headless --path godot --script res://tests/dump_scene.gd -- <scena> [filtro]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: PackedScene = load(args[0])
	var filt := args[1] if args.size() > 1 else ""
	_node = scene.instantiate()
	_filt = filt
	root.add_child(_node)


var _node: Node
var _filt := ""
var _done := false


func _process(_delta: float) -> bool:
	if not _done:
		_done = true
		_dump(_node, 0, _filt)
		quit()
	return false


func _dump(n: Node, depth: int, filt: String) -> void:
	var line := "  ".repeat(mini(depth, 6)) + n.name + " <" + n.get_class() + ">"
	if n is Node3D:
		line += " pos=" + str(((n as Node3D).global_position * 100).round() / 100)
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var aabb := mi.global_transform * mi.get_aabb()
		line += " aabb=" + str((aabb.position * 100).round() / 100) + "+" + str((aabb.size * 100).round() / 100)
		var mats := []
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			mats.append(m.resource_name if m else "-")
		line += " mats=" + str(mats)
	if n is CollisionShape3D and (n as CollisionShape3D).shape:
		var sh := (n as CollisionShape3D).shape
		line += " shape=" + sh.get_class()
		var pts := PackedVector3Array()
		if sh is ConvexPolygonShape3D:
			pts = (sh as ConvexPolygonShape3D).points
		elif sh is ConcavePolygonShape3D:
			pts = (sh as ConcavePolygonShape3D).get_faces()
		if pts.size() > 0:
			var bb := AABB(pts[0], Vector3.ZERO)
			for q in pts:
				bb = bb.expand(q)
			bb = (n as Node3D).global_transform * bb
			line += " bb=" + str((bb.position * 100).round() / 100) + "+" + str((bb.size * 100).round() / 100)
	var show := filt == "" or depth <= 1
	for f in filt.split(",", false):
		if n.name.to_lower().contains(f):
			show = true
	if show:
		print(line)
	for c in n.get_children():
		_dump(c, depth + 1, filt)
