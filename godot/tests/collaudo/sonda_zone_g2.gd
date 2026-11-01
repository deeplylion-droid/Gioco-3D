extends Node
## grafica-2: la nebbia viola per zona nel corridoio delle pile (partenza F9 "fiume", gioco vero, headless): le zone
## ZonaNebbiaViola del gioco (box nel mondo), quali contengono i punti del corridoio, e quanto vale la nebbia col
## giocatore fermo in ognuno dei punti (dopo 4 s).
const F := preload("res://scripts/risalita/fiume_gioco.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Game.pause_on_focus_loss = false
	print("ZONE versione %s" % ProjectSettings.get_setting("application/config/version"))
	MenuProva.parti(get_tree(), "fiume")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p.is_inside_tree() and p.input_enabled:
			break
	if Game.has_method(&"aspetta_caricamenti"):
		await Game.aspetta_caricamenti(get_tree().current_scene, 120.0)
	for i in 120:
		await get_tree().process_frame
	var fiume: Node3D = null
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n.get_script() == F:
			fiume = n
			break
	var zone := get_tree().get_nodes_in_group(ZonaNebbiaViola.GRUPPO)
	for z in zone:
		var bb := AABB()
		var primo := true
		for cs in (z as Node).find_children("*", "CollisionShape3D", true, false):
			var b := (cs as CollisionShape3D).shape.get_debug_mesh().get_aabb()
			b = (cs as Node3D).global_transform * b
			bb = b if primo else bb.merge(b)
			primo = false
		print("ZONE zona %s: box %s" % [String((z as Node).get_path()).replace("/root/", ""), bb])
	var nv := Grafica.nebbia_viola
	var p := GameState.player as Node3D
	var da := Vector3(F.INGRESSO_X, 0, F.Z0 + 1.0)
	var dir := (F.FINE_FILA - da).normalized()
	var lungo := da.distance_to(F.FINE_FILA)
	var punti := {"porta_ingresso": Vector3(F.INGRESSO_X, 0, F.Z0 + 2.5)}
	for k in 4:
		punti["corridoio_%d" % (k + 1)] = da + dir * lungo * [0.08, 0.35, 0.62, 0.9][k]
	punti["salvagente"] = Vector3(-2.3, 0, -2.3)
	print("ZONE alla partenza: quanto %.2f, zone attive %d" % [nv.quanto, (nv.get(&"_zone") as Array).size()])
	for nome in punti:
		var q: Vector3 = fiume.to_global(punti[nome])
		var dentro := []
		for z in zone:
			if (z as ZonaNebbiaViola).contiene(q + Vector3.UP * 1.0):
				dentro.append(String((z as Node).name))
		p.global_position = q
		var t := 0.0
		while t < 4.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		var attive := (nv.get(&"_zone") as Array).map(func(z): return String(z.name) if is_instance_valid(z) else "?")
		print("ZONE %s %s: contenuto in %s; nebbia quanto %.2f, zone attive %s" % [nome, q.snapped(Vector3.ONE * 0.1), dentro, nv.quanto, attive])
	print("ZONE FINE")
	Game.esci(0)
