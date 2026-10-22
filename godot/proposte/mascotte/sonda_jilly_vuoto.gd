extends Node
## Sonda: Jilly affacciata alla vasca centrale (Vasca/Medusa) e alla fossa dei bimbi (Gioco/LeiSbuca/MedusaFossa, dopo
## il blackout, fase GUARDA), nella posa del momento con i modificatori dello scheletro (i vertici deformati, letti a
## fine aggiornamento: fuori da skeleton_updated la posa è quella senza modificatori). Il pieno vero sono le collisioni
## statiche del livello (scatole chiuse di pareti, bordi, fondi; non il coperchio invisibile della fossa): per ogni
## vertice dentro una collisione stampa di quanto va spostato per uscirne (il minimo fra i 6 assi e la direzione
## verso il suo occhio) e in quale collisione. Il conteggio "nel vuoto o nell'acqua" usa la mesh contenitore, che non
## è chiusa (pareti a faccia singola, bordi senza fondo): è solo indicativo. Per la fossa stampa anche i vertici dei
## tentacoli all'altezza delle gambe e la loro distanza (in pianta) dall'occhio, da confrontare con
## LeiSbuca.distanza_presa: dentro quella distanza lei ti prende. Alla fine il costo di TentacoliControIMuri.
## Per la squadra (proposte/ è esclusa dall'export).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- \
##        res://proposte/mascotte/sonda_jilly_vuoto.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const STRATO := 1 << 22
const PROFONDO := 0.01          # sotto 1 cm non conta (sfiora)

