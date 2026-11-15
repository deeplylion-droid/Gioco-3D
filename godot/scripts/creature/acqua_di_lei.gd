class_name AcquaDiLei
extends Node3D
## «L'acqua è sua» (build 0.4.0, GDD: «Analisi del capitolo 1 e direzione nuova», 15 novembre): lei in uno specchio
## d'acqua vero (vasca, pozza profonda, canale). Si attacca come figlio della zona, con uno o più punti d'uscita.
## Le fasi:
## - LONTANA: niente. Da qui la chiama la zona ([method chiama]) o, con [member automatica], lei stessa ogni tanto;
## - ARRIVA: la luce rosa sott'acqua arriva sotto il punto d'uscita (per [member avviso] - [member silenzio] s);
## - SILENZIO: l'ultimo secondo dell'avviso, la luce è lì e il canto si ferma (lo legge l'audio: [member fase]);
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

enum Fase { LONTANA, ARRIVA, SILENZIO, ESCE, SU, PRESA, SCENDE, CALMA }
## Come esce: intera (le vasche grandi) o mano e tentacoli (gli specchi stretti: punto 3 della build, da fare).
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

@export var abilitata := true
@export var modo := Modo.INTERA
## I punti d'uscita: l'origine è la posa «su» (incombe) di lei, cioè dove sta il suo nodo quando è fuori; le
## animazioni salgono da 5 m sotto. Lei si gira verso il giocatore. Esce dal punto più vicino al giocatore.
@export var punti_uscita: Array[Node3D] = []
## Quota del pelo dell'acqua (nel mondo). NAN: quella del punto d'uscita.
@export var pelo := NAN
## Quanto spazio c'è sotto i punti d'uscita (m, al più 5): la salita parte da lì, nascosta sott'acqua.
@export var profondita := 5.0
## Da dove arriva la luce rosa (se manca: 8 m dietro il punto d'uscita, dalla parte opposta al giocatore).
@export var partenza_luce: Node3D
@export_group("Tempi e distanze")
## L'avviso intero (s): la luce che arriva più il silenzio.
@export var avviso := 3.0
## L'ultima parte dell'avviso (s): la luce è ferma lì e il canto tace.
@export var silenzio := 1.0
## Più vicino di così al punto d'uscita (m, in pianta) quando è fuori: ti prende.
@export var portata := 3.0
## Quanto sta su a cercarti, se non sei nella portata (s).
@export var tempo_su := 2.2
## Da su, quanto aspetta prima di prenderti (s): il tempo di uno spruzzo.
@export var tempo_presa := 0.35
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
## Lei viene da sola quando il giocatore è entro [member distanza_richiamo] da un punto d'uscita, ogni
## [member intervallo] s (a caso fra i due).
@export var automatica := false
@export var intervallo := Vector2(14.0, 26.0)
@export var distanza_richiamo := 10.0

var fase := Fase.LONTANA
## Quanto è vicina (0 lontana, 1 sotto il punto o fuori): per il canto.
var vicinanza := 0.0
## Dove sta la luce rosa (nel mondo).
var punto_luce := Vector3.ZERO

var _t := 0.0
var _durata := 0.0
var _punto: Node3D
var _da := Vector3.ZERO
var _getto := 0.0
var _ultimo_getto := -1
var _respinta := false
var _prossima := 0.0
var _dimostrativa := false

## Lei, la sua luce e il viso da colpire: una sola per tutto il gioco, sotto l'istanza che la usa.
static var _lei: MedusaAffacciata
static var _luce: OmniLight3D
static var _viso: WaterHitbox
static var _proprietaria: AcquaDiLei
## Le zone dove la prima uscita dimostrativa c'è già stata (per percorso del nodo: una volta per partita).
static var _dimostrate := {}


func _ready() -> void:
	add_to_group(GRUPPO)
	_prossima = randf_range(intervallo.x, intervallo.y)
	# lei pronta prima che serva (il modello è quello delle condotte e degli oblò, già nel riscaldamento)
	_assicura_lei.call_deferred()


func _exit_tree() -> void:
	if _proprietaria == self:
		_proprietaria = null


# --- Domande -----------------------------------------------------------------------------------------------------

## Vero se lei adesso può venire qui.
func puo_venire() -> bool:
	if not abilitata or not is_inside_tree() or punti_uscita.is_empty():
		return false
	if GameState.luci != GameState.Luci.BLACKOUT or GameState.is_dying:
		return false
	if _proprietaria != null and is_instance_valid(_proprietaria) and _proprietaria != self:
		return false
	return not lei_in_vista_altrove() and not bambino_in_vista()


## Vero se un'altra lei (oblò, fossa, condotte, tunnel) è in scena adesso.
func lei_in_vista_altrove() -> bool:
	var scena := get_tree().current_scene
	if scena == null:
		return false
	for n in scena.find_children("*", "MedusaAffacciata", true, false):
		if n != _lei and (n as Node3D).is_visible_in_tree():
			return true
	return false


