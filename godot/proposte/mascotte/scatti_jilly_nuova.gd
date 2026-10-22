extends Node
## Scatti dal motore della targa e dell'insegna di Jilly da nuove (lo spot della crociera,
## assets/models/mascotte/jilly_nuova/, da assets_src/mascotte/jilly_gioco.py nuova), accanto a quelle
## invecchiate del gioco: su una parete di piastrelle chiare, luce da sala accesa.
## Uso (sotto render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://proposte/mascotte/scatti_jilly_nuova.gd <cartella>

const VECCHIA := "res://assets/models/mascotte/jilly/"
const NUOVA := "res://assets/models/mascotte/jilly_nuova/"
## nome: [da dove, verso dove, campo visivo]
const SCATTI := {
	"insegne": [Vector3(0.0, 1.9, 4.6), Vector3(0.0, 1.9, 0.0), 50.0],
	"insegna_nuova": [Vector3(1.25, 1.9, 2.3), Vector3(1.25, 1.9, 0.0), 50.0],
	"targhe": [Vector3(0.0, 1.0, 1.7), Vector3(0.0, 1.0, 0.0), 45.0],
	"targa_nuova_luce": [Vector3(0.75, 1.0, 0.9), Vector3(0.48, 1.0, 0.0), 40.0],
}

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
	env.background_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	radice.add_child(we)
	# parete e pavimento
	var piastrelle := StandardMaterial3D.new()
	piastrelle.albedo_color = Color(0.82, 0.86, 0.88)
	piastrelle.roughness = 0.35
	for d in [[Vector3(0, 2.0, -0.05), Vector3(6, 4, 0.1)], [Vector3(0, -0.05, 2.0), Vector3(6, 0.1, 4)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = d[1]
		m.mesh = b
		m.material_override = piastrelle
		m.position = d[0]
		radice.add_child(m)
	# luce da sala accesa: una plafoniera calda dall'alto davanti e una fredda di riempimento
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-38, 18, 0)
	sole.light_energy = 1.4
	sole.light_color = Color(1.0, 0.95, 0.88)
	sole.shadow_enabled = true
	radice.add_child(sole)
	var riempi := OmniLight3D.new()
	riempi.position = Vector3(-1.5, 2.5, 3.0)
	riempi.omni_range = 9.0
	riempi.light_energy = 1.2
	riempi.light_color = Color(0.8, 0.88, 1.0)
	radice.add_child(riempi)
	# insegne in alto (a sinistra la vecchia, a destra la nuova), targhe in basso
	_metti(radice, VECCHIA + "insegna.glb", Vector3(-1.25, 1.9, 0.0), true)
	_metti(radice, NUOVA + "insegna.glb", Vector3(1.25, 1.9, 0.0), true)
	_metti(radice, VECCHIA + "targa.glb", Vector3(-0.48, 1.0, 0.0), false)
	_metti(radice, NUOVA + "targa.glb", Vector3(0.48, 1.0, 0.0), false)
	var cam := Camera3D.new()
	radice.add_child(cam)
	cam.current = true
	for nome in SCATTI:
		var s: Array = SCATTI[nome]
		cam.global_position = s[0]
		cam.look_at(s[1], Vector3.UP)
		cam.fov = s[2]
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var f := out_dir.path_join(nome + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f)
	get_tree().quit()


## Il modello col retro sulla parete (il davanti guarda verso +Z); le lampade dell'insegna accese.
func _metti(radice: Node3D, percorso: String, dove: Vector3, lampade: bool) -> void:
	var n := (load(percorso) as PackedScene).instantiate() as Node3D
	radice.add_child(n)
	n.position = dove
	# l'insegna sta 12 cm davanti al muro sulle staffe, la targa è avvitata a filo
	if lampade:
		for nome in ["luce_sx", "luce_dx"]:
			var e := n.find_child(nome, true, false) as Node3D
			if e:
				var l := SpotLight3D.new()
				l.light_color = Color(1.0, 0.85, 0.62)
				l.light_energy = 3.0
				l.spot_range = 2.0
				l.spot_angle = 50.0
				e.add_child(l)
				l.look_at(e.global_position + Vector3(0, -1.0, -0.6), Vector3.UP)
