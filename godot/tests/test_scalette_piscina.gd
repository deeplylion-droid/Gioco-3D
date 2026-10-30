extends Node
## Test delle scalette della piscina a onde (Piscina/ScalettaEst e ScalettaOvest, scene/props/ladder.tscn) col
## giocatore vero nella sala principale (riscontro della 0.3.16: col controller in cima alla scaletta est non si
## scavalcava e si tornava giù). A piscina vuota e piena, per ogni scaletta, dal fondo davanti alla scaletta con
## avanti tenuto premuto, fino a 12 s:
## - guardando dritto, guardando in alto, guardando la scaletta un po' in basso (-15 gradi), con la corsa, con lo
##   stick a metà (come un controller), accovacciati (col tasto tenuto, che in cima si lascia) e spostati di lato;
## si deve uscire sul bordo, fuori dalla piscina. E dalla spiaggia (a nord): camminando avanti dal fondo si esce. E dal bordo
## si scende con la scaletta (col tasto e con lo stick a metà), e chi esce in cima e resta fermo fra i corrimano non viene
## spinto via (ricontrollo di ambienti-1 della 0.3.17).
## Poi, negli stessi sette modi, tutte le altre scale che il giocatore usa (ricontrollo chiesto dal coordinatore): nei
## tecnici la scala del pozzo (col portello aperto, fino sul fondo della piscina vuota) e la scaletta della vasca; nella
## torre le scale delle vasche di raccolta e nelle condotte quelle degli scoli e del bacino. E chi passa accanto a una
## scala senza andarle contro non ci si aggrappa (sul bordo della piscina e sul fondo, con lo stick pieno, a metà e a
## un terzo, dritto lungo il bordo e un po' di sbieco).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_scalette_piscina.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
const MODI := ["dritto", "in alto", "in basso", "corsa", "stick a metà", "accovacciato", "di lato"]

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
	var modi := MODI
	# (prima piena, com'è all'inizio: svuotata, la piscina non tiene più l'acqua)
	for stato in ([] if OS.get_environment("SOLO") == "tecnici" else (["piena"] if OS.get_environment("SOLO") == "discesa" else ["piena", "vuota"])):
		if stato == "vuota":
			vasca.fill = 0.0
		await _frames(30)
		print("piscina %s (fill %.2f)" % [stato, vasca.fill])
		check(vasca.fill > 0.5 if stato == "piena" else vasca.fill < 0.01, "la piscina è %s (fill %.2f)" % [stato, vasca.fill])
		for s in ([] if OS.get_environment("SOLO") == "discesa" else scalette):
			for modo in modi:
				var r: Dictionary = await _sali(s, modo)
				check(r["fuori"], "piscina %s, %s, %s: si esce sul bordo (in %.1f s; il più in alto %.2f, %d prese della scala, fine %s)" % [
						stato, s.name, modo, r["tempo"], r["alto"], r["prese"], r["fine"]])
		var sp: Dictionary = await _spiaggia()
		check(sp["fuori"], "piscina %s: dalla spiaggia si esce camminando (in %.1f s, fine %s)" % [stato, sp["tempo"], sp["fine"]])
		# dal bordo si scende con la scala (ricontrollo di ambienti-1 della 0.3.17), col tasto e con lo stick a metà; e chi
		# esce in cima e resta fermo fra i corrimano non viene spinto via dopo qualche secondo
		for s in scalette:
			for forza in [1.0, 0.5]:
				var g: Dictionary = await _scendi(s, forza)
				check(g["giu"], "piscina %s, %s, dal bordo con avanti a %.1f: si scende con la scala fino in fondo (in %.1f s, %d prese, il più basso %.2f, fine %s)" % [
						stato, s.name, forza, g["tempo"], g["prese"], g["basso"], g["fine"]])
			var f: Dictionary = await _fermo_in_cima(s)
			check(f["salto"] < 0.08, "piscina %s, %s: fuori dalla scala e fermo 8 s fra i corrimano non si viene spinti (spostamento più grande in un fotogramma %.3f m, fermo a %s)" % [
					stato, s.name, f["salto"], f["dove"]])
		if stato == "vuota":
			await _accanto(scalette[0])
	# i tecnici (sotto la piscina, vuota): la scala del pozzo col portello aperto, e la scaletta della vasca di raccolta
	var portello := level.get_node_or_null(^"Piscina/Portello")
	if portello and portello.has_method(&"open"):
		portello.call(&"open")
	await _frames(120)
	for nome in [^"Tecnici/Gioco/ScalaPozzo", ^"Tecnici/Gioco/ScalettaVasca"]:
		var l := level.get_node_or_null(nome) as Ladder
		check(l != null, "c'è %s" % nome)
		if l:
			await _tutti_i_modi(l, "tecnici")
	if OS.get_environment("SOLO") in ["tecnici", "discesa"]:
		_fine()
		return
	# la torre con le condotte: le scale delle vasche di raccolta, degli scoli e del bacino
	get_tree().change_scene_to_file(TORRE)
	for i in 600:
		await get_tree().process_frame
		if get_tree().current_scene is SalaTorre:
			break
	await _frames(30)
	level = get_tree().current_scene
	var torre := level as SalaTorre
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
		level.add_child(p)
		await _frames(10)
	var ins := torre.inseguimento as SalaInseguimento
	if ins:
		# (senza lei: nelle vasche di scolo ti prende)
		ins.set_physics_process(false)
		if ins.lei:
			ins.lei.visible = false
	var scale := level.find_children("*", "Ladder", true, false)
	check(scale.size() >= 4, "nella torre e nelle condotte ci sono le scale (%d)" % scale.size())
	for l in scale:
		# (la scaletta del bacino si sale dopo SB1, che parte quando ci si avvicina e ferma i comandi: la prova
		# test_scaletta_bacino.gd, dopo SB1 vero)
		if ins and ins.is_ancestor_of(l) and (l as Ladder).get_top_y() > float(ins.dati["bacino"]["fondo"]) + 3.0 \
				and (l as Ladder).global_position.y < float(ins.dati["bacino"]["fondo"]) + 0.5:
			print("  (%s, la scaletta del bacino: in test_scaletta_bacino.gd)" % l.name)
			continue
		await _tutti_i_modi(l as Ladder, "torre" if not (ins and ins.is_ancestor_of(l)) else "condotte")
	_fine()


