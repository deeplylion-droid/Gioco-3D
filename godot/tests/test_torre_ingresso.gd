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

var _passed := 0
var _failed := 0
var _ultimo := 0
var _durate: Array[float] = []
var _registra := false


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
		add_child(n)
		await _frames(1)
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
	var torre := scena.instantiate() as SalaTorre
	torre.costruzione_a_pezzi = true
	torre.visible = false
	torre.process_mode = Node.PROCESS_MODE_DISABLED
	_durate.clear()
	_registra = true
	add_child(torre)
	await torre.costruisci_a_pezzi()
	_registra = false
	if OS.has_environment("TORRE_TEMPI"):
		print("durate: ", _durate.map(func(x): return roundi(x)))
	var d := _durate.duplicate()
	d.sort()
	check(torre.costruita and torre.checkpoint.size() > 2 and not torre.corpi_scivolo().is_empty(), "la torre è costruita (%d checkpoint, %d scivoli)" % [torre.checkpoint.size(), torre.corpi_scivolo().size()])
	check(torre.fotogramma_piu_carico_ms < CARICO_MASSIMO, "in %d fotogrammi, al più %.0f ms di costruzione in uno (al massimo %.0f; fotogramma solito %.0f ms, il più lungo %.0f ms)" % [d.size(), torre.fotogramma_piu_carico_ms, CARICO_MASSIMO, base, d[-1]])

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
	_fine()


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
	get_tree().quit(1 if _failed > 0 else 0)
