extends Node
## Test dell'uscita dal gioco con un caricamento nel thread ancora in corso (CI di lavoro/godot 58cc633:
## test_acquari passava e poi Godot moriva con "Aborted" 12 s dopo il quit(), con la torre in precarica).
## In prova: uscire appena il caricamento finisce fa fermare Godot per sempre o abortire (134); Game.esci()
## aspetta la fine fotogramma per fotogramma e poi ancora almeno 30 fotogrammi e 1 s.
## Avvia tre Godot di prova (tests/prova_uscita_caricamento.gd) che chiudono il gioco mentre caricano:
## la torre appena chiesta, la sala che si ricarica a un checkpoint con la torre in caricamento (come la
## fine di test_acquari) e il livello dalla schermata di caricamento. Per ognuno: esce con 0, all'uscita
## Game ha aspettato il caricamento (non l'ha lasciato a metà mentre Godot smonta tutto). In più il respawn
## durante l'attesa di Game.esci() (la fine di test_tappa8, CI di lavoro/godot 2a4f4a8a: lei ti prende, la sala
## ripartiva e richiedeva la torre mentre si usciva): la sala non riparte e niente si carica a metà.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_uscita.gd

const MODI := [["torre", "0.3"], ["riparti", "0"], ["livello", "1"], ["riparti_dopo"]]

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for modo in MODI:
		print("Uscita: %s" % " ".join(modo))
		var uscita := []
		var argomenti := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script",
				"res://tests/run.gd", "--", "res://tests/prova_uscita_caricamento.gd"]
		argomenti.append_array(modo)
		# timeout: un Godot fermo all'uscita non deve bloccare la CI
		var codice := OS.execute("timeout", ["300", OS.get_executable_path()] + argomenti, uscita, true)
		var testo := "".join(uscita)
		check(codice == 0, "il gioco si chiude con 0 (codice %d)" % codice)
		check(testo.contains("USCITA"), "si è chiuso mentre caricava")
		if modo[0] == "riparti_dopo":
			check(testo.contains("sala non ricaricata (si sta uscendo)"), "mentre si esce il respawn non ricarica la sala")
		elif testo.contains("già finita"):
			# a volte, mentre la sala si ricarica, la torre finisce di caricare prima dell'uscita
			print("  (la torre aveva già finito di caricare: niente da aspettare)")
		else:
			# (con la torre si caricano nel thread anche i file dell'inseguimento: più caricamenti insieme, blocchi del
			# 25 ottobre)
			var aspettati := RegEx.create_from_string("Uscita: aspettati [1-9][0-9]* caricamenti nel thread")
			check(aspettati.search(testo) != null, "all'uscita ha aspettato il caricamento")
		check(not testo.contains("Parse Error: Failed"), "il caricamento non è stato troncato a metà")
		check(not testo.contains("Resource file not found"), "niente caricamenti rotti mentre Godot si chiude")
		if codice != 0 or _failed > 0:
			print(testo.right(3000))
	_fine()


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)
