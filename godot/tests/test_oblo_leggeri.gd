extends Node
## Test automatico: niente blocchi quando lei compare dietro un oblò (ObloLei; riscontro dell'utente sulla v0.3.14:
## "blocchi di qualche secondo" ai quattro oblò). Col renderer vero (Vulkan; nella CI quello software, llvmpipe, con
## xvfb) e la cache degli shader vuota:
## 1. la risalita da sola (scenes/risalita/risalita.tscn, i suoi tre oblò) e la torre da sola, costruita a pezzi e
##    preparata come nella sala (SalaTorre.costruisci_a_pezzi e prepara_materiali): lei di ogni oblò c'è già, nascosta
##    e ferma, prima di comparire, e la sua preparazione sta in un passo della costruzione;
## 2. quando lei compare (ObloLei._mostra) il codice ci mette meno di [constant COMPARSA_MAX] ms, e non istanzia niente;
## 3. guardandola e mentre si stacca (si scurisce fino al nero) il motore non compila pipeline che fermano il gioco
##    (monitor Performance "surface" a zero, "draw" al più [constant DRAW_TOLLERATE]; quelle "specialization", in
##    sottofondo, si stampano);
## 4. mentre si stacca nessuna parte di lei diventa trasparente (la trasparenza metteva la palpebra sotto l'occhio).
## Si misura il tempo del codice, non il fotogramma intero: col disegno sulla CPU la durata dei fotogrammi nella CI va
## su e giù da sola (come in test_torre_ingresso).
## Uso: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 \
##        --script res://tests/run.gd -- res://tests/test_oblo_leggeri.gd [senza_preparazione]
## Con "senza_preparazione" lei si crea al momento di comparire, com'era prima (per misurare il prima: i controlli
## falliscono).

const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
const RISALITA := "res://scenes/risalita/risalita.tscn"
## Quanto può costare il momento in cui lei compare (ms di codice, sulla CPU della CI).
const COMPARSA_MAX := 50.0
## Guardandola e al distacco: quante pipeline "draw" si accettano (0 "surface" sempre). Col renderer software, da una
## prova all'altra, in uno degli oblò della risalita ne restano a volte 1-3, sempre diverse: varianti delle ombre e
## delle luci della zona, non dei materiali di lei (che si compilano tutti prima). Alla comparsa: 0.
const DRAW_TOLLERATE := 3

var _passed := 0
var _failed := 0
var _cam: Camera3D
var _senza := false


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _monitor(k: String) -> Performance.Monitor:
	match k:
		"surface":
			return Performance.PIPELINE_COMPILATIONS_SURFACE
		"draw":
			return Performance.PIPELINE_COMPILATIONS_DRAW
	return Performance.PIPELINE_COMPILATIONS_SPECIALIZATION


func _conta() -> Dictionary:
	var d := {}
	for k in ["surface", "draw", "spec"]:
		d[k] = Performance.get_monitor(_monitor(k))
	return d


