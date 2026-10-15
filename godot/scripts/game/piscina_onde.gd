class_name PiscinaOnde
extends Node3D
## Tappa 5 di docs/livello/capitolo1.md, l'enigma deciso dall'utente il 15 ottobre: la piscina a
## onde si svuota con lo zaino. Si aspira l'acqua della parte profonda (tasto destro) e la si spara
## fuori dalla vasca (tasto sinistro): il livello scende davvero. L'acqua sparata dentro la vasca
## (sul fondo, sulle pareti o sulla spiaggia) ci ricola dentro: conta solo quella che esce.
## A piscina vuota il pulsante della botola si attiva: per ora lo segnala una luce provvisoria
## (l'aspetto del pulsante lo sceglie l'utente fra due versioni). Colpito col getto apre la botola,
## sotto c'è il pozzo della camera delle onde.
## L'acqua da togliere ha due tarature, da circa 1 e circa 2 minuti di lavoro ([member taratura]).

## Il pulsante si è attivato (la piscina è vuota).
signal pulsante_attivato

enum Taratura { UN_MINUTO, DUE_MINUTI }

## L'acqua della piscina (WaterTank, col fondo nella conca dello scarico).
@export var vasca: WaterTank
## Il pulsante della botola: finché la piscina non è vuota il getto non lo preme.
@export var pulsante: WaterButton
## Quanta acqua c'è da togliere: circa 1 minuto o circa 2 minuti di lavoro.
@export var taratura := Taratura.UN_MINUTO:
	set(v):
		taratura = v
		_applica_taratura()
## Pieni di zaino che servono per ciascuna taratura (un pieno = [member litri_pieno]).
@export var pieni_un_minuto := 9
@export var pieni_due_minuti := 18
## Litri di un pieno di zaino (WaterPack.tank_capacity).
@export var litri_pieno := 20.0

@export_group("Ritorno dell'acqua")
## L'acqua sparata dentro la vasca della piscina ci ritorna (conta solo quella sparata fuori).
@export var riflusso := true
## La vasca della piscina in pianta: x e z minimi, larghezza (x) e lunghezza (z).
@export var conca := Rect2(-7.0, -13.2, 14.0, 18.2)
## Sotto questa quota (il bordo della vasca) l'acqua che cade nella conca ci ricola dentro.
@export var quota_bordo := -0.05

@export_group("Segnale provvisorio")
## La luce che si accende accanto al pulsante quando si attiva.
@export var colore_segnale := Color(0.35, 1.0, 0.45)
@export var energia_segnale := 2.4
@export var raggio_segnale := 3.2
## Dove sta la luce rispetto al pulsante (coordinate del pulsante: +Z è davanti).
@export var posizione_segnale := Vector3(0.0, 0.12, 0.3)

## Vero quando la piscina è stata svuotata e il pulsante funziona (resta vero).
var attivo := false
var _luce: OmniLight3D
var _t := 0.0


func _ready() -> void:
	add_to_group(&"persist")
	add_to_group(&"water_catchers")
	_applica_taratura()
	if pulsante:
		_luce = OmniLight3D.new()
		_luce.name = "SegnalePulsante"
		_luce.light_color = colore_segnale
		_luce.light_energy = energia_segnale
		_luce.omni_range = raggio_segnale
		_luce.omni_attenuation = 1.2
		_luce.shadow_enabled = false
		_luce.light_volumetric_fog_energy = 0.5
		_luce.visible = false
		add_child(_luce)
		_luce.global_position = pulsante.global_transform * posizione_segnale
	_aggiorna_pulsante()


## Litri d'acqua da togliere con la taratura scelta.
func litri_da_togliere() -> float:
	return float(pieni_un_minuto if taratura == Taratura.UN_MINUTO else pieni_due_minuti) * litri_pieno


func _applica_taratura() -> void:
	if vasca == null or not is_inside_tree():
		return
	# La quota non cambia: cambia quanti litri vale (e quindi quanti pieni di zaino servono).
	vasca.capacity_liters = litri_da_togliere()


func _physics_process(delta: float) -> void:
	_t += delta
	if not attivo and vasca and vasca.fill <= 0.001:
		attivo = true
		_aggiorna_pulsante()
		pulsante_attivato.emit()
	if _luce and _luce.visible:
		# Pulsa piano, per farsi notare dal fondo della piscina.
		_luce.light_energy = energia_segnale * (0.75 + 0.25 * sin(_t * 3.0))


func _aggiorna_pulsante() -> void:
	if pulsante:
		pulsante.enabled = attivo
	if _luce:
		_luce.visible = attivo


# --- L'acqua che ricade nella vasca (gruppo "water_catchers", come le vasche) -----------------

## Il getto non si ferma qui (si ferma sul fondo o sull'acqua): -1 sempre.
func surface_hit_fraction(_a: Vector3, _b: Vector3) -> float:
	return -1.0


## L'acqua che arriva dentro la conca, sotto il bordo, e non già dentro l'acqua della piscina.
func catches_point(p: Vector3) -> bool:
	if not riflusso or attivo or vasca == null:
		return false
	if p.y >= quota_bordo or not conca.has_point(Vector2(p.x, p.z)):
		return false
	return not vasca.catches_point(p)


## Ricola giù fino all'acqua della piscina.
func receive_water(liters: float, point: Vector3, direction: Vector3) -> void:
	if vasca:
		vasca.receive_water(liters, point, direction)


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"attivo": attivo}


func load_state(data: Dictionary) -> void:
	attivo = bool(data.get("attivo", false))
	_aggiorna_pulsante()
