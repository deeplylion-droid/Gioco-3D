extends Node
## Test automatico: niente blocchi quando lei compare dietro un oblò (ObloLei; riscontro dell'utente sulla v0.3.14:
## "blocchi di qualche secondo" ai quattro oblò). Col renderer vero (Vulkan; nella CI quello software, llvmpipe, con
## xvfb) e la cache degli shader vuota:
## 1. la risalita da sola (scenes/risalita/risalita.tscn, i suoi tre oblò) e la torre da sola, costruita a pezzi e
##    preparata come nella sala (SalaTorre.costruisci_a_pezzi e prepara_materiali): lei di ogni oblò c'è già, nascosta
##    e ferma, prima di comparire, e la sua preparazione sta in un passo della costruzione;
## 2. quando lei compare (ObloLei._mostra) il codice ci mette meno di [constant COMPARSA_MAX] ms, e non istanzia niente
##    (0 nodi nuovi). Se la prima misura supera il limite, la zona si rifà da capo (risalita o torre nuova, preparata
##    allo stesso modo) e si misura di nuovo, fino a [constant RIPROVE_COMPARSA] volte: vale la misura più bassa, e si
##    stampano tutte. Un runner della CI rallentato in quel momento non fa cadere il test; una regressione vera (il
##    codice della comparsa più lento sempre) sì, perché resta sopra il limite in ogni misura;
## 3. guardandola e mentre si stacca (si scurisce fino al nero) il motore non compila pipeline che fermano il gioco
##    (monitor Performance "surface" a zero, "draw" al più [constant DRAW_TOLLERATE]; quelle "specialization", in
##    sottofondo, si stampano);
## 4. mentre si stacca nessuna parte di lei diventa trasparente (la trasparenza metteva la palpebra sotto l'occhio).
## Si misura il tempo del codice, non il fotogramma intero: col disegno sulla CPU la durata dei fotogrammi nella CI va
## su e giù da sola (come in test_torre_ingresso).
## Uso: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 \
##        --script res://tests/run.gd -- res://tests/test_oblo_leggeri.gd [senza_preparazione]
## Con OBLO_RITARDO_COMPARSA=<ms>,<volte> le prime <volte> misure della comparsa si allungano di <ms>, e con
## OBLO_RITARDO_TORRE=<ms>,<volte> quelle della costruzione della torre (per provare che un runner lento una volta non fa
## cadere il test e una regressione vera sì).
## Con "senza_preparazione" lei si crea al momento di comparire, com'era prima (per misurare il prima: i controlli
## falliscono).

const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
const RISALITA := "res://scenes/risalita/risalita.tscn"
## Quanto può costare il momento in cui lei compare (ms di codice, sulla CPU della CI).
const COMPARSA_MAX := 50.0
## Quante volte si rifà la zona e si rimisura la comparsa se la prima misura supera [constant COMPARSA_MAX] (nella CI,
## sulla stessa build: 0,7-6 ms di solito, una volta 87 e una 174 ms con un runner lento, rifatto il job 3 ms).
const RIPROVE_COMPARSA := 3
## Quanti ms della costruzione a pezzi della torre possono finire in un fotogramma (come in test_torre_ingresso; nella CI
## 17-61 ms di solito, 99 e 151 con un runner lento). Anche questa si rimisura con la torre rifatta, come la comparsa.
const CARICO_MAX := 100.0
## Guardandola e al distacco: quante pipeline "draw" si accettano (0 "surface" sempre). Col renderer software, da una
## prova all'altra, in uno degli oblò della risalita ne restano a volte 1-3, sempre diverse: varianti delle ombre e
## delle luci della zona, non dei materiali di lei (che si compilano tutti prima). Alla comparsa: 0.
const DRAW_TOLLERATE := 3

