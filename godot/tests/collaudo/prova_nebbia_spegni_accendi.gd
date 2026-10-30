extends Node3D
## La nebbia viola spenta e riaccesa dalle opzioni non compila niente che fermi il gioco (lavoro/nebbia-0317: più passi e
## i valori per zona). Col renderer vero, una stanza piccola (pavimento, muro, una lampada) dentro una ZonaNebbiaViola:
## la nebbia accesa e già disegnata, poi spenta (Grafica, "nebbia_viola"), riaccesa, due volte; poi i passi dei preset
## (16, 24, 32) e una zona con meno aria e alone (come il tunnel). Conta le compilazioni di pipeline "surface" e "draw"
## (quelle che bloccano; le "specialization" vanno in sottofondo e si stampano).
## Uso: xvfb-run -a -s "-screen 0 640x360x24" godot --path godot --rendering-driver vulkan --resolution 640x360 \
##        --script res://tests/run.gd -- res://tests/collaudo/prova_nebbia_spegni_accendi.gd

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_ok += 1
		print("  ok    ", what)
	else:
		_ko += 1
		printerr("  FALLITO ", what)


func _conta() -> Array:
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatola(dove: Vector3, misura: Vector3) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = misura
	m.mesh = b
	m.position = dove
	add_child(m)


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	Grafica.imposta("nebbia_viola", true)
	var we := WorldEnvironment.new()
	we.environment = load("res://addons/grafica/sala/ambiente_sala.tres") as Environment
	add_child(we)
	_scatola(Vector3(0, -0.05, 0), Vector3(12, 0.1, 12))
	_scatola(Vector3(0, 1.5, -4), Vector3(12, 3, 0.2))
	var l := OmniLight3D.new()
	l.position = Vector3(1, 2.4, -3)
	l.light_energy = 2.0
	l.omni_range = 6.0
	add_child(l)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.6, 3)
	add_child(cam)
	cam.make_current()
	var z := ZonaNebbiaViola.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(12, 4, 12)
	cs.shape = bs
	cs.position = Vector3(0, 2, 0)
	z.add_child(cs)
	add_child(z)
	var n: NebbiaViola = Grafica.nebbia_viola
	await _frames(5)
	n.zona(z, true, true)
	await _frames(120)
	check(n.quanto > 0.99, "la nebbia è accesa e disegnata (%.2f)" % n.quanto)
	var prima := _conta()
	for giro in 2:
		Grafica.imposta("nebbia_viola", false)
		await _frames(260)
		var spenta := n.quanto
		Grafica.imposta("nebbia_viola", true)
		await _frames(260)
		check(spenta < 0.01 and n.quanto > 0.99, "giro %d: spenta scende a %.2f, riaccesa sale a %.2f" % [giro + 1, spenta, n.quanto])
	var c := _conta()
	check(int(c[0] - prima[0]) == 0 and int(c[1] - prima[1]) == 0,
			"spegnendo e riaccendendo nessuna compilazione che blocca (surface %d, draw %d; in sottofondo %d)" % [
			c[0] - prima[0], c[1] - prima[1], c[2] - prima[2]])
	prima = _conta()
	for preset in ["basso", "medio", "alto", "ultra"]:
		n.imposta_qualita(1, preset)
		await _frames(30)
	var z2 := ZonaNebbiaViola.new()
	z2.aria = 0.25
	z2.alone = 0.7
	z2.polvere = 0.5
	add_child(z2)
	n.zona(z2, true, true)
	await _frames(60)
	c = _conta()
	check(int(c[0] - prima[0]) == 0 and int(c[1] - prima[1]) == 0,
			"cambiando i passi (16, 24, 32) e i valori della zona nessuna compilazione che blocca (surface %d, draw %d; in sottofondo %d)" % [
			c[0] - prima[0], c[1] - prima[1], c[2] - prima[2]])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
