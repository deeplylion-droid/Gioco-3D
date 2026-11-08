extends Node
## Collaudo del menu di prova F9 cliccabile col mouse (#143, lavoro/menu-f9-mouse di ambienti-2), enigmi.
## Il titolo vero (menu_principale.tscn) col renderer Vulkan; mouse e tastiera VERI: xdotool manda gli eventi X11 alla
## finestra del gioco (spostamento, clic sinistro, tasti), come una persona. Il joypad con Input.parse_input_event
## (gli stessi eventi che arrivano da un joypad vero). Per ogni caso: cosa c'è sotto il mouse, cosa ha il fuoco, se il
## menu si apre e si chiude, se parte la partenza giusta (scena di caricamento e checkpoint dell'istantanea, o lo spot
## VHS per "Inizio"), l'opacità della dissolvenza e se il menu c'è ancora mentre si scurisce; scatti dei punti
## importanti. Poco dopo che una partenza è partita il processo esce (la sala, renderizzata con llvmpipe, non sta in
## memoria): la riga "COLLAUDO: ESCO" separa il log del collaudo da quello dell'uscita.
## Casi: pannelli, parti_<id>, tastiera, joypad, salvataggio, continua, inglese, controllo (il clic sulla base).
## Uso (cartella utente vuota: XDG_DATA_HOME nuova; xvfb con lo schermo grande quanto la finestra):
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan \
##     --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/collaudo_menu_f9.gd <cartella> <caso>

const TITOLO := "res://scenes/ui/menu_principale.tscn"
const CARICAMENTO := "res://scenes/ui/caricamento.tscn"

var cart := ""
var caso := ""
var titolo: Node
var _win := ""
var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secondi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(caso + "_" + nome + ".jpg"), 0.88)
	print("SCATTO ", caso, "_", nome)


func _check(cond: bool, cosa: String) -> void:
	if cond:
		_ok += 1
		print("  OK   ", cosa)
	else:
		_ko += 1
		print("  NO   ", cosa)


func _xdo(args: Array) -> String:
	var out := []
	OS.execute("xdotool", PackedStringArray(args.map(func(a): return str(a))), out, true)
	return "".join(out).strip_edges()


func _schermo(c: Control, punto := Vector2(-1, -1)) -> Vector2i:
	var p := c.get_global_rect().get_center() if punto.x < 0 else punto
	var s := get_viewport().get_screen_transform() * p + Vector2(DisplayServer.window_get_position())
	return Vector2i(roundi(s.x), roundi(s.y))


func _nome(c: Control) -> String:
	if c == null:
		return "niente"
	if c is Button:
		return "%s «%s»" % [c.name, (c as Button).text]
	return "%s (%s)" % [c.name, c.get_class()]


## Clic sinistro vero (xdotool) al centro di [param c] (o nel [param punto] del suo canvas). Torna se sotto il mouse,
## prima del clic, c'era proprio [param c] (il nome si legge prima: dopo il clic il menu può non esserci più).
func _clic(c: Control, cosa: String, punto := Vector2(-1, -1), dopo := 5) -> bool:
	var s := _schermo(c, punto)
	_xdo(["mousemove", "--sync", s.x, s.y])
	await _frames(4)
	var sotto := get_viewport().gui_get_hovered_control()
	var giusto := sotto == c
	var nomi := "%s; sotto il mouse %s" % [_nome(c), _nome(sotto)]
	_xdo(["click", "1"])
	await _frames(dopo)
	print("CLIC %s: in (%d, %d) su %s" % [cosa, s.x, s.y, nomi])
	return giusto


func _passa(c: Control) -> Control:
	var s := _schermo(c)
	_xdo(["mousemove", "--sync", s.x, s.y])
	await _frames(4)
	return get_viewport().gui_get_hovered_control()


## Tasto vero (xdotool) alla finestra del gioco.
func _tasto(k: String) -> void:
	_xdo(["windowfocus", "--sync", _win])
	_xdo(["key", "--clearmodifiers", k])
	await _frames(5)
	print("TASTO %s: fuoco su %s" % [k, _nome(get_viewport().gui_get_focus_owner())])


