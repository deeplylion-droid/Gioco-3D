extends Node
## Collaudo finale 0.3.21 (mascotte): i bersagli da luna park delle 6 paratie delle condotte da vicino, chiuse e aperte
## (apri_paratia su tutte, poi si aspetta che siano su). Per ogni paratia: il bersaglio di fronte a 1 m, l'anello di
## led di sbieco, i due montanti (i lati del pannello) dall'alto in basso e il piede del pannello. La torre con le
## condotte, ambiente della sala, luci del blackout, lei nascosta; una luce di servizio sulla camera (per vedere la forma
## da vicino dove la sala è buia).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/collaudo_0321_bersagli.gd <cartella>

var cartella := "/tmp/bersagli"
var cam: Camera3D


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _f(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(da: Vector3, verso: Vector3, nome: String) -> void:
	cam.global_position = da
	cam.look_at(verso, Vector3.UP)
	await _f(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.88)


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	await _f(30)
	var ins := torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	ins.comparsa = PackedFloat32Array([9999.0, 9999.0, 9999.0])
	if ins.lei:
		ins.lei.visible = false
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.03
	add_child(cam)
	cam.make_current()
	var luce := OmniLight3D.new()
	luce.light_energy = 0.6
	luce.omni_range = 4.0
	cam.add_child(luce)
	for stato in ["chiuse", "aperte"]:
		if stato == "aperte":
			for k in ins.paratie.size():
				ins.apri_paratia(k)
			await _f(60 * 12)
		for k in ins.paratie.size():
			var d: Dictionary = ins.paratie[k]
			var bk := SalaInseguimento.b(d["bersaglio"])
			var pan := d["pannello_nodo"] as Node3D
			if stato == "aperte" and pan:
				bk += pan.global_position - (d["chiuso"] as Vector3)
			# (come scatti_bersagli_g2.gd: "verso" guarda dentro il muro, il giocatore sta dall'altra parte)
			var n := -SalaInseguimento.b(d["verso"]).normalized()
			var lato := n.cross(Vector3.UP).normalized()
			var bb := AABB()
			var primo := true
			if pan:
				for mi in pan.find_children("*", "MeshInstance3D", true, false):
					var x := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
					bb = x if primo else bb.merge(x)
					primo = false
			var nome := "%s_p%d_v%d_%s" % [stato, k, int(d["vasca"]) + 1, "giusta" if bool(d["giusta"]) else "sbagliata"]
			print("%s: bersaglio %s, pannello %s (aperta %.2f)" % [nome, bk.snapped(Vector3.ONE * 0.01), bb.size.snapped(Vector3.ONE * 0.01), float(d["aperta"])])
			await _scatto(bk + n * 1.0, bk, nome + "_1_bersaglio")
			await _scatto(bk + n * 0.6 + lato * 0.45 + Vector3.UP * 0.2, bk, nome + "_2_anello_di_sbieco")
			# i montanti: i due lati del pannello, a metà e in basso
			var largo := absf(bb.size.dot(lato.abs())) * 0.5 if not primo else 0.8
			for s: float in [-1.0, 1.0]:
				var bordo := bk + lato * s * (largo + 0.05)
				await _scatto(bordo + n * 0.9 + lato * s * 0.4, bordo, nome + "_3_montante_%s" % ("a" if s < 0 else "b"))
				var basso := Vector3(bordo.x, bb.position.y + 0.2 if not primo else bk.y - 1.0, bordo.z)
				await _scatto(basso + n * 0.9 + lato * s * 0.3 + Vector3.UP * 0.3, basso, nome + "_4_piede_%s" % ("a" if s < 0 else "b"))
	print("BERSAGLI FINITI")
	get_tree().quit()
