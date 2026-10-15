class_name Dissolvenza
extends CanvasLayer
## Velo nero sopra tutto (gioco, HUD, post-processing e menu) che sopravvive ai cambi di scena:
## sta sotto la radice. Si scurisce prima di cambiare scena e si schiarisce quando la scena
## nuova è pronta, poi si toglie da solo. Ce n'è uno solo: Dissolvenza.di(get_tree()).

const NOME := &"Dissolvenza"

var _nero: ColorRect
var _scritta: Label
var _tween: Tween
var _giro := 0  # cresce a ogni richiesta: una schiarita in attesa non ferma quelle dopo


## Il velo attuale, creato (trasparente) se non c'è.
static func di(albero: SceneTree) -> Dissolvenza:
	var d := albero.root.get_node_or_null(NodePath(NOME)) as Dissolvenza
	if d == null or d.is_queued_for_deletion():
		d = Dissolvenza.new()
		d.name = NOME
		# Differito: la radice può essere occupata (per esempio durante un cambio di scena).
		albero.root.add_child.call_deferred(d)
	return d


## C'è un velo (per esempio lasciato dalla scena precedente)?
static func presente(albero: SceneTree) -> bool:
	var d := albero.root.get_node_or_null(NodePath(NOME))
	return d != null and not d.is_queued_for_deletion()


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_nero = ColorRect.new()
	_nero.color = Color.BLACK
	_nero.modulate.a = 0.0
	_nero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_nero)
	# Scritta piccola in basso a destra, per le attese lunghe a schermo nero.
	_scritta = Label.new()
	_scritta.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_scritta.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_scritta.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_scritta.offset_right = -56
	_scritta.offset_bottom = -40
	_scritta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scritta.add_theme_font_override("font", StileMenu.barlow())
	_scritta.add_theme_font_size_override("font_size", 17)
	_scritta.add_theme_color_override("font_color", StileMenu.TESTO_SPENTO)
	_scritta.modulate.a = 0.0
	_nero.add_child(_scritta)


## Quanto è nero (0 trasparente, 1 nero).
func opacita() -> float:
	return _nero.modulate.a


## Nero subito, senza dissolvenza.
func nero(testo := "") -> void:
	_ferma()
	_nero.modulate.a = 1.0
	_scritta.text = testo
	_scritta.modulate.a = 1.0 if testo != "" else 0.0


## Dal trasparente al nero in [param durata] secondi. Si può aspettare con await.
func scurisci(durata := 0.8, testo := "") -> void:
	_ferma()
	_scritta.text = testo
	_tween = _nuovo_tween()
	_tween.tween_property(_nero, ^"modulate:a", 1.0, durata * (1.0 - _nero.modulate.a))
	if testo != "":
		_tween.parallel().tween_property(_scritta, ^"modulate:a", 1.0, durata * 0.5).set_delay(durata * 0.5)
	await _tween.finished


## Dal nero al trasparente, dopo [param attesa_frame] frame disegnati (per lasciare alla scena
## nuova il tempo di prepararsi: shader, ombre, GI). Alla fine il velo si toglie.
func schiarisci(durata := 1.2, attesa_frame := 0) -> void:
	_ferma()
	var giro := _giro
	var albero := Engine.get_main_loop() as SceneTree
	for i in attesa_frame:
		await albero.process_frame
	if giro != _giro:
		return  # nel frattempo è arrivata un'altra richiesta
	_tween = _nuovo_tween()
	_tween.tween_property(_scritta, ^"modulate:a", 0.0, minf(0.3, durata))
	_tween.parallel().tween_property(_nero, ^"modulate:a", 0.0, durata).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	queue_free()


func _nuovo_tween() -> Tween:
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return t


func _ferma() -> void:
	_giro += 1
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
