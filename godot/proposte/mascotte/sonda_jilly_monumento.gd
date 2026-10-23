extends Node
## Sonda: Jilly in piedi sul piano del monumento a gradoni dello spot (scenes/spot/sala_spot.tscn, nodo "Jilly"),
## nella posa ferma ("statua") e in tre momenti del saluto. Per i vertici dei tentacoli (skinning sulla CPU, letti a fine
## aggiornamento dello scheletro) stampa: quanti sono dentro le collisioni della scena e di quanto; quanti stanno fuori
## dal piano (raggio dal centro oltre il bordo); per ogni tentacolo il vertice più basso, cioè quanto la punta è sopra
## il piano (deve poggiare: vicino a 0, mai sotto).
## Per la squadra (proposte/ è esclusa dall'export).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- \
##        res://proposte/mascotte/sonda_jilly_monumento.gd

const SCENA := "res://scenes/spot/sala_spot.tscn"
const CENTRO := Vector3(0.0, 1.15, 10.0)
const RAGGIO := 1.88
const PROFONDO := 0.01
## momento: secondi dall'inizio del saluto (-1 = ferma)
const MOMENTI := [["ferma", -1.0], ["alza", 0.45], ["saluta", 1.3], ["giu", 5.6]]

var spazio: PhysicsDirectSpaceState3D
var escludi: Array[RID] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scena := (load(SCENA) as PackedScene).instantiate()
	get_tree().root.add_child(scena)
	for i in 20:
		await get_tree().physics_frame
	var lei := scena.get_node("Jilly") as Node3D
	for co in lei.find_children("*", "CollisionObject3D", true, false):
		escludi.append((co as CollisionObject3D).get_rid())
	spazio = scena.get_viewport().world_3d.direct_space_state
	print("Jilly in ", lei.global_position, " occhio ", lei.call(&"get_eye_position"))
	var ap := lei.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var tempo := 0.0
	var salutato := false
	for m in MOMENTI:
		if float(m[1]) >= 0.0:
			if not salutato:
				lei.call(&"saluta", 3.9)
				salutato = true
			while tempo < float(m[1]):
				await get_tree().process_frame
				tempo += 1.0 / 60.0
		var prima := ap.speed_scale
		ap.speed_scale = 0.0
		await get_tree().process_frame
		await _controlla(lei, String(m[0]) + " (" + String(ap.current_animation) + ")")
		ap.speed_scale = prima
	print("FINE")
	get_tree().quit()


func _controlla(lei: Node3D, nome: String) -> void:
	print("== ", nome)
	for mi in lei.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null or not String(m.name).contains("Tentacoli"):
			continue
		var r: Array = await _vertici(m)
		var vv: PackedVector3Array = r[0]
		var ossi: PackedStringArray = r[1]
		var pieni := 0
		var prof := 0.0
		var dove := ""
		var fuori := 0
		var r_max := 0.0
		var basso := {}
		for i in vv.size():
			var v := vv[i]
			var rr := Vector2(v.x - CENTRO.x, v.z - CENTRO.z).length()
			r_max = maxf(r_max, rr)
			if rr > RAGGIO:
				fuori += 1
			var t := ossi[i].substr(0, 12)       # "tentacolo_NN"
			if not basso.has(t) or v.y < float(basso[t]):
				basso[t] = v.y
			if _dentro(v):
				var p := _uscita(v)
				if p >= PROFONDO:
					pieni += 1
					if p > prof:
						prof = p
						dove = "%s %s" % [_v(v), ossi[i]]
		print("   %s: %d vertici; nel pieno %d%s; oltre il bordo del piano %d (raggio massimo %.2f m su %.2f)" % [m.name,
			vv.size(), pieni, "" if pieni == 0 else " fino a %.1f cm, %s" % [prof * 100.0, dove], fuori, r_max, RAGGIO])
		var righe := []
		var chiavi := basso.keys()
		chiavi.sort()
		for t in chiavi:
			righe.append("%s %+.1f" % [String(t).substr(10), (float(basso[t]) - CENTRO.y) * 100.0])
		print("      punta più bassa sopra il piano (cm), per tentacolo: ", ", ".join(righe))


func _dentro(v: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = v
	q.exclude = escludi
	return not spazio.intersect_point(q, 1).is_empty()


func _uscita(v: Vector3) -> float:
	var migliore := 9.0
	for dir in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var t := 0.0
		while t < minf(migliore, 1.0):
			t += 0.005
			if not _dentro(v + dir * t):
				migliore = minf(migliore, t)
				break
	return migliore


func _vertici(mi: MeshInstance3D) -> Array:
	var out := PackedVector3Array()
	var ossi := PackedStringArray()
	var sk := mi.get_node(mi.skeleton) as Skeleton3D
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
		for i in v.size():
			var q := Vector3.ZERO
			var tw := 0.0
			var jm := 0
			for j in k:
				if w[i * k + j] > 0.0:
					q += (pose[b[i * k + j]] as Transform3D) * v[i] * w[i * k + j]
					tw += w[i * k + j]
				if w[i * k + j] > w[i * k + jm]:
					jm = j
			out.append(q / tw if tw > 0.0 else mi.global_transform * v[i])
			ossi.append(mi.skin.get_bind_name(b[i * k + jm]))
	return [out, ossi]


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
