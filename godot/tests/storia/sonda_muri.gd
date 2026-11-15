extends Node
## Sonda dei muri attorno a dei punti (per mettere i disegni del bambino): carica una scena, e da ogni punto a 1,1 m
## manda raggi orizzontali in 8 direzioni e uno in giù; stampa le distanze.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/storia/sonda_muri.gd <scena> "x,y,z;x,y,z"

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scena := (load(args[1]) as PackedScene).instantiate()
	add_child(scena)
	for i in 10:
		await get_tree().physics_frame
	var space := (scena as Node3D).get_world_3d().direct_space_state
	for t in args[2].split(";"):
		var c := t.split(",")
		var p := Vector3(float(c[0]), float(c[1]), float(c[2]))
		var riga := "%s:" % p
		for k in 8:
			var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0)
			var q := PhysicsRayQueryParameters3D.create(p, p + d * 12.0)
			var h := space.intersect_ray(q)
			riga += " %s=%s" % [["N-z", "NO", "O-x", "SO", "S+z", "SE", "E+x", "NE"][k], ("%.2f" % p.distance_to(h.position)) if h else "-"]
		var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 5))
		riga += " giù=%s" % (("%.3f" % (h_y(g))) if g else "-")
		print(riga)
	get_tree().quit()


func h_y(g: Dictionary) -> float:
	return (g.position as Vector3).y
