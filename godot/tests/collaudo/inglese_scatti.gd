extends Node
## Collaudo: il gioco in inglese, col renderer vero. Lingua "en" come dalle opzioni, poi scatti del titolo, di ogni
## scheda delle opzioni (aperte dal pulsante del titolo) e della schermata dei comandi; per ognuno stampa i testi a
## schermo (Label, Button, CheckBox, OptionButton) che non sono cambiati in inglese (uguali alla chiave italiana del CSV).
## Alla fine rimette l'italiano.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/collaudo/inglese_scatti.gd <cartella>

const TITOLO := "res://scenes/ui/menu_principale.tscn"
const COMANDI := "res://scenes/ui/comandi.tscn"
var cart := ""
var _it := {}


func _ready() -> void:
	cart = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.9)
	print("INGLESE: scatto ", nome)


## I testi visibili a schermo sotto [param radice] che sono ancora in italiano (una chiave del CSV con la traduzione
## diversa).
func _italiani(radice: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for n in radice.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		var testo := ""
		if c is Label:
			testo = (c as Label).text
		elif c is Button:
			testo = (c as Button).text
		if testo.strip_edges() == "":
			continue
		if _it.has(testo) and String(_it[testo]) != testo:
			out.append(testo)
	return out


func _run() -> void:
	Game.pause_on_focus_loss = false
	var f := FileAccess.open("res://lingue/testi.csv", FileAccess.READ)
	if f:
		while not f.eof_reached():
			var r := f.get_csv_line()
			if r.size() >= 3 and r[0] != "":
				_it[r[0]] = r[2]
	Lingua.imposta("en")
	get_tree().change_scene_to_file(TITOLO)
	await _frames(240)
	var sc := get_tree().current_scene
	await _scatto("titolo")
	print("INGLESE: titolo, ancora in italiano: %s" % [_italiani(sc)])
	# le opzioni dal pulsante del titolo
	var opz: Button = null
	for b in sc.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree() and (b as Button).text.to_lower().begins_with("option"):
			opz = b
	if opz == null:
		print("INGLESE: ERRORE nessun pulsante Options nel titolo")
	else:
		opz.pressed.emit()
		await _frames(30)
		var schede: Array = []
		for t in get_tree().root.find_children("*", "TabContainer", true, false):
			if (t as TabContainer).is_visible_in_tree():
				schede.append(t)
		print("INGLESE: opzioni aperte, %d gruppi di schede" % schede.size())
		var k := 0
		for t in schede:
			var tc := t as TabContainer
			for i in tc.get_tab_count():
				tc.current_tab = i
				await _frames(6)
				await _scatto("opzioni_%d_%d" % [k, i])
				print("INGLESE: scheda %d «%s», ancora in italiano: %s" % [i, tc.get_tab_title(i), _italiani(get_tree().root)])
			k += 1
		if schede.is_empty():
			await _scatto("opzioni")
			print("INGLESE: opzioni, ancora in italiano: %s" % [_italiani(get_tree().root)])
	# i comandi
	get_tree().change_scene_to_file(COMANDI)
	await _frames(60)
	await _scatto("comandi")
	print("INGLESE: comandi, ancora in italiano: %s" % [_italiani(get_tree().current_scene)])
	Lingua.imposta("it")
	await _frames(2)
	print("INGLESE: finito")
	get_tree().quit()
