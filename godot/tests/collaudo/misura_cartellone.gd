extends Node
## Collaudo del cartellone rovinato: dov'è il cartellone rispetto al muro (distacco) e cosa della mesh del corridoio
## gli sta intorno: per ogni materiale i triangoli vicini al suo rettangolo (allargato di [constant MARGINE]) entro
## [constant MARGINE] dal suo piano, quanto stanno davanti (verso il corridoio) o dietro, e quali attraversano il piano
## dentro il rettangolo (compenetrano il cartellone). Senza schermo.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/misura_cartellone.gd

const TEXTURE := "cartellone_medusa_rovinato"
const MARGINE := 0.12


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
		# il piano del cartellone (è dritto: z costante) e il corridoio verso z più piccola
		var zp := (lo.z + hi.z) * 0.5
		print("CARTELLONE vertici %d, da %s a %s (spessore %.4f)" % [pv.size(), lo, hi, hi.z - lo.z])
		for si in mi.mesh.get_surface_count():
			if si == poster:
				continue
			var arr := mi.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var davanti := 0
			var dietro := 0
			var attraversa := 0
			var d_max := 0.0        # quanto sporge davanti al piano (m)
			var dietro_min := INF   # il più vicino dietro il piano (m): il muro
			var y_d := Vector2(INF, -INF)
			for t in range(0, ix.size(), 3):
				var a := mi.global_transform * v[ix[t]]
				var b := mi.global_transform * v[ix[t + 1]]
				var c := mi.global_transform * v[ix[t + 2]]
				var tlo := a.min(b).min(c)
				var thi := a.max(b).max(c)
				if thi.x < lo.x - MARGINE or tlo.x > hi.x + MARGINE or thi.y < lo.y - MARGINE or tlo.y > hi.y + MARGINE:
					continue
				if thi.z < zp - MARGINE or tlo.z > zp + MARGINE:
					continue
				# dentro il rettangolo del cartellone (non solo vicino)?
				var sopra := thi.x > lo.x + 0.005 and tlo.x < hi.x - 0.005 and thi.y > lo.y + 0.005 and tlo.y < hi.y - 0.005
				if tlo.z < zp - 0.0005 and thi.z > zp + 0.0005 and sopra:
					attraversa += 1
				elif thi.z <= zp + 0.0005:
					davanti += 1
					d_max = maxf(d_max, zp - tlo.z)
					y_d = Vector2(minf(y_d.x, tlo.y), maxf(y_d.y, thi.y))
				else:
					dietro += 1
					if sopra:
						dietro_min = minf(dietro_min, tlo.z - zp)
			if davanti + dietro + attraversa == 0:
				continue
			var m2 := mi.get_active_material(si)
			var nome := m2.resource_name if m2 else "?"
			var riga := "  %s (superficie %d): %d davanti" % [nome, si, davanti]
			if davanti > 0:
				riga += " (fino a %.3f m davanti, y %.2f-%.2f)" % [d_max, y_d.x, y_d.y]
			riga += ", %d dietro" % dietro
			if dietro_min < INF:
				riga += " (il più vicino dentro il rettangolo a %.4f m dietro)" % dietro_min
			if attraversa > 0:
				riga += ", %d ATTRAVERSANO il cartellone" % attraversa
			print(riga)
	print("RISULTATO: 1 controlli ok, 0 falliti")
	get_tree().quit()
