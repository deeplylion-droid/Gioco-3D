extends Node
## Strumento: il posto della Polaroid 12 sul grigliato del pianerottolo del portone della torre (SalaTorre.P12). Sta
## ferma, quindi l'altezza si calcola una volta sola qui e si scrive nel codice: a gioco avviato niente raggi (con la
## torre che si costruisce a pezzi i raggi sotto tutta la foto facevano fotogrammi da 130 ms, test_attesa_zone del 29
## ottobre). Posa.appoggia_su_impronta guarda sotto tutta la foto (un raggio solo passava in un buco del grigliato e la
## lasciava 13 mm sopra le barre, collaudo del 28 ottobre). Stampa il posto da scrivere in SalaTorre.P12 e quanto è
## lontano da quello scritto ora; test_torre controlla che sia appoggiata.
## Da rilanciare se cambia il pianerottolo del portone.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/posa_polaroid12.gd

const TORRE := "res://scenes/sala/torre/sala_torre.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var torre: SalaTorre = (load(TORRE) as PackedScene).instantiate()
	torre.crea_luci = false
	get_tree().root.add_child(torre)
	for i in 10:
		await get_tree().physics_frame
	var p12 := torre.get_node_or_null(^"Polaroid12") as PolaroidPhoto
	if p12 == null:
		print("ERRORE: niente Polaroid12 nella torre")
		get_tree().quit(1)
		return
	var scritta := p12.position
	# di nuovo dal punto di partenza, appena sopra il pianerottolo
	p12.position = SalaTorre.b([scritta.x, -scritta.z, 0.03])
	await get_tree().physics_frame
	# quanto costa (per questo si calcola qui e non a gioco avviato)
	var t := Time.get_ticks_usec()
	Posa.appoggia_su_impronta(p12, PolaroidPhoto.IMPRONTA, 0.004)
	var costo := (Time.get_ticks_usec() - t) / 1000.0
	var nuova := p12.position
	p12.position = SalaTorre.b([scritta.x, -scritta.z, 0.03])
	t = Time.get_ticks_usec()
	Posa.appoggia_su_impronta(p12, PolaroidPhoto.IMPRONTA, 0.004)
	var costo2 := (Time.get_ticks_usec() - t) / 1000.0
	p12.position = SalaTorre.b([scritta.x, -scritta.z, 0.03])
	t = Time.get_ticks_usec()
	Posa.appoggia_a_terra(p12, 0.004)
	var costo1 := (Time.get_ticks_usec() - t) / 1000.0
	p12.position = nuova
	print("costo: sotto tutta la foto %.1f ms la prima volta, %.1f ms la seconda; un raggio solo %.1f ms" % [costo, costo2, costo1])
	print("P12 calcolata: Vector3(%.5f, %.5f, %.5f)" % [nuova.x, nuova.y, nuova.z])
	print("P12 scritta:   Vector3(%.5f, %.5f, %.5f), scarto %.1f mm" % [scritta.x, scritta.y, scritta.z,
		scritta.distance_to(nuova) * 1000.0])
	get_tree().quit(0 if scritta.distance_to(nuova) < 0.0005 else 1)
