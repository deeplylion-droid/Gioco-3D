extends Node
## Collaudo di lavoro/varchi-cielo: dove cielo_zone.gd trova pochi raggi nel cielo (2 su 240) nella torre, si guarda da
## vicino. Nel gioco vero (partenza F9 torre), negli occhi di ogni posto: i 240 raggi di cielo_zone, e attorno a ogni
## raggio che esce un ventaglio fitto (41x41 raggi in ±3 gradi): quanti escono, la larghezza della fessura (gradi e cm alla
## distanza dei colpi vicini), e i punti colpiti attorno (dove sta la fessura) con la mesh. Stampa FESSURA:.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/cielo_fessure.gd

const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const POSTI := [["Checkpoint_portone", Vector3(21.4, 1.59, -15.0)], ["Checkpoint_NEm3", Vector3(37.47, -1.41, -18.97)],
		["Checkpoint_NOm12", Vector3(27.05, -10.41, -21.41)]]


func _ready() -> void:
	_run.call_deferred()


func _pronto() -> bool:
	var pl := GameState.player
	var sc := get_tree().current_scene
	return pl and is_instance_valid(pl) and pl.input_enabled and not GameState.is_dying and sc \
			and not String(sc.scene_file_path).contains("caricamento")


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	MenuProva.parti(get_tree(), "torre")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		if _pronto():
			break
	for i in 60 * 20:
		await get_tree().process_frame
	var sc := get_tree().current_scene as Node3D
	var p := GameState.player
	var dirs: Array[Vector3] = []
	for i in 240:
		var y := 1.0 - 2.0 * (i + 0.5) / 240
		var r := sqrt(1.0 - y * y)
		var th := PI * (3.0 - sqrt(5.0)) * i
		dirs.append(Vector3(cos(th) * r, y, sin(th) * r))
	for ps in POSTI:
		var occhio: Vector3 = ps[1]
		p.teleport(occhio + Vector3.DOWN * 1.5)
		for i in 30:
			await get_tree().physics_frame
		p.process_mode = Node.PROCESS_MODE_DISABLED
		CorpiMesh.crea(sc, AABB(occhio, Vector3.ZERO).grow(80.0), p)
		for i in 2:
			await get_tree().physics_frame
		var spazio := get_viewport().find_world_3d().direct_space_state
		for d in dirs:
			if not _raggio(spazio, occhio, d, p).is_empty():
				continue
			# il ventaglio attorno
			var a := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
			var b := d.cross(a).normalized()
			var fuori := 0
			var colpi := []
			var ang := []
			for i in range(-20, 21):
				for j in range(-20, 21):
					var dd := (d + a * tan(deg_to_rad(i * 0.15)) + b * tan(deg_to_rad(j * 0.15))).normalized()
					var h := _raggio(spazio, occhio, dd, p)
					if h.is_empty():
						fuori += 1
						ang.append(Vector2(i, j) * 0.15)
					else:
						colpi.append([occhio.distance_to(h.position), h.position, _nome(sc, h.collider as Node), Vector2(i, j) * 0.15])
			var largo := Vector2.ZERO
			if not ang.is_empty():
				var mn := Vector2(INF, INF)
				var mx := Vector2(-INF, -INF)
				for v in ang:
					mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.y))
					mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.y))
				largo = mx - mn + Vector2(0.15, 0.15)
			# i colpi più vicini al buco (nel ventaglio)
			colpi.sort_custom(func(x, y): return (x[3] as Vector2).length() < (y[3] as Vector2).length())
			var vicini := colpi.slice(0, 4)
			var dist := 0.0
			for c in vicini:
				dist += float(c[0])
			dist /= maxf(vicini.size(), 1)
			print("FESSURA: %s, occhi %s verso %s: nel ventaglio di ±3 gradi %d raggi su 1681 nel cielo, larga %.2f x %.2f gradi (a %.1f m: %.0f x %.0f cm); attorno colpisce %s" % [ps[0],
					occhio.snapped(Vector3.ONE * 0.01), d.snapped(Vector3.ONE * 0.001), fuori, largo.x, largo.y, dist,
					deg_to_rad(largo.x) * dist * 100.0, deg_to_rad(largo.y) * dist * 100.0,
					", ".join(vicini.map(func(c): return "%s a %.1f m in %s" % [c[2], c[0], (c[1] as Vector3).snapped(Vector3.ONE * 0.01)]))])
		p.process_mode = Node.PROCESS_MODE_INHERIT
	print("FESSURA: finito")
	get_tree().quit()


func _raggio(spazio: PhysicsDirectSpaceState3D, da: Vector3, d: Vector3, p: Node) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(da, da + d * 150.0, 0xFFFFFFFF, [(p as CollisionObject3D).get_rid()])
	q.hit_back_faces = true
	return spazio.intersect_ray(q)


func _nome(sc: Node, n: Node) -> String:
	if n == null:
		return "?"
	var m := n.get_parent() if n.get_parent() is MeshInstance3D else n
	var pezzi := String(sc.get_path_to(m)).split("/")
	return "/".join(pezzi.slice(0, 2)) + "/…/" + pezzi[-1]
