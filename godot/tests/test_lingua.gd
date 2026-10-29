extends Node
## Test delle lingue (Lingua, res://lingue/testi.csv; il gioco anche in inglese, approvato dall'utente il 25 ottobre):
## 1. il CSV: tre colonne (chiave italiana, it, en), nessuna chiave o traduzione vuota, nessuna chiave doppia, e in
##    inglese ogni chiave dà la sua traduzione;
## 2. i testi nel codice e nelle scene: ogni frase che va a schermo (voci, etichette, pulsanti, scelte delle opzioni,
##    comandi, consigli, avvisi, azioni, oggetti, scritte finali, sottotitoli dello spot) è una chiave del CSV;
## 3. a schermo, in inglese: titolo, pausa, opzioni (tutte le schede, audio compreso), calibrazione e comandi non
##    mostrano nessun testo che non sia una traduzione inglese del CSV (o un nome che non si traduce);
## 4. cambiando lingua dalle opzioni le voci del titolo cambiano subito, e la scelta si salva.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_lingua.gd

const CSV := "res://lingue/testi.csv"
const TITOLO := "res://scenes/ui/menu_principale.tscn"
const COMANDI := "res://scenes/ui/comandi.tscn"
## Dove si cercano i testi che vanno a schermo.
const CARTELLE := ["res://scripts", "res://addons/grafica", "res://addons/audio"]
const SCENE := ["res://scenes"]
const SPOT := "res://scenes/spot/spot_inquadrature.json"
## Nomi e sigle che restano uguali in tutte le lingue (a schermo non sono traduzioni del CSV).
## Il contatore degli FPS (F3) è uno strumento di prova, in italiano.
const SALTA := ["fps_counter.gd"]
const UGUALI := ["VoxelGI", "SDFGI", "FXAA", "AMD FSR 1.0", "AMD FSR 2.2", "MSAA 2×", "MSAA 4×", "MSAA 8×",
		"Italiano", "English", "Ctrl", "Alt", "Esc", "Tab", "Backspace", "LB", "RB", "LT", "RT", "L3", "R3", "Back",
		"Start", "CAM 3", "● REC"]

var _passed := 0
var _failed := 0
var _it := {}      # chiave -> it
var _en := {}      # chiave -> en
var _modelli: Array[RegEx] = []


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String, extra: Variant = null) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what, "" if extra == null else "  " + str(extra))


func _fine() -> void:
	TranslationServer.set_locale("it")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Grafica.salva_su_disco = false
	print("1. Il CSV")
	_leggi_csv()
	print("2. I testi nel codice e nelle scene")
	_testi_nel_codice()
	print("3. A schermo, in inglese")
	await _a_schermo()
	print("4. Cambiare lingua")
	await _cambia_lingua()
	_fine()


# --- 1 -------------------------------------------------------------------------------------------------------------

func _leggi_csv() -> void:
	var f := FileAccess.open(CSV, FileAccess.READ)
	check(f != null, "c'è il CSV delle lingue")
	if f == null:
		return
	var testa := f.get_csv_line()
	check(testa == PackedStringArray(["keys", "it", "en"]), "le colonne sono chiave, it, en", testa)
	var vuote := []
	var doppie := []
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() == 1 and r[0] == "":
			continue
		if r.size() != 3 or r[0].strip_edges() == "" or r[1].strip_edges() == "" or r[2].strip_edges() == "":
			vuote.append(r)
			continue
		if _en.has(r[0]):
			doppie.append(r[0])
		_it[r[0]] = r[1]
		_en[r[0]] = r[2]
	check(_en.size() > 150 and vuote.is_empty(), "%d frasi, nessuna chiave o traduzione vuota" % _en.size(), vuote)
	check(doppie.is_empty(), "nessuna chiave doppia", doppie)
	var diverse := _it.keys().filter(func(k): return _it[k] != k)
	check(diverse.is_empty(), "la colonna it è la chiave stessa", diverse)
	TranslationServer.set_locale("en")
	var sbagliate := _en.keys().filter(func(k): return tr(k) != _en[k])
	TranslationServer.set_locale("it")
	var sbagliate_it := _en.keys().filter(func(k): return tr(k) != k)
	check(sbagliate.is_empty() and sbagliate_it.is_empty(), "in inglese ogni chiave dà la sua traduzione, in italiano sé stessa",
			[sbagliate.slice(0, 5), sbagliate_it.slice(0, 5)])
	# i modelli delle traduzioni con un numero o un nome dentro (%s, %d, {tasto})
	for k in _en:
		var e: String = _en[k]
		if e.contains("%") or e.contains("{"):
			var re := RegEx.new()
			var p := "^" + _escape(e) + "$"
			for segno in ["%s", "%d", "%.2f"]:
				p = p.replace(_escape(segno), ".+")
			re.compile(p)
			_modelli.append(re)


