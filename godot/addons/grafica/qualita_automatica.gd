class_name QualitaAutomatica
extends Node
## La qualità scelta in automatico al primo avvio (ritocco "qualità" dell'utente del 4 novembre, scelta A): la prima
## volta che si entra nella sala, dietro lo schermo ancora nero del caricamento, una prova di pochi secondi misura la
## sala vera e sceglie il preset più alto che resta fluido. Nelle opzioni si legge «scelto in automatico: …»; una scelta
## fatta a mano resta del giocatore (Grafica._scelta_a_mano: la prova non si rifà).
## - Si parte da "alto" (il preset del primo avvio): se è fluido si prova "ultra", se no "medio".
## - Non scende sotto "medio": nebbia e luci restano come sono (col "basso" la nebbia volumetrica diventa semplice);
##   il "basso" resta una scelta a mano, o l'avvio sicuro.
## - Fluido: la mediana dei fotogrammi entro [constant SOGLIA_MS] (tempo della scheda video, se il driver lo dà, e
##   tempo del fotogramma intero, che con la sincronia verticale a 60 Hz sta sui 16,7 ms).
## - Il giocatore intanto è fermo (input spento), e alla fine lo schermo si schiarisce come sempre.

## Mediana massima del tempo della scheda video per un fotogramma (ms): 60 fps con margine.
const SOGLIA_GPU_MS := 14.0
## Mediana massima del fotogramma intero (ms): con la sincronia a 60 Hz un fotogramma perso porta a 33 ms.
const SOGLIA_MS := 20.0
## Per ogni preset: il tempo per assestarsi (pipeline, ombre, nebbia) e quello delle misure (s).
const ASSESTAMENTO := 0.5
const MISURA := 0.8
## Massimo in tutto (s): poi si tiene l'ultimo preset fluido.
const MASSIMO := 6.0

## Gli esiti delle misure, per i test: [[preset, ms_gpu, ms_fotogramma, fluido], ...].
var esiti: Array = []
## Solo per i test: sostituisce la misura ([param preset] -> fluido).
var misura_finta: Callable
signal finita(preset: String)

var _frame_assestamento := 0


## La prova va fatta adesso? (primo avvio, nessuna scelta a mano; mai nei test automatici, che la avviano da soli)
static func da_fare() -> bool:
	return not bool(Grafica.valore("qualita_provata")) and (not Game.is_automated() or forza_nei_test)


## Solo per i test (tests/test_primo_ingresso.gd): la prova si fa anche con --script, dalla schermata di caricamento vera,
## e la misura è [member misura_finta_test] (preset -> fluido) se c'è.
static var forza_nei_test := false
static var misura_finta_test: Callable


## Avvia la prova sull'albero (resta fra un cambio di scena e l'altro) e poi schiarisce lo schermo dopo
## [param frame_di_assestamento] fotogrammi, come il caricamento.
static func avvia(albero: SceneTree, frame_di_assestamento := 0) -> QualitaAutomatica:
	var q := QualitaAutomatica.new()
	q.name = "QualitaAutomatica"
	q._frame_assestamento = frame_di_assestamento
	if misura_finta_test.is_valid():
		q.misura_finta = misura_finta_test
	albero.root.add_child(q)
	return q


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prova.call_deferred()


func _prova() -> void:
	var inizio := Time.get_ticks_msec()
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var giocatore_fermato := await _ferma_giocatore()
	Grafica.prova_automatica = true
	var preset := "alto"
	var scelto := ""
	var provati := {}
	while preset != "" and not provati.has(preset):
		provati[preset] = true
		var fluido := await _misura(preset, rid)
		if fluido:
			scelto = preset
			preset = "ultra" if preset == "alto" else ""
		else:
			preset = "medio" if preset == "alto" else ""
		if Time.get_ticks_msec() - inizio > MASSIMO * 1000.0:
			break
	if scelto == "":
		scelto = "medio"
	if String(Grafica.valore("preset")) != scelto:
		Grafica.applica_preset(scelto)
	Grafica.valori["qualita_provata"] = true
	Grafica.valori["scelta_automatica"] = scelto
	Grafica.prova_automatica = false
	Grafica.salva()
	RenderingServer.viewport_set_measure_render_time(rid, false)
	print("Qualità automatica: %s (%s)" % [scelto, str(esiti)])
	if giocatore_fermato and is_instance_valid(GameState.player) and not GameState.player.input_enabled:
		GameState.player.input_enabled = true
	if Dissolvenza.presente(get_tree()):
		Dissolvenza.di(get_tree()).schiarisci(1.6, _frame_assestamento)
	finita.emit(scelto)
	queue_free()


## Prova [param preset]: vero se resta fluido.
func _misura(preset: String, rid: RID) -> bool:
	Grafica.applica_preset(preset)
	if misura_finta.is_valid():
		await get_tree().process_frame
		var f: bool = misura_finta.call(preset)
		esiti.append([preset, 0.0, 0.0, f])
		return f
	await _attendi(ASSESTAMENTO)
	var gpu: Array[float] = []
	var tot: Array[float] = []
	var t0 := Time.get_ticks_usec()
	var prima := t0
	while Time.get_ticks_usec() - t0 < MISURA * 1e6:
		await get_tree().process_frame
		var adesso := Time.get_ticks_usec()
		tot.append((adesso - prima) / 1000.0)
		prima = adesso
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	var m_gpu := _mediana(gpu)
	var m_tot := _mediana(tot)
	# (senza il tempo della scheda, cioè 0, conta solo il fotogramma intero)
	var fluido := m_tot <= SOGLIA_MS and (m_gpu <= 0.0 or m_gpu <= SOGLIA_GPU_MS)
	esiti.append([preset, snappedf(m_gpu, 0.1), snappedf(m_tot, 0.1), fluido])
	return fluido


## Il giocatore fermo durante la prova (vero se l'ha fermato qui).
func _ferma_giocatore() -> bool:
	for i in 30:
		if is_instance_valid(GameState.player):
			break
		await get_tree().process_frame
	var p := GameState.player
	if is_instance_valid(p) and p.input_enabled:
		p.input_enabled = false
		return true
	return false


func _attendi(secondi: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < secondi * 1000.0:
		await get_tree().process_frame


static func _mediana(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]
