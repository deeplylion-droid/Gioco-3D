extends Node
## Test automatico: niente blocchi quando la sala della torre entra in scena all'apertura del portone
## (riscontro dell'utente: "nota ogni blocco"). Con la torre da sola (la sala intera non sta nella
## memoria della CI), lo stesso meccanismo della sala principale:
## 1. la torre caricata si costruisce nascosta un pezzo per fotogramma (SalaTorre.costruisci_a_pezzi):
##    nessun fotogramma lungo;
## 2. si disegna una volta fuori vista (SalaTorre.prepara_materiali);
## 3. mostrata alla camera del gioco, al primo fotogramma il motore non compila pipeline che lo fermano
##    (monitor Performance "surface" e "draw" a zero; le "specialization" in sottofondo si stampano).
## Serve il renderer vero (Vulkan; nella CI quello software, llvmpipe, con xvfb).
## Uso: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 \
##        --script res://tests/run.gd -- res://tests/test_torre_ingresso.gd [senza_preparazione]

const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
## Quanti ms di costruzione possono finire in un fotogramma (la CI fa tutto sulla CPU, anche il disegno:
## lì i passi più cari costano 30-60 ms; prima la torre entrava tutta in un fotogramma, più di 1 s, e poi
## 11 s per le pipeline). Si misura il tempo dei passi, non il fotogramma intero: col disegno sulla CPU
## e le pipeline compilate in sottofondo la durata dei fotogrammi nella CI va su e giù da sola.
const CARICO_MASSIMO := 100.0
## Se il fotogramma più carico supera [constant CARICO_MASSIMO], alla fine la torre si rifà da capo e si ricostruisce a
## pezzi, fino a tante volte: vale la misura più bassa, e si stampano tutte (nella CI 30-60 ms di solito, 99 e 151 con un
## runner lento: un runner rallentato in quel momento non fa cadere il test, un passo diventato più caro sì, perché
## resta sopra il limite in ogni misura). Con TORRE_RITARDO=<ms>,<volte> le prime <volte> misure si allungano di <ms>,
## per provare il controllo stesso.
const RIPROVE_CARICO := 3

