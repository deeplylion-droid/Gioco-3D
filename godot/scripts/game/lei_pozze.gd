class_name LeiPozze
extends Node3D
## Lei sotto il pavimento della stanza delle pozze (0.4.0, «L'acqua è sua»; GDD, «Analisi del capitolo 1 e direzione
## nuova», 15 novembre). La stanza, i colori, il cartello e l'enigma restano quelli di EnigmaPozze: le pozze dello stesso
## colore sono collegate sotto il pavimento, e lì sotto nuota lei.
## - Finché il giocatore non toglie il primo colore non succede niente ([constant Fase] DORME). Dopo, il canto sale da
##   sotto e la luce rosa passa di pozza in pozza (GIRA).
## - La prima uscita è dimostrativa: lontano dal giocatore (almeno [member distanza_dimostrativa], se si può dove lui
##   guarda), mano e tentacoli sbattono sul grigliato e tornano giù. Non prende.
## - Poi punta la pozza piena del bordo più vicina al giocatore: la luce ci arriva e resta lì [member avviso] secondi
##   (ARRIVA, poi SILENZIO: il canto si ferma), poi esce (ESCE) e al colpo prende chi è entro [member portata] dalla
##   pozza (PRESA).
## - Ci si salva in tre modi: allontanandosi lungo la passerella; col getto sulla pozza mentre lei sta per uscire o esce,
##   fino al colpo (RESPINTA); svuotando quel colore: una pozza che si svuota è una porta che si chiude, e se la luce è
##   lì viene cacciata (CACCIATA). Il gorgo dura più dell'avviso: per questo vale già quando comincia, non a pozza vuota.
## - Se i tre colori sono sbagliati e le pozze si riempiono di nuovo, tutte le porte si riaprono.
## - Fra un'uscita e l'altra una pausa fra [member pausa_min] e [member pausa_max]. Deve sempre esistere una via di
##   salvezza: non esce se il giocatore non è sulla passerella della stanza, se è in una pozza, se sta aspirando e la
##   pozza non è nel suo campo visivo, o se lungo la passerella non c'è un punto fuori portata raggiungibile in tempo.
## - [member letale] (acceso): la presa uccide; spento, lei esce, sbatte e torna giù, solo paura.
## - Quando l'enigma è risolto se ne va (FINITA). Chi muore riparte dal checkpoint 14 d'ingresso con le pozze piene:
##   questo nodo riparte da DORME.
## Quello che si vede e si sente (la luce rosa sott'acqua, il canto, mano e tentacoli) lo fa il motore di lei di
## mascotte ([member motore]); qui c'è solo dove e quando. Senza motore lei non c'è (non può prendere senza farsi vedere).
## Il motore riceve:
## - luce(posizione: Vector3): la luce rosa va sotto il pelo di una pozza (il centro del fondo);
## - fase(fase: StringName, pozza: WaterTank, dati: Dictionary): &"dorme", &"gira" (canto da sotto), &"arriva"
##   ({avviso}), &"silenzio", &"esce" ({dimostrativa, colpo, verso: dalla pozza verso il giocatore}), &"presa"
##   ({giocatore, letale}), &"respinta", &"cacciata", &"torna", &"finita".
## Le coordinate sono quelle di EnigmaPozze (il padre): origine al centro della griglia, sul piano della passerella.

signal fase_cambiata(fase: StringName, pozza: WaterTank)
signal presa(giocatore: Node3D)
signal respinta
signal cacciata

enum Fase { DORME, GIRA, ARRIVA, SILENZIO, ESCE, PRESA, RESPINTA, CACCIATA, TORNA, FINITA }
const NOMI := [&"dorme", &"gira", &"arriva", &"silenzio", &"esce", &"presa", &"respinta", &"cacciata", &"torna", &"finita"]

## Interruttore della zona (0.4.0): acceso, la presa uccide; spento, solo paura.
@export var letale := true
## Il motore di lei (mascotte): luce(), fase(). Senza, lei non c'è.
@export var motore: Node

