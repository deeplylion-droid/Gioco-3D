extends Node
## Ricontrollo dell'agnellino della scala di C2 (0.3.21, "agnellini animati come il bambino col cubo"), col giocatore
## vero e il blackout, in cima alla scala come scatti_agnellino_buco.gd:
## - fermo: 4 scatti in 2 s dagli occhi del giocatore (deve respirare, la testa viva) e i ravvicinati dei piedi da
##   davanti, di lato e da dietro, a 15 cm da terra, con la distanza delle ossa dei piedi e delle punte dal pavimento
##   (PIEDI:);
## - scappa: ogni fotogramma per 1,2 s (primo passo, girata di scatto) e, per tutta la corsa fino al buco, la quota dei
##   piedi sul pavimento a ogni fotogramma (CORSA: la più bassa e la più alta, quando tocca terra).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 30 --script res://tests/run.gd -- res://tests/collaudo/ricontrollo_agnellino_scala.gd <cartella>

const SCENA := "res://tests/scene/tappa7_gioco_agnellino.tscn"
const PUNTO := Vector3(44.2, 9.05, 0.5)
const OSSA := ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]

var p: Player
var tec: Node3D
var ag: AgnellinoScala
var cartella := "/tmp/claude-0/ric_agnellino"
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		cartella = args[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	get_tree().change_scene_to_file(SCENA)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	get_tree().paused = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for n in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if n is LuceEmergenza and int(n.get(&"modalita")) in [1, 2]:
			n.set(&"modalita", 0)
	p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	tec = get_tree().current_scene.get_node("Tecnici")
	ag = tec.get_node("AgnellinoScala") as AgnellinoScala
	p.teleport(tec.to_global(PUNTO) + Vector3(0, 0.05, 0), 0.0, 0.0)
	for i in 12:
		await get_tree().physics_frame
	GameState.luci_cambiate.emit(GameState.luci)
	ag.compari()
	var b := ag.bambino
	# fermo: non scappa finché non lo si lascia (lo si guarda, ma il tempo per vederlo è lunghissimo)
	var tempo: float = b.tempo_per_vederlo
	b.tempo_per_vederlo = 9999.0
	for i in 45:
		_guarda(b.punto_testa())
		await get_tree().physics_frame
	for k in 4:
		_guarda(b.punto_testa())
		await _salva("1_fermo_%d" % k)
		for i in 15:
			_guarda(b.punto_testa())
			await get_tree().physics_frame
	# i piedi da vicino (il giocatore resta dov'è: non scappa)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.02
	get_tree().current_scene.add_child(cam)
	var c := _piedi(b)
	print("PIEDI: fermo %s" % _quote(b))
	var avanti := -b.global_basis.z
	avanti.y = 0.0
	avanti = avanti.normalized()
	var lato := avanti.cross(Vector3.UP)
	for v in [["davanti", avanti], ["lato", lato], ["dietro", -avanti], ["altro_lato", -lato]]:
		var dir: Vector3 = v[1]
		cam.global_position = c + dir * 0.7 + Vector3.UP * 0.12
		cam.look_at(c + Vector3.UP * 0.04)
		cam.make_current()
		await _salva("2_piedi_%s" % v[0])
	p.camera.make_current()
	# scappa: ogni fotogramma per 1,2 s, e la quota dei piedi per tutta la corsa
	b.tempo_per_vederlo = tempo
	var da := -1
	var basso := INF
	var alto := -INF
	var n := 0
	for i in 600:
		if not is_instance_valid(b) or not b.visible:
			break
		_guarda(b.punto_testa())
		if b.modalita == Bambino.Modalita.SCAPPA:
			if da < 0:
				da = i
			if i - da < 36:
				await _salva("3_scappa_%02d" % (i - da))
			# la quota del piede più basso (quello che tocca terra), solo sul pavimento in piano
			var q := _quote_min(b)
			if OS.has_environment("OGNI_FOTOGRAMMA"):
				print("CORSA: %d quota %.3f, in %s, girato in avanti %.0f gradi" % [i - da, q, str(tec.to_local(b.global_position).snapped(Vector3.ONE * 0.01)), rad_to_deg(b.rotation.x)])
			if q != INF:
				basso = minf(basso, q)
				alto = maxf(alto, q)
				n += 1
		await get_tree().physics_frame
	print("CORSA: piede più basso sul pavimento fra %.3f e %.3f m (%d fotogrammi)" % [basso, alto, n])
	print("FINE")
	get_tree().quit()


func _guarda(dove: Vector3) -> void:
	var d := dove - p.get_eye_position()
	p.set_look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _salva(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.9)


func _skel(b: Node3D) -> Skeleton3D:
	for s in b.find_children("*", "Skeleton3D", true, false):
		if (s as Node3D).is_visible_in_tree():
			return s as Skeleton3D
	return null


func _ossa(b: Node3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var sk := _skel(b)
	if sk == null:
		return out
	for nome in OSSA:
		var i := sk.find_bone(nome)
		if i >= 0:
			out.append(sk.global_transform * sk.get_bone_global_pose(i).origin)
	return out


func _piedi(b: Node3D) -> Vector3:
	var c := Vector3.ZERO
	var o := _ossa(b)
	for v in o:
		c += v / o.size()
	return c


## La distanza di ogni osso dei piedi dal pavimento sotto (raggio dall'alto, senza il bambino).
func _quote(b: Node3D) -> String:
	var out := []
	var o := _ossa(b)
	for k in o.size():
		out.append("%s %.3f" % [OSSA[k], _sopra(o[k])])
	return ", ".join(out)


func _quote_min(b: Node3D) -> float:
	var m := INF
	for v in _ossa(b):
		m = minf(m, _sopra(v))
	return m


func _sopra(v: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(v + Vector3.UP * 0.6, v + Vector3.DOWN * 1.0)
	q.exclude = [p.get_rid()]
	var r := get_viewport().find_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or (r.normal as Vector3).y < 0.9:
		return INF
	return v.y - (r.position as Vector3).y
