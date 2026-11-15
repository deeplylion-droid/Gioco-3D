extends Node
## Sonda di una parete: da una fila di punti manda un raggio nella direzione data e stampa dove colpisce (e cosa).
## Uso: ... -- res://tests/storia/sonda_parete.gd <scena> "x0,y,z" "x1,y,z" passi "dx,dy,dz"

func _ready() -> void:
	_run.call_deferred()


func _v(s: String) -> Vector3:
	var c := s.split(",")
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scena := (load(args[1]) as PackedScene).instantiate()
	add_child(scena)
	for i in 10:
		await get_tree().physics_frame
	var space := (scena as Node3D).get_world_3d().direct_space_state
	var a := _v(args[2])
	var b := _v(args[3])
	var n := int(args[4])
	var d := _v(args[5])
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + d * 10.0))
		print("%s -> %s %s" % [p, h.position if h else "-", (h.collider as Node).name if h else ""])
	get_tree().quit()
