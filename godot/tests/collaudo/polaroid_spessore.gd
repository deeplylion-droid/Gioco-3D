extends Node
## Collaudo Polaroid (0.3.24): l'altezza del modello della Polaroid rispetto alla sua origine (quella che Posa mette a
## 4 mm dal pavimento). Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/polaroid_spessore.gd


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var p := (load("res://scenes/props/polaroid.tscn") as PackedScene).instantiate() as Node3D
	p.set(&"snap_to_surface", false)
	add_child(p)
	await get_tree().process_frame
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := p.global_transform.affine_inverse() * m.global_transform
		var a := t * m.get_aabb()
		print("SPESSORE %s: y da %.2f a %.2f mm, x %.1f-%.1f cm, z %.1f-%.1f cm" % [m.name, a.position.y * 1000.0, a.end.y * 1000.0,
				a.position.x * 100.0, a.end.x * 100.0, a.position.z * 100.0, a.end.z * 100.0])
		# i vertici più bassi
		var f := m.mesh.get_faces()
		var ys := {}
		for v in f:
			var y := snappedf((t * v).y * 1000.0, 0.01)
			ys[y] = int(ys.get(y, 0)) + 1
		var k := ys.keys()
		k.sort()
		print("  quote dei vertici (mm): %s" % str(k.slice(0, 8)))
		# la quota più bassa per zona (griglia 3x3 sull'impronta): dove tocca e dove è sollevata
		var zone := {}
		for v in f:
			var w := t * v
			var cz := Vector2i(clampi(int(floor((w.x + 0.044) / 0.0294)), 0, 2), clampi(int(floor((w.z + 0.054) / 0.036)), 0, 2))
			zone[cz] = minf(float(zone.get(cz, 1.0)), w.y * 1000.0)
		for zz in 3:
			print("  fondo per zona, riga z %d: %.2f  %.2f  %.2f mm" % [zz, zone.get(Vector2i(0, zz), 99.0), zone.get(Vector2i(1, zz), 99.0), zone.get(Vector2i(2, zz), 99.0)])
	get_tree().quit()
