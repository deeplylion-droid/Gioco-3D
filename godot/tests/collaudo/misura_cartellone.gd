extends Node
## Collaudo del cartellone rovinato: dov'è il cartellone rispetto al muro (distacco) e cosa della mesh del corridoio sta
## davanti a lui (fra il suo piano e il corridoio, dentro il suo rettangolo). Senza schermo.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/misura_cartellone.gd

const TEXTURE := "cartellone_medusa_rovinato"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var interni := (load("res://scenes/interni/interni.tscn") as PackedScene).instantiate() as Node3D
	interni.set(&"giocatore_proprio", false)
	add_child(interni)
	for i in 5:
		await get_tree().physics_frame
	for n in interni.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var poster := -1
		for si in mi.mesh.get_surface_count():
			var m := mi.get_active_material(si) as BaseMaterial3D
			if m and m.albedo_texture and m.albedo_texture.resource_path.contains(TEXTURE):
				poster = si
		if poster < 0:
			continue
		var pv: PackedVector3Array = mi.mesh.surface_get_arrays(poster)[Mesh.ARRAY_VERTEX]
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for v in pv:
			var g := mi.global_transform * v
			lo = lo.min(g)
			hi = hi.max(g)
		print("CARTELLONE vertici %d, da %s a %s" % [pv.size(), lo, hi])
		# cosa delle altre superfici sta nel rettangolo del cartellone e davanti al suo piano (z più piccola: il corridoio)
		for si in mi.mesh.get_surface_count():
			if si == poster:
				continue
			var arr := mi.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var davanti := 0
			var zmin := INF
			var ymin := INF
			var ymax := -INF
			var dietro_max := -INF
			for t in range(0, ix.size(), 3):
				var c := (mi.global_transform * v[ix[t]] + mi.global_transform * v[ix[t + 1]] + mi.global_transform * v[ix[t + 2]]) / 3.0
				if c.x < lo.x + 0.01 or c.x > hi.x - 0.01 or c.y < lo.y + 0.01 or c.y > hi.y - 0.01:
					continue
				if c.z < lo.z - 0.002 and c.z > lo.z - 0.5:
					davanti += 1
					zmin = minf(zmin, c.z)
					ymin = minf(ymin, c.y)
					ymax = maxf(ymax, c.y)
				elif c.z >= lo.z - 0.002 and c.z < lo.z + 0.3:
					dietro_max = maxf(dietro_max, c.z)
			var m2 := mi.get_active_material(si)
			if davanti > 0:
				print("  DAVANTI: superficie %d (%s): %d triangoli, fino a %.3f m davanti al cartellone, y da %.2f a %.2f" % [si, m2.resource_name if m2 else "?", davanti, lo.z - zmin, ymin, ymax])
			if dietro_max > -INF:
				print("  dietro/a filo: superficie %d (%s): il più vicino a %.3f m dietro il piano del cartellone" % [si, m2.resource_name if m2 else "?", dietro_max - lo.z])
	print("RISULTATO: 1 controlli ok, 0 falliti")
	get_tree().quit()
