class_name MenuOpzioni
extends Control
## Menu delle opzioni grafiche, costruito da codice. Ogni modifica passa per
## l'autoload Grafica: si applica subito e si salva in user://settings.cfg.
## Uso: var m := MenuOpzioni.new(); add_child(m)  (meglio dentro un CanvasLayer
## con layer 100, sopra il post-processing). Segnale "chiuso" quando si esce.
## Lo stile è volutamente neutro: quello definitivo lo decide l'utente.

signal chiuso

const ACCENTO := Color(0.55, 0.78, 0.86)

var _controlli := {}          # chiave -> controllo
var _preset: OptionButton
var _nota_aa: Label
var _calibrazione: CalibrazioneLuminosita
var _tabs: TabContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _crea_tema()
	var sfondo := ColorRect.new()
	sfondo.color = Color(0, 0, 0, 0.55)
	sfondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sfondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var pannello := PanelContainer.new()
	pannello.custom_minimum_size = Vector2(780, 580)
	centro.add_child(pannello)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	pannello.add_child(col)

	var testa := HBoxContainer.new()
	var titolo := Label.new()
	titolo.text = "Opzioni grafiche"
	titolo.add_theme_font_size_override("font_size", 26)
	titolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	testa.add_child(titolo)
	var lp := Label.new()
	lp.text = "Preset"
	testa.add_child(lp)
	_preset = OptionButton.new()
	for n in ["Basso", "Medio", "Alto", "Ultra", "Personalizzato"]:
		_preset.add_item(n)
	_preset.set_item_disabled(4, true)
	_preset.custom_minimum_size.x = 180
	_preset.item_selected.connect(func(i): if i < 4: Grafica.applica_preset(Grafica.PRESET_NOMI[i]))
	testa.add_child(_preset)
	col.add_child(testa)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)

	var t := _scheda("Schermo")
	_scelta(t, "Modalità", "modalita_finestra", ["Finestra", "Schermo intero", "Schermo intero esclusivo"])
	var ris: Array[String] = []
	for r in Grafica.RISOLUZIONI:
		ris.append("%d × %d" % [r.x, r.y])
	_scelta(t, "Risoluzione (in finestra)", "risoluzione", ris)
	_scelta(t, "Sincronia verticale (VSync)", "vsync", ["No", "Sì", "Adattiva", "Mailbox"])
	_scelta(t, "Limite FPS", "limite_fps", ["Nessuno", "30", "60", "120", "144", "165", "240"],
		[0, 30, 60, 120, 144, 165, 240])
	_cursore(t, "Campo visivo (FOV)", "fov", 50, 90, 1, "%d°")

	t = _scheda("Resa")
	_cursore(t, "Scala di rendering", "scala_rendering", 0.5, 1.0, 0.01, "%d%%", 100.0)
	_scelta(t, "Upscaler", "upscaler", ["Bilineare", "AMD FSR 1.0", "AMD FSR 2.2"])
	_cursore(t, "Nitidezza FSR", "nitidezza_fsr", 0.0, 2.0, 0.05, "%d%%", 50.0, true)
	_scelta(t, "Antialiasing", "antialiasing", ["No", "FXAA", "SMAA (nitido)", "TAA (morbido)", "MSAA 2×", "MSAA 4×", "MSAA 8×"])
	_nota_aa = Label.new()
	_nota_aa.add_theme_color_override("font_color", Color(0.65, 0.68, 0.7))
	_nota_aa.add_theme_font_size_override("font_size", 14)
	_nota_aa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_child(_nota_aa)
	_scelta(t, "Qualità delle texture", "qualita_texture", ["Bassa", "Media", "Alta"])

	t = _scheda("Luci e ombre")
	_scelta(t, "Ombre", "ombre", ["Minime (solo torcia)", "Basse", "Medie", "Alte", "Ultra"])
	_scelta(t, "Illuminazione globale", "gi", ["No", "VoxelGI", "SDFGI"])
	_scelta(t, "Nebbia", "nebbia", ["Semplice", "Volumetrica", "Volumetrica alta"])
	_scelta(t, "Riflessi (SSR)", "ssr", ["No", "Bassi", "Medi", "Alti"])
	_scelta(t, "Occlusione ambientale (SSAO)", "ssao", ["No", "Bassa", "Media", "Alta", "Ultra"])
	_scelta(t, "Luce indiretta (SSIL)", "ssil", ["No", "Bassa", "Media", "Alta", "Ultra"])
	_scelta(t, "Particelle", "particelle", ["Poche", "Medie", "Tutte"])

	t = _scheda("Immagine")
	_cursore(t, "Esposizione", "esposizione", 0.5, 2.0, 0.05, "%.2f")
	_cursore(t, "Contrasto", "contrasto", 0.8, 1.3, 0.01, "%.2f")
	_cursore(t, "Saturazione", "saturazione", 0.5, 1.3, 0.01, "%.2f")
	_scelta(t, "Color grading", "color_grading", Grafica.GRADING)
	_spunta(t, "Bagliore (glow)", "glow")
	_spunta(t, "Grana della pellicola", "grana")
	_spunta(t, "Vignettatura", "vignetta")
	_spunta(t, "Aberrazione cromatica", "aberrazione")
	_spunta(t, "Profondità di campo (lontano)", "profondita_campo")
	_spunta(t, "Riduci i lampi (fotosensibilità)", "riduci_lampi")

	t = _scheda("Controlli")
	_cursore(t, "Sensibilità del mouse", "sensibilita_mouse", 0.2, 3.0, 0.05, "%.2f")
	_spunta(t, "Inverti l'asse Y", "inverti_y")
	_spunta(t, "Oscillazione della camera", "oscillazione_camera")

	t = _scheda("Luminosità")
	_cursore(t, "Luminosità (gamma)", "luminosita", 0.6, 1.8, 0.01, "%.2f")
	var b := Button.new()
	b.text = "Calibra la luminosità…"
	b.pressed.connect(apri_calibrazione)
	t.add_child(b)

	var piede := HBoxContainer.new()
	piede.alignment = BoxContainer.ALIGNMENT_END
	piede.add_theme_constant_override("separation", 10)
	var rip := Button.new()
	rip.text = "Ripristina predefiniti"
	rip.pressed.connect(Grafica.ripristina_predefiniti)
	piede.add_child(rip)
	var chiudi := Button.new()
	chiudi.text = "Chiudi"
	chiudi.custom_minimum_size.x = 120
	chiudi.pressed.connect(chiudi_menu)
	piede.add_child(chiudi)
	col.add_child(piede)

	Grafica.impostazione_cambiata.connect(func(_k, _v): _aggiorna())
	_aggiorna()
	chiudi.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and _calibrazione == null:
		chiudi_menu()
		get_viewport().set_input_as_handled()


