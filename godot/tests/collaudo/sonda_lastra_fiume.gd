extends Node
## Collaudo riga del fiume (#130): dove sono le zone magenta rimaste negli scatti senz'acqua. Rimette la camera degli
## scatti (fiume_giro.gd) e per alcuni pixel tira il raggio dalla camera: dove taglia il pelo (quota 0) e il fondo
## (-0,9), e cosa colpisce con le collisioni (LASTRA:).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_lastra_fiume.gd

const CASI := [["Giusto1", 1.0, 0.97, 70.0, [Vector2(200, 500), Vector2(600, 450), Vector2(700, 430)]],
	["Imbarco", 49.0, 1.65, 0.0, [Vector2(250, 495), Vector2(400, 460), Vector2(540, 410)]],
	["Giusto1", 33.0, 0.97, 0.0, [Vector2(520, 625)]],
	["Giusto2", 1.0, 1.65, 70.0, [Vector2(1180, 245)]]]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	while not bool(f.get(&"costruita")):
		await get_tree().process_frame
	for i in 5:
		await get_tree().physics_frame
	var cam := Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	get_viewport().size = Vector2i(1280, 720)
	var sp := get_tree().root.get_world_3d().direct_space_state
	for c in CASI:
		var t: TrattoFiume = null
		for x in f.find_children(c[0], "TrattoFiume", true, false):
			t = x
		var d := t.direzione(c[1])
		d.y = 0
		d = d.normalized().rotated(Vector3.UP, deg_to_rad(c[3]))
		var p := t.punto(c[1]) + Vector3.UP * float(c[2])
		cam.global_position = p
		cam.look_at(p + d * 10.0 + Vector3.DOWN * 0.9, Vector3.UP)
		for px: Vector2 in c[4]:
			var o := cam.project_ray_origin(px)
			var v := cam.project_ray_normal(px)
			var a0 := o + v * ((0.0 - o.y) / v.y)
			var a1 := o + v * ((-0.9 - o.y) / v.y)
			var q := PhysicsRayQueryParameters3D.create(o, o + v * 60.0)
			var r := sp.intersect_ray(q)
			print("LASTRA: %s %.0f, pixel %s: al pelo %s, al fondo %s, colpo %s %s" % [c[0], c[1], px, Vector2(a0.x, a0.z).snappedf(0.01),
				Vector2(a1.x, a1.z).snappedf(0.01), r.position.snappedf(0.01) if not r.is_empty() else "niente",
				(r.collider as Node).get_parent().name + "/" + (r.collider as Node).name if not r.is_empty() else ""])
	print("LASTRA: finito")
	get_tree().quit()
