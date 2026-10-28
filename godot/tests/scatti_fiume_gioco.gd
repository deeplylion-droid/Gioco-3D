extends Node
## Scatti di controllo del fiume lento del gioco (scenes/risalita/fiume.tscn), da solo con una luce
## d'ambiente come quella della proposta (nel gioco la dà la sala). Più scatti per processo.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1600x900 --script res://tests/run.gd \
##        -- res://tests/scatti_fiume_gioco.gd <cartella> [camere separate da virgole]
## I file: fiume_arrivo_<camera>.jpg; con SCATTI_GIRATE=1 le tre paratie sono girate (fiume_girate_<camera>.jpg).

const F := preload("res://scripts/risalita/fiume_gioco.gd")


static func camere() -> Dictionary:
	var d := {
		"piazza": [Vector3(F.INGRESSO_X, 1.7, F.Z0 + 1.0), Vector3(-3.6, 0.6, -3.6)],
		"imbarco": [Vector3(-2.3, 0.6, -2.3), Vector3(0.0, 0.9, -13.0)],
		"bivio1": [F.anello(62.0) + Vector3(0, 0.6, 0), F.anello(90.0) + Vector3(0, 1.6, 0)],
		"ramo": [F.anello(115.0) + Vector3(0, 0.6, 0), F.anello(150.0) + Vector3(0, 1.2, 0)],
		"bivio3": [F.anello(238.0) + Vector3(0, 0.6, 0), F.anello(229.0, F.R - 2.2) + Vector3(0, 1.8, 0)],
		"approdo": [Vector3(-29.6, 0.6, 0.0), Vector3(-40.0, 0.8, 0.0)],
		"alto": [Vector3(-6.0, 70.0, 0.1), Vector3(-6.0, 0.0, 0.0)],
		# lo scivolo in fondo al ramo sbagliato 2 (scelta B): dalla ciambella e dalla banchina
		"scivolo_ciambella": [Vector3(0.0, 0.75, 11.0), Vector3(0.0, 0.0, 2.0)],
		# (prima la camera era a x 3,0, dentro la faccia di un pannello di roccia: ora sulla banchina davanti)
		"scivolo_banchina": [Vector3(1.95, 1.6, 12.0), Vector3(0.0, 0.2, 5.0)],
		# le tre paratie dalla barca, poco prima di arrivarci
		"paratia1": [F.anello(45.0) + Vector3(0, 0.6, 0), F.anello(55.0) + Vector3(0, 1.0, 0)],
		"paratia2": [F.anello(135.0) + Vector3(0, 0.6, 0), F.anello(145.0) + Vector3(0, 1.0, 0)],
		"paratia3": [F.anello(222.0) + Vector3(0, 0.6, 0), F.anello(232.0) + Vector3(0, 1.0, 0)],
		# dalla ciambella, la sponda interna prima del bivio 3: il buco nella roccia prima della colonna (chiuso, riscontro
		# dell'utente sulla v0.3.14) e quello al disco (lasciato com'è)
		"sponda_colonna": [F.anello(214.0) + Vector3(0, 0.6, 0), F.anello(224.4, 21.0) + Vector3(0, 1.4, 0)],
		"sponda_colonna_vicino": [F.anello(220.0) + Vector3(0, 0.6, 0), F.anello(225.0, 21.0) + Vector3(0, 1.4, 0)],
		"sponda_disco3": [F.anello(230.0) + Vector3(0, 0.6, 0), F.anello(237.0, 20.5) + Vector3(0, 1.4, 0)],
		# da vicino, per il collaudo: la pila di ciambelle, il cartello dei tuffi, la catena di una lampada del capannone
		# col suo attacco, il disco e il collare della paratia 1, il portale del cartello d'uscita 1Sx
		"catena": [Vector3(-3.0, 6.0, -5.6), Vector3(-4.0, 6.42, -6.6)],
		"collare1": [Vector3(22.1, 2.9, -14.4), Vector3(21.49, 2.75, -14.96)],
		"disco1": [Vector3(22.2, 2.1, -14.3), Vector3(21.42, 2.0, -15.0)],
		"portale1": [Vector3(24.0, 0.6, 7.5), Vector3(24.0, 1.2, 2.7)],
		"pila_ciambelle": [Vector3(-2.7, 1.6, -7.7), Vector3(-4.6, 0.4, -9.2)],
		"cartello_tuffi": [Vector3(-2.7, 1.7, -5.3), Vector3(-4.2, 1.6, -6.0)],
		# dagli occhi del giocatore (1,6 m): la capanna tiki (da lontano e dal punto più vicino dove si arriva, a
		# 1,9 m dal centro) e le due porte, attraverso il vano e da vicino su uno stipite
		"tiki": [Vector3(-11.0, 1.6, -2.5), Vector3(-14.0, 1.2, -6.0)],
		"tiki_vicino": [Vector3(-13.15, 1.6, -4.3), Vector3(-14.0, 1.3, -6.0)],
		"porta_ingresso": [Vector3(F.INGRESSO_X, 1.6, F.Z0 + 2.5), Vector3(F.INGRESSO_X, 1.4, F.Z0 - 2.0)],
		"stipite_ingresso": [Vector3(F.INGRESSO_X + 0.4, 1.75, F.Z0 + 1.1), Vector3(F.INGRESSO_X - 0.66, 1.5, F.Z0)],
		"porta_approdo": [Vector3(F.X0 + 2.5, 1.6, F.APPRODO.y), Vector3(F.X0 - 2.0, 1.4, F.APPRODO.y)],
		# il capo di sotto della catena nell'occhiello della lampada del capannone (una dritta e una storta)
		"catena_lampada": [Vector3(-3.6, 4.45, -6.25), Vector3(-4.0, 4.6, -6.6)],
		"catena_lampada_storta": [Vector3(13.6, 4.45, -16.25), Vector3(14.0, 4.6, -16.6)],
		# di lato, all'altezza dell'aggancio fra la catenella e il cappello della lampada (prima e dopo, 23 ottobre)
		"gancio_lampada": [Vector3(-3.75, 4.5, -6.3), Vector3(-4.0, 4.5, -6.6)],
		"gancio_lampada_fronte": [Vector3(-4.0, 4.5, -6.22), Vector3(-4.0, 4.5, -6.6)],
		"gancio_lampada_storta": [Vector3(13.75, 4.5, -16.3), Vector3(14.0, 4.5, -16.6)],
	}
	return d


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var cam_tutte := camere()
	var lista: PackedStringArray = a[2].split(",") if a.size() > 2 else PackedStringArray(cam_tutte.keys())
	DirAccess.make_dir_recursive_absolute(out)
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.2, 0.18, 0.17)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.1
	e.ssr_enabled = true
	e.ssao_enabled = true
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.025
	we.environment = e
	get_tree().root.add_child(we)
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(f)
	var girate := OS.get_environment("SCATTI_GIRATE") == "1"
	if girate:
		await get_tree().process_frame
		for pf in f.find_children("*", "ParatiaFiume", true, false):
			(pf as ParatiaFiume).gira()
		for i in 240:
			await get_tree().physics_frame
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 200.0
	get_tree().root.add_child(cam)
	cam.make_current()
	# "gabbie": tutte le lampade a gabbia (la stessa del portone), da vicino dai due lati del loro retro, per vedere che
	# poggiano sulla roccia o sul muro (controllo con la distanza vera, 22 ottobre notte)
	if lista.has("gabbie"):
		lista.remove_at(lista.find("gabbie"))
		var k := 0
		for g in f.find_children("globo", "MeshInstance3D", true, false):
			var l := (g as Node3D).get_parent() as Node3D
			while l.get_parent() != f and l.get_parent() != null:
				l = l.get_parent() as Node3D
			var b := AABB()
			var primo := true
			for mi in l.find_children("*", "MeshInstance3D", true, false):
				var bb := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				b = bb if primo else b.merge(bb)
				primo = false
			var c := b.get_center()
			var avanti := (l.global_basis.z * Vector3(1, 0, 1)).normalized()
			var lato := avanti.cross(Vector3.UP).normalized()
			k += 1
			for j in 2:
				var nome_g := "gabbia%02d_%s" % [k, "ab"[j]]
				cam_tutte[nome_g] = [c + avanti * 0.45 + lato * (0.4 if j == 0 else -0.4) + Vector3(0, 0.15, 0), c - avanti * 0.08]
				lista.append(nome_g)
	# "giro": dalla ciambella lungo la strada giusta (anello da 20 a 266 gradi, ogni 8), guardando avanti, per trovare
	# dove la roccia delle sponde si interrompe (riscontro dell'utente sulla v0.3.14)
	if lista.has("giro"):
		lista.remove_at(lista.find("giro"))
		var g := 20.0
		while g <= 266.0:
			var nome_g := "giro_%03d" % int(g)
			cam_tutte[nome_g] = [F.anello(g) + Vector3(0, 0.6, 0), F.anello(g + 12.0) + Vector3(0, 1.0, 0)]
			lista.append(nome_g)
			g += 8.0
	for nome in lista:
		var c: Array = cam_tutte[nome]
		f.get_node("Tetto").visible = nome != "alto"
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP if nome != "alto" else Vector3.FORWARD)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join("fiume_%s_%s.jpg" % ["girate" if girate else "arrivo", nome]), 0.9)
		print("salvato fiume_gioco_", nome)
	get_tree().quit()
