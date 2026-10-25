class_name EffettiInseguimento
extends Node3D
## Gli effetti dell'inseguimento nel tunnel (approvati dall'utente il 25 ottobre, GDD: "gli effetti quando è vicina"),
## per sentire lei addosso senza girarsi. Tutti leggeri, e la distanza di lei non cambia (8-18 m):
## - sotto [member bordi_da] metri i bordi dello schermo si scuriscono, sempre di più fino a [member bordi_pieni];
## - a ogni morso a vuoto (SalaSottomarino.lei_morde) la camera trema appena, per [member tremito_durata] secondi
##   (niente se nelle opzioni l'oscillazione della camera è spenta);
## - la sua luce rosa ti supera: una SpotLight3D da lei verso la strada davanti al giocatore, che si posa sulle pareti
##   e sull'acqua davanti a te.
## Niente pipeline nuove a metà inseguimento: i bordi sono una TextureRect col gradiente (lo shader di sempre della
## UI) e la luce si accende già nel riscaldamento del tunnel ([method riscalda_da]), con le ombre come in gioco.
## La crea SalaSottomarino con lei (_lei_crea).

## Sotto questa distanza (m lungo la strada) i bordi cominciano a scurirsi; a [member bordi_pieni] sono al massimo.
@export var bordi_da := 8.0
@export var bordi_pieni := 3.0
## Quanto scuri al massimo (l'alfa del nero sui bordi).
@export var bordi_max := 0.6
## Il tremito a ogni morso: rotazione massima (gradi), spostamento massimo (m) e durata (s).
@export var tremito_gradi := 0.45
@export var tremito_metri := 0.008
@export var tremito_durata := 0.35
## La luce rosa davanti: quanti metri oltre il giocatore guarda, l'energia, l'apertura del cono (gradi).
@export var luce_avanti := 7.0
@export var luce_energia := 3.5
@export var luce_angolo := 26.0
## Dove nasce la luce, sopra l'origine di lei (come la sua OmniLight in LeiTunnel).
const LUCE_DA := Vector3(0, 2.6, 0.9)

var sala: SalaSottomarino
var bordi: TextureRect
var luce: SpotLight3D
## Quanto sono scuri i bordi ora (0-1, prima di [member bordi_max]) e quanto è accesa la luce (0-1).
var forza_bordi := 0.0
var forza_luce := 0.0
var _tremito := 0.0
var _tremito_t := 0.0
var _camera_mossa: Camera3D
var _riscalda := false


static func su(s: SalaSottomarino) -> EffettiInseguimento:
	var e := EffettiInseguimento.new()
	e.name = "EffettiInseguimento"
	e.sala = s
	s.add_child(e)
	return e


func _ready() -> void:
	var strato := CanvasLayer.new()
	strato.name = "Bordi"
	strato.layer = 0          # sotto l'HUD (1): il mirino e il serbatoio restano chiari
	add_child(strato)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.78, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 1)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	bordi = TextureRect.new()
	bordi.texture = tex
	bordi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bordi.stretch_mode = TextureRect.STRETCH_SCALE
	bordi.set_anchors_preset(Control.PRESET_FULL_RECT)
	bordi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bordi.modulate.a = 0.0
	strato.add_child(bordi)
	luce = SpotLight3D.new()
	luce.name = "LuceAvanti"
	luce.light_color = LeiTunnel.ROSA
	luce.light_energy = 0.0
	luce.spot_angle = luce_angolo
	luce.spot_angle_attenuation = 1.6
	luce.spot_attenuation = float(OS.get_environment("EFF_ATT")) if OS.has_environment("EFF_ATT") else 0.5   # (cala piano: arriva oltre il giocatore)
	luce.light_cull_mask = 0xFFFFF & ~2   # (non la lancia in mano: livello 2, viewmodel)
	luce.spot_range = 30.0
	luce.light_volumetric_fog_energy = 0.5
	luce.shadow_enabled = false      # (senza ombre: zero pipeline nuove, e costa poco; nasce davanti a lei)
	luce.set_meta(&"risveglio_ignora", true)
	luce.visible = false
	add_child(luce)
	sala.lei_morde.connect(morso)
	sala.giocatore_preso.connect(_ferma_tremito)