static func _escape(s: String) -> String:
	var out := ""
	for c in s:
		out += ("\\" + c) if c in "\\^$.|?*+()[]{}" else c
	return out


# --- 2 -------------------------------------------------------------------------------------------------------------

## I testi che vanno a schermo, cercati nel codice: [testo, file:riga].
func _testi_nel_codice() -> void:
	var trovati := []
	# le frasi passate a chi le mette a schermo (o già tradotte con tr / Lingua.t)
	var pozzi := RegEx.new()
	pozzi.compile("(?:StileMenu\\.(?:voce|etichetta|tasto)|_voce\\([^,()]+,|_menu_button\\([^,()]+,|show_hint|show_banner|show_message|_label|_scheda|_scelta\\(\\w+,|_cursore\\(\\w+,|_spunta\\(\\w+,|_riga\\(\\w+,|\\btr|Lingua\\.t|DOMANDA\\.new)\\(?\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	var assegna := RegEx.new()
	assegna.compile("(?:\\.text|\\bprompt|\\bitem_name|\\bdisplay_name|\\btitolo|\\bnota|_testo)\\s*:?=\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	var stringa := RegEx.new()
	stringa.compile("\"((?:[^\"\\\\]|\\\\.)*)\"")
	for file in _file(CARTELLE, "gd"):
		if file.get_file() in SALTA:
			continue
		var righe := FileAccess.get_file_as_string(file).split("\n")
		var in_elenco := ""
		for i in righe.size():
			var r := righe[i]
			if r.strip_edges().begins_with("#"):
				continue
			for re in [pozzi, assegna]:
				for m in (re as RegEx).search_all(r):
					trovati.append([_vero(m.get_string(1)), "%s:%d" % [file.get_file(), i + 1]])
			# gli elenchi di testi: le scelte delle opzioni, le righe dei comandi, i nomi dei tasti, i consigli, i volumi,
			# le partenze di prova, i color grading
			if r.begins_with("const RIGHE") or r.begins_with("const _NOMI_") or r.begins_with("const CONSIGLI") \
					or r.begins_with("const VOCI") or r.begins_with("const PARTENZE") or r.begins_with("const GRADING"):
				# (su più righe fino alla chiusa; su una riga sola, solo quella)
				in_elenco = r if r.strip_edges().ends_with("[") or r.strip_edges().ends_with("{") else ""
				for m in stringa.search_all(r):
					if not _tecnico(_vero(m.get_string(1))):
						trovati.append([_vero(m.get_string(1)), "%s:%d" % [file.get_file(), i + 1]])
			var opzioni := file.get_file() == "menu_opzioni.gd" and ("_scelta(" in r or r.strip_edges().begins_with("for n in ["))
			var elenco := in_elenco != "" or opzioni
			if elenco:
				for m in stringa.search_all(r):
					var s := _vero(m.get_string(1))
					# (le chiavi dei dizionari dei nomi dei tasti e i nomi delle azioni non sono testi)
					# (né gli id e le chiavi in minuscolo, una parola sola)
					if not r.contains("&\"" + s + "\"") and not RegEx.create_from_string("^[a-z]+$").search(s) and not _tecnico(s):
						trovati.append([s, "%s:%d" % [file.get_file(), i + 1]])
			if in_elenco != "" and (r.begins_with("]") or r.begins_with("}")):
				in_elenco = ""
	# nelle scene
	var prop := RegEx.new()
	prop.compile("^(?:prompt|item_name|display_name|text) = \"((?:[^\"\\\\]|\\\\.)*)\"")
	for file in _file(SCENE, "tscn"):
		var righe := FileAccess.get_file_as_string(file).split("\n")
		for i in righe.size():
			var m := prop.search(righe[i])
			if m:
				trovati.append([_vero(m.get_string(1)), "%s:%d" % [file.get_file(), i + 1]])
	# i sottotitoli dello spot
	var spot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPOT))
	for s in spot.get("sottotitoli", []):
		trovati.append([String(s["testo"]), "spot_inquadrature.json"])
	var mancano := []
	var visti := {}
	for t in trovati:
		var s: String = t[0]
		if visti.has(s) or _tecnico(s) or _en.has(s):
			visti[s] = true
			continue
		visti[s] = true
		mancano.append("%s (%s)" % [s, t[1]])
	check(visti.size() > 150 and mancano.is_empty(), "%d testi a schermo nel codice, nelle scene e nello spot, tutti nel CSV" % visti.size(), mancano)


