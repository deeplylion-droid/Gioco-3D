extends Node
## Sonda: lo spazio sopra e intorno alle vasche di raccolta della torre (per lei che esce): per ogni vasca, dal centro e
## da 9 punti sul pelo, quanto c'è libero in su (raggio) e la distanza dai bordi.
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	for i in 4:
		await get_tree().physics_frame
	var space := torre.get_world_3d().direct_space_state
	var k := 0
	for v in torre.dati.get("raccolta", []):
		var r: Array = v["rett"]
		var acqua := float(v["acqua"])
		var righe: Array[String] = []
		for fx in [0.25, 0.5, 0.75]:
			for fy in [0.25, 0.5, 0.75]:
				var p := torre.b([lerpf(r[0], r[2], fx), lerpf(r[1], r[3], fy), acqua + 0.05])
				var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.UP * 12.0)
				q.collide_with_areas = false
				var h := space.intersect_ray(q)
				var su := (h["position"] as Vector3).y - p.y if h else 12.0
				righe.append("%.2f/%.2f su %.1f" % [fx, fy, su])
		print("VASCA %d (%s, pedana %.1f): %.1f x %.1f m, acqua %.2f m sul fondo; %s" % [k, v["torre"], float(v["livello"]),
				float(r[2]) - float(r[0]), float(r[3]) - float(r[1]), acqua - float(v["fondo"]), ", ".join(righe)])
		k += 1
	get_tree().quit()
