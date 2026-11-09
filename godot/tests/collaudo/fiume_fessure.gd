extends Node
## Collaudo riga del fiume (#130): da dove escono i pixel magenta (sfondo magenta, senz'acqua) di alcuni scatti di
## fiume_giro.gd. Per ogni pixel magenta un raggio dalla camera; dove esce dal capannone (o l'ultimo oggetto vicino al
## raggio) raggruppato a 0,5 m. Uso (sotto il render.lock): xvfb-run ... godot --path godot --rendering-driver vulkan
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/fiume_fessure.gd

const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const F := preload("res://scripts/risalita/fiume_gioco.gd")
const GIRO := 70.0
var cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.BLACKOUT
	Grafica.applica_preset("alto")
	var we := WorldEnvironment.new()
	var env := (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 1)
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.06)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.ssr_enabled = false
	we.environment = env
	add_child(we)
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	while not bool(f.get(&"costruita")):
		await get_tree().process_frame
	for mi in f.find_children("*", "GeometryInstance3D", true, false):
		if String(mi.name).to_lower().contains("acqua"):
			(mi as GeometryInstance3D).visible = false
	for i in 120:
		await get_tree().process_frame
	print("FESSURE: corpi ", CorpiMesh.crea(f, AABB(Vector3(-60, -10, -60), Vector3(120, 40, 120))))
	for i in 3:
		await get_tree().physics_frame
	var viste := []
	for v in [["Sbagliato1", 25.0, "piedi", "avanti"], ["Sbagliato1", 25.0, "piedi", "sinistra"], ["Sbagliato2", 25.0, "piedi", "avanti"],
			["Sbagliato2", 25.0, "accovacciato", "sinistra"], ["Uscita", 1.0, "piedi", "avanti"], ["Imbarco", 1.0, "banchina_dx", ""]]:
		var t := f.find_child(v[0], true, false) as TrattoFiume
		var s: float = v[1]
		var d := t.direzione(s)
		d.y = 0.0
		d = d.normalized()
		if v[2] == "banchina_dx":
			var c := t.punto(s)
			var da := c + d.cross(Vector3.UP).normalized() * 3.6
			da.y = 1.6
			viste.append(["%s_%03d_banchina_dx" % [v[0], int(s)], da, Vector3(c.x, -0.4, c.z)])
		else:
			var p := t.punto(s) + Vector3.UP * (1.65 if v[2] == "piedi" else 0.97)
			var dir := d.rotated(Vector3.UP, deg_to_rad(GIRO if v[3] == "sinistra" else 0.0))
			viste.append(["%s_%03d_%s_%s" % [v[0], int(s), v[2], v[3]], p, p + dir * 10.0 + Vector3.DOWN * 0.9])
	var sp := get_viewport().world_3d.direct_space_state
	for v in viste:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var gruppi := {}
		var conta := 0
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var c := img.get_pixel(x, y)
				if not (c.r > 0.7 and c.b > 0.7 and c.g < 0.25):
					continue
				conta += 1
				var o := cam.project_ray_origin(Vector2(x, y))
				var n := cam.project_ray_normal(Vector2(x, y))
				var q := PhysicsRayQueryParameters3D.create(o, o + n * 150.0, CorpiMesh.STRATO)
				q.hit_back_faces = true
				var r := sp.intersect_ray(q)
				var dove := ""
				if r.is_empty():
					# dove il raggio esce dal capannone
					var tt := 1e9
					for asse in [[0, F.X0], [0, F.X1], [2, F.Z0], [2, F.Z1], [1, F.TETTO]]:
						var a: int = asse[0]
						if absf(n[a]) > 1e-5:
							var k: float = (float(asse[1]) - o[a]) / n[a]
							if k > 0.0:
								tt = minf(tt, k)
					dove = "esce a %s" % (o + n * tt).snappedf(0.5)
				else:
					var mesh := (r.collider as Node).get_parent()
					var retro := (r.normal as Vector3).dot(n) > 0.0
					dove = "colpisce %s (%s, %s) a %s" % [mesh.name, mesh.get_parent().name, "dal retro" if retro else "davanti", (r.position as Vector3).snappedf(0.5)]
				gruppi[dove] = int(gruppi.get(dove, 0)) + 1
		print("FESSURE %s: %d pixel, camera %s" % [v[0], conta, (v[1] as Vector3).snappedf(0.01)])
		for g in gruppi:
			print("    %s: %d" % [g, gruppi[g]])
	print("FESSURE FINITO")
	get_tree().quit()
