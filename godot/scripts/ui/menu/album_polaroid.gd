class_name AlbumPolaroid
extends Control
## L'album delle Polaroid, dal menu di pausa (scelta A dell'utente del 4 novembre, proposta enigmi-1; scena
## res://scenes/ui/album_polaroid.tscn, CanvasLayer di livello 100 come i comandi): le 16 Polaroid del capitolo in ordine,
## in due file da otto. Quelle trovate mostrano la foto e, scelte, si riaprono grandi come quando le hai raccolte;
## quelle che mancano sono cornici vuote, senza dire dove cercarle. Sopra, il contatore "n su 16".
## Si gira con le frecce, il mouse o il joypad; si chiude con "Indietro", Esc o B. Il salvataggio non cambia: legge
## le Polaroid raccolte da GameState (PolaroidPhoto.NOMI_RACCOLTA).

signal chiuso

const COLONNE := 8
## La cornice in pixel (le foto sono 1024 x 1245) e lo spazio fra l'una e l'altra.
const CORNICE := Vector2(118, 143)
const SPAZIO := 16
## La foto dentro la carta bianca della Polaroid (in frazioni della carta, come nelle texture Pxx.jpg).
const FOTO_DENTRO := Rect2(0.051, 0.061, 0.896, 0.738)

var _cornici: Array[Button] = []
var _indietro: Button
var _conteggio: Label
var _visore: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = StileMenu.tema()
	var fondo := ColorRect.new()
	fondo.color = Color(StileMenu.FONDO, 0.9)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	centro.add_child(col)

	var testa := HBoxContainer.new()
	testa.add_theme_constant_override("separation", 24)
	col.add_child(testa)
	var titolo := StileMenu.etichetta("POLAROID", StileMenu.oswald(600, 6), 40)
	testa.add_child(titolo)
	_conteggio = StileMenu.etichetta("", StileMenu.barlow(true), 22, StileMenu.TESTO_VOCE)
	_conteggio.name = "Conteggio"
	_conteggio.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_conteggio.size_flags_vertical = Control.SIZE_SHRINK_END
	testa.add_child(_conteggio)
	Lingua.segui(_conteggio, func(): _conteggio.text = Lingua.t("%d su %d") % [PolaroidPhoto.quante_trovate(), PolaroidPhoto.NOMI_RACCOLTA.size()])
	col.add_child(_linea())
	var spazio := Control.new()
	spazio.custom_minimum_size.y = 14
	col.add_child(spazio)

	var griglia := GridContainer.new()
	griglia.name = "Cornici"
	griglia.columns = COLONNE
	griglia.add_theme_constant_override("h_separation", SPAZIO)
	griglia.add_theme_constant_override("v_separation", SPAZIO + 6)
	col.add_child(griglia)
	for n in range(1, PolaroidPhoto.NOMI_RACCOLTA.size() + 1):
		var b := _cornice(n)
		griglia.add_child(b)
		_cornici.append(b)

	var spazio2 := Control.new()
	spazio2.custom_minimum_size.y = 18
	col.add_child(spazio2)
	_indietro = StileMenu.voce("Indietro", 26)
	_indietro.name = "Indietro"
	_indietro.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_indietro.custom_minimum_size.x = 220
	_indietro.pressed.connect(chiudi)
	col.add_child(_indietro)
	_collega_focus()
	_cornici[0].grab_focus.call_deferred()


