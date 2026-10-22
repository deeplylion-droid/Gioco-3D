extends Node
## Test automatico del blocco del pool di thread (21 ottobre: gli scatti restavano fermi per sempre a 3 GB al
## primo fotogramma della sala, sulle macchine a 4 core; vedi Grafica._attiva_shader_avanzati). La sala si
## carica come nel gioco (ResourceLoader a thread, come la schermata di caricamento), entra in scena e deve
## disegnare i primi fotogrammi. Senza la cache degli shader (nella CI è sempre vuota: tutto da compilare,
## come alla prima partita di un giocatore). Un thread di guardia fa fallire il test se il thread
## principale resta fermo per [constant FERMO_MASSIMO] s con la CPU ferma.
## Per la memoria della CI (16 GB; col renderer software ogni pipeline compilata occupa memoria): senza le parti di
## [constant TOGLI] e si esce dopo il primo fotogramma, quello in cui il blocco succedeva. Picco circa 9 GB, stampato
## nel log. Senza la correzione si blocca lo stesso (a 3,2 GB).
## Il processo esce senza aspettare il pool (vedi la fine di _run): il passo della CI controlla la riga RISULTATO.
## Con l'argomento senza_shader_avanzati la correzione è spenta e il test si blocca (prova che se ne accorge).
## Serve il renderer vero e 4 worker (nella CI: override.cfg con threading/worker_pool/max_threads=4).
## Uso: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 \
##        --script res://tests/run.gd -- res://tests/test_pool_sala.gd [senza_shader_avanzati]

const LEVEL := "res://scenes/sala_principale.tscn"
const FOTOGRAMMI := 1
## Le parti della sala che non servono al caso. Restano l'architettura, le luci e il GI della sala, il giocatore.
const TOGLI := ["Interni", "Tecnici", "Piscina", "Vasche", "Vasca", "BambiniBalconata", "Polaroid", "Mascotte",
		"Sala/AngoloPalloni", "Sala/AngoloScatoloni", "Sala/Oggetti", "Sala/Dettagli", "Sala/AreaBimbi", "Sala/VascaCentrale",
		"Sala/Cupola", "Sala/Piscina", "LuciSala/LuciAreaBimbi"]
## Il primo fotogramma della sala su llvmpipe, con tutti gli shader da compilare, dura 1-2 minuti.
const FERMO_MASSIMO := 600.0

var _passed := 0
var _failed := 0
var _battito := 0
var _fine := false
var _guardia: Thread


func _ready() -> void:
	_guardia = Thread.new()
	_guardia.start(_guarda)
	_run.call_deferred()


func _process(_delta: float) -> void:
	_battito += 1


## Sul suo thread: se il thread principale non va avanti per FERMO_MASSIMO s, il test fallisce.
func _guarda() -> void:
	var ultimo := -1
	var fermo := 0.0
	while not _fine:
		OS.delay_msec(1000)
		fermo = fermo + 1.0 if _battito == ultimo else 0.0
		ultimo = _battito
		if fermo >= FERMO_MASSIMO:
			printerr("  FALLITO il thread principale è fermo da %d s: il pool di thread è bloccato" % int(fermo))
			print("")
			print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed + 1])
			OS.kill(OS.get_process_id())
			return


func _run() -> void:
	Game.pause_on_focus_loss = false
	var worker := int(ProjectSettings.get_setting("threading/worker_pool/max_threads"))
	print("worker_pool/max_threads: %d, processori: %d" % [worker, OS.get_processor_count()])
	check(worker == 4 or (worker < 0 and OS.get_processor_count() == 4),
		"4 worker nel pool (il caso dei giocatori con 4 core)")
	var t0 := Time.get_ticks_msec()
	ResourceLoader.load_threaded_request(LEVEL, "PackedScene")
	while ResourceLoader.load_threaded_get_status(LEVEL) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var level := (ResourceLoader.load_threaded_get(LEVEL) as PackedScene).instantiate()
	for percorso in TOGLI:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	print("sala caricata in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	t0 = Time.get_ticks_msec()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	for i in FOTOGRAMMI:
		await RenderingServer.frame_post_draw
	check(true, "la sala entra in scena e disegna %d fotogrammi in %.0f s, senza blocchi" % [FOTOGRAMMI,
			(Time.get_ticks_msec() - t0) / 1000.0])
	_fine = true
	_guardia.wait_to_finish()
	print("picco di memoria del processo: %s" % _picco_memoria())
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	# Uscendo con quit() Godot aspetta che il pool finisca tutte le pipeline in coda: col renderer software
	# della CI sono più di 12 GB. Il risultato è già stampato: si esce subito (la CI legge la riga RISULTATO).
	OS.kill(OS.get_process_id())


## Il picco di memoria del processo (VmHWM di Linux): nella CI la macchina ha 16 GB.
static func _picco_memoria() -> String:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return "non disponibile"
	# (i file di /proc hanno lunghezza zero: si leggono a righe)
	while not f.eof_reached():
		var riga := f.get_line()
		if riga.begins_with("VmHWM:"):
			return "%.1f GB" % (riga.get_slice(":", 1).strip_edges().to_int() / 1048576.0)
	return "non disponibile"


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)