func _joy(b: JoyButton, nome: String) -> void:
	for premuto in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = b
		e.pressed = premuto
		e.pressure = 1.0 if premuto else 0.0
		Input.parse_input_event(e)
		await _frames(3)
	await _frames(2)
	print("JOYPAD %s: fuoco su %s" % [nome, _nome(get_viewport().gui_get_focus_owner())])


func _menu_prova() -> MenuProva:
	return titolo.get_node_or_null(^"MenuProva") as MenuProva if is_instance_valid(titolo) else null


## Le voci del menu di prova, in ordine (le partenze, poi Indietro).
func _voci_prova() -> Array:
	var m := _menu_prova()
	return m.find_children("*", "Button", true, false) if m else []


func _voce_prova(id: String) -> Button:
	var ids := MenuProva.disponibili().map(func(p): return String(p["id"]))
	var i := ids.find(id)
	var v := _voci_prova()
	return v[i] if i >= 0 and i < v.size() else null


func _bottone(radice: Node, testo: String) -> Button:
	for b in radice.find_children("*", "Button", true, false):
		if (b as Button).text == testo and (b as Button).is_visible_in_tree():
			return b
	return null


func _voce_titolo(nome: String) -> Button:
	for b in titolo.voci():
		if String(b.name) == nome:
			return b
	return null


## F9 vero: il menu di prova si apre?
func _apri_f9(cosa: String) -> MenuProva:
	await _tasto("F9")
	await _frames(3)
	var m := _menu_prova()
	_check(m != null and m.is_inside_tree(), "%s: F9 apre il menu di prova (layer %d)" % [cosa, m.layer if m else -1])
	return m


## Dopo la scelta di una partenza: la dissolvenza (opacità e menu ancora presente) fotogramma per fotogramma, fino alla
## scena di caricamento (o allo spot VHS per "inizio"); poi il checkpoint dell'istantanea.
func _segui_partenza(id: String, etichetta: String) -> void:
	var t0 := Time.get_ticks_msec()
	var menu_sopra_nero := 0
	var visto_nero := false
	var n := 0
	var partita := false
	var spot := false
	var scatti := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]   # (i primi otto fotogrammi dopo il clic, tutti)
	while Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
		n += 1
		var d := Dissolvenza.di(get_tree())
		var op := d.opacita() if d else 0.0
		var m := _menu_prova()
		var menu_vis := m != null and is_instance_valid(m) and m.is_inside_tree() and m.visible
		if op > 0.98:
			visto_nero = true
		if menu_vis and op > 0.5:
			menu_sopra_nero += 1
		var tt := (Time.get_ticks_msec() - t0) / 1000.0
		if not scatti.is_empty() and tt >= scatti[0]:
			await _scatto("%s_dissolvenza_%03d_ms_op%02d%s" % [etichetta, int(tt * 1000), int(op * 99), "_menu" if menu_vis else ""])
			scatti.pop_front()
		var s := get_tree().current_scene
		if s and s.scene_file_path == CARICAMENTO:
			partita = true
			break
		if id == "inizio" and get_tree().root.get_children().any(func(c): return c is LettoreSpot):
			spot = true
			break
	var dt := (Time.get_ticks_msec() - t0) / 1000.0
	if id == "inizio":
		_check(spot, "%s: «Inizio» fa partire la nuova partita (lo spot VHS) dopo %.1f s" % [etichetta, dt])
	else:
		var atteso := String(MenuProva.istantanea(id).get("checkpoint", ""))
		var cp := String(GameState.snapshot.get("checkpoint", ""))
		_check(partita and cp == atteso, "%s: parte «%s»: caricamento %s dopo %.1f s, checkpoint %s (atteso %s)" % [
				etichetta, id, partita, dt, cp, atteso])
	_check(menu_sopra_nero == 0, "%s: mentre si scurisce il menu di prova non resta sopra il nero (%d fotogrammi), nero pieno %s" % [
			etichetta, menu_sopra_nero, visto_nero or partita or spot])
	await _secondi(1.5)
	await _scatto("%s_dopo" % etichetta)


