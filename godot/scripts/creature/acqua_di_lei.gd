class_name AcquaDiLei
extends Node3D
## «L'acqua è sua» (build 0.4.0, GDD: «Analisi del capitolo 1 e direzione nuova», 15 novembre): lei in uno specchio
## d'acqua vero (vasca, pozza profonda, canale). Si attacca come figlio della zona, con uno o più punti d'uscita.
## Le fasi:
## - LONTANA: niente. Da qui la chiama la zona ([method chiama]) o, con [member automatica], lei stessa ogni tanto;
## - ARRIVA: la luce rosa sott'acqua arriva sotto il punto d'uscita (l'avviso meno spegnimento e silenzio);
## - SPEGNE: la luce è lì e il canto si spegne da solo, l'ultima nota che cala ([member spegnimento], 1 s: il canto non
##   si tronca mai di netto, scelta dell'utente del 15 novembre);
## - SILENZIO: silenzio vero ([member silenzio], 0,5 s), poi esce (lo legge l'audio: [member fase_canto]);
## - ESCE: lei sale dall'acqua («intera»: sale_dall_acqua delle condotte);
## - SU: incombe e ti cerca con la testa; se sei nella [member portata] ti prende ([member letale]), se no dopo
##   [member tempo_su] sbatte nell'acqua e torna sotto;
## - PRESA: GameState.kill_player(&"medusa"), la scena di morte di sempre;
## - SCENDE: torna sotto (respinta: il getto in faccia per [member getto_per_respingere] s mentre esce o incombe);
## - CALMA: dopo una respinta lo specchio resta calmo per [member pausa_respinta] s; poi di nuovo LONTANA.
## Lei e la luce rosa sono una sola per tutto il gioco (condivise da tutte le istanze): mai in due posti, mai mentre
## un'altra lei è in vista (oblò, fossa, condotte, tunnel), mai mentre un bambino è in vista, mai prima che le pompe
## siano riaccese (GameState.luci BLACKOUT). Vetri e grate la fermano: i punti d'uscita stanno solo in acqua vera
## (li mette la zona). Per il canto ogni istanza è nel gruppo [constant GRUPPO] e dà [member vicinanza],
## [member punto_luce] e [member fase]. Come si usa: docs/tecnico/acqua_di_lei/LEGGIMI.md.

## La fase è cambiata.
signal fase_cambiata(fase: Fase)
## La luce rosa è partita verso il punto d'uscita (l'avviso).
signal arriva(punto: Vector3)
## Lei è uscita dall'acqua.
signal uscita
## Ti ha preso (subito prima della scena di morte).
signal presa
## Il getto in faccia l'ha ricacciata sotto.
signal respinta
## È tornata sotto (respinta o da sola) ed è sparita.
signal tornata_sotto
## Il percorso della luce ([method percorri]) è finito (anche il giro, con [method smetti_giro]): la luce è spenta e lei
## se n'è andata, o (con alla_fine) arriva al punto d'uscita.
signal percorso_finito

enum Fase { LONTANA, ARRIVA, SPEGNE, SILENZIO, ESCE, SU, PRESA, SCENDE, CALMA }
## Come esce: intera (le vasche grandi) o mano e tentacoli (le pozze piccole della Risalita, scelta C dell'utente: esce
## prima il braccio e la mano sbatte sul grigliato, poi dal bordo salgono quattro tentacoli che strisciano lungo la
## passerella; la presa la fa la mano, alla caviglia).
enum Modo { INTERA, MANO }

const GRUPPO := &"lei_nell_acqua"
## La luce rosa sott'acqua: la LuceSottacqua di LeiSbuca (colore, forza, portata).
const ROSA := Color(1.0, 0.45, 0.75)
const LUCE_SOTTO := 2.6
const LUCE_SOTTO_PORTATA := 4.5
## Fuori dall'acqua la luce le sta addosso come nelle condotte (SalaInseguimento.LUCE_LEI).
const LUCE_SU := 6.0
const LUCE_SU_PORTATA := 9.0
const ANIM := "inseguimento/"
## Modo MANO: quando la mano sbatte sul grigliato in pozza_esce (s; POZZA_SLAM_T di medusa_inseguimento.py).
const MANO_SBATTE := 0.62
## Modo MANO: la luce resta nell'acqua della pozza, più forte (la pozza si accende di rosa da sotto).
const LUCE_POZZA := 3.0
const LUCE_POZZA_PORTATA := 1.6

