extends Node
## Scatti dal motore del saluto di Jilly (JillySpot.saluta: col sorriso, l'occhio a mezzaluna) per lo spot (inquadrature 5-6, tools/blender/medusa_spot.py,
## libreria res://assets/models/medusa/medusa_spot.res, animazioni "spot/<nome>"): lei in piedi su un
## piedistallo di prova (quello vero lo fa la sala dello spot), luce da spettacolo con i fari rosa e viola
## (scelta dell'utente), da davanti e in primo piano, in quattro momenti.
## Uso (sotto render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://proposte/mascotte/scatti_jilly_saluto.gd <cartella>

const SPOT := "res://assets/models/medusa/medusa_spot.res"
## nome: [secondi dall'inizio di saluta_su, camera rispetto all'occhio, verso dove rispetto all'occhio, campo]
const SCATTI := [
	["alza", 0.45, Vector3(0.9, -0.6, 4.6), Vector3(0, -0.9, 0), 40.0],
	["saluta_a", 1.05, Vector3(0.9, -0.6, 4.6), Vector3(0, -0.9, 0), 40.0],
	["saluta_b", 1.3, Vector3(0.9, -0.6, 4.6), Vector3(0, -0.9, 0), 40.0],
	["primo_piano", 1.8, Vector3(0.35, -0.05, 1.5), Vector3(0, -0.15, 0), 40.0],
	["primo_piano_davanti", 2.3, Vector3(0.0, -0.1, 1.3), Vector3(0, -0.2, 0), 45.0],
]

var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var radice := Node3D.new()
	add_child(radice)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.75)
	env.ambient_light_energy = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	radice.add_child(we)
	# piedistallo di prova: cilindro bianco col bordo blu, il piano dove poggiano i tentacoli a y 0
	var marmo := StandardMaterial3D.new()
	marmo.albedo_color = Color(0.9, 0.9, 0.92)
	marmo.roughness = 0.3
	var ped := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 1.3
	c.bottom_radius = 1.45
	c.height = 1.0
	ped.mesh = c
	ped.material_override = marmo
	ped.position = Vector3(0, -0.5, 0)
	radice.add_child(ped)
	var pav := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(20, 0.1, 20)
	pav.mesh = b
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.15, 0.2, 0.28)
	mp.roughness = 0.2
	pav.material_override = mp
	pav.position = Vector3(0, -1.05, 0)
	radice.add_child(pav)
	# lei
	var lei: Node3D = load("res://scripts/spot/jilly_spot.gd").new()
	lei.set(&"model", load("res://assets/models/medusa/medusa.glb"))
	lei.set(&"bell_material", load("res://assets/models/medusa/medusa_campana.tres"))
	lei.set(&"animazione", &"statua")
	radice.add_child(lei)
	for i in 5:
		await get_tree().process_frame
	var ap := lei.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# l'occhio dritto in camera (lo sguardo che segue il giocatore qui non ha un giocatore)
	for m in lei.find_children("SguardoOcchio", "", true, false):
		(m as SkeletonModifier3D).active = false
	var occhio: Vector3 = lei.call(&"get_eye_position")
	print("occhio ", occhio)
	# luci da spettacolo: chiave bianca davanti in alto, fari rosa e viola dai lati, controluce
	for l in [[Vector3(0.5, occhio.y + 3.0, 5.0), Color(1.0, 0.95, 0.9), 2.2, 30.0],
			[Vector3(-4.0, occhio.y + 1.5, 3.0), Color(1.0, 0.35, 0.72), 5.0, 28.0],
			[Vector3(4.0, occhio.y + 1.5, 3.0), Color(0.62, 0.35, 1.0), 5.0, 28.0],
			[Vector3(0.0, occhio.y + 2.5, -4.0), Color(0.75, 0.6, 1.0), 4.0, 30.0]]:
		var s := SpotLight3D.new()
		s.position = l[0]
		s.light_color = l[1]
		s.light_energy = l[2]
		s.spot_angle = l[3]
		s.spot_range = 14.0
		s.shadow_enabled = true
		radice.add_child(s)
		s.look_at(Vector3(0, occhio.y - 0.8, 0), Vector3.UP)
	var cam := Camera3D.new()
	radice.add_child(cam)
	cam.current = true
	cam.near = 0.05
	lei.call(&"saluta", 6.0)
	var t0 := Time.get_ticks_msec()
	var tempo := 0.0
	for s in SCATTI:
		# il tempo dell'animazione (fps fissi: 1/60 per fotogramma)
		while tempo < float(s[1]):
			await get_tree().process_frame
			tempo += 1.0 / 60.0
		var prima := ap.speed_scale
		ap.speed_scale = 0.0
		cam.global_position = occhio + (s[2] as Vector3)
		cam.look_at(occhio + (s[3] as Vector3), Vector3.UP)
		cam.fov = s[4]
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var f := out_dir.path_join(String(s[0]) + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f)
		ap.speed_scale = prima
	print("in ", Time.get_ticks_msec() - t0, " ms")
	get_tree().quit()
