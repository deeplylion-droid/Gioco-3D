extends Node
## Collaudo: elenca i nodi visibili (mesh, nebbie, particelle, decal) il cui riquadro contiene dei punti, e le
## distanze dai muri lungo i 6 assi. Uso: ... -- res://tests/collaudo/sonda_punto.gd <scena> <stato> "x,y,z;x,y,z"

const STATI := preload("res://tests/collaudo/stati.gd")


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	var livello: Node3D = (load(a[1]) as PackedScene).instantiate()
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 30:
		await get_tree().physics_frame
	get_tree().paused = false
	STATI.applica(livello, a[2])
	for i in 240:
		await get_tree().physics_frame
	var spazio := livello.get_world_3d().direct_space_state
	for t in a[3].split(";"):
		var c := t.split(",")
		var p := Vector3(float(c[0]), float(c[1]), float(c[2]))
		print("COLLAUDO: punto ", p)
		for n in livello.find_children("*", "VisualInstance3D", true, false):
			var v := n as VisualInstance3D
			if not v.is_visible_in_tree():
				continue
			var box := v.global_transform * v.get_aabb()
			if box.grow(0.05).has_point(p):
				var extra := ""
				if v is MeshInstance3D and (v as MeshInstance3D).mesh:
					extra = (v as MeshInstance3D).mesh.get_class()
				print("COLLAUDO:   ", v.get_class(), " ", livello.get_path_to(v), " ", extra, " box ", box.position, " ", box.size)
		for d in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var q := PhysicsRayQueryParameters3D.create(p, p + d * 20.0)
			q.hit_back_faces = true
			var r := spazio.intersect_ray(q)
			if r:
				print("COLLAUDO:   raggio ", d, " ", snappedf(p.distance_to(r.position), 0.01), " m ", livello.get_path_to(r.collider))
			else:
				print("COLLAUDO:   raggio ", d, " niente")
	get_tree().quit()
