extends Node
## Collaudo di lavoro/varchi-cielo: dalla cima della scala di servizio alla porta di C3 nel gioco vero, la "texture
## grigia" (il cielo) non si deve vedere. Senza schermo: si parte dal menu F9 (fiume), si risolve l'enigma delle pozze e si
## raggiunge il checkpoint a enigma risolto (salvato su disco); poi
##  1) dal gioco così com'è: il giocatore messo ogni 0,5 m dalla cima della scala alla porta di C3 (30 fotogrammi fermo,
##     perché le zone si accendono col giocatore vicino), e da lì 36 raggi verso il vano della porta e oltre;
##  2) da Continua (GameState.continue_from_disk), le stesse pose.
## I raggi guardano solo le mesh VISIBILI in quel momento (corpi temporanei dalle mesh visibili, CorpiMesh, rifatti a ogni
## posa): un raggio che non tocca niente di visibile entro 120 m è cielo. Stampa CIELO: con quanti raggi su quanti, e
## quante mesh di Tecnici (il corridoio C3) sono visibili oltre la porta.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scala_c3_cielo.gd

const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const DISTANZA := 120.0


func _ready() -> void:
	_run.call_deferred()


func _pronto() -> bool:
	var pl := GameState.player
	var sc := get_tree().current_scene
	return pl and is_instance_valid(pl) and pl.input_enabled and not GameState.is_dying and sc \
			and not String(sc.scene_file_path).contains("caricamento")


func _aspetta() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		if _pronto():
			break
	for i in 60 * 20:
		await get_tree().process_frame


func _ris() -> Node3D:
	return get_tree().current_scene.find_child("Risalita", true, false) as Node3D


func _run() -> void:
	Game.pause_on_focus_loss = false
	MenuProva.parti(get_tree(), "fiume")
	await _aspetta()
	var ris := _ris()
	print("CIELO: partenza fiume, Risalita %s, checkpoint %s" % [ris != null, GameState.snapshot.get("checkpoint", "")])
	for i in 3000:
		await get_tree().process_frame
		if ris.get(&"fiume") != null and not bool(ris.call(&"lavori_in_corso")) and i > 120:
			break
	for ep in ris.find_children("EnigmaPozze", "", true, false):
		if ep.has_method(&"load_state"):
			ep.call(&"load_state", {"stato": 2, "tolti": ["turchese", "viola", "arancione"]})
	for i in 240:
		await get_tree().physics_frame
	var cp := ris.find_child("CheckpointRisolto", true, false) as Checkpoint
	GameState.player.teleport(cp.get_spawn_transform().origin + Vector3.UP * 0.1)
	await get_tree().physics_frame
	GameState.reach_checkpoint(cp)
	for i in 120:
		await get_tree().process_frame
	print("CIELO: checkpoint raggiunto %s, salvataggio su disco %s" % [GameState.snapshot.get("checkpoint", ""), GameState.has_save()])
	await _giro("gioco")
	print("CIELO: Continua: %s" % GameState.continue_from_disk())
	await _aspetta()
	print("CIELO: da Continua, checkpoint %s, giocatore in %s" % [GameState.snapshot.get("checkpoint", ""), GameState.player.global_position.snapped(Vector3.ONE * 0.01)])
	await _giro("continua")
	print("CIELO: finito")
	get_tree().quit()


func _giro(come: String) -> void:
	var ris := _ris()
	var sala := get_tree().current_scene as Node3D
	var p := GameState.player
	for i in 3000:
		await get_tree().process_frame
		if ris.get(&"fiume") != null and not bool(ris.call(&"lavori_in_corso")) and i > 60:
			break
	var m := ris.get_node(^"Marker")
	var cima := (m.get_node(^"CimaScala") as Node3D).global_position
	var c3 := (m.get_node(^"PortaC3") as Node3D).global_position
	var passi := int(ceil(cima.distance_to(c3) / 0.5))
	var tot := 0
	for k in passi + 1:
		var piede := cima.lerp(c3, float(k) / passi)
		p.teleport(piede + Vector3.UP * 0.1)
		for i in 30:
			await get_tree().physics_frame
		CorpiMesh.crea(sala, AABB(cima, Vector3.ZERO).expand(c3).grow(40.0), p)
		for i in 2:
			await get_tree().physics_frame
		var occhio := p.global_position + Vector3.UP * 1.6
		var fuori := 0
		var tirati := 0
		var dove := {}
		for zi in 6:
			for yi in 6:
				var b := ris.to_global(Vector3(-16.15, 0.1 + yi * 0.38, 37.97 + zi * 0.19))
				var q := PhysicsRayQueryParameters3D.create(occhio, occhio + (b - occhio).normalized() * DISTANZA, CorpiMesh.STRATO)
				q.hit_back_faces = true
				var h := get_viewport().find_world_3d().direct_space_state.intersect_ray(q)
				tirati += 1
				if h.is_empty():
					fuori += 1
				else:
					var n := (h.collider as Node).get_parent() as Node
					var nome := String(n.name)
					dove[nome] = int(dove.get(nome, 0)) + 1
		tot += fuori
		# le mesh visibili oltre la porta (x più piccola della porta, entro 12 m)
		var porta_x: float = ris.to_global(Vector3(-16.15, 0, 0)).x
		var oltre := 0
		for mi in sala.find_children("*", "MeshInstance3D", true, false):
			var mm := mi as MeshInstance3D
			if mm.mesh and mm.is_visible_in_tree():
				var c := (mm.global_transform * mm.get_aabb()).get_center()
				if absf(c.z - occhio.z) < 12.0 and c.x < porta_x - 0.3 and c.x > porta_x - 14.0 and absf(c.y - occhio.y) < 6.0:
					oltre += 1
		var primi := dove.keys()
		primi.sort_custom(func(a, b): return dove[a] > dove[b])
		print("CIELO: %s, a %.1f m dalla porta: %d raggi su %d nel cielo; mesh visibili oltre la porta %d; colpiti %s" % [come,
				occhio.distance_to(Vector3(porta_x, occhio.y, occhio.z)), fuori, tirati, oltre, ", ".join(primi.slice(0, 4).map(func(x): return "%s %d" % [x, dove[x]]))])
	print("CIELO: %s, totale raggi nel cielo %d" % [come, tot])
