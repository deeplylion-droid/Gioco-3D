extends Node
## Collaudo delle lingue (lavoro/inglese, 28 ottobre): con un renderer vero, nella lingua di LINGUA (it o en), uno
## scatto per schermata: titolo senza e con salvataggio (Continua), domanda di Nuova partita, opzioni (ogni scheda),
## cambio di lingua dalle opzioni (vale subito: scatto dopo aver scelto l'altra lingua e poi di nuovo questa),
## calibrazione, comandi, pausa, comandi dalla pausa, schermata di caricamento, attesa al ritorno al checkpoint, menu F9,
## i sottotitoli dello spot (uno per frase) e "FINE DEL CAPITOLO 1" (con e senza la riga della torre).
## Stampa anche i testi a schermo che escono dal loro riquadro o dallo schermo (FUORI) e quelli tagliati (TAGLIATO).
## Uso (sotto il render.lock):
##   LINGUA=en xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/collaudo/giro_lingua.gd <cartella>

const TITOLO := "res://scenes/ui/menu_principale.tscn"
var cartella := "user://giro_lingua"
var lingua := "it"
var _n := 0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var f := cartella.path_join("%s_%02d_%s.jpg" % [lingua, _n, nome])
	get_viewport().get_texture().get_image().save_jpg(f, 0.9)
	print("SCATTO ", f)
	_controlla_testi(get_tree().root, nome)


