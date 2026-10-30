extends Node
## Collaudo della nebbia viola (ZonaNebbiaViola), col renderer vero e il giocatore vero: in una zona cerca sul bordo
## della sua scatola un varco (pavimento fuori e dentro, niente in mezzo all'altezza del petto), mette il giocatore
## 1,5 m fuori, lo fa camminare dentro per 5 s guardando avanti, poi si gira e torna fuori per 5 s. Ogni 0,5 s uno
## scatto e il valore della nebbia (Grafica.nebbia_viola.quanto, in_zona). Alla fine, dentro, l'opzione spenta e
## riaccesa (scatti). Stampa anche le compilazioni di pipeline durante il giro.
## Zone: "infermeria" (tests/scene/infermeria_gioco_prova.tscn), "tunnel" (scenes/test/sottomarino_prova.tscn),
## "sala" (la sala ridotta, tests/scena_ridotta.gd, senza le parti pesanti).
## Uso: xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/nebbia_giro.gd <cartella> <zona>

const SCENE := {
	"infermeria": "res://tests/scene/infermeria_gioco_prova.tscn",
	"tunnel": "res://scenes/test/sottomarino_prova.tscn",
}
const SALA := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Sala/Dettagli", "Gioco/EnigmaAcquari", "Atmosfera", "Polaroid", "Vasche", "Piscina", "Vasca",
		"Sala/Piscina", "Sala/VascaCentrale", "Sala/Cupola", "Sala/AreaBimbi", "Sala/Oggetti", "Sala/TorreScivoli"]
var cart := ""
var zona_nome := ""
var p: Player
var _n := 0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	zona_nome = a[2]
	DirAccess.make_dir_recursive_absolute(cart)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _pip() -> Vector2i:
	return Vector2i(int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)))


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var nv = Grafica.get(&"nebbia_viola")
	get_viewport().get_texture().get_image().save_jpg(cart.path_join("%s_%02d_%s.jpg" % [zona_nome, _n, nome]), 0.88)
	print("NEBBIA: %02d %s: quanto %.2f, in zona %s, giocatore %s" % [_n, nome, float(nv.quanto) if nv else -1.0,
		nv.in_zona() if nv else false, p.global_position.snapped(Vector3.ONE * 0.01)])
	_n += 1


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.reset_progress()
	if zona_nome == "sala":
		Engine.set_meta(&"risalita_subito", true)
		get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci(SALA, TOGLI))
	else:
		get_tree().change_scene_to_file(SCENE[zona_nome])
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	p = GameState.player
	var sc := get_tree().current_scene
	if sc.get(&"sala_sottomarino_scena") != null:
		sc.set(&"sala_sottomarino_scena", "")
	if zona_nome == "sala" and sc.has_method(&"applica_preset"):
		sc.call(&"applica_preset", "basso")
	var z: ZonaNebbiaViola = null
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000 and z == null:
		await get_tree().process_frame
		var lavori := sc.has_method(&"lavori_in_corso") and bool(sc.call(&"lavori_in_corso"))
		if not lavori:
			for n in get_tree().root.find_children("*", "ZonaNebbiaViola", true, false):
				z = n
		# il tunnel della scena di prova si costruisce più avanti nella partita: qui lo si costruisce subito
		if z == null and Time.get_ticks_msec() - t0 > 30000 and Time.get_ticks_msec() - t0 < 30100:
			for n in get_tree().root.find_children("*", "SalaSottomarino", true, false):
				if n.has_method(&"costruisci") and not bool(n.get(&"costruita")):
					print("NEBBIA: costruisco %s" % n.get_path())
					n.call(&"costruisci")
	await _frames(120)
	if z == null:
		print("NEBBIA: ERRORE nessuna ZonaNebbiaViola")
		get_tree().quit()
		return
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var bb := AABB()
	var primo := true
	for cs in z.find_children("*", "CollisionShape3D", false, false):
		var b := (cs as CollisionShape3D).shape as BoxShape3D
		if b:
			var a := AABB((cs as Node3D).global_position - b.size * 0.5, b.size)
			bb = a if primo else bb.merge(a)
			primo = false
	print("NEBBIA: zona %s, scatola %s, quota %.2f" % [z.get_path(), bb, z.quota])
	var varco := _varco(z, bb)
	if varco.is_empty():
		# le porte della stanza chiuse (scena di prova): si aprono, come più avanti nel gioco
		var aperte := 0
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method(&"apri") and n is Node3D and bb.grow(1.0).has_point((n as Node3D).global_position):
				n.call(&"apri")
				aperte += 1
		print("NEBBIA: nessun varco, aperte %d porte" % aperte)
		await _frames(240)
		varco = _varco(z, bb)
	var salto := false
	if varco.is_empty():
		# senza varco: fuori e dentro col salto della camera (come Continua e i checkpoint)
		salto = true
		var de := _pavimento(z.get_world_3d().direct_space_state, bb.get_center(), z.quota)
		var fu := p.global_position if not z.contiene(p.global_position + Vector3.UP) else bb.get_center() + Vector3(bb.size.x, 0, 0)
		varco = [fu, de if de.x != INF else bb.get_center()]
		print("NEBBIA: nessun varco anche con le porte aperte: entro ed esco col salto della camera")
	var fuori: Vector3 = varco[0]
	var dentro: Vector3 = varco[1]
	print("NEBBIA: varco: fuori %s, dentro %s" % [fuori.snapped(Vector3.ONE * 0.01), dentro.snapped(Vector3.ONE * 0.01)])
	var pip0 := _pip()
	p.teleport(fuori)
	p.look_at_point(dentro + Vector3.UP * 1.4)
	await _frames(180)
	await _scatto("fuori")
	# dentro, camminando (o col salto)
	if salto:
		p.teleport(dentro)
		p.look_at_point(dentro + Vector3(1, 1.4, 0))
		for k in 4:
			await _frames(15)
			await _scatto("salto_dentro")
	Input.action_press(&"move_forward")
	for k in (0 if salto else 10):
		for i in 30:
			p.look_at_point(dentro + (dentro - fuori).normalized() * 6.0 + Vector3.UP * 1.4)
			await get_tree().physics_frame
		await _scatto("entra")
	Input.action_release(&"move_forward")
	await _frames(60)
	await _scatto("dentro")
	# l'opzione spenta e riaccesa
	var nv = Grafica.get(&"nebbia_viola")
	if nv:
		nv.set(&"accesa", false)
		await _frames(150)
		await _scatto("opzione_spenta")
		nv.set(&"accesa", true)
		await _frames(150)
		await _scatto("opzione_accesa")
	# fuori, camminando
	var qui := p.global_position
	if salto:
		p.teleport(fuori)
		for k in 6:
			await _frames(30)
			await _scatto("salto_fuori")
	Input.action_press(&"move_forward")
	for k in (0 if salto else 10):
		for i in 30:
			p.look_at_point(fuori + (fuori - qui).normalized() * 6.0 + Vector3.UP * 1.4)
			await get_tree().physics_frame
		await _scatto("esce")
	Input.action_release(&"move_forward")
	await _frames(120)
	await _scatto("fuori_dopo")
	var pip := _pip() - pip0
	print("NEBBIA: compilazioni durante il giro: surface %d, draw %d" % [pip.x, pip.y])
	print("NEBBIA: finito")
	get_tree().quit()


