extends Node
## grafica-2: le luci che arrivano nel corridoio delle pile del fiume (partenza F9 "fiume", gioco vero, headless):
## per dei punti fissi (occhi a 1,6 m) le luci accese entro 14 m, con energia al disegno (LuciBianche applicata),
## colore, raggio, ombra, maschera, e di chi sono (il percorso). Per confrontare due build.
const F := preload("res://scripts/risalita/fiume_gioco.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Game.pause_on_focus_loss = false
	print("SONDA versione %s" % ProjectSettings.get_setting("application/config/version"))
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
	print("SONDA fiume: %s a %s" % [fiume.get_path() if fiume else "-", fiume.global_position if fiume else "-"])
	var da := Vector3(F.INGRESSO_X, 0, F.Z0 + 1.0)
	var dir := (F.FINE_FILA - da).normalized()
	var lungo := da.distance_to(F.FINE_FILA)
	var punti := {"porta_ingresso": Vector3(F.INGRESSO_X, 1.6, F.Z0 + 2.5)}
	for k in 4:
		punti["corridoio_%d" % (k + 1)] = da + dir * lungo * [0.08, 0.35, 0.62, 0.9][k] + Vector3(0, 1.6, 0)
	punti["salvagente"] = Vector3(-2.3, 1.6, -2.3)
	var lb := get_node_or_null(^"/root/LuciBianche")
	if lb:
		lb.call(&"applica")
	var player := GameState.player as Node3D
	print("SONDA giocatore a %s" % player.global_position)
	for nome in punti:
		var q: Vector3 = fiume.to_global(punti[nome]) if fiume else punti[nome]
		var righe := []
		var somma := 0.0
		for l: Light3D in get_tree().root.find_children("*", "Light3D", true, false):
			if not l.is_visible_in_tree() or l.light_energy <= 0.0 or l is DirectionalLight3D:
				continue
			var d := l.global_position.distance_to(q)
			if d > 14.0:
				continue
			var rg: float = l.get(&"omni_range") if l is OmniLight3D else l.get(&"spot_range")
			var e := l.light_energy * l.light_color.get_luminance() / maxf(d * d, 1.0)
			somma += e
			righe.append([e, "%s E%.2f col %s r%.1f a %.1f m om %s mask %x ind %.2f" % [String(l.get_path()).replace("/root/", ""), l.light_energy, l.light_color.to_html(false), rg, d, l.shadow_enabled, l.light_cull_mask, l.light_indirect_energy]])
		righe.sort_custom(func(x, y): return x[0] > y[0])
		print("SONDA %s (%s): %d luci, somma %.3f" % [nome, q.snapped(Vector3.ONE * 0.1), righe.size(), somma])
		for r in righe.slice(0, 14):
			print("SONDA   %.3f %s" % [r[0], r[1]])
	if lb:
		lb.call(&"ripristina")
	var env: Environment = get_viewport().get_camera_3d().environment if get_viewport().get_camera_3d() else null
	for w: WorldEnvironment in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		if env == null and w.is_inside_tree():
			env = w.environment
	if env:
		print("SONDA ambiente %d %.2f %s sdfgi %s ssil %s voxelgi? tonemap %d esp %.2f" % [env.ambient_light_source, env.ambient_light_energy, env.ambient_light_color.to_html(false), env.sdfgi_enabled, env.ssil_enabled, env.tonemap_mode, env.tonemap_exposure])
	for g in get_tree().root.find_children("*", "VoxelGI", true, false):
		print("SONDA VoxelGI %s a %s visibile %s energia %.2f" % [g.get_path(), (g as Node3D).global_position, (g as Node3D).is_visible_in_tree(), (g as VoxelGI).data.energy if (g as VoxelGI).data else -1.0])
	for g in get_tree().root.find_children("*", "LightmapGI", true, false):
		print("SONDA LightmapGI %s visibile %s" % [g.get_path(), (g as Node3D).is_visible_in_tree()])
	print("SONDA FINE")
	Game.esci(0)
