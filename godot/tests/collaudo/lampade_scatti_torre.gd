extends Node
## Collaudo 0.3.23 (giro corto della torre su f2f810a2): le 7 lampade d'emergenza rosse viste col renderer vero. La torre
## da sola come in vista_fessure_torre.gd (sala_torre.tscn con l'ambiente della sala e le luci del blackout: la sala
## intera con Vulkan non ci sta in memoria). Le posizioni (LS:) si confrontano con quelle delle strade vere
## (lampade_torre_giro.gd senza grafica). Per ogni lampada: di fronte a 1,6 m (30 cm più in basso), radente da destra e
## da sinistra a 0,6 m lungo il muro; più due viste larghe (fov 100) dall'altezza degli occhi a 3 m.
## Uso: xvfb-run ... --script res://tests/run.gd -- res://tests/collaudo/lampade_scatti_torre.gd <cartella>

const PLAYER := "res://scenes/player/player.tscn"
var cart := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	await _frames(12)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.9)


## Il verso del muro (dal centro della lampada verso il muro): il lato sottile della scatola col muro più vicino.
func _verso_muro(corpo: MeshInstance3D) -> Vector3:
	var bx := (corpo.mesh as BoxMesh).size
	var v := (corpo.global_basis * (Vector3.RIGHT if bx.x < bx.z else Vector3.BACK)).normalized()
	var space := corpo.get_world_3d().direct_space_state
	var p := corpo.global_position
	var meglio := v
	var dist := INF
	for d in [v, -v]:
		var q := PhysicsRayQueryParameters3D.create(p, p + d * 0.6)
		var h := space.intersect_ray(q)
		if not h.is_empty() and p.distance_to(h.position) < dist:
			dist = p.distance_to(h.position)
			meglio = d
	return meglio


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	cart = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as Node3D
	add_child(torre)
	for i in 600:
		if bool(torre.get(&"costruita")):
			break
		await get_tree().process_frame
	await _frames(240)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(5)
	var cam := Camera3D.new()
	cam.attributes = p.camera.attributes
	cam.near = 0.02
	add_child(cam)
	p.global_position = Vector3(0, -50, 0)
	p.set_physics_process(false)
	cam.make_current()
	var lamp: Array = []
	var luci := torre.get_node_or_null(^"Luci")
	for c in (luci.get_children() if luci else []):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			lamp.append(c)
	print("LS: torre costruita %s, lampade %d" % [torre.get(&"costruita"), lamp.size()])
	for k in lamp.size():
		var l := lamp[k] as MeshInstance3D
		var pos := l.global_position
		var muro := _verso_muro(l)
		var lungo := muro.cross(Vector3.UP).normalized()
		print("LS: lampada %d in %s, muro verso %s, scatola %s" % [k, pos.snappedf(0.0001), muro.snappedf(0.01), (l.mesh as BoxMesh).size])
		cam.fov = 60.0
		cam.global_position = pos - muro * 1.6 + Vector3.DOWN * 0.3
		cam.look_at(pos, Vector3.UP)
		await _scatto("L%d_fronte" % k)
		cam.global_position = pos - muro * 0.3 + lungo * 0.6
		cam.look_at(pos, Vector3.UP)
		await _scatto("L%d_radente_a" % k)
		cam.global_position = pos - muro * 0.3 - lungo * 0.6 + Vector3.DOWN * 0.15
		cam.look_at(pos, Vector3.UP)
		await _scatto("L%d_radente_b" % k)
		cam.fov = 100.0
		cam.global_position = pos - muro * 3.0 + Vector3.DOWN * 0.5
		cam.look_at(pos, Vector3.UP)
		await _scatto("L%d_largo" % k)
	print("LS: finito")
	get_tree().quit()