## Il testo vero di una stringa del codice (le sequenze \n, \", \\).
static func _vero(s: String) -> String:
	return s.c_unescape()


## Vero per le stringhe che non sono testi da tradurre: senza lettere, solo segnaposto, sigle e nomi che restano
## uguali, nomi di nodi e percorsi.
func _tecnico(s: String) -> bool:
	if s == "" or s in UGUALI:
		return true
	var lettere := RegEx.create_from_string("[A-Za-zÀ-ÿ]{2,}")
	if lettere.search(s) == null:
		return true
	var segnaposto := RegEx.create_from_string("^[\\s%sd.0-9f·:/\\[\\]()×-]*$")
	if segnaposto.search(s):
		return true
	return s.begins_with("res://") or s.begins_with("user://") or s.contains("_") and not s.contains(" ")


static func _file(cartelle: Array, estensione: String) -> PackedStringArray:
	var out := PackedStringArray()
	var da := cartelle.duplicate()
	while not da.is_empty():
		var d: String = da.pop_back()
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		for sub in dir.get_directories():
			if not sub.begins_with("."):
				da.append(d.path_join(sub))
		for f in dir.get_files():
			if f.get_extension() == estensione:
				out.append(d.path_join(f))
	return out


# --- 3 -------------------------------------------------------------------------------------------------------------

## Vero se [param s] (a schermo, in inglese) è una traduzione inglese del CSV, o un testo che non si traduce.
func _inglese(s: String) -> bool:
	s = s.strip_edges()
	if _tecnico(s) or s in _en.values() or s.to_upper() in _en.values().map(func(e): return String(e).to_upper()):
		return true
	for re in _modelli:
		if re.search(s):
			return true
	# una sola lettera o un numero (i tasti W, A, S, D, E...)
	return s.length() <= 2


## I testi visibili sotto [param radice], come si vedono (tradotti dove si traducono da soli).
func _a_video(radice: Node) -> Array:
	var out := []
	for n in [radice] + radice.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null or not c.is_visible_in_tree():
			continue
		if c is Label:
			out.append([c.atr((c as Label).text) if c.can_auto_translate() else (c as Label).text, c])
		elif c is OptionButton:
			var o := c as OptionButton
			for i in o.item_count:
				out.append([o.get_popup().atr(o.get_item_text(i)) if o.get_popup().can_auto_translate() else o.get_item_text(i), c])
		elif c is Button:
			out.append([c.atr((c as Button).text) if c.can_auto_translate() else (c as Button).text, c])
		elif c is TabContainer:
			var tc := c as TabContainer
			for i in tc.get_tab_count():
				out.append([tc.get_tab_title(i), c])
	return out


func _controlla_inglese(radice: Node, cosa: String) -> void:
	var italiani := []
	var visti := 0
	for t in _a_video(radice):
		# (il testo intero, o riga per riga: il banner ha titolo e sottotitolo)
		visti += 1
		if _inglese(String(t[0])):
			continue
		for riga in String(t[0]).split("\n"):
			if riga.strip_edges() != "" and not _inglese(riga):
				italiani.append("%s (%s)" % [riga, (t[1] as Node).name])
	check(visti > 0 and italiani.is_empty(), "%s: %d testi a schermo, tutti in inglese" % [cosa, visti], italiani)