func _diff(prima: Dictionary) -> Dictionary:
	var d := {}
	for k in prima:
		d[k] = int(Performance.get_monitor(_monitor(k)) - prima[k])
	return d


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	GameState.save_to_disk = false
	_senza = OS.get_cmdline_user_args().has("senza_preparazione")
	print("Il renderer")
	var vero := RenderingServer.get_rendering_device() != null
	check(vero, "c'è il renderer vero (%s)" % RenderingServer.get_video_adapter_name())
	if not vero:
		_fine()
		return
	var env := WorldEnvironment.new()
	env.environment = load("res://assets/env/sala_environment.tres")
	add_child(env)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.make_current()
	_cam.position = Vector3(0, 2, 0)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)

	print("1. La risalita da sola: i suoi tre oblò")
	if _senza:
		Engine.set_meta(&"oblo_senza_preparazione", true)
	var ris := (load(RISALITA) as PackedScene).instantiate() as Node3D
	add_child(ris)
	await _frames(40)   # (la preparazione delle lei, a schermo nero nel gioco)
	var obli := ris.find_children("*", "ObloLei", true, false)
	# prima un giro dal corridoio davanti a ogni vetro, senza lei: le pipeline dei muri, dei vetri e dell'acqua sono della
	# zona, non di lei (qui si stampano e basta)
	var giro := _conta()
	for o: ObloLei in obli:
		_cam.global_position = o.global_transform * Vector3(0.2, 0.1, 2.6)
		_cam.look_at(o.global_transform * Vector3(0, -0.3, 0), Vector3.UP)
		await _frames(4)
		_cam.look_at(_cam.global_position + o.normale(), Vector3.UP)
		await _frames(4)
	var cg := _diff(giro)
	print("  (il giro della zona senza lei: surface %d, draw %d, in sottofondo %d)" % [cg.surface, cg.draw, cg.spec])
	for o: ObloLei in obli:
		await _prova(o)
	ris.queue_free()
	await _frames(5)

	print("2. La torre da sola, costruita a pezzi e preparata come nella sala")
	# come in test_torre_ingresso: quello che la sala ha già in scena (i bambini, la Polaroid) e gli shader dei materiali
	# che la torre crea da codice
	for sc in ["res://scenes/creature/bambino_cubo.tscn", "res://scenes/creature/bambino_agnello.tscn", "res://scenes/props/polaroid.tscn"]:
		var n := (load(sc) as PackedScene).instantiate()
		n.set(&"visible", false)
		# (la Polaroid qui, nell'origine, non ha niente sotto: niente avviso dello snap)
		n.set(&"snap_to_surface", false)
		add_child(n)
		await _frames(1)
	var campioni := SalaTorre.materiali_campione()
	var scena := load(TORRE) as PackedScene
	await _frames(10)
	var torre := scena.instantiate() as SalaTorre
	torre.costruzione_a_pezzi = true
	torre.visible = false
	torre.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(torre)
	await torre.costruisci_a_pezzi()
	check(torre.fotogramma_piu_carico_ms < 100.0, "la torre si costruisce a pezzi con lei dentro: al più %.0f ms in un fotogramma" % torre.fotogramma_piu_carico_ms)
	await torre.prepara_materiali(get_viewport())
	torre.visible = true
	torre.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(5)
	if torre.oblo:
		await _prova(torre.oblo)
	else:
		check(false, "nella torre c'è l'oblò")
	campioni.clear()
	_fine()


func _prova(o: ObloLei) -> void:
	var nome := String(o.get_parent().name) + "/" + String(o.name)
	if not _senza:
		check(o.lei != null and is_instance_valid(o.lei) and o.lei.lei != null and not o.lei.lei.visible,
				"%s: lei c'è già, nascosta, prima di comparire" % nome)
	# la camera nel corridoio, girata dall'altra parte (lei compare col vetro fuori dalla vista)
	var da := o.global_transform * Vector3(0.2, 0.1, 2.6)
	_cam.global_position = da
	_cam.look_at(da + o.normale(), Vector3.UP)
	await _frames(5)
	var nodi_prima := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var prima := _conta()
	var t0 := Time.get_ticks_usec()
	o._mostra()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var nuovi := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodi_prima)
	await _frames(4)
	var c := _diff(prima)
	check(ms < COMPARSA_MAX, "%s: lei compare in %.1f ms di codice (al più %.0f), %d nodi nuovi" % [nome, ms, COMPARSA_MAX, nuovi])
	check(c.surface == 0 and c.draw == 0, "%s: comparsa, nessuna compilazione che blocca (surface %d, draw %d; in sottofondo %d)" % [nome, c.surface, c.draw, c.spec])
	# girandosi verso il vetro: lei vista davanti
	prima = _conta()
	_cam.look_at(o.global_transform * Vector3(0, -0.3, 0), Vector3.UP)
	await _frames(6)
	c = _diff(prima)
	check(c.surface == 0 and c.draw <= DRAW_TOLLERATE, "%s: guardandola, nessuna compilazione che blocca (surface %d, draw %d su %d tollerate; in sottofondo %d)" % [nome, c.surface, c.draw, DRAW_TOLLERATE, c.spec])
	# il distacco: si scurisce, non diventa trasparente
	prima = _conta()
	o.via()
	var t := 0.0
	var scura := false
	var trasparente := false
	while t < 4.0 and o.stato != ObloLei.Stato.FINITA:
		await get_tree().process_frame
		t += get_process_delta_time()
		for g in o._parti_lei():
			if (g as GeometryInstance3D).visible and (g as GeometryInstance3D).transparency > 0.0:
				trasparente = true
		for e in o._scuri:
			if ((e[0] as BaseMaterial3D).albedo_color.v) < 0.2:
				scura = true
	c = _diff(prima)
	check(scura and not trasparente, "%s: si stacca scurendosi fino al nero, senza trasparenza" % nome)
	check(o.stato == ObloLei.Stato.FINITA, "%s: lei si stacca e sparisce" % nome)
	check(c.surface == 0 and c.draw <= DRAW_TOLLERATE, "%s: distacco, nessuna compilazione che blocca (surface %d, draw %d su %d tollerate; in sottofondo %d)" % [nome, c.surface, c.draw, DRAW_TOLLERATE, c.spec])


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)  # aspetta i caricamenti nel thread
