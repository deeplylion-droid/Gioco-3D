class_name TubeBuilder
extends RefCounted
## Costruisce mesh lungo una Curve3D: tubi (scivoli chiusi o aperti) e nastri d'acqua.
## UV: u = metri lungo la curva, v = 0..1 intorno al tubo (0 = fondo).


## Base ortonormale stabile lungo la curva: T tangente, U "su" (vicino alla verticale), R destra.
static func frame_at(curve: Curve3D, offset: float) -> Basis:
	var length := curve.get_baked_length()
	var o := clampf(offset, 0.0, length)
	var p0 := curve.sample_baked(clampf(o - 0.05, 0.0, length))
	var p1 := curve.sample_baked(clampf(o + 0.05, 0.0, length))
	var t := (p1 - p0).normalized()
	if t.length() < 0.5:
		t = Vector3.FORWARD
	var up := Vector3.UP - t * t.dot(Vector3.UP)
	if up.length() < 1e-3:
		up = Vector3.BACK - t * t.dot(Vector3.BACK)
	up = up.normalized()
	var r := t.cross(up).normalized()
	return Basis(r, up, t)


## Tubo con parete interna ed esterna. `arc_degrees` < 360 fa un canale aperto in alto
## (centrato sul fondo). `step` = distanza tra gli anelli (m).
static func build_tube(curve: Curve3D, inner_radius: float, outer_radius: float, radial_segments: int,
		step: float, cap_ends := true, arc_degrees := 360.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := curve.get_baked_length()
	var rings := maxi(2, int(ceil(length / step)) + 1)
	var full := arc_degrees >= 359.9
	var seg := radial_segments
	var cols := seg + 1
	var arc := deg_to_rad(arc_degrees)
	var pts_in: Array[PackedVector3Array] = []
	var pts_out: Array[PackedVector3Array] = []
	var nrm: Array[PackedVector3Array] = []
	for i in rings:
		var o := length * float(i) / float(rings - 1)
		var c := curve.sample_baked(o)
		var f := frame_at(curve, o)
		var pin := PackedVector3Array()
		var pout := PackedVector3Array()
		var nn := PackedVector3Array()
		for k in cols:
			# angolo 0 = fondo del tubo
			var a := -arc * 0.5 + arc * float(k) / float(seg)
			var d := (-f.y * cos(a) + f.x * sin(a)).normalized()
			pin.append(c + d * inner_radius)
			pout.append(c + d * outer_radius)
			nn.append(d)
		pts_in.append(pin)
		pts_out.append(pout)
		nrm.append(nn)
	for i in rings - 1:
		var u0 := length * float(i) / float(rings - 1)
		var u1 := length * float(i + 1) / float(rings - 1)
		for k in seg:
			var v0 := float(k) / seg
			var v1 := float(k + 1) / seg
			# parete interna (normale verso il centro)
			_tri(st, pts_in[i][k], -nrm[i][k], Vector2(u0, v0), pts_in[i + 1][k + 1], -nrm[i + 1][k + 1], Vector2(u1, v1), pts_in[i + 1][k], -nrm[i + 1][k], Vector2(u1, v0))
			_tri(st, pts_in[i][k], -nrm[i][k], Vector2(u0, v0), pts_in[i][k + 1], -nrm[i][k + 1], Vector2(u0, v1), pts_in[i + 1][k + 1], -nrm[i + 1][k + 1], Vector2(u1, v1))
			# parete esterna
			_tri(st, pts_out[i][k], nrm[i][k], Vector2(u0, v0), pts_out[i + 1][k], nrm[i + 1][k], Vector2(u1, v0), pts_out[i + 1][k + 1], nrm[i + 1][k + 1], Vector2(u1, v1))
			_tri(st, pts_out[i][k], nrm[i][k], Vector2(u0, v0), pts_out[i + 1][k + 1], nrm[i + 1][k + 1], Vector2(u1, v1), pts_out[i][k + 1], nrm[i][k + 1], Vector2(u0, v1))
	if cap_ends:
		for e in [0, rings - 1]:
			var f := frame_at(curve, length * float(e) / float(rings - 1))
			var n := -f.z if e == 0 else f.z
			for k in seg:
				var a: Vector3 = pts_in[e][k]
				var b: Vector3 = pts_in[e][k + 1]
				var c: Vector3 = pts_out[e][k + 1]
				var d: Vector3 = pts_out[e][k]
				if e == 0:
					_tri(st, a, n, Vector2.ZERO, d, n, Vector2.ZERO, c, n, Vector2.ZERO)
					_tri(st, a, n, Vector2.ZERO, c, n, Vector2.ZERO, b, n, Vector2.ZERO)
				else:
					_tri(st, a, n, Vector2.ZERO, c, n, Vector2.ZERO, d, n, Vector2.ZERO)
					_tri(st, a, n, Vector2.ZERO, b, n, Vector2.ZERO, c, n, Vector2.ZERO)
	if not full:
		pass
	st.generate_tangents()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, na: Vector3, ua: Vector2, b: Vector3, nb: Vector3, ub: Vector2, c: Vector3, nc: Vector3, uc: Vector2) -> void:
	st.set_normal(na)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(nb)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_normal(nc)
	st.set_uv(uc)
	st.add_vertex(c)
