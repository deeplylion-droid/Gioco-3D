extends Node
## Costruisce le pile di scatoloni del fiume lento (FiumeLento._pile, col generatore) e le salva già pronte in
## FiumeLento.PILE_FILE, che il gioco carica invece di rifarle (scelta A dell'utente del 4 novembre, "pile nel file").
## Da rilanciare solo quando si vogliono cambiare le pile di proposito (codice di _pile, muri, rocce, transenne).
## Con "dump=<file>" scrive anche tutte le trasformazioni, le tinte, le collisioni e le lampade delle pile, una per riga a
## precisione piena; con "dal_file" non le costruisce ma le prende dal file (per il confronto: i due dump devono essere
## uguali riga per riga).
## Uso (sotto il render.lock):
##   godot --headless --path godot --script res://tests/run.gd -- res://tools/salva_pile_fiume.gd [dal_file] [dump=<file>]

const SCENA := "res://tests/scene/fiume_gioco_prova.tscn"
const FIUME := preload("res://scripts/risalita/fiume_gioco.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var dal_file := "dal_file" in argomenti
	var dump := ""
	for a in argomenti:
		if a.begins_with("dump="):
			dump = a.substr(5)
	if not dal_file:
		Engine.set_meta(&"costruisci_pile", true)
	get_tree().change_scene_to_file(SCENA)
	var fiume: Node = null
	for i in 12000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s == null:
			continue
		for f in s.find_children("*", "Node3D", true, false):
			if (f as Node).get_script() == FIUME and f.get(&"costruita") == true:
				fiume = f
		if fiume:
			break
	if fiume == null:
		print("PILE: il fiume non si è costruito")
		get_tree().quit(1)
		return
	var dati: Dictionary = fiume.get(&"dati_pile")
	if not dal_file:
		var r := Resource.new()
		r.set_meta(&"dati", dati)
		var err := ResourceSaver.save(r, FIUME.PILE_FILE, ResourceSaver.FLAG_COMPRESS)
		print("PILE: salvate in %s (errore %d)" % [FIUME.PILE_FILE, err])
		# rilette dal file, devono essere identiche a quelle costruite
		var riletto: Dictionary = (ResourceLoader.load(FIUME.PILE_FILE, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource).get_meta(&"dati")
		print("PILE: rilette uguali: %s" % (_righe(riletto) == _righe(dati)))
	if not dump.is_empty():
		var f := FileAccess.open(dump, FileAccess.WRITE)
		for riga in _righe(dati):
			f.store_line(riga)
		f.close()
		print("PILE: dump in %s (%d righe)" % [dump, _righe(dati).size()])
	Engine.remove_meta(&"costruisci_pile")
	print("PILE: finito")
	get_tree().quit()


## Tutto quello che è nelle pile, una riga per elemento, coi numeri a precisione piena (var_to_str).
func _righe(d: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in ["casse", "cartone", "aperte", "scatole", "tinte_scatole", "colorate", "tinte_colorate", "casse_sciolte", "collisioni", "lampade"]:
		var arr: Array = d[k]
		out.append("%s %d" % [k, arr.size()])
		for v in arr:
			out.append(var_to_str(v).replace("\n", " "))
	return out
