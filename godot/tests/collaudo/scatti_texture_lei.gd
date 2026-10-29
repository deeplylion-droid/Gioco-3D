extends Node
## Confronto delle texture di lei prima e dopo la compressione (lavoro/controllo-texture c7a4c5a3, 29 ottobre: le 14 texture
## estratte della medusa uscivano Lossless e senza mipmap fino alla 0.3.15). Lei sola, in pose fisse del gioco, con le
## camere da vicino dove la si vede di più: all'oblò (oblo_sbircia, 0,9 m), nella presa (presa, 0,8 m dall'occhio), nel
## tunnel quando insegue (insegue_aperta, 2,6 m), più tre dettagli (capelli, pelle del petto, tentacoli). Luce: buio
## blu della sala e la torcia sulla camera, uguali nei due giri. Si lancia due volte, una con le texture come prima
## e una come dopo, nella stessa cartella con un prefisso diverso.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scatti_texture_lei.gd <cartella> <prima|dopo>

## [nome, animazione, punto dell'animazione (0..1), osso guardato, distanza dalla camera, alzata della camera, di lato]
const SCATTI := [
	["oblo", &"inseguimento/oblo_sbircia", 0.5, "occhio", 0.9, 0.05, 0.0],
	["presa", &"inseguimento/presa", 0.6, "occhio", 0.8, 0.1, 0.1],
	["tunnel", &"inseguimento/insegue_aperta", 0.5, "testa", 2.6, 0.3, 0.0],
	["capelli", &"inseguimento/insegue_aperta", 0.5, "testa", 0.55, 0.15, 0.45],
	["pelle", &"inseguimento/insegue_aperta", 0.5, "petto", 0.6, 0.0, 0.2],
	["tentacoli", &"inseguimento/insegue_aperta", 0.5, "tentacolo_03_04", 0.7, 0.0, 0.3],
]


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella: String = a[1]
	var giro: String = a[2]
	DirAccess.make_dir_recursive_absolute(cartella)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.01, 0.02, 0.035)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.25, 0.35, 0.5)
	env.environment.ambient_light_energy = 0.4
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	add_child(env)
	var sole := DirectionalLight3D.new()
	sole.light_energy = 0.35
	sole.light_color = Color(0.6, 0.75, 1.0)
	sole.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sole)
	var lei := MedusaAffacciata.new()
	lei.model = load("res://assets/models/medusa/medusa.glb")
	lei.animazioni_inseguimento = true
	add_child(lei)
	await _frames(10)
	lei.process_mode = Node.PROCESS_MODE_DISABLED     # (la posa la decide lo scatto)
	var ap := lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	ap.process_mode = Node.PROCESS_MODE_ALWAYS
	var sk := lei.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var cam := Camera3D.new()
	cam.near = 0.02
	cam.fov = 60.0
	add_child(cam)
	cam.current = true
	var torcia := SpotLight3D.new()
	torcia.spot_range = 15.0
	torcia.spot_angle = 30.0
	torcia.light_energy = 3.0
	torcia.shadow_enabled = true
	cam.add_child(torcia)
	torcia.position = Vector3(0.15, -0.1, 0)
	for s in SCATTI:
		ap.play(s[1])
		ap.seek(ap.current_animation_length * float(s[2]), true)
		ap.pause()
		await _frames(3)
		var osso := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(s[3])).origin
		var testa := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("testa")).origin
		var occhio := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("occhio")).origin
		var avanti := Vector3(occhio.x - testa.x, 0, occhio.z - testa.z).normalized()
		if avanti.length() < 0.5:
			avanti = Vector3.BACK
		var lato := avanti.cross(Vector3.UP).normalized()
		cam.global_position = osso + avanti * float(s[4]) + Vector3.UP * float(s[5]) + lato * float(s[6])
		cam.look_at(osso, Vector3.UP)
		await _frames(30)
		await RenderingServer.frame_post_draw
		var f := cartella.path_join("%s_%s.png" % [s[0], giro])
		get_viewport().get_texture().get_image().save_png(f)
		print("SCATTO ", f)
	get_tree().quit()
