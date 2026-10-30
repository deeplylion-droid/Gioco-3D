extends Node
## Ricontrollo delle scalette della piscina a onde (ambienti-1, 30 ottobre, per lavoro/scalette-piscina): quello che
## test_scalette_piscina.gd non prova. A piscina piena e vuota, per ogni scaletta:
## - la discesa dal bordo con la scala (Ladder.get_climb_normal() punta dentro la piscina): girati verso la piscina con
##   avanti e di spalle alla piscina con indietro, anche con lo stick a metà; ci si deve aggrappare e arrivare in basso;
##   poi, dal fondo, avanti verso la scala: ci si riaggrappa e si esce di nuovo sul bordo;
## - i corrimano sul bordo: camminandoci contro (dritto e di sbieco) non si attraversano all'altezza del bordo (sotto,
##   aggrappati alla scala, si può scendere);
## - dopo la cima: salendo con avanti, da 0,5 s dopo lo scavalco (finito lo slancio) a 7 s fermi la posizione non cambia
##   più di 2 cm (prima, a 6 s, l'eccezione dei corrimano scadeva dentro di loro e il giocatore schizzava indietro di 81 cm);
##   poi si cammina via.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/ricontrollo_scalette.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var level: Node
var p: Player
var vasca: WaterTank
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(1200.0, true, false, true).timeout.connect(func():
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
	for stato in ["piena", "vuota"]:
		if stato == "vuota":
			vasca.fill = 0.0
		await _frames(30)
		print("piscina %s (fill %.2f)" % [stato, vasca.fill])
		for s in scalette:
			for modo in ([] if OS.get_environment("SOLO_USCITA") == "1" else ["verso la piscina, avanti", "verso la piscina, avanti a metà",
					"di spalle alla piscina, indietro", "di spalle alla piscina, indietro a metà"]):
				var r: Dictionary = await _scendi(s, modo)
				check(r["giu"] and r["presa"], "piscina %s, %s, discesa %s: ci si aggrappa e si arriva in basso (in %.1f s, il più in basso %.2f, cima %.2f, presa %s, fine %s)" % [
						stato, s.name, modo, r["tempo"], r["basso"], s.get_top_y(), r["presa"], r["fine"]])
				if r["giu"]:
					check(r["a_terra"], "piscina %s, %s, discesa %s: in fondo si lascia la scala e si sta sul fondo (fine %s)" % [stato, s.name, modo, r["fine"]])
					var su: Dictionary = await _risali(s)
					check(su["fuori"] and su["prese"] >= 1, "piscina %s, %s, dopo la discesa %s: dal fondo, staccati dalla scala, ci si riaggrappa e si esce sul bordo (in %.1f s, prese %d, fine %s)" % [
							stato, s.name, modo, su["tempo"], su["prese"], su["fine"]])
			for modo in ([] if OS.get_environment("SOLO_USCITA") == "1" else ["dritto", "di sbieco"]):
				var c: Dictionary = await _corrimano(s, modo)
				check(c["fermo"], "piscina %s, %s: camminando contro i corrimano dal bordo (%s) non si passano (più avanti %.2f m oltre il muro, fine %s)" % [
						stato, s.name, modo, c["oltre"], c["fine"]])
			var u: Dictionary = await _uscita(s)
			check(u["ok"], "piscina %s, %s: dopo la cima non si resta nella scala e si cammina via (%s)" % [stato, s.name, u["dettaglio"]])
	_fine()


func _fondo(q: Vector3, alto := 1.0) -> Vector3:
	var da := Vector3(q.x, alto, q.z)
	var c := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 6.0, Layers.WORLD))
	return c.position if not c.is_empty() else Vector3(q.x, alto - 2.95, q.z)


