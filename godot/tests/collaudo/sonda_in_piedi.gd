extends Node
## Sonda: dove si sta in piedi in un rettangolo a una quota (per scegliere il posto di un oggetto, per esempio una
## Polaroid in un angolo). Carica la scena, aspetta che sia costruita e su una griglia di passo 0,25 m cerca il pavimento
## sotto (raggio dall'alto) e lo spazio di una capsula del giocatore sopra. Stampa una mappa: "#" in piedi, "." niente
## pavimento a quella quota, "x" pavimento ma ingombro sopra.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_in_piedi.gd \
##        <scena> <x0> <x1> <z0> <z1> <quota>

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var scena: Node = (load(a[1]) as PackedScene).instantiate()
	var x0 := float(a[2])
	var x1 := float(a[3])
	var z0 := float(a[4])
	var z1 := float(a[5])
	var y := float(a[6])
	get_tree().root.add_child(scena)
	for i in 600:
		await get_tree().physics_frame
		var pronto := true
		for n in scena.find_children("*", "", true, false):
			if &"costruita" in n and not bool(n.get(&"costruita")):
				pronto = false
		if pronto and i > 60:
			break
	var space := (scena as Node3D).get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = Layers.WORLD | Layers.PROPS
	var righe := PackedStringArray()
	var z := z0
	while z <= z1 + 0.001:
		var riga := "%7.2f " % z
		var x := x0
		while x <= x1 + 0.001:
			var r := PhysicsRayQueryParameters3D.create(Vector3(x, y + 1.0, z), Vector3(x, y - 0.6, z), Layers.WORLD | Layers.PROPS)
			var h := space.intersect_ray(r)
			if h.is_empty() or absf((h.position as Vector3).y - y) > 0.25:
				riga += "."
			else:
				q.transform = Transform3D(Basis(), (h.position as Vector3) + Vector3(0, 0.85, 0))
				riga += "x" if not space.intersect_shape(q, 1).is_empty() else "#"
			x += 0.25
		righe.append(riga)
		z += 0.25
	print("SONDA x da %.2f a %.2f (una colonna ogni 0,25 m), quota %.2f" % [x0, x1, y])
	for r in righe:
		print(r)
	get_tree().quit()
