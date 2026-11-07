extends Node
## Sonda del collaudo 0.3.21 (mascotte): che cos'è la striscia chiara a pelo d'acqua contro la sponda negli scatti del
## fiume dalla ciambella (collaudo_0321_fiume.gd: Giusto1 a 37 m e Giusto2 a 1 m, a sinistra). Rifà quelle camere,
## lancia un raggio dai pixel della striscia sulle collisioni e sulle mesh vere (CorpiMesh) e stampa cosa colpisce; poi
## uno scatto da 1,2 m sul punto colpito.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/sonda_0321_striscia_fiume.gd <cartella>

const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
## [tratto, s, pixel della striscia]
const CASI := [["Giusto1", 37.0, [Vector2(467, 583), Vector2(125, 624), Vector2(800, 537)]],
	["Giusto2", 1.0, [Vector2(384, 587), Vector2(172, 638), Vector2(634, 557)]]]
var cartella := "/tmp/striscia"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.BLACKOUT
	Grafica.applica_preset("alto")
	var we := WorldEnvironment.new()
	we.environment = load("res://addons/grafica/sala/ambiente_sala.tres") as Environment
	we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(we)
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	for i in 240:
		await get_tree().process_frame
	for i in 3:
		await get_tree().physics_frame
	var sp := f.get_world_3d().direct_space_state
	for caso in CASI:
		var t := f.find_child(caso[0], true, false) as TrattoFiume
		var s: float = caso[1]
		var p := t.punto(s) + Vector3.UP * 1.65
		var d := t.direzione(s)
		d.y = 0.0
		var dir := d.normalized().rotated(Vector3.UP, deg_to_rad(70.0))
		cam.global_position = p
		cam.look_at(p + dir * 10.0 + Vector3.DOWN * 0.9, Vector3.UP)
		await get_tree().process_frame
		var primo := Vector3.INF
		for px: Vector2 in caso[2]:
			var o := cam.project_ray_origin(px)
			var n := cam.project_ray_normal(px)
			var rq := PhysicsRayQueryParameters3D.create(o, o + n * 60.0, 0xFFFFFFFF)
			rq.hit_back_faces = true
			var h := sp.intersect_ray(rq)
			if h.is_empty():
				# niente di solido: il punto dove il raggio incontra il pelo dell'acqua (la quota della strada del tratto)
				var pelo := Plane(Vector3.UP, t.punto(s).y)
				var q = pelo.intersects_ray(o, n)
				print("%s %.0f m, pixel %s: niente di solido; sul pelo dell'acqua (y %.2f) a %s, a %.1f m" % [caso[0], s, px, t.punto(s).y,
						(q as Vector3).snapped(Vector3.ONE * 0.01) if q != null else "-", o.distance_to(q) if q != null else -1.0])
				if q != null:
					for mi in f.find_children("*", "MeshInstance3D", true, false):
						var bb2 := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
						if bb2.grow(0.1).has_point(q) and bb2.size.length() < 40.0:
							print("     vicino: %s (%s)" % [String(f.get_path_to(mi)), bb2.size.snapped(Vector3.ONE * 0.01)])
					if primo == Vector3.INF:
						primo = q
				continue
			var c: Object = h["collider"]
			var chi := String((c as Node).get_path()) if c is Node else str(c)
			if c is Node and (c as Node).has_meta(&"mesh"):
				chi += " (mesh %s)" % (c as Node).get_meta(&"mesh")
			print("%s %.0f m, pixel %s: %s, normale %s, a %.1f m: %s" % [caso[0], s, px, (h["position"] as Vector3).snapped(Vector3.ONE * 0.01),
					(h["normal"] as Vector3).snapped(Vector3.ONE * 0.01), o.distance_to(h["position"]), chi])
			if primo == Vector3.INF:
				primo = h["position"]
			# le mesh vicine al punto
			for mi in f.find_children("*", "MeshInstance3D", true, false):
				var bb := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				if bb.grow(0.05).has_point(h["position"]) and bb.size.length() < 30.0:
					print("     vicino: %s (%s)" % [String(f.get_path_to(mi)), bb.size.snapped(Vector3.ONE * 0.01)])
		if primo != Vector3.INF:
			cam.global_position = primo + Vector3.UP * 0.6 + (p - primo).normalized() * 1.2
			cam.look_at(primo, Vector3.UP)
			for i in 12:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s_%d_vicino.jpg" % [caso[0], int(s)]), 0.9)
	print("SONDA FINITA")
	get_tree().quit()