@export var abilitata := true
@export var modo := Modo.INTERA
## I punti d'uscita: l'origine è la posa «su» (incombe) di lei, cioè dove sta il suo nodo quando è fuori; le
## animazioni salgono da 5 m sotto. Lei si gira verso il giocatore. Esce dal punto più vicino al giocatore.
## Nel modo MANO l'origine è dove sbatte la mano, sul grigliato a filo del bordo della pozza, e il +Z del marker va
## verso la passerella (fuori dalla pozza): lei non si gira (misure in docs/tecnico/acqua_di_lei/LEGGIMI.md).
@export var punti_uscita: Array[Node3D] = []
## Quota del pelo dell'acqua (nel mondo). NAN: quella del punto d'uscita.
@export var pelo := NAN
## Quanto spazio c'è sotto i punti d'uscita (m, al più 5): la salita parte da lì, nascosta sott'acqua.
@export var profondita := 5.0
## Da dove arriva la luce rosa (se manca: 8 m dietro il punto d'uscita, dalla parte opposta al giocatore).
@export var partenza_luce: Node3D
## I volumi d'acqua vera (WaterTank) dove passa la luce rosa: fuori da questi (fra una vasca e l'altra, sotto un
## pavimento) la luce è spenta, si spegne arrivando al bordo e si riaccende dentro la vasca dopo. Vuoto: sempre accesa.
@export var acque: Array[Node3D] = []
@export_group("Tempi e distanze")
## L'avviso intero (s): la luce che arriva, il canto che si spegne e il silenzio.
@export var avviso := 3.5
## Dentro l'avviso: il canto che si spegne da solo (s), con la luce già ferma sotto il punto.
@export var spegnimento := 1.0
## L'ultima parte dell'avviso (s): silenzio vero, poi esce.
@export var silenzio := 0.5
## Più vicino di così al punto d'uscita (m, in pianta) quando è fuori: ti prende.
@export var portata := 3.0
## Nel modo MANO: più vicino di così al punto dove sbatte la mano (m, in pianta) ti prende alla caviglia.
@export var portata_mano := 1.2
## Quanto sta su a cercarti, se non sei nella portata (s).
@export var tempo_su := 2.2
## Da su, quanto aspetta prima di prenderti (s): il tempo di uno spruzzo. 1,6 s (collaudo della 0.4.0: col giocatore
## vero servono 0,9 s dall'inizio del getto per respingerla; chi la vede fuori e reagisce in mezzo secondo deve farcela):
## dall'acqua che si apre alla presa 3,2 s.
@export var tempo_presa := 1.6
## Nel modo MANO, la scena di morte: la camera trascinata finisce col viso sopra il liquido, che guarda giù nella pozza
## (vero, la proposta del coordinatore) o dentro la pozza che guarda indietro il braccio che esce (falso). Vedi
## [method camera_morte_mano].
@export var camera_morte_avanti := true
## Nel modo MANO: da su, quanto aspetta la mano prima di prenderti alla caviglia (s).
@export var tempo_presa_mano := 0.35
## Secondi di getto in faccia che la ricacciano sotto.
@export var getto_per_respingere := 0.5
## Dopo una respinta lo specchio resta calmo per tanto (s).
@export var pausa_respinta := 20.0
## Dopo un'uscita senza respinta (s).
@export var pausa_dopo := 4.0
@export_group("Regole")
## Se spento non prende mai: esce, incombe e torna sotto («solo paura»).
@export var letale := true
## La prima uscita è dal punto più lontano dal giocatore e non prende (una volta per partita).
@export var prima_volta_dimostrativa := false
## Il nome stabile della zona per la prima uscita dimostrativa (vuoto: il percorso del nodo).
@export var chiave_zona: StringName = &""
## Lei viene da sola quando il giocatore è entro [member distanza_richiamo] da un punto d'uscita, ogni
## [member intervallo] s (a caso fra i due).
@export var automatica := false
@export var intervallo := Vector2(14.0, 26.0)
@export var distanza_richiamo := 10.0
## La zona di questo specchio: il giocatore è qui se è entro [member zona_raggio] m (in pianta) da un punto d'uscita
## e a non più di [member zona_dislivello] m sopra o sotto il pelo. Fuori dalla zona lei non viene e, se è qui
## (la luce che gira o aspetta), se ne va subito: nessuno specchio la tiene da lontano.
@export var zona_raggio := 25.0
@export var zona_dislivello := 3.0
## Un'altra lei conta «in vista» se è entro tanto dal giocatore (m) e nell'inquadratura, o comunque più vicina di
## [member vista_dietro] (girandosi la vedrebbe).
@export var vista_lontano := 40.0
@export var vista_dietro := 12.0

var fase := Fase.LONTANA
## Quanto è vicina (0 lontana, 1 sotto il punto o fuori): per il canto.
var vicinanza := 0.0
## Dove sta la luce rosa (nel mondo).
var punto_luce := Vector3.ZERO
## La fase per il canto (accordo con ambienti-1): &"ferma" (prima delle pompe, o spenta: niente canto), &"lontana"
## (canto lontano), &"arriva" (sale con [member vicinanza]), &"spegne" (il canto si spegne da solo in
## [member spegnimento] s), &"silenzio" (niente), &"fuori" (esce, incombe, prende: niente canto), &"respinta" (il
## getto la ricaccia sotto: niente), &"va_via" (torna sotto da sola: il canto lontano riprende).
var fase_canto: StringName:
	get:
		match fase:
			Fase.ARRIVA:
				return &"arriva"
			Fase.SPEGNE:
				return &"spegne"
			Fase.SILENZIO:
				return &"silenzio"
			Fase.ESCE, Fase.SU, Fase.PRESA:
				return &"fuori"
			Fase.SCENDE:
				return &"respinta" if _respinta else &"va_via"
		if not abilitata or GameState.luci != GameState.Luci.BLACKOUT:
			return &"ferma"
		# lei è da un'altra parte, o il giocatore è lontano da qui: niente canto da questo specchio
		if _proprietaria != self and (not is_inside_tree() or lei_altrove() or not giocatore_nella_zona()):
			return &"ferma"
		# (la luce del giro che si spegne alla fine del percorso, o mandata via: il canto muore come prima di un'uscita)
		if _fine_giro and _proprietaria == self:
			return &"spegne"
		return &"arriva" if in_giro() and vicinanza > 0.2 else &"lontana"

var _t := 0.0
var _durata := 0.0
var _punto: Node3D
var _da := Vector3.ZERO
var _getto := 0.0
var _ultimo_getto := -1
var _respinta := false
var _prossima := 0.0
var _dimostrativa := false
var _giro := PackedVector3Array()
var _giro_i := 0
## La velocità della luce nel giro (m/s).
var velocita_giro := 1.6
var _fine_giro := false
var _fine_da := Vector3.ZERO
var _fine_a := Vector3.ZERO
var _fine_t := 0.0
var _fine_durata := 1.0
var _una_volta := false
var _alla_fine: Node3D
var _spegni_alla_fine := 1.5

## Lei, la sua luce e il viso da colpire: una sola per tutto il gioco, sotto l'istanza che la usa.
static var _lei: MedusaAffacciata
static var _luce: OmniLight3D
static var _viso: WaterHitbox
static var _proprietaria: AcquaDiLei
## Le zone dove la prima uscita dimostrativa c'è già stata: in stato_lei.gd (si azzera con la partita nuova).
const _STATO := preload("res://scripts/game/stato_lei.gd")
## Gruppo delle lei che una scena sta usando adesso (la fossa in corso, le condotte, il tunnel): finché c'è, lei è lì,
## da nessun'altra parte (niente uscite, niente canto lontano). Chi ha la scena ci mette la sua lei e la toglie alla fine.
const LEI_IN_SCENA := &"lei_in_scena"


func _ready() -> void:
	add_to_group(GRUPPO)
	_prossima = randf_range(intervallo.x, intervallo.y)
	# lei pronta prima che serva (il modello è quello delle condotte e degli oblò, già nel riscaldamento)
	_assicura_lei.call_deferred()


func _exit_tree() -> void:
	if _proprietaria == self:
		_proprietaria = null


# --- Domande -----------------------------------------------------------------------------------------------------

## Vero se la prossima uscita da qui sarà quella dimostrativa (dal punto più lontano, non prende):
## [member prima_volta_dimostrativa] acceso e da questo nodo non è ancora uscita.
func prossima_dimostrativa() -> bool:
	return prima_volta_dimostrativa and not _STATO.dimostrate.has(_chiave())


func _chiave() -> String:
	return String(chiave_zona) if chiave_zona != &"" else str(get_path())


