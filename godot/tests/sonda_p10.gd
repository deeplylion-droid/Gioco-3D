extends Node
## Sonda: che cosa c'è sotto la Polaroid 10 nella sala della torre, subito e dopo un po'.
const POLAROID_LIBERE := preload("res://tests/polaroid_libere.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var torre: SalaTorre = (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate()
	torre.crea_luci = false
	get_tree().root.add_child(torre)
	for n in [3, 30, 120]:
		for i in n:
			await get_tree().physics_frame
		var p10 := torre.get_node("Polaroid10") as Node3D
		var da := p10.global_position + Vector3(0, 0.6, 0)
		var hit := torre.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(da, da + Vector3(0, -6, 0), 0xFFFFFFFF))
		print("P10 dopo %d: %s, fisica %s, appoggio %.2f cm" % [n, p10.global_position, (str(hit.collider.get_path()) + " " + str(hit.position) + " layer " + str(hit.collider.get(&"collision_layer"))) if not hit.is_empty() else "niente", POLAROID_LIBERE.appoggio(torre, p10) * 100.0])
		for g in torre.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = (g as MeshInstance3D).global_transform * (g as MeshInstance3D).get_aabb()
			if a.grow(0.05).has_point(p10.global_position) and a.size.length() < 20:
				print("  mesh ", g.get_path(), " ", a)
	var p10 := torre.get_node("Polaroid10") as Node3D
	for y in [-11.59, -11.62, -11.635]:
		p10.global_position = Vector3(23.59315, y, -22.40685)
		var r := PackedStringArray()
		for k in [Vector3.ZERO, Vector3(-0.044, 0, -0.0535), Vector3(0.044, 0, -0.0535), Vector3(-0.044, 0, 0.0535), Vector3(0.044, 0, 0.0535)]:
			r.append("%.2f" % (POLAROID_LIBERE.appoggio(torre, p10, k) * 100.0))
		print("SEDILE a %.3f: %s, coperte %s, rot %s" % [y, ", ".join(r), POLAROID_LIBERE.coperte(torre), p10.global_rotation_degrees])
	var buoni := []
	for yaw in [0.0, 90.0, 13.0, 103.0]:
		for i in range(-16, 17):
			for j in range(-16, 17):
				var q := Vector3(23.59315 + i * 0.03, -11.45, -22.40685 + j * 0.03)
				p10.global_rotation = Vector3(0, deg_to_rad(yaw), 0)
				p10.global_position = q
				var h0: float = POLAROID_LIBERE.appoggio(torre, p10)
				if h0 == INF:
					continue
				p10.global_position = q - Vector3(0, h0 - 0.004, 0)
				var ok := true
				var r := PackedStringArray()
				for k in [Vector3(-0.044, 0, -0.0535), Vector3(0.044, 0, -0.0535), Vector3(-0.044, 0, 0.0535), Vector3(0.044, 0, 0.0535)]:
					var h: float = POLAROID_LIBERE.appoggio(torre, p10, k)
					r.append("%.1f" % (h * 100.0))
					ok = ok and h > -0.002 and h < 0.012
				if ok and POLAROID_LIBERE.coperte(torre).is_empty():
					buoni.append([Vector2(i, j).length() * 0.03, yaw, p10.global_position, ", ".join(r)])
	buoni.sort_custom(func(a, b): return a[0] < b[0])
	print("BUONI ", buoni.size())
	for b in buoni.slice(0, 15):
		print("BUONO a %.2f m, yaw %.0f: %s angoli %s" % b)
	get_tree().quit()