## Sul bordo, 0,6 m dietro la cima della scaletta (fuori dalla piscina).
func _sul_bordo(s: Ladder, dietro := 0.6) -> void:
	var n := s.get_climb_normal()
	var q := s.global_position - n * dietro
	p.teleport(_fondo(q, s.get_top_y() + 1.0) + Vector3.UP * 0.05)
	await _frames(20)


func _scendi(s: Ladder, modo: String) -> Dictionary:
	_rilascia()
	var n := s.get_climb_normal()
	# (1 m dietro: la scatola dei corrimano va 70 cm sul bordo, e il giocatore deve partire fuori)
	await _sul_bordo(s, 1.0)
	var verso_piscina := modo.begins_with("verso la piscina")
	# (verso la piscina si guarda lungo la normale della scala, che punta dentro la piscina; di spalle, al contrario)
	var dir := n if verso_piscina else -n
	p.look_at_point(p.global_position + Vector3.UP * 1.5 + dir * 5.0)
	p.pitch = deg_to_rad(-20.0) if verso_piscina else 0.0
	var forza := 0.5 if modo.ends_with("a metà") else 1.0
	Input.action_press(&"move_back" if modo.contains("indietro") else &"move_forward", forza)
	var t := 0.0
	var basso := INF
	var presa := false
	var giu := false
	for f in 60 * 10:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		presa = presa or p.is_on_ladder()
		basso = minf(basso, p.global_position.y)
		if p.global_position.y < s.get_top_y() - 1.2:
			giu = true
			break
	# arrivati in basso, si tiene premuto fino al fondo: lì si lascia la scala (sott'acqua o sul fondo asciutto)
	var a_terra := false
	if giu:
		for f in 60 * 6:
			await get_tree().physics_frame
			if not p.is_on_ladder() and p.is_on_floor():
				a_terra = true
				break
	var fine := "%s%s" % [p.global_position.snapped(Vector3.ONE * 0.01), " sulla scala" if p.is_on_ladder() else ""]
	_rilascia()
	return {"giu": giu, "a_terra": a_terra, "tempo": t, "basso": basso, "presa": presa, "fine": fine}


## Dopo una discesa: si lascia tutto, fermi 1 s, poi avanti verso la scala (girati verso il muro) fino a 12 s; si deve
## uscire sul bordo, oltre il muro.
func _risali(s: Ladder) -> Dictionary:
	_rilascia()
	var n := s.get_climb_normal()
	await _frames(60)
	p.look_at_point(Vector3(s.global_position.x, p.global_position.y + 1.5, s.global_position.z) - n * 2.0)
	p.pitch = 0.0
	Input.action_press(&"move_forward")
	var t := 0.0
	var prese := 0
	var era := p.is_on_ladder()
	var fuori := false
	for f in 60 * 12:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if p.is_on_ladder() and not era:
			prese += 1
		era = p.is_on_ladder()
		var oltre := (p.global_position - s.global_position).dot(-n)
		if p.is_on_floor() and p.global_position.y > s.get_top_y() - 0.4 and oltre > 0.3 and not p.is_on_ladder():
			fuori = true
			break
	var fine := "%s%s" % [p.global_position.snapped(Vector3.ONE * 0.01), " sulla scala" if p.is_on_ladder() else ""]
	_rilascia()
	return {"fuori": fuori, "tempo": t, "prese": prese, "fine": fine}