## Il riscaldamento del tunnel: la luce accesa davanti alla camera nascosta [param cam] (le pipeline delle sue ombre e
## della sua luce sui materiali del tunnel si compilano lì), e i bordi appena visibili. [param acceso] falso: finito.
func riscalda_da(cam: Camera3D, acceso: bool) -> void:
	_riscalda = acceso
	luce.visible = acceso
	luce.light_energy = luce_energia if acceso else 0.0
	# (il cono largo quanto la vista della camera nascosta: tutto quello che vede è illuminato, e fa ombra, da lei)
	luce.spot_angle = 70.0 if acceso else luce_angolo
	luce.spot_range = 40.0
	if acceso:
		var d := -cam.global_transform.basis.z
		luce.global_position = cam.global_position - d * 1.0 + Vector3.UP * 0.5
		luce.look_at(cam.global_position + d * 8.0, Vector3.UP)
	bordi.modulate.a = 0.004 if acceso else 0.0


## Un morso a vuoto: la camera trema appena.
func morso() -> void:
	_tremito = 1.0
	_tremito_t = 0.0


func _process(delta: float) -> void:
	if _riscalda:
		return
	var gap := INF
	var attiva := sala.lei_stato == SalaSottomarino.Lei.INSEGUE or sala.lei_stato == SalaSottomarino.Lei.RESPINTA \
			or sala.lei_stato == SalaSottomarino.Lei.SALE
	if attiva and sala.lei_tunnel and sala.lei_tunnel.lei.visible and not sala.finito:
		gap = sala._s_bersaglio - sala.lei_s
	# i bordi: salgono in fretta quando si avvicina, scendono più piano
	var vuole := 0.0
	if gap < bordi_da:
		vuole = smoothstep(bordi_da, bordi_pieni, gap)
	forza_bordi = lerpf(forza_bordi, vuole, 1.0 - exp(-(4.0 if vuole > forza_bordi else 1.5) * delta))
	bordi.modulate.a = forza_bordi * bordi_max
	bordi.visible = bordi.modulate.a > 0.002
	# la luce davanti: accesa mentre lei ti insegue, più forte quando è vicina
	var vuole_luce := 0.0
	if gap < sala.distanza_max + 6.0:
		vuole_luce = lerpf(1.0, 0.55, clampf((gap - bordi_pieni) / (sala.distanza_max - bordi_pieni), 0.0, 1.0))
	forza_luce = lerpf(forza_luce, vuole_luce, 1.0 - exp(-2.5 * delta))
	luce.visible = forza_luce > 0.01
	if luce.visible:
		_metti_luce(gap)
	_aggiorna_tremito(delta)


## La luce nasce da lei e guarda la strada [member luce_avanti] metri oltre il giocatore, poco sopra l'acqua.
func _metti_luce(gap: float) -> void:
	var da := sala.lei_tunnel.lei.global_transform * LUCE_DA
	var s := minf(sala._s_bersaglio + luce_avanti, sala.lunghezza())
	var a := sala.punto(s)
	a.y = sala.acqua + 0.6
	if da.distance_to(a) < 0.5:
		return
	luce.global_position = da
	luce.look_at(a, Vector3.UP)
	luce.spot_range = clampf(da.distance_to(a) + 6.0, 10.0, 40.0)
	luce.light_energy = (float(OS.get_environment("EFF_E")) if OS.has_environment("EFF_E") else luce_energia) * forza_luce * (1.0 if is_finite(gap) else 0.0)


func _aggiorna_tremito(delta: float) -> void:
	var p := GameState.player
	var cam: Camera3D = p.camera if p and is_instance_valid(p) else null
	if _tremito <= 0.0 or cam == null:
		_ferma_tremito()
		return
	if not p.head_bob_enabled or not p.input_enabled:
		_ferma_tremito()
		return
	_tremito_t += delta
	var k := 1.0 - _tremito_t / tremito_durata
	if k <= 0.0:
		_ferma_tremito()
		return
	k *= k
	var t := _tremito_t * 38.0
	var r := deg_to_rad(tremito_gradi) * k
	cam.rotation = Vector3(sin(t) * r, sin(t * 1.37 + 1.1) * r * 0.6, sin(t * 0.83 + 2.3) * r * 0.5)
	cam.position = Vector3(sin(t * 1.21 + 0.4), sin(t * 0.91 + 2.0), 0.0) * tremito_metri * k
	_camera_mossa = cam


## Rimette la camera a posto (alla fine del tremito o quando lei ti prende: lì la muove la sequenza della morte).
func _ferma_tremito() -> void:
	_tremito = 0.0
	if _camera_mossa and is_instance_valid(_camera_mossa):
		_camera_mossa.rotation = Vector3.ZERO
		_camera_mossa.position = Vector3.ZERO
	_camera_mossa = null
