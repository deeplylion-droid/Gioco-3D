extends Node
## Test dell'album delle Polaroid nel menu di pausa (scelta A dell'utente del 4 novembre, proposta enigmi-1):
## 1. le 16 Polaroid hanno ognuna il suo nome nel salvataggio, quelli di sempre (p01-p09, Polaroid10, PolaroidPecora,
##    p12-p16), e il contatore del HUD dice sempre "Polaroid: n su 16", anche in inglese;
## 2. nel menu di pausa c'è "Polaroid": apre l'album sopra la pausa, con 16 cornici in ordine e "n su 16"; le trovate
##    hanno la foto, le altre sono vuote, senza la foto né niente che dica dove cercarle;
## 3. col joypad (o le frecce): il focus parte dalla prima cornice, a destra passa alla seconda, giù alla fila sotto e poi
##    a "Indietro"; A su una trovata la riapre grande, B la chiude e si resta nell'album, in pausa, sulla stessa cornice;
##    coi bottoni veri del joypad (#128) A riapre la foto, Start non la chiude (la pausa non ha il joypad), A e B la
##    chiudono; su una vuota non succede niente;
## 4. B chiude l'album e si torna al menu di pausa; in inglese il contatore è "n of 16";
## 5. il salvataggio non cambia: le raccolte restano liste di nomi nella collezione "polaroid".
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_album_polaroid.gd

const TROVATE := [1, 4, 10, 11, 16]

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)


func _fine() -> void:
	TranslationServer.set_locale("it")
	if get_tree().paused:
		Game.set_paused(false)
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Preme e rilascia un'azione (come un tasto del joypad).
func _premi(azione: StringName) -> void:
	var e := InputEventAction.new()
	e.action = azione
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var r := InputEventAction.new()
	r.action = azione
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(2)


