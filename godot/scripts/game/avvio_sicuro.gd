class_name AvvioSicuro
extends RefCounted
## L'avvio sicuro dopo una chiusura di colpo (ritocco "avvio sicuro" dell'utente del 4 novembre, scelta A): se l'ultima
## partita non si è chiusa normalmente (crash, driver, processo ucciso), al titolo il gioco propone, con un solo
## pulsante, la qualità bassa e l'altro driver grafico (Vulkan o DirectX 12, solo su Windows). Il Continua funziona come
## sempre; senza una chiusura di colpo il gioco è identico a prima.
## - All'avvio (Game._ready) si guarda se c'è ancora il segno della sessione di prima, [constant SEGNO], e se ne scrive
##   uno nuovo; all'uscita normale (Game.esci, o l'albero che si chiude) si cancella. Rimasto lì = chiusura di colpo.
## - Il driver si cambia col file [constant OVERRIDE], che Godot legge all'avvio prima di scegliere il driver
##   (application/config/project_settings_override in project.godot); poi il gioco si riavvia da solo.
## Nei test (--script) e senza schermo non fa niente.

const SEGNO := "user://sessione_aperta"
const OVERRIDE := "user://avvio.cfg"
const DRIVER_SETTING := "rendering/rendering_device/driver.windows"

## L'ultima sessione si è chiusa di colpo (vale per tutta questa sessione, finché il giocatore risponde).
static var chiusa_di_colpo := false
## La domanda è già stata fatta in questa sessione.
static var chiesto := false
## Solo per i test (tests/test_avvio_sicuro.gd): attivo anche con --script.
static var forza := false


## All'avvio del gioco: guarda il segno di prima e ne scrive uno nuovo.
static func all_avvio() -> void:
	if not attivo():
		return
	chiusa_di_colpo = FileAccess.file_exists(SEGNO)
	var f := FileAccess.open(SEGNO, FileAccess.WRITE)
	if f:
		f.store_line("%s %s" % [Time.get_datetime_string_from_system(), RenderingServer.get_current_rendering_driver_name()])
		f.close()


## All'uscita normale: il segno si cancella.
static func all_uscita() -> void:
	if attivo() and FileAccess.file_exists(SEGNO):
		DirAccess.remove_absolute(SEGNO)


static func attivo() -> bool:
	# (non nei test, senza schermo, né con gli argomenti delle prove dopo il --: la Prova su Vulkan parte così)
	if forza:
		return true
	return not OS.get_cmdline_args().has("--script") and DisplayServer.get_name() != "headless" \
			and OS.get_cmdline_user_args().is_empty()


## Il driver grafico di adesso e l'altro da provare ("" se non ce n'è un altro: fuori da Windows c'è solo Vulkan).
static func driver_adesso() -> String:
	return RenderingServer.get_current_rendering_driver_name()


static func altro_driver() -> String:
	if OS.get_name() != "Windows":
		return ""
	return "vulkan" if driver_adesso() == "d3d12" else "d3d12"


static func nome_driver(d: String) -> String:
	return {"vulkan": "Vulkan", "d3d12": "DirectX 12"}.get(d, d)


## La domanda al titolo: va fatta adesso?
static func da_chiedere() -> bool:
	return chiusa_di_colpo and not chiesto and attivo()


## Il testo sotto la domanda, con l'altro driver se c'è.
static func nota() -> String:
	var d := altro_driver()
	if d == "":
		return Lingua.t("L'ultima volta il gioco si è chiuso di colpo. L'avvio sicuro mette la qualità bassa.")
	return Lingua.t("L'ultima volta il gioco si è chiuso di colpo. L'avvio sicuro mette la qualità bassa e prova l'altro driver grafico (%s).") % nome_driver(d)


## La risposta del giocatore. Con l'avvio sicuro: qualità bassa (salvata come scelta sua) e, se c'è, l'altro driver dal
## prossimo avvio, con un riavvio subito. Vero se il gioco si sta riavviando.
static func rispondi(sicuro: bool, albero: SceneTree) -> bool:
	chiesto = true
	chiusa_di_colpo = false
	if not sicuro:
		return false
	# (una scelta del giocatore: niente prova automatica e niente «scelto in automatico»)
	Grafica.applica_preset("basso")
	var d := altro_driver()
	if d == "":
		return false
	var cfg := ConfigFile.new()
	cfg.load(OVERRIDE)
	cfg.set_value("rendering", "rendering_device/driver.windows", d)
	if cfg.save(OVERRIDE) != OK:
		return false
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	Game.esci()
	return true