func _tutti_i_modi(l: Ladder, zona: String) -> void:
	for modo in MODI:
		var r: Dictionary = await _sali(l, modo)
		check(r["fuori"], "%s, %s, %s: si sale e si scavalca in cima (in %.1f s; il più in alto %.2f di %.2f, %d prese della scala, fine %s)" % [
				zona, l.name, modo, r["tempo"], r["alto"], l.get_top_y(), r["prese"], r["fine"]])


## Dal bordo, 1,6 m dietro la scaletta [param s] e girati verso la piscina, avanti tenuto premuto (a [param forza]): ci
## si aggrappa, si passano i corrimano e si scende fino al fondo.
func _scendi(s: Ladder, forza: float) -> Dictionary:
	_rilascia()
	var n := s.get_climb_normal()
	var da := _fondo(s.global_position - n * 1.6, s.get_top_y() + 1.0) + Vector3.UP * 0.05
	p.teleport(da)
	await _frames(20)
	p.look_at_point(p.global_position + Vector3.UP * 1.5 + n * 5.0)
	p.pitch = deg_to_rad(-30.0)
	Input.action_press(&"move_forward", forza)
	var prese := 0
	var era := false
	var basso := INF
	var t := 0.0
	var giu := false
	for fr in 60 * 12:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if p.is_on_ladder() and not era:
			prese += 1
		era = p.is_on_ladder()
		basso = minf(basso, p.global_position.y)
		if p.is_on_floor() and not p.is_on_ladder() and p.global_position.y < s.global_position.y + 0.3 and prese > 0:
			giu = true
			break
	var fine := str(p.global_position.snapped(Vector3.ONE * 0.01))
	_rilascia()
	return {"giu": giu, "tempo": t, "prese": prese, "basso": basso, "fine": fine}


