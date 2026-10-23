extends Node
## Prova diagnostica di un ingresso spostato nel canale (tratto e spostamento dagli argomenti).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sim_imbocco.gd <tratto> <spostato> <storto>

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var k := int(a[1]) if a.size() > 1 else 0
	var sp := float(a[2]) if a.size() > 2 else 0.45
	var st := float(a[3]) if a.size() > 3 else 0.0
	var torre: SalaTorre = (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate()
	torre.crea_luci = false
	torre.caduta_mortale = 1000.0
	get_tree().root.add_child(torre)
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(p)
	for i in 5:
		await get_tree().physics_frame
	var tr: Dictionary = torre.dati["tratti"][k]
	var avanti := SalaTorre.b(tr["verso"])
	var lato := Vector3(-avanti.z, 0, avanti.x)
	p.global_position = SalaTorre.b(tr["entrata"]) + lato * sp + Vector3(0, 0.2, 0)
	p.set_look(atan2(-avanti.x, -avanti.z) + deg_to_rad(st), 0.0)
	for i in 10:
		await get_tree().physics_frame
	var decollo := SalaTorre.b(tr["a"])
	var getto := false
	var lancio := 0.0
	Input.action_press(&"move_forward")
	for i in 240:
		await get_tree().physics_frame
		if not getto and p.is_sliding and (tr["salti"] as Array).has("getto") \
				and Vector2(p.global_position.x - decollo.x, p.global_position.z - decollo.z).length() < 3.0:
			getto = true
			p.set_look(p.yaw, deg_to_rad(-80.0))
			Input.action_press(&"spray")
		if p.slide_launched and lancio == 0.0:
			lancio = Vector2(p.velocity.x, p.velocity.z).length()
			print("LANCIO a %.2f m/s (f%d, dentro %.2f m)" % [lancio, i, _dentro_canale(torre, k, p.global_position)])
		# avanti si tiene premuto finché non si scivola davvero (come chi gioca), poi si lascia fare
		if p.is_sliding and Vector2(p.velocity.x, p.velocity.z).length() > 2.5 and Input.is_action_pressed(&"move_forward") \
				and _dentro_canale(torre, k, p.global_position) > 0.5:
			Input.action_release(&"move_forward")
		if i % 8 == 0 or (i > 12 and i < 30):
			var tocca := ""
			for c in p.get_slide_collision_count():
				var cn := p.get_slide_collision(c).get_collider() as Node
				tocca += "%s/%s n(%.1f,%.1f,%.1f) " % [cn.get_parent().name, cn.name, p.get_slide_collision(c).get_normal().x, p.get_slide_collision(c).get_normal().y, p.get_slide_collision(c).get_normal().z]
			var e := (p.global_position - SalaTorre.b(tr["entrata"])).dot(lato)
			print("f%3d pos (%.2f %.2f %.2f) lat %.2f v (%.1f %.1f %.1f) scivola %s aria %s pav %s fw %s %s" % [i, p.global_position.x, p.global_position.y, p.global_position.z, e, p.velocity.x, p.velocity.y, p.velocity.z, p.is_sliding, p.slide_launched, p.is_on_floor(), Input.is_action_pressed(&"move_forward"), tocca])
	Input.action_release(&"spray")
	print("FINE a ", p.global_position)
	get_tree().quit(0)


## Quanti metri si è già dentro il canale del tratto k (negativo prima dell'imbocco), lungo la sua direzione.
func _dentro_canale(torre: SalaTorre, k: int, pos: Vector3) -> float:
	var linea: Array = torre.dati["tratti"][k]["linee"][0]
	var a := SalaTorre.b(linea[0])
	var c := SalaTorre.b(linea[1])
	var t := Vector3(c.x - a.x, 0, c.z - a.z).normalized()
	return Vector3(pos.x - a.x, 0, pos.z - a.z).dot(t)