@export_group("Tempi")
## Dopo il primo colore tolto, quanto gira (canto e luce) prima dell'uscita dimostrativa (s).
@export var prima_attesa := 5.0
## La pausa fra un'uscita e l'altra (s), a caso fra i due.
@export var pausa_min := 15.0
@export var pausa_max := 20.0
## Dall'arrivo della luce nella pozza all'uscita (s): l'avviso, compreso il silenzio.
@export var avviso := 3.0
## L'ultima parte dell'avviso, col canto fermo (s).
@export var silenzio := 0.6
## Dall'inizio dell'uscita al colpo sul grigliato (s): fino a lì il getto la respinge.
@export var colpo := 0.6
## Quanto resta fuori in tutto (s).
@export var durata_uscita := 1.4
## Quanto ci mette a tornare giù, respinta o no (s).
@export var ritorno := 1.2
## Ogni quanto la luce passa a un'altra pozza mentre gira (s).
@export var passo_luce := 0.8
## Quanto ci mette la luce da una pozza all'altra andando verso quella dell'uscita (s).
@export var viaggio_luce := 0.15
## Ogni quanto si riprova a scegliere la pozza quando adesso non si può (s).
@export var riprova := 0.5

@export_group("Distanze")
## Fin dove arriva la presa dal bordo della pozza (m).
@export var portata := 2.0
## Il getto la respinge se colpisce entro questa distanza dal centro della pozza (m, in pianta).
@export var raggio_getto := 1.0
## La prima uscita, almeno così lontana dal giocatore (m).
@export var distanza_dimostrativa := 4.0
## Oltre questa distanza dalla pozza più vicina non lo punta (m): gira e basta.
@export var distanza_attenzione := 6.0
## Mentre aspira, la pozza deve essere entro questo angolo da dove guarda (gradi).
@export var angolo_vista := 50.0
## Per la via di salvezza: a che velocità il giocatore si allontana camminando (m/s) e dopo quanto reagisce (s).
@export var velocita_fuga := 3.4
@export var reazione := 0.8
## Quanto oltre la portata deve poter arrivare (m).
@export var margine_fuga := 0.5

var fase := Fase.DORME
## La pozza dell'uscita (o null).
var bersaglio: WaterTank
## La pozza dove sta la luce.
var luce_in: WaterTank
var dimostrativa_fatta := false
## Quante uscite e come sono finite, per i test.
var uscite := 0
var prese := 0
var respinte := 0
var cacciate := 0

var _enigma: EnigmaPozze
var _t := 0.0
var _t_luce := 0.0
var _percorso: Array[WaterTank] = []
var _colpito := false
var _colpo_fatto := false
var _dimostrativa := false
var _zaino: WaterPack
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_enigma = get_parent() as EnigmaPozze
	if _enigma == null:
		set_physics_process(false)
		return
	_enigma.colore_tolto.connect(_su_colore_tolto)
	_enigma.colore_cominciato.connect(_su_colore_cominciato)
	_enigma.risolto.connect(_su_risolto)
	_rng.randomize()


## Il nome della fase adesso.
func nome_fase() -> StringName:
	return NOMI[fase]


func _vai(f: Fase, dati := {}) -> void:
	fase = f
	_t = 0.0
	if motore and motore.has_method(&"fase"):
		motore.call(&"fase", NOMI[f], bersaglio, dati)
	fase_cambiata.emit(NOMI[f], bersaglio)


func _su_colore_tolto(_c: String) -> void:
	if fase == Fase.DORME and motore and _enigma.stato == EnigmaPozze.Stato.APERTO:
		_sveglia()


func _sveglia() -> void:
	bersaglio = null
	_muovi_luce(_pozza_a_caso(null))
	_vai(Fase.GIRA)
	_t = -prima_attesa


func _su_colore_cominciato(c: String) -> void:
	# una pozza che si svuota è una porta che si chiude: se la luce è lì, viene cacciata
	if bersaglio and String(bersaglio.fill_pigment) == c and fase in [Fase.ARRIVA, Fase.SILENZIO, Fase.ESCE] \
			and not (fase == Fase.ESCE and _t >= colpo):
		_caccia()


func _su_risolto() -> void:
	if fase != Fase.FINITA and fase != Fase.DORME:
		bersaglio = null
		_vai(Fase.FINITA)
	fase = Fase.FINITA


func _caccia() -> void:
	cacciate += 1
	_vai(Fase.CACCIATA)
	cacciata.emit()


