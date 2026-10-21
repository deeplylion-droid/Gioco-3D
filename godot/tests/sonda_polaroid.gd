extends Node
## Sonda delle Polaroid della sala: dove sono finite dopo lo snap e se qualcosa le copre
## (tests/polaroid_libere.gd). Con l'argomento "vecchia" rimette la P08 dov'era prima della prova
## del 19 ottobre, sotto il pannello di controsoffitto, per vedere che il controllo se ne accorge.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sonda_polaroid.gd [vecchia]

const LEVEL := "res://scenes/sala_principale.tscn"
const POLAROID_LIBERE := preload("res://tests/polaroid_libere.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 10:
		await get_tree().physics_frame
	var level := get_tree().current_scene
	for f in level.find_children("*", "PolaroidPhoto", true, false):
		print("%s P%02d in %s, su %s" % [f.name, int(f.get(&"photo")), str((f as Node3D).global_position), str((f as Node3D).global_basis.y)])
	# PROVA="Polaroid08:x,y,z;Polaroid07:x,y,z": prova altre posizioni (poi lo snap come nel gioco)
	for voce in OS.get_environment("PROVA").split(";", false):
		var f := level.find_child(voce.get_slice(":", 0), true, false) as Node3D
		var v := voce.get_slice(":", 1).split_floats(",")
		f.global_position = Vector3(v[0], v[1], v[2])
		if v.size() > 3:
			f.global_rotation = Vector3(0, deg_to_rad(v[3]), 0)
		if f.get(&"snap_to_surface"):
			f.call(&"_snap")
	for i in 5:
		await get_tree().physics_frame
	var space := (level as Node3D).get_world_3d().direct_space_state if level is Node3D else get_viewport().world_3d.direct_space_state
	for f in level.find_children("*", "PolaroidPhoto", true, false):
		var pf := f as Node3D
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pf.global_position + Vector3(0, 0.6, 0), pf.global_position + Vector3(0, -3.4, 0), Layers.WORLD | Layers.PROPS))
		print("FISICA %s %s snap %s: %s" % [f.name, str(pf.global_position), str(f.get(&"snap_to_surface")), (str(hit.collider.get_path()) + " a " + str(hit.position)) if not hit.is_empty() else "niente"])
	if OS.get_environment("COLONNA") != "":
		var v := OS.get_environment("COLONNA").split_floats(",")
		var da := Vector3(v[0], 15.0, v[1])
		while true:
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(da, Vector3(v[0], -10.0, v[1]), Layers.WORLD | Layers.PROPS))
			if h.is_empty():
				break
			print("COLONNA ", h.collider.get_path(), " a ", h.position)
			da = h.position + Vector3(0, -0.01, 0)
		for g in level.find_children("*", "VisualInstance3D", true, false):
			var a: AABB = (g as VisualInstance3D).global_transform * (g as VisualInstance3D).get_aabb()
			if a.has_point(Vector3(v[0], a.get_center().y, v[1])) and a.size.length() < 30.0:
				print("COLONNA visiva ", g.get_path(), " ", a)
	print("COPERTE: ", POLAROID_LIBERE.coperte(level))
	# CERCA="Polaroid07:0.3": posti liberi e appoggiati (4 angoli) entro 0,3 m, i più vicini
	if OS.get_environment("CERCA") != "":
		var voce := OS.get_environment("CERCA")
		await _cerca(level, level.find_child(voce.get_slice(":", 0), true, false) as Node3D, float(voce.get_slice(":", 1)))
	for f in level.find_children("*", "PolaroidPhoto", true, false):
		print("APPOGGIO %s: %.2f cm, su %s" % [f.name, POLAROID_LIBERE.appoggio(level, f) * 100.0, str((f as Node3D).global_basis.y)])
	for f in level.find_children("Foglio_*", "MeshInstance3D", true, false):
		print("FOGLIO %s in %s, rot %.0f, aabb %s" % [f.name, str((f as Node3D).global_position), rad_to_deg((f as Node3D).global_rotation.y), str((f as Node3D).global_transform * (f as MeshInstance3D).get_aabb())])
	if OS.get_environment("SOTTO") != "":
		for f in level.find_children("*", "PolaroidPhoto", true, false):
			_sotto(level, f as Node3D)
	if OS.get_cmdline_user_args().has("vecchia"):
		var p8 := level.find_child("Polaroid08", true, false) as Node3D
		p8.global_position = Vector3(-8.5, 0.004, 6.6)
		print("COPERTE con la P08 di prima: ", POLAROID_LIBERE.coperte(level))
		for g in level.find_children("*", "MultiMeshInstance3D", true, false):
			var mm := (g as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var t := (g as Node3D).global_transform * mm.get_instance_transform(i)
				if Vector2(t.origin.x, t.origin.z).distance_to(Vector2(-8.5, 6.6)) < 1.0:
					print("VICINO ", g.get_path(), " ", t.origin, " aabb ", t * mm.mesh.get_aabb(), " visibile ", (g as Node3D).is_visible_in_tree())
	get_tree().quit()


## Le mesh sotto il centro e gli angoli della Polaroid: altezza (cm, nel suo sistema) e nome.
func _sotto(level: Node, f: Node3D) -> void:
	var punti := [Vector3.ZERO, Vector3(-0.044, 0, -0.0535), Vector3(0.044, 0, -0.0535), Vector3(-0.044, 0, 0.0535), Vector3(0.044, 0, 0.0535)]
	var meglio := [1e9, 1e9, 1e9, 1e9, 1e9]
	var chi := ["-", "-", "-", "-", "-"]
	var zona := f.global_transform * AABB(Vector3(-0.06, -0.3, -0.07), Vector3(0.12, 0.6, 0.14))
	for g in level.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or f.is_ancestor_of(mi):
			continue
		if not (mi.global_transform * mi.mesh.get_aabb()).intersects(zona):
			continue
		# tutto nel sistema della Polaroid: i raggi scendono lungo -y da 30 cm sopra
		var t := f.global_transform.affine_inverse() * mi.global_transform
		var facce := mi.mesh.get_faces()
		for i in range(0, facce.size(), 3):
			var a := t * facce[i]
			var b := t * facce[i + 1]
			var c := t * facce[i + 2]
			if maxf(a.x, maxf(b.x, c.x)) < -0.05 or minf(a.x, minf(b.x, c.x)) > 0.05 \
					or maxf(a.z, maxf(b.z, c.z)) < -0.06 or minf(a.z, minf(b.z, c.z)) > 0.06 \
					or maxf(a.y, maxf(b.y, c.y)) < -0.3 or minf(a.y, minf(b.y, c.y)) > 0.3:
				continue
			for k in 5:
				var o: Vector3 = punti[k] + Vector3(0, 0.3, 0)
				var h = Geometry3D.ray_intersects_triangle(o, Vector3.DOWN, a, b, c)
				if h != null and o.y - (h as Vector3).y < meglio[k]:
					meglio[k] = o.y - (h as Vector3).y
					chi[k] = mi.name
	var righe := PackedStringArray()
	for k in 5:
		righe.append("%.1f %s" % [(0.3 - meglio[k]) * 100.0, chi[k]])
	print("SOTTO %s: %s" % [f.name, ", ".join(righe)])


func _cerca(level: Node, f: Node3D, raggio: float) -> void:
	var geo := level.find_children("*", "GeometryInstance3D", true, false)
	var meshes := level.find_children("*", "MeshInstance3D", true, false)
	var centro := f.global_position
	var yaw := f.global_rotation.y
	var buoni := []
	var passo := 0.03
	var n := int(raggio / passo)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var q := centro + Vector3(i * passo, 0.0, j * passo)
			if Vector2(i, j).length() * passo > raggio:
				continue
			f.global_position = q + Vector3(0, 0.3, 0)
			f.global_rotation = Vector3(0, yaw, 0)
			var space := (f.get_world_3d()).direct_space_state
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(f.global_position + Vector3(0, 0.3, 0), f.global_position + Vector3(0, -1.0, 0), Layers.WORLD | Layers.PROPS))
			if hit.is_empty():
				continue
			f.global_position = hit.position + Vector3(0, 0.004, 0)
			var ok := true
			var alt := PackedStringArray()
			for k in [Vector3.ZERO, Vector3(-0.044, 0, -0.0535), Vector3(0.044, 0, -0.0535), Vector3(-0.044, 0, 0.0535), Vector3(0.044, 0, 0.0535)]:
				var h: float = POLAROID_LIBERE.appoggio(level, f, k, meshes)
				alt.append("%.1f" % (h * 100.0))
				if h < -0.002 or h > 0.012:
					ok = false
			if not ok:
				continue
			if not POLAROID_LIBERE.coperta(f, geo).is_empty():
				continue
			buoni.append([Vector2(i, j).length() * passo, f.global_position, hit.collider.name, alt])
	buoni.sort_custom(func(a, b): return a[0] < b[0])
	print("CERCA %s: %d posti buoni" % [f.name, buoni.size()])
	for b in buoni.slice(0, int(OS.get_environment("QUANTI")) if OS.has_environment("QUANTI") else 12):
		print("CERCA  a %.2f m: %s su %s, angoli %s" % b)
	f.global_position = centro
	f.global_rotation = Vector3(0, yaw, 0)
