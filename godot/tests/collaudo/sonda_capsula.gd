extends Node
## Collaudo: per ogni punto di un elenco ("x y z [nota]", nella scena degli interni da sola), che cosa tocca la capsula
## del giocatore (raggio 0,35 m, dal gradino di 32 cm fino a 1,75 m) e dove.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_capsula.gd \
##     <stato> <elenco>

const STATI := preload("res://tests/collaudo/stati.gd")


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	Game.pause_on_focus_loss = false
	var scena := a[3] if a.size() > 3 else "res://scenes/interni/interni.tscn"
	var livello := (load(scena) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 30:
		await get_tree().physics_frame
	get_tree().paused = false
	var p := GameState.player
	if a[1] == "aperto":
		if livello.has_method(&"_on_trigger_armadietto") and p:
			livello.call(&"_on_trigger_armadietto", p)
		STATI.applica(livello, a[1])
		for i in 300:
			await get_tree().physics_frame
	if p:
		p.global_position = Vector3(0, -500, 0)
		p.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 5:
		await get_tree().physics_frame
	var spazio := livello.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75 - 0.32
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1 | 8 | 256
	for riga in FileAccess.get_file_as_string(a[2]).split("\n", false):
		var v := riga.split(" ", false)
		var c := Vector3(float(v[0]), float(v[1]), float(v[2]))
		q.transform = Transform3D(Basis(), c + Vector3(0, 0.32 + cap.height * 0.5, 0))
		var tocchi := spazio.intersect_shape(q, 16)
		var punti := spazio.collide_shape(q, 32)
		var nomi := PackedStringArray()
		for t in tocchi:
			var co := t.collider as Node
			nomi.append("%s#%d" % [livello.get_path_to(co) if co else "?", t.shape])
		var vicino := Vector3.INF
		for pt in punti:
			var w := (pt as Vector3)
			if Vector2(w.x - c.x, w.z - c.z).length() < Vector2(vicino.x - c.x, vicino.z - c.z).length():
				vicino = w
		print("SONDA %s -> %s punto %s" % [riga, ", ".join(nomi) if nomi.size() else "libero",
				vicino.snapped(Vector3.ONE * 0.01) if vicino != Vector3.INF else "-"])
	get_tree().quit()
