class_name Torcia
extends Node3D
## Torcia del giocatore. Va messa come figlia della Camera3D.
## La luce segue lo sguardo con un leggero ritardo, ha un fascio con texture
## (cookie), ombre morbide e si accende/spegne con l'azione "torcia" (tasto F).
## Lo sfarfallio si attiva da fuori, per esempio quando il mostro è vicino:
##   torcia.sfarfalla(1.5)                 # un attacco di sfarfallio
##   torcia.disturbo = 0.8                 # sfarfallio continuo finché resta > 0
## La batteria esiste ma è spenta di default (scelta di design ancora aperta).

signal accesa_cambiata(accesa: bool)          # per il suono del clic
signal batteria_cambiata(carica: float)       # 0..1
signal batteria_esaurita

@export var accesa := true
@export_group("Luce")
@export var energia := 9.0
@export var colore := Color(1.0, 0.86, 0.68)  # bianco caldo (circa 4000 K)
@export var angolo := 26.0
@export var portata := 26.0
@export var attenuazione := 0.75   # calo più lento: illumina anche lontano senza bruciare vicino
@export var dimensione_sorgente := 0.02        # ombre morbide (PCSS)
@export var energia_nebbia := 0.12             # fascio appena accennato nella nebbia
@export var cookie: Texture2D = preload("res://addons/grafica/texture/torcia_cookie.png")
## Posizione della luce rispetto alla camera (a destra e in basso, come in mano):
## lo scarto fa vedere le ombre degli oggetti vicini.
@export var offset_mano := Vector3(0.2, -0.2, -0.15)
## Strati che la torcia NON illumina: di serie il 2, quello del modello in mano
## (lancia, impugnatura), che altrimenti si accende in primo piano.
@export_flags_3d_render var strati_esclusi := 2
## Vicino ai muri la luce si abbassa (come l'occhio che si adatta): senza, entro
## 3 m bruciava tutto. Fattore = clamp(distanza / distanza_piena, minimo, 1).
@export var attenua_vicino := true
@export var distanza_piena := 2.5
@export var minimo_vicino := 0.4
@export var portata_controllo := 3.0
@export_group("Movimento")
## Più è alto, più la luce segue lo sguardo in fretta.
@export var rapidita := 7.0
@export var oscillazione := 0.004             # piccolo movimento della mano
@export_group("Batteria")
@export var batteria_attiva := false
@export var durata_batteria := 420.0          # secondi di luce piena
@export var soglia_scarica := 0.2             # sotto questa carica si indebolisce e sfarfalla

## 0..1: sfarfallio continuo (es. in base alla distanza del mostro).
var disturbo := 0.0
var carica := 1.0

var luce: SpotLight3D
var _rot := Quaternion.IDENTITY
var _t := 0.0
var _sfarfallio_tempo := 0.0
var _sfarfallio_forza := 0.0
var _rumore := FastNoiseLite.new()
var _livello := 1.0
var _vicino := 1.0
var _esclusi: Array[RID] = []   # il corpo del giocatore, da non colpire col raggio


