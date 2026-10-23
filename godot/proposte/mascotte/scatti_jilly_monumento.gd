extends Node
## Scatti dal motore di Jilly sul monumento a gradoni dello spot (scenes/spot/sala_spot.tscn, nodo "Jilly"): il primo
## piano dell'inquadratura 6, mentre saluta e sorride (JillySpot.saluta), con le luci della sala dello spot. Le camere
## sono riferite al centro dell'occhio (lei guarda verso +z); più uno scatto largo per vedere i tentacoli sul piano.
## Uso (sotto render.lock, con almeno 13,5 GB liberi):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://proposte/mascotte/scatti_jilly_monumento.gd <cartella>

const SCENA := "res://scenes/spot/sala_spot.tscn"
## nome: [secondi dall'inizio del saluto (-1 = prima), camera rispetto all'occhio, verso dove rispetto all'occhio, campo]
const SCATTI := [
	["ferma_largo", -1.0, Vector3(1.6, -2.4, 6.5), Vector3(0, -2.3, 0), 45.0],
	["primo_piano_alza", 0.5, Vector3(0.45, -0.35, 2.3), Vector3(0, -0.35, 0), 40.0],
	["primo_piano_saluta_a", 1.3, Vector3(0.45, -0.35, 2.3), Vector3(0, -0.35, 0), 40.0],
	["primo_piano_saluta_b", 1.8, Vector3(0.45, -0.35, 2.3), Vector3(0, -0.35, 0), 40.0],
	["primo_piano_davanti", 2.4, Vector3(0.0, -0.2, 1.6), Vector3(0, -0.25, 0), 42.0],
	["saluta_largo", 3.0, Vector3(1.6, -2.4, 6.5), Vector3(0, -2.3, 0), 45.0],
]

var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var g := get_node_or_null(^"/root/Grafica")
	if g:
		g.set(&"salva_su_disco", false)
		g.call(&"applica_preset", "alto")
	var scena := (load(SCENA) as PackedScene).instantiate()
	get_tree().root.add_child(scena)
	var cam := scena.get_node_or_null(^"Camera") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		scena.add_child(cam)
	cam.current = true
	cam.near = 0.05
	var lei := scena.get_node("Jilly") as Node3D
	var ap := lei.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# GI, sonde e acqua si assestano
	for i in 360:
		await get_tree().process_frame
	var occhio: Vector3 = lei.call(&"get_eye_position")
	print("occhio ", occhio, " animazione ", ap.current_animation)
	var tempo := -1.0
	for s in SCATTI:
		if float(s[1]) >= 0.0 and tempo < 0.0:
			lei.call(&"saluta", 3.9)
			tempo = 0.0
		while tempo >= 0.0 and tempo < float(s[1]):
			await get_tree().process_frame
			tempo += 1.0 / 60.0
		var prima := ap.speed_scale
		ap.speed_scale = 0.0
		cam.global_position = occhio + (s[2] as Vector3)
		cam.look_at(occhio + (s[3] as Vector3), Vector3.UP)
		cam.fov = s[4]
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var f := out_dir.path_join(String(s[0]) + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f, " (", ap.current_animation, ")")
		ap.speed_scale = prima
	get_tree().quit()
