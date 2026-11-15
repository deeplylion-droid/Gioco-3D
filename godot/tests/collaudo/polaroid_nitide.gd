extends Node
## Collaudo: le Polaroid da vicino col renderer vero, tutte nelle stesse condizioni (le texture P11-P16 compresse come
## P01-P10, lavoro/godot 0b2c2564). Su un piano grigio, con una luce bianca e l'ambiente neutro, ogni foto (scena vera
## della Polaroid, materiali del gioco) si scatta dall'alto a 25 cm e a 60 cm e di sbieco a 40 cm (le mipmap più basse).
## Uso: xvfb-run -a -s "-screen 0 960x960x24" godot --path godot --rendering-driver vulkan --resolution 960x960 \
##        --script res://tests/run.gd -- res://tests/collaudo/polaroid_nitide.gd <cartella>

const SCENA := "res://scenes/props/polaroid.tscn"
const FOTO := [1, 3, 5, 7, 10, 11, 12, 13, 14, 15, 16]
var cart := ""
var cam: Camera3D


func _ready() -> void:
	cart = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	_run.call_deferred()


func _run() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.2, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-60, 30, 0)
	sole.light_energy = 1.0
	add_child(sole)
	var piano := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4, 4)
	piano.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.35)
	piano.material_override = mat
	add_child(piano)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.01
	add_child(cam)
	cam.current = true
	for n in FOTO:
		var f := (load(SCENA) as PackedScene).instantiate()
		f.set(&"photo", n)
		f.set(&"snap_to_surface", false)
		add_child(f)
		(f as Node3D).global_position = Vector3(0, 0.002, 0)
		for i in 10:
			await get_tree().process_frame
		var c := _aabb(f as Node3D).get_center()
		for v in [["alto_25", c + Vector3(0, 0.25, 0.001)], ["alto_60", c + Vector3(0, 0.6, 0.001)], ["sbieco_40", c + Vector3(0, 0.2, 0.35)]]:
			cam.look_at_from_position(v[1], c, Vector3.FORWARD if v[0].begins_with("alto") else Vector3.UP)
			for i in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(cart.path_join("P%02d_%s.jpg" % [n, v[0]]), 0.92)
		print("NITIDE: P%02d fatta (scatola %s)" % [n, _aabb(f as Node3D).size])
		f.queue_free()
		await get_tree().process_frame
	print("NITIDE: finito")
	get_tree().quit()


func _aabb(n: Node3D) -> AABB:
	var bb := AABB()
	var primo := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var vi := m as MeshInstance3D
		var b := vi.global_transform * vi.get_aabb()
		bb = b if primo else bb.merge(b)
		primo = false
	if primo:
		bb = AABB(n.global_position - Vector3.ONE * 0.05, Vector3.ONE * 0.1)
	return bb
