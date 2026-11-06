extends Node
## La trave sotto il piano dello scolo 2 (x 73,8-74,0, sotto -31,35) contro la scatola a mano per i tentacoli
## (genera_forme_inseguimento.gd, A_MANO "scolo_2", e inseguimento_forme_lei.json): raggi sulla geometria vera
## (collisioni più mesh visibili) per trovare dove finisce la trave in basso, ai lati e alle estremità, e se esce dalla
## scatola. Ricontrollo di ambienti-1 (6 novembre).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_trave_scolo2.gd

const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const SCATOLA := [73.8, -31.70, -16.086, 74.0, -31.35, -11.886]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sala := (load("res://scenes/sala/inseguimento/sala_inseguimento.tscn") as PackedScene).instantiate() as SalaInseguimento
	sala.crea_luci = false
	add_child(sala)
	for i in 600:
		await get_tree().physics_frame
		if sala.costruita:
			break
	print("TRAVE: corpi dalle mesh %d" % CorpiMesh.crea(sala, AABB(Vector3(73.9, -31.5, -14.0), Vector3.ZERO).grow(4.0), sala.lei))
	for i in 4:
		await get_tree().physics_frame
	var sp := sala.get_world_3d().direct_space_state
	var json := FileAccess.get_file_as_string("res://assets/models/medusa/inseguimento/inseguimento_forme_lei.json")
	print("TRAVE: nel json la scatola c'è: %s" % json.contains("73.8"))
	# il fondo della trave: raggi dal basso (da -33) in su, a x 73,82..73,98, lungo z
	var fondo_min := INF
	var fondo_max := -INF
	var z := -16.4
	var fuori := []
	while z <= -11.5:
		for x in [73.75, 73.82, 73.9, 73.98, 74.05]:
			var a := Vector3(x, -33.0, z)
			var r := sp.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3.UP * 2.0, 0xFFFFFFFF))
			if r.is_empty():
				continue
			var y := (r.position as Vector3).y
			if y > -31.36:
				continue
			fondo_min = minf(fondo_min, y)
			fondo_max = maxf(fondo_max, y)
			var dentro: bool = x >= SCATOLA[0] and x <= SCATOLA[3] and z >= SCATOLA[2] and z <= SCATOLA[5] and y >= SCATOLA[1] - 0.001
			if not dentro:
				fuori.append("(%.2f, %.3f, %.2f)" % [x, y, z])
		z += 0.1
	print("TRAVE: sotto -31,36 la geometria fra x 73,75 e 74,05 arriva da %.3f a %.3f" % [fondo_min, fondo_max])
	print("TRAVE: punti sotto il piano fuori dalla scatola %d %s" % [fuori.size(), fuori.slice(0, 12)])
	# i lati: raggi orizzontali in x a -31,6 da fuori verso la trave
	for zz in [-16.0, -14.0, -12.0]:
		for dir in [[73.5, 1.0], [74.3, -1.0]]:
			var a := Vector3(dir[0], -31.6, zz)
			var r := sp.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3(dir[1], 0, 0) * 0.8, 0xFFFFFFFF))
			print("TRAVE: lato a z %.1f da x %.1f: %s" % [zz, dir[0], ("x %.3f" % (r.position as Vector3).x) if not r.is_empty() else "-"])
	# le estremità: raggi in z a -31,6
	for dir in [[-17.0, 1.0], [-11.0, -1.0]]:
		var a := Vector3(73.9, -31.6, dir[0])
		var r := sp.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3(0, 0, dir[1]) * 1.5, 0xFFFFFFFF))
		print("TRAVE: estremità da z %.1f: %s" % [dir[0], ("z %.3f" % (r.position as Vector3).z) if not r.is_empty() else "-"])
	print("TRAVE: finito")
	get_tree().quit()
