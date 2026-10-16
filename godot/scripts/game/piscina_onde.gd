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
## Un lampo del lampeggiante giallo (uno ogni [member periodo_lampeggio] secondi finché non colpisci
## il pulsante): per il richiamo dell'audio.
signal lampeggio
## Il pulsante è stato colpito: la luce diventa verde e il richiamo si ferma.
signal pulsante_premuto
## Si comincia ([code]true[/code]) o si smette di togliere acqua dalla piscina (per il gorgo).
signal svuotamento(attivo: bool)

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
## A piscina vuota il lampeggiante sopra il pulsante dà un lampo giallo ogni [member periodo_lampeggio]
## secondi finché non lo colpisci, poi resta verde (valori della proposta A approvata).
@export var colore_attesa := Color(1.0, 0.68, 0.08)
@export var colore_premuto := Color(0.15, 1.0, 0.3)
@export var energia_segnale := 4.0
@export var raggio_segnale := 7.0
@export var periodo_lampeggio := 1.6
## A piscina vuota il pulsante si attiva dopo questi secondi: il sorso finale del suono della
## piscina vuota (a 2,2 s) non si sovrappone allo scatto e al jingle del pulsante.
@export var ritardo_pulsante := 2.5
## Dove sta la luce rispetto al pulsante (coordinate del pulsante: +Z è davanti), se non c'è il
## vetro del lampeggiante.
@export var posizione_segnale := Vector3(0.0, 0.12, 0.3)
## Il vetro del lampeggiante sopra il pulsante (sala_lampeggiante_portello del GLB della sala):
## la luce sta al suo centro, la sua emissione lampeggia con lei e diventa verde col colpo.
@export var vetro_lampeggiante: MeshInstance3D

## Vero quando la piscina è stata svuotata e il pulsante funziona (resta vero).
var attivo := false
var _luce: OmniLight3D
var _t := 0.0
var _t_lampo := -1.0
var _premuto_detto := false
var _fill_prima := -1.0
var _svuota_t := 0.0
var _svuotando := false
var _vuota_t := 0.0
var _stile_di_serie: Resource
var _lampada: SpotLight3D
var _medusine: Medusine
var _mat_vetro: BaseMaterial3D
var _emissione_vetro := 1.0


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
		_luce.omni_attenuation = 1.3
		_luce.shadow_enabled = true
		_luce.light_volumetric_fog_energy = 0.5
		_luce.visible = false
		add_child(_luce)
		_luce.global_position = pulsante.global_transform * posizione_segnale
	if vetro_lampeggiante and vetro_lampeggiante.mesh:
		vetro_lampeggiante.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in vetro_lampeggiante.mesh.get_surface_count():
			var m := vetro_lampeggiante.get_active_material(i) as BaseMaterial3D
			if m and m.emission_enabled:
				_mat_vetro = m.duplicate() as BaseMaterial3D
				_emissione_vetro = maxf(_mat_vetro.emission_energy_multiplier, 1.0)
				vetro_lampeggiante.set_surface_override_material(i, _mat_vetro)
				break
		if _luce:
			_luce.global_position = vetro_lampeggiante.global_transform * vetro_lampeggiante.get_aabb().get_center()
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
	_segui_svuotamento(delta)
	if not attivo and vasca:
		_vuota_t = _vuota_t + delta if vasca.fill <= 0.001 else 0.0
		if _vuota_t >= ritardo_pulsante:
			attivo = true
			_t_lampo = -1.0
			_aggiorna_pulsante()
			pulsante_attivato.emit()
	if premuto() and not _premuto_detto:
		_premuto_detto = true
		pulsante_premuto.emit()
	if _luce and _luce.visible:
		if premuto():
			_luce.light_color = colore_premuto
			_luce.light_energy = energia_segnale
			_vetro(colore_premuto, 1.0)
		else:
			# Il lampeggiante giallo: un lampo corto ogni periodo_lampeggio secondi.
			var k := _lampo(delta)
			_luce.light_color = colore_attesa
			_luce.light_energy = energia_segnale * (0.04 + 0.96 * k)
			_vetro(colore_attesa, 0.08 + 0.92 * k)


func _vetro(colore: Color, k: float) -> void:
	if _mat_vetro:
		_mat_vetro.emission = colore
		_mat_vetro.emission_energy_multiplier = _emissione_vetro * k


## Quanto è acceso il lampeggiante in attesa (0..1): sale in fretta, si spegne in mezzo secondo.
func _lampo(delta: float) -> float:
	if _t_lampo < 0.0:
		_t_lampo = 0.0
		lampeggio.emit()
	else:
		var prima := _t_lampo
		_t_lampo += delta
		if fmod(_t_lampo, periodo_lampeggio) < fmod(prima, periodo_lampeggio):
			lampeggio.emit()
	var tf := fmod(_t_lampo, periodo_lampeggio)
	return smoothstep(0.0, 0.05, tf) * (1.0 - smoothstep(0.1, 0.55, tf))


## Quando il livello scende si sta svuotando la piscina (con lo zaino): svuotamento(true), e
## svuotamento(false) quando smette da un quinto di secondo.
func _segui_svuotamento(delta: float) -> void:
	if vasca == null:
		return
	var f := vasca.fill
	if _fill_prima >= 0.0 and f < _fill_prima - 0.000001:
		_svuota_t = 0.2
	else:
		_svuota_t = maxf(0.0, _svuota_t - delta)
	_fill_prima = f
	var ora := _svuota_t > 0.0
	if ora != _svuotando:
		_svuotando = ora
		svuotamento.emit(ora)


## Vero quando il pulsante è stato colpito (la botola si apre).
func premuto() -> bool:
	return attivo and pulsante != null and pulsante.powered


func _aggiorna_pulsante() -> void:
	if pulsante:
		pulsante.enabled = attivo
	if _luce:
		_luce.visible = attivo
	# Prima che la piscina sia vuota il lampeggiante è spento.
	if not attivo:
		_vetro(colore_attesa, 0.0)


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
	_premuto_detto = premuto()
	_t_lampo = -1.0
	_fill_prima = -1.0
	_vuota_t = 0.0
	_aggiorna_pulsante()
