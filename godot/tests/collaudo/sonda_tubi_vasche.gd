extends Node
## Sonda per i tubi di scarico delle vasche di raccolta: per ogni vasca, le linee verticali libere (una sfera di 0,25 m
## che scende da sotto la vasca fino al fondo della sala senza toccare niente) vicine alla vasca, il tratto orizzontale
## libero da sotto la vasca fino a lì, la distanza dai salti e dal traliccio della sua torre.
const TORRI := {"NO": 135.0, "NE": 45.0, "SE": 315.0, "SO": 225.0}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	for i in 4:
		await get_tree().physics_frame
	var space := torre.get_world_3d().direct_space_state
	var sfera := SphereShape3D.new()
	sfera.radius = 0.25
	var k := 0
	for v in torre.dati.get("raccolta", []):
		var r: Array = v["rett"]
		var c := SalaTorre.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(v["fondo"]) - 0.65])
		var a := deg_to_rad(float(TORRI[v["torre"]]))
		var tc := SalaTorre.b([31.0 + 8.0 * cos(a), 15.0 + 8.0 * sin(a), 0.0])
		var buoni: Array = []
		for ix in range(-16, 17):
			for iz in range(-16, 17):
				var p := Vector3(c.x + ix * 0.5, c.y, c.z + iz * 0.5)
				if not _libero(space, sfera, p, Vector3(p.x, -19.7, p.z)):
					continue
				if not _libero(space, sfera, c, p):
					continue
				var salto := INF
				for s in torre.dati["salti"]:
					var da := SalaTorre.b(s["da"])
					var al := SalaTorre.b(s["a"])
					if minf(da.y, al.y) > c.y + 3.0:
						continue
					var q := Geometry3D.get_closest_points_between_segments(da, al, Vector3(p.x, c.y, p.z), Vector3(p.x, -20.0, p.z))
					salto = minf(salto, (q[0] as Vector3).distance_to(q[1]))
				if salto < 1.2:
					continue
				var dt := Vector2(p.x - tc.x, p.z - tc.z)
				var faccia := maxf(absf(dt.x), absf(dt.y)) - 1.1
				buoni.append([Vector2(p.x - c.x, p.z - c.z).length(), faccia, p, salto])
		buoni.sort_custom(func(x, y): return x[0] < y[0])
		print("VASCA %d (%s): %d linee libere; le più vicine:" % [k, v["torre"], buoni.size()])
		for b in buoni.slice(0, 6):
			print("   orizzontale %.1f m, dal traliccio %.1f m, in %s, dai salti %.1f m" % [b[0], b[1], b[2], b[3]])
		var vicine := buoni.filter(func(x): return x[1] < 1.0)
		vicine.sort_custom(func(x, y): return x[0] < y[0])
		for b in vicine.slice(0, 3):
			print("   ACCANTO AL TRALICCIO: orizzontale %.1f m, dal traliccio %.1f m, in %s" % [b[0], b[1], b[2]])
		k += 1
	get_tree().quit()


func _libero(space: PhysicsDirectSpaceState3D, sfera: Shape3D, da: Vector3, a: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sfera
	q.transform = Transform3D(Basis(), da)
	q.motion = a - da
	q.collide_with_areas = false
	var f := space.cast_motion(q)
	return f[0] >= 0.999
