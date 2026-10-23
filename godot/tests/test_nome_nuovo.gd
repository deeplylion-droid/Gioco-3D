extends Node
## Test del nome nuovo del gioco (Jilly Jubilee, 22 ottobre) e del passaggio dei dati dalla cartella
## user:// del vecchio nome (Splash Lagoon): il nome del progetto e dell'esportazione; DatiVecchi è il
## primo autoload; eredita() copia impostazioni e salvataggio solo nella cartella nuova ancora vuota e
## non sovrascrive mai; un Godot vero, avviato con una cartella dei dati finta che ha solo la cartella
## vecchia, ritrova le impostazioni e il salvataggio nella cartella nuova (solo su Linux: XDG_DATA_HOME).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_nome_nuovo.gd

const NOME := "Jilly Jubilee"
const DatiVecchi := preload("res://scripts/game/dati_vecchi.gd")

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("Il nome")
	check(ProjectSettings.get_setting("application/config/name") == NOME, "il progetto si chiama %s" % NOME)
	check(OS.get_user_data_dir().get_file() == NOME, "la cartella dei dati è quella del nome nuovo")
	var preset := ConfigFile.new()
	check(preset.load("res://export_presets.cfg") == OK, "export_presets.cfg si legge")
	for sezione in preset.get_sections():
		if not sezione.ends_with(".options") and preset.has_section_key(sezione, "export_path"):
			var percorso: String = preset.get_value(sezione, "export_path")
			check(percorso.get_file().get_basename() == "JillyJubilee",
				"%s esporta %s" % [preset.get_value(sezione, "name"), percorso.get_file()])
		if sezione.ends_with(".options") and preset.has_section_key(sezione, "application/product_name"):
			check(preset.get_value(sezione, "application/product_name") == NOME
				and preset.get_value(sezione, "application/file_description") == NOME,
				"%s: nome e descrizione del file sono %s" % [sezione, NOME])

	print("Il primo autoload")
	var primo := get_tree().root.get_child(0)
	check(primo.name == "DatiVecchi" and primo.get_script() == DatiVecchi,
		"DatiVecchi è il primo autoload (copia prima che gli altri leggano le impostazioni)")

	print("eredita()")
	var base := ProjectSettings.globalize_path("user://prova_nome_nuovo")
	_svuota(base)
	var vecchia := base.path_join("Splash Lagoon")
	var nuova := base.path_join(NOME)
	DirAccess.make_dir_recursive_absolute(vecchia.path_join("logs"))
	DirAccess.make_dir_recursive_absolute(nuova.path_join("logs"))
	_scrivi(vecchia.path_join("settings.cfg"), "[grafica]\npreset=\"basso\"\n")
	_scrivi(vecchia.path_join("salvataggio.json"), "{\"checkpoint\": \"vecchio\"}")
	_scrivi(vecchia.path_join("logs/godot.log"), "log")
	_scrivi(vecchia.path_join("scatto.jpg"), "jpg")
	var n := DatiVecchi.eredita(vecchia, nuova)
	check(n == 2, "copia impostazioni e salvataggio nella cartella nuova (che ha solo i log): %d file" % n)
	check(_leggi(nuova.path_join("settings.cfg")).contains("basso")
		and _leggi(nuova.path_join("salvataggio.json")).contains("vecchio"), "i file copiati sono uguali ai vecchi")
	check(not FileAccess.file_exists(nuova.path_join("scatto.jpg"))
		and not FileAccess.file_exists(nuova.path_join("logs/godot.log")), "il resto non si copia")
	_scrivi(nuova.path_join("settings.cfg"), "[grafica]\npreset=\"alto\"\n")
	check(DatiVecchi.eredita(vecchia, nuova) == 0 and _leggi(nuova.path_join("settings.cfg")).contains("alto"),
		"la seconda volta non copia e non sovrascrive niente")
	DirAccess.remove_absolute(nuova.path_join("settings.cfg"))
	_scrivi(nuova.path_join("salvataggio.json"), "{\"checkpoint\": \"nuovo\"}")
	check(DatiVecchi.eredita(vecchia, nuova) == 0 and not FileAccess.file_exists(nuova.path_join("settings.cfg")),
		"se la cartella nuova ha già un salvataggio non prende niente dalla vecchia")
	check(DatiVecchi.eredita(base.path_join("non_esiste"), base.path_join("altra")) == 0,
		"senza la cartella vecchia non fa niente")

	if OS.get_name() == "Linux":
		print("Un avvio vero col nome nuovo")
		# XDG_DATA_HOME finto: <base>/xdg/godot/app_userdata/<nome>
		var xdg := base.path_join("xdg")
		var vera_vecchia := xdg.path_join("godot/app_userdata/Splash Lagoon")
		var vera_nuova := xdg.path_join("godot/app_userdata").path_join(NOME)
		DirAccess.make_dir_recursive_absolute(vera_vecchia)
		_scrivi(vera_vecchia.path_join("settings.cfg"), "[audio]\nmusica=0.25\n")
		_scrivi(vera_vecchia.path_join("salvataggio.json"), "{\"checkpoint\": \"da_splash_lagoon\"}")
		var uscita := []
		var codice := OS.execute("env", ["XDG_DATA_HOME=" + xdg, OS.get_executable_path(), "--headless",
				"--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/solo_autoload.gd"],
				uscita, true)
		check(codice == 0, "il Godot di prova parte e si chiude (codice %d)" % codice)
		check(_leggi(vera_nuova.path_join("salvataggio.json")).contains("da_splash_lagoon"),
			"al primo avvio il salvataggio di Splash Lagoon è nella cartella di %s" % NOME)
		var cfg := ConfigFile.new()
		check(cfg.load(vera_nuova.path_join("settings.cfg")) == OK and is_equal_approx(float(cfg.get_value("audio", "musica", -1.0)), 0.25),
			"e anche le impostazioni (il volume della musica è quello vecchio)")
		check(FileAccess.file_exists(vera_vecchia.path_join("salvataggio.json")), "la cartella vecchia resta com'era")
		if _failed > 0:
			print("".join(uscita))
	_svuota(base)
	_fine()


func _scrivi(percorso: String, testo: String) -> void:
	var f := FileAccess.open(percorso, FileAccess.WRITE)
	f.store_string(testo)
	f.close()


func _leggi(percorso: String) -> String:
	return FileAccess.get_file_as_string(percorso) if FileAccess.file_exists(percorso) else ""


func _svuota(cartella: String) -> void:
	var d := DirAccess.open(cartella)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for c in d.get_directories():
		_svuota(cartella.path_join(c))
	DirAccess.remove_absolute(cartella)


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
