extends Node
## Sonda delle paratie coi bersagli da luna park (grafica-2, 0.3.21; ricontrollo di ambienti-1). Nella sala
## dell'inseguimento vera (con le sagome del club), per ogni paratia, chiusa e aperta del tutto: cosa entra nel pannello
## (la sua forma convessa, rimpicciolita del 5 per mille attorno al centro, contro le collisioni e i corpi dalle mesh
## visibili di tutto il resto: muri, bocche, sagome). Poi il getto vero sul bersaglio: quanto ci mette ad aprirsi.
## Uso (sotto il render.lock):
##   godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_paratie_bersagli.gd

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"
const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")

var sala: SalaInseguimento


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	sala = (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	sala.crea_luci = false
	add_child(sala)
	for i in 1200:
		await get_tree().physics_frame
		if sala.costruita:
			break
	for i in 10:
		await get_tree().physics_frame
	var n := 0
	for v in sala.dati["vasche"]:
		var r: Array = v["rett"]
		var c := SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(v["fondo"])])
		n += CorpiMesh.crea(sala, AABB(c, Vector3.ZERO).grow(12.0), sala.lei)
	print("PARATIE: %d paratie, corpi dalle mesh %d, sagome %s" % [sala.paratie.size(), n, sala.get_node_or_null(^"SagomeClub") != null])
	for i in 4:
		await get_tree().physics_frame
	var difetti := 0
	for stato in ["chiusa", "aperta"]:
		if stato == "aperta":
			for d in sala.paratie:
				d["apre"] = true
				d["aperta"] = 0.999
			sala._muovi_paratie(1.0)
			for i in 4:
				await get_tree().physics_frame
		for d in sala.paratie:
			var pn := d["pannello_nodo"] as Node3D
			var tocchi := _dentro(pn)
			var nome := "vasca %d %s" % [int(d["vasca"]) + 1, "giusta" if bool(d["giusta"]) else "sbagliata"]
			print("PARATIE: %s, %s (pannello in %s): %s" % [nome, stato, pn.global_position.snapped(Vector3.ONE * 0.01),
					"niente dentro" if tocchi.is_empty() else "DENTRO " + str(tocchi)])
			if not tocchi.is_empty():
				difetti += 1
				print("PARATIE:   %s" % _quanto(pn))
	# il getto vero: si colpisce il bersaglio della giusta di ogni vasca fino a quando è alzata del tutto
	for d in sala.paratie:
		d["apre"] = false
		d["aperta"] = 0.0
		d["getto"] = 0.0
	sala._muovi_paratie(0.0)
	for d in sala.paratie:
		(d["pannello_nodo"] as Node3D).global_position = d["chiuso"]
		if not bool(d["giusta"]):
			continue
		var hb := d["bersaglio_nodo"] as Node
		var t := 0.0
		var t_apre := -1.0
		for f in 900:
			if not bool(d["apre"]):
				hb.emit_signal(&"water_hit", 1.0, (hb as Node3D).global_position, Vector3.FORWARD)
			await get_tree().physics_frame
			sala._muovi_paratie(1.0 / 60.0)
			t += 1.0 / 60.0
			if bool(d["apre"]) and t_apre < 0.0:
				t_apre = t
			if float(d["aperta"]) >= 1.0:
				break
		print("PARATIE: getto sulla vasca %d giusta: comincia ad aprirsi dopo %.2f s di getto, alzata del tutto a %.2f s (corsa %.2f m)" % [
				int(d["vasca"]) + 1, t_apre, t, float(d["corsa"])])
	print("PARATIE: difetti %d" % difetti)
	print("PARATIE: finito")
	get_tree().quit()


## Cosa entra nel pannello: i nomi dei corpi che toccano la sua forma convessa rimpicciolita (senza i suoi corpi).
func _dentro(pn: Node3D) -> Array:
	var spazio := sala.get_world_3d().direct_space_state
	var suoi: Array[RID] = []
	for b in pn.find_children("*", "CollisionObject3D", true, false):
		suoi.append((b as CollisionObject3D).get_rid())
	if pn is CollisionObject3D:
		suoi.append((pn as CollisionObject3D).get_rid())
	var out := {}
	for m in [pn] + pn.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var forma := mi.mesh.create_convex_shape(true, false)
		var c := mi.get_aabb().get_center()
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma
		q.collision_mask = 0xFFFFFFFF
		q.exclude = suoi
		q.transform = mi.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.995), c - c * 0.995)
		for h in spazio.intersect_shape(q, 8):
			out[_nome(h["collider"])] = true
	return out.keys()


## Di quanto il pannello entra nella struttura: raggi dalla sua faccia di sotto verso il basso e dai lati verso fuori
## (dentro la sua scatola), per vedere dove poggia o si incastra.
func _quanto(pn: Node3D) -> String:
	var spazio := sala.get_world_3d().direct_space_state
	var box := AABB()
	var primo := true
	for m in [pn] + pn.find_children("*", "MeshInstance3D", true, false):
		if m is MeshInstance3D and (m as MeshInstance3D).mesh:
			var b := (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			box = b if primo else box.merge(b)
			primo = false
	var c := box.get_center()
	var out := "scatola %s - %s;" % [box.position.snapped(Vector3.ONE * 0.001), box.end.snapped(Vector3.ONE * 0.001)]
	# sotto: dal centro della scatola in giù
	var r := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(c, c + Vector3.DOWN * 3.0, 0xFFFFFFFF))
	if not r.is_empty():
		out += " sotto il centro il primo colpo a y %.3f (fondo del pannello %.3f: %+.1f mm)" % [(r.position as Vector3).y, box.position.y,
				(box.position.y - (r.position as Vector3).y) * 1000.0]
	# lati lunghi in pianta
	var asse := Vector3.RIGHT if box.size.x > box.size.z else Vector3.BACK
	for s in [-1.0, 1.0]:
		var r2 := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(c, c + asse * s * 3.0, 0xFFFFFFFF))
		if not r2.is_empty():
			var bordo := box.end.dot(asse) if s > 0 else box.position.dot(asse)
			out += " lato %+d: primo colpo a %.1f mm dal bordo del pannello (%s)" % [int(s), ((r2.position as Vector3).dot(asse) - bordo) * s * 1000.0, _nome(r2.collider)]
	return out


func _nome(n: Object) -> String:
	var nd := n as Node
	if nd == null:
		return "?"
	var s := String(nd.name)
	var p := nd.get_parent()
	for i in 3:
		if p == null or p == sala:
			break
		s = String(p.name) + "/" + s
		p = p.get_parent()
	return s