var _passed := 0
var _failed := 0
var _ultimo := 0
var _durate: Array[float] = []
var _registra := false
var _ritardo_ms := 0.0
var _ritardo_volte := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _process(_delta: float) -> void:
	var ora := Time.get_ticks_usec()
	if _registra and _ultimo > 0:
		_durate.append((ora - _ultimo) / 1000.0)
	_ultimo = ora


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	# (con RITARDO_THREAD_TEST=<s> il thread rallentato apposta, come in test_attesa_zone: Game.ritardo_thread_test)
	if OS.has_environment("RITARDO_THREAD_TEST"):
		Game.ritardo_thread_test = float(OS.get_environment("RITARDO_THREAD_TEST"))
	if OS.has_environment("TORRE_RITARDO"):
		var r := OS.get_environment("TORRE_RITARDO").split(",")
		_ritardo_ms = float(r[0])
		_ritardo_volte = int(r[1]) if r.size() > 1 else 1
		print("(prova del controllo: le prime %d costruzioni più cariche di %.0f ms)" % [_ritardo_volte, _ritardo_ms])
	print("Il renderer")
	var vero := RenderingServer.get_rendering_device() != null
	check(vero, "c'è il renderer vero (%s)" % RenderingServer.get_video_adapter_name())
	if not vero:
		_fine()
		return
	var env := WorldEnvironment.new()
	env.environment = load("res://assets/env/sala_environment.tres")
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	cam.position = Vector3(0, 2, 0)
	# Come nella sala: le scene dei bambini e la torre sono già caricate (la torre col thread)
	# (e nella sala i bambini e la Polaroid sono già in scena e restano: il primo instantiate di una scena
	# e la prima entrata di un bambino costano 50-100 ms sulla CPU, i successivi pochi ms)
	for s in ["res://scenes/creature/bambino_cubo.tscn", "res://scenes/creature/bambino_agnello.tscn", "res://scenes/props/polaroid.tscn"]:
		var n := (load(s) as PackedScene).instantiate()
		n.set(&"visible", false)
		# (la Polaroid qui, nell'origine, non ha niente sotto: niente avviso dello snap)
		n.set(&"snap_to_surface", false)
		add_child(n)
		await _frames(1)
	# e gli shader dei materiali che la torre crea da codice, che la sala crea entrando (sala_principale.gd)
	var campioni := SalaTorre.materiali_campione()
	var scena := load(TORRE) as PackedScene
	await _frames(10)

	# il fotogramma solito, senza la torre
	_durate.clear()
	_registra = true
	await _frames(12)
	_registra = false
	var solito := _durate.duplicate()
	solito.sort()
	var base: float = solito[solito.size() / 2]
	print("1. La torre si costruisce nascosta, un pezzo per fotogramma")
	var torre: SalaTorre = await _costruisci(scena)
	if OS.has_environment("TORRE_TEMPI"):
		print("durate: ", _durate.map(func(x): return roundi(x)))
	var d := _durate.duplicate()
	d.sort()
	check(torre.costruita and torre.checkpoint.size() > 2 and not torre.corpi_scivolo().is_empty(), "la torre è costruita (%d checkpoint, %d scivoli)" % [torre.checkpoint.size(), torre.corpi_scivolo().size()])
	var carichi: Array[float] = [torre.fotogramma_piu_carico_ms]
	var passi: Array[String] = [torre.passo_piu_lungo]
	var quanti := d.size()
	var piu_lungo: float = d[-1]
	if carichi[0] < CARICO_MASSIMO:
		_check_carico(carichi, passi, quanti, base, piu_lungo)
	else:
		print("  (la prima costruzione ha %.0f ms in un fotogramma, sopra %.0f: alla fine si rifà la torre e si rimisura)" % [carichi[0], CARICO_MASSIMO])

	print("2. Disegnata una volta fuori vista")
	if not OS.get_cmdline_user_args().has("senza_preparazione"):
		await torre.prepara_materiali(get_viewport())
	check(not torre.visible, "e resta nascosta")

	print("3. Il portone si apre: la torre si vede")
	var prima := {}
	for k in ["surface", "draw", "spec"]:
		prima[k] = Performance.get_monitor(_monitor(k))
	torre.visible = true
	torre.process_mode = Node.PROCESS_MODE_INHERIT
	# dall'ingresso, guardando la discesa (come entrando dal portone)
	cam.global_position = Vector3(22.0, 1.6, -15.0)
	cam.look_at(Vector3(5.0, -6.0, -15.0))
	_durate.clear()
	_registra = true
	await _frames(6)
	_registra = false
	var c := {}
	for k in prima:
		c[k] = int(Performance.get_monitor(_monitor(k)) - prima[k])
	check(c.surface == 0 and c.draw == 0, "al primo fotogramma nessuna compilazione che blocca (surface %d, draw %d; in sottofondo %d)" % [c.surface, c.draw, c.spec])
	if carichi[0] >= CARICO_MASSIMO:
		print("4. La costruzione a pezzi rimisurata con la torre rifatta da capo")
		var k := 0
		while k < RIPROVE_CARICO and carichi.min() >= CARICO_MASSIMO:
			k += 1
			torre.queue_free()
			await _frames(5)
			torre = await _costruisci(scena)
			carichi.append(torre.fotogramma_piu_carico_ms)
			passi.append(torre.passo_piu_lungo)
		_check_carico(carichi, passi, quanti, base, piu_lungo)
	_fine()


## La torre caricata, costruita nascosta un pezzo per fotogramma, registrando la durata dei fotogrammi.
func _costruisci(scena: PackedScene) -> SalaTorre:
	var torre := scena.instantiate() as SalaTorre
	torre.costruzione_a_pezzi = true
	torre.visible = false
	torre.process_mode = Node.PROCESS_MODE_DISABLED
	_durate.clear()
	_registra = true
	add_child(torre)
	await torre.costruisci_a_pezzi()
	_registra = false
	if _ritardo_volte > 0:
		_ritardo_volte -= 1
		torre.fotogramma_piu_carico_ms += _ritardo_ms
	return torre


## Il controllo della costruzione a pezzi: vale la misura più bassa (con una sola, quella).
func _check_carico(carichi: Array[float], passi: Array[String], quanti: int, base: float, piu_lungo: float) -> void:
	var i := carichi.find(carichi.min())
	var tutte := ""
	if carichi.size() > 1:
		tutte = " (la più bassa delle misure %s ms, con la torre rifatta da capo)" % ", ".join(carichi.map(func(x: float) -> String: return "%.0f" % x))
	check(carichi.min() < CARICO_MASSIMO, "in %d fotogrammi, al più %.0f ms di costruzione in uno (al massimo %.0f; fotogramma solito %.0f ms, il più lungo %.0f ms; il passo più lungo: %s)%s" % [
			quanti, carichi.min(), CARICO_MASSIMO, base, piu_lungo, passi[i], tutte])


func _monitor(k: String) -> Performance.Monitor:
	match k:
		"surface":
			return Performance.PIPELINE_COMPILATIONS_SURFACE
		"draw":
			return Performance.PIPELINE_COMPILATIONS_DRAW
	return Performance.PIPELINE_COMPILATIONS_SPECIALIZATION


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)  # aspetta i caricamenti nel thread
