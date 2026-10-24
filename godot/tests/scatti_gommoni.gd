extends Node
## Scatti interni dei gommoni del tunnel sottomarino (per il collaudo e i controlli della squadra, non per l'utente):
## per ogni attraversamento la vista dalla banchina di partenza, agli occhi del giocatore; per ogni gommone la vista
## dal bordo della banchina; per ogni corda il ravvicinato dell'anello nel muro e quello della maniglia. Con le luci
## del tunnel, senza torcia: si vede se qualcosa è sospeso o staccato e se al buio si legge.
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_gommoni.gd <cartella> [istante del dondolio, s]

var cartella := "user://scatti_gommoni"
var istante := 0.0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	if a.size() > 2:
		istante = float(a[2])
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.009
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	sala.costruisci()
	if sala.get(&"lei") is Node3D:
		(sala.get(&"lei") as Node3D).visible = false
	sala.set_physics_process(false)
	sala.ferma_gommoni(istante)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	for i in 30:
		await get_tree().process_frame
	var scatti := _scatti(sala)
	for nome in scatti:
		var sc: Array = scatti[nome]
		cam.fov = sc[2]
		cam.look_at_from_position(sc[0], sc[1])
		for i in 30:
			await get_tree().process_frame
		var f := cartella.path_join(nome + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.88)
		print("scatto -> ", f)
	get_tree().quit()


## Gli scatti: nome -> [da, verso, campo visivo].
func _scatti(sala: SalaSottomarino) -> Dictionary:
	var out := {}
	var k := 0
	for a in sala.attraversamenti.size():
		var att: Array = sala.attraversamenti[a]
		var n: int = (att[1] as Array).size() - 1
		var gs: Array = sala._gommoni.slice(k, k + n)
		k += n
		var da := 1.0
		for o in sala.ostacoli:
			if absf(float(o["s"]) - float(att[0])) < 0.01:
				da = float(o["lato"])
		var c0: Vector3 = (gs[0]["corpo"] as Node3D).global_position
		var s0: float = sala.proietta(c0)[0]
		var cn: Vector3 = (gs[gs.size() - 1]["corpo"] as Node3D).global_position
		var sn: float = sala.proietta(cn)[0]
		var occhi := sala.punto(s0 - 3.0) + sala.destra(s0 - 3.0) * da * (sala.canale + 0.8)
		occhi.y = sala.piano + 1.6
		var meta := (c0 + cn) * 0.5
		meta.y = sala.acqua + 0.3
		out["a%d_s%d_attraversamento" % [a + 1, int(att[0])]] = [occhi, meta, 75.0]
		# dalla banchina d'arrivo, indietro
		var occhi2 := sala.punto(sn + 3.0) + sala.destra(sn + 3.0) * -da * (sala.canale + 0.8)
		occhi2.y = sala.piano + 1.6
		out["a%d_s%d_dall_arrivo" % [a + 1, int(att[0])]] = [occhi2, meta, 75.0]
		for gi in gs.size():
			var g: Dictionary = gs[gi]
			var corpo: Node3D = g["corpo"]
			var c := corpo.global_position
			var pr: Array = sala.proietta(c)
			var lato := signf(float(pr[1]))
			# dal bordo della banchina più vicina, agli occhi, guardando il gommone
			var bordo := sala.punto(float(pr[0])) + sala.destra(float(pr[0])) * lato * (sala.canale + 0.4)
			bordo.y = sala.piano + 1.6
			out["a%d_g%d_dal_bordo" % [a + 1, gi + 1]] = [bordo, c + Vector3.UP * 0.4, 65.0]
			var ci := 0
			for cd in g["corde"]:
				ci += 1
				var anello: Vector3 = cd["anello"]
				var dentro := (Vector3(c.x, anello.y, c.z) - anello)
				var sa: float = sala.proietta(anello)[0]
				var lungo := sala.direzione(sa)
				dentro = (dentro - lungo * dentro.dot(lungo)).normalized()
				out["a%d_g%d_corda%d_anello" % [a + 1, gi + 1, ci]] = [anello + dentro * 0.45 + Vector3.UP * 0.22 + lungo * 0.15, anello, 50.0]
				var man: Vector3 = corpo.global_transform * (cd["maniglia"] as Vector3)
				var fuori := Vector3(man.x - c.x, 0.0, man.z - c.z).normalized()
				out["a%d_g%d_corda%d_maniglia" % [a + 1, gi + 1, ci]] = [man + fuori * 0.5 + Vector3.UP * 0.35 + fuori.cross(Vector3.UP) * 0.15, man, 50.0]
	return out
