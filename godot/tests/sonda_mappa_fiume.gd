extends Node
## Sonda: la pianta del fiume (coordinate locali) in JSON: acqua, cose, rocce, collisioni.
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var f := (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	for i in 600:
		await get_tree().process_frame
		if f.get(&"costruita"):
			break
	var out := {"acqua": [], "cose": [], "forme": []}
	for w in f.get(&"_poligoni_acqua_cache"):
		var pts := []
		for p in (w as PackedVector2Array):
			pts.append([p.x, p.y])
		out["acqua"].append(pts)
	for c in f.get_children():
		if c is Node3D:
			var n := c as Node3D
			out["cose"].append([String(n.name), n.position.x, n.position.y, n.position.z, n.rotation_degrees.y, n.get_class()])
	for body in [f.get_node_or_null("Collisioni"), f.get_node_or_null("Barriere")]:
		if body == null:
			continue
		for cs in body.get_children():
			var s := cs as CollisionShape3D
			if s == null or s.shape == null:
				continue
			var t := s.transform
			if s.shape is BoxShape3D:
				out["forme"].append(["box", t.origin.x, t.origin.z, (s.shape as BoxShape3D).size.x, (s.shape as BoxShape3D).size.z, rad_to_deg(t.basis.get_euler().y), t.origin.y, (s.shape as BoxShape3D).size.y])
			elif s.shape is CylinderShape3D:
				out["forme"].append(["cil", t.origin.x, t.origin.z, (s.shape as CylinderShape3D).radius])
	var fa := FileAccess.open("/tmp/claude-0/fiume/mappa.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(out))
	fa.close()
	print("RISULTATO: sonda finita")
	get_tree().quit(0)
