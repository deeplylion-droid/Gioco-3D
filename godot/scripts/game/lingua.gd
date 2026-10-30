extends Node
## La lingua del gioco (autoload Lingua): italiano o inglese (scelta approvata dall'utente il 25 ottobre: "anche
## eventuali scritte sui disegni o nel videoclip sono da tradurre"). I testi stanno in res://lingue/testi.csv, con la
## frase italiana come chiave: le etichette e i pulsanti si traducono da soli; i testi composti (con un nome di tasto o
## un numero dentro) passano da [method t] prima di comporli.
## - All'inizio: la lingua salvata in user://settings.cfg, sezione [lingua]; la prima volta l'inglese se il sistema è in
##   inglese, se no l'italiano (di base resta l'italiano).
## - Nei test (--script) l'italiano, salvo la variabile d'ambiente LINGUA (it o en), che vale anche nel gioco e non si
##   salva.
## - Si cambia dalle opzioni ([method imposta]): le etichette si aggiornano subito, i testi composti con [method segui].

signal cambiata(lingua: String)

const LINGUE := ["it", "en"]
## I nomi delle lingue, ognuno nella sua lingua (nelle opzioni non si traducono).
const NOMI := ["Italiano", "English"]
const PERCORSO := "user://settings.cfg"
const SEZIONE := "lingua"

var lingua := "it"


func _ready() -> void:
	var da_env := OS.get_environment("LINGUA")
	if da_env in LINGUE:
		lingua = da_env
	elif OS.get_cmdline_args().has("--script"):
		lingua = "it"
	else:
		var cfg := ConfigFile.new()
		var salvata := ""
		if cfg.load(PERCORSO) == OK:
			salvata = String(cfg.get_value(SEZIONE, "lingua", ""))
		lingua = salvata if salvata in LINGUE else ("en" if OS.get_locale_language() == "en" else "it")
	TranslationServer.set_locale(lingua)


## Cambia lingua e la salva.
func imposta(nuova: String) -> void:
	if not nuova in LINGUE or nuova == lingua:
		return
	lingua = nuova
	TranslationServer.set_locale(lingua)
	var cfg := ConfigFile.new()
	cfg.load(PERCORSO)
	cfg.set_value(SEZIONE, "lingua", lingua)
	cfg.save(PERCORSO)
	cambiata.emit(lingua)


## La frase [param testo] nella lingua del gioco (anche da funzioni statiche, dove tr() non c'è).
static func t(testo: String) -> String:
	return TranslationServer.translate(testo)


## Chiama [param aggiorna] adesso e ogni volta che cambia la lingua, finché [param nodo] c'è: per i testi composti
## (con tasti, numeri o maiuscole) che non si traducono da soli.
static func segui(nodo: Node, aggiorna: Callable) -> void:
	var s := _Segui.new()
	s.name = "SegueLaLingua"
	s.aggiorna = aggiorna
	nodo.add_child(s, false, Node.INTERNAL_MODE_BACK)
	aggiorna.call()


class _Segui extends Node:
	var aggiorna: Callable

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSLATION_CHANGED and aggiorna.is_valid() and is_inside_tree():
			aggiorna.call()
