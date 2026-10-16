class_name PiscinaOnde
extends Node3D
## Tappa 5 di docs/livello/capitolo1.md, l'enigma deciso dall'utente il 15 ottobre: la piscina a
## onde si svuota con lo zaino. Si aspira l'acqua della parte profonda (tasto destro) e la si spara
## fuori dalla vasca (tasto sinistro): il livello scende davvero. L'acqua sparata dentro la vasca
## (sul fondo, sulle pareti o sulla spiaggia) ci ricola dentro: conta solo quella che esce.
## A piscina vuota il pulsante della botola si attiva e il suo lampeggiante giallo lampeggia;
## colpito col getto la luce diventa verde e la botola si apre: sotto c'è il pozzo della camera delle
## onde (pulsante A, scelto dall'utente il 16 ottobre; il modello lo mette la sala).
## Scelte del 16 ottobre: si svuota in circa 30 secondi, con 4 zainate ([member taratura]; restano
## anche le tarature da circa 1 e 2 minuti proposte prima); l'acqua resta com'è (aspetto A, le
## varianti B e C restano in [member aspetto] ma non si usano) e ci nuotano le micro medusine
## luminose, che si aspirano con l'acqua e si sparano via (Medusine, [member medusine]).

## Il pulsante si è attivato (la piscina è vuota).
signal pulsante_attivato

enum Taratura { TRENTA_SECONDI, UN_MINUTO, DUE_MINUTI }
## OGGI: com'è adesso (dalla spiaggia piena e a metà quasi non si distinguono). LEGGIBILE (B):
## superficie più riflettente, un po' più chiara e meno torbida, con la schiuma sul pelo lungo la
## riva e le pareti, senza luci in più. LEGGIBILE_CON_LAMPADA (C): come B, più una lampada di
## servizio che illumina la parte profonda dall'alto.
enum Aspetto { OGGI, LEGGIBILE, LEGGIBILE_CON_LAMPADA }

## L'acqua della piscina (WaterTank, col fondo nella conca dello scarico).
@export var vasca: WaterTank
## Il pulsante della botola: finché la piscina non è vuota il getto non lo preme.
@export var pulsante: WaterButton
## Quanta acqua c'è da togliere: di serie circa 30 secondi di lavoro (4 zainate).
@export var taratura := Taratura.TRENTA_SECONDI:
	set(v):
		taratura = v
		_applica_taratura()
## Pieni di zaino che servono per ciascuna taratura (un pieno = [member litri_pieno]).
@export var pieni_trenta_secondi := 4
@export var pieni_un_minuto := 9
@export var pieni_due_minuti := 18
## Litri di un pieno di zaino (WaterPack.tank_capacity).
@export var litri_pieno := 20.0
## L'aspetto dell'acqua. Di serie OGGI, scelto dall'utente il 16 ottobre (le altre erano proposte).
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

@export_group("Micro medusine")
## Quante micro medusine luminose nuotano nella piscina piena (0 = nessuna).
@export var medusine := 15

@export_group("Lampeggiante del pulsante")
## A piscina vuota la luce accanto al pulsante lampeggia gialla finché non lo colpisci, poi resta verde.
@export var colore_attesa := Color(1.0, 0.68, 0.12)
@export var colore_premuto := Color(0.35, 1.0, 0.45)
@export var energia_segnale := 2.4
@export var raggio_segnale := 3.2
@export var lampeggi_al_secondo := 1.4
## Dove sta la luce rispetto al pulsante (coordinate del pulsante: +Z è davanti).
@export var posizione_segnale := Vector3(0.0, 0.12, 0.3)

## Vero quando la piscina è stata svuotata e il pulsante funziona (resta vero).
var attivo := false
var _luce: OmniLight3D
var _t := 0.0
var _stile_di_serie: Resource
var _lampada: SpotLight3D
var _medusine: Medusine


func _ready() -> void:
	add_to_group(&"persist")
	add_to_group(&"water_catchers")
	_applica_taratura()
	if pulsante:
		_luce = OmniLight3D.new()
		_luce.name = "SegnalePulsante"
		_luce.light_color = colore_attesa
		_luce.light_energy = energia_segnale
		_luce.omni_range = raggio_segnale
		_luce.omni_attenuation = 1.2
		_luce.shadow_enabled = false
		_luce.light_volumetric_fog_energy = 0.5
		_luce.visible = false
		add_child(_luce)
		_luce.global_position = pulsante.global_transform * posizione_segnale
	_aggiorna_pulsante()
	if medusine > 0 and vasca:
		_medusine = Medusine.new()
		_medusine.name = "Medusine"
		_medusine.vasca = vasca
		_medusine.numero = medusine
		add_child(_medusine)
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


## Pieni di zaino da togliere con la taratura scelta.
func pieni_da_togliere() -> int:
	match taratura:
		Taratura.UN_MINUTO:
			return pieni_un_minuto
		Taratura.DUE_MINUTI:
			return pieni_due_minuti
	return pieni_trenta_secondi


## Litri d'acqua da togliere con la taratura scelta.
func litri_da_togliere() -> float:
	return float(pieni_da_togliere()) * litri_pieno


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
		if premuto():
			_luce.light_color = colore_premuto
			_luce.light_energy = energia_segnale
		else:
			# Il lampeggiante giallo: lampi corti e regolari.
			_luce.light_color = colore_attesa
			var k := pow(maxf(sin(_t * TAU * lampeggi_al_secondo), 0.0), 2.0)
			_luce.light_energy = energia_segnale * (0.08 + 0.92 * k)


## Vero quando il pulsante è stato colpito (la botola si apre).
func premuto() -> bool:
	return attivo and pulsante != null and pulsante.powered


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
