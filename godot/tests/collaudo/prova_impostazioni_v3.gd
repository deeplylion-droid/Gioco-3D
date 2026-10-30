extends Node
## Collaudo delle impostazioni versione 3 (nebbia 0.3.17: la grana spenta per tutti, una volta): parte da un
## settings.cfg come lo salvava la 0.3.16 (versione 2, grana accesa) e controlla che dopo la grana sia spenta e tutto il
## resto resti com'era (lingua, nebbia viola, volumi, FOV, glow); poi che, riaccesa dal giocatore, la grana resti accesa.
## Va lanciato con -s (non --script: con --script Lingua mette sempre l'italiano), in fasi, una per avvio:
##   godot --headless --path godot -s res://tests/run.gd -- res://tests/collaudo/prova_impostazioni_v3.gd <fase> [nebbia]
## fasi: scrivi (il file della 0.3.16, con "nebbia" = true/false), leggi (dopo il caricamento; salva), accendi (il
## giocatore riaccende la grana; salva), rileggi. Esce con 1 se un controllo fallisce. Il settings.cfg vero va salvato
## a parte prima e rimesso dopo.

const PERCORSO := "user://settings.cfg"
const FOV := 75.0
const VOLUMI := {"generale": 0.6, "musica": 0.4, "ambiente": 0.7, "effetti": 0.9}

var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print("  ok  " if cond else "  KO  ", msg)
	if not cond:
		_ko += 1


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var fase: String = a[1]
	var nebbia := a.size() < 3 or a[2] != "false"
	match fase:
		"scrivi":
			var cfg := ConfigFile.new()
			for k in Grafica.PREDEFINITI:
				cfg.set_value("grafica", k, Grafica.PREDEFINITI[k])
			cfg.set_value("grafica", "fov", FOV)
			cfg.set_value("grafica", "grana", true)
			cfg.set_value("grafica", "glow", true)
			cfg.set_value("grafica", "nebbia_viola", nebbia)
			cfg.set_value("grafica", "versione", 2)
			for k in VOLUMI:
				cfg.set_value("audio", k, VOLUMI[k])
			cfg.set_value("audio", "versione", 2)
			cfg.set_value("lingua", "lingua", "en")
			cfg.save(PERCORSO)
			print("scritto il settings.cfg della 0.3.16 (nebbia viola %s)" % nebbia)
		"leggi":
			var g: Dictionary = Grafica.valori
			check(g["grana"] == false, "la grana è spenta (era accesa)")
			check(g["glow"] == true, "il glow resta acceso come salvato")
			check(is_equal_approx(float(g["fov"]), FOV), "il FOV resta %.0f (%s)" % [FOV, g["fov"]])
			check(g["nebbia_viola"] == nebbia, "la nebbia viola resta %s (%s)" % [nebbia, g["nebbia_viola"]])
			check(Lingua.lingua == "en", "la lingua resta l'inglese (%s)" % Lingua.lingua)
			for k in VOLUMI:
				check(is_equal_approx(Audio.volume(k), VOLUMI[k]), "volume %s resta %.1f (%.2f)" % [k, VOLUMI[k], Audio.volume(k)])
			Grafica.salva_su_disco = true
			Grafica.salva()
			var cfg := ConfigFile.new()
			cfg.load(PERCORSO)
			check(int(cfg.get_value("grafica", "versione", 0)) == 3, "salvato con la versione 3")
			check(cfg.get_value("grafica", "grana") == false, "salvata la grana spenta")
			check(cfg.get_value("lingua", "lingua", "") == "en" and is_equal_approx(float(cfg.get_value("audio", "musica", 0.0)), 0.4),
					"nel file restano la lingua e i volumi")
		"accendi":
			Grafica.salva_su_disco = true
			Grafica.imposta("grana", true)
			Grafica.salva()
			print("il giocatore riaccende la grana")
		"rileggi":
			check(Grafica.valori["grana"] == true, "riaccesa dal giocatore, la grana resta accesa (la versione 3 la spegne una volta sola)")
			check(Lingua.lingua == "en" and is_equal_approx(float(Grafica.valori["fov"]), FOV), "lingua e FOV ancora come salvati")
	print("RISULTATO %s: %d falliti" % [fase, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
