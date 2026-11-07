extends Node
## L'avvio sicuro dopo una chiusura di colpo (AvvioSicuro; ritocco dell'utente del 4 novembre, scelta A):
## - senza il segno della sessione di prima il titolo non chiede niente (il gioco identico a prima);
## - col segno rimasto (chiusura di colpo) il titolo chiede "Avvio sicuro?", col focus su "Avvio sicuro";
## - "Avvio normale": il titolo torna com'era, la qualità non cambia, niente riavvio;
## - "Avvio sicuro" fuori da Windows (un driver solo): qualità bassa, niente file del driver e niente riavvio;
## - chiusa di colpo prima di confermare la luminosità: la domanda aspetta la fine della calibrazione (l'Invio conferma
##   la luminosità, la qualità non cambia), poi compare col focus su "Avvio sicuro";
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

	# 3b) chiusura di colpo prima di confermare la luminosità (calibrato falso): la calibrazione sta sopra il titolo;
	# la domanda aspetta che si chiuda, e l'Invio conferma la luminosità senza toccare la qualità (collaudo finale di
	# grafica-2, 6 novembre)
	Grafica.applica_preset("alto")
	Grafica.valori["calibrato"] = false
	AvvioSicuro.chiesto = false
	AvvioSicuro.chiusa_di_colpo = true
	Game.call(&"_show_calibration")
	await _titolo()
	var cal: Node = null
	for c in Game.get_children():
		if c is CanvasLayer and String(c.scene_file_path).ends_with("calibrazione_luminosita.tscn"):
			cal = c
	check(cal != null, "calibrato falso: la calibrazione della luminosità è aperta sopra il titolo")
	d = get_tree().current_scene.get_node_or_null(^"DomandaAvvioSicuro")
	var fuoco := get_viewport().gui_get_focus_owner()
	check(d == null or fuoco != d.get(&"voce_si"), "con la luminosità aperta la domanda non c'è o non ha il focus")
	check(fuoco is Button and (fuoco as Button).text == "Conferma" and cal != null and cal.is_ancestor_of(fuoco),
		"con la luminosità aperta il focus è sul Conferma della luminosità (%s)" % [fuoco.get_path() if fuoco else "nessuno"])
	var invio := InputEventAction.new()
	invio.action = &"ui_accept"
	invio.pressed = true
	Input.parse_input_event(invio)
	await _frames(2)
	invio = invio.duplicate()
	invio.pressed = false
	Input.parse_input_event(invio)
	await _frames(10)
	check(not is_instance_valid(cal) or not cal.is_inside_tree(), "Invio conferma la luminosità: la calibrazione si chiude")
	check(bool(Grafica.valore("calibrato")), "Invio conferma la luminosità: calibrato vero")
	check(String(Grafica.valore("preset")) == "alto", "Invio sulla luminosità: la qualità non cambia")
	d = get_tree().current_scene.get_node_or_null(^"DomandaAvvioSicuro")
	check(d != null, "chiusa la luminosità, la domanda dell'avvio sicuro compare")
	if d:
		check(d.get_viewport().gui_get_focus_owner() == d.get(&"voce_si"), "chiusa la luminosità, il focus è su Avvio sicuro")
		d.call(&"rispondi", false)
		await _frames(5)
	check(String(Grafica.valore("preset")) == "alto", "Avvio normale dopo la luminosità: la qualità resta alta")

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
