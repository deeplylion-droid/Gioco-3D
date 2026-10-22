extends Node
## Scatti di controllo (interni, per la squadra) della zona degli acquari davanti al portone come la vede il
## giocatore: acquari comparsi (o risolti, col portone aperto). Solo la sala (architettura, oggetti, interattivi,
## dettagli), le luci, gli acquari e il portone, con la GI spenta, per stare nella memoria di llvmpipe. Quattro punti di vista attorno alla zona, all'altezza degli occhi.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan \
##   --resolution 960x540 --script res://tests/run.gd -- res://tests/scatti_acquari_zona.gd <cartella> [risolti]

const LEVEL := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var cartella := OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("medio")
	Grafica.imposta("gi", 0)
	# senza la torre: con gli acquari comparsi la sala la precarica (e col portone aperto la mette in scena)
	Engine.set_meta(&"precarica_torre_spento", true)
	var level := (load(LEVEL) as PackedScene).instantiate()
	# la serranda del magazzino sta nei Tecnici, che qui si tolgono: gli acquari compaiono come senza serranda
	# (con la tappa 8 finita)
	var enigma := level.find_child("EnigmaAcquari", true, false)
	enigma.set(&"serranda", null)
	enigma.set(&"tappa8", null)
	# solo quello che serve alla zona (la sala intera non sta nella memoria di llvmpipe)
	var tieni := {"": ["Sala", "LuciSala", "Atmosfera", "Gioco"], "Gioco": ["EnigmaAcquari", "PortoneTorre"],
		"Sala": ["Architettura", "Oggetti", "Interattivi", "Luci", "Dettagli", "PavimentiBagnati", "SuperficiBagnate"]}
	for padre in tieni:
		var nodo := level if padre == "" else level.get_node(NodePath(padre))
		for c in nodo.get_children():
			if not (tieni[padre] as Array).has(String(c.name)):
				nodo.remove_child(c)
				c.free()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	for c in level.find_children("*", "CharacterBody3D", true, false):
		(c as Node).process_mode = Node.PROCESS_MODE_DISABLED
	if OS.get_cmdline_user_args().has("risolti"):
		enigma.set(&"stato", EnigmaAcquari.Stato.RISOLTO)
		var portone = enigma.get(&"portone")
		portone.call(&"apri")
		for i in 900:
			if bool(portone.call(&"is_aperto")) and not bool(portone.get(&"in_movimento")):
				break
			await get_tree().physics_frame
	for i in 30:
		await get_tree().process_frame
	var box := AABB()
	var primo := true
	for n in enigma.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not String(enigma.get_path_to(mi)).begins_with("Acquario"):
			continue
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var a := mi.global_transform * mi.get_aabb()
		box = a if primo else box.merge(a)
		primo = false
	print("ZONA ", box, " centro ", box.get_center())
	var cam := Camera3D.new()
	cam.fov = 70.0
	level.add_child(cam)
	cam.current = true
	var c := box.get_center()
	var r := maxf(box.size.x, box.size.z) * 0.5 + 3.0
	for n in enigma.get_children():
		if n is Node3D:
			print("PARTE %s a %s" % [n.name, (n as Node3D).global_position.snapped(Vector3.ONE * 0.01)])
	# da vicino, all'altezza degli occhi, dal lato da cui arriva il giocatore (la sala è a nord degli acquari, z più alto)
	var viste := {
		"1_giallo": [Vector3(16.9, 1.7, -18.3), Vector3(16.9, 1.4, -22.3)],
		"2_giallo_lato": [Vector3(13.6, 1.7, -19.4), Vector3(16.9, 1.6, -22.3)],
		"3_misto": [Vector3(11.3, 2.3, -17.4), Vector3(11.3, 0.7, -21.6)],
		"4_valvola": [Vector3(8.4, 1.7, -17.2), Vector3(8.0, 1.2, -21.2)],
		"5_blu": [Vector3(5.7, 1.7, -18.3), Vector3(5.7, 1.4, -22.3)],
		"6_blu_lato": [Vector3(8.9, 1.7, -19.4), Vector3(5.7, 1.6, -22.3)],
		"7_portone": [Vector3(13.5, 1.7, -15.0), Vector3(19.5, 2.0, -15.0)],
		"8_insieme": [Vector3(11.3, 1.7, -13.0), Vector3(11.3, 1.4, -22.0)],
	}
	for nome in viste:
		cam.look_at_from_position(viste[nome][0], viste[nome][1])
		for k in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var f := cartella.path_join("acquari_%s.jpg" % nome)
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("SCATTO ", f)
	OS.kill(OS.get_process_id())