func _physics_process(delta: float) -> void:
	if fase == Fase.DORME:
		# ripreso da un salvataggio con un colore già tolto: si sveglia subito
		if motore and _enigma.stato == EnigmaPozze.Stato.APERTO and not _enigma.tolti.is_empty():
			_sveglia()
		return
	if fase == Fase.FINITA:
		return
	_collega_zaino()
	_t += delta
	match fase:
		Fase.GIRA:
			_gira(delta)
		Fase.ARRIVA:
			_avanza_luce(delta)
			if _t >= avviso - silenzio:
				_vai(Fase.SILENZIO)
		Fase.SILENZIO:
			if _t >= silenzio:
				_esci()
		Fase.ESCE:
			if _t >= colpo and not _colpo_fatto:
				_colpo_fatto = true
				_al_colpo()
			if fase == Fase.ESCE and _t >= durata_uscita:
				_vai(Fase.TORNA)
		Fase.RESPINTA, Fase.CACCIATA, Fase.TORNA:
			if _t >= ritorno:
				bersaglio = null
				_vai(Fase.GIRA)
				_t = -_rng.randf_range(pausa_min, maxf(pausa_min, pausa_max))
		Fase.PRESA:
			# (con letale la sala si ricarica e questo nodo con lei; se no, o se la morte non c'è stata, riprende)
			if _t >= durata_uscita + ritorno and not GameState.is_dying:
				bersaglio = null
				_vai(Fase.GIRA)
				_t = -_rng.randf_range(pausa_min, maxf(pausa_min, pausa_max))


# --- Gira: la luce passa di pozza in pozza; finita la pausa sceglie dove uscire ------------------------------------

func _gira(delta: float) -> void:
	_t_luce += delta
	if luce_in == null or not _piena(luce_in) or _t_luce >= passo_luce:
		_t_luce = 0.0
		_muovi_luce(_pozza_vicina_a_caso(luce_in))
	if _t < 0.0 or _enigma.stato == EnigmaPozze.Stato.RISOLTO:
		return
	var b := _bersaglio_dimostrativo() if not dimostrativa_fatta else _bersaglio()
	if b == null:
		_t = -riprova
		return
	bersaglio = b
	_dimostrativa = not dimostrativa_fatta
	_percorso = _strada(luce_in, b)
	_t_luce = 0.0
	_colpito = false
	_vai(Fase.ARRIVA, {"avviso": avviso})


func _avanza_luce(delta: float) -> void:
	if _percorso.is_empty():
		return
	_t_luce += delta
	if _t_luce >= viaggio_luce:
		_t_luce = 0.0
		_muovi_luce(_percorso.pop_front())


func _muovi_luce(t: WaterTank) -> void:
	if t == null:
		return
	luce_in = t
	if motore and motore.has_method(&"luce"):
		motore.call(&"luce", t.global_position + Vector3(0, 0.05, 0))


func _esci() -> void:
	# (se la luce era ancora per strada, ora è nella pozza)
	if not _percorso.is_empty():
		_muovi_luce(_percorso.back())
		_percorso.clear()
	uscite += 1
	var verso := Vector3.ZERO
	var g := _giocatore()
	if g:
		verso = g.global_position - bersaglio.global_position
		verso.y = 0.0
		verso = verso.normalized()
	_colpo_fatto = false
	_vai(Fase.ESCE, {"dimostrativa": _dimostrativa, "colpo": colpo, "verso": verso})
	if _dimostrativa:
		dimostrativa_fatta = true


func _al_colpo() -> void:
	if _colpito:
		respinte += 1
		_vai(Fase.RESPINTA)
		respinta.emit()
		return
	if _dimostrativa:
		return
	var g := _giocatore()
	if g == null or GameState.is_dying or not _in_stanza(g) or _distanza(g, bersaglio) > portata:
		return
	prese += 1
	_vai(Fase.PRESA, {"giocatore": g, "letale": letale})
	presa.emit(g)
	if letale:
		GameState.kill_player(&"lei_pozze")


# --- Il getto ------------------------------------------------------------------------------------------------------

func _collega_zaino() -> void:
	var g := _giocatore()
	var z: WaterPack = g.water_pack if g else null
	if z == _zaino:
		return
	if _zaino and is_instance_valid(_zaino) and _zaino.jet_hit.is_connected(_su_getto):
		_zaino.jet_hit.disconnect(_su_getto)
	_zaino = z
	if _zaino:
		_zaino.jet_hit.connect(_su_getto)


func _su_getto(_collider: Object, punto: Vector3, _normale: Vector3) -> void:
	if bersaglio == null or not (fase == Fase.SILENZIO or (fase == Fase.ESCE and _t < colpo)):
		return
	var c := bersaglio.global_position
	var d := Vector2(punto.x - c.x, punto.z - c.z).length()
	var su := punto.y - (bersaglio.global_position.y + bersaglio.inner_size.y * bersaglio.fill)
	# (il getto può andare fino al fondo della pozza: conta tutto, dal fondo a 2,5 m sopra il pelo)
	if d <= raggio_getto and su > -(bersaglio.inner_size.y + 0.3) and su < 2.5:
		_colpito = true


