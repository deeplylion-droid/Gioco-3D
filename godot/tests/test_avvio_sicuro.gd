extends Node
## L'avvio sicuro dopo una chiusura di colpo (AvvioSicuro; ritocco dell'utente del 4 novembre, scelta A):
## - senza il segno della sessione di prima il titolo non chiede niente (il gioco identico a prima);
## - col segno rimasto (chiusura di colpo) il titolo chiede "Avvio sicuro?", col focus su "Avvio sicuro";
## - "Avvio normale": il titolo torna com'era, la qualità non cambia, niente riavvio;
## - "Avvio sicuro" fuori da Windows (un driver solo): qualità bassa, niente file del driver e niente riavvio;
## - con la luminosità mai confermata (calibrato falso) niente calibrazione: la domanda compare subito col focus su
##   "Avvio sicuro";
## - all'uscita normale il segno si cancella; i testi ci sono in italiano e in inglese.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_avvio_sicuro.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	AvvioSicuro.forza = true
	DirAccess.remove_absolute(AvvioSicuro.SEGNO)
	DirAccess.remove_absolute(AvvioSicuro.OVERRIDE)

	# 1) senza chiusura di colpo: niente domanda
	AvvioSicuro.all_avvio()
	check(not AvvioSicuro.chiusa_di_colpo and FileAccess.file_exists(AvvioSicuro.SEGNO), "all'avvio il segno si scrive, e senza quello di prima niente chiusura di colpo")
	await _titolo()
	check(get_tree().current_scene.get_node_or_null(^"DomandaAvvioSicuro") == null, "senza chiusura di colpo il titolo non chiede niente")

	# 2) il segno rimasto: chiusura di colpo, la domanda
	AvvioSicuro.chiesto = false
	AvvioSicuro.all_avvio()
	check(AvvioSicuro.chiusa_di_colpo, "col segno rimasto dalla volta prima: chiusura di colpo")
	Grafica.applica_preset("alto")
	await _titolo()
	var d := get_tree().current_scene.get_node_or_null(^"DomandaAvvioSicuro")
	check(d != null, "dopo una chiusura di colpo il titolo chiede l'avvio sicuro")
	if d:
		check(String(d.get(&"testo_si")) == "Avvio sicuro" and String(d.get(&"testo_no")) == "Avvio normale", "le voci sono Avvio sicuro e Avvio normale")
		check(d.get_viewport().gui_get_focus_owner() == d.get(&"voce_si"), "il focus parte su Avvio sicuro")
		d.call(&"rispondi", false)
		await _frames(5)
	check(String(Grafica.valore("preset")) == "alto", "Avvio normale: la qualità resta com'era")
	check(not AvvioSicuro.da_chiedere(), "Avvio normale: non chiede più in questa sessione")

	# 3) avvio sicuro (qui fuori da Windows: un driver solo)
	AvvioSicuro.chiesto = false
	AvvioSicuro.chiusa_di_colpo = true
	await _titolo()
	d = get_tree().current_scene.get_node_or_null(^"DomandaAvvioSicuro")
	if d:
		d.call(&"rispondi", true)
		await _frames(5)
	check(String(Grafica.valore("preset")) == "basso", "Avvio sicuro: qualità bassa")
	if OS.get_name() != "Windows":
		check(not FileAccess.file_exists(AvvioSicuro.OVERRIDE), "fuori da Windows niente file del driver (c'è solo Vulkan)")
		check(not Game.uscendo, "fuori da Windows niente riavvio")
	check(get_tree().current_scene.get_node_or_null(^"DomandaAvvioSicuro") == null, "la domanda si chiude")

	# 3b) chiusura di colpo con la luminosità mai confermata (calibrato falso): niente calibrazione al primo avvio
	# (richiesta dell'utente del 7 novembre), la domanda compare subito col focus su Avvio sicuro
	Grafica.applica_preset("alto")
	Grafica.valori["calibrato"] = false
	AvvioSicuro.chiesto = false
	AvvioSicuro.chiusa_di_colpo = true
	await _titolo()
	var cal := Game.find_children("*", "CalibrazioneLuminosita", true, false)
	cal.append_array(get_tree().current_scene.find_children("*", "CalibrazioneLuminosita", true, false))
	check(cal.is_empty() and not Game.has_method(&"_show_calibration"), "calibrato falso: nessuna calibrazione sopra il titolo")
	d = get_tree().current_scene.get_node_or_null(^"DomandaAvvioSicuro")
	check(d != null, "calibrato falso e chiusura di colpo: la domanda dell'avvio sicuro compare subito")
	if d:
		check(d.get_viewport().gui_get_focus_owner() == d.get(&"voce_si"), "calibrato falso: il focus è su Avvio sicuro")
		d.call(&"rispondi", false)
		await _frames(5)
	check(String(Grafica.valore("preset")) == "alto", "Avvio normale: la qualità resta alta")

	# 4) l'uscita normale cancella il segno; i testi tradotti
	AvvioSicuro.all_uscita()
	check(not FileAccess.file_exists(AvvioSicuro.SEGNO), "all'uscita normale il segno si cancella")
	for k in ["Avvio sicuro?", "Avvio sicuro", "Avvio normale"]:
		check(TranslationServer.get_translation_object("en").get_message(k) != StringName(), "testo in inglese per \"%s\"" % k)
	TranslationServer.set_locale("en")
	check(AvvioSicuro.nota().begins_with("Last time"), "la nota in inglese (%s)" % AvvioSicuro.nota())
	TranslationServer.set_locale("it")
	AvvioSicuro.forza = false
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _titolo() -> void:
	get_tree().change_scene_to_file(TITOLO)
	await _frames(40)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)
