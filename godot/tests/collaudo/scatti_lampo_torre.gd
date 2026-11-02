extends Node
## Scatti del lampo della balconata nella torre (SalaTorre.lampo): i bambini si vedono per un istante, fermi come statue.
## Dopo il bambino col cubo animato meglio nel corridoio del fiume (scelta A dell'utente del 1° novembre) si controlla
## che qui restino immobili come prima: tre scatti durante il lampo, e per ogni bambino l'animazione e quanto si
## muovono le ossa fra il primo e l'ultimo scatto. La torre da sola, al buio, con l'ambiente della sala.
## Uso (sotto flock /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_lampo_torre.gd <cartella>

const TORRE := "res://scenes/sala/torre/sala_torre.tscn"

var out_dir := "user://scatti_lampo_torre"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var scena := Node3D.new()
	scena.name = "ProvaTorre"
	var we := WorldEnvironment.new()
	we.environment = load("res://addons/grafica/sala/ambiente_sala.tres")
	we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	scena.add_child(we)
	var torre := (load(TORRE) as PackedScene).instantiate() as SalaTorre
	scena.add_child(torre)
	var cam := Camera3D.new()
	cam.fov = 75.0
	scena.add_child(cam)
	get_tree().root.add_child(scena)
	get_tree().current_scene = scena
	await _frames(90)
	var bambini: Array = torre.get(&"_bambini")
	print("bambini della balconata: ", bambini.size())
	if bambini.is_empty():
		get_tree().quit(1)
		return
	var centro := Vector3.ZERO
	for bimbo: Node3D in bambini:
		centro += bimbo.global_position
	centro /= bambini.size()
	# dagli occhi di chi arriva davanti alla balconata (dove guardano i bambini), a 4 m
	var avanti := (bambini[0] as Node3D).global_basis.z
	avanti.y = 0.0
	var occhio := centro + avanti.normalized() * 4.0 + Vector3.UP * 1.6
	cam.look_at_from_position(occhio, centro + Vector3.UP * 0.7, Vector3.UP)
	cam.current = true
	await _frames(10)
	var pose := []
	torre.lampo()
	for k in 3:
		await get_tree().create_timer([0.05, 0.16, 0.12][k], false).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out_dir.path_join("lampo_%d.jpg" % k), 0.9)
		var p := []
		for bimbo in bambini:
			if not is_instance_valid(bimbo):
				continue
			var sk := (bimbo as Node).find_children("*", "Skeleton3D", true, false)
			var ap := (bimbo as Node).find_child("AnimationPlayer", true, false) as AnimationPlayer
			var ossa := []
			for s: Skeleton3D in sk:
				if not (s.get_parent() as Node3D).is_visible_in_tree():
					continue
				for o in s.get_bone_count():
					ossa.append(s.global_transform * s.get_bone_global_pose(o).origin)
			p.append([String((bimbo as Node).name), ap.current_animation if ap else "-", ap.is_playing() if ap else false, ossa])
		pose.append(p)
	for i in pose[0].size():
		var a: Array = pose[0][i]
		var mosso := 0.0
		if i < pose[2].size():
			var z: Array = pose[2][i]
			for j in mini(a[3].size(), z[3].size()):
				mosso = maxf(mosso, (a[3][j] as Vector3).distance_to(z[3][j]))
		print("%s: animazione '%s' (in corso: %s), le ossa si muovono di %.1f mm durante il lampo" % [a[0], a[1], a[2], mosso * 1000.0])
	print("FINE")
	get_tree().quit(0)