var _passed := 0
var _failed := 0
var _cam: Camera3D
var _senza := false
## La prima misura della comparsa, per gli oblò che l'hanno avuta sopra il limite (nome → ms).
var _prima_misura := {}
## Per provare il controllo stesso (OBLO_RITARDO_COMPARSA=<ms>,<volte>): le prime <volte> misure della comparsa si
## allungano di <ms>, come un runner lento (1 volta: passa rimisurando) o una regressione vera (tante: cade).
var _ritardo_ms := 0.0
var _ritardo_volte := 0
## Lo stesso per la costruzione della torre (OBLO_RITARDO_TORRE=<ms>,<volte>: il fotogramma più carico misurato più
## lungo di <ms>).
var _ritardo_torre_ms := 0.0
var _ritardo_torre_volte := 0


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
	if OS.has_environment("OBLO_RITARDO_COMPARSA"):
		var r := OS.get_environment("OBLO_RITARDO_COMPARSA").split(",")
		_ritardo_ms = float(r[0])
		_ritardo_volte = int(r[1]) if r.size() > 1 else 1
		print("(prova del controllo: le prime %d misure della comparsa allungate di %.0f ms)" % [_ritardo_volte, _ritardo_ms])
	if OS.has_environment("OBLO_RITARDO_TORRE"):
		var r := OS.get_environment("OBLO_RITARDO_TORRE").split(",")
		_ritardo_torre_ms = float(r[0])
		_ritardo_torre_volte = int(r[1]) if r.size() > 1 else 1
		print("(prova del controllo: le prime %d costruzioni della torre più cariche di %.0f ms)" % [_ritardo_torre_volte, _ritardo_torre_ms])
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

	# (con OBLO_SOLO_TORRE=1 solo la parte 2; con RITARDO_THREAD_TEST=<s> il thread rallentato apposta come in
	# test_attesa_zone, Game.ritardo_thread_test: un passo che aspettasse il thread si vedrebbe nel passo più lungo)
	if OS.has_environment("RITARDO_THREAD_TEST"):
		Game.ritardo_thread_test = float(OS.get_environment("RITARDO_THREAD_TEST"))
	if not OS.has_environment("OBLO_SOLO_TORRE"):
		print("1. La risalita da sola: i suoi tre oblò")
		if _senza:
			Engine.set_meta(&"oblo_senza_preparazione", true)
		var ris: Node3D = await _nuova_risalita()
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
		var lenti: Array[String] = []
		for o: ObloLei in obli:
			if not await _prova(o):
				lenti.append(String(o.get_parent().name) + "/" + String(o.name))
		ris.queue_free()
		await _frames(5)
		for nome in lenti:
			await _riprova(nome, _nuova_risalita)

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
	await _frames(10)
	var torre: SalaTorre = await _nuova_torre()
	# (la costruzione a pezzi: se il fotogramma più carico supera il limite, la torre si rifà e si rimisura, fino a
	# [constant RIPROVE_COMPARSA] volte, insieme alla comparsa; vale la misura più bassa, come per la comparsa)
	var carichi: Array[float] = [torre.fotogramma_piu_carico_ms]
	var passi: Array[String] = [torre.passo_piu_lungo]
	var nome := ""
	var veloce := true
	if torre.oblo:
		nome = String(torre.oblo.get_parent().name) + "/" + String(torre.oblo.name)
		veloce = await _prova(torre.oblo)
	else:
		check(false, "nella torre c'è l'oblò")
	var comparse: Array[float] = []
	if not veloce:
		comparse.append(_prima_misura[nome])
	var nodi := 0
	var k := 0
	while k < RIPROVE_COMPARSA and (carichi.min() >= CARICO_MAX or (not veloce and comparse.min() >= COMPARSA_MAX)):
		k += 1
		torre.queue_free()
		await _frames(5)
		torre = await _nuova_torre()
		await _fermi()
		carichi.append(torre.fotogramma_piu_carico_ms)
		passi.append(torre.passo_piu_lungo)
		if not veloce and torre.oblo:
			var m: Array = await _misura_comparsa(torre.oblo)
			comparse.append(m[0])
			nodi = maxi(nodi, m[1])
	var i_min := carichi.find(carichi.min())
	check(carichi.min() < CARICO_MAX, "la torre si costruisce a pezzi con lei dentro: al più %.0f ms in un fotogramma (al massimo %.0f; il passo più lungo: %s)%s" % [
			carichi.min(), CARICO_MAX, passi[i_min], _misure(carichi)])
	if not veloce:
		check(comparse.min() < COMPARSA_MAX and nodi == 0, "%s: lei compare in %.1f ms di codice (al più %.0f)%s, %d nodi nuovi" % [
				nome, comparse.min(), COMPARSA_MAX, _misure(comparse), nodi])
	torre.queue_free()
	campioni.clear()
	_fine()


## La risalita da sola, con le lei già preparate (a schermo nero nel gioco).
func _nuova_risalita() -> Node3D:
	var ris := (load(RISALITA) as PackedScene).instantiate() as Node3D
	add_child(ris)
	await _frames(40)
	return ris


## La torre da sola, costruita a pezzi e preparata come nella sala.
func _nuova_torre() -> SalaTorre:
	var torre := (load(TORRE) as PackedScene).instantiate() as SalaTorre
	torre.costruzione_a_pezzi = true
	torre.visible = false
	torre.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(torre)
	await torre.costruisci_a_pezzi()
	if _ritardo_torre_volte > 0:
		_ritardo_torre_volte -= 1
		torre.fotogramma_piu_carico_ms += _ritardo_torre_ms
	await torre.prepara_materiali(get_viewport())
	torre.visible = true
	torre.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(5)
	return torre