## Vero se un bambino (anche quelli visti di sfuggita) è visibile e dentro l'inquadratura.
func bambino_in_vista() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var lista: Array = get_tree().get_nodes_in_group(&"bambini")
	for n in get_tree().get_nodes_in_group(&"persist"):
		if n is BambinoSfuggita:
			lista.append(n)
	for n in lista:
		var b := n as Node3D
		if b and b.is_visible_in_tree() and cam.is_position_in_frustum(b.global_position + Vector3.UP * 0.8):
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
	_dimostrativa = prima_volta_dimostrativa and not _dimostrate.has(str(get_path()))
	_punto = punto if punto else _scegli_punto(p, _dimostrativa)
	if _punto == null:
		return false
	_proprietaria = self
	_assicura_lei()
	_luce.reparent(self, false)
	var arrivo := _sotto(_punto)
	if partenza_luce:
		_da = partenza_luce.global_position
	else:
		var via := Vector3.FORWARD
		if p and is_instance_valid(p):
			via = _punto.global_position - p.global_position
			via.y = 0.0
		if via.length() < 0.1:
			via = Vector3.FORWARD
		_da = arrivo + via.normalized() * 8.0
	_da.y = arrivo.y - 0.4
	_luce.light_energy = 0.0
	_luce.omni_range = LUCE_SOTTO_PORTATA
	_luce.shadow_enabled = false
	_luce.global_position = _da
	_luce.visible = true
	_cambia(Fase.ARRIVA)
	arriva.emit(arrivo)
	return true


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


## Il punto della luce sotto l'uscita [param q]: 0,6 m sotto il pelo.
func _sotto(q: Node3D) -> Vector3:
	var v := q.global_position
	v.y = pelo_a(q) - 0.6
	return v


# --- Ogni fotogramma ---------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	var p := GameState.player
	match fase:
		Fase.LONTANA:
			vicinanza = 0.0
			if automatica and p and is_instance_valid(p) and _vicino(p):
				_prossima -= delta
				if _prossima <= 0.0:
					_prossima = randf_range(intervallo.x, intervallo.y)
					chiama()
		Fase.ARRIVA:
			var dur := maxf(avviso - silenzio, 0.01)
			var k := clampf(_t / dur, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			_luce.global_position = _da.lerp(_sotto(_punto), e)
			_luce.light_energy = LUCE_SOTTO * clampf(k * 3.0, 0.0, 1.0)
			vicinanza = e * 0.9
			punto_luce = _luce.global_position
			if _t >= dur:
				vicinanza = 1.0
				_cambia(Fase.SILENZIO)
		Fase.SILENZIO:
			vicinanza = 1.0
			# la luce ferma, che pulsa piano
			_luce.light_energy = LUCE_SOTTO * (0.85 + 0.15 * sin(_t * 9.0))
			punto_luce = _luce.global_position
			if _t >= silenzio:
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
				_anima("incombe", 0.2)
				_lei.segui_con_la_testa(1.0, 0.5)
		Fase.SU:
			vicinanza = 1.0
			_aggiorna_viso()
			_girala_verso(p)
			var vicino := p != null and is_instance_valid(p) and _in_pianta(p.global_position, _punto.global_position) <= portata
			if letale and not _dimostrativa and vicino and _t >= tempo_presa:
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
			if _proprietaria == self:
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
	_luce.visible = false
	_proprietaria = null
	_cambia(Fase.LONTANA)


# --- Fuori dall'acqua --------------------------------------------------------------------------------------------

func _esci() -> void:
	if _dimostrativa:
		_dimostrate[str(get_path())] = true
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


func _prendi() -> void:
	_cambia(Fase.PRESA)
	_girala_verso(GameState.player)
	_lei.segui_con_la_testa(0.0, 0.1)
	_anima("presa", 0.15)
	_lei.attacca(0.7, &"")
	_lei.add_to_group(&"medusa_che_prende")
	presa.emit()
	GameState.kill_player(&"medusa")


## Torna sotto: respinta (il getto in faccia) o da sola (dopo averti cercato: sbatte nell'acqua).
func _scendi(da_respinta: bool) -> void:
	_respinta = da_respinta
	_lei.segui_con_la_testa(0.0, 0.15)
	var nome := "respinta" if da_respinta else "scende"
	_anima(nome, 0.15)
	var a := _ap().get_animation(StringName(ANIM + nome)) if _ap() else null
	_durata = _quando_radice(StringName(ANIM + nome), clampf(profondita, 0.05, 5.0), false) if a else 1.0
	# la luce si spegne con lei, negli ultimi 0,4 s
	var spegni := minf(0.4, _durata)
	var tw := create_tween()
	tw.tween_interval(_durata - spegni)
	tw.tween_property(_luce, "light_energy", 0.0, spegni)
	get_tree().create_timer(_durata * 0.6, false).timeout.connect(func():
		if fase == Fase.SCENDE and _proprietaria == self:
			Audio.suona(&"atterraggio_acqua", _lei.global_position + Vector3.UP * 3.0, 2.0, 0.6))
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


## Respinge lei adesso, come un getto lungo in faccia (per i test e per chi la ricaccia in altro modo).
func respingi() -> void:
	if fase == Fase.ESCE or fase == Fase.SU:
		_scendi(true)


# --- Lei condivisa ------------------------------------------------------------------------------------------------

## Lei (MedusaAffacciata con le animazioni dell'inseguimento), la luce rosa e il viso da colpire: creati una volta,
## nascosti, sotto la prima istanza che li chiede.
func _assicura_lei() -> void:
	if _lei and is_instance_valid(_lei):
		return
	_lei = MedusaAffacciata.new()
	_lei.name = "LeiNellAcqua"
	_lei.model = LeiOblo.MODELLO
	_lei.bell_material = LeiOblo.CAMPANA
	_lei.material_map = LeiOblo.MATERIALI.duplicate()
	_lei.animazioni_inseguimento = true
	_lei.animazione = &"inseguimento/incombe"
	_lei.visible = false
	add_child(_lei)
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


## Il viso da colpire segue l'occhio.
func _aggiorna_viso() -> void:
	var occhio := _lei.get_eye_position()
	if occhio != Vector3.ZERO and _viso:
		_viso.global_position = occhio


func _girala_verso(p: Node3D) -> void:
	if p == null or not is_instance_valid(p) or _lei == null:
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
