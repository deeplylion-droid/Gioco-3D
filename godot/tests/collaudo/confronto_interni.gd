extends Node
## Collaudo: impronta degli interni (nodi, mesh, materiali, collisioni, luci) e celle dove passa la capsula del
## giocatore (raggio 0,35 m), per confrontare due commit.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/confronto_interni.gd \
##     <stato: inizio|aperto> <uscita senza estensione> [sala]
## Con "sala" apre sala_principale.tscn e guarda il suo nodo Interni (posizioni nel mondo della sala).
## Scrive <uscita>_nodi.json e <uscita>_celle.json.

const STATI := preload("res://tests/collaudo/stati.gd")
const PASSO := 0.1
const RAGGIO := 0.35
const GRADINO := 0.32
const ALTEZZA := 1.75
const MASCHERA := 1 | 8 | 256

var stato := "inizio"
var uscita := ""
var livello: Node3D
var radice: Node3D
var nella_sala := false
var _spazio: PhysicsDirectSpaceState3D


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	var a := OS.get_cmdline_user_args()
	stato = a[1]
	uscita = a[2]
	nella_sala = a.size() > 3 and a[3] == "sala"
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var scena := "res://scenes/sala_principale.tscn" if nella_sala else "res://scenes/interni/interni.tscn"
	livello = (load(scena) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	radice = livello.get_node(^"Interni") if nella_sala else livello
	for i in 30:
		await get_tree().physics_frame
	get_tree().paused = false
	var p := GameState.player
	for i in 900:
		if p == null or not is_instance_valid(p) or p.input_enabled:
			break
		await get_tree().physics_frame
	var cps := []
	for cp in radice.find_children("*", "Checkpoint", true, false):
		var t: Transform3D = cp.call(&"get_spawn_transform")
		cps.append({"nodo": String(radice.get_path_to(cp)), "ordine": int(cp.get(&"order")), "pos": _v(t.origin)})
	if stato == "aperto":
		# l'armadietto che sbatte, come quando ci passa il giocatore
		if radice.has_method(&"_on_trigger_armadietto") and p:
			radice.call(&"_on_trigger_armadietto", p)
		STATI.applica(livello, stato)
		for i in 300:
			await get_tree().physics_frame
	# il giocatore fuori dai piedi: non deve entrare nelle celle
	if p and is_instance_valid(p):
		p.global_position = Vector3(0, -500, 0)
		p.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 5:
		await get_tree().physics_frame
	_spazio = radice.get_world_3d().direct_space_state
	var nodi := _nodi(p)
	var f := FileAccess.open(uscita + "_nodi.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(nodi, " ", true))
	f.close()
	print("CONFRONTO: %d nodi" % nodi.size())
	var celle := _celle(cps)
	f = FileAccess.open(uscita + "_celle.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"passo": PASSO, "checkpoint": cps, "celle": celle}))
	f.close()
	print("CONFRONTO: %d celle dove passa la capsula" % celle.size())
	get_tree().quit()


func _v(v: Vector3, s := 0.001) -> Array:
	return [snappedf(v.x, s), snappedf(v.y, s), snappedf(v.z, s)]


func _mat(m: Material) -> String:
	if m == null:
		return ""
	var s := m.resource_path if m.resource_path != "" else m.resource_name
	if s == "":
		s = m.get_class()
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		s += " col=%s tr=%d cull=%d" % [b.albedo_color.to_html(), b.transparency, b.cull_mode]
		if b.albedo_texture:
			s += " tex=" + b.albedo_texture.resource_path.get_file()
	elif m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		s += " shader=" + (sh.resource_path.get_file() if sh else "")
	return s


## La parte di triangoli che guarda dalla parte delle normali dei vertici (1 = tutte dritte, 0 = tutte rovesciate).
func _dritte(m: Mesh) -> float:
	var si := 0
	var tot := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn = arr[Mesh.ARRAY_NORMAL]
		if nn == null or (nn as PackedVector3Array).is_empty():
			continue
		var idx = arr[Mesh.ARRAY_INDEX]
		var ii: PackedInt32Array = idx if idx != null else PackedInt32Array(range(v.size()))
		for k in range(0, ii.size(), 3):
			var a := v[ii[k]]
			var g := (v[ii[k + 1]] - a).cross(v[ii[k + 2]] - a)
			var media: Vector3 = nn[ii[k]] + nn[ii[k + 1]] + nn[ii[k + 2]]
			tot += 1
			# Godot: davanti è il verso orario, la normale geometrica di (b-a)x(c-a) guarda dietro
			if g.dot(media) < 0.0:
				si += 1
	return snappedf(float(si) / maxf(tot, 1), 0.001)


func _nodi(p: Node) -> Dictionary:
	var out := {}
	for n in radice.find_children("*", "Node3D", true, false):
		if p and (n == p or p.is_ancestor_of(n)):
			continue
		var n3 := n as Node3D
		var t := n3.global_transform
		var e := {"classe": n.get_class(), "pos": _v(t.origin), "rot": _v(t.basis.get_euler() * 180.0 / PI, 0.1),
				"scala": _v(t.basis.get_scale()), "visibile": n3.is_visible_in_tree()}
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh:
				var tri := 0
				for s in mi.mesh.get_surface_count():
					var arr := mi.mesh.surface_get_arrays(s)
					var idx = arr[Mesh.ARRAY_INDEX]
					tri += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
				var b: AABB = t * mi.mesh.get_aabb()
				e["triangoli"] = tri
				e["dritte"] = _dritte(mi.mesh)
				e["box"] = _v(b.position) + _v(b.size)
				var mats := []
				for s in mi.mesh.get_surface_count():
					mats.append(_mat(mi.get_active_material(s)))
				e["materiali"] = mats
				e["ombra"] = mi.cast_shadow
				e["trasparenza"] = snappedf(mi.transparency, 0.01)
			else:
				e["triangoli"] = 0
		elif n is CollisionShape3D:
			var c := n as CollisionShape3D
			var co := c.get_parent() as CollisionObject3D
			e["disattiva"] = c.disabled
			e["livello"] = co.collision_layer if co else -1
			e["corpo_attivo"] = co.process_mode != Node.PROCESS_MODE_DISABLED if co else false
			var sh := c.shape
			e["forma"] = sh.get_class() if sh else ""
			if sh is BoxShape3D:
				e["misure"] = _v((sh as BoxShape3D).size)
			elif sh is CapsuleShape3D or sh is CylinderShape3D:
				e["misure"] = [snappedf(sh.get(&"radius"), 0.001), snappedf(sh.get(&"height"), 0.001)]
			elif sh is SphereShape3D:
				e["misure"] = [snappedf((sh as SphereShape3D).radius, 0.001)]
			if sh:
				var b: AABB = t * sh.get_debug_mesh().get_aabb()
				e["box"] = _v(b.position) + _v(b.size)
			if sh is ConcavePolygonShape3D:
				e["facce"] = (sh as ConcavePolygonShape3D).get_faces().size() / 3
			elif sh is ConvexPolygonShape3D:
				e["punti"] = (sh as ConvexPolygonShape3D).points.size()
		elif n is Light3D:
			var l := n as Light3D
			e["energia"] = snappedf(l.light_energy, 0.01)
			e["colore"] = l.light_color.to_html()
			e["ombre"] = l.shadow_enabled
			if l is OmniLight3D:
				e["portata"] = snappedf((l as OmniLight3D).omni_range, 0.01)
			elif l is SpotLight3D:
				e["portata"] = snappedf((l as SpotLight3D).spot_range, 0.01)
				e["angolo"] = snappedf((l as SpotLight3D).spot_angle, 0.1)
		elif n is Decal:
			e["misure"] = _v((n as Decal).size)
			var tx := (n as Decal).texture_albedo
			e["texture"] = tx.resource_path.get_file() if tx else ""
		elif n is Area3D:
			e["monitoring"] = (n as Area3D).monitoring
		out[String(radice.get_path_to(n))] = e
	return out


func _raggio(da: Vector3, a: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(da, a, Layers.WORLD)
	q.hit_back_faces = true
	return _spazio.intersect_ray(q)


## Le celle (10 cm) dove sta in piedi la capsula del giocatore, raggiungibili dai punti di ripartenza dei
## checkpoint: gradini fino a 32 cm, capsula di 35 cm di raggio dal gradino fino a 1,75 m.
func _celle(cps: Array) -> Array:
	var limiti := AABB()
	var primo := true
	for c in radice.find_children("*", "CollisionShape3D", true, false):
		var co := (c as Node).get_parent() as CollisionObject3D
		if co == null or co is Area3D or (co.collision_layer & Layers.WORLD) == 0 or (c as CollisionShape3D).shape == null:
			continue
		if co is CharacterBody3D:
			continue
		var b: AABB = (c as Node3D).global_transform * (c as CollisionShape3D).shape.get_debug_mesh().get_aabb()
		if b.size.length() > 400.0:
			continue
		limiti = b if primo else limiti.merge(b)
		primo = false
	var cap := CapsuleShape3D.new()
	cap.radius = RAGGIO
	cap.height = ALTEZZA - GRADINO
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = MASCHERA
	var x0 := floorf(limiti.position.x / PASSO) * PASSO
	var z0 := floorf(limiti.position.z / PASSO) * PASSO
	var nx := int((limiti.end.x - x0) / PASSO) + 1
	var nz := int((limiti.end.z - z0) / PASSO) + 1
	var colonne := {}
	for ix in nx:
		for iz in nz:
			var x := x0 + ix * PASSO
			var zz := z0 + iz * PASSO
			var y := limiti.end.y + 1.0
			var piani := []
			for k in 10:
				var h := _raggio(Vector3(x, y, zz), Vector3(x, limiti.position.y - 1.0, zz))
				if h.is_empty():
					break
				if (h.normal as Vector3).y >= 0.7:
					piani.append((h.position as Vector3).y)
				y = (h.position as Vector3).y - 0.05
			if not piani.is_empty():
				colonne[Vector2i(ix, iz)] = piani
	var libero := func(c: Vector2i, yy: float) -> bool:
		var centro := Vector3(x0 + c.x * PASSO, yy, z0 + c.y * PASSO)
		q.transform = Transform3D(Basis(), centro + Vector3(0, GRADINO + cap.height * 0.5, 0))
		if not _spazio.intersect_shape(q, 1).is_empty():
			return false
		# da dentro un muro a trimesh la capsula non tocca niente: lo dice il raggio verso l'alto
		return _raggio(centro + Vector3(0, 0.1, 0), centro + Vector3(0, ALTEZZA, 0)).is_empty()
	var raggiunte := {}
	var coda := []
	for cp in cps:
		var s := Vector3(cp.pos[0], cp.pos[1], cp.pos[2])
		var c := Vector2i(roundi((s.x - x0) / PASSO), roundi((s.z - z0) / PASSO))
		# il punto di ripartenza o la cella libera più vicina (entro 30 cm)
		var fatto := false
		for r in 4:
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					var c2 := c + Vector2i(dx, dz)
					if fatto or not colonne.has(c2):
						continue
					var piani: Array = colonne[c2]
					for i in piani.size():
						if not fatto and absf(float(piani[i]) - s.y) < 0.6 and libero.call(c2, float(piani[i])):
							var k := Vector3i(c2.x, i, c2.y)
							if not raggiunte.has(k):
								raggiunte[k] = int(cp.ordine)
								coda.append(k)
							fatto = true
		if not fatto:
			print("CONFRONTO: checkpoint %s senza cella libera" % cp.nodo)
	while not coda.is_empty():
		var k: Vector3i = coda.pop_front()
		var y: float = colonne[Vector2i(k.x, k.z)][k.y]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c := Vector2i(k.x + d.x, k.z + d.y)
			if not colonne.has(c):
				continue
			var piani: Array = colonne[c]
			for i in piani.size():
				var y2 := float(piani[i])
				if absf(y2 - y) > GRADINO:
					continue
				var k2 := Vector3i(c.x, i, c.y)
				if raggiunte.has(k2) or not libero.call(c, y2):
					continue
				raggiunte[k2] = raggiunte[k]
				coda.append(k2)
	var out := []
	for k in raggiunte:
		out.append([snappedf(x0 + k.x * PASSO, 0.01), snappedf(float(colonne[Vector2i(k.x, k.z)][k.y]), 0.01), snappedf(z0 + k.z * PASSO, 0.01), raggiunte[k]])
	return out