## Il momento in cui lei compare: la camera nel corridoio, girata dall'altra parte (lei compare col vetro fuori dalla
## vista), e il tempo del codice di ObloLei._mostra. Restituisce [ms, nodi nuovi].
func _misura_comparsa(o: ObloLei) -> Array:
	var da := o.global_transform * Vector3(0.2, 0.1, 2.6)
	_cam.global_position = da
	_cam.look_at(da + o.normale(), Vector3.UP)
	await _frames(5)
	var nodi_prima := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var t0 := Time.get_ticks_usec()
	o._mostra()
	if _ritardo_volte > 0:
		_ritardo_volte -= 1
		OS.delay_usec(int(_ritardo_ms * 1000.0))
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	return [ms, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodi_prima)]


## La prima misura della comparsa di [param nome] è sopra il limite: la zona si rifà da capo con [param rifai] (la
## risalita o la torre nuova) e si rimisura, fino a [constant RIPROVE_COMPARSA] volte; vale la misura più bassa. I nodi
## nuovi devono essere 0 in ogni misura.
func _riprova(nome: String, rifai: Callable) -> void:
	var misure: Array[float] = [_prima_misura[nome]]
	var nodi := 0
	for k in RIPROVE_COMPARSA:
		var zona: Node3D = await rifai.call()
		await _fermi()
		var o: ObloLei = null
		for c in zona.find_children("*", "ObloLei", true, false):
			if String(c.get_parent().name) + "/" + String(c.name) == nome:
				o = c
		if o == null:
			check(false, "%s: rifatta la zona, l'oblò c'è" % nome)
			zona.queue_free()
			return
		var m: Array = await _misura_comparsa(o)
		misure.append(m[0])
		nodi = maxi(nodi, m[1])
		zona.queue_free()
		await _frames(5)
		if m[0] < COMPARSA_MAX:
			break
	check(misure.min() < COMPARSA_MAX and nodi == 0, "%s: lei compare in %.1f ms di codice (al più %.0f)%s, %d nodi nuovi" % [
			nome, misure.min(), COMPARSA_MAX, _misure(misure), nodi])


## Aspetta che la zona appena rifatta smetta di creare nodi (come alla prima misura, che arriva dopo il giro della
## camera): al più 5 s, finché il numero dei nodi resta uguale per 20 fotogrammi.
func _fermi() -> void:
	var n := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var uguali := 0
	for i in 300:
		await get_tree().process_frame
		var ora := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		uguali = uguali + 1 if ora == n else 0
		n = ora
		if uguali >= 20:
			return


## Le misure ripetute, da stampare: niente se ce n'è una sola.
func _misure(m: Array[float]) -> String:
	if m.size() < 2:
		return ""
	return " (la più bassa delle misure %s ms, con la zona rifatta da capo)" % ", ".join(m.map(func(x: float) -> String: return "%.1f" % x))


## Tutti i controlli di un oblò. Restituisce falso se la comparsa ha superato [constant COMPARSA_MAX] (con 0 nodi
## nuovi): allora il controllo del tempo non si conta qui, lo fa [method _riprova] con la zona rifatta (le compilazioni
## e il resto si controllano qui, alla prima volta, con la cache degli shader vuota).
func _prova(o: ObloLei) -> bool:
	var nome := String(o.get_parent().name) + "/" + String(o.name)
	if not _senza:
		check(o.lei != null and is_instance_valid(o.lei) and o.lei.lei != null and not o.lei.lei.visible,
				"%s: lei c'è già, nascosta, prima di comparire" % nome)
	var prima := _conta()
	var m: Array = await _misura_comparsa(o)
	var ms: float = m[0]
	var nuovi: int = m[1]
	await _frames(4)
	var c := _diff(prima)
	var veloce := ms < COMPARSA_MAX
	if veloce or nuovi != 0 or _senza:
		check(veloce and nuovi == 0, "%s: lei compare in %.1f ms di codice (al più %.0f), %d nodi nuovi" % [nome, ms, COMPARSA_MAX, nuovi])
		veloce = true
	else:
		print("  (%s: la prima misura della comparsa è %.1f ms, sopra %.0f: si rimisura con la zona rifatta da capo)" % [nome, ms, COMPARSA_MAX])
		_prima_misura[nome] = ms
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
	return veloce


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)  # aspetta i caricamenti nel thread