## Dal bordo, 1 m dietro (fuori dalla scatola dei corrimano), contro i corrimano verso la piscina (dritto, o di sbieco
## da 50 cm di lato mirando al centro della scala), 3 s: il giocatore non deve
## finire oltre il muro della piscina senza essere sulla scala (cioè passare attraverso i corrimano).
func _corrimano(s: Ladder, modo: String) -> Dictionary:
	_rilascia()
	var n := s.get_climb_normal()
	await _sul_bordo(s, 1.0)
	if modo != "dritto":
		var lato := n.cross(Vector3.UP).normalized()
		p.teleport(p.global_position + lato * 0.5)
		await _frames(10)
	var mira := Vector3(s.global_position.x, p.global_position.y + 1.5, s.global_position.z)
	p.look_at_point(mira)
	p.pitch = 0.0
	Input.action_press(&"move_forward")
	var oltre := -INF
	var passato := false
	for f in 60 * 3:
		await get_tree().physics_frame
		var o := (p.global_position - s.global_position).dot(n)
		oltre = maxf(oltre, o)
		# oltre la scala, verso la piscina, all'altezza del bordo e senza esserci aggrappati: è passato fra i corrimano
		# (più in basso, sulla scala o sul fondo dopo la discesa, va bene)
		if o > 0.45 and not p.is_on_ladder() and p.global_position.y > s.get_top_y() - 0.5:
			passato = true
	var fine := "%s%s" % [p.global_position.snapped(Vector3.ONE * 0.01), " sulla scala" if p.is_on_ladder() else ""]
	_rilascia()
	return {"fermo": not passato, "oltre": oltre, "fine": fine}


## Dal fondo, avanti fino allo scavalco; poi fermi fino a 7 s: da 0,5 s in poi non ci si sposta più di 2 cm; poi 1,5 s
## avanti: ci si allontana di almeno 1 m.
func _uscita(s: Ladder) -> Dictionary:
	_rilascia()
	var n := s.get_climb_normal()
	var base := s.global_position + n * 1.0
	p.teleport(_fondo(base, s.global_position.y + 1.0) + Vector3.UP * 0.05)
	await _frames(20)
	p.look_at_point(Vector3(s.global_position.x, p.global_position.y + 1.5, s.global_position.z))
	p.pitch = 0.0
	Input.action_press(&"move_forward")
	var sopra := false
	for f in 60 * 12:
		await get_tree().physics_frame
		if p.is_on_floor() and p.global_position.y > s.get_top_y() - 0.4 and not p.is_on_ladder():
			sopra = true
			break
	_rilascia()
	if not sopra:
		return {"ok": false, "dettaglio": "non si è usciti (fine %s)" % p.global_position.snapped(Vector3.ONE * 0.01)}
	# da 0,5 s (finito lo slancio dello scavalco) a 7 s: lo spostamento più grande dalla posizione a 0,5 s
	await _frames(30)
	var uscito := p.global_position
	var salto := 0.0
	for f in 60 * 7 - 30:
		await get_tree().physics_frame
		salto = maxf(salto, Vector2(p.global_position.x - uscito.x, p.global_position.z - uscito.z).length())
	var dopo7 := p.global_position
	# dentro i corpi della scala (i corrimano)? con la forma del giocatore, senza margine
	var corpi: Array = s.corpi_da_attraversare() if s.has_method(&"corpi_da_attraversare") else []
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = p.collision_shape.shape
	q.transform = p.collision_shape.global_transform
	q.collision_mask = p.collision_mask
	var dentro := false
	for r in p.get_world_3d().direct_space_state.intersect_shape(q, 16):
		if corpi.has(r.collider):
			dentro = true
	var eccezioni := p.get_collision_exceptions().size()
	var da := p.global_position
	p.look_at_point(p.global_position + Vector3.UP * 1.5 - n * 5.0)
	Input.action_press(&"move_forward")
	await _frames(90)
	_rilascia()
	var via := Vector2(p.global_position.x - da.x, p.global_position.z - da.z).length()
	return {"ok": salto <= 0.02 and via > 1.0 and not p.is_on_ladder(),
			"dettaglio": "spinta da fermi (0,5-7 s) %.3f m, a 0,5 s %s, a 7 s %s, tocca ancora la scala %s, eccezioni %d, poi via di %.2f m, fine %s" % [salto, uscito.snapped(Vector3.ONE * 0.01), dopo7.snapped(Vector3.ONE * 0.01), dentro, eccezioni, via, p.global_position.snapped(Vector3.ONE * 0.01)]}
