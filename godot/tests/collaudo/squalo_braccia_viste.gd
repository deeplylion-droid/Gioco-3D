extends Node3D
## Le braccia dello squalo nel giro, viste da vicino nel motore: il GLB caricato a runtime (così si confrontano due
## versioni), a ogni istante di [constant ISTANTI] la camera guarda il petto da quattro lati (da dietro il giocatore, cioè
## da ovest; dalla porta, da est; da nord; da sopra), con una luce bianca semplice. Per vedere se il braccio alzato o la
## pinna dell'avambraccio entrano nel muso o nel corpo, e come sta attaccata la pinna. Scrive <cartella>/<t>_<lato>.jpg.
## Con "bocca" dopo la cartella: più vicino (1,1 m), attorno all'osso della bocca, a [constant ISTANTI_BOCCA] e da sei lati;
## con "mento": a 0,7 m dalla punta del mento, da dieci lati ([constant LATI_MENTO]). Gli istanti si possono dare dopo.
## Uso: xvfb-run -a -s "-screen 0 640x640x24" godot --path godot --rendering-driver vulkan --resolution 640x640 \
##        --script res://tests/run.gd -- res://tests/collaudo/squalo_braccia_viste.gd <glb> <cartella> [bocca|petto] [istanti]

const ISTANTI := [8.6, 8.8, 9.0, 9.1, 9.2, 9.3, 9.4, 9.6]
const ISTANTI_BOCCA := [9.1, 9.167, 9.2, 9.233, 9.667, 9.7, 9.733, 9.767]
## (direzione da cui si guarda il petto, nel modello: il giocatore sta verso +Z, la porta verso -Z)
const LATI := {"giocatore": Vector3(0, 0.15, 1), "porta": Vector3(0, 0.15, -1), "fianco": Vector3(1, 0.1, 0),
		"sopra": Vector3(0.01, 1, 0.2)}
## Attorno al mento, a 0,7 m: un giro di otto lati in orizzontale e due da sotto.
const LATI_MENTO := {"n": Vector3(0, 0.05, -1), "ne": Vector3(0.7, 0.05, -0.7), "e": Vector3(1, 0.05, 0), "se": Vector3(0.7, 0.05, 0.7),
		"s": Vector3(0, 0.05, 1), "so": Vector3(-0.7, 0.05, 0.7), "o": Vector3(-1, 0.05, 0), "no": Vector3(-0.7, 0.05, -0.7),
		"sotto_e": Vector3(0.6, -0.8, 0.0), "sotto_o": Vector3(-0.6, -0.8, 0.0)}
const LATI_BOCCA := {"+x": Vector3(1, 0.1, 0), "-x": Vector3(-1, 0.1, 0), "+z": Vector3(0, 0.1, 1), "-z": Vector3(0, 0.1, -1),
		"sopra": Vector3(0.01, 1, 0.2), "sotto": Vector3(0.2, -0.6, 0.6)}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella: String = a[2]
	DirAccess.make_dir_recursive_absolute(cartella)
	var doc := GLTFDocument.new()
	var stato := GLTFState.new()
	if doc.append_from_file(a[1], stato) != OK:
		printerr("non carico ", a[1])
		get_tree().quit(1)
		return
	var radice := doc.generate_scene(stato) as Node3D
	add_child(radice)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.32, 0.34)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-50, 30, 0)
	sole.light_energy = 1.4
	add_child(sole)
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	var ap := radice.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := radice.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var anim: StringName = ap.get_animation_list()[0]
	for n in ap.get_animation_list():
		if String(n).contains("risveglio"):
			anim = n
	ap.play(anim)
	ap.pause()
	var bocca := a.size() > 3 and a[3] in ["bocca", "mento"]
	var mento := a.size() > 3 and a[3] == "mento"
	var centro := sk.find_bone("mento_punta" if mento else ("bocca" if bocca else "petto"))
	var lati: Dictionary = LATI_MENTO if mento else (LATI_BOCCA if bocca else LATI)
	var distanza := 0.7 if mento else (1.1 if bocca else 2.6)
	var istanti: Array = ISTANTI_BOCCA if bocca else ISTANTI
	if a.size() > 4:
		istanti = Array(a[4].split(",")).map(func(x): return float(x))
	for t in istanti:
		ap.seek(t, true)
		for i in 3:
			await get_tree().process_frame
		var c := (sk.global_transform * sk.get_bone_global_pose(centro)).origin + Vector3(0, 0.0 if bocca else 0.05, 0)
		for lato in lati:
			var d: Vector3 = (lati[lato] as Vector3).normalized()
			cam.global_transform = Transform3D(Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.9 else Vector3.FORWARD), c + d * distanza)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(cartella.path_join(("%.3f_%s.jpg" if bocca else "%.1f_%s.jpg") % [t, lato]), 0.9)
	print("FINE viste ", cartella)
	get_tree().quit()
