extends Node
## Collaudo delle scalette della piscina a onde (Piscina/ScalettaEst e ScalettaOvest) dagli occhi del giocatore vero, col
## renderer vero: per la piscina piena e vuota e per ogni scaletta, dal bordo si va verso la scaletta e si scende (avanti
## tenuto premuto, girati verso la piscina), poi dal fondo (o dall'acqua) si risale fino al bordo. Uno scatto ogni
## [constant OGNI] fotogrammi; stampa quanto si scende, se ci si aggrappa, quanto ci vuole e dove si finisce.
## La sala a parti come scatti_piscina_vuota.gd (intera non ci sta nella memoria del renderer software).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 30 --script res://tests/run.gd -- res://tests/collaudo/scalette_giro.gd <cartella>

const SALA := "res://scenes/sala_principale.tscn"
const PARTI := ["Sala", "LuciSala", "Piscina", "Atmosfera"]
const OGNI := 10
var raggio := 30.0
var _cartella := ""
var _radice: Node3D
var _accese := {}
var p: Player
var _k := 0


func _ready() -> void:
	_cartella = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(_cartella)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(_cartella.path_join("%03d_%s.jpg" % [_k, nome]), 0.88)
	_k += 1


func _rilascia() -> void:
	for a in [&"move_forward", &"crouch", &"sprint", &"jump"]:
		Input.action_release(a)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("medio")
	_radice = Node3D.new()
	_radice.name = "SalaPerScalette"
	get_tree().node_added.connect(_aggiunto)
	var tutta := (load(SALA) as PackedScene).instantiate()
	for percorso in PARTI:
		var n := tutta.get_node_or_null(NodePath(percorso)) as Node3D
		if n == null:
			continue
		var tr := _globale(n, tutta)
		n.get_parent().remove_child(n)
		n.transform = tr
		_radice.add_child(n)
	tutta.free()
	var look: LookSala = null
	for c in _radice.find_children("*", "LookSala", true, false):
		look = c
	var we := WorldEnvironment.new()
	we.environment = look.ambiente if look else (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment)
	we.camera_attributes = look.attributi_camera if look else null
	_radice.add_child(we)
	p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	_radice.add_child(p)
	get_tree().root.add_child(_radice)
	get_tree().current_scene = _radice
	GameState.player = p
	await _frames(30)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var pozza := _radice.get_node_or_null(^"Piscina/Pozza") as WaterTank
	var scalette: Array[Ladder] = [_radice.get_node(^"Piscina/ScalettaEst") as Ladder, _radice.get_node(^"Piscina/ScalettaOvest") as Ladder]
	for stato in ["piena", "vuota"]:
		if stato == "vuota":
			pozza.fill = 0.0
			GameState.imposta_luci(GameState.Luci.BLACKOUT)
		await _frames(30)
		for s in scalette:
			await _scendi(s, stato)
			await _sali(s, stato)
	print("SCALETTE: finito")
	get_tree().quit()


## Il primo pavimento sotto [param q] dall'alto.
func _sotto(q: Vector3, da: float) -> Vector3:
	var h := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, da, q.z), Vector3(q.x, da - 8.0, q.z), Layers.WORLD))
	return h.position if not h.is_empty() else q


func _giro(nome: String, verso: Vector3, secondi: float, fermati: Callable, pitch := 0.0) -> Dictionary:
	var prese := 0
	var era := false
	var basso := INF
	var alto := -INF
	var t := 0.0
	Input.action_press(&"move_forward")
	for f in int(Engine.physics_ticks_per_second * secondi):
		p.look_at_point(Vector3(verso.x, p.global_position.y + 1.6, verso.z))
		p.pitch = deg_to_rad(pitch)
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if f % 15 == 0:
			_accendi(p.get_eye_position())
		if p.is_on_ladder() and not era:
			prese += 1
		era = p.is_on_ladder()
		basso = minf(basso, p.global_position.y)
		alto = maxf(alto, p.global_position.y)
		if f % OGNI == 0:
			await _scatto(nome)
		if fermati.call(t):
			break
	_rilascia()
	return {"t": t, "prese": prese, "basso": basso, "alto": alto, "fine": p.global_position.snapped(Vector3.ONE * 0.01)}


