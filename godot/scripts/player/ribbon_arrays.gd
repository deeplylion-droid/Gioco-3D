class_name RibbonArrays
extends RefCounted
## Costruisce i vertici di nastri rivolti alla camera (getto e aspirazione dell'acqua).
## Ogni punto diventa due vertici ai lati della curva. Per lo shader:
##  - UV.x: 0..1 attraverso il nastro; UV.y: metri d'acqua (per le striature che scorrono);
##  - NORMAL: verso la camera; TANGENT: di lato (lo shader ricostruisce la normale del cilindro);
##  - COLOR.a: visibilità del punto (0 = sparito).

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var tangents := PackedFloat32Array()
var uvs := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


func count() -> int:
	return indices.size()


func add_ribbon(pts: PackedVector3Array, radii: PackedFloat32Array, alphas: PackedFloat32Array,
		lengths: PackedFloat32Array, cam: Vector3) -> void:
	var m := pts.size()
	if m < 2:
		return
	var base := verts.size()
	var side_prev := Vector3.ZERO
	for k in m:
		var p := pts[k]
		var tan := (pts[mini(k + 1, m - 1)] - pts[maxi(k - 1, 0)])
		if tan.length_squared() < 1e-10:
			tan = Vector3.FORWARD
		tan = tan.normalized()
		var to_cam := cam - p
		if to_cam.length_squared() < 1e-8:
			to_cam = Vector3.UP
		to_cam = to_cam.normalized()
		var side := tan.cross(to_cam)
		if side.length_squared() < 1e-8:
			side = side_prev if side_prev != Vector3.ZERO else tan.cross(Vector3.UP)
		side = side.normalized()
		side_prev = side
		var r := radii[k]
		var a := alphas[k]
		var l := lengths[k]
		verts.append(p - side * r)
		verts.append(p + side * r)
		for s in 2:
			normals.append(to_cam)
			tangents.append_array([side.x, side.y, side.z, 1.0])
			colors.append(Color(1.0, 1.0, 1.0, a))
		uvs.append(Vector2(0.0, l))
		uvs.append(Vector2(1.0, l))
	for k in m - 1:
		var i := base + k * 2
		indices.append_array([i, i + 2, i + 1, i + 1, i + 2, i + 3])


func to_arrays() -> Array:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TANGENT] = tangents
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = indices
	return arr