## Un varco sul bordo della scatola: [fuori, dentro], con pavimento in tutti e due, a meno di 1,5 m dalla quota, e
## niente fra i due all'altezza del petto.
func _varco(z: ZonaNebbiaViola, bb: AABB) -> Array:
	var spazio := z.get_world_3d().direct_space_state
	var c := bb.get_center()
	var facce := [[Vector3.RIGHT, bb.end.x, "x"], [Vector3.LEFT, bb.position.x, "x"], [Vector3.BACK, bb.end.z, "z"], [Vector3.FORWARD, bb.position.z, "z"]]
	var migliore: Array = []
	var d_migliore := INF
	for f in facce:
		var n: Vector3 = f[0]
		var lungo := Vector3(0, 0, 1) if f[2] == "x" else Vector3(1, 0, 0)
		var da: float = bb.position.z if f[2] == "x" else bb.position.x
		var a: float = bb.end.z if f[2] == "x" else bb.end.x
		var s := da + 0.5
		while s < a - 0.5:
			var bordo := Vector3(f[1], 0, s) if f[2] == "x" else Vector3(s, 0, f[1])
			var fu := _pavimento(spazio, bordo + n * 1.5, z.quota)
			var de := _pavimento(spazio, bordo - n * 2.5, z.quota)
			if fu.x != INF and de.x != INF and not z.contiene(fu + Vector3.UP * 1.0) and z.contiene(de + Vector3.UP * 1.0):
				var q := PhysicsRayQueryParameters3D.create(fu + Vector3.UP * 1.2, de + Vector3.UP * 1.2)
				q.exclude = [p.get_rid()]
				if spazio.intersect_ray(q).is_empty():
					var q2 := PhysicsRayQueryParameters3D.create(fu + Vector3.UP * 0.4, de + Vector3.UP * 0.4)
					q2.exclude = [p.get_rid()]
					if spazio.intersect_ray(q2).is_empty():
						# il varco più vicino al giocatore di partenza (di solito la strada del gioco)
						var d := fu.distance_to(p.global_position)
						if d < d_migliore:
							d_migliore = d
							migliore = [fu, de]
			s += 0.5
	return migliore


func _pavimento(spazio: PhysicsDirectSpaceState3D, q: Vector3, quota: float) -> Vector3:
	var r := PhysicsRayQueryParameters3D.create(Vector3(q.x, quota + 1.8, q.z), Vector3(q.x, quota - 1.5, q.z))
	r.exclude = [p.get_rid()]
	var h := spazio.intersect_ray(r)
	if h.is_empty() or (h.normal as Vector3).y < 0.8:
		return Vector3.INF
	return h.position
