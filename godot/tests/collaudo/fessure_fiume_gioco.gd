extends Node
## Collaudo riga del fiume (#130): nel gioco vero, cosa si vede dalle fessure che nel fiume da solo danno magenta (fra
## la capanna e la parete vicino all'imbarco, sotto la valvola verde dell'approdo). Dagli occhi degli scatti di
## fiume_giro.gd, raggi verso i punti dove nel fiume da solo escono (la porta d'ingresso a x -26, z -28,6 e la porta di
## servizio dell'approdo a x -41, z 0): cosa colpiscono nel livello (collisioni e mesh vere), o se vanno nel cielo.
## Senza rendering. Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/fessure_fiume_gioco.gd

const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const GIRO := 70.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene as Node3D
	var ris: Node = null
	var fiume: Node3D = null
	for i in 3000:
		await get_tree().process_frame
		ris = level.get_node_or_null(^"Risalita")
		fiume = ris.get(&"fiume") as Node3D if ris else null
		if fiume and bool(fiume.get(&"costruita")):
			break
	if fiume == null:
		print("FESSURE: il fiume non c'è")
		get_tree().quit()
		return
	(GameState.player as Player).teleport(fiume.global_position + Vector3.UP * 0.5)
	for i in 120:
		await get_tree().physics_frame
	print("FESSURE: fiume a %s, corpi %d" % [fiume.global_position, CorpiMesh.crea(level, AABB(fiume.global_position, Vector3.ZERO).grow(120.0), GameState.player)])
	for i in 5:
		await get_tree().physics_frame
	var sp := level.get_world_3d().direct_space_state
	var occhi := []
	for v in [["Sbagliato1", 25.0, 1.65], ["Sbagliato2", 25.0, 1.65], ["Sbagliato2", 25.0, 0.97], ["Uscita", 1.0, 1.65], ["Imbarco", 1.0, -1.0]]:
		var t := fiume.find_child(v[0], true, false) as TrattoFiume
		var s: float = v[1]
		if float(v[2]) < 0.0:
			var d := t.direzione(s)
			d.y = 0.0
			var da := t.punto(s) + d.normalized().cross(Vector3.UP).normalized() * 3.6
			da.y = fiume.global_position.y + 1.6
			occhi.append(["%s_%03d_banchina_dx" % [v[0], int(s)], da])
		else:
			occhi.append(["%s_%03d_occhi_%.2f" % [v[0], int(s), v[2]], t.punto(s) + Vector3.UP * float(v[2])])
	var mete := []
	for y in [0.5, 1.0, 1.5, 2.0]:
		for z in [-0.5, 0.0, 0.5]:
			mete.append(["porta approdo", Vector3(-41.0, y, z)])
		for x in [-26.5, -26.0, -25.5]:
			mete.append(["porta ingresso", Vector3(x, y, -28.6)])
	for o in occhi:
		var da: Vector3 = o[1]
		var esiti := {}
		for m in mete:
			var verso: Vector3 = fiume.to_global(m[1])
			var dir := (verso - da).normalized()
			var q := PhysicsRayQueryParameters3D.create(da, da + dir * 150.0, Layers.WORLD | CorpiMesh.STRATO)
			q.hit_back_faces = true
			q.exclude = [(GameState.player as CollisionObject3D).get_rid()]
			var r := sp.intersect_ray(q)
			var cosa := "CIELO"
			if not r.is_empty():
				var c := r.collider as Node
				var nodo: Node = c.get_parent() if c.has_meta(&"corpo_dalla_mesh") or c.get_parent() is MeshInstance3D else c
				cosa = "%s a %.1f m" % [str(level.get_path_to(nodo)).get_slice("/", 0) + "/…/" + nodo.name, da.distance_to(r.position)]
			var k := "%s -> %s" % [m[0], cosa]
			esiti[k] = int(esiti.get(k, 0)) + 1
		print("FESSURE %s:" % o[0])
		for k in esiti:
			print("    %s (%d raggi)" % [k, esiti[k]])
	print("FESSURE FINITO")
	get_tree().quit()
