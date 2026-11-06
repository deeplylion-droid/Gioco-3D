extends Node
## Scatti ravvicinati delle sei paratie coi bersagli da luna park (ricontrollo di ambienti-1, 0.3.21): per ogni paratia,
## chiusa, la faccia da 1,6 m, gli spigoli in basso e in alto contro i montanti (da davanti, a 45 cm), il piede dei due
## montanti; aperta, la faccia e il bordo di sotto del pannello alzato fra i montanti. Con una luce di servizio sulla
## camera (con le sole lampade da lavoro da vicino si vede poco). Nella sala dell'inseguimento vera.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_paratie_vicino.gd <cartella>

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"

var sala: SalaInseguimento
var cam: Camera3D
var cartella := "/tmp/scatti_paratie_vicino"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.volumetric_fog_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	sala = (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	add_child(sala)
	for i in 1200:
		await get_tree().physics_frame
		if sala.costruita:
			break
	for i in 30:
		await get_tree().physics_frame
	if sala.lei:
		sala.lei.visible = false
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.02
	add_child(cam)
	cam.make_current()
	var l := OmniLight3D.new()
	l.omni_range = 2.5
	l.light_energy = 0.7
	l.shadow_enabled = true
	cam.add_child(l)
	l.position = Vector3(0.05, 0.1, 0)
	var spazio := sala.get_world_3d().direct_space_state
	for stato in ["chiusa", "aperta"]:
		if stato == "aperta":
			for d in sala.paratie:
				d["apre"] = true
				d["aperta"] = 0.999
			sala._muovi_paratie(1.0)
			for i in 10:
				await get_tree().physics_frame
		for d in sala.paratie:
			var pn := d["pannello_nodo"] as Node3D
			var box := _scatola(pn)
			var c := box.get_center()
			var lungo := Vector3.RIGHT if box.size.x > box.size.z else Vector3.BACK
			var avanti := Vector3.BACK if lungo == Vector3.RIGHT else Vector3.RIGHT
			var bers := (d["bersaglio_nodo"] as Node3D).global_position
			if (bers - c).dot(avanti) < 0.0:
				avanti = -avanti
			# il pavimento davanti al pannello
			var davanti := c + avanti * 0.6
			var r := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(davanti, davanti + Vector3.DOWN * 4.0, 0xFFFFFFFF))
			var pav := (r.position as Vector3).y if not r.is_empty() else box.position.y
			var mezzo := box.size.dot(lungo) / 2.0
			var alto := box.end.y
			var nome := "v%d_%s_%s" % [int(d["vasca"]) + 1, "giusta" if bool(d["giusta"]) else "sbagliata", stato]
			await _scatta(nome + "_faccia", c + avanti * 1.6 + Vector3.UP * 0.1, c)
			if stato == "chiusa":
				for s in [-1.0, 1.0]:
					var spigolo := c + lungo * s * mezzo
					var basso := Vector3(spigolo.x, pav + 0.05, spigolo.z)
					await _scatta(nome + "_spigolo_basso_%s" % ("sx" if s < 0 else "dx"), basso + avanti * 0.45 + Vector3.UP * 0.12 - lungo * s * 0.15, basso)
					var su := Vector3(spigolo.x, alto - 0.05, spigolo.z)
					await _scatta(nome + "_spigolo_alto_%s" % ("sx" if s < 0 else "dx"), su + avanti * 0.45 - Vector3.UP * 0.1 - lungo * s * 0.15, su)
					var piede := Vector3(spigolo.x, pav, spigolo.z) + lungo * s * 0.12
					await _scatta(nome + "_piede_montante_%s" % ("sx" if s < 0 else "dx"), piede + avanti * 0.5 + lungo * s * 0.25 + Vector3.UP * 0.25, piede)
			else:
				var fondo := Vector3(c.x, box.position.y, c.z)
				await _scatta(nome + "_bordo_sotto", fondo + avanti * 0.7 - Vector3.UP * 0.35, fondo)
	print("FINE")
	get_tree().quit()


func _scatola(pn: Node3D) -> AABB:
	var box := AABB()
	var primo := true
	for m in [pn] + pn.find_children("*", "MeshInstance3D", true, false):
		if m is MeshInstance3D and (m as MeshInstance3D).mesh:
			var b := (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			box = b if primo else box.merge(b)
			primo = false
	return box


func _scatta(nome: String, da: Vector3, verso: Vector3) -> void:
	cam.global_position = da
	cam.look_at(verso, Vector3.UP)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
	print("SCATTO ", nome)