## Vero se lei adesso può venire qui.
func puo_venire() -> bool:
	if not abilitata or not is_inside_tree() or punti_uscita.is_empty():
		return false
	if GameState.luci != GameState.Luci.BLACKOUT or GameState.is_dying:
		return false
	if not giocatore_nella_zona():
		return false
	return not lei_altrove() and not bambino_in_vista()


## Dov'è lei adesso: vero se è da un'altra parte, cioè se un altro specchio la usa, se una scena la sta usando (la
## fossa in corso, le condotte, il tunnel: gruppo [constant LEI_IN_SCENA]) o se un'altra lei è in vista
## ([method lei_in_vista_altrove]). La usano [method puo_venire] (non viene) e [member fase_canto] (niente canto
## lontano: lei non è in due posti).
func lei_altrove() -> bool:
	if _proprietaria != null and is_instance_valid(_proprietaria) and _proprietaria != self:
		return true
	for n in get_tree().get_nodes_in_group(LEI_IN_SCENA):
		if n != _lei and n is Node3D and (n as Node3D).is_visible_in_tree():
			return true
	return lei_in_vista_altrove()


## Vero se il giocatore è nella zona di questo specchio (vedi [member zona_raggio]).
func giocatore_nella_zona() -> bool:
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return false
	for q in punti_uscita:
		if q and _in_pianta(q.global_position, p.global_position) <= zona_raggio \
				and absf(p.global_position.y - pelo_a(q)) <= zona_dislivello:
			return true
	return false


## Vero se un'altra lei (oblò, fossa, condotte, tunnel) è visibile e il giocatore la può vedere da dove sta: vicina
## e nell'inquadratura, o vicinissima (alle spalle). Una lei lontana o dietro i muri di un'altra zona non conta.
func lei_in_vista_altrove() -> bool:
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return false
	var cam := get_viewport().get_camera_3d()
	for n in get_tree().get_nodes_in_group(MedusaAffacciata.GRUPPO_LEI):
		var l := n as Node3D
		if l == null or l == _lei or not l.is_visible_in_tree():
			continue
		var q := l.global_position + Vector3.UP * 1.5
		var d := q.distance_to(p.global_position)
		if d > vista_lontano:
			continue
		if d > vista_dietro and not (cam and cam.is_position_in_frustum(q)):
			continue
		# (dietro i muri non la vede: una lei di un'altra stanza, come quella di un oblò dietro la parete, non conta)
		if not _coperta(p, cam, q):
			return true
	return false


## Vero se fra gli occhi del giocatore e [param q] c'è un muro (più di [constant VETRO_TOLLERANZA] m prima di lei:
## il vetro di un oblò, o il bordo della vasca dove lei sta, non la coprono).
const VETRO_TOLLERANZA := 2.5


func _coperta(p: Node3D, cam: Camera3D, q: Vector3) -> bool:
	var da := cam.global_position if cam else p.global_position + Vector3.UP * 1.6
	var spazio := get_world_3d().direct_space_state if is_inside_tree() else null
	if spazio == null:
		return false
	var qr := PhysicsRayQueryParameters3D.create(da, q)
	if p is CollisionObject3D:
		qr.exclude = [(p as CollisionObject3D).get_rid()]
	var hit := spazio.intersect_ray(qr)
	return not hit.is_empty() and (hit["position"] as Vector3).distance_to(da) < da.distance_to(q) - VETRO_TOLLERANZA


## Vero se un bambino (anche quelli visti di sfuggita) è visibile e dentro l'inquadratura.
func bambino_in_vista() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var lista: Array = get_tree().get_nodes_in_group(&"bambini")
	for n in get_tree().get_nodes_in_group(&"persist"):
		if n is BambinoSfuggita:
			lista.append(n)
	var p := GameState.player
	for n in lista:
		var b := n as Node3D
		if b == null or not b.is_visible_in_tree():
			continue
		var q := b.global_position + Vector3.UP * 0.8
		# (come per l'altra lei: lontano, o dietro i muri, non lo vede)
		if cam.global_position.distance_to(q) > vista_lontano or not cam.is_position_in_frustum(q):
			continue
		if p == null or not is_instance_valid(p) or not _coperta(p, cam, q):
			return true
	return false


## Il pelo dell'acqua sotto il punto [param p].
func pelo_a(p: Node3D) -> float:
	return pelo if not is_nan(pelo) else p.global_position.y


# --- Chiamarla --------------------------------------------------------------------------------------------------

## Lei arriva: la luce rosa parte verso il punto d'uscita (il più vicino al giocatore, o [param punto]).
## Ritorna falso se adesso non può.
func chiama(punto: Node3D = null) -> bool:
	if fase != Fase.LONTANA or not puo_venire():
		return false
	var p := GameState.player
	_dimostrativa = prima_volta_dimostrativa and not _STATO.dimostrate.has(_chiave())
	_punto = punto if punto else _scegli_punto(p, _dimostrativa)
	if _punto == null:
		return false
	_proprietaria = self
	_assicura_lei()
	# (col giro o alla fine di un percorso la luce c'è già: parte da dove sta)
	var gia := _luce.visible and _luce.light_energy > 0.05 and _luce.get_parent() == self
	_luce.reparent(self, false)
	var arrivo := _sotto(_punto)
	if gia:
		_da = _luce.global_position
	elif partenza_luce:
		_da = partenza_luce.global_position
	else:
		var via := Vector3.FORWARD
		if p and is_instance_valid(p):
			via = _punto.global_position - p.global_position
			via.y = 0.0
		if via.length() < 0.1:
			via = Vector3.FORWARD
		_da = arrivo + via.normalized() * 8.0
	if not gia:
		_da.y = arrivo.y - 0.4
		_luce.light_energy = 0.0
	_luce.omni_range = LUCE_SOTTO_PORTATA
	_luce.shadow_enabled = false
	_luce.global_position = _da
	_luce.visible = true
	_cambia(Fase.ARRIVA)
	arriva.emit(arrivo)
	return true


## Solo l'avviso, senza uscita: la luce va sotto [param punto] (con [method _sotto]), il canto fa «arriva», si spegne, mezzo
## secondo di silenzio ([member avviso] in tutto), poi la luce si spegne, lei lascia questo specchio e si chiama [param poi]
## (la fossa della sala al buio: lì sbuca LeiSbuca). Ritorna falso se adesso non può.
func annuncia(punto: Node3D, poi: Callable) -> bool:
	if not chiama(punto):
		return false
	_dimostrativa = false
	_solo_avviso = poi
	return true


