extends Node
## La qualità scelta in automatico al primo avvio (QualitaAutomatica; ritocco dell'utente del 4 novembre, scelta A):
## - da "alto": fluido -> prova "ultra"; non fluido -> prova "medio"; mai sotto "medio" (nebbia e luci come sono);
## - alla fine qualita_provata è vera e scelta_automatica è il preset scelto; nelle opzioni «scelto in automatico: …»;
## - una scelta a mano (anche prima della prova) resta del giocatore: la prova non si rifà e la scritta sparisce;
## - la misura vera finisce in pochi secondi; chi ha già le impostazioni (senza la chiave) non fa la prova.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_qualita_automatica.gd

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	check(bool(Grafica.PREDEFINITI["qualita_provata"]), "chi ha già le impostazioni (senza la chiave) non rifà la prova")

	# 1) le scelte, con la misura finta
	var casi := [
		[{"alto": true, "ultra": true}, "ultra", ["alto", "ultra"]],
		[{"alto": true, "ultra": false}, "alto", ["alto", "ultra"]],
		[{"alto": false, "medio": true}, "medio", ["alto", "medio"]],
		[{"alto": false, "medio": false}, "medio", ["alto", "medio"]],
	]
	for c in casi:
		var esito: Dictionary = c[0]
		Grafica.applica_preset("alto")
		Grafica.valori["qualita_provata"] = false
		var q := QualitaAutomatica.avvia(get_tree())
		q.misura_finta = func(p: String) -> bool: return bool(esito.get(p, false))
		var scelto: String = await q.finita
		var provati := (q.esiti as Array).map(func(e): return e[0])
		check(scelto == c[1] and String(Grafica.valore("preset")) == c[1], "fluidi %s: scelto %s (%s)" % [str(esito), scelto, c[1]])
		check(provati == c[2], "provati in ordine %s (%s)" % [str(provati), str(c[2])])
		check(bool(Grafica.valore("qualita_provata")) and String(Grafica.valore("scelta_automatica")) == c[1], "la prova è segnata come fatta, col preset scelto")
		check(int(Grafica.valore("nebbia")) >= 1, "la nebbia resta volumetrica")
	check(not Grafica.prova_automatica, "finita la prova i cambi tornano del giocatore")

	# 2) le opzioni: «scelto in automatico: …», poi una scelta a mano
	var menu: CanvasLayer = load("res://addons/grafica/menu_opzioni.tscn").instantiate()
	get_tree().root.add_child(menu)
	await _frames(3)
	var scritta := menu.find_child("SceltoInAutomatico", true, false) as Label
	check(scritta != null and scritta.visible and scritta.text == "scelto in automatico: Medio", "nelle opzioni: %s" % (scritta.text if scritta else "-"))
	Grafica.applica_preset("alto")
	await _frames(2)
	check(scritta != null and not scritta.visible, "cambiato a mano: la scritta sparisce")
	check(String(Grafica.valore("scelta_automatica")) == "" and bool(Grafica.valore("qualita_provata")), "cambiato a mano: la scelta è del giocatore")
	TranslationServer.set_locale("en")
	Grafica.valori["scelta_automatica"] = "alto"
	Grafica.impostazione_cambiata.emit("preset", "alto")
	await _frames(2)
	check(scritta != null and scritta.visible and scritta.text == "chosen automatically: High", "in inglese: %s" % (scritta.text if scritta else "-"))
	TranslationServer.set_locale("it")
	menu.queue_free()

	# 3) una scelta a mano prima della prova (dal titolo): niente prova
	Grafica.valori["qualita_provata"] = false
	Grafica.imposta("ombre", 1)
	check(bool(Grafica.valore("qualita_provata")), "un'opzione della qualità cambiata a mano prima della prova: la prova non si fa")
	Grafica.valori["qualita_provata"] = false
	Grafica.applica_preset("basso")
	check(bool(Grafica.valore("qualita_provata")) and String(Grafica.valore("preset")) == "basso", "un preset scelto a mano prima della prova: resta quello")

	# 4) la misura vera (qui senza schermo): finisce in pochi secondi
	Grafica.applica_preset("alto")
	Grafica.valori["qualita_provata"] = false
	var t := Time.get_ticks_msec()
	var q := QualitaAutomatica.avvia(get_tree())
	var scelto: String = await q.finita
	var durata := (Time.get_ticks_msec() - t) / 1000.0
	check(scelto in ["medio", "alto", "ultra"] and durata < QualitaAutomatica.MASSIMO + 2.0, "misura vera: %s in %.1f s %s" % [scelto, durata, str(q.esiti)])
	check(not QualitaAutomatica.da_fare(), "nei test automatici la prova non parte da sola")

	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


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
