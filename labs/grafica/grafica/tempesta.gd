class_name Tempesta
extends Node3D
## Lampi della tempesta visti attraverso la cupola.
## Muove una DirectionalLight3D (luce del lampo, con ombre che si spostano a ogni
## scarica), il cielo (shader cielo_tempesta.gdshader) e gli eventuali materiali
## che hanno il parametro "lampo" (per esempio il vetro della cupola).
## Il tuono arriva in ritardo, come nella realtà (circa 3 secondi per km):
## collegare il segnale "tuono" all'audio.

signal lampo(intensita: float)                       # inizio di un lampo
signal tuono(intensita: float, distanza_km: float)   # da suonare ora

## Strato di rendering escluso dalla luce del lampo (usato dal pulviscolo).
const STRATO_NO_LAMPO := 1 << 19

@export var automatica := true
@export var intervallo_min := 7.0
@export var intervallo_max := 18.0
@export var energia_lampo := 9.0
@export var colore_lampo := Color(0.74, 0.82, 1.0)
@export var luce: DirectionalLight3D
## Se vuoto, usa il cielo dell'Environment se è uno ShaderMaterial.
@export var cielo: ShaderMaterial
@export var materiali: Array[ShaderMaterial] = []
@export var distanza_min_km := 0.4
@export var distanza_max_km := 5.0

var intensita := 0.0          # intensità attuale (0..1+), leggibile da altri effetti
var _attesa := 3.0
var _t := 0.0                 # tempo dall'inizio del lampo in corso
var _impulsi: Array = []      # [inizio, picco, decadimento, azimut]
var _durata := 0.0
var _elevazione := 1.0
var _azimut := 0.0
var _seme := 0.0


func _ready() -> void:
	if luce == null:
		luce = DirectionalLight3D.new()
		luce.name = "LuceLampo"
		luce.shadow_enabled = true
		luce.light_angular_distance = 1.5
		luce.light_volumetric_fog_energy = 1.2
		add_child(luce)
	luce.light_color = colore_lampo
	luce.light_cull_mask &= ~STRATO_NO_LAMPO
	luce.light_energy = 0.0
	luce.visible = false
	_attesa = randf_range(2.0, intervallo_min)


func _process(delta: float) -> void:
	if cielo == null:
		var env := get_viewport().find_world_3d().environment
		if env and env.sky and env.sky.sky_material is ShaderMaterial:
			cielo = env.sky.sky_material
	if _impulsi.is_empty():
		if automatica:
			_attesa -= delta
			if _attesa <= 0.0:
				lampo_ora()
		return
	_t += delta
	var fattore: float = Grafica.fattore_lampi() if is_instance_valid(Grafica) else 1.0
	var i := 0.0
	var az := _azimut
	for p in _impulsi:
		if _t >= p[0]:
			var dt: float = _t - p[0]
			var att := clampf(dt / 0.012, 0.0, 1.0)
			var v: float = p[1] * att * exp(-dt / p[2])
			if v > i * 0.6:
				az = p[3]
			i += v
	intensita = i * fattore
	_imposta_direzione(az + _t * 0.03)
	luce.light_energy = energia_lampo * intensita
	luce.visible = intensita > 0.003
	_imposta_parametri(intensita, clampf(i * 1.5, 0.0, 1.0) if _t < _durata * 0.6 else 0.0)
	if _t > _durata:
		_impulsi.clear()
		intensita = 0.0
		luce.visible = false
		_imposta_parametri(0.0, 0.0)
		_attesa = randf_range(intervallo_min, intervallo_max)


## Fa partire subito un lampo. "forza" scala l'intensità (es. 1.5 per un colpo vicino).
## "azimut" (radianti, 0 = verso +Z) sceglie da dove arriva; se NAN è casuale.
func lampo_ora(forza := 1.0, distanza_km := -1.0, azimut := NAN) -> void:
	if distanza_km < 0.0:
		distanza_km = randf_range(distanza_min_km, distanza_max_km)
	_t = 0.0
	_seme = randf() * 100.0
	_azimut = randf() * TAU if is_nan(azimut) else azimut
	_elevazione = deg_to_rad(randf_range(48.0, 72.0))
	_impulsi.clear()
	var riduci: bool = is_instance_valid(Grafica) and Grafica.valore("riduci_lampi")
	var n := 1 if riduci else randi_range(2, 4)
	var t := 0.0
	for k in n:
		var picco := randf_range(0.5, 1.0) * forza * (1.0 if k == 0 else randf_range(0.6, 1.1))
		var dec := randf_range(0.05, 0.11) if not riduci else 0.35
		_impulsi.append([t, picco, dec, _azimut + randf_range(-0.12, 0.12)])
		t += randf_range(0.06, 0.24)
	_durata = t + 0.8
	var intensita_tuono := clampf(forza / (0.6 + distanza_km * 0.5), 0.1, 1.5)
	lampo.emit(forza)
	get_tree().create_timer(distanza_km * 2.9, false).timeout.connect(
		func(): tuono.emit(intensita_tuono, distanza_km))


func _imposta_direzione(az: float) -> void:
	# La luce arriva dall'alto, dalla parte del fulmine.
	var verso_fulmine := Vector3(sin(az) * cos(_elevazione), sin(_elevazione), cos(az) * cos(_elevazione))
	luce.global_basis = Basis.looking_at(-verso_fulmine, Vector3.FORWARD if absf(verso_fulmine.y) > 0.99 else Vector3.UP)
	if cielo:
		cielo.set_shader_parameter("lampo_dir", verso_fulmine)


func _imposta_parametri(i: float, f: float) -> void:
	if cielo:
		cielo.set_shader_parameter("lampo", i)
		cielo.set_shader_parameter("fulmine", f)
		cielo.set_shader_parameter("fulmine_seme", _seme)
	for m in materiali:
		m.set_shader_parameter("lampo", i)