var _solo_avviso := Callable()
## Altri volumi d'acqua (nel mondo) oltre ad [member acque], dove la luce è accesa: la fossa della sala al buio.
var acque_extra: Array[AABB] = []


## Dove esce: il punto più vicino al giocatore (il più lontano per l'uscita dimostrativa).
func _scegli_punto(p: Node3D, lontano: bool) -> Node3D:
	var meglio: Node3D = null
	var d_meglio := INF if not lontano else -INF
	for q in punti_uscita:
		if q == null:
			continue
		var d := _in_pianta(q.global_position, p.global_position) if p and is_instance_valid(p) else 0.0
		if (not lontano and d < d_meglio) or (lontano and d > d_meglio):
			d_meglio = d
			meglio = q
	return meglio


## Il punto della luce sotto l'uscita [param q]: 0,6 m sotto il pelo (nel modo MANO al centro della pozza, 0,6 m dentro
## dal marker e a metà fondo: il marker sta sul grigliato, sopra il bordino).
func _sotto(q: Node3D) -> Vector3:
	if modo == Modo.MANO:
		var c := q.global_transform * Vector3(0.0, 0.0, -0.6)
		c.y = pelo_a(q) - 0.35
		return c
	var v := q.global_position
	v.y = pelo_a(q) - 0.6
	return v


