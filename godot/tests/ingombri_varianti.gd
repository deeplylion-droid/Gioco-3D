extends Node
## Strumento (non è un test della CI): prova un'altra posizione degli acquari (P2, P3: una scena
## generata con ACQUARI_POSIZIONE=... assets_src/enigma_acquari/genera_scena.py) nella sala principale,
## senza toccare quella del gioco. Spegne le collisioni dell'enigma vero, mette la variante accanto e
## controlla che le sue collisioni non entrino in niente, che il viale fino al portone e la corsa del
## portone (6,4 m verso +z) restino liberi.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/ingombri_varianti.gd <variante.tscn>

const LEVEL := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	var level := get_tree().current_scene
	var vero := level.get_node(^"Gioco/EnigmaAcquari")
	for cs in vero.find_children("*", "CollisionShape3D", true, false):
		(cs as CollisionShape3D).disabled = true
	var var_scena := load(a[1]) as PackedScene
	var variante := var_scena.instantiate() as Node3D
	variante.set_script(null)   # solo la geometria: la logica vuole il portone e la serranda
	variante.name = "Variante"
	level.get_node(^"Gioco").add_child(variante)
	variante.global_transform = (vero as Node3D).global_transform
	for i in 30:
		await get_tree().physics_frame
	var space := variante.get_world_3d().direct_space_state
	var propri: Array[RID] = [GameState.player.get_rid()]
	for b in variante.find_children("*", "CollisionObject3D", true, false):
		propri.append((b as CollisionObject3D).get_rid())
	var errori := 0
	for cs in variante.find_children("*", "CollisionShape3D", true, false):
		var f := cs as CollisionShape3D
		if f.disabled or f.shape == null or not (f.get_parent() is StaticBody3D) or f.name == &"Rampa":
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = f.shape
		q.transform = f.global_transform.translated(Vector3(0.0, 0.02, 0.0))
		q.exclude = propri
		for r in space.intersect_shape(q, 8):
			var n := r.get("collider") as Node
			print("TOCCA %s con %s" % [variante.get_path_to(f), level.get_path_to(n) if n else "?"])
			errori += 1
	# il viale (da ovest fino al portone) e la corsa del portone: niente della variante
	var zone := [AABB(Vector3(2.0, 0.05, -18.6), Vector3(17.2, 2.2, 7.2)), AABB(Vector3(19.25, 0.05, -18.6), Vector3(1.0, 6.0, 13.6))]
	for z in zone:
		var q := PhysicsShapeQueryParameters3D.new()
		var b := BoxShape3D.new()
		b.size = z.size
		q.shape = b
		q.transform = Transform3D(Basis.IDENTITY, z.get_center())
		q.collision_mask = 0xFFFFFFFF
		for r in space.intersect_shape(q, 16):
			var n := r.get("collider") as Node
			if n and variante.is_ancestor_of(n):
				print("NEL PASSAGGIO %s: %s" % [z, variante.get_path_to(n)])
				errori += 1
	# anche le mesh (tubi, gradini, lampada) fuori dalla corsa del portone
	for vi in variante.find_children("*", "VisualInstance3D", true, false):
		if vi is Light3D or variante.get_node(^"LampadePortone").is_ancestor_of(vi):
			continue   # la cornice delle lampadine è la stessa in tutte le posizioni
		var box := (vi as VisualInstance3D).global_transform * (vi as VisualInstance3D).get_aabb()
		if box.intersects(zone[1]):
			print("MESH NELLA CORSA DEL PORTONE: ", variante.get_path_to(vi), " ", box)
			errori += 1
	for n in ["AcquarioGiallo", "AcquarioMisto", "AcquarioBlu", "Pedana", "Valvola", "LampadaValvola"]:
		print("%s in %s" % [n, (variante.get_node(n) as Node3D).global_position])
	print("RISULTATO VARIANTE: %d problemi" % errori)
	get_tree().quit(0)
