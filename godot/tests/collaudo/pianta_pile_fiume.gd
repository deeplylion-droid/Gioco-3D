extends Node
## La pianta delle pile di scatoloni del fiume lento, senza render (headless): un'immagine dall'alto, nelle coordinate del
## fiume, coi corpi di collisione delle pile (marrone), il resto degli ingombri a terra (grigio: rocce, transenne, cabina,
## pali), la strada del giocatore (giallo) e la riva (azzurro, dove non si cammina). Serve a vedere i buchi fra le pile e
## fra le pile e i muri senza aspettare gli scatti.
## Uso (sotto il render.lock):
##   godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/pianta_pile_fiume.gd <file.png>

const SCENA := "res://tests/scene/fiume_gioco_prova.tscn"
const X := Vector2(-33.0, -1.0)
const Z := Vector2(-30.0, 2.0)
const PX := 20.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var file := a[1] if a.size() > 1 else "user://pianta_pile.png"
	get_tree().change_scene_to_file(SCENA)
	var fiume: Node3D = null
	for i in 6000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s:
			for f in s.find_children("*", "Node3D", true, false):
				var sc := (f as Node).get_script() as Script
				if sc and sc.resource_path.ends_with("fiume_gioco.gd") and f.get(&"costruita") == true:
					fiume = f
			if fiume:
				break
	if fiume == null:
		print("PIANTA: niente fiume")
		get_tree().quit(1)
		return
	var w := int((X.y - X.x) * PX)
	var h := int((Z.y - Z.x) * PX)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.12, 0.12))
	# la banchina (dove si cammina) chiara, il resto scuro
	for py in h:
		for px in w:
			var q := _mondo(px, py)
			if fiume.call(&"_sulla_banchina", Vector3(q.x, 0, q.y), 0.0):
				img.set_pixel(px, py, Color(0.32, 0.32, 0.34))
	var pile := 0
	for fc in fiume.find_children("*", "CollisionShape3D", true, false):
		var f := fc as CollisionShape3D
		if f.shape == null or f.disabled:
			continue
		var tr := fiume.global_transform.affine_inverse() * f.global_transform
		var col := Color(0.6, 0.6, 0.6)
		var poli := PackedVector2Array()
		if f.shape is BoxShape3D:
			var hs := (f.shape as BoxShape3D).size * 0.5
			# le pile: alte più di 2 m, sui 1,2 x 1,0 o più strette (le sciolte)
			if hs.y * 2.0 > 2.0 and hs.x < 0.65 and hs.z < 0.55 and tr.origin.y < 3.5:
				col = Color(0.65, 0.42, 0.22)
				pile += 1
			if tr.origin.y - hs.y > 2.0:
				continue   # quello che sta in alto (travi, lampade) non ingombra la strada
			var pts := PackedVector2Array()
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var v: Vector3 = tr * Vector3(hs.x * sx, 0, hs.z * sz)
					pts.append(Vector2(v.x, v.z))
			poli = Geometry2D.convex_hull(pts)
		elif f.shape is CylinderShape3D:
			var r := (f.shape as CylinderShape3D).radius
			for k in 12:
				poli.append(Vector2(tr.origin.x, tr.origin.z) + Vector2.from_angle(TAU * k / 12.0) * r)
		elif f.shape is ConvexPolygonShape3D:
			var pts := PackedVector2Array()
			for v in (f.shape as ConvexPolygonShape3D).points:
				var vv: Vector3 = tr * v
				if vv.y < 2.0:
					pts.append(Vector2(vv.x, vv.z))
			if pts.size() >= 3:
				poli = Geometry2D.convex_hull(pts)
		if poli.size() >= 3:
			_riempi(img, poli, col)
	# la strada
	var m := fiume.get_node(^"Marker")
	var punti: Array[Vector2] = []
	for nome in ["Ingresso", "FineFila", "Imbarco"]:
		var g := fiume.to_local((m.get_node(NodePath(nome)) as Node3D).global_position)
		punti.append(Vector2(g.x, g.z))
	for k in punti.size() - 1:
		for t in 200:
			var q := punti[k].lerp(punti[k + 1], t / 200.0)
			var pp := _pixel(q)
			for dx in 2:
				img.set_pixel(clampi(pp.x + dx, 0, w - 1), clampi(pp.y, 0, h - 1), Color(1, 0.9, 0.1))
	# la griglia ogni 2 m
	for gx in range(int(X.x), int(X.y) + 1, 2):
		for py in h:
			var pp := _pixel(Vector2(gx, 0))
			if pp.x >= 0 and pp.x < w and py % 4 == 0:
				img.set_pixel(pp.x, py, Color(0.2, 0.5, 0.2))
	for gz in range(int(Z.x), int(Z.y) + 1, 2):
		for px in w:
			var pp := _pixel(Vector2(0, gz))
			if pp.y >= 0 and pp.y < h and px % 4 == 0:
				img.set_pixel(px, pp.y, Color(0.2, 0.5, 0.2))
	img.save_png(file)
	print("PIANTA: %d colonne di pile, salvata in %s" % [pile, file])
	get_tree().quit()


func _mondo(px: int, py: int) -> Vector2:
	return Vector2(X.x + (px + 0.5) / PX, Z.x + (py + 0.5) / PX)


func _pixel(q: Vector2) -> Vector2i:
	return Vector2i(int((q.x - X.x) * PX), int((q.y - Z.x) * PX))


func _riempi(img: Image, poli: PackedVector2Array, col: Color) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in poli:
		lo = lo.min(v)
		hi = hi.max(v)
	var a := _pixel(lo)
	var b := _pixel(hi)
	for py in range(maxi(a.y, 0), mini(b.y + 1, img.get_height())):
		for px in range(maxi(a.x, 0), mini(b.x + 1, img.get_width())):
			if Geometry2D.is_point_in_polygon(_mondo(px, py), poli):
				img.set_pixel(px, py, col)
