extends Node
## Collaudo riga del fiume (#130): dove stanno nel mondo i residui magenta degli scatti senz'acqua (casi in un JSON fatto
## dagli scatti: tratto, s, altezza o banchina, verso, pixel). Per ogni pixel il raggio dalla camera: dove taglia il pelo
## (quota 0) e cosa colpisce con le collisioni (RES:).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_residui_fiume.gd <casi.json>

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var casi: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[1]))
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
	for c: Dictionary in casi:
		var t: TrattoFiume = null
		for x in f.find_children(String(c["tratto"]), "TrattoFiume", true, false):
			t = x
		var s: float = c["s"]
		var d := t.direzione(s)
		d.y = 0
		d = d.normalized()
		if String(c["alt"]) == "banchina":
			var centro := t.punto(s)
			var lato := d.cross(Vector3.UP).normalized() * (1.0 if String(c["ang"]) == "dx" else -1.0)
			var da := centro + lato * 3.6
			da.y = 1.6
			cam.global_position = da
			cam.look_at(Vector3(centro.x, -0.4, centro.z), Vector3.UP)
		else:
			var gir: float = {"avanti": 0.0, "sinistra": 70.0, "destra": -70.0}[String(c["ang"])]
			var dir := d.rotated(Vector3.UP, deg_to_rad(gir))
			var p := t.punto(s) + Vector3.UP * (1.65 if String(c["alt"]) == "piedi" else 0.97)
			cam.global_position = p
			cam.look_at(p + dir * 10.0 + Vector3.DOWN * 0.9, Vector3.UP)
		var righe := []
		for px in c["pixel"]:
			var v2 := Vector2(px[0], px[1])
			var o := cam.project_ray_origin(v2)
			var v := cam.project_ray_normal(v2)
			var a0: Vector3 = o + v * ((0.0 - o.y) / v.y) if v.y < -0.001 else Vector3(INF, INF, INF)
			var q := PhysicsRayQueryParameters3D.create(o, o + v * 80.0)
			var r := sp.intersect_ray(q)
			righe.append("pelo %s, colpo %s" % [Vector2(a0.x, a0.z).snappedf(0.01), r.position.snappedf(0.01) if not r.is_empty() else "niente"])
		print("RES: %s (prima %d, dopo %d px; camera %s): %s" % [c["nome"], c["prima"], c["dopo"], cam.global_position.snappedf(0.01), " | ".join(righe)])
	print("RES: finito")
	get_tree().quit()
