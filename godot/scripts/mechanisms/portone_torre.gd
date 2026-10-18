class_name PortoneTorre
extends Node3D
## Il portone scorrevole della sala della torre, sulla parete est (scelta dell'utente del 16 ottobre:
## versione 2, con la torre dipinta e le bande a strisce, senza cartello). Resta chiuso fino a dopo
## la tappa 8. Poi si apre scorrendo di [member corsa] metri, in due modi ([member apertura]):
## - DOPO_TAPPA8 (di serie, scelto dall'utente il 16 ottobre): da solo, appena lei è andata via
##   (LeiSbuca.andata_via);
## - ALL_ARRIVO: quando arrivi davanti ([method apri], lo chiama la sala con FineDemo);
## - SOLO_ENIGMA (GDD, 18 ottobre: prende il posto di DOPO_TAPPA8): lo apre solo l'enigma degli
##   acquari (EnigmaAcquari chiama [method apri]); né la tappa 8 né l'arrivo lo aprono.
## Il movimento segue il suono del motore (portone_torre_apre, 8,5 s, lo suona l'addon audio su
## [signal apertura_iniziata]): la serratura a 0, l'anta parte a [member partenza] secondi,
## accelera per [member accelera] secondi, frena nell'ultimo [member frena] e sbatte a fine corsa
## ([signal aperto]), con un piccolo rimbalzo. Dall'inizio dell'apertura lampeggia il faro rosso.

signal apertura_iniziata
signal aperto

enum Apertura { ALL_ARRIVO, DOPO_TAPPA8, SOLO_ENIGMA }

## Quando si apre: di serie da solo dopo la tappa 8 (scelta dell'utente del 16 ottobre).
@export var apertura := Apertura.DOPO_TAPPA8
## L'anta che scorre (sala_portone_torre del GLB della sala; la collisione è sua figlia).
@export var anta: Node3D
## Dove scorre (direzione globale) e di quanto (m).
@export var direzione := Vector3(0.0, 0.0, 1.0)
@export var corsa := 2.0
## Tempi del movimento (s), sincronizzati col suono: parte, accelera, frena e sbatte a
## partenza + durata.
@export var partenza := 0.7
@export var durata := 5.7
@export var accelera := 1.1
@export var frena := 0.9
## La velocità con cui sbatte a fine corsa, rispetto a quella di crociera.
@export_range(0.0, 1.0) var urto := 0.25
## La tappa 8 (LeiSbuca): prima che lei sia andata via il portone non si apre.
@export var tappa8: Node

@export_group("Lampeggiante")
## Il vetro del lampeggiante rosso (sala_lampeggiante_torre del GLB): la sua emissione lampeggia.
@export var vetro: MeshInstance3D
## La luce, in coordinate globali.
@export var posizione_luce := Vector3(19.55, 5.8, -15.0)
@export var colore_luce := Color(1.0, 0.1, 0.06)
@export var energia_luce := 4.0
@export var raggio_luce := 9.0
@export var periodo_lampeggio := 1.0

## 0 chiuso, 1 aperto del tutto.
var quanto := 0.0
var in_movimento := false
var _t := -1.0
var _chiuso_xf := Transform3D.IDENTITY
var _luce: OmniLight3D
var _mat_vetro: BaseMaterial3D
var _emissione_vetro := 0.0
var _lampeggia := false
var _tl := 0.0


func _ready() -> void:
	add_to_group(&"persist")
	if anta:
		_chiuso_xf = anta.global_transform
	_luce = OmniLight3D.new()
	_luce.name = "LuceLampeggiante"
	_luce.light_color = colore_luce
	_luce.light_energy = 0.0
	_luce.omni_range = raggio_luce
	_luce.omni_attenuation = 1.3
	_luce.shadow_enabled = true
	_luce.light_volumetric_fog_energy = 0.6
	_luce.visible = false
	# È il faro del portone: il blackout non lo spegne (come le luci della medusa).
	_luce.set_meta(&"risveglio_ignora", true)
	add_child(_luce)
	_luce.global_position = posizione_luce
	if vetro and vetro.mesh:
		for i in vetro.mesh.get_surface_count():
			var m := vetro.get_active_material(i) as BaseMaterial3D
			if m and m.emission_enabled:
				_mat_vetro = m.duplicate() as BaseMaterial3D
				_emissione_vetro = _mat_vetro.emission_energy_multiplier
				vetro.set_surface_override_material(i, _mat_vetro)
				break
	_accendi_vetro(0.0)
	if tappa8 and tappa8.has_signal(&"andata_via"):
		tappa8.connect(&"andata_via", func():
			if apertura == Apertura.DOPO_TAPPA8:
				apri())


