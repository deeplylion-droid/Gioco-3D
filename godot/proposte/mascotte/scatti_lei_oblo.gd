extends Node
## Scatti dal motore di lei dietro un oblò (LeiOblo, le pose di tools/blender/medusa_inseguimento.py): un muro con un
## oblò di 0,6 m di raggio (centro a 1,65 m), il vetro, l'acqua buia dietro; la camera del giocatore nel corridoio, a
## 1,6 m dal vetro. Per ogni posa uno scatto in ciclo e due durante il distacco.
## Uso (sotto render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --script res://tests/run.gd -- res://proposte/mascotte/scatti_lei_oblo.gd <cartella> [posa,posa]

const CENTRO := Vector3(0, 1.65, 0)
## il raggio del vetro (RAGGIO=0.22 nell'ambiente per il vetro piccolo della torre)
var RAGGIO := float(OS.get_environment("RAGGIO")) if OS.has_environment("RAGGIO") else 0.6
## dove sta il giocatore (i piedi) per posa
const GIOCATORE := {"schiacciata": Vector3(0.25, 0, 1.6), "sbircia": Vector3(-0.35, 0, 1.6),
	"sbircia_altro": Vector3(0.35, 0, 1.6), "capovolta": Vector3(0.2, 0, 1.5), "occhio": Vector3(0.15, 0, 1.2)}

var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _materiale(c: Color, rugosita := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugosita
	return m


func _scena(radice: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.6, 0.7)
	env.ambient_light_energy = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.06, 0.07)
	env.fog_density = 0.18
	var we := WorldEnvironment.new()
	we.environment = env
	radice.add_child(we)
	# il muro con il foro, la cornice dalla parte del corridoio (+z), il pavimento del corridoio
	var muro := CSGCombiner3D.new()
	radice.add_child(muro)
	var lastra := CSGBox3D.new()
	lastra.size = Vector3(6, 4, 0.3)
	lastra.position = Vector3(0, 2.0, 0.15)
	lastra.material = _materiale(Color(0.32, 0.33, 0.33))
	muro.add_child(lastra)
	var foro := CSGCylinder3D.new()
	foro.radius = RAGGIO
	foro.height = 1.0
	foro.sides = 48
	foro.operation = CSGShape3D.OPERATION_SUBTRACTION
	foro.rotation_degrees = Vector3(90, 0, 0)
	foro.position = CENTRO
	muro.add_child(foro)
	var cornice := CSGTorus3D.new()
	cornice.inner_radius = RAGGIO - 0.02
	cornice.outer_radius = RAGGIO + 0.12
	cornice.sides = 48
	cornice.rotation_degrees = Vector3(90, 0, 0)
	cornice.position = CENTRO + Vector3(0, 0, 0.32)
	cornice.material = _materiale(Color(0.45, 0.42, 0.36), 0.4)
	radice.add_child(cornice)
	var pav := CSGBox3D.new()
	pav.size = Vector3(6, 0.2, 4)
	pav.position = Vector3(0, -0.1, 2.3)
	pav.material = _materiale(Color(0.2, 0.2, 0.2))
	radice.add_child(pav)
	var vetro := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(RAGGIO * 2.0, RAGGIO * 2.0)
	vetro.mesh = q
	var mv := StandardMaterial3D.new()
	mv.albedo_color = Color(0.6, 0.75, 0.75, 0.12)
	mv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mv.roughness = 0.05
	mv.metallic_specular = 0.9
	vetro.material_override = mv
	vetro.position = CENTRO + Vector3(0, 0, 0.02)
	radice.add_child(vetro)
	# la luce del corridoio, fioca, da sopra
	var lampada := OmniLight3D.new()
	lampada.light_color = Color(1.0, 0.85, 0.65)
	lampada.light_energy = 1.2
	lampada.omni_range = 5.0
	lampada.position = Vector3(0.8, 3.2, 1.8)
	radice.add_child(lampada)


func _scatta(nome: String) -> void:
	for k in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(nome + ".jpg"), 0.9)


func _run() -> void:
	Game.pause_on_focus_loss = false
	var solo: PackedStringArray = OS.get_cmdline_user_args()[2].split(",") if OS.get_cmdline_user_args().size() > 2 else PackedStringArray()
	var radice := Node3D.new()
	add_child(radice)
	_scena(radice)
	var giocatore := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	radice.add_child(giocatore)
	giocatore.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.player = giocatore
	var lo := LeiOblo.new()
	radice.add_child(lo)
	for i in 5:
		await get_tree().process_frame
	for posa: String in LeiOblo.POSE:
		if not solo.is_empty() and not posa in solo:
			continue
		giocatore.global_position = GIOCATORE[posa]
		var occhi: Vector3 = GIOCATORE[posa] + Vector3.UP * 1.6
		giocatore.camera.current = true
		giocatore.camera.look_at_from_position(occhi, CENTRO, Vector3.UP)
		print("CAMERA ", giocatore.camera.global_position)
		lo.mostra(CENTRO, Vector3.BACK, posa)
		var ap := lo.lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
		# un secondo e mezzo in ciclo: la testa e l'occhio si girano verso il giocatore
		for i in (120 if posa == "occhio" else 45):
			await get_tree().physics_frame
		await _scatta("%s_1_ciclo" % posa)
		# di lato, per vedere che niente passa il vetro
		var cam2 := Camera3D.new()
		radice.add_child(cam2)
		cam2.global_position = CENTRO + Vector3(3.2, 0.4, -1.6)
		cam2.look_at(CENTRO + Vector3(0, -0.6, -1.0), Vector3.UP)
		cam2.current = true
		await _scatta("%s_0_lato" % posa)
		cam2.queue_free()
		giocatore.camera.current = true
		lo.stacca()
		var dur := ap.get_animation(StringName("inseguimento/oblo_%s_stacca" % posa)).length
		for i in int(dur * 0.4 * 30):
			await get_tree().physics_frame
		await _scatta("%s_2_stacca" % posa)
		for i in int(dur * 0.35 * 30):
			await get_tree().physics_frame
		await _scatta("%s_3_stacca" % posa)
		await lo.sparita
		print("SCATTI ", posa)
	get_tree().quit(0)
