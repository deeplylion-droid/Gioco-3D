extends SceneTree
## Costruisce la sagoma della torre degli scivoli per lo sfondo del titolo (MenuSfondo): le mesh della
## struttura e degli scivoli della torre (assets/ambiente/torre/, senza l'acqua e senza il guscio della sala) fuse in una sola mesh con
## solo posizioni e normali, senza materiali né texture. Si vede solo nera, contro il cielo del lampo.
## Uso: godot --headless --path godot --script res://tools/sagoma_torre.gd

const GLB := ["res://assets/ambiente/torre/torre_struttura.glb", "res://assets/ambiente/torre/torre_scivoli.glb"]
const USCITA := "res://assets/menu/sagoma_torre.res"


func _init() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	for path in GLB:
		var radice: Node3D = (load(path) as PackedScene).instantiate()
		for mi in radice.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if String(m.name).begins_with("acqua") or m.mesh == null:
				continue
			var t := _globale(m, radice)
			for s in m.mesh.get_surface_count():
				var arr := m.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				if idx.is_empty():
					idx.resize(v.size())
					for i in v.size():
						idx[i] = i
				for k in range(0, idx.size(), 3):
					var tri := [t * v[idx[k]], t * v[idx[k + 1]], t * v[idx[k + 2]]]
					if _guscio(tri):
						continue
					for j in 3:
						if not nn.is_empty():
							st.set_normal((t.basis * nn[idx[k + j]]).normalized())
						st.add_vertex(tri[j])
						n += 1
		radice.free()
	st.index()
	var mesh := st.commit()
	var err := ResourceSaver.save(mesh, USCITA, ResourceSaver.FLAG_COMPRESS)
	print("SAGOMA ", USCITA, " ", n, " vertici, errore ", err)
	quit()


## Il guscio della sala della torre (muri, pavimento e soffitto, nella struttura): non fa parte della sagoma.
## I suoi triangoli stanno tutti su uno dei piani del guscio.
const GUSCIO_X := Vector2(20.2, 40.0)
const GUSCIO_Z := Vector2(-26.0, -4.0)
const GUSCIO_Y := Vector2(-28.0, 14.0)


func _guscio(tri: Array) -> bool:
	for asse in 3:
		var lim: Vector2 = [GUSCIO_X, GUSCIO_Y, GUSCIO_Z][asse]
		for l in [lim.x, lim.y]:
			if tri.all(func(q: Vector3): return absf(q[asse] - l) < 0.9):
				return true
	return false


func _globale(n: Node3D, radice: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p and p != radice:
		t = (p as Node3D).transform * t if p is Node3D else t
		p = p.get_parent()
	return t