func _ready() -> void:
	luce = SpotLight3D.new()
	luce.name = "Luce"
	luce.top_level = true
	luce.light_color = colore
	luce.spot_angle = angolo
	luce.spot_range = portata
	luce.spot_attenuation = attenuazione
	luce.spot_angle_attenuation = 0.4    # il bordo morbido lo fa la texture
	luce.light_projector = cookie
	luce.light_size = dimensione_sorgente
	luce.light_volumetric_fog_energy = energia_nebbia
	luce.light_specular = 0.35
	luce.light_cull_mask &= ~strati_esclusi
	luce.shadow_enabled = true
	luce.shadow_bias = 0.04
	luce.shadow_normal_bias = 1.2
	luce.shadow_blur = 1.5
	luce.set_meta("grafica_priorita_ombra", 0)  # l'ombra della torcia resta anche al minimo
	add_child(luce)
	var p := get_parent()
	while p:
		if p is CollisionObject3D:
			_esclusi.append((p as CollisionObject3D).get_rid())
		p = p.get_parent()
	_rumore.frequency = 0.9
	_rumore.seed = 31
	_rot = global_basis.get_rotation_quaternion()
	_aggiorna_luce(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("torcia") and not event.is_echo():
		commuta()
		get_viewport().set_input_as_handled()


func commuta() -> void:
	imposta_accesa(not accesa)


func imposta_accesa(v: bool) -> void:
	if v and batteria_attiva and carica <= 0.0:
		v = false
	if v == accesa:
		return
	accesa = v
	accesa_cambiata.emit(accesa)


## Un attacco di sfarfallio di "durata" secondi.
func sfarfalla(durata := 1.2, forza := 1.0) -> void:
	_sfarfallio_tempo = maxf(_sfarfallio_tempo, durata)
	_sfarfallio_forza = maxf(_sfarfallio_forza, forza)


func ricarica(quanto := 1.0) -> void:
	carica = clampf(carica + quanto, 0.0, 1.0)
	batteria_cambiata.emit(carica)


func _process(delta: float) -> void:
	_t += delta
	# Segue lo sguardo con ritardo (interpolazione esponenziale, indipendente dagli FPS).
	var target := global_basis.get_rotation_quaternion()
	_rot = _rot.slerp(target, 1.0 - exp(-rapidita * delta))
	var mano := Vector3(_rumore.get_noise_1d(_t * 0.7), _rumore.get_noise_1d(_t * 0.7 + 50.0), 0.0) * oscillazione
	luce.global_position = global_transform * (offset_mano + mano)
	luce.global_basis = Basis(_rot)

	if attenua_vicino:
		var obiettivo := 1.0
		var spazio := get_world_3d().direct_space_state
		if spazio:
			var da := luce.global_position
			var q := PhysicsRayQueryParameters3D.create(da, da - luce.global_basis.z * portata_controllo)
			q.exclude = _esclusi
			var r := spazio.intersect_ray(q)
			if r:
				obiettivo = clampf(da.distance_to(r.position) / distanza_piena, minimo_vicino, 1.0)
		_vicino = lerpf(_vicino, obiettivo, 1.0 - exp(-8.0 * delta))

	if batteria_attiva and accesa:
		var prima := carica
		carica = maxf(carica - delta / durata_batteria, 0.0)
		if int(prima * 100) != int(carica * 100):
			batteria_cambiata.emit(carica)
		if carica <= 0.0:
			batteria_esaurita.emit()
			imposta_accesa(false)
	_aggiorna_luce(delta)


func _aggiorna_luce(delta: float) -> void:
	var obiettivo := 1.0 if accesa else 0.0
	# Accensione quasi istantanea (LED), con un minimo di rampa per evitare scatti.
	_livello = move_toward(_livello, obiettivo, delta * 25.0) if delta > 0.0 else obiettivo
	var f := _livello
	var forza := clampf(disturbo, 0.0, 1.0)
	if _sfarfallio_tempo > 0.0:
		_sfarfallio_tempo -= delta
		forza = maxf(forza, _sfarfallio_forza)
		if _sfarfallio_tempo <= 0.0:
			_sfarfallio_forza = 0.0
	if batteria_attiva and carica < soglia_scarica:
		var s := carica / soglia_scarica
		f *= lerpf(0.35, 1.0, s)
		forza = maxf(forza, (1.0 - s) * 0.5)
	if forza > 0.0 and f > 0.0:
		# Cali rapidi e irregolari, a volte fino al buio completo.
		var n := _rumore.get_noise_1d(_t * 40.0) * 0.5 + 0.5
		var buco := 1.0 if _rumore.get_noise_1d(_t * 13.0 + 200.0) > 0.45 - 0.25 * forza else 0.0
		f *= clampf(1.0 - forza * (n * 0.9 + buco), 0.0, 1.0)
	luce.light_energy = energia * f * _vicino
	luce.visible = f > 0.001