## Su per la scaletta [param s] fino a scavalcare la cima, poi fermi appena fuori (fra i corrimano) per 8 s: lo
## spostamento più grande in un fotogramma (il motore che spinge fuori dalla scatola dei corrimano).
func _fermo_in_cima(s: Ladder) -> Dictionary:
	_rilascia()
	var n := s.get_climb_normal()
	p.teleport(_fondo(s.global_position + n * 1.0, s.global_position.y + 1.0) + Vector3.UP * 0.05)
	await _frames(20)
	p.look_at_point(Vector3(s.global_position.x, p.global_position.y + 1.5, s.global_position.z))
	p.pitch = 0.0
	Input.action_press(&"move_forward")
	var su := false
	for fr in 60 * 8:
		await get_tree().physics_frame
		if OS.has_environment("DIAG") and fr % 20 == 0:
			print("    DIAG fermo %s scala %s pavimento %s v %s" % [p.global_position.snapped(Vector3.ONE * 0.01), p.is_on_ladder(), p.is_on_floor(), p.velocity.snapped(Vector3.ONE * 0.01)])
		# appena scavalcato e posato sul bordo, dentro la scatola dei corrimano: si lascia tutto
		if not p.is_on_ladder() and p.is_on_floor() and p.global_position.y > s.get_top_y() - 0.15:
			su = true
			break
	_rilascia()
	var salto := 0.0
	var prima := p.global_position
	for fr in 60 * 8:
		await get_tree().physics_frame
		salto = maxf(salto, Vector2(p.global_position.x - prima.x, p.global_position.z - prima.z).length())
		prima = p.global_position
	return {"salto": salto if su else 99.0, "dove": str(p.global_position.snapped(Vector3.ONE * 0.01)) + ("" if su else " (non è arrivato in cima)")}


## Chi passa accanto alla scaletta [param s] senza andarle contro non ci si aggrappa: sul bordo lungo la piscina, davanti
## alla cima, e sul fondo davanti al piede, dritto lungo il bordo e di sbieco (20 gradi verso la scala), con lo stick
## pieno, a metà e a un terzo.
func _accanto(s: Ladder) -> void:
	var n := s.get_climb_normal()
	var lato := n.cross(Vector3.UP).normalized()
	for dove in ["bordo", "fondo"]:
		for forza in [1.0, 0.5, 0.33]:
			for sbieco in [0.0, 20.0]:
				_rilascia()
				# sul bordo: 0,4 m dietro il muro (fuori dalla piscina); sul fondo: 0,6 m davanti alla scala
				var da := s.global_position + lato * 2.5 + (-n * 0.4 if dove == "bordo" else n * 0.6)
				da = _fondo(da, s.get_top_y() + 1.0) + Vector3.UP * 0.05 if dove == "bordo" else _fondo(da, s.global_position.y + 1.0) + Vector3.UP * 0.05
				p.teleport(da)
				await _frames(15)
				var dir := (-lato).rotated(Vector3.UP, deg_to_rad(sbieco) * (1.0 if (-lato).cross(-n).y > 0.0 else -1.0))
				p.look_at_point(p.global_position + Vector3.UP * 1.5 + dir * 5.0)
				p.pitch = 0.0
				Input.action_press(&"move_forward", forza)
				var presa := false
				for f in 60 * 3:
					await get_tree().physics_frame
					if p.is_on_ladder():
						presa = true
						break
				_rilascia()
				check(not presa, "passando accanto a %s (%s, stick %.2f, %s): non ci si aggrappa" % [s.name, dove, forza, "dritto" if sbieco == 0.0 else "di sbieco"])