## Il getto ha colpito la pozza dell'uscita adesso (per i test e per il motore, se la colpisce lui).
func colpisci() -> void:
	if bersaglio and (fase == Fase.SILENZIO or (fase == Fase.ESCE and _t < colpo)):
		_colpito = true


# --- Dove uscire ---------------------------------------------------------------------------------------------------

func _giocatore() -> Player:
	var g := GameState.player
	return g if g and is_instance_valid(g) and g.is_inside_tree() else null


func _locale(p: Vector3) -> Vector3:
	return _enigma.global_transform.affine_inverse() * p


## Mezzo lato della griglia delle pozze (dal centro al bordo esterno dei bordini, m).
func _mezza() -> float:
	return _enigma.passo * 2.5


func _in_stanza(g: Node3D) -> bool:
	var q := _locale(g.global_position)
	var fuori := _mezza() + 1.6
	return absf(q.x) <= fuori and absf(q.z) <= fuori and q.y > -0.2 and q.y < 2.5


func _in_acqua(g: Node3D) -> bool:
	var q := _locale(g.global_position)
	var m := _mezza()
	return absf(q.x) < m and absf(q.z) < m and q.y < -0.05


## Distanza in pianta del punto [param p] dal quadrato della pozza [param t] (bordino compreso).
func _distanza_punto(p: Vector3, t: WaterTank) -> float:
	var q := _locale(p)
	var c := _locale(t.global_position)
	var h := _enigma.passo * 0.5
	var dx := maxf(absf(q.x - c.x) - h, 0.0)
	var dz := maxf(absf(q.z - c.z) - h, 0.0)
	return Vector2(dx, dz).length()


func _distanza(g: Node3D, t: WaterTank) -> float:
	return _distanza_punto(g.global_position, t)


func _piena(t: WaterTank) -> bool:
	var c := String(t.fill_pigment)
	return not (c in _enigma.tolti or c in _enigma.svuotando) and t.fill >= _enigma.pieno - 0.05


func _sul_bordo(t: WaterTank) -> bool:
	var q := _locale(t.global_position)
	var m := _enigma.passo * 2.0 - 0.01
	return absf(q.x) >= m or absf(q.z) >= m


func _pozze_buone() -> Array[WaterTank]:
	var out: Array[WaterTank] = []
	for t in _enigma.pozze():
		if _sul_bordo(t) and _piena(t):
			out.append(t)
	return out


## Vero se il giocatore guarda la pozza [param t] (entro [member angolo_vista]).
func _la_vede(g: Player, t: WaterTank) -> bool:
	var cam := g.camera
	if cam == null:
		return true
	var avanti := -cam.global_transform.basis.z
	var verso := t.global_position + Vector3(0, t.inner_size.y, 0) - cam.global_position
	if verso.length() < 0.01:
		return true
	return rad_to_deg(avanti.angle_to(verso.normalized())) <= angolo_vista


## Il giocatore adesso si può puntare: è sulla passerella della stanza, fuori dalle pozze, vivo e libero di muoversi.
func _puntabile(g: Player) -> bool:
	return g != null and g.input_enabled and not GameState.is_dying and _in_stanza(g) and not _in_acqua(g)


## La pozza piena del bordo più vicina al giocatore, se adesso c'è una via di salvezza; se no null (si riprova dopo).
func _bersaglio() -> WaterTank:
	var g := _giocatore()
	if not _puntabile(g):
		return null
	var migliore: WaterTank
	var d_min := INF
	for t in _pozze_buone():
		var d := _distanza(g, t)
		if d < d_min:
			d_min = d
			migliore = t
	if migliore == null or d_min > distanza_attenzione:
		return null
	# fermo ad aspirare, deve poter vedere la luce
	if g.water_pack and g.water_pack.is_sucking and not _la_vede(g, migliore):
		return null
	if not via_di_salvezza(g.global_position, migliore):
		return null
	return migliore


## La prima uscita: una pozza piena del bordo lontana dal giocatore, se si può dove guarda (la più lontana fra quelle
## che vede, se no la più lontana). Il giocatore deve essere nella stanza, a vederla.
func _bersaglio_dimostrativo() -> WaterTank:
	var g := _giocatore()
	if not _puntabile(g):
		return null
	var vista: WaterTank
	var d_vista := -1.0
	var lontana: WaterTank
	var d_lontana := -1.0
	for t in _pozze_buone():
		var d := _distanza(g, t)
		if d < distanza_dimostrativa:
			continue
		if d > d_lontana:
			d_lontana = d
			lontana = t
		if _la_vede(g, t) and d > d_vista:
			d_vista = d
			vista = t
	return vista if vista else lontana