func chiudi_menu() -> void:
	chiuso.emit()
	# Se è la scena .tscn (CanvasLayer + Control), si chiude tutta.
	if owner is CanvasLayer:
		owner.queue_free()
	else:
		queue_free()


func apri_calibrazione() -> void:
	_calibrazione = CalibrazioneLuminosita.new()
	_calibrazione.chiusa.connect(func(): _calibrazione = null; _aggiorna())
	add_child(_calibrazione)


## Mostra una scheda (0..5), utile per gli screenshot.
func mostra_scheda(i: int) -> void:
	_tabs.current_tab = i


# --- Costruzione delle righe ---------------------------------------------------

func _scheda(nome: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = nome
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	_tabs.add_child(sc)
	return v


func _riga(contenitore: Control, titolo: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = titolo
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	contenitore.add_child(h)
	return h


func _scelta(c: Control, titolo: String, chiave: String, voci: Array, valori: Array = []) -> void:
	var o := OptionButton.new()
	for v in voci:
		o.add_item(v)
	o.custom_minimum_size.x = 260
	o.item_selected.connect(func(i): Grafica.imposta(chiave, valori[i] if valori else i))
	o.set_meta("valori", valori)
	_riga(c, titolo).add_child(o)
	_controlli[chiave] = o


func _cursore(c: Control, titolo: String, chiave: String, minimo: float, massimo: float, passo: float,
		formato: String, scala_testo := 1.0, inverti := false) -> void:
	var h := _riga(c, titolo)
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = massimo
	s.step = passo
	s.custom_minimum_size = Vector2(200, 0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.custom_minimum_size.x = 120 if chiave == "fov" else 60
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v):
		var reale: float = (massimo + minimo - v) if inverti else v
		l.text = _testo(chiave, formato, v * scala_testo)
		if chiave == "fov" or chiave == "limite_fps":
			Grafica.imposta(chiave, roundf(reale))
		else:
			Grafica.imposta(chiave, reale))
	s.set_meta("inverti", inverti)
	s.set_meta("etichetta", l)
	s.set_meta("formato", formato)
	s.set_meta("scala_testo", scala_testo)
	h.add_child(s)
	h.add_child(l)
	_controlli[chiave] = s


## Testo accanto al cursore; il FOV mostra anche i gradi orizzontali.
func _testo(chiave: String, formato: String, v: float) -> String:
	if chiave == "fov":
		return "%d° (%d° orizz.)" % [roundi(v), roundi(Grafica.fov_orizzontale(v))]
	return formato % v


func _spunta(c: Control, titolo: String, chiave: String) -> void:
	var b := CheckButton.new()
	b.toggled.connect(func(v): Grafica.imposta(chiave, v))
	_riga(c, titolo).add_child(b)
	_controlli[chiave] = b


func _aggiorna() -> void:
	var nome: String = Grafica.valore("preset")
	_preset.set_block_signals(true)
	_preset.select(Grafica.PRESET_NOMI.find(nome) if nome in Grafica.PRESET_NOMI else 4)
	_preset.set_block_signals(false)
	for chiave in _controlli:
		var c: Control = _controlli[chiave]
		var v: Variant = Grafica.valore(chiave)
		c.set_block_signals(true)
		if c is OptionButton:
			var valori: Array = c.get_meta("valori")
			(c as OptionButton).select(valori.find(v) if valori else int(v))
		elif c is HSlider:
			var s := c as HSlider
			s.value = (s.max_value + s.min_value - float(v)) if s.get_meta("inverti") else float(v)
			(s.get_meta("etichetta") as Label).text = _testo(chiave, String(s.get_meta("formato")), s.value * float(s.get_meta("scala_testo")))
		elif c is CheckButton:
			(c as CheckButton).button_pressed = bool(v)
		c.set_block_signals(false)
	var up := int(Grafica.valore("upscaler"))
	var scala := float(Grafica.valore("scala_rendering"))
	(_controlli["nitidezza_fsr"] as Control).get_parent().visible = up != 0
	var nota := ""
	if up == 2:
		nota = "FSR 2 fa anche da antialiasing temporale: TAA, FXAA e SMAA non servono. Al 100% di scala è usato solo come antialiasing."
	elif up == 1 and scala >= 1.0:
		nota = "FSR 1 ha effetto solo con la scala di rendering sotto il 100%."
	_nota_aa.text = nota
	_nota_aa.visible = nota != ""


func _crea_tema() -> Theme:
	var th := Theme.new()
	th.default_font_size = 17
	var p := StyleBoxFlat.new()
	p.bg_color = Color(0.07, 0.075, 0.085, 0.96)
	p.set_corner_radius_all(8)
	p.set_content_margin_all(22)
	p.border_color = Color(1, 1, 1, 0.06)
	p.set_border_width_all(1)
	th.set_stylebox("panel", "PanelContainer", p)
	var tabp := StyleBoxFlat.new()
	tabp.bg_color = Color(0.1, 0.105, 0.12)
	tabp.set_corner_radius_all(6)
	tabp.set_content_margin_all(16)
	th.set_stylebox("panel", "TabContainer", tabp)
	for stato in ["normal", "hover", "pressed", "focus", "disabled"]:
		var b := StyleBoxFlat.new()
		b.bg_color = Color(0.15, 0.16, 0.18) if stato != "hover" else Color(0.2, 0.22, 0.25)
		if stato == "pressed":
			b.bg_color = ACCENTO.darkened(0.55)
		if stato == "focus":
			b.bg_color = Color(0, 0, 0, 0)
			b.border_color = ACCENTO
			b.set_border_width_all(1)
		b.set_corner_radius_all(5)
		b.content_margin_left = 12
		b.content_margin_right = 12
		b.content_margin_top = 6
		b.content_margin_bottom = 6
		for tipo in ["Button", "OptionButton"]:
			th.set_stylebox(stato, tipo, b)
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(0.1, 0.105, 0.12)
	sel.border_color = ACCENTO
	sel.border_width_bottom = 2
	sel.set_content_margin_all(10)
	th.set_stylebox("tab_selected", "TabContainer", sel)
	var nosel := StyleBoxFlat.new()
	nosel.bg_color = Color(0, 0, 0, 0)
	nosel.set_content_margin_all(10)
	th.set_stylebox("tab_unselected", "TabContainer", nosel)
	th.set_stylebox("tab_hovered", "TabContainer", nosel)
	th.set_color("font_selected_color", "TabContainer", Color.WHITE)
	th.set_color("font_unselected_color", "TabContainer", Color(0.62, 0.65, 0.68))
	th.set_color("font_color", "Label", Color(0.86, 0.88, 0.9))
	var area := StyleBoxFlat.new()
	area.bg_color = ACCENTO
	area.content_margin_top = 3
	area.content_margin_bottom = 3
	area.set_corner_radius_all(3)
	th.set_stylebox("grabber_area", "HSlider", area)
	th.set_stylebox("grabber_area_highlight", "HSlider", area)
	var bin := StyleBoxFlat.new()
	bin.bg_color = Color(0.22, 0.23, 0.26)
	bin.content_margin_top = 3
	bin.content_margin_bottom = 3
	bin.set_corner_radius_all(3)
	th.set_stylebox("slider", "HSlider", bin)
	return th
