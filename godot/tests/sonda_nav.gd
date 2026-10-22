extends Node
## Sonda: navmesh dell'area bimbi cotta dalle collisioni (agente come il Player: raggio 0,35, alto 1,75,
## gradino 0,32): quali pedane della struttura di gioco si raggiungono a piedi da terra.
const LEVEL := "res://scenes/sala_principale.tscn"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 5:
		await get_tree().physics_frame
	var level := get_tree().current_scene
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Layers.WORLD
	nm.agent_radius = 0.35
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.32
	nm.agent_max_slope = 45.0
	nm.cell_size = 0.05
	nm.cell_height = 0.05
	nm.filter_baking_aabb = AABB(Vector3(-20.0, -0.5, -22.0), Vector3(12.0, 10.0, 10.0))
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, level)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	print("NAV poligoni: ", nm.get_polygon_count())
	var mappa := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(mappa, 0.05)
	NavigationServer3D.map_set_cell_height(mappa, 0.05)
	NavigationServer3D.map_set_active(mappa, true)
	var reg := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(reg, mappa)
	NavigationServer3D.region_set_navigation_mesh(reg, nm)
	for i in 3:
		await get_tree().physics_frame
	NavigationServer3D.map_force_update(mappa)
	var da := Vector3(-13.6, 0.0, -15.0)
	var mete := {"verde": Vector3(-17.2, 1.24, -15.6), "arancio": Vector3(-14.15, 1.71, -18.4), "rossa": Vector3(-17.2, 2.72, -18.4),
		"secchio": Vector3(-15.2, 4.07, -19.8), "scivolo_cima": Vector3(-12.5, 1.55, -18.2)}
	for k in mete:
		var w: Vector3 = mete[k]
		var vicino := NavigationServer3D.map_get_closest_point(mappa, w)
		var giro := NavigationServer3D.map_get_path(mappa, da, vicino, true)
		var fine: Vector3 = giro[giro.size() - 1] if giro.size() > 0 else Vector3.INF
		print("NAV %s: punto della navmesh più vicino %s (a %.2f m), strada di %d punti fino a %s %s" % [k, vicino, vicino.distance_to(w), giro.size(), fine, "RAGGIUNTA" if fine.distance_to(vicino) < 0.3 else "NO"])
		if fine.distance_to(vicino) < 0.3:
			print("NAV   strada ", giro)
	get_tree().quit()