## Preme e rilascia un bottone vero del joypad.
func _joy(bottone: JoyButton) -> void:
	for giu in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = bottone
		e.pressed = giu
		e.device = 0
		Input.parse_input_event(e)
		await _frames(2)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _visore() -> CanvasLayer:
	for n in get_tree().root.get_children():
		if n is CanvasLayer and n.get_script() == PolaroidPhoto.VIEWER:
			return n as CanvasLayer
	return null


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	TranslationServer.set_locale("it")
	GameState.reset_progress()

	print("1. I nomi delle 16 e il contatore")
	var nomi := PolaroidPhoto.NOMI_RACCOLTA.map(func(v): return String(v))
	check(nomi == ["p01", "p02", "p03", "p04", "p05", "p06", "p07", "p08", "p09", "Polaroid10", "PolaroidPecora",
			"p12", "p13", "p14", "p15", "p16"], "le 16 Polaroid coi nomi di sempre nel salvataggio")
	for n in TROVATE:
		GameState.collect(&"polaroid", PolaroidPhoto.NOMI_RACCOLTA[n - 1])
	# una che non è delle 16 (le prove del livello di test) non conta
	GameState.collect(&"polaroid", &"polaroid01")
	check(PolaroidPhoto.quante_trovate() == TROVATE.size(), "ne risultano trovate %d" % PolaroidPhoto.quante_trovate())
	var hud: CanvasLayer = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	add_child(hud)
	await _frames(2)
	hud.call(&"_on_collectible", &"polaroid", &"p16", 6, 7)
	var msg := hud.get(&"_message") as Label
	check(msg.text == "Polaroid: 5 su 16", "il HUD dice \"Polaroid: 5 su 16\", non il totale delle zone caricate (%s)" % msg.text)
	TranslationServer.set_locale("en")
	hud.call(&"_on_collectible", &"polaroid", &"p16", 6, 7)
	check(msg.text == "Polaroid: 5 of 16", "in inglese \"Polaroid: 5 of 16\" (%s)" % msg.text)
	TranslationServer.set_locale("it")
	hud.queue_free()

	print("2. L'album dal menu di pausa")
	Game.set_paused(true)
	await _frames(3)
	var overlay := Game.get_node("PauseOverlay") as CanvasLayer
	var bottone: Button = null
	for b in overlay.find_children("*", "Button", true, false):
		if (b as Button).text == "Polaroid":
			bottone = b
	check(bottone != null, "nel menu di pausa c'è \"Polaroid\"")
	if bottone == null:
		_fine()
		return
	bottone.pressed.emit()
	await _frames(3)
	var album := Game.find_child("Album", true, false) as AlbumPolaroid
	check(album != null and not overlay.visible and get_tree().paused, "apre l'album sopra la pausa")
	if album == null:
		_fine()
		return
	var cornici := album.cornici()
	check(cornici.size() == 16, "16 cornici")
	var giuste := true
	for i in cornici.size():
		var n := i + 1
		var c := cornici[i]
		var foto := c.get_node_or_null(^"Foto") as TextureRect
		var vuota := c.get_node_or_null(^"Vuota")
		if n in TROVATE:
			giuste = giuste and foto != null and vuota == null and foto.texture != null \
					and foto.texture.resource_path.ends_with("P%02d.jpg" % n)
		else:
			giuste = giuste and foto == null and vuota != null and c.find_children("*", "TextureRect", true, false).is_empty() \
					and c.find_children("*", "Label", true, false).is_empty()
	check(giuste, "le trovate hanno la loro foto, in ordine; le altre sono cornici vuote, senza foto né scritte")
	var conteggio := album.find_child("Conteggio", true, false) as Label
	check(conteggio != null and conteggio.text == "5 su 16", "il contatore dice \"5 su 16\" (%s)" % (conteggio.text if conteggio else "-"))

	print("3. Col joypad")
	await _frames(2)
	check(_focus() == cornici[0], "il focus parte dalla prima cornice")
	await _premi(&"ui_right")
	check(_focus() == cornici[1], "a destra la seconda")
	await _premi(&"ui_down")
	check(_focus() == cornici[9], "giù la cornice sotto (la 10)")
	await _premi(&"ui_down")
	check(_focus() is Button and (_focus() as Button).name == &"Indietro", "ancora giù: Indietro")
	await _premi(&"ui_down")
	check(_focus() == cornici[0], "e di nuovo giù si torna alla prima")
	# A sulla 1 (trovata): si riapre grande
	await _premi(&"ui_accept")
	await _frames(3)
	var v := _visore()
	check(v != null and v.layer > 100 and get_tree().paused, "A su una trovata la riapre grande, sopra l'album")
	if v:
		await _frames(30)   # (il visore accetta i tasti dopo 0,3 s)
		await _premi(&"ui_cancel")
		await _frames(3)
		check(_visore() == null and is_instance_valid(album) and album.is_inside_tree() and get_tree().paused,
			"B la chiude: si resta nell'album, in pausa")
		check(_focus() == cornici[0], "sulla stessa cornice")
	# coi bottoni veri del joypad (#128): A apre, Start non chiude, A chiude; poi B chiude
	await _joy(JOY_BUTTON_A)
	await _frames(3)
	check(_visore() != null, "il bottone A del joypad riapre la foto")
	await _frames(30)
	await _joy(JOY_BUTTON_START)
	await _frames(3)
	check(_visore() != null, "Start del joypad non chiude la foto (la pausa non ha il joypad)")
	await _joy(JOY_BUTTON_A)
	await _frames(3)
	check(_visore() == null and is_instance_valid(album) and get_tree().paused, "il bottone A del joypad chiude la foto: si resta nell'album")
	await _joy(JOY_BUTTON_A)
	await _frames(33)
	check(_visore() != null, "riaperta con A")
	await _joy(JOY_BUTTON_B)
	await _frames(3)
	check(_visore() == null and is_instance_valid(album) and get_tree().paused, "il bottone B del joypad chiude la foto: si resta nell'album")
	cornici[0].grab_focus()
	# A su una vuota (la 2): niente
	cornici[1].grab_focus()
	await _premi(&"ui_accept")
	await _frames(3)
	check(_visore() == null, "A su una cornice vuota non apre niente")

	print("4. Si chiude e torna alla pausa; in inglese")
	await _premi(&"ui_cancel")
	await _frames(3)
	check(Game.find_child("Album", true, false) == null and overlay.visible and get_tree().paused, "B chiude l'album e si torna al menu di pausa")
	TranslationServer.set_locale("en")
	Game.call(&"open_album")
	await _frames(3)
	album = Game.find_child("Album", true, false) as AlbumPolaroid
	conteggio = album.find_child("Conteggio", true, false) as Label if album else null
	check(conteggio != null and conteggio.text == "5 of 16", "in inglese il contatore è \"5 of 16\" (%s)" % (conteggio.text if conteggio else "-"))
	var indietro := album.find_child("Indietro", true, false) as Button if album else null
	check(indietro != null and indietro.text == "BACK", "e \"Indietro\" è \"BACK\"")
	if album:
		album.chiudi()
	await _frames(3)
	TranslationServer.set_locale("it")

	print("5. Il salvataggio")
	# (quello che va nell'istantanea e su disco, alla voce "collectibles": qui non c'è il giocatore per un'istantanea)
	var raccolte: Dictionary = GameState.call(&"_collected_to_lists")
	var lista: Array = raccolte.get("polaroid", [])
	check(lista.size() == TROVATE.size() + 1 and lista.has("PolaroidPecora") and lista.has("Polaroid10") and lista.has("p16"),
		"il salvataggio resta com'era: i nomi delle raccolte nella collezione \"polaroid\" (%s)" % str(lista))
	_fine()
