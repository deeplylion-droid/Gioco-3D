extends Node
## Test del primo ingresso nella sala con un profilo nuovo (collaudo della 0.3.22: al primo avvio di ogni giocatore la
## qualità automatica partiva con un albero nullo, lo schermo restava nero e l'exe release andava in segfault):
## dal titolo, Nuova partita, la schermata di caricamento vera fino alla sala, con qualita_provata falso e senza la
## scorciatoia dei test (QualitaAutomatica.forza_nei_test; la misura è finta, così il test è veloce):
## 1. la prova della qualità parte (il nodo QualitaAutomatica entra nell'albero) e finisce;
## 2. la qualità è segnata come provata, col preset scelto;
## 3. alla fine lo schermo si schiarisce (il velo nero della dissolvenza va a zero);
## 4. finita la prova, il suo nodo se ne va.
## Che la prova parta si vede dal segnale node_added dell'albero: con la misura finta il nodo vive 2-3 fotogrammi, e
## guardarlo ogni 5 fotogrammi a volte non lo trovava (CI di main della 0.3.22, 42456683462, con la prova fatta).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_primo_ingresso.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var _ok := 0
var _ko := 0
var _prova_vista := false


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _nodo_aggiunto(n: Node) -> void:
	if n is QualitaAutomatica:
		_prova_vista = true


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	Grafica.valori["qualita_provata"] = false
	Grafica.valori["scelta_automatica"] = ""
	QualitaAutomatica.forza_nei_test = true
	# (misura finta: "alto" fluido, "ultra" no: la prova sceglie "alto")
	QualitaAutomatica.misura_finta_test = func(preset: String) -> bool: return preset == "alto"
	check(QualitaAutomatica.da_fare(), "profilo nuovo: la prova della qualità è da fare")
	get_tree().change_scene_to_file(TITOLO)
	await _frames(30)
	get_tree().node_added.connect(_nodo_aggiunto)
	get_tree().current_scene.call(&"_avvia_nuova_partita")
	# la sala: fino a 10 minuti (il caricamento nel thread), poi la prova
	var fino := Time.get_ticks_msec() + 600000
	while Time.get_ticks_msec() < fino:
		await _frames(5)
		if get_tree().root.get_node_or_null(^"QualitaAutomatica") != null:
			_prova_vista = true
		if bool(Grafica.valore("qualita_provata")):
			break
	get_tree().node_added.disconnect(_nodo_aggiunto)
	check(_prova_vista, "entrando nella sala la prova della qualità parte")
	check(bool(Grafica.valore("qualita_provata")), "la prova finisce: qualità segnata come provata")
	check(String(Grafica.valore("scelta_automatica")) == "alto" and String(Grafica.valore("preset")) == "alto",
		"il preset scelto dalla prova è applicato (%s)" % Grafica.valore("preset"))
	var sc := get_tree().current_scene
	check(sc != null and String(sc.name) != "Caricamento", "siamo nella sala (%s)" % (sc.name if sc else "nessuna scena"))
	# il velo nero si schiarisce
	var schiarito := false
	fino = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < fino:
		await _frames(5)
		if not Dissolvenza.presente(get_tree()) or Dissolvenza.di(get_tree()).opacita() <= 0.01:
			schiarito = true
			break
	check(schiarito, "alla fine lo schermo si schiarisce (velo %.2f)" % (Dissolvenza.di(get_tree()).opacita() if Dissolvenza.presente(get_tree()) else 0.0))
	check(get_tree().root.get_node_or_null(^"QualitaAutomatica") == null, "finita la prova, il suo nodo se ne va")
	QualitaAutomatica.forza_nei_test = false
	QualitaAutomatica.misura_finta_test = Callable()
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
