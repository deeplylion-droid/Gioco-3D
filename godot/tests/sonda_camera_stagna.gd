extends Node
## Sonda: dove sta la camera stagna in fondo al tunnel e cosa c'è intorno (per allargarla). Senza schermo.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var sala := SalaSottomarino.new()
	get_tree().root.add_child(sala)
	sala.costruisci()
	var L := sala.lunghezza()
	print("L=", L, " p=", sala.punto(L), " d=", sala.direzione(L), " r=", sala.destra(L), " piano=", sala.piano, " muro=", sala.muro)
	for s in [-4.5, 0.0, 2.0, 4.0, 6.0, 8.0, 10.0, L - 40.0, L - 20.0, L - 10.0, L]:
		print("  s=", s, " p=", sala.punto(s), " d=", sala.direzione(s), " r=", sala.destra(s), " canale=", sala.canale, " banchina=", sala.banchina, " acqua=", sala.acqua)
	var aabb := AABB()
	var primo := true
	for mi in sala.find_children("*", "VisualInstance3D", true, false):
		var b := (mi as VisualInstance3D).get_aabb()
		b = (mi as VisualInstance3D).global_transform * b
		if primo:
			aabb = b
			primo = false
		else:
			aabb = aabb.merge(b)
	print("AABB tunnel: ", aabb)
	var box := AABB(Vector3(-62.0, -27.5, 8.0), Vector3(10.0, 4.0, 14.0))
	for mi in sala.find_children("*", "VisualInstance3D", true, false):
		var b := (mi as VisualInstance3D).global_transform * (mi as VisualInstance3D).get_aabb()
		if b.intersects(box):
			print("  vicino: ", sala.get_path_to(mi), " ", b)
	get_tree().quit()
