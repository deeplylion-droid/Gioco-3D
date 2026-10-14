extends SceneTree
## Lancia raggi dentro una scena importata, per capire dove sono aperture e superfici.
## Uso: godot --headless --path godot --script res://tests/probe_rays.gd -- <scena> "ax,ay,az>bx,by,bz" ...

var _node: Node3D
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_node = (load(args[0]) as PackedScene).instantiate()
	root.add_child(_node)
	# Collisioni trimesh dalle mesh visibili (per provare le aperture dei muri).
	if args.has("--trimesh"):
		for mi in _node.find_children("*", "MeshInstance3D", true, false):
			if mi.name in ["sala_pareti_basse", "sala_galleria", "piscina_bordi", "arrivo_bordi"]:
				(mi as MeshInstance3D).create_trimesh_collision()


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var space := _node.get_world_3d().direct_space_state
	var args := OS.get_cmdline_user_args()
	for i in range(1, args.size()):
		if not args[i].contains(">"):
			continue
		var parts := args[i].split(">")
		var a := _v(parts[0])
		var b := _v(parts[1])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))
		if hit.is_empty():
			print(args[i], " -> niente")
		else:
			print(args[i], " -> ", (hit.position * 100).round() / 100, " n=", (hit.normal * 100).round() / 100, " ", (hit.collider as Node).name)
	quit()
	return true


func _v(s: String) -> Vector3:
	var c := s.split(",")
	return Vector3(float(c[0]), float(c[1]), float(c[2]))
