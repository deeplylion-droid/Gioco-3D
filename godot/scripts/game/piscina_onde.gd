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
## L'aspetto dell'acqua ha due varianti da proporre all'utente ([member aspetto]); finché non sceglie
## resta com'è.

## Il pulsante si è attivato (la piscina è vuota).
signal pulsante_attivato

enum Taratura { UN_MINUTO, DUE_MINUTI }
## OGGI: com'è adesso (dalla spiaggia piena e a metà quasi non si distinguono). LEGGIBILE (B):
## superficie più riflettente, un po' più chiara e meno torbida, con la schiuma sul pelo lungo la
## riva e le pareti, senza luci in più. LEGGIBILE_CON_LAMPADA (C): come B, più una lampada di
## servizio che illumina la parte profonda dall'alto.
enum Aspetto { OGGI, LEGGIBILE, LEGGIBILE_CON_LAMPADA }

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
## L'aspetto dell'acqua (proposte per l'utente, 16 ottobre). Di serie OGGI.
@export var aspetto := Aspetto.OGGI:
	set(v):
		aspetto = v
		if is_inside_tree():
			_applica_aspetto()

@export_group("Lampada di servizio (aspetto C)")
## Appesa in alto sopra la parte profonda (sopra lo scivolo a spirale che passa a 4-4,6 m), punta
## dritta in giù: sull'acqua arriva un po' più luce di quella dei fari sulla medusa.
@export var lampada_posizione := Vector3(0.0, 8.0, 1.2)
@export var lampada_colore := Color(0.92, 0.96, 1.0)
@export var lampada_energia := 16.0
@export var lampada_angolo := 36.0
@export var lampada_portata := 16.0

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
var _stile_di_serie: Resource
var _lampada: SpotLight3D


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
	GameState.luci_cambiate.connect(func(_f): _aggiorna_lampada())
	if aspetto != Aspetto.OGGI:
		_applica_aspetto()


## La superficie dell'acqua della piscina (il WaterTankLink dell'addon che segue [member vasca]).
func superficie() -> Node:
	if vasca == null or get_parent() == null:
		return null
	for n in get_parent().get_children():
		if n != vasca and &"tank" in n and n.get(&"tank") == vasca:
			return n
	return null


func _applica_aspetto() -> void:
	var acqua := superficie()
	if acqua:
		if _stile_di_serie == null:
			_stile_di_serie = acqua.get(&"style")
		acqua.set(&"style", _stile_di_serie if aspetto == Aspetto.OGGI else stile_leggibile(_stile_di_serie as WaterStyle))
	if aspetto == Aspetto.LEGGIBILE_CON_LAMPADA and _lampada == null:
		_lampada = SpotLight3D.new()
		_lampada.name = "LampadaServizio"
		_lampada.light_color = lampada_colore
		_lampada.light_energy = lampada_energia
		_lampada.spot_angle = lampada_angolo
		_lampada.spot_angle_attenuation = 1.4
		_lampada.spot_range = lampada_portata
		_lampada.spot_attenuation = 0.6
		_lampada.shadow_enabled = true
		_lampada.light_size = 0.2
		_lampada.light_volumetric_fog_energy = 0.6
		add_child(_lampada)
		_lampada.global_position = lampada_posizione
		_lampada.global_basis = Basis(Vector3.RIGHT, -PI * 0.5)
	_aggiorna_lampada()


func _aggiorna_lampada() -> void:
	if _lampada:
		# Va con la corrente: al blackout si spegne come le altre luci della sala.
		_lampada.visible = aspetto == Aspetto.LEGGIBILE_CON_LAMPADA and GameState.luci != GameState.Luci.BLACKOUT


## L'acqua dell'aspetto B: la stessa torbida di serie, ma più riflettente, un po' più chiara e meno
## fitta (vicino alla riva si intravede il fondo), con le caustiche sul fondo e una riga di schiuma
## dove il pelo tocca la spiaggia e le pareti.
static func stile_leggibile(base: WaterStyle) -> WaterStyle:
	var st := (base.duplicate() if base else WaterStyle.new()) as WaterStyle
	st.reflection_strength = 3.6
	st.roughness = 0.028
	st.turbidity = 1.6
	st.scatter_color = Color(0.36, 0.44, 0.36)
	st.scatter_ambient = 0.18
	st.scum_amount = 0.2
	st.foam_color = Color(0.82, 0.84, 0.76)
	st.foam_shore_amount = 1.4
	st.foam_shore_width = 0.35
	st.caustics_strength = 1.0
	return st


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
