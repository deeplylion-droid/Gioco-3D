extends Node
## Prova della discesa della sala della torre con il movimento vero sugli scivoli (Player, di grafica): per
## ogni tratto il giocatore parte dalla pedana del checkpoint, cammina in avanti fino al canale e scivola
## da solo; in aria sui salti col getto punta in basso e spruzza fino all'atterraggio. Stampa velocità,
## salti e com'è finita (arrivato alla pedana dopo, o caduto e dove). Serve a regolare la geometria
## (tools/blender/torre_a.py); il controllo vero è in test_torre.gd.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sim_torre.gd [tratto]

const TORRE := "res://scenes/sala/torre/sala_torre.tscn"

var torre: SalaTorre
var traccia := true
var _cam: Camera3D
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	torre = (load(TORRE) as PackedScene).instantiate()
	torre.crea_luci = DisplayServer.get_name() != "headless"
	torre.caduta_mortale = 1000.0
	get_tree().root.add_child(torre)
	for z in torre.find_children("CadutaFondo*", "KillZone", false, false):
		z.queue_free()
	p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(p)
	if DisplayServer.get_name() != "headless":
		_cam = Camera3D.new()
		get_tree().root.add_child(_cam)
		_cam.fov = 70.0
	await _frames(5)
	if p.water_pack:
		p.water_pack.set_equipped(true, false)
		p.water_pack.set_tank_amount(20.0)
	var solo := -1
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		solo = int(args[1])
	var esiti := []
	for k in range(torre.checkpoint.size() - 1):
		if solo >= 0 and k != solo:
			continue
		esiti.append(await _tratto(k))
	print("")
	for e in esiti:
		print(e)
	get_tree().quit(0)


func _tratto(k: int) -> String:
	var cp := torre.checkpoint[k]
	var dopo := torre.checkpoint[k + 1]
	var salti_tratto := _salti_del_tratto(k)
	var tr_k: Dictionary = torre.dati["tratti"][k]
	var fine_getto: bool = (tr_k["salti"] as Array).size() > 0 and tr_k["salti"][-1] == "getto" and (tr_k["pezzi"] as Array).size() == (tr_k["salti"] as Array).size()
	var decollo := SalaTorre.b(tr_k["a"])
	var tr: Dictionary = torre.dati["tratti"][k]
	var entra := SalaTorre.b(tr["entrata"])
	var avanti := SalaTorre.b(tr["verso"])
	p.global_position = entra + Vector3(0, 0.2, 0)
	p.velocity = Vector3.ZERO
	p.set_look(atan2(-avanti.x, -avanti.z), 0.0)
	if p.water_pack:
		p.water_pack.set_tank_amount(20.0)
	await _frames(10)
	Input.action_press(&"move_forward")
	var lanci := 0
	var v_max := 0.0
	var v_lanci := []
	var in_aria := false
	var getto := false
	var esito := "tempo scaduto"
	var t := 0
	for i in 60 * 40:
		await _frames(1)
		t += 1
		if p.is_sliding and Input.is_action_pressed(&"move_forward"):
			Input.action_release(&"move_forward")
		var v := p.velocity.length()
		v_max = maxf(v_max, v)
		# tratti che finiscono col getto: si tiene premuto lo spruzzo verso il basso negli ultimi metri (la
		# carica di 0,35 s si fa scivolando, così in aria la spinta parte subito)
		if fine_getto and not getto and p.is_sliding and Vector2(p.global_position.x - decollo.x, p.global_position.z - decollo.z).length() < 3.0:
			getto = true
			p.set_look(p.yaw, deg_to_rad(-80.0))
			Input.action_press(&"spray")
		if p.slide_launched and not in_aria and Vector3(p.velocity.x, 0, p.velocity.z).length() > 1.5:
			in_aria = true
			lanci += 1
			v_lanci.append(snappedf(Vector3(p.velocity.x, 0, p.velocity.z).length(), 0.1))
			var tipo: String = salti_tratto[lanci - 1] if lanci - 1 < salti_tratto.size() else "?"
			if tipo == "getto" and not getto:
				getto = true
				p.set_look(p.yaw, deg_to_rad(-80.0))
				Input.action_press(&"spray")
		elif in_aria and (p.is_sliding or p.is_on_floor()):
			in_aria = false
			if getto:
				Input.action_release(&"spray")
				p.set_look(p.yaw, 0.0)
				getto = false
		var pos := p.global_position
		if _cam:
			var dietro := -Vector3(p.velocity.x, 0, p.velocity.z).normalized() if Vector3(p.velocity.x, 0, p.velocity.z).length() > 0.5 else Vector3(0, 0, 1)
			_cam.global_position = p.global_position + dietro * 4.0 + Vector3(0, 3.0, 0)
			_cam.look_at(p.global_position + Vector3(0, 0.8, 0))
			_cam.current = true
		if t % 20 == 0 and t <= 240 and DisplayServer.get_name() != "headless":
			var img := get_viewport().get_texture().get_image()
			img.save_jpg("/tmp/claude-0/sp/sim_%d_%03d.jpg" % [k, t], 0.8)
		if (t % 15 == 0 or (t > 100 and t < 140 and t % 3 == 0)) and traccia:
			var sotto := ""
			for c in p.get_slide_collision_count():
				var cn := p.get_slide_collision(c).get_collider() as Node
				sotto += String(cn.get_parent().name) + "/" + String(cn.name) + " "
			print("    t %.2f pos %s v %s scivola %s in_aria %s pav %s n %s tocca %s" % [t / 60.0, _v(pos), _v(p.velocity), p.is_sliding, p.slide_launched, p.is_on_floor(), _v(p.slide_normal), sotto])
		if pos.y < dopo.global_position.y - 3.0:
			esito = "CADUTO a %s dopo %d salti" % [_v(pos), lanci]
			break
		if pos.distance_to(dopo.global_position) < 2.2 and not p.is_sliding:
			esito = "arrivato"
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"spray")
	return "tratto %d (%s -> %s): %s; salti previsti %s, lanci %d a %s m/s; velocità massima %.1f m/s; %.1f s" % [
		k, cp.name, dopo.name, esito, salti_tratto, lanci, v_lanci, v_max, t / 60.0]


func _salti_del_tratto(k: int) -> Array:
	return torre.dati["tratti"][k]["salti"]


func _v(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
