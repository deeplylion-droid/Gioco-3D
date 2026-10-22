class_name LettoreSpot
extends CanvasLayer
## Il lettore dello spot VHS della crociera (GDD, "Lo spot della crociera Jubilee"): dopo "Nuova partita", prima del
## risveglio, a schermo intero. Il video (assets/spot/spot.ogv, registrato pulito dalla regia) va sotto; sopra, dal
## vivo, il filtro della TV a tubo e della VHS di enigmi con il guasto e l'effetto dell'occhio, e l'audio: la sigla
## pulita, poi quella rovinata, la voce dello speaker e il ronzio. Tempi in scenes/spot/spot_inquadrature.json
## ("audio" e "filtro").
## Si salta tenendo premuto un tasto qualunque (o un pulsante del joypad o del mouse) per [member tenere_per_saltare]
## secondi: un anello nell'angolo si riempie. Alla fine, o saltato, emette [signal finito] e, se c'è
## [member scena_dopo], passa a quella (col velo nero della Dissolvenza, come il menu).
## Uso dal menu (dopo la v0.3.9): LettoreSpot.avvia(get_tree(), SCENA_CARICAMENTO) al posto del cambio di scena.

signal finito

const INQUADRATURE := "res://scenes/spot/spot_inquadrature.json"
const SCENA := "res://scenes/spot/lettore_spot.tscn"

const VIDEO := "res://assets/spot/spot.ogv"

## Il video dello spot (null: [constant VIDEO]).
@export var video: VideoStream
## Lo shader del filtro VHS di enigmi (null: niente filtro). Riceve i parametri [member parametro_guasto] e
## [member parametro_occhio] (0..1, dalle chiavi "filtro" del JSON) e [member parametro_tempo] (secondi dello spot).
@export var filtro: Shader
@export var parametro_guasto := &"guasto"
@export var parametro_occhio := &"occhio"
@export var parametro_tempo := &"tempo_spot"
@export var tenere_per_saltare := 1.0
@export_file("*.tscn") var scena_dopo := ""
@export var bus := &"Musica"

var _dati: Dictionary
var _t := 0.0
var _audio: Array[Dictionary] = []     ## {voce: dict del JSON, player}
var _premuto := 0.0
var _tenuto := false
var _finito := false
@onready var _video: VideoStreamPlayer = $Video
@onready var _filtro: ColorRect = $Filtro
@onready var _anello: Control = $Anello


## Mette il lettore sopra tutto e lo fa partire; alla fine passa a [param poi] (vuoto: resta lì, si ascolta
## [signal finito]).
static func avvia(albero: SceneTree, poi := "") -> LettoreSpot:
	var l := (load(SCENA) as PackedScene).instantiate() as LettoreSpot
	l.scena_dopo = poi
	albero.root.add_child(l)
	return l


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dati = JSON.parse_string(FileAccess.get_file_as_string(INQUADRATURE))
	if video == null and ResourceLoader.exists(VIDEO):
		video = load(VIDEO)
	_video.stream = video
	if filtro:
		var m := ShaderMaterial.new()
		m.shader = filtro
		_filtro.material = m
	else:
		_filtro.visible = false
	for a in _dati["audio"]:
		if not ResourceLoader.exists(String(a["file"])):
			push_warning("spot: manca l'audio " + String(a["file"]))
			continue
		var p := AudioStreamPlayer.new()
		p.stream = load(String(a["file"]))
		p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
		p.volume_db = float(a.get("volume_db", 0.0))
		add_child(p)
		_audio.append({"voce": a, "player": p})
	_anello.draw.connect(_disegna_anello)
	_video.play()
	# se la Dissolvenza del menu è nera, si schiarisce subito: lo spot comincia dal suo schermo blu
	if Dissolvenza.presente(get_tree()):
		Dissolvenza.di(get_tree()).schiarisci(0.3)


func _process(delta: float) -> void:
	if _finito:
		return
	_t += delta
	# il video comanda il tempo finché va (l'audio resta in passo anche se un fotogramma tarda)
	if _video.is_playing():
		_t = maxf(_t, _video.stream_position)
	else:
		_video.visible = _t < float(_dati["durata_video"])
	for e in _audio:
		_suona(e, _t)
	if _filtro.material:
		var m := _filtro.material as ShaderMaterial
		m.set_shader_parameter(parametro_guasto, _chiave("guasto"))
		m.set_shader_parameter(parametro_occhio, _chiave("occhio"))
		m.set_shader_parameter(parametro_tempo, _t)
		# dopo il video (inquadratura 9) il filtro resta sul nero: solo il disturbo della TV
		_filtro.visible = _t < float(_dati["durata"])
	if _tenuto:
		_premuto += delta
		if _premuto >= tenere_per_saltare:
			_fine()
	else:
		_premuto = maxf(_premuto - delta * 2.0, 0.0)
	_anello.visible = _premuto > 0.0
	_anello.queue_redraw()
	if _t >= float(_dati["durata"]):
		_fine()


func _suona(e: Dictionary, t: float) -> void:
	var a: Dictionary = e["voce"]
	var p: AudioStreamPlayer = e["player"]
	var da := float(a["da"])
	var a_fine := float(a.get("a", da + p.stream.get_length()))
	if t >= da and t < a_fine:
		if not p.playing:
			p.play(t - da)
		var v := float(a.get("volume_db", 0.0))
		if a.has("sale_a_db"):
			v = lerpf(v, float(a["sale_a_db"]), clampf((t - da) / (a_fine - da), 0.0, 1.0))
		var sfuma := 1.0
		if a.has("sfuma_inizio"):
			sfuma = minf(sfuma, clampf((t - da) / float(a["sfuma_inizio"]), 0.0, 1.0))
		if a.has("sfuma_fine"):
			sfuma = minf(sfuma, clampf((a_fine - t) / float(a["sfuma_fine"]), 0.0, 1.0))
		p.volume_db = v + linear_to_db(maxf(sfuma, 0.0001))
	elif p.playing:
		p.stop()


## Il valore di [param campo] nelle chiavi "filtro" al tempo dello spot (lineare tra le chiavi).
func _chiave(campo: String) -> float:
	var chiavi: Array = _dati["filtro"]
	if _t <= float(chiavi[0]["t"]):
		return float(chiavi[0][campo])
	for i in chiavi.size() - 1:
		var a: Dictionary = chiavi[i]
		var b: Dictionary = chiavi[i + 1]
		if _t <= float(b["t"]):
			return lerpf(float(a[campo]), float(b[campo]), (_t - float(a["t"])) / maxf(float(b["t"]) - float(a["t"]), 1e-4))
	return float(chiavi[-1][campo])


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		if not event.is_echo():
			_tenuto = event.is_pressed()
		get_viewport().set_input_as_handled()


func _disegna_anello() -> void:
	var c := _anello.size * 0.5
	var r := minf(c.x, c.y) - 3.0
	_anello.draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 3.0, true)
	_anello.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(_premuto / tenere_per_saltare, 0.0, 1.0), 48,
			Color(1, 1, 1, 0.9), 3.0, true)


## Lo spot è finito (o saltato): tutto zitto, poi la scena dopo.
func _fine() -> void:
	if _finito:
		return
	_finito = true
	_video.stop()
	for e in _audio:
		(e["player"] as AudioStreamPlayer).stop()
	finito.emit()
	if scena_dopo != "":
		await Dissolvenza.di(get_tree()).scurisci(0.4)
		get_tree().change_scene_to_file(scena_dopo)
	queue_free()
