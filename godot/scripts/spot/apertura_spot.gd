extends Control
## L'inquadratura 1 dello spot VHS (0-3 s): il logo di Jilly da nuovo che compare. Lo schermo blu del videoregistratore
## e la scritta PLAY (resta, scelta dell'utente del 22 ottobre) li mette dal vivo il filtro VHS di enigmi
## (schermo_blu e play nelle chiavi "filtro" del JSON). La regia la gira come le altre (a_tempo).

const LOGO_NUOVO := "res://assets/models/mascotte/jilly_nuova/logo_jilly.png"   # di mascotte, senza ruggine
const LOGO_GIOCO := "res://assets/ui/logo/logo_jilly_jubilee.png"

## Secondi prima del logo (sotto lo schermo blu del filtro), e durata della sua comparsa.
@export var blu_per := 1.1
@export var comparsa := 0.5

@onready var _logo: TextureRect = $Logo
@onready var _fondo: ColorRect = $Fondo


func _ready() -> void:
	# il logo senza ruggine di mascotte (lavoro/spot-mascotte); finché il ramo non è unito, quello del gioco
	_logo.texture = load(LOGO_NUOVO if ResourceLoader.exists(LOGO_NUOVO) else LOGO_GIOCO)
	a_tempo(0.0, 1)


func a_tempo(t: float, _n: int) -> void:
	var u := clampf((t - blu_per) / comparsa, 0.0, 1.0)
	_fondo.color = Color(0.55, 0.82, 0.97)
	_logo.modulate.a = u
	_logo.scale = Vector2.ONE * lerpf(0.92, 1.0, 1.0 - pow(1.0 - u, 3.0))
