extends Node
## grafica-2: tutte le lampade a gabbia col globo (lampada_gabbia.glb) caricate col gioco vero (partenza F9 "fiume":
## sala, risalita, fiume, infermeria, pozze), con la zona, la luce vicina (energia scritta e colore) e il globo.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Game.pause_on_focus_loss = false
	MenuProva.parti(get_tree(), "fiume")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p.is_inside_tree() and p.input_enabled:
			break
	if Game.has_method(&"aspetta_caricamenti"):
		await Game.aspetta_caricamenti(get_tree().current_scene, 120.0)
	for i in 60:
		await get_tree().process_frame
	var luci: Array = get_tree().root.find_children("*", "Light3D", true, false)
	var conta := {}
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if not String(n.scene_file_path).ends_with("lampada_gabbia.glb"):
			continue
		var nd := n as Node3D
		var zona := String(nd.get_path()).replace("/root/SalaPrincipale/", "").get_slice("/", 0)
		if zona == "Risalita":
			zona += "/" + String(nd.get_path()).replace("/root/SalaPrincipale/Risalita/", "").get_slice("/", 0)
		var g := nd.find_child("globo", true, false) as MeshInstance3D
		var em := -1.0
		if g and g.material_override is StandardMaterial3D and (g.material_override as StandardMaterial3D).emission_enabled:
			em = (g.material_override as StandardMaterial3D).emission_energy_multiplier
		var vicina: Light3D = null
		var dmin := 1.0
		for l: Light3D in luci:
			var d := l.global_position.distance_to(nd.global_position)
			if d < dmin:
				dmin = d
				vicina = l
		var desc := "luce %.2f %s" % [vicina.light_energy, vicina.light_color.to_html(false)] if vicina else "senza luce (rotta)"
		print("GABBIA %s a %s: %s, globo %.2f" % [zona, nd.global_position.snapped(Vector3.ONE * 0.1), desc, em])
		var k := "%s | %s | globo %.2f" % [zona, desc, em]
		conta[k] = int(conta.get(k, 0)) + 1
	for k in conta:
		print("GABBIE %d × %s" % [conta[k], k])
	print("GABBIE FINE")
	Game.esci(0)