# --- Ogni fotogramma ---------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	var p := GameState.player
	# nessuno specchio tiene lei da lontano: col giocatore fuori dalla zona se ne va (non mentre è fuori dall'acqua)
	if _proprietaria == self and not _riscaldo and not giocatore_nella_zona():
		lascia()
	match fase:
		Fase.LONTANA:
			vicinanza = 0.0
			if not _giro.is_empty() or _fine_giro:
				_muovi_giro(delta, p)
			if automatica and p and is_instance_valid(p) and _vicino(p):
				_prossima -= delta
				if _prossima <= 0.0:
					_prossima = randf_range(intervallo.x, intervallo.y)
					chiama()
		Fase.ARRIVA:
			var dur := maxf(avviso - spegnimento - silenzio, 0.01)
			var k := clampf(_t / dur, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			var prima := _luce.global_position
			_luce.global_position = _da.lerp(_sotto(_punto), e)
			_luce.light_energy = minf(maxf(_luce.light_energy, LUCE_SOTTO * clampf(k * 3.0, 0.0, 1.0)),
					_energia_in_acqua(LUCE_SOTTO, delta, _luce.global_position - prima))
			vicinanza = e * 0.9
			punto_luce = _luce.global_position
			if _t >= dur:
				vicinanza = 1.0
				_cambia(Fase.SPEGNE)
		Fase.SPEGNE:
			vicinanza = 1.0
			_luce.light_energy = LUCE_SOTTO * (0.85 + 0.15 * sin(_t * 9.0))
			punto_luce = _luce.global_position
			if _t >= spegnimento:
				_cambia(Fase.SILENZIO)
		Fase.SILENZIO:
			vicinanza = 1.0
			# la luce ferma, che pulsa piano
			_luce.light_energy = LUCE_SOTTO * (0.85 + 0.15 * sin(_t * 9.0))
			punto_luce = _luce.global_position
			if _t >= silenzio and _solo_avviso.is_valid():
				var poi := _solo_avviso
				_solo_avviso = Callable()
				lascia()
				poi.call()
			elif _t >= silenzio:
				# un bambino è comparso intanto, o un'altra lei: non esce, la luce se ne va
				if bambino_in_vista() or lei_in_vista_altrove() or GameState.is_dying:
					_annulla()
				else:
					_esci()
		Fase.ESCE:
			vicinanza = 1.0
			_aggiorna_viso()
			_girala_verso(p)
			if _t >= _durata:
				_cambia(Fase.SU)
				if modo == Modo.MANO:
					_anima("pozza_attesa", 0.0)
				else:
					_anima("incombe", 0.2)
					_lei.segui_con_la_testa(1.0, 0.5)
		Fase.SU:
			vicinanza = 1.0
			_aggiorna_viso()
			_girala_verso(p)
			var vicino := p != null and is_instance_valid(p) \
					and _in_pianta(p.global_position, _punto.global_position) <= (portata_mano if modo == Modo.MANO else portata)
			if letale and not _dimostrativa and vicino and _t >= (tempo_presa_mano if modo == Modo.MANO else tempo_presa):
				_prendi()
			elif _t >= tempo_su:
				_scendi(false)
		Fase.PRESA:
			_aggiorna_viso()
		Fase.SCENDE:
			vicinanza = clampf(1.0 - _t / maxf(_durata, 0.01), 0.0, 1.0)
			if _t >= _durata:
				_lei.visible = false
				_luce.visible = false
				tornata_sotto.emit()
				_cambia(Fase.CALMA)
		Fase.CALMA:
			vicinanza = 0.0
			# (col giro della luce lei resta qui: la luce riparte da dove è scesa)
			if _proprietaria == self and _giro.is_empty():
				_proprietaria = null
			if _t >= (pausa_respinta if _respinta else pausa_dopo):
				_cambia(Fase.LONTANA)


func _vicino(p: Node3D) -> bool:
	for q in punti_uscita:
		if q and _in_pianta(q.global_position, p.global_position) <= distanza_richiamo:
			return true
	return false


func _cambia(f: Fase) -> void:
	fase = f
	_t = 0.0
	fase_cambiata.emit(f)


## La luce se ne va senza che lei esca (un bambino in vista all'ultimo momento).
func _annulla() -> void:
	if _giro.is_empty():
		_luce.visible = false
		_proprietaria = null
	_cambia(Fase.LONTANA)


# --- Il giro della luce (la sala al buio) ---------------------------------------------------------------------------

## Mentre è lontana la luce rosa gira sott'acqua lungo [param punti] (nel mondo, in ciclo) a [param velocita] m/s:
## lei è qui (in nessun altro posto) e si avvicina e si allontana. La zona la chiama ([method chiama]) quando la luce
## passa vicino a un punto d'uscita (vedi [method punto_vicino_alla_luce]): parte da dove sta la luce.
## Ritorna falso se adesso lei non può essere qui.
func gira(punti: PackedVector3Array, velocita := 1.6) -> bool:
	if punti.size() < 2 or fase != Fase.LONTANA or not puo_venire():
		return false
	_assicura_lei()
	# (la luce già accesa qui, ferma o in giro: riparte da dove sta, senza spegnersi)
	var gia := _proprietaria == self and _luce.visible and _luce.get_parent() == self and _luce.light_energy > 0.05
	_proprietaria = self
	_giro = punti
	velocita_giro = velocita
	_fine_giro = false
	_luce.reparent(self, false)
	if not gia or _luce.global_position.distance_to(punti[0]) > 0.3:
		_luce.global_position = punti[0]
	_giro_i = 1
	_luce.omni_range = LUCE_SOTTO_PORTATA
	_luce.shadow_enabled = false
	if not gia:
		_luce.light_energy = 0.0
	_luce.visible = true
	punto_luce = _luce.global_position
	return true


## Lei se ne va subito da qui (la luce si spegne, il giro finisce): per il giocatore uscito dalla zona.
func lascia() -> void:
	_solo_avviso = Callable()
	if fase == Fase.ARRIVA or fase == Fase.SPEGNE or fase == Fase.SILENZIO:
		_cambia(Fase.LONTANA)
	elif fase != Fase.LONTANA and fase != Fase.CALMA:
		return
	_giro = PackedVector3Array()
	_fine_giro = false
	_una_volta = false
	_alla_fine = null
	if _luce and is_instance_valid(_luce) and _luce.get_parent() == self:
		_luce.visible = false
		_luce.light_energy = 0.0
	if _proprietaria == self:
		_proprietaria = null


## Il giro finisce: la luce va a [param verso] (sott'acqua), si spegne in [param secondi] e lei se ne va da qui.
func smetti_giro(verso: Vector3, secondi := 2.5) -> void:
	if _giro.is_empty():
		return
	_giro = PackedVector3Array()
	_fine_giro = true
	_fine_da = _luce.global_position
	_fine_a = verso
	_fine_durata = maxf(secondi, 0.1)
	_fine_t = 0.0


## La luce fa una volta sola il percorso [param punti] (nel mondo, sott'acqua) a [param velocita] m/s, senza che lei
## esca: la luce che passa di pozza in pozza, quella che passa sotto la vasca della sala pompe e se ne va. Alla fine:
## con [param alla_fine] (un punto d'uscita, sopra l'ultimo punto del percorso) lei viene lì come con [method chiama]
## (avviso, canto che si spegne, silenzio, esce); senza, la luce si spegne in [param spegni] s e lei se ne va; con
## [param spegni] 0 la luce resta accesa e ferma all'ultimo punto (lei resta qui) finché la zona non la chiama
## ([method chiama] parte da lì) o la manda via ([method manda_via]). Intanto la fase resta LONTANA.
## Ritorna falso se adesso lei non può essere qui.
func percorri(punti: PackedVector3Array, velocita := 1.6, alla_fine: Node3D = null, spegni := 1.5) -> bool:
	if not gira(punti, velocita):
		return false
	_una_volta = true
	_alla_fine = alla_fine
	_spegni_alla_fine = spegni
	return true


## Vero mentre la luce fa il giro (o lo sta finendo).
func in_giro() -> bool:
	return not _giro.is_empty() or _fine_giro


## Il punto d'uscita sopra cui passa adesso la luce del giro (entro [param raggio] m, in pianta), o null.
func punto_vicino_alla_luce(raggio := 2.0) -> Node3D:
	if _giro.is_empty() or fase != Fase.LONTANA or not _luce.visible:
		return null
	for q in punti_uscita:
		if q and _in_pianta(q.global_position, _luce.global_position) <= raggio:
			return q
	return null


func _muovi_giro(delta: float, p: Node3D) -> void:
	if _luce == null or not is_instance_valid(_luce):
		_giro = PackedVector3Array()
		_fine_giro = false
		return
	if _luce.get_parent() != self:
		# (era su di lei: riparte da dove è scesa)
		_luce.reparent(self, false)
		_luce.omni_range = LUCE_SOTTO_PORTATA
		_luce.shadow_enabled = false
		if _punto:
			_luce.global_position = _sotto(_punto)
		_giro_i = _vicino_del_giro(_luce.global_position)
	_luce.visible = true
	if _fine_giro:
		_fine_t += delta
		var k := clampf(_fine_t / _fine_durata, 0.0, 1.0)
		_luce.global_position = _fine_da.lerp(_fine_a, k * k * (3.0 - 2.0 * k))
		_luce.light_energy = minf(LUCE_SOTTO * (1.0 - k), _energia_in_acqua(LUCE_SOTTO, delta))
		punto_luce = _luce.global_position
		if k >= 1.0:
			_fine_giro = false
			_luce.visible = false
			if _proprietaria == self:
				_proprietaria = null
			percorso_finito.emit()
		return
	_luce.light_energy = _energia_in_acqua(LUCE_SOTTO, delta)
	if _giro.size() == 1:
		_luce.global_position = _giro[0]
		punto_luce = _luce.global_position
		if p and is_instance_valid(p):
			vicinanza = clampf(1.0 - _in_pianta(p.global_position, punto_luce) / 14.0, 0.0, 1.0) * 0.8
		return
	var dove: Vector3 = _giro[_giro_i]
	var passo := velocita_giro * delta
	var verso := dove - _luce.global_position
	if verso.length() <= passo:
		_luce.global_position = dove
		if _una_volta and _giro_i == _giro.size() - 1:
			# il percorso è finito
			_una_volta = false
			var fine := _alla_fine
			_alla_fine = null
			if fine == null and _spegni_alla_fine <= 0.0:
				# resta accesa e ferma qui
				_giro = PackedVector3Array([_luce.global_position])
				_giro_i = 0
				percorso_finito.emit()
				return
			if fine:
				_giro = PackedVector3Array()
				_proprietaria = null
				percorso_finito.emit()
				# (chiama parte da dove sta la luce); se adesso non può uscire, la luce si spegne lì
				if not chiama(fine):
					_proprietaria = self
					_fine_giro = true
					_fine_da = _luce.global_position
					_fine_a = _fine_da
					_fine_durata = maxf(_spegni_alla_fine, 0.1)
					_fine_t = 0.0
			else:
				smetti_giro(_luce.global_position, _spegni_alla_fine)
			return
		_giro_i = (_giro_i + 1) % _giro.size()
	else:
		_luce.global_position += verso.normalized() * passo
	punto_luce = _luce.global_position
	# per il canto: più vicina quanto più la luce è vicina al giocatore (al più 0,8: fuori è 1)
	if p and is_instance_valid(p):
		vicinanza = clampf(1.0 - _in_pianta(p.global_position, punto_luce) / 14.0, 0.0, 1.0) * 0.8


## Vero se [param q] è dentro un volume d'acqua vera di [member acque] (lontano 5 cm dalle pareti e dal fondo e sotto
## il pelo); senza [member acque], sempre.
func in_acqua(q: Vector3) -> bool:
	if acque.is_empty():
		return true
	for b in acque_extra:
		if b.has_point(q):
			return true
	for a in acque:
		var t := a as WaterTank
		if t == null or not is_instance_valid(t):
			continue
		var l := t.to_local(q)
		var m := t.inner_size * 0.5
		if absf(l.x) <= m.x - 0.05 and absf(l.z) <= m.z - 0.05 \
				and q.y >= t.get_floor_global_y() + 0.05 and q.y <= t.get_surface_global_y() - 0.05:
			return true
	return false


## L'energia della luce verso [param piena] dentro l'acqua e verso 0 fuori, in 0,25 s; guarda anche 0,45 m più avanti
## (dove va la luce), così si spegne arrivando al bordo e non dopo averlo passato.
func _energia_in_acqua(piena: float, delta: float, mossa := Vector3.ZERO) -> float:
	var q := _luce.global_position
	var avanti := mossa
	if avanti.length_squared() < 1e-8 and not _giro.is_empty() and _giro_i < _giro.size():
		avanti = _giro[_giro_i] - q
	var dentro := in_acqua(q) and (avanti.length_squared() < 1e-8 or in_acqua(q + avanti.normalized() * 0.45))
	return move_toward(_luce.light_energy, piena if dentro else 0.0, piena * delta / 0.25)


## L'indice del punto del giro più vicino a [param q].
func _vicino_del_giro(q: Vector3) -> int:
	var meglio := 0
	for i in _giro.size():
		if _giro[i].distance_to(q) < _giro[meglio].distance_to(q):
			meglio = i
	return (meglio + 1) % _giro.size() if _giro.size() > 1 else 0


# --- Fuori dall'acqua --------------------------------------------------------------------------------------------

func _esci() -> void:
	_assicura_lei()
	if _dimostrativa:
		_STATO.dimostrate[_chiave()] = true
	_lei.reparent(self, false)
	_lei.global_position = _punto.global_position
	_lei.visible = true
	_luce.reparent(_lei, false)
	_luce.position = Vector3(0, 2.4, 0.9)
	_luce.light_energy = LUCE_SU
	_luce.omni_range = LUCE_SU_PORTATA
	_luce.shadow_enabled = true
	_getto = 0.0
	_ultimo_getto = -1
	_respinta = false
	_lei.segui_con_la_testa(0.0, 0.01)
	if modo == Modo.MANO:
		_esci_mano()
		return
	_viso_mano(false)
	_girala_verso(GameState.player)
	var nome := "sale_dall_acqua"
	var dur := _anima(nome)
	var t0 := _quando_radice(StringName(ANIM + nome), clampf(profondita, 0.0, 5.0), true)
	var ap := _ap()
	if ap:
		ap.seek(t0, true)
	_durata = dur - t0
	_cambia(Fase.ESCE)
	# l'acqua che si apre (verso metà della salita)
	get_tree().create_timer(_durata * 0.45, false).timeout.connect(func():
		if fase == Fase.ESCE and _proprietaria == self:
			Audio.suona(&"tuffo", _lei.global_position + Vector3.UP * 3.0, 0.0, 0.7))
	uscita.emit()


## Modo MANO: lei col marker (non si gira), la luce resta nell'acqua della pozza, pozza_esce dall'inizio: la mano
## esce e sbatte sul grigliato (MANO_SBATTE), poi i tentacoli strisciano sulla passerella.
func _esci_mano() -> void:
	_lei.global_transform = _punto.global_transform
	_luce.reparent(self, false)
	_luce.global_position = _sotto(_punto)
	_luce.light_energy = LUCE_POZZA
	_luce.omni_range = LUCE_POZZA_PORTATA
	_luce.shadow_enabled = false
	_durata = _anima("pozza_esce")
	var ap := _ap()
	if ap:
		ap.seek(0.0, true)
	_viso_mano(true)
	_cambia(Fase.ESCE)
	get_tree().create_timer(0.2, false).timeout.connect(func():
		if fase == Fase.ESCE and _proprietaria == self:
			Audio.suona(&"tuffo", _punto.global_position, -6.0, 1.3))
	get_tree().create_timer(MANO_SBATTE, false).timeout.connect(func():
		if fase == Fase.ESCE and _proprietaria == self:
			Audio.suona(&"atterraggio_acqua", _punto.global_position, 0.0, 1.4))
	uscita.emit()


func _prendi() -> void:
	_cambia(Fase.PRESA)
	if modo == Modo.MANO:
		_anima("pozza_presa", 0.1)
		# la scena di morte (DeathSequence): la camera scende e si ferma sopra il pelo, al bordo della pozza dalla parte del
		# giocatore, e guarda dove il braccio rientra nell'acqua; il viso no (piano B del coordinatore per la 0.4.0)
		_lei.set_meta(&"camera_morte", camera_morte_mano())
		_lei.add_to_group(&"medusa_che_prende")
		presa.emit()
		GameState.kill_player(&"medusa")
		return
	if _lei.has_meta(&"camera_morte"):
		_lei.remove_meta(&"camera_morte")
	_girala_verso(GameState.player)
	_lei.segui_con_la_testa(0.0, 0.1)
	_anima("presa", 0.15)
	_lei.attacca(0.7, &"")
	_lei.add_to_group(&"medusa_che_prende")
	presa.emit()
	GameState.kill_player(&"medusa")


## Nel modo MANO, la strada della camera nella scena di morte ([caduta, arrivo, bersaglio], nel mondo; piano B del
## coordinatore per la 0.4.0, il viso no). Prima cade verso il grigliato accanto alla caviglia (di lato al braccio), poi è
## trascinata a strattoni fino al bordo, alta sopra il braccio e i tentacoli stesi. Con [member camera_morte_avanti] (la
## proposta del coordinatore) finisce col viso sopra il liquido, 22 cm sopra il pelo appena dentro il bordo, inclinata in
## giù verso il liquido opaco davanti e sotto: lo schermo quasi tutto del colore della pozza, il chiarore rosa in alto, il
## braccio sotto e dietro. Senza, finisce dentro la pozza 30 cm sopra il pelo e guarda indietro il bordo, dove il braccio
## esce dal liquido verso la caviglia. (Per gli scatti: la variabile d'ambiente CAMERA_MORTE = "avanti" o "bordo".)
func camera_morte_mano() -> Array:
	var q := _punto
	var pelo_q := pelo_a(q)
	var caduta := q.global_transform * Vector3(0.35, 0.0, 0.8)
	caduta.y = q.global_position.y + 0.6
	var avanti := camera_morte_avanti
	if OS.has_environment("CAMERA_MORTE"):
		avanti = OS.get_environment("CAMERA_MORTE") == "avanti"
	if avanti:
		var pos_a := q.global_transform * Vector3(0.12, 0.0, -0.12)
		pos_a.y = maxf(pelo_q, q.global_position.y) + 0.22
		var guarda_a := q.global_transform * Vector3(0.0, 0.0, -0.75)
		guarda_a.y = pelo_q - 0.25
		return [caduta, pos_a, guarda_a]
	var pos := q.global_transform * Vector3(0.25, 0.0, -0.5)
	pos.y = maxf(pelo_q, q.global_position.y) + 0.3
	var guarda := q.global_transform * Vector3(0.0, 0.0, 0.15)
	guarda.y = pelo_q + 0.1
	return [caduta, pos, guarda]


## Torna sotto: respinta (il getto in faccia) o da sola (dopo averti cercato: sbatte nell'acqua).
func _scendi(da_respinta: bool) -> void:
	_respinta = da_respinta
	_lei.segui_con_la_testa(0.0, 0.15)
	var nome := "respinta" if da_respinta else "scende"
	if modo == Modo.MANO:
		nome = "pozza_" + nome
	var dur_anim := _anima(nome, 0.15 if modo == Modo.INTERA else 0.08)
	var a := _ap().get_animation(StringName(ANIM + nome)) if _ap() else null
	if modo == Modo.MANO:
		_durata = dur_anim
	else:
		_durata = _quando_radice(StringName(ANIM + nome), clampf(profondita, 0.05, 5.0), false) if a else 1.0
	# la luce si spegne con lei, negli ultimi 0,4 s
	var spegni := minf(0.4, _durata)
	var tw := create_tween()
	tw.tween_interval(_durata - spegni)
	tw.tween_property(_luce, "light_energy", 0.0, spegni)
	var dove := _punto.global_position if modo == Modo.MANO else _lei.global_position + Vector3.UP * 3.0
	get_tree().create_timer(_durata * (0.3 if modo == Modo.MANO else 0.6), false).timeout.connect(func():
		if fase == Fase.SCENDE and _proprietaria == self:
			Audio.suona(&"atterraggio_acqua", dove, -2.0 if modo == Modo.MANO else 2.0, 1.2 if modo == Modo.MANO else 0.6))
	_cambia(Fase.SCENDE)
	if da_respinta:
		respinta.emit()


func _su_getto(_litri: float, _punto_colpo: Vector3, _dir: Vector3) -> void:
	if fase != Fase.ESCE and fase != Fase.SU:
		return
	# i secondi di getto di fila, nel tempo del gioco (un colpo ogni fotogramma di fisica mentre spruzzi; una pausa più
	# lunga di 0,2 s ricomincia il conto)
	var ora := Engine.get_physics_frames()
	var passo := 1.0 / Engine.physics_ticks_per_second
	if _ultimo_getto >= 0 and (ora - _ultimo_getto) * passo <= 0.2:
		_getto += (ora - _ultimo_getto) * passo
	else:
		_getto = 0.0
	_ultimo_getto = ora
	if _getto >= getto_per_respingere:
		_scendi(true)


## La manda via. Se non è ancora uscita (la luce che gira o percorre, l'avviso) la luce si allontana di qualche metro
## dal giocatore, si spegne in [param secondi] e lei se ne va (fase LONTANA, libera); se è già fuori (ESCE, SU) è come
## [method respingi]. Le pozze la chiamano quando il giocatore comincia a svuotare il colore della pozza.
func manda_via(secondi := 1.0) -> void:
	if fase == Fase.ESCE or fase == Fase.SU:
		_scendi(true)
		return
	var sotto := fase == Fase.ARRIVA or fase == Fase.SPEGNE or fase == Fase.SILENZIO
	if not sotto and _giro.is_empty():
		return
	if _luce == null or not is_instance_valid(_luce) or not _luce.visible:
		return
	var via := Vector3.FORWARD
	var p := GameState.player
	if p and is_instance_valid(p):
		via = _luce.global_position - p.global_position
		via.y = 0.0
	if via.length() < 0.1:
		via = Vector3.FORWARD
	_giro = PackedVector3Array()
	_una_volta = false
	_alla_fine = null
	_fine_giro = true
	_fine_da = _luce.global_position
	_fine_a = _fine_da + via.normalized() * 3.0
	_fine_durata = maxf(secondi, 0.1)
	_fine_t = 0.0
	_proprietaria = self
	if sotto:
		_cambia(Fase.LONTANA)


## Respinge lei adesso, come un getto lungo in faccia (per i test e per chi la ricaccia in altro modo).
func respingi() -> void:
	if fase == Fase.ESCE or fase == Fase.SU:
		_scendi(true)


# --- Il riscaldamento ---------------------------------------------------------------------------------------------

var _riscaldo := false


## Per il riscaldamento degli shader della zona (RiscaldamentoShader.disegna_fuori_vista intorno alla zona): con
## [param acceso] mette lei fuori dall'acqua sul primo punto d'uscita, visibile, con la luce di quando è fuori e
## l'animazione [param animazione] (vuota: quella dell'uscita, sale_dall_acqua o pozza_esce, a metà), così la prima
## uscita vera non compila niente; con falso la nasconde e rimette la luce spenta sotto lo specchio. Non fa niente se
## lei è in uso (qui fuori dalla fase LONTANA, o in un altro specchio).
func posa_per_il_riscaldamento(acceso: bool, animazione := "") -> void:
	if not acceso:
		if not _riscaldo:
			return
		_riscaldo = false
		if _lei and is_instance_valid(_lei):
			_lei.visible = false
		if _luce and is_instance_valid(_luce):
			_luce.visible = false
			_luce.light_energy = 0.0
			_luce.reparent(self, false)
		if _proprietaria == self and _giro.is_empty():
			_proprietaria = null
		return
	if punti_uscita.is_empty() or fase != Fase.LONTANA or in_giro():
		return
	if _proprietaria != null and is_instance_valid(_proprietaria) and _proprietaria != self:
		return
	_assicura_lei()
	_riscaldo = true
	_proprietaria = self
	var q := punti_uscita[0]
	_lei.reparent(self, false)
	if modo == Modo.MANO:
		_lei.global_transform = q.global_transform
		_luce.reparent(self, false)
		_luce.global_position = _sotto(q)
		_luce.light_energy = LUCE_POZZA
		_luce.omni_range = LUCE_POZZA_PORTATA
		_luce.shadow_enabled = false
	else:
		_lei.global_position = q.global_position
		_luce.reparent(_lei, false)
		_luce.position = Vector3(0, 2.4, 0.9)
		_luce.light_energy = LUCE_SU
		_luce.omni_range = LUCE_SU_PORTATA
		_luce.shadow_enabled = true
	_viso_mano(modo == Modo.MANO)
	_lei.visible = true
	_luce.visible = true
	var nome := animazione if animazione != "" else ("pozza_esce" if modo == Modo.MANO else "sale_dall_acqua")
	var dur := _anima(nome)
	var ap := _ap()
	if ap:
		ap.seek(dur * 0.6, true)


# --- Lei condivisa ------------------------------------------------------------------------------------------------

## Lei (MedusaAffacciata con le animazioni dell'inseguimento), la luce rosa e il viso da colpire: creati una volta,
## nascosti, sotto la prima istanza che li chiede.
func _assicura_lei() -> void:
	# (ognuno dei tre si controlla da solo: lei e la luce possono stare sotto specchi diversi, e uno specchio liberato
	# si porta via quello che ha sotto; si ricrea solo quello che manca, mai una seconda luce)
	if not (_lei and is_instance_valid(_lei)):
		_lei = MedusaAffacciata.new()
		_lei.name = "LeiNellAcqua"
		_lei.model = LeiOblo.MODELLO
		_lei.bell_material = LeiOblo.CAMPANA
		_lei.material_map = LeiOblo.MATERIALI.duplicate()
		_lei.animazioni_inseguimento = true
		_lei.animazione = &"inseguimento/incombe"
		_lei.visible = false
		add_child(_lei)
		_viso = null
	if not (_luce and is_instance_valid(_luce)):
		_luce = OmniLight3D.new()
		_luce.name = "LuceSottacqua"
		_luce.light_color = ROSA
		_luce.light_energy = 0.0
		_luce.omni_range = LUCE_SOTTO_PORTATA
		_luce.light_volumetric_fog_energy = 3.0
		_luce.shadow_enabled = false
		_luce.visible = false
		_luce.set_meta(&"risveglio_ignora", true)
		add_child(_luce)
	if not (_viso and is_instance_valid(_viso)):
		_viso = WaterHitbox.new()
		_viso.name = "Viso"
		var cs := CollisionShape3D.new()
		var sf := SphereShape3D.new()
		sf.radius = 0.9
		cs.shape = sf
		_viso.add_child(cs)
		_viso.position = Vector3(0, 3.4, 0.6)
		_lei.add_child(_viso)
		_viso.water_hit.connect(func(litri: float, pt: Vector3, d: Vector3):
			if _proprietaria and is_instance_valid(_proprietaria):
				_proprietaria._su_getto(litri, pt, d))


## Quando questo specchio viene liberato, quello che ha sotto di condiviso (lei, la luce, il viso) se ne va con lui:
## gli altri specchi lo ricreano ([method _assicura_lei]) invece di toccare un oggetto liberato.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _luce and is_instance_valid(_luce) and is_ancestor_of(_luce):
			_luce = null
		if _lei and is_instance_valid(_lei) and is_ancestor_of(_lei):
			_lei = null
			_viso = null
		if _proprietaria == self:
			_proprietaria = null


func _ap() -> AnimationPlayer:
	return _lei.find_child("AnimationPlayer", true, false) as AnimationPlayer if _lei else null


## Fa partire "inseguimento/<nome>" con [param fondi] s di fusione; ritorna la durata.
func _anima(nome: String, fondi := 0.0) -> float:
	var n := StringName(ANIM + nome)
	_lei.animazione = n
	var ap := _ap()
	if ap == null or not ap.has_animation(n):
		return 1.0
	ap.play(n, fondi)
	return ap.get_animation(n).length


## Il viso da colpire segue l'occhio (nel modo MANO: la mano, il getto sulla mano la ricaccia sotto).
func _aggiorna_viso() -> void:
	if _viso == null:
		return
	if modo == Modo.MANO:
		var sk := _scheletro()
		var i := sk.find_bone("mano.R") if sk else -1
		if i >= 0:
			_viso.global_position = sk.global_transform * sk.get_bone_global_pose(i).origin
		return
	var occhio := _lei.get_eye_position()
	if occhio != Vector3.ZERO:
		_viso.global_position = occhio


## Il bersaglio del getto: grande come il viso (INTERA) o come la mano (MANO).
func _viso_mano(mano: bool) -> void:
	var cs := _viso.get_child(0) as CollisionShape3D if _viso and _viso.get_child_count() > 0 else null
	if cs and cs.shape is SphereShape3D:
		(cs.shape as SphereShape3D).radius = 0.4 if mano else 0.9


func _scheletro() -> Skeleton3D:
	if _lei == null:
		return null
	var l := _lei.find_children("*", "Skeleton3D", true, false)
	return l[0] as Skeleton3D if l.size() > 0 else null


func _girala_verso(p: Node3D) -> void:
	if p == null or not is_instance_valid(p) or _lei == null or modo == Modo.MANO:
		return
	var guarda := p.global_position
	guarda.y = _lei.global_position.y
	if guarda.distance_to(_lei.global_position) > 0.1:
		_lei.look_at(guarda, Vector3.UP, true)


## Il tempo dell'animazione in cui la radice è [param sotto] m sotto la quota della fine (salita) o dell'inizio
## (discesa): come SalaInseguimento._quando_radice.
func _quando_radice(anim: StringName, sotto: float, salita: bool) -> float:
	var ap := _ap()
	var a := ap.get_animation(anim) if ap and ap.has_animation(anim) else null
	if a == null:
		return 0.0
	var tr := -1
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D and String(a.track_get_path(i)).ends_with(":radice"):
			tr = i
	if tr < 0 or sotto >= 4.99:
		return 0.0 if salita else a.length
	var n := a.track_get_key_count(tr)
	var rif: float = (a.track_get_key_value(tr, n - 1 if salita else 0) as Vector3).y
	for k in n:
		var y: float = (a.track_get_key_value(tr, k) as Vector3).y
		if salita and y >= rif - sotto:
			return a.track_get_key_time(tr, k)
		if not salita and y <= rif - sotto:
			return a.track_get_key_time(tr, k)
	return 0.0 if salita else a.length


static func _in_pianta(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Lei è in uso qui adesso (per i test: mai in due posti).
static func chi_la_usa() -> AcquaDiLei:
	return _proprietaria if _proprietaria and is_instance_valid(_proprietaria) else null
