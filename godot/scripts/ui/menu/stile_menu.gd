class_name StileMenu
extends RefCounted
## Stile comune di titolo, caricamento e schermata dei comandi: colori, font, tema e pezzi
## riusati (voci del menu, tasti). Cupo come il concept A: testo chiaro e freddo, il rosso delle
## luci d'emergenza sulla voce scelta, il ciano dell'acqua sulle barre.
## Font (licenza SIL OFL 1.1, in res://ui/fonts/): Oswald per titoli e voci, Barlow per i testi.

const ROSSO := Color(0.93, 0.14, 0.09)
const CIANO := Color(0.42, 0.86, 0.9)
const TESTO := Color(0.84, 0.87, 0.89)
const TESTO_VOCE := Color(0.72, 0.76, 0.79)
const TESTO_SPENTO := Color(0.5, 0.56, 0.6)
const FONDO := Color(0.012, 0.016, 0.02)

const _OSWALD := preload("res://ui/fonts/Oswald.ttf")
const _BARLOW := preload("res://ui/fonts/Barlow-Regular.ttf")
const _BARLOW_FORTE := preload("res://ui/fonts/Barlow-SemiBold.ttf")

static var _cache := {}


## Oswald con il peso scelto (200 sottile ... 700 nero) e la spaziatura tra le lettere (pixel).
static func oswald(peso := 400, spaziatura := 0) -> Font:
	var chiave := "oswald_%d_%d" % [peso, spaziatura]
	if not _cache.has(chiave):
		var f := FontVariation.new()
		f.base_font = _OSWALD
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): peso}
		f.spacing_glyph = spaziatura
		_cache[chiave] = f
	return _cache[chiave]


static func barlow(forte := false) -> Font:
	return _BARLOW_FORTE if forte else _BARLOW


## Tema di base: testi in Barlow, pulsanti piatti con la barra rossa sulla voce scelta.
static func tema() -> Theme:
	if _cache.has("tema"):
		return _cache["tema"]
	var t := Theme.new()
	t.default_font = _BARLOW
	t.default_font_size = 19
	t.set_color("font_color", "Label", TESTO)
	var vuoto := StyleBoxEmpty.new()
	vuoto.content_margin_left = 30
	vuoto.content_margin_right = 18
	vuoto.content_margin_top = 3
	vuoto.content_margin_bottom = 5
	for stato in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		t.set_stylebox(stato, "Button", vuoto)
	t.set_stylebox("focus", "Button", _stile_scelta())
	t.set_font("font", "Button", oswald(400, 3))
	t.set_font_size("font_size", "Button", 30)
	t.set_color("font_color", "Button", TESTO_VOCE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ROSSO.lightened(0.45))
	t.set_color("font_hover_pressed_color", "Button", ROSSO.lightened(0.45))
	t.set_color("font_disabled_color", "Button", TESTO_SPENTO)
	# Barra di avanzamento sottile, color acqua.
	var fondo_barra := StyleBoxFlat.new()
	fondo_barra.bg_color = Color(1, 1, 1, 0.08)
	fondo_barra.set_content_margin_all(0)
	var pieno := StyleBoxFlat.new()
	pieno.bg_color = CIANO
	pieno.shadow_color = Color(CIANO, 0.35)
	pieno.shadow_size = 4
	t.set_stylebox("background", "ProgressBar", fondo_barra)
	t.set_stylebox("fill", "ProgressBar", pieno)
	_cache["tema"] = t
	return t


## Voce del menu: testo in maiuscolo; il mouse sopra la sceglie come la tastiera e il joypad.
static func voce(testo: String, dimensione := 30) -> Button:
	var b := Button.new()
	b.text = testo.to_upper()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if dimensione != 30:
		b.add_theme_font_size_override("font_size", dimensione)
	b.mouse_entered.connect(func():
		if not b.disabled:
			b.grab_focus())
	return b


## Collega le voci in verticale, con il giro dall'ultima alla prima e viceversa.
static func collega_voci(voci: Array) -> void:
	for i in voci.size():
		var b: Control = voci[i]
		var su: Control = voci[(i - 1 + voci.size()) % voci.size()]
		var giu: Control = voci[(i + 1) % voci.size()]
		b.focus_neighbor_top = b.get_path_to(su)
		b.focus_neighbor_bottom = b.get_path_to(giu)
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
		b.focus_previous = b.get_path_to(su)
		b.focus_next = b.get_path_to(giu)


## Un tasto disegnato come un tasto vero ("Maiusc", "E", "Tasto sinistro"...).
static func tasto(testo: String, dimensione := 17) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.085, 0.095, 0.92)
	s.border_color = Color(0.62, 0.68, 0.72, 0.55)
	s.set_border_width_all(1)
	s.border_width_bottom = 3
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 1
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = testo
	l.add_theme_font_override("font", _BARLOW_FORTE)
	l.add_theme_font_size_override("font_size", dimensione)
	l.add_theme_color_override("font_color", TESTO)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Etichetta con font, dimensione e colore in una riga.
static func etichetta(testo: String, font: Font, dimensione: int, colore := TESTO) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", dimensione)
	l.add_theme_color_override("font_color", colore)
	return l


## Sfumatura orizzontale (per l'ombra dietro il menu e per la voce scelta).
static func sfumatura(colori: PackedColorArray, posizioni: PackedFloat32Array, larghezza := 256) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = posizioni
	g.colors = colori
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = larghezza
	tex.height = 4
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	return tex


## La voce scelta: barra rossa a sinistra (come una luce d'emergenza) e un alone che sfuma.
static func _stile_scelta() -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = sfumatura(
		PackedColorArray([ROSSO, ROSSO, Color(ROSSO, 0.3), Color(ROSSO, 0.07), Color(ROSSO, 0.0)]),
		PackedFloat32Array([0.0, 0.014, 0.018, 0.5, 1.0]), 512)
	s.content_margin_left = 30
	s.content_margin_right = 18
	s.content_margin_top = 3
	s.content_margin_bottom = 5
	return s
