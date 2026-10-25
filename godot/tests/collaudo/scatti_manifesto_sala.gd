extends Node
## Collaudo del manifesto rovinato nella posizione vera della sala: solo l'architettura della sala
## (sala_architettura.glb, coi suoi muri e le collisioni) e le mascotte (MascotteSala, che mette il manifesto a filo del
## muro con Posa.fissa_al_muro, come nel gioco). Misura quanto ogni vertice del manifesto sta davanti al muro (lungo la
## normale) e scatta dagli occhi del giocatore, dall'alto, dal basso, radente dai due lati, lo scotch in alto a destra e
## l'angolo in basso a sinistra; una lampadina di collaudo accanto alla camera solo negli scatti "_luce".
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd \
##        -- res://tests/collaudo/scatti_manifesto_sala.gd <cartella>


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out)
	Game.pause_on_focus_loss = false
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.55)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = e
	add_child(we)
	var arch := (load("res://assets/ambiente/sala/sala_architettura.glb") as PackedScene).instantiate() as Node3D
	add_child(arch)
	for i in 5:
		await get_tree().physics_frame
	var masc := Node3D.new()
	masc.name = "Mascotte"
	masc.set_script(load("res://scripts/environment/mascotte_sala.gd"))
	add_child(masc)
	for i in 5:
		await get_tree().physics_frame
	var man := masc.get_node("ManifestoJilly") as Node3D
	var n := Vector3(1, 0, 0)
	# il muro: un raggio dal centro del manifesto verso il muro, partendo da davanti
	var c := man.global_position
	var q := PhysicsRayQueryParameters3D.create(c + n * 0.5, c - n * 1.0)
	var h := get_viewport().world_3d.direct_space_state.intersect_ray(q)
	var muro_x: float = (h.position as Vector3).x if h else NAN
	var righe := PackedStringArray()
	righe.append("manifesto a %s, muro a x %.4f" % [man.global_position, muro_x])
	# ogni vertice: quanto sta davanti al muro (per mesh e per quarti del manifesto)
	var b := AABB()
	var primo := true
	for mi in man.find_children("*", "MeshInstance3D", true, false):
		var bb := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		b = bb if primo else b.merge(bb)
		primo = false
	for mi in man.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var mesh := m.mesh
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var mx := -INF
			var mn := INF
			var dove := Vector3.ZERO
			var quarti := {}
			for v in vs:
				var g := m.global_transform * v
				var d := g.x - muro_x
				if d > mx:
					mx = d
					dove = g
				mn = minf(mn, d)
				var qn := ("alto" if g.y > b.get_center().y else "basso") + "_" + ("dx" if g.z < b.get_center().z else "sx")
				quarti[qn] = maxf(float(quarti.get(qn, -INF)), d)
			var mat := mesh.surface_get_material(si)
			righe.append("%s superficie %d (%s): %d vertici, davanti al muro da %.1f a %.1f mm (il più lontano in %s); per quarti (sx/dx visti dal giocatore): %s" % [
				m.name, si, mat.resource_name if mat else "-", vs.size(), mn * 1000.0, mx * 1000.0, dove,
				", ".join(quarti.keys().map(func(k): return "%s %.1f mm" % [k, float(quarti[k]) * 1000.0]))])
	# il muro vero dietro ogni vertice (un campione: un vertice ogni 150), raggio lungo la normale: la distanza vera dal
	# muro locale (le piastrelle, la fascia rossa, il bordo)
	var spazio := get_viewport().world_3d.direct_space_state
	for mi in man.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var vs: PackedVector3Array = m.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var mn := INF
		var mx := -INF
		var dove_mn := Vector3.ZERO
		var passo := 150 if vs.size() > 1000 else 1
		for k in range(0, vs.size(), passo):
			var g := m.global_transform * vs[k]
			var r := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(g + n * 0.3, g - n * 0.3))
			if r.is_empty():
				continue
			var d: float = g.x - (r.position as Vector3).x
			if d < mn:
				mn = d
				dove_mn = g
			mx = maxf(mx, d)
		righe.append("%s rispetto al muro locale: da %.1f a %.1f mm (il più vicino in %s)" % [m.name, mn * 1000.0, mx * 1000.0, dove_mn])
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.02
	add_child(cam)
	cam.make_current()
	var luce := OmniLight3D.new()
	luce.light_energy = 1.2
	luce.omni_range = 4.0
	luce.shadow_enabled = true
	cam.add_child(luce)
	luce.position = Vector3(0.25, 0.2, 0)
	var cc := b.get_center()
	var w := b.size.z
	var hh := b.size.y
	var dx := cc + Vector3(0, hh * 0.45, -w * 0.45)      # in alto a destra (vista dal giocatore)
	var sx := cc + Vector3(0, -hh * 0.45, w * 0.45)      # in basso a sinistra
	var viste := {
		"giocatore": [Vector3(-17.5, 1.6, 13.4), cc],
		"alto": [cc + Vector3(0.35, hh * 0.5 + 0.45, 0.0), cc + Vector3(0, hh * 0.35, 0)],
		"basso": [cc + Vector3(0.4, -hh * 0.5 - 0.35, 0.0), cc + Vector3(0, -hh * 0.35, 0)],
		"radente_sx": [cc + Vector3(0.12, 0.0, w * 0.5 + 0.7), cc],
		"radente_dx": [cc + Vector3(0.12, 0.0, -w * 0.5 - 0.7), cc],
		"scotch": [dx + Vector3(0.25, 0.15, -0.2), dx],
		"scotch_radente": [dx + Vector3(0.05, 0.25, -0.05), dx],
		"angolo_sx": [sx + Vector3(0.25, -0.15, 0.2), sx],
		"angolo_sx_radente": [sx + Vector3(0.06, -0.05, 0.35), sx],
	}
	for v in viste:
		for con_luce in [false, true]:
			luce.visible = con_luce
			cam.global_position = viste[v][0]
			cam.look_at(viste[v][1], Vector3.UP)
			for i in 10:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(out.path_join("manifesto_%s%s.jpg" % [v, "_luce" if con_luce else ""]), 0.9)
	var fh := FileAccess.open(out.path_join("misure.txt"), FileAccess.WRITE)
	fh.store_string("\n".join(righe) + "\n")
	fh.close()
	print("\n".join(righe))
	get_tree().quit()