## Vero se si può aprire: dopo la tappa 8 (o se non c'è).
## Con SOLO_ENIGMA, solo dopo che l'enigma l'ha aperto.
func si_puo_aprire() -> bool:
	if apertura == Apertura.SOLO_ENIGMA:
		return in_movimento or quanto >= 1.0
	if tappa8 == null or not (&"fase" in tappa8):
		return true
	var s: Script = tappa8.get_script()
	var finita = s.get_script_constant_map().get("Fase", {}).get("FINITA") if s else null
	return finita == null or tappa8.get(&"fase") == finita


## Comincia ad aprirsi (se non è già aperto o in movimento).
func apri() -> void:
	if in_movimento or quanto >= 1.0:
		return
	in_movimento = true
	_lampeggia = true
	_t = 0.0
	apertura_iniziata.emit()


func is_aperto() -> bool:
	return quanto >= 1.0


func _physics_process(delta: float) -> void:
	if _lampeggia:
		_tl += delta
		var tf := fmod(_tl, periodo_lampeggio)
		# un lampo come di un faro che gira: sale e scende in fretta
		var k := smoothstep(0.0, 0.08, tf) * (1.0 - smoothstep(0.2, 0.55, tf))
		_luce.visible = true
		_luce.light_energy = energia_luce * (0.05 + 0.95 * k)
		_accendi_vetro(0.15 + 0.85 * k)
	if not in_movimento:
		return
	_t += delta
	var fine := partenza + durata
	if _t >= fine:
		# Sbatte a fine corsa e rimbalza appena.
		var r := _t - fine
		quanto = 1.0
		_metti(1.0 - 0.006 * sin(clampf(r / 0.18, 0.0, 1.0) * PI))
		if r >= 0.18:
			in_movimento = false
			_metti(1.0)
			aperto.emit()
		return
	quanto = clampf(_strada(_t - partenza) / corsa, 0.0, 1.0)
	_metti(quanto)


## Metri percorsi dopo [param t] secondi dalla partenza: accelera, va a velocità costante e frena
## fino alla velocità d'urto (profilo trapezoidale).
func _strada(t: float) -> float:
	if t <= 0.0:
		return 0.0
	var tc := maxf(durata - accelera - frena, 0.0)
	var v := corsa / (accelera * 0.5 + tc + frena * (1.0 + urto) * 0.5)
	if t < accelera:
		return 0.5 * v / accelera * t * t
	var s := 0.5 * v * accelera
	if t < accelera + tc:
		return s + v * (t - accelera)
	s += v * tc
	var tf := minf(t - accelera - tc, frena)
	var dec := v * (1.0 - urto) / frena
	return minf(s + v * tf - 0.5 * dec * tf * tf, corsa)


func _metti(k: float) -> void:
	if anta:
		anta.global_transform = Transform3D(_chiuso_xf.basis, _chiuso_xf.origin + direzione.normalized() * corsa * k)


func _accendi_vetro(k: float) -> void:
	if _mat_vetro:
		_mat_vetro.emission_energy_multiplier = _emissione_vetro * k


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"aperto": quanto >= 1.0 or in_movimento}


func load_state(data: Dictionary) -> void:
	in_movimento = false
	_t = -1.0
	if bool(data.get("aperto", false)):
		quanto = 1.0
		_lampeggia = true
	else:
		quanto = 0.0
		_lampeggia = false
		if _luce:
			_luce.visible = false
		_accendi_vetro(0.0)
	_metti(quanto)
