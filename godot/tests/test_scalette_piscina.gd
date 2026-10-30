extends Node
## Test delle scalette della piscina a onde (Piscina/ScalettaEst e ScalettaOvest, scene/props/ladder.tscn) col
## giocatore vero nella sala principale (riscontro della 0.3.16: col controller in cima alla scaletta est non si
## scavalcava e si tornava giù). A piscina vuota e piena, per ogni scaletta, dal fondo davanti alla scaletta con
## avanti tenuto premuto, fino a 12 s:
## - guardando dritto, guardando in alto, guardando la scaletta un po' in basso (-15 gradi), con la corsa, con lo
##   stick a metà (come un controller), accovacciati (col tasto tenuto, che in cima si lascia) e spostati di lato;
## si deve uscire sul bordo, fuori dalla piscina. E dalla spiaggia (a nord): camminando avanti dal fondo si esce.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_scalette_piscina.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var level: Node
var p: Player
var vasca: WaterTank
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(1500.0, true, false, true).timeout.connect(func():
		printerr("  FALLITO tempo scaduto")
		_failed += 1
		_fine())


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _rilascia() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"sprint", &"crouch"]:
		Input.action_release(a)


func _fine() -> void:
	_rilascia()
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene != null \
				and get_tree().current_scene != self:
			break
	await _frames(5)
	level = get_tree().current_scene
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	vasca = level.get_node(^"Piscina/Pozza") as WaterTank
	var scalette: Array[Ladder] = [level.get_node(^"Piscina/ScalettaEst") as Ladder, level.get_node(^"Piscina/ScalettaOvest") as Ladder]
	var modi := ["dritto", "in alto", "in basso", "corsa", "stick a metà", "accovacciato", "di lato"]
	for stato in ["vuota", "piena"]:
		vasca.fill = 0.0 if stato == "vuota" else vasca.max_fill
		await _frames(30)
		print("piscina %s (fill %.2f)" % [stato, vasca.fill])
		for s in scalette:
			for modo in modi:
				var r: Dictionary = await _sali(s, modo)
				check(r["fuori"], "piscina %s, %s, %s: si esce sul bordo (in %.1f s; il più in alto %.2f, %d prese della scala, fine %s)" % [
						stato, s.name, modo, r["tempo"], r["alto"], r["prese"], r["fine"]])
		var sp: Dictionary = await _spiaggia()
		check(sp["fuori"], "piscina %s: dalla spiaggia si esce camminando (in %.1f s, fine %s)" % [stato, sp["tempo"], sp["fine"]])
	_fine()


## Il giocatore sul fondo 1,2 m davanti alla scaletta [param s], girato verso di lei, poi avanti tenuto premuto.
func _sali(s: Ladder, modo: String) -> Dictionary:
	_rilascia()
	var n := s.get_climb_normal()
	var lato := n.cross(Vector3.UP).normalized()
	var base := s.global_position + n * 1.2 + (lato * 0.3 if modo == "di lato" else Vector3.ZERO)
	var fondo := _fondo(base)
	p.teleport(fondo + Vector3.UP * 0.05)
	await _frames(20)
	var guarda := Vector3(s.global_position.x, p.global_position.y + 1.5, s.global_position.z)
	p.look_at_point(guarda)
	match modo:
		"in alto":
			p.pitch = deg_to_rad(35.0)
		"in basso":
			p.pitch = deg_to_rad(-15.0)
		_:
			p.pitch = 0.0
	if modo == "corsa":
		Input.action_press(&"sprint")
	if modo == "accovacciato":
		Input.action_press(&"crouch")
	Input.action_press(&"move_forward", 0.5 if modo == "stick a metà" else 1.0)
	var prese := 0
	var era := false
	var alto := -INF
	var t := 0.0
	var fuori := false
	for f in 60 * 12:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if p.is_on_ladder() and not era:
			prese += 1
		era = p.is_on_ladder()
		alto = maxf(alto, p.global_position.y)
		if OS.has_environment("DIAG") and p.global_position.y > -0.4:
			for k in p.get_slide_collision_count():
				var c := p.get_slide_collision(k)
				var o := c.get_collider() as Node
				print("    DIAG y %.2f urta %s a %s (normale %s)" % [p.global_position.y, o.get_path() if o else "?", c.get_position().snapped(Vector3.ONE * 0.01), c.get_normal().snapped(Vector3.ONE * 0.01)])
		# (accovacciati sulla scala non ci si aggrappa: arrivati al piede si lascia il tasto, come farebbe chi gioca)
		if modo == "accovacciato" and t > 1.5:
			Input.action_release(&"crouch")
		var oltre := (p.global_position - s.global_position).dot(-n)
		if p.is_on_floor() and p.global_position.y > s.get_top_y() - 0.1 and oltre > 0.3:
			fuori = true
			break
	var fine := "%s%s" % [p.global_position.snapped(Vector3.ONE * 0.01), " sulla scala" if p.is_on_ladder() else ""]
	_rilascia()
	return {"fuori": fuori, "tempo": t, "alto": alto, "prese": prese, "fine": fine}


## Dal fondo della parte profonda verso nord (la spiaggia), avanti tenuto premuto.
func _spiaggia() -> Dictionary:
	_rilascia()
	p.teleport(_fondo(Vector3(0.0, 0.0, 3.0)) + Vector3.UP * 0.05)
	await _frames(20)
	p.look_at_point(p.global_position + Vector3(0.0, 1.5, -10.0))
	p.pitch = 0.0
	Input.action_press(&"move_forward")
	var t := 0.0
	var fuori := false
	for f in 60 * 20:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if p.is_on_floor() and p.global_position.y > -0.05:
			fuori = true
			break
	var fine := str(p.global_position.snapped(Vector3.ONE * 0.01))
	_rilascia()
	return {"fuori": fuori, "tempo": t, "fine": fine}


## Il fondo sotto [param q] (il primo pavimento dall'alto, da 1 m sopra il bordo).
func _fondo(q: Vector3) -> Vector3:
	var da := Vector3(q.x, 1.0, q.z)
	var c := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 6.0, Layers.WORLD))
	return c.position if not c.is_empty() else Vector3(q.x, -1.95, q.z)
