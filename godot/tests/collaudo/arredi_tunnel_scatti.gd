extends Node
## Collaudo 0.3.25 (arredi del tunnel messi con Posa con le sole mesh del tunnel, a9e6f0f4 e 774e9c46): ogni arredo da
## vicino, col renderer vero. Il tunnel da solo (sala_sottomarino.tscn costruito tutto), l'ambiente della sala. Gli
## arredi: i coralli e le loro mensole, l'ancora con le staffe, il salvagente, il forziere con la sua mensola, il palombaro
## con la sua mensola, il salvagente fosforescente, la tartaruga, i pesci e le loro mensole. Per ognuno il muro si trova coi raggi (il più vicino fra 16
## direzioni orizzontali) e si fanno quattro scatti: di fronte a 1,4 m, radente da sinistra e da destra a 0,25 m dal
## muro e 0,7 m di lato, da sotto (0,5 m fuori e 0,45 m sotto). Stampa (AT:) posizione e distanza dal muro.
## Uso: xvfb-run ... --script res://tests/run.gd -- res://tests/collaudo/arredi_tunnel_scatti.gd <cartella> [solo i primi n]

const TUNNEL := "res://scenes/sala/sottomarino/sala_sottomarino.tscn"
var cart := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(cam: Camera3D, nome: String, da: Vector3, verso: Vector3) -> void:
	cam.global_position = da
	cam.look_at(verso, Vector3.UP if absf((verso - da).normalized().y) < 0.95 else Vector3.RIGHT)
	await _frames(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.9)


static func _aabb(n: Node3D) -> AABB:
	var a := AABB()
	var primo := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		a = b if primo else a.merge(b)
		primo = false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var b2 := (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
		a = b2 if primo else a.merge(b2)
	return a


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	var quanti := int(a[2]) if a.size() > 2 else 999
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var we := WorldEnvironment.new()
	var look := LookSala.new()
	we.environment = look.ambiente
	we.camera_attributes = look.attributi_camera
	look.free()
	add_child(we)
	var tun := (load(TUNNEL) as PackedScene).instantiate() as Node3D
	add_child(tun)
	tun.call(&"costruisci")
	await _frames(120)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.02
	add_child(cam)
	cam.make_current()
	# una lampadina sulla camera (le luci del tunnel lì sono deboli): con LAMPADA=0 senza
	if OS.get_environment("LAMPADA") != "0":
		var lamp := OmniLight3D.new()
		lamp.omni_range = 4.0
		lamp.light_energy = 1.2
		lamp.shadow_enabled = true
		cam.add_child(lamp)
		lamp.position = Vector3(0.15, 0.25, 0)
	var arredi: Array[Node3D] = []
	for gruppo in ["Coralli", "Relitto", "SalaPalombaro"]:
		var g := tun.find_child(gruppo, true, false)
		for c in (g.get_children() if g else []):
			if c is Node3D:
				arredi.append(c)
				if String(c.name) == "Ancora":
					for s in (c as Node3D).find_children("Staffa*", "", true, false):
						if s is Node3D:
							arredi.append(s)
	for s in tun.find_children("Staffa*", "Node3D", true, false):
		if not arredi.has(s):
			arredi.append(s)
	for patt in ["salvagente_fosforescente", "tartaruga", "mensola_pesce_*", "pesce_*"]:
		for x in tun.find_children(patt, "Node3D", true, false):
			if not arredi.has(x) and not String(x.name).begins_with("cavo"):
				arredi.append(x)
	print("AT: arredi %d" % arredi.size())
	var space := tun.get_world_3d().direct_space_state
	var k := 0
	for n in arredi:
		if k >= quanti:
			break
		var box := _aabb(n)
		var c := box.get_center()
		# il muro: il raggio orizzontale più corto
		var muro := Vector3.ZERO
		var dist := INF
		for i in 16:
			var d := Vector3(cos(TAU * i / 16.0), 0, sin(TAU * i / 16.0))
			var q := PhysicsRayQueryParameters3D.create(c, c + d * 3.0)
			q.collision_mask = Layers.WORLD
			var h := space.intersect_ray(q)
			if not h.is_empty() and c.distance_to(h.position) < dist:
				dist = c.distance_to(h.position)
				muro = d
		var fuori := -muro if muro != Vector3.ZERO else Vector3.BACK
		var lato := fuori.cross(Vector3.UP).normalized()
		var nome := "%02d_%s_%s" % [k, n.get_parent().name, n.name]
		print("AT: %s in %s, grande %s, muro a %.3f m dal centro verso %s" % [nome, n.global_position.snappedf(0.001), box.size.snappedf(0.01), dist, muro.snappedf(0.01)])
		var r := maxf(box.size.length(), 0.4)
		await _scatto(cam, nome + "_fronte", c + fuori * maxf(1.4, r * 1.5) + Vector3.UP * 0.3, c)
		await _scatto(cam, nome + "_radente_sx", c + fuori * 0.25 + lato * maxf(0.7, r), c - fuori * 0.05)
		await _scatto(cam, nome + "_radente_dx", c + fuori * 0.25 - lato * maxf(0.7, r), c - fuori * 0.05)
		await _scatto(cam, nome + "_sotto", c + fuori * maxf(0.5, r * 0.6) + Vector3.DOWN * maxf(0.45, box.size.y), c)
		k += 1
	print("AT: finito")
	get_tree().quit()
