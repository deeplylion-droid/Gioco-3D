extends Node
## Misura la preparazione nascosta della sala della torre come nel gioco (SalaPrincipale._prepara_torre): caricata
## prima (come dal thread), con quello che la sala ha già (come in test_torre_ingresso: i bambini e la Polaroid in scena,
## i materiali campione di SalaTorre.materiali_campione; senza, i passi che fanno una scena o uno shader per la prima
## volta costano come la prima volta, non come nel gioco), instantiate, add_child nascosta e ferma, costruisci_a_pezzi
## (con l'inseguimento), prepara_materiali (SENZA_PREPARA=1 lo salta) e infine si mostra. Stampa ogni fotogramma sopra
## i 50 ms e, con TORRE_TEMPI=1, la durata di ogni passo della torre e dell'inseguimento.
## Uso: TORRE_TEMPI=1 godot --headless --path godot --script res://tests/run.gd -- res://tests/misura_torre_pezzi.gd

var _t := 0
var _misura := false


func _ready() -> void:
	_run.call_deferred()


func _process(_d: float) -> void:
	var ora := Time.get_ticks_usec()
	if _misura and _t > 0 and ora - _t > 50000:
		print("BLOCCO %.0f ms" % ((ora - _t) / 1000.0))
	_t = ora


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	# come nel gioco: nella sala i bambini e la Polaroid sono già in scena (il primo instantiate di una scena e la prima
	# entrata di un bambino costano molto più dei successivi)
	for sc in ["res://scenes/creature/bambino_cubo.tscn", "res://scenes/creature/bambino_agnello.tscn", "res://scenes/props/polaroid.tscn"]:
		var n := (load(sc) as PackedScene).instantiate()
		n.set(&"visible", false)
		# (la Polaroid qui, nell'origine, non ha niente sotto: niente avviso dello snap)
		n.set(&"snap_to_surface", false)
		add_child(n)
		await get_tree().process_frame
	# e la sala crea entrando gli shader dei materiali che la torre fa da codice, e li tiene
	var campioni := SalaTorre.materiali_campione()
	var scena := load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene
	# come nel gioco: i file di lei arrivano col thread insieme alla torre
	var tenuti: Array = []
	for r in SalaInseguimento.risorse():
		tenuti.append(load(r))
	for i in 10:
		await get_tree().process_frame
	_misura = true
	var t0 := Time.get_ticks_usec()
	var t := scena.instantiate() as Node3D
	t.set(&"costruzione_a_pezzi", true)
	t.set(&"inseguimento_continua", true)
	t.visible = false
	t.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(t)
	print("instantiate e add_child: %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	await t.call(&"costruisci_a_pezzi")
	print("TORRE: costruita in %.1f s, il fotogramma più carico della torre %.0f ms" % [(Time.get_ticks_usec() - t0) / 1e6, float(t.get(&"fotogramma_piu_carico_ms"))])
	# come nel gioco: costruita, si disegna una volta fuori vista (SalaTorre.prepara_materiali), poi si mostra (col renderer
	# software compila le pipeline per un paio di minuti; SENZA_PREPARA=1 lo salta, per i soli tempi dei passi)
	if not OS.has_environment("SENZA_PREPARA"):
		var tp := Time.get_ticks_usec()
		print("prepara_materiali:")
		await t.call(&"prepara_materiali", get_viewport())
		print("prepara_materiali: %.1f s" % ((Time.get_ticks_usec() - tp) / 1e6))
	for i in 10:
		await get_tree().process_frame
	# la torre si mostra (SalaPrincipale._mostra_torre): process e visibile
	var t1 := Time.get_ticks_usec()
	if OS.has_environment("A_PEZZI"):
		# i figli fermi uno per uno, poi la radice viva, poi i figli vivi uno per fotogramma
		var peggiore := 0.0
		for c in t.get_children():
			var tc := Time.get_ticks_usec()
			c.process_mode = Node.PROCESS_MODE_DISABLED
			peggiore = maxf(peggiore, (Time.get_ticks_usec() - tc) / 1000.0)
		print("mostra a pezzi: figli fermi %.1f ms (il peggiore %.1f)" % [(Time.get_ticks_usec() - t1) / 1000.0, peggiore])
		var tr := Time.get_ticks_usec()
		t.process_mode = Node.PROCESS_MODE_INHERIT
		print("mostra a pezzi: radice viva %.1f ms" % ((Time.get_ticks_usec() - tr) / 1000.0))
		peggiore = 0.0
		for c in t.get_children():
			var tc := Time.get_ticks_usec()
			c.process_mode = Node.PROCESS_MODE_INHERIT
			var d := (Time.get_ticks_usec() - tc) / 1000.0
			if d > peggiore:
				peggiore = d
				print("  figlio %s: %.1f ms (%d nodi)" % [c.name, d, c.get_child_count()])
		print("mostra a pezzi: il figlio peggiore %.1f ms" % peggiore)
	else:
		# come nel gioco (SalaPrincipale._mostra_torre)
		await AccensioneAPezzi.accendi(t)
	var t2 := Time.get_ticks_usec()
	t.visible = true
	var t3 := Time.get_ticks_usec()
	print("mostra: process %.1f ms, visible %.1f ms" % [(t2 - t1) / 1000.0, (t3 - t2) / 1000.0])
	for i in 20:
		await get_tree().process_frame
	campioni.clear()
	get_tree().quit()