func _f9_chiudi_tutti(cosa: String) -> void:
	# F9 di nuovo, Esc e Indietro col mouse: il menu si chiude e il titolo torna com'era
	var m := await _apri_f9(cosa + ", chiudi con F9")
	await _tasto("F9")
	await _frames(4)
	_check(_menu_prova() == null, cosa + ": F9 lo richiude")
	m = await _apri_f9(cosa + ", chiudi con Esc")
	await _tasto("Escape")
	await _frames(4)
	_check(_menu_prova() == null, cosa + ": Esc lo chiude")
	m = await _apri_f9(cosa + ", chiudi col mouse")
	var v := _voci_prova()
	if v.size() > 0:
		var giusto := await _clic(v[-1], "Indietro")
		await _frames(4)
		_check(_menu_prova() == null and giusto, cosa + ": un clic su «Indietro» lo chiude (era sotto il mouse: %s)" % giusto)
	_check(titolo.voci()[0].get_parent().is_visible_in_tree(), cosa + ": le voci del titolo tornano visibili")


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1] if a.size() > 1 else "user://collaudo_menu_f9"
	caso = a[2] if a.size() > 2 else "pannelli"
	DirAccess.make_dir_recursive_absolute(cart)
	print("COLLAUDO: caso %s, cartella utente %s (salvataggio: %s)" % [caso, ProjectSettings.globalize_path("user://"),
			FileAccess.file_exists(GameState.SAVE_PATH)])
	if caso in ["salvataggio", "continua"]:
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(MenuProva.istantanea("torre")))
		f.close()
		print("COLLAUDO: scritto un salvataggio (istantanea torre)")
	if caso == "inglese":
		Lingua.imposta("en")
	get_tree().change_scene_to_file(TITOLO)
	for i in 30:
		await get_tree().process_frame
	titolo = get_tree().current_scene
	_win = _xdo(["search", "--onlyvisible", "--pid", OS.get_process_id()]).split("\n")[0]
	if _win == "":
		_win = _xdo(["search", "--onlyvisible", "--name", "Jilly"]).split("\n")[0]
	print("COLLAUDO: finestra %s, posizione %s, dimensione %s, vista %s, lingua %s" % [_win, DisplayServer.window_get_position(),
			DisplayServer.window_get_size(), get_viewport().get_visible_rect().size, TranslationServer.get_locale()])
	await _secondi(4.0)  # la schiarita del titolo
	await _scatto("titolo")
	print("COLLAUDO: voci del titolo %s, sottomenu %s" % [titolo.voci().map(func(b): return String(b.name)), titolo.sottomenu()])
	match caso:
		"pannelli", "inglese":
			await _pannelli()
			await _f9_chiudi_tutti(caso)
			var m := await _apri_f9(caso)
			for v in _voci_prova():
				await _passa(v)
			var ultima: Button = _voci_prova()[1] if _voci_prova().size() > 1 else null
			if ultima:
				await _passa(ultima)
				await _scatto("menu_f9_mouse_sopra")
			var id := "inizio" if caso == "pannelli" else "tunnel"
			var v := _voce_prova(id)
			var testo := v.text
			var giusto := await _clic(v, id, Vector2(-1, -1), 0)
			await _segui_partenza(id, "clic_" + id)
			_check(giusto, "%s: sotto il mouse c'è la voce «%s»" % [caso, testo])
		"tastiera":
			var m := await _apri_f9("tastiera")
			await _scatto("f9_aperto")
			var v := _voci_prova()
			_check(get_viewport().gui_get_focus_owner() == v[0], "tastiera: il fuoco parte sulla prima voce (%s)" % _nome(get_viewport().gui_get_focus_owner()))
			await _tasto("Down")
			_check(get_viewport().gui_get_focus_owner() == v[1], "tastiera: freccia giù sulla seconda voce")
			await _tasto("Down")
			await _tasto("Up")
			_check(get_viewport().gui_get_focus_owner() == v[1], "tastiera: freccia su torna alla seconda")
			await _tasto("Escape")
			_check(_menu_prova() == null, "tastiera: Esc chiude")
			m = await _apri_f9("tastiera")
			await _tasto("F9")
			_check(_menu_prova() == null, "tastiera: F9 chiude")
			m = await _apri_f9("tastiera")
			v = _voci_prova()
			for i in v.size() - 1:
				await _tasto("Down")
			_check(get_viewport().gui_get_focus_owner() == v[-1], "tastiera: in fondo c'è «Indietro»")
			await _tasto("Return")
			_check(_menu_prova() == null, "tastiera: Invio su «Indietro» chiude")
			m = await _apri_f9("tastiera")
			var bersaglio := _voce_prova("fiume")
			while get_viewport().gui_get_focus_owner() != bersaglio and _menu_prova():
				await _tasto("Down")
			await _scatto("tastiera_su_fiume")
			await _tasto("Return")
			await _segui_partenza("fiume", "invio_fiume")
		"joypad":
			var m := await _apri_f9("joypad")
			var v := _voci_prova()
			await _joy(JOY_BUTTON_DPAD_DOWN, "giù")
			_check(get_viewport().gui_get_focus_owner() == v[1], "joypad: croce giù sulla seconda voce")
			await _joy(JOY_BUTTON_DPAD_UP, "su")
			_check(get_viewport().gui_get_focus_owner() == v[0], "joypad: croce su torna alla prima")
			await _joy(JOY_BUTTON_B, "B")
			_check(_menu_prova() == null, "joypad: B chiude")
			m = await _apri_f9("joypad")
			v = _voci_prova()
			for i in v.size() - 1:
				await _joy(JOY_BUTTON_DPAD_DOWN, "giù")
			await _joy(JOY_BUTTON_A, "A")
			_check(_menu_prova() == null, "joypad: A su «Indietro» chiude")
			m = await _apri_f9("joypad")
			var bersaglio := _voce_prova("torre")
			while get_viewport().gui_get_focus_owner() != bersaglio and _menu_prova():
				await _joy(JOY_BUTTON_DPAD_DOWN, "giù")
			await _scatto("joypad_su_torre")
			await _joy(JOY_BUTTON_A, "A")
			await _segui_partenza("torre", "a_torre")
		"salvataggio":
			_check(_voce_titolo("Continua") != null, "salvataggio: c'è «Continua»")
			var nuova := _voce_titolo("NuovaPartita")
			await _clic(nuova, "Nuova partita")
			var d: Node = titolo.sottomenu()
			_check(d != null and String(d.name) == "DomandaNuovaPartita", "salvataggio: «Nuova partita» chiede «Ricominciare da capo?» (%s)" % (d.name if d else "-"))
			await _scatto("domanda_nuova_partita")
			if d:
				await _clic(d.get("voce_no"), "No")
				await _frames(5)
				_check(titolo.sottomenu() == null and nuova.is_visible_in_tree(), "salvataggio: «No» torna al titolo")
			var m := await _apri_f9("salvataggio")
			var v := _voce_prova("inizio")
			await _clic(v, "Inizio")
			await _frames(5)
			d = titolo.sottomenu()
			_check(d != null and String(d.name) == "DomandaNuovaPartita", "salvataggio: «Inizio» del menu F9 chiede anche lui «Ricominciare da capo?»")
			await _scatto("domanda_da_f9")
			if d:
				await _clic(d.get("voce_no"), "No")
				await _frames(5)
			m = await _apri_f9("salvataggio, dopo il No")
			v = _voce_prova("risalita")
			var testo := v.text
			var giusto := await _clic(v, "risalita")
			_check(giusto, "salvataggio: sotto il mouse c'è «%s»" % testo)
			await _segui_partenza("risalita", "clic_risalita")
		"continua":
			var c := _voce_titolo("Continua")
			_check(c != null, "continua: c'è «Continua»")
			await _clic(c, "Continua")
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 15000:
				await get_tree().process_frame
				var s := get_tree().current_scene
				if s and s.scene_file_path == CARICAMENTO:
					break
			var s := get_tree().current_scene
			_check(s != null and s.scene_file_path == CARICAMENTO and String(GameState.snapshot.get("checkpoint", "")) == String(MenuProva.istantanea("torre").get("checkpoint")),
					"continua: un clic su «Continua» riparte dal salvataggio (%s)" % GameState.snapshot.get("checkpoint", ""))
			await _secondi(1.5)
			await _scatto("continua_caricamento")
		"controllo":
			var m := await _apri_f9("controllo")
			var v := _voce_prova("risalita")
			var giusto := await _clic(v, "risalita")
			await _secondi(3.0)
			var s := get_tree().current_scene
			print("CONTROLLO: la voce sotto il mouse %s; partita %s; menu ancora aperto %s" % [giusto,
					s != null and s.scene_file_path == CARICAMENTO, _menu_prova() != null])
			await _scatto("controllo_dopo_clic")
		_:
			if caso.begins_with("parti_"):
				var id := caso.trim_prefix("parti_")
				var m := await _apri_f9(caso)
				await _scatto("f9_aperto")
				var v := _voce_prova(id)
				var testo := v.text
				var giusto := await _clic(v, id, Vector2(-1, -1), 0)
				await _segui_partenza(id, "clic_" + id)
				_check(giusto, "%s: sotto il mouse c'è la voce «%s»" % [caso, testo])
	print("COLLAUDO: RISULTATO %s: %d controlli giusti, %d sbagliati" % [caso, _ok, _ko])
	print("COLLAUDO: ESCO")
	get_tree().quit()


