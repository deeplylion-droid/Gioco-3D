extends Node
## Gli strati e le maschere delle luci cambiati su nodi già nella scena (Strati, addons/grafica/strati.gd), e il
## riscaldamento delle pipeline interrotto a metà (la morte mentre la zona si disegna fuori vista).
## Va lanciato col binario di Godot (debug) e un renderer vero: il controllo vero è che nel registro non ci sia nessun
## "ERROR: BUG, indexing did not unpair geometries from light" né "SCRIPT ERROR" (lo guarda la CI, job di debug della
## Prova su Vulkan). Headless il motore non accoppia niente: i controlli qui sotto passano, ma non provano il motore.
## Con -- --riproduci fa anche i casi coi cambi diretti, che il BUG lo devono dare (solo a mano, per vedere che la prova
## lo vede).
## Uso: xvfb-run godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- res://tests/test_strati_luci.gd

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var riproduci := OS.get_cmdline_user_args().has("--riproduci")
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.5, 6)
	cam.current = true
	print("PROVA STRATI: renderer ", RenderingServer.get_current_rendering_driver_name())

	if riproduci:
		print("PROVA STRATI: diretto, layers (qui il BUG ci deve essere)")
		var r := _zona(4)
		await _fotogrammi(4)
		for m in r.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).layers = 0  # strati: voluto (il caso che il BUG lo deve dare)
		await _fotogrammi(2)
		r.free()
		await _fotogrammi(3)
		print("PROVA STRATI: diretto, light_cull_mask (in questo caso semplice la 4.7.2 il BUG non lo dà: si vede solo che Strati fa lo stesso)")
		r = _zona(4)
		await _fotogrammi(4)
		(r.get_node(^"Luce") as Light3D).light_cull_mask = 1 << 10  # strati: voluto (il cambio diretto, per confronto)
		await _fotogrammi(2)
		r.free()
		await _fotogrammi(3)

	print("PROVA STRATI: Strati.metti")
	var z := _zona(4)
	await _fotogrammi(4)
	for m in z.find_children("*", "MeshInstance3D", true, false):
		Strati.metti(m as MeshInstance3D, 0)
	check(z.find_children("*", "MeshInstance3D", true, false).all(func(m: Node) -> bool: return (m as MeshInstance3D).layers == 0),
			"Strati.metti mette gli strati")
	await _fotogrammi(2)
	z.free()
	await _fotogrammi(3)

	print("PROVA STRATI: Strati.maschera_luce")
	z = _zona(4)
	await _fotogrammi(4)
	var luce := z.get_node(^"Luce") as Light3D
	Strati.maschera_luce(luce, 1 << 10)
	check(luce.light_cull_mask == 1 << 10 and luce.visible, "Strati.maschera_luce mette la maschera, la luce resta accesa")
	await _fotogrammi(2)
	z.free()
	await _fotogrammi(3)

	print("PROVA STRATI: Strati.metti su un nodo nascosto e su uno fuori dalla scena")
	z = _zona(2)
	await _fotogrammi(3)
	var m0 := z.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	m0.visible = false
	Strati.metti(m0, 1 << 3)
	m0.visible = true
	var fuori := MeshInstance3D.new()
	Strati.metti(fuori, 1 << 4)
	check(m0.layers == 1 << 3 and fuori.layers == 1 << 4, "anche nascosto e fuori dalla scena")
	fuori.free()
	await _fotogrammi(2)
	z.free()
	await _fotogrammi(3)

	print("PROVA STRATI: la morte a metà del riscaldamento a pezzi")
	z = _zona(6)
	await _fotogrammi(3)
	var prima := {}
	for m in z.find_children("*", "MeshInstance3D", true, false):
		prima[m.name] = (m as MeshInstance3D).layers
	RiscaldamentoShader.disegna_a_pezzi(z, get_viewport(), 2)
	await _fotogrammi(5)
	var rimessi := [false]
	z.tree_exiting.connect(func() -> void:
		rimessi[0] = z.find_children("*", "MeshInstance3D", true, false).all(
				func(m: Node) -> bool: return (m as MeshInstance3D).layers == prima[m.name]))
	z.queue_free()
	await _fotogrammi(8)
	check(rimessi[0], "a metà dei pezzi, la zona che esce dalla scena ha già gli strati di prima")

	print("PROVA STRATI: la morte a metà del riscaldamento fuori vista")
	z = _zona(6)
	await _fotogrammi(3)
	RiscaldamentoShader.disegna_fuori_vista(z, get_viewport(), 6)
	await _fotogrammi(2)
	rimessi[0] = false
	z.tree_exiting.connect(func() -> void:
		rimessi[0] = z.find_children("*", "VisualInstance3D", true, false).all(
				func(v: Node) -> bool: return (v as VisualInstance3D).layers == 1))
	z.queue_free()
	await _fotogrammi(10)
	check(rimessi[0], "fuori vista, la zona che esce dalla scena ha già gli strati di prima")

	print("PROVA STRATI: fine")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Una luce con le ombre e [param quante] mesh nel suo raggio, davanti alla camera.
func _zona(quante: int) -> Node3D:
	var r := Node3D.new()
	r.name = "Zona"
	add_child(r)
	var luce := OmniLight3D.new()
	luce.name = "Luce"
	luce.omni_range = 12.0
	luce.shadow_enabled = true
	luce.position = Vector3(0, 3, 0)
	r.add_child(luce)
	for i in quante:
		var m := MeshInstance3D.new()
		m.name = "Pezzo%d" % i
		m.mesh = BoxMesh.new()
		m.position = Vector3(i * 1.2 - quante * 0.6, 0.5, 0)
		r.add_child(m)
	return r


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)