## La cornice della foto [param n]: un pulsante grande quanto la Polaroid, con la foto se è trovata, vuota se no.
func _cornice(n: int) -> Button:
	var b := Button.new()
	b.name = "Polaroid%02d" % n
	b.custom_minimum_size = CORNICE
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var vuoto := StyleBoxEmpty.new()
	for stato in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(stato, vuoto)
	# scelta: la barra rossa delle voci del menu, qui come un bordo attorno alla cornice
	var scelta := StyleBoxFlat.new()
	scelta.draw_center = false
	scelta.border_color = StileMenu.ROSSO
	scelta.set_border_width_all(3)
	scelta.set_expand_margin_all(5)
	scelta.set_corner_radius_all(2)
	b.add_theme_stylebox_override("focus", scelta)
	b.mouse_entered.connect(func(): b.grab_focus())
	var trovata := PolaroidPhoto.trovata(n)
	b.set_meta(&"trovata", trovata)
	if trovata:
		var foto := TextureRect.new()
		foto.name = "Foto"
		foto.texture = PolaroidPhoto.texture_di(n)
		foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		foto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(foto)
		b.pressed.connect(_apri.bind(n))
	else:
		# la cornice vuota: la carta bianca della Polaroid, spenta, e dentro il riquadro della foto scuro
		var carta := Panel.new()
		carta.name = "Vuota"
		var sc := StyleBoxFlat.new()
		sc.bg_color = Color(0.85, 0.84, 0.8, 0.22)
		sc.set_corner_radius_all(2)
		carta.add_theme_stylebox_override("panel", sc)
		carta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		carta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(carta)
		var dentro := ColorRect.new()
		dentro.color = Color(0.02, 0.025, 0.03, 0.85)
		dentro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dentro.anchor_left = FOTO_DENTRO.position.x
		dentro.anchor_top = FOTO_DENTRO.position.y
		dentro.anchor_right = FOTO_DENTRO.end.x
		dentro.anchor_bottom = FOTO_DENTRO.end.y
		carta.add_child(dentro)
	return b


## La foto [param n] grande, come quando l'hai raccolta; chiusa, si torna all'album (il gioco resta in pausa).
func _apri(n: int) -> void:
	if is_instance_valid(_visore):
		return
	_visore = PolaroidPhoto.VIEWER.new()
	_visore.set(&"texture", PolaroidPhoto.texture_di(n))
	_visore.set(&"riprendi", false)
	_visore.set(&"livello", 105)
	var cornice := _cornici[n - 1]
	_visore.tree_exited.connect(func():
		if is_instance_valid(cornice) and cornice.is_inside_tree():
			cornice.grab_focus())
	get_tree().root.add_child(_visore)


## Il focus: frecce e croce del joypad girano fra le cornici (otto per fila) e da sotto si arriva a "Indietro".
func _collega_focus() -> void:
	var tot := _cornici.size()
	var file := ceili(float(tot) / COLONNE)
	for i in tot:
		var b := _cornici[i]
		var r := i / COLONNE
		var c := i % COLONNE
		var sx := _cornici[r * COLONNE + (c - 1 + COLONNE) % COLONNE]
		var dx := _cornici[mini(r * COLONNE + (c + 1) % COLONNE, tot - 1)]
		b.focus_neighbor_left = b.get_path_to(sx)
		b.focus_neighbor_right = b.get_path_to(dx)
		b.focus_neighbor_top = b.get_path_to(_cornici[i - COLONNE] if r > 0 else _indietro)
		b.focus_neighbor_bottom = b.get_path_to(_cornici[i + COLONNE] if r < file - 1 and i + COLONNE < tot else _indietro)
		b.focus_next = b.get_path_to(_cornici[i + 1] if i < tot - 1 else _indietro)
		b.focus_previous = b.get_path_to(_cornici[i - 1] if i > 0 else _indietro)
	_indietro.focus_neighbor_top = _indietro.get_path_to(_cornici[(file - 1) * COLONNE])
	_indietro.focus_neighbor_bottom = _indietro.get_path_to(_cornici[0])
	_indietro.focus_neighbor_left = _indietro.get_path_to(_indietro)
	_indietro.focus_neighbor_right = _indietro.get_path_to(_indietro)
	_indietro.focus_next = _indietro.get_path_to(_cornici[0])
	_indietro.focus_previous = _indietro.get_path_to(_cornici[tot - 1])


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_visore):
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		chiudi()


## Le cornici, per i test.
func cornici() -> Array[Button]:
	return _cornici


func chiudi() -> void:
	if is_queued_for_deletion():
		return
	if is_instance_valid(_visore):
		_visore.queue_free()
	chiuso.emit()
	if owner is CanvasLayer:
		owner.queue_free()
	else:
		queue_free()


func _linea() -> Control:
	var r := ColorRect.new()
	r.color = StileMenu.ROSSO
	r.custom_minimum_size = Vector2(64, 3)
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return r