## Vero se dal punto [param da], camminando lungo la passerella per il tempo dell'avviso (meno la reazione), si arriva
## a un punto a più di [member portata] + [member margine_fuga] dalla pozza [param t].
func via_di_salvezza(da: Vector3, t: WaterTank) -> bool:
	var q := _locale(da)
	var r := _mezza() + 0.6   # la linea di mezzo della passerella
	var corsa := maxf(avviso - reazione, 0.0) * velocita_fuga
	var s0 := _anello_s(q, r)
	var perimetro := 8.0 * r
	# (dal punto di partenza alla linea di mezzo della passerella ci si arriva in linea retta: quel tratto si conta)
	var p0 := _anello_punto(s0, r)
	var d0 := Vector2(p0.x - q.x, p0.y - q.z).length()
	var k := 0.0
	while k + d0 <= corsa:
		for verso in [-1.0, 1.0]:
			var p := _anello_punto(fposmod(s0 + verso * k, perimetro), r)
			if _distanza_punto(_enigma.global_transform * Vector3(p.x, 0.0, p.y), t) > portata + margine_fuga:
				return true
		k += 0.25
	return false


## Il punto dell'anello (quadrato di mezzo lato [param r], percorso in senso orario da (-r, -r)) alla lunghezza [param s].
static func _anello_punto(s: float, r: float) -> Vector2:
	var l := 2.0 * r
	if s < l:
		return Vector2(-r + s, -r)
	if s < 2.0 * l:
		return Vector2(r, -r + (s - l))
	if s < 3.0 * l:
		return Vector2(r - (s - 2.0 * l), r)
	return Vector2(-r, r - (s - 3.0 * l))


## La lunghezza lungo l'anello del punto dell'anello più vicino a [param q] (in coordinate dell'enigma).
static func _anello_s(q: Vector3, r: float) -> float:
	var x := clampf(q.x, -r, r)
	var z := clampf(q.z, -r, r)
	# il lato più vicino
	var dn := absf(q.z + r)
	var de := absf(q.x - r)
	var ds := absf(q.z - r)
	var dw := absf(q.x + r)
	var m := minf(minf(dn, de), minf(ds, dw))
	var l := 2.0 * r
	if m == dn:
		return x + r
	if m == de:
		return l + z + r
	if m == ds:
		return 2.0 * l + (r - x)
	return 3.0 * l + (r - z)


# --- La luce sotto le pozze ----------------------------------------------------------------------------------------

func _vicine(t: WaterTank) -> Array[WaterTank]:
	var out: Array[WaterTank] = []
	if t == null:
		return out
	var c := _locale(t.global_position)
	for u in _enigma.pozze():
		if u == t:
			continue
		var d := _locale(u.global_position) - c
		if absf(d.x) <= _enigma.passo * 1.01 and absf(d.z) <= _enigma.passo * 1.01:
			out.append(u)
	return out


func _pozza_a_caso(lontana_da: WaterTank) -> WaterTank:
	var piene: Array[WaterTank] = []
	for t in _enigma.pozze():
		if _piena(t) and t != lontana_da:
			piene.append(t)
	return piene[_rng.randi() % piene.size()] if not piene.is_empty() else null


func _pozza_vicina_a_caso(da: WaterTank) -> WaterTank:
	var piene: Array[WaterTank] = []
	for t in _vicine(da):
		if _piena(t):
			piene.append(t)
	if piene.is_empty():
		return _pozza_a_caso(da)
	return piene[_rng.randi() % piene.size()]


## La strada della luce da [param da] ad [param a] passando per pozze piene (la più corta), senza [param da].
func _strada(da: WaterTank, a: WaterTank) -> Array[WaterTank]:
	var out: Array[WaterTank] = []
	if da == null or da == a:
		out.append(a)
		return out
	var prima := {da: null}
	var coda: Array[WaterTank] = [da]
	while not coda.is_empty():
		var t: WaterTank = coda.pop_front()
		if t == a:
			break
		for u in _vicine(t):
			if not prima.has(u) and (_piena(u) or u == a):
				prima[u] = t
				coda.append(u)
	if not prima.has(a):
		# chiusa dalle pozze vuote: va giù e risale lì
		out.append(a)
		return out
	var t: WaterTank = a
	while t != da:
		out.push_front(t)
		t = prima[t]
	return out
