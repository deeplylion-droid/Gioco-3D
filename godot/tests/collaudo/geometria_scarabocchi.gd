extends Node
## Collaudo degli scarabocchi (lavoro/scarabocchi, 29 ottobre; controllo indipendente da cerca_muri.gd): per ogni decal
## di godot/assets/ambiente/scarabocchi/scarabocchi.json nella scena data, senza renderer:
## - RAGGI: una griglia di 13 x 7 raggi sulla faccia del disegno, dalla faccia davanti alla faccia dietro della scatola:
##   VUOTO dove non c'è muro (il disegno lì si taglia), STORTO dove la superficie non è parallela al muro (il disegno lì
##   si stira), RILIEVO dove la superficie colpita sta a più di 3 cm dal piano del muro (cornici, tubi, mensole);
## - DENTRO: le mesh (anche quelle nascoste, che compaiono dopo) che entrano nella scatola della decal ma non sono il
##   muro: anche su quelle si disegnerebbe;
## - VICINO: porte, Polaroid, pulsanti, poster, oblò, indizi, acquari, grate a meno di 1 m dal disegno.
## Uso (sotto il render.lock): godot --headless --path godot --script res://tests/run.gd -- \
##        res://tests/collaudo/geometria_scarabocchi.gd <scena.tscn>

const DATI := "res://assets/ambiente/scarabocchi/scarabocchi.json"
const SPESSORE := 0.12
const IMPORTANTI := "(?i)(polaroid|pulsante|button|porta|door|poster|cartell|oblo|oblò|disegno|cassaforte|schema|tacch|grata|griglia|acquar|leva|valvola|interrutt|portello|botola|scaletta|ladder|lampeggiante|quadro)"


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _vec(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]))


func _run() -> void:
	Engine.set_meta(&"risalita_subito", true)
	var scena: String = OS.get_cmdline_user_args()[1]
	var tutti: Array = JSON.parse_string(FileAccess.get_file_as_string(DATI))
	var miei := tutti.filter(func(s): return _scena_per_zona(String(s["zona"])) == scena)
	print("SCENA ", scena, ": ", miei.size(), " scarabocchi")
	var radice := (load(scena) as PackedScene).instantiate()
	if &"giocatore_proprio" in radice:
		radice.set(&"giocatore_proprio", false)
	add_child(radice)
	await _frames(10)
	var r := radice.get_node_or_null(^"Risalita")
	if r and r.has_method(&"carica_subito"):
		r.call(&"carica_subito")
		await _frames(10)
	if radice.has_method(&"costruisci"):
		radice.call(&"costruisci")
		await _frames(5)
	radice.process_mode = Node.PROCESS_MODE_DISABLED
	var mesh_tutte: Array = radice.find_children("*", "MeshInstance3D", true, false)
	var nodi_tutti: Array = radice.find_children("*", "Node3D", true, false)
	var re := RegEx.create_from_string(IMPORTANTI)
	for s in miei:
		await _controlla(s, mesh_tutte, nodi_tutti, re)
	get_tree().quit()


func _scena_per_zona(z: String) -> String:
	match z:
		"torre", "inseguimento":
			return "res://scenes/sala/torre/sala_torre.tscn"
		"tunnel":
			return "res://scenes/sala/sottomarino/sala_sottomarino.tscn"
	return "res://scenes/sala_principale.tscn"


## La scatola di una decal nel mondo come AABB.
func _aabb_box(t: Transform3D, size: Vector3) -> AABB:
	var a := AABB(t.origin, Vector3.ZERO)
	for i in 8:
		var p := Vector3((i & 1) * 2 - 1, ((i >> 1) & 1) * 2 - 1, ((i >> 2) & 1) * 2 - 1) * size * 0.5
		a = a.expand(t * p)
	return a


