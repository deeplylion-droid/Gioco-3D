class_name PannelloAudio
extends VBoxContainer
## Pannello dei volumi: generale, musica, ambiente, effetti. Ogni modifica passa per l'autoload
## Audio, si sente subito e si salva da sola in user://settings.cfg (sezione [audio]).
## Lasciando il cursore parte un suono di prova sul suo bus.
##
## Si mette in qualunque menu:
##   add_child(preload("res://addons/audio/pannello_audio.tscn").instantiate())
## L'autoload Audio lo aggiunge già da solo come scheda "Audio" al menu delle opzioni
## dell'addon grafica (MenuOpzioni).

const VOCI := [
	["generale", "Volume generale"],
	["musica", "Musica"],
	["ambiente", "Ambiente (pioggia, vento, nave)"],
	["effetti", "Effetti"],
]

var _cursori := {}       # chiave -> HSlider
var _etichette := {}     # chiave -> Label con la percentuale


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var audio := _audio()
	for voce in VOCI:
		var chiave: String = voce[0]
		var riga := HBoxContainer.new()
		var nome := Label.new()
		nome.text = voce[1]
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		riga.add_child(nome)
		var s := HSlider.new()
		s.name = "Cursore_" + chiave
		s.min_value = 0.0
		s.max_value = 100.0
		s.step = 1.0
		s.custom_minimum_size = Vector2(220, 0)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		riga.add_child(s)
		var perc := Label.new()
		perc.custom_minimum_size.x = 56
		perc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		riga.add_child(perc)
		add_child(riga)
		_cursori[chiave] = s
		_etichette[chiave] = perc
		s.value_changed.connect(func(v: float):
			perc.text = "%d%%" % roundi(v)
			var a := _audio()
			if a:
				a.call(&"imposta_volume", chiave, v / 100.0))
		s.drag_ended.connect(func(cambiato: bool):
			var a := _audio()
			if cambiato and a:
				a.call(&"prova_volume", chiave))
	var nota := Label.new()
	nota.text = "I volumi si salvano da soli."
	nota.add_theme_font_size_override("font_size", 14)
	nota.add_theme_color_override("font_color", Color(0.65, 0.68, 0.7))
	add_child(nota)
	var piede := HBoxContainer.new()
	piede.alignment = BoxContainer.ALIGNMENT_END
	var rip := Button.new()
	rip.text = "Ripristina i volumi"
	rip.pressed.connect(func():
		var a := _audio()
		if a:
			a.call(&"ripristina_volumi"))
	piede.add_child(rip)
	add_child(piede)
	if audio and audio.has_signal(&"volume_cambiato"):
		audio.connect(&"volume_cambiato", func(_k, _v): aggiorna())
	aggiorna()


## Rilegge i volumi dall'autoload (senza far ripartire i suoni di prova).
func aggiorna() -> void:
	var a := _audio()
	for chiave in _cursori:
		var s: HSlider = _cursori[chiave]
		var v := float(a.call(&"volume", chiave)) if a else 1.0
		s.set_block_signals(true)
		s.value = roundf(v * 100.0)
		s.set_block_signals(false)
		(_etichette[chiave] as Label).text = "%d%%" % roundi(s.value)


func _audio() -> Node:
	return get_node_or_null(^"/root/Audio") if is_inside_tree() else null