## Opzioni (col mouse: ogni scheda, la calibrazione della luminosità, Chiudi) e Comandi (col mouse, Indietro).
func _pannelli() -> void:
	var op := _voce_titolo("Opzioni")
	var giusto := await _clic(op, "Opzioni")
	await _frames(10)
	var pannello: Node = titolo.sottomenu()
	_check(pannello != null and giusto, "%s: un clic su «Opzioni» apre le opzioni" % caso)
	if pannello:
		var tabs := pannello.find_children("*", "TabContainer", true, false)[0] as TabContainer
		var barra := tabs.get_tab_bar()
		for i in tabs.get_tab_count():
			var r := barra.get_tab_rect(i)
			var dove := barra.get_global_transform() * r.get_center()
			await _clic(barra, "scheda %d" % i, dove)
			await _frames(6)
			_check(tabs.current_tab == i, "%s: un clic sulla scheda «%s» la apre" % [caso, tabs.get_tab_title(i)])
			await _scatto("opzioni_scheda_%d" % i)
		# di nuovo la scheda della luminosità, col mouse, e lì il pulsante della calibrazione
		var cal := pannello.find_child("CalibraLuminosita", true, false) as Button
		if cal:
			var i_lum := -1
			for i in tabs.get_tab_count():
				if tabs.get_tab_control(i).is_ancestor_of(cal):
					i_lum = i
			if i_lum >= 0:
				await _clic(barra, "scheda della luminosità", barra.get_global_transform() * barra.get_tab_rect(i_lum).get_center())
				await _frames(6)
		if cal and cal.is_visible_in_tree():
			await _clic(cal, "Calibra la luminosità")
			await _frames(8)
			var om := pannello.get_node_or_null(^"Menu")   # (il menu delle opzioni, che tiene la calibrazione)
			var aperta := om != null and om.get("_calibrazione") != null and (om.get("_calibrazione") as Node).is_inside_tree()
			_check(aperta, "%s: dalle opzioni si apre la calibrazione della luminosità" % caso)
			await _scatto("calibrazione")
			var ok := _bottone(pannello, "Conferma")
			if ok:
				await _clic(ok, "Conferma")
				await _frames(6)
			_check(om != null and om.get("_calibrazione") == null and cal.is_visible_in_tree(), "%s: «Conferma» chiude la calibrazione e torna alle opzioni" % caso)
		else:
			_check(false, "%s: il pulsante della calibrazione c'è" % caso)
		var chiudi := _bottone(pannello, "Chiudi")
		await _clic(chiudi, "Chiudi")
		await _frames(6)
		_check(titolo.sottomenu() == null, "%s: «Chiudi» chiude le opzioni" % caso)
	var co := _voce_titolo("Comandi")
	giusto = await _clic(co, "Comandi")
	await _frames(10)
	pannello = titolo.sottomenu()
	_check(pannello != null, "%s: un clic su «Comandi» apre i comandi" % caso)
	await _scatto("comandi")
	if pannello:
		var ind := pannello.find_child("Indietro", true, false) as Button
		await _clic(ind, "Indietro dei comandi")
		await _frames(6)
		_check(titolo.sottomenu() == null, "%s: «Indietro» chiude i comandi" % caso)