## Il giocatore sul fondo 1,2 m davanti alla scaletta [param s], girato verso di lei, poi avanti tenuto premuto.
func _sali(s: Ladder, modo: String) -> Dictionary:
	_rilascia()
	var n := s.get_climb_normal()
	var lato := n.cross(Vector3.UP).normalized()
	# (1,2 m davanti, o meno se prima c'è un muro: il pozzo dei tecnici è stretto)
	var dist := 1.2
	var da_ := s.global_position + Vector3.UP * 0.9
	var muro := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(da_, da_ + n * 1.6, Layers.WORLD))
	if not muro.is_empty():
		dist = clampf(da_.distance_to(muro.position) - 0.45, 0.45, 1.2)
	var base := s.global_position + n * dist + (lato * 0.3 if modo == "di lato" else Vector3.ZERO)
	var fondo := _fondo(base, s.global_position.y + 1.0)
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
		if OS.has_environment("DIAG") and p.global_position.y > s.get_top_y() - 0.4:
			for k in p.get_slide_collision_count():
				var c := p.get_slide_collision(k)
				var o := c.get_collider() as Node
				print("    DIAG y %.2f urta %s a %s (normale %s)" % [p.global_position.y, o.get_path() if o else "?", c.get_position().snapped(Vector3.ONE * 0.01), c.get_normal().snapped(Vector3.ONE * 0.01)])
		# (accovacciati sulla scala non ci si aggrappa: arrivati al piede si lascia il tasto, come farebbe chi gioca)
		if modo == "accovacciato" and t > 1.5:
			Input.action_release(&"crouch")
		var oltre := (p.global_position - s.global_position).dot(-n)
		if p.is_on_floor() and p.global_position.y > s.get_top_y() - 0.4 and oltre > 0.3 and not p.is_on_ladder():
			fuori = true
			break
	var fine := "%s%s" % [p.global_position.snapped(Vector3.ONE * 0.01), " sulla scala" if p.is_on_ladder() else ""]
	_rilascia()
	return {"fuori": fuori, "tempo": t, "alto": alto, "prese": prese, "fine": fine}


## Dal fondo della parte profonda verso nord (la spiaggia), avanti tenuto premuto.
func _spiaggia() -> Dictionary:
	_rilascia()
	# (di lato, a est: al centro sul fondo ci sono i giocattoli dell'enigma, che fermano chi ci cammina contro dritto)
	p.teleport(_fondo(Vector3(4.5, 0.0, 3.0)) + Vector3.UP * 0.05)
	await _frames(20)
	p.look_at_point(p.global_position + Vector3(0.0, 1.5, -10.0))
	p.pitch = 0.0
	Input.action_press(&"move_forward")
	var t := 0.0
	var fuori := false
	var fermo := 0.0
	var gira := 0.0
	for f in 60 * 20:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if p.is_on_floor() and p.global_position.y > -0.05:
			fuori = true
			break
		# fermo contro un giocattolo dell'enigma (sul fondo, o a galla davanti): gli si gira attorno, a destra
		fermo = fermo + 1.0 / 60.0 if Vector2(p.velocity.x, p.velocity.z).length() < 0.3 else 0.0
		if fermo > 0.4 and gira <= 0.0:
			gira = 0.7
		if gira > 0.0:
			gira -= 1.0 / 60.0
			Input.action_press(&"move_right")
			if gira <= 0.0:
				Input.action_release(&"move_right")
		if OS.has_environment("DIAG") and f % 30 == 0:
			var urti := []
			for k in p.get_slide_collision_count():
				var c := p.get_slide_collision(k)
				urti.append("%s n%s" % [(c.get_collider() as Node).name if c.get_collider() is Node else "?", c.get_normal().snapped(Vector3.ONE * 0.01)])
			print("    DIAG spiaggia %s v %s pavimento %s urti %s" % [p.global_position.snapped(Vector3.ONE * 0.01), p.velocity.snapped(Vector3.ONE * 0.01), p.is_on_floor(), urti])
	var fine := str(p.global_position.snapped(Vector3.ONE * 0.01))
	_rilascia()
	return {"fuori": fuori, "tempo": t, "fine": fine}


## Il fondo sotto [param q] (il primo pavimento dall'alto, da [param alto], di serie 1 m sopra il bordo della piscina).
func _fondo(q: Vector3, alto := 1.0) -> Vector3:
	var da := Vector3(q.x, alto, q.z)
	var c := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 6.0, Layers.WORLD))
	return c.position if not c.is_empty() else Vector3(q.x, alto - 2.95, q.z)
