extends Node
## grafica-2: la luce rosa di lei (SalaInseguimento._lei_luce) in vasca_0: piena mentre sale e sta su, si spegne negli
## ultimi 0,4 s della discesa, torna piena alla comparsa dopo; anche con una respinta a metà salita e una comparsa
## subito dopo una discesa interrotta.
var sala: SalaInseguimento

func _ready() -> void:
	_run.call_deferred()

func _e() -> float:
	return (sala.get(&"_lei_luce") as OmniLight3D).light_energy

func _run() -> void:
	Game.pause_on_focus_loss = false
	sala = SalaInseguimento.new()
	sala.costruzione_a_pezzi = true
	add_child(sala)
	sala.set_physics_process(false)
	sala.call(&"_lei_crea")
	sala.call(&"_lei_parti")
	for i in 5:
		await get_tree().process_frame
	for giro in 2:
		sala.call(&"_lei_sale", "vasca_0", Vector3.ZERO)
		await get_tree().process_frame
		print("LUCE giro %d: alla comparsa %.2f" % [giro, _e()])
		var mn := 99.0
		for i in 60:
			await get_tree().process_frame
			mn = minf(mn, _e())
		print("LUCE giro %d: durante la salita al meno %.2f" % [giro, mn])
		sala.call(&"_scendi", false)
		var d := float(sala.get_meta(&"durata_discesa"))
		var t := 0.0
		var righe := []
		while t < d + 0.2:
			await get_tree().process_frame
			t += get_process_delta_time()
			righe.append("%.2f:%.2f" % [t, _e()])
		print("LUCE giro %d: discesa %.2f s, energia: %s" % [giro, d, " ".join(righe.slice(0, righe.size(), 3))])
	# respinta a metà salita e comparsa subito dopo (la luce a metà spegnimento)
	sala.call(&"_lei_sale", "vasca_0", Vector3.ZERO)
	for i in 20:
		await get_tree().process_frame
	sala.call(&"_scendi", true)
	var d2 := float(sala.get_meta(&"durata_discesa"))
	var t2 := 0.0
	while t2 < d2 - 0.15:
		await get_tree().process_frame
		t2 += get_process_delta_time()
	print("LUCE respinta: a %.2f s su %.2f energia %.2f" % [t2, d2, _e()])
	sala.call(&"_lei_sale", "vasca_0", Vector3.ZERO)
	var mn2 := 99.0
	for i in 30:
		await get_tree().process_frame
		mn2 = minf(mn2, _e())
	print("LUCE ricomparsa durante lo spegnimento: al meno %.2f nei 30 fotogrammi dopo" % mn2)
	get_tree().quit()