func _controlla(s: Dictionary, mesh_tutte: Array, nodi_tutti: Array, re: RegEx) -> void:
	var nome := String(s["nome"])
	var n := _vec(s["normale"]).normalized()
	var c := _vec(s["centro"])
	var x := Vector3.UP.cross(n).normalized()
	var z := x.cross(n).normalized()
	var t := Transform3D(Basis(x, n, z), c)
	var size := Vector3(float(s["largo"]), SPESSORE * 2.0, float(s["alto"]))
	var box := _aabb_box(t, size)
	# le mesh vicine: collisioni solo per loro
	var corpi := []
	var dentro := []
	for m in mesh_tutte:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var a := mi.global_transform * mi.get_aabb()
		if not a.intersects(box.grow(0.5)):
			continue
		var sb := StaticBody3D.new()
		sb.process_mode = Node.PROCESS_MODE_ALWAYS   # (la scena è ferma: un corpo fermo esce dalla fisica)
		sb.set_meta(&"mesh", mi)
		mi.add_child(sb)
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		sb.add_child(cs)
		corpi.append(sb)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var spazio := get_viewport().world_3d.direct_space_state
	var vuoti := 0
	var storti := 0
	var rilievi := 0
	var colpite := {}
	var NX := 13
	var NZ := 7
	for i in NX:
		for k in NZ:
			var u := (float(i) / (NX - 1) - 0.5) * size.x * 0.98
			var v := (float(k) / (NZ - 1) - 0.5) * size.z * 0.98
			var p := c + x * u + z * v
			var q := PhysicsRayQueryParameters3D.create(p + n * SPESSORE, p - n * SPESSORE)
			q.hit_back_faces = false
			var h := spazio.intersect_ray(q)
			if h.is_empty():
				vuoti += 1
				continue
			var mi: MeshInstance3D = (h["collider"] as Node).get_meta(&"mesh")
			colpite[mi] = int(colpite.get(mi, 0)) + 1
			if (h["normal"] as Vector3).dot(n) < 0.9:
				storti += 1
			elif absf(((h["position"] as Vector3) - c).dot(n)) > 0.03:
				rilievi += 1
	# dov'è davvero la superficie davanti e dietro (sul centro, 2 m per parte)
	var q2 := PhysicsRayQueryParameters3D.create(c + n * 2.0, c - n * 2.0)
	var h2 := spazio.intersect_ray(q2)
	var sonda := "niente" if h2.is_empty() else "%s a %.3f m dal piano (normale %s)" % [((h2["collider"] as Node).get_meta(&"mesh") as Node).name, ((h2["position"] as Vector3) - c).dot(n), (h2["normal"] as Vector3).snapped(Vector3.ONE * 0.01)]
	var muro: MeshInstance3D = null
	var piu := 0
	for mi in colpite:
		if colpite[mi] > piu:
			piu = colpite[mi]
			muro = mi
	# le altre mesh che entrano nella scatola (dove la decal disegnerebbe anche su di loro)
	for m in mesh_tutte:
		var mi := m as MeshInstance3D
		if mi == muro or mi.mesh == null:
			continue
		var a := mi.global_transform * mi.get_aabb()
		if a.intersects(box) and colpite.has(mi) or (a.intersects(box) and _tocca_box(mi, t, size)):
			dentro.append("%s%s" % [mi.name, "" if mi.is_visible_in_tree() else " (nascosta)"])
	# gli oggetti importanti vicini
	var vicini := []
	var area := box.grow(1.0)
	for nd in nodi_tutti:
		var n3 := nd as Node3D
		if re.search(String(n3.name)) == null:
			continue
		var a: AABB
		if n3 is VisualInstance3D:
			a = n3.global_transform * (n3 as VisualInstance3D).get_aabb()
		else:
			a = AABB(n3.global_position, Vector3.ZERO)
		if a.intersects(area):
			var d := _distanza(a, box)
			vicini.append("%s %.2f m%s" % [n3.name, d, "" if n3.is_visible_in_tree() else " (nascosto)"])
	print("SCARABOCCHIO %s (%s) muro=%s raggi %d: vuoti %d, storti %d, rilievi %d" % [nome, s["zona"],
			muro.name if muro else "-", NX * NZ, vuoti, storti, rilievi])
	print("  centro: la prima superficie lungo la normale è ", sonda)
	if not dentro.is_empty():
		print("  DENTRO la scatola: ", ", ".join(dentro))
	if not vicini.is_empty():
		print("  VICINO (entro 1 m): ", ", ".join(vicini.slice(0, 12)))
	for sb in corpi:
		sb.queue_free()
	await get_tree().physics_frame


## Se la mesh ha vertici dentro la scatola della decal (non solo la sua AABB).
func _tocca_box(mi: MeshInstance3D, t: Transform3D, size: Vector3) -> bool:
	var inv := t.affine_inverse() * mi.global_transform
	var mezzo := size * 0.5
	for sup in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(sup)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if vs.size() > 200000:
			continue
		for v in vs:
			var p := inv * v
			if absf(p.x) < mezzo.x and absf(p.y) < mezzo.y and absf(p.z) < mezzo.z:
				return true
	return false


func _distanza(a: AABB, b: AABB) -> float:
	var d := Vector3.ZERO
	for i in 3:
		d[i] = maxf(0.0, maxf(a.position[i] - b.end[i], b.position[i] - a.end[i]))
	return d.length()