## I testi visibili che escono dallo schermo, o da un contenitore che taglia, o che non ci stanno (testo tagliato).
func _controlla_testi(radice: Node, dove: String) -> void:
	var schermo := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	for n in radice.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.get_global_rect().size == Vector2.ZERO:
			continue
		var testo := ""
		var minimo := Vector2.ZERO
		if c is Label:
			testo = c.atr((c as Label).text)   # (il testo a schermo: la traduzione della chiave)
			minimo = c.get_minimum_size()
			var lb := c as Label
			if lb.autowrap_mode == TextServer.AUTOWRAP_OFF and lb.clip_text == false:
				var font := lb.get_theme_font(&"font")
				var fs := lb.get_theme_font_size(&"font_size")
				var largo := 0.0
				for riga in testo.split("\n"):
					largo = maxf(largo, font.get_string_size(riga, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
				if largo > c.size.x + 2:
					print("TAGLIATO [%s] %s: «%s» largo %d su %d" % [dove, c.get_path(), testo.replace("\n", " / "), largo, c.size.x])
			if lb.get_visible_line_count() < lb.get_line_count() and lb.autowrap_mode != TextServer.AUTOWRAP_OFF:
				print("TAGLIATO [%s] %s: «%s» righe %d su %d" % [dove, c.get_path(), testo.replace("\n", " / "), lb.get_visible_line_count(), lb.get_line_count()])
		elif c is Button:
			testo = c.atr((c as Button).text)
			var b := c as Button
			var font := b.get_theme_font(&"font")
			var fs := b.get_theme_font_size(&"font_size")
			var margini := 0.0
			var sb := b.get_theme_stylebox(&"normal")
			if sb:
				margini = sb.get_content_margin(SIDE_LEFT) + sb.get_content_margin(SIDE_RIGHT)
			var largo := font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if testo != "" and largo > b.size.x - margini + 2:
				print("TAGLIATO [%s] %s: «%s» largo %d su %d" % [dove, c.get_path(), testo, largo, b.size.x])
		else:
			continue
		if testo.strip_edges() == "":
			continue
		var r := c.get_global_rect()
		if not schermo.grow(1).encloses(r):
			print("FUORI [%s] %s: «%s» %s" % [dove, c.get_path(), testo.replace("\n", " / "), r])


func _titolo() -> Node:
	get_tree().change_scene_to_file(TITOLO)
	await _frames(40)
	var menu := get_tree().current_scene
	menu.set(&"_t", 20.0)
	menu.call(&"_aggiorna_camera", 0.0)
	await _frames(15)
	return menu


func _run() -> void:
	lingua = Lingua.lingua
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	# 1. titolo senza salvataggio
	var menu := await _titolo()
	await _scatta("titolo_senza_salvataggio")
	# 2. titolo con salvataggio, domanda di Nuova partita
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(MenuProva.istantanea("torre")))
	f.close()
	menu = await _titolo()
	await _scatta("titolo_con_continua")
	menu.call(&"nuova_partita")
	await _frames(90)
	await _scatta("domanda_nuova_partita")
	menu = await _titolo()
	# 3. le opzioni, scheda per scheda
	menu.call(&"apri_opzioni")
	await _frames(30)
	var tabs := get_tree().root.find_children("*", "TabContainer", true, false)
	var tc: TabContainer = tabs[0] if not tabs.is_empty() else null
	if tc:
		for i in tc.get_tab_count():
			tc.current_tab = i
			await _frames(6)
			await _scatta("opzioni_%d_%s" % [i, tc.get_tab_title(i).to_lower().replace(" ", "_")])
		# il cambio di lingua dalle opzioni: si sceglie l'altra lingua nel menu a tendina, vale subito
		tc.current_tab = 0
		await _frames(4)
		var ob: OptionButton = null
		for o in tc.find_children("*", "OptionButton", true, false):
			if (o as OptionButton).get_item_text(0) == "Italiano":
				ob = o
		if ob:
			var altra := 1 - Lingua.LINGUE.find(lingua)
			ob.select(altra)
			ob.item_selected.emit(altra)
			await _frames(6)
			await _scatta("opzioni_cambiata_in_%s" % Lingua.LINGUE[altra])
			ob.select(1 - altra)
			ob.item_selected.emit(1 - altra)
			await _frames(6)
			await _scatta("opzioni_tornata_in_%s" % lingua)
		else:
			print("MANCA la scelta della lingua nelle opzioni")
	var opz := get_tree().root.find_children("*", "MenuOpzioni", true, false)
	if not opz.is_empty():
		opz[0].call(&"apri_calibrazione")
		await _frames(20)
		await _scatta("calibrazione")
	menu = await _titolo()
	# 4. i comandi dal titolo
	menu.call(&"apri_comandi")
	await _frames(30)
	await _scatta("comandi")
	menu = await _titolo()
	# 5. la pausa, i comandi e le opzioni dalla pausa
	Game.set_paused(true)
	await _frames(20)
	await _scatta("pausa")
	Game.open_controls()
	await _frames(20)
	await _scatta("pausa_comandi")
	if is_instance_valid(Game.get(&"_menu_layer")):
		(Game.get(&"_menu_layer") as Node).queue_free()
	Game.set(&"_menu_layer", null)
	Game.set_paused(false)
	await _frames(5)
	# 6. il menu F9
	menu.call(&"apri_prova")
	await _frames(30)
	await _scatta("menu_f9")
	# 7. l'attesa al ritorno al checkpoint
	var spia: CanvasLayer = Game.call(&"_mostra_attesa")
	await _frames(20)
	await _scatta("attesa_checkpoint")
	spia.queue_free()
	# 8. la schermata di caricamento (con una scena leggera al posto della sala)
	var car := (load("res://scenes/ui/caricamento.tscn") as PackedScene).instantiate()
	car.set(&"scena", "res://scenes/ui/comandi.tscn")
	get_tree().root.add_child(car)
	await _frames(40)
	await _scatta("caricamento")
	car.queue_free()
	await _frames(5)
	# 9. "FINE DEL CAPITOLO 1"
	get_tree().change_scene_to_packed(_vuota())
	await _frames(5)
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	get_tree().current_scene.add_child(hud)
	var nero := ColorRect.new()
	nero.color = Color.BLACK
	nero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lv := CanvasLayer.new()
	lv.layer = -1
	lv.add_child(nero)
	get_tree().current_scene.add_child(lv)
	await _frames(5)
	hud.call(&"show_banner", "FINE DEL CAPITOLO 1", "La discesa continua nel buio.\nGrazie per aver giocato!", 30.0)
	await _frames(90)
	await _scatta("fine_capitolo_torre")
	hud.call(&"show_banner", "FINE DEL CAPITOLO 1", "", 30.0)
	await _frames(90)
	await _scatta("fine_capitolo_tunnel")
	hud.queue_free()
	# 10. i sottotitoli dello spot, uno per frase (a metà di ogni frase)
	var dati: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/spot/spot_inquadrature.json"))
	var lettore: Node = LettoreSpot.avvia(get_tree())
	await _frames(10)
	for s in dati.get("sottotitoli", []):
		var quando := (float(s["da"]) + float(s["a"])) * 0.5
		while is_instance_valid(lettore) and float(lettore.get(&"_t")) < quando:
			await get_tree().process_frame
		if not is_instance_valid(lettore):
			print("lo spot è finito prima")
			break
		var sot := lettore.get_node(^"Sottotitolo") as Label
		print("SOTTOTITOLO %d a %.1f s: «%s»" % [int(s["frase"]), float(lettore.get(&"_t")), sot.text if sot.visible else ""])
		await _scatta("spot_frase_%d" % int(s["frase"]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	get_tree().quit()


func _vuota() -> PackedScene:
	var n := Node.new()
	n.name = "Vuota"
	var p := PackedScene.new()
	p.pack(n)
	n.free()
	return p