## Dal bordo, 1,2 m dietro la cima della scaletta, verso la piscina: avanti finché si è giù (sul fondo o in acqua).
func _scendi(s: Ladder, stato: String) -> void:
	_rilascia()
	var n := s.get_climb_normal()
	var cima := s.get_top_y()
	var bordo := _sotto(s.global_position - n * 1.2, cima + 1.5)
	p.teleport(bordo + Vector3.UP * 0.05)
	await _frames(20)
	_accendi(p.get_eye_position())
	var verso := s.global_position + n * 3.0
	var nome := "%s_%s_scende" % [stato, s.name]
	var r: Dictionary = await _giro(nome, verso, 7.0, func(t): return t > 1.5 and p.global_position.y < cima - 1.2 and p.is_on_floor() and not p.is_on_ladder(), -15.0)
	await _frames(30)
	await _scatto(nome + "_giu")
	print("SCALETTE: %s, %s, scende dal bordo: da y %.2f a %.2f (cima %.2f) in %.1f s, %d prese della scala, fine %s%s" % [stato, s.name,
			bordo.y, r["basso"], cima, r["t"], r["prese"], r["fine"], " sulla scala" if p.is_on_ladder() else ""])


## Dal fondo (o dall'acqua) 1,2 m davanti alla scaletta: avanti finché si è sul bordo.
func _sali(s: Ladder, stato: String) -> void:
	_rilascia()
	var n := s.get_climb_normal()
	var cima := s.get_top_y()
	var giu := _sotto(s.global_position + n * 1.2, cima - 0.3)
	p.teleport(giu + Vector3.UP * 0.05)
	await _frames(20)
	_accendi(p.get_eye_position())
	var nome := "%s_%s_sale" % [stato, s.name]
	var r: Dictionary = await _giro(nome, s.global_position - n * 3.0, 7.0, func(t): return p.is_on_floor() and p.global_position.y > cima - 0.4 and (p.global_position - s.global_position).dot(-n) > 0.3 and not p.is_on_ladder())
	await _frames(30)
	await _scatto(nome + "_su")
	var fuori := p.global_position.y > cima - 0.4
	print("SCALETTE: %s, %s, risale: da y %.2f a %.2f (cima %.2f) in %.1f s, %d prese della scala, fuori sul bordo %s, fine %s" % [stato, s.name,
			giu.y, r["alto"], cima, r["t"], r["prese"], fuori, r["fine"]])


## La posizione di [param n] nella scena [param tutta] (non ancora nell'albero).
static func _globale(n: Node3D, tutta: Node) -> Transform3D:
	var tr := n.transform
	var q := n.get_parent()
	while q and q != tutta:
		if q is Node3D:
			tr = (q as Node3D).transform * tr
		q = q.get_parent()
	if tutta is Node3D:
		tr = (tutta as Node3D).transform * tr
	return tr


## Ogni mesh della sala che entra nella scena parte spenta (si accendono poi quelle vicine alla camera).
func _aggiunto(n: Node) -> void:
	if n is GeometryInstance3D and _radice and _radice.is_ancestor_of(n) and not _accese.has(n):
		(n as GeometryInstance3D).set_meta(&"era_visibile", (n as GeometryInstance3D).visible)
		(n as GeometryInstance3D).visible = false


## Accende le mesh entro [member raggio] m da [param occhio] (quelle che il gioco teneva nascoste restano nascoste) e
## spegne le altre.
func _accendi(occhio: Vector3) -> void:
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.has_meta(&"era_visibile"):
			continue
		var vicino := g.get_aabb().size == Vector3.ZERO or (g.global_transform * g.get_aabb()).grow(raggio).has_point(occhio)
		g.visible = bool(g.get_meta(&"era_visibile")) and vicino
		if g.visible:
			_accese[g] = true