var level: Node
var spazio: PhysicsDirectSpaceState3D
var escludi: Array[RID] = []
var osso_di: PackedStringArray = []      # per ogni vertice di _vertici: l'osso col peso più grande


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	level = (load(LEVEL) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	for i in 20:
		await get_tree().physics_frame
	GameState.luci = GameState.Luci.BLACKOUT
	var ls := level.get_node("Gioco/LeiSbuca")
	ls.call(&"_affaccia")
	for i in 10:
		await get_tree().physics_frame
	# un altro momento del respiro: "-- <fotogrammi>" dopo lo script li lascia passare prima di fermarla
	var args := OS.get_cmdline_user_args()
	for i in (int(args[1]) if args.size() > 1 else 0):
		await get_tree().process_frame
	for n in level.find_children("*", "AnimationPlayer", true, false):
		(n as AnimationPlayer).pause()
	spazio = level.get_viewport().world_3d.direct_space_state
	var vasca := level.get_node("Sala/VascaCentrale").find_child("sala_vasca_centrale", true, false) as MeshInstance3D
	var fossa := level.get_node("Sala/AreaBimbi").find_child("sala_fossa_bimbi", true, false) as MeshInstance3D
	_corpo(vasca)
	_corpo(fossa)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for co in level.find_children("*", "CollisionObject3D", true, false):
		if String(co.name).begins_with("coperchio") or level.get_node("Vasca/Medusa").is_ancestor_of(co) or ls.is_ancestor_of(co):
			escludi.append((co as CollisionObject3D).get_rid())
	await _controlla(level.get_node("Vasca/Medusa") as Node3D, vasca, null)
	await _controlla(level.get_node("Gioco/LeiSbuca/MedusaFossa") as Node3D, fossa, ls)
	for t in level.find_children("TentacoliControIMuri", "", true, false):
		var somma := 0
		for k in 30:
			await get_tree().process_frame
			somma += int(t.get(&"durata_usec"))
		print("costo di %s: %.2f ms per fotogramma" % [level.get_path_to(t), somma / 30000.0])
	print("FINE")
	get_tree().quit()


func _corpo(mi: MeshInstance3D) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = STRATO
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	b.add_child(cs)
	mi.add_child(b)
	b.global_transform = mi.global_transform
	b.set_meta(&"chi", mi.name)


func _controlla(lei: Node3D, contenitore: MeshInstance3D, ls: Node) -> void:
	var occhio: Vector3 = lei.call(&"get_eye_position")
	print("== %s (occhio %s), contenitore %s" % [level.get_path_to(lei), _v(occhio), contenitore.name])
	var presa := 0.0
	if ls:
		presa = float(ls.get(&"distanza_presa"))
	for mi in lei.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null or not m.is_visible_in_tree():
			continue
		var vv: PackedVector3Array = await _vertici(m)
		var vuoti := 0
		var pieni := 0
		var prof_max := 0.0
		var dove := Vector3.ZERO
		var chi := {}
		var esempi := {}
		var gambe := []
		for iv in vv.size():
			var v := vv[iv]
			var d := _dentro_pieno(occhio, v)
			if d == 1:
				vuoti += 1
			# il pieno vero: dentro una collisione statica (scatole chiuse di pareti, bordi, fondi)
			var c := _collisione(v)
			if c == null:
				continue
			var p := _uscita(v, occhio)
			if p < PROFONDO:
				continue
			pieni += 1
			chi[c.name] = maxf(float(chi.get(c.name, 0.0)), p)
			if not esempi.has(c.name):
				esempi[c.name] = []
			if (esempi[c.name] as Array).size() < 6 and p >= 0.03:
				(esempi[c.name] as Array).append("%s %.0fcm %s" % [_v(v), p * 100.0, osso_di[iv] if iv < osso_di.size() else "?"])
			if p > prof_max:
				prof_max = p
				dove = v
		if ls and String(m.name).contains("Tentacoli"):
			for v in vv:
				if v.y > 0.35 and v.y < 0.6:
					gambe.append(Vector2(v.x - occhio.x, v.z - occhio.z).length())
		print("   %s: %d vertici, %d per la mesh nel vuoto o nell'acqua, %d nel pieno delle collisioni%s" % [m.name, vv.size(),
			vuoti, pieni, "" if pieni == 0 else " fino a %.1f cm, il più profondo a %s" % [prof_max * 100.0, _v(dove)]])
		for k in chi:
			print("      in %s fino a %.1f cm  %s" % [k, float(chi[k]) * 100.0, ", ".join(esempi.get(k, []))])
		if not gambe.is_empty():
			gambe.sort()
			print("      tentacoli all'altezza delle gambe: %d vertici, in pianta da %.2f a %.2f m dall'occhio (lei prende sotto %.2f m)" % [
				gambe.size(), gambe[0], gambe[-1], presa])


## Il vertice secondo la mesh contenitore (che non è chiusa: solo indicativo): 0 fuori, 1 nel vuoto, 2 nel pieno.
func _dentro_pieno(occhio: Vector3, v: Vector3) -> int:
	var giu := PhysicsRayQueryParameters3D.create(v, v + Vector3.DOWN * 6.0, STRATO)
	giu.hit_back_faces = true
	if spazio.intersect_ray(giu).is_empty():
		return 0
	var n := 0
	var da := occhio
	var dir := (v - occhio).normalized()
	for i in 40:
		var q := PhysicsRayQueryParameters3D.create(da, v, STRATO)
		q.hit_back_faces = true
		var h := spazio.intersect_ray(q)
		if h.is_empty():
			break
		n += 1
		da = (h["position"] as Vector3) + dir * 0.0005
	return 2 if n % 2 == 1 else 1


## La collisione statica del livello (non di lei, non il coperchio della fossa) che contiene il punto.
func _collisione(v: Vector3) -> Node:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = v
	q.collision_mask = 0xFFFFFFFF & ~STRATO
	q.exclude = escludi
	for h in spazio.intersect_point(q, 8):
		var o: Object = h.get("collider")
		if o is StaticBody3D or o is AnimatableBody3D:
			return o as Node
	return null


## Quanto va spostato il punto per uscire dal pieno: il minimo fra i 6 assi e la direzione verso l'occhio (passi di 1 cm).
func _uscita(v: Vector3, occhio: Vector3) -> float:
	var migliore := 9.0
	for dir in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, (occhio - v).normalized()]:
		var t := 0.0
		while t < minf(migliore, 2.0):
			t += 0.01
			if _collisione(v + dir * t) == null:
				migliore = minf(migliore, t)
				break
	return migliore


func _vertici(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	osso_di = PackedStringArray()
	var sk := mi.get_node(mi.skeleton) as Skeleton3D
	# la posa con i modificatori (sguardo, tentacoli contro i muri) c'è solo a fine aggiornamento dello scheletro
	await sk.skeleton_updated
	var pose: Array = []
	for i in mi.skin.get_bind_count():
		var osso := mi.skin.get_bind_bone(i)
		if osso < 0:
			osso = sk.find_bone(mi.skin.get_bind_name(i))
		pose.append(sk.global_transform * sk.get_bone_global_pose(osso) * mi.skin.get_bind_pose(i))
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var b: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var k := b.size() / maxi(v.size(), 1)
		var passo := maxi(1, v.size() / 4000)
		for i in range(0, v.size(), passo):
			var q := Vector3.ZERO
			var tw := 0.0
			for j in k:
				if w[i * k + j] > 0.0:
					q += (pose[b[i * k + j]] as Transform3D) * v[i] * w[i * k + j]
					tw += w[i * k + j]
			out.append(q / tw if tw > 0.0 else mi.global_transform * v[i])
			var jm := 0
			for j in k:
				if w[i * k + j] > w[i * k + jm]:
					jm = j
			osso_di.append(mi.skin.get_bind_name(b[i * k + jm]))
	return out


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
