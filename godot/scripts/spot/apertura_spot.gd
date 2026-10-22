extends Control
## L'inquadratura 1 dello spot VHS (0-3 s): lo schermo blu del videoregistratore con la scritta PLAY (resta, scelta
## dell'utente del 22 ottobre), poi il logo di Jilly da nuovo. La regia la gira come le altre (a_tempo).

const LOGO_NUOVO := "res://assets/spot/logo_jilly_nuovo.png"
const LOGO_GIOCO := "res://assets/ui/logo/logo_jilly_jubilee.png"

## Secondi di schermo blu prima del logo, e durata della sua comparsa.
@export var blu_per := 1.1
@export var comparsa := 0.5

@onready var _play: Label = $Play
@onready var _logo: TextureRect = $Logo
@onready var _fondo: ColorRect = $Fondo


func _ready() -> void:
	# il logo senza ruggine (da fare); finché manca, quello del gioco
	_logo.texture = load(LOGO_NUOVO if ResourceLoader.exists(LOGO_NUOVO) else LOGO_GIOCO)
	a_tempo(0.0, 1)


func a_tempo(t: float, _n: int) -> void:
	_play.visible = t < blu_per + comparsa
	var u := clampf((t - blu_per) / comparsa, 0.0, 1.0)
	_fondo.color = Color(0.0, 0.08, 0.72).lerp(Color(0.55, 0.82, 0.97), u)
	_logo.modulate.a = u
	_logo.scale = Vector2.ONE * lerpf(0.92, 1.0, 1.0 - pow(1.0 - u, 3.0))
