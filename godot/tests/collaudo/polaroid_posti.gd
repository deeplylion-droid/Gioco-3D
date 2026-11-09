extends Node
## Collaudo Polaroid (0.3.24, lavoro/polaroid-fiume): nel gioco vero, dove sono le Polaroid e a che altezza dal
## pavimento sotto (raggio di Posa e mesh vere), dopo che le stanze della risalita sono costruite e accese.
## Modi: "subito" (la risalita mette le stanze subito, come gli strumenti) o "richiesta" (come nel gioco: il giocatore
## va al corridoio del fiume, le stanze si costruiscono nascoste e ferme e poi si riaccendono).
## Alla fine raccoglie la P16 e guarda se è nella collezione (quella che legge l'album).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/polaroid_posti.gd <modo>

const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var modo: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "subito"
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	if modo == "subito":
		Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene as Node3D
	var p := GameState.player as Player
	var ris := level.get_node_or_null(^"Risalita")
	var t0 := Time.get_ticks_msec()
	# al corridoio del fiume: le stanze si accendono (e, a richiesta, si costruiscono)
	for i in 60:
		await get_tree().physics_frame
	p.teleport(Vector3(-4.9, -5.4, 55.0))   # nel corridoio (c'è il pavimento anche a stanze non costruite)
	var f: Node3D = null
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		f = ris.get(&"fiume") as Node3D if ris else null
		if f and bool(f.get(&"costruita")) and f.can_process() and f.visible and not bool(ris.get(&"_riaccendendo")):
			break
	print("POSTI: modo %s, fiume pronto dopo %.1f s" % [modo, (Time.get_ticks_msec() - t0) / 1000.0])
	await get_tree().create_timer(25.0).timeout
	CorpiMesh.crea(level, AABB(Vector3(-200, -50, -200), Vector3(400, 120, 400)), p)
	for i in 3:
		await get_tree().physics_frame
	var sp := level.get_world_3d().direct_space_state
	var foto := level.find_children("*", "PolaroidPhoto", true, false)
	foto.sort_custom(func(a, b): return int(a.get(&"photo")) < int(b.get(&"photo")))
	for n in foto:
		var ph := n as PolaroidPhoto
		var da := ph.global_position + Vector3.UP * 0.05
		var q := PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 2.0, Posa.STRATI)
		var h := sp.intersect_ray(q)
		var q2 := PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 2.0, CorpiMesh.STRATO)
		var h2 := sp.intersect_ray(q2)
		# (non la Polaroid stessa)
		while not h2.is_empty() and ph.is_ancestor_of(h2.collider as Node):
			q2.exclude = q2.exclude + [(h2.collider as CollisionObject3D).get_rid()]
			h2 = sp.intersect_ray(q2)
		print("POSTO P%02d %s in %s, giro %.1f°, %s: collisione %s mm, mesh %s mm" % [ph.photo, ph.name, ph.global_position.snappedf(0.0001),
				ph.global_rotation_degrees.y, "visibile" if ph.is_visible_in_tree() else "NASCOSTA",
				"%.1f" % ((ph.global_position.y - (h.position as Vector3).y) * 1000.0) if not h.is_empty() else "niente",
				"%.1f" % ((ph.global_position.y - (h2.position as Vector3).y) * 1000.0) if not h2.is_empty() else "niente"])
	var p16: PolaroidPhoto = null
	for n in foto:
		if int(n.get(&"photo")) == 16:
			p16 = n
	if p16:
		print("POSTI: P16 raccolta prima: %s, foto trovate %d" % [PolaroidPhoto.trovata(16), PolaroidPhoto.quante_trovate()])
		p.teleport(p16.global_position + p16.global_basis.z * 0.8)
		for i in 10:
			await get_tree().physics_frame
		p16.interact(p)
		for i in 10:
			await get_tree().process_frame
		print("POSTI: P16 raccolta dopo: %s, foto trovate %d, nodo %s" % [PolaroidPhoto.trovata(16), PolaroidPhoto.quante_trovate(),
				"c'è ancora" if is_instance_valid(p16) and p16.is_inside_tree() and p16.visible else "tolto"])
	else:
		print("POSTI: P16 NON C'È")
	print("POSTI FINITO")
	get_tree().quit()