func _a_schermo() -> void:
	TranslationServer.set_locale("en")
	# il titolo
	get_tree().change_scene_to_file(TITOLO)
	await _frames(10)
	var menu := get_tree().current_scene
	_controlla_inglese(menu, "il titolo")
	var voci := menu.find_children("*", "Button", true, false).map(func(b): return (b as Button).text)
	check("NEW GAME" in voci and "OPTIONS" in voci and "CONTROLS" in voci and "QUIT" in voci, "le voci del titolo in inglese", voci)
	# le opzioni, scheda per scheda (con l'audio)
	var livello := CanvasLayer.new()
	livello.layer = 100
	add_child(livello)
	var opz := MenuOpzioni.new()
	livello.add_child(opz)
	await _frames(5)
	if Audio.has_method(&"_inietta_menu"):
		Audio.call(&"_inietta_menu", opz)
	await _frames(5)
	var tabs := opz.find_children("*", "TabContainer", true, false)
	var tc: TabContainer = tabs[0] if not tabs.is_empty() else null
	check(tc != null and tc.get_tab_count() >= 6, "le opzioni hanno le loro schede (%d)" % (tc.get_tab_count() if tc else 0))
	if tc:
		var titoli := []
		for i in tc.get_tab_count():
			titoli.append(tc.get_tab_title(i))
		check("Display" in titoli and "Audio" in titoli and "Brightness" in titoli, "i titoli delle schede in inglese", titoli)
		for i in tc.get_tab_count():
			tc.current_tab = i
			await _frames(2)
			_controlla_inglese(opz, "opzioni, scheda %s" % tc.get_tab_title(i))
	opz.apri_calibrazione()
	await _frames(3)
	var cal := opz.find_children("*", "CalibrazioneLuminosita", true, false)
	check(not cal.is_empty(), "la calibrazione della luminosità si apre")
	if not cal.is_empty():
		_controlla_inglese(cal[0], "la calibrazione della luminosità")
	opz.queue_free()
	await _frames(2)
	# i comandi
	var com := (load(COMANDI) as PackedScene).instantiate()
	add_child(com)
	await _frames(3)
	_controlla_inglese(com, "i comandi")
	var testi_com := _a_video(com).map(func(t): return t[0])
	check("CONTROLS" in testi_com and "Move" in testi_com and "Space" in testi_com and "hold" in testi_com, "i comandi in inglese (titolo, righe, tasti, note)", testi_com.slice(0, 12))
	com.queue_free()
	# la domanda di Nuova partita con un salvataggio
	var dom: CanvasLayer = (load("res://scripts/ui/menu/domanda_menu.gd") as GDScript).new("Ricominciare da capo?", "Il salvataggio verrà sostituito")
	add_child(dom)
	await _frames(3)
	_controlla_inglese(dom, "la domanda di Nuova partita")
	var tit := dom.find_child("Titolo", true, false) as Label
	check(tit != null and tit.text == "START OVER?", "la domanda in inglese e in maiuscolo", tit.text if tit else null)
	dom.queue_free()
	# la pausa
	Game.set_paused(true)
	await _frames(3)
	var pausa: Node = Game.get(&"_overlay")
	_controlla_inglese(pausa, "il menu di pausa")
	Game.set_paused(false)
	# il consiglio del caricamento, coi tasti
	var c: String = (load("res://scripts/ui/menu/caricamento.gd") as GDScript).call(&"consiglio",
			"Lo zaino-pompa aspira l'acqua con il {suck} e la spruzza con il {spray}.")
	check(c.begins_with("The pump backpack sucks up water with the ") and not c.contains("tasto"), "i consigli del caricamento in inglese, coi nomi dei tasti", c)
	TranslationServer.set_locale("it")


# --- 4 -------------------------------------------------------------------------------------------------------------

func _cambia_lingua() -> void:
	var menu := get_tree().current_scene
	var nuova := menu.find_child("NuovaPartita", true, false) as Button
	Lingua.imposta("en")
	await _frames(2)
	var in_inglese := nuova != null and nuova.text == "NEW GAME"
	var versione := menu.find_child("Versione", true, false) as Label
	var v_en := versione != null and versione.text.begins_with("Chapter 1")
	Lingua.imposta("it")
	await _frames(2)
	check(in_inglese and v_en and nuova.text == "NUOVA PARTITA" and versione.text.begins_with("Capitolo 1"),
			"cambiando lingua il titolo cambia subito (voci e capitolo), avanti e indietro")
	var cfg := ConfigFile.new()
	cfg.load(Lingua.PERCORSO)
	check(String(cfg.get_value(Lingua.SEZIONE, "lingua", "")) == "it", "la scelta della lingua si salva")
	# nelle opzioni aperte anche il testo del FOV cambia subito (collaudo del 28 ottobre: restava "horiz." in italiano)
	var opz := MenuOpzioni.new()
	add_child(opz)
	await _frames(3)
	var fov := (opz.get(&"_controlli") as Dictionary).get("fov") as HSlider
	var etichetta: Label = fov.get_meta("etichetta") if fov else null
	var prima := etichetta.text if etichetta else ""
	Lingua.imposta("en")
	await _frames(2)
	var dopo := etichetta.text if etichetta else ""
	Lingua.imposta("it")
	await _frames(2)
	check(prima.ends_with("orizz.)") and dopo.ends_with("horiz.)") and etichetta.text == prima,
			"nelle opzioni il testo del FOV cambia lingua subito, avanti e indietro", [prima, dopo, etichetta.text if etichetta else ""])
	opz.queue_free()
	await _frames(2)
