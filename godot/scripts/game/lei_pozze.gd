class_name LeiPozze
extends Node3D
## Lei sotto il pavimento della stanza delle pozze (0.4.0, «L'acqua è sua»; GDD, «Analisi del capitolo 1 e direzione
## nuova», 15 novembre). La stanza, i colori, il cartello e l'enigma restano quelli di EnigmaPozze: le pozze dello stesso
## colore sono collegate sotto il pavimento, e lì sotto nuota lei.
## Quello che si vede e si sente (la luce rosa, il canto che si spegne, il silenzio, l'uscita, la presa, la respinta col
## getto in faccia) e i suoi tempi sono del motore comune di mascotte, [AcquaDiLei] ([member acqua], figlio di questo
## nodo): qui c'è solo dove e quando.
## - Finché il giocatore non toglie il primo colore non succede niente (DORME). Dopo, la luce rosa passa di pozza in pozza
##   piena (GIRA, AcquaDiLei.percorri a tratti di [member passi_giro] pozze; il canto lo fa il motore dalla vicinanza) e
##   fra un'uscita e l'altra c'è una pausa fra [member pausa_min] e [member pausa_max]. Finita la pausa la luce va per
##   pozze piene fino a quella accanto alla pozza scelta, e da lì comincia l'avviso del motore (AcquaDiLei.chiama).
## - La prima uscita è dimostrativa ([member AcquaDiLei.prima_volta_dimostrativa]): lontano dal giocatore (almeno
##   [member distanza_dimostrativa], se si può dove lui guarda). Non prende.
## - Poi punta la pozza piena del bordo più vicina al giocatore (VIENE): l'avviso del motore, poi esce e prende chi è entro
##   [member portata] dal punto d'uscita.
## - Ci si salva in tre modi: allontanandosi lungo la passerella; col getto in faccia mentre esce o incombe (la respinta
##   del motore); svuotando quel colore: una pozza che si svuota è una porta che si chiude, e lei viene cacciata appena
##   comincia il gorgo (il gorgo dura più dell'avviso).
## - Se i tre colori sono sbagliati e le pozze si riempiono di nuovo, tutte le porte si riaprono.
## - Deve sempre esistere una via di salvezza: non la chiama se il giocatore non è sulla passerella della stanza, se è in
##   una pozza, se sta aspirando e la pozza non è nel suo campo visivo, o se lungo la passerella non c'è un punto fuori
##   portata raggiungibile durante l'avviso.
## - [member letale] (acceso): la presa uccide; spento, esce, incombe e torna sotto, solo paura.
## - Quando l'enigma è risolto se ne va (FINITA). Chi muore riparte dal checkpoint 14 d'ingresso con le pozze piene:
##   questo nodo riparte da DORME.
## Le coordinate sono quelle di EnigmaPozze (il padre): origine al centro della griglia, sul piano della passerella.

signal fase_cambiata(fase: StringName)
## Ha cominciato a svuotarsi il colore della pozza dove stava venendo: se n'è andata.
signal cacciata

enum Fase { DORME, GIRA, VIENE, FINITA }
const NOMI := [&"dorme", &"gira", &"viene", &"finita"]

## Interruttore della zona (0.4.0): acceso, la presa uccide; spento, solo paura (è [member AcquaDiLei.letale]).
@export var letale := true:
	set(v):
		letale = v
		if acqua:
			acqua.letale = v
## Col segnaposto INTERA: fin dove arriva la presa, in pianta dal punto d'uscita (m; è [member AcquaDiLei.portata]).
## Con la mano vale quella del motore, [member AcquaDiLei.portata_mano] (vedi [method portata_effettiva]).
@export var portata := 2.0:
	set(v):
		portata = v
		if acqua:
			acqua.portata = v

@export_group("Quando")
## Dopo il primo colore tolto, quanto gira la luce prima dell'uscita dimostrativa (s).
@export var prima_attesa := 5.0
## La pausa fra un'uscita e l'altra (s), a caso fra i due; parte quando lei è tornata sotto.
@export var pausa_min := 15.0
@export var pausa_max := 20.0
## Ogni quanto si riprova a chiamarla quando adesso non si può (s).
@export var riprova := 0.5
## La luce che gira di pozza in pozza (m/s), e quante pozze fa per volta.
@export var velocita_luce := 1.5
@export var passi_giro := 4
## La luce che va verso la pozza scelta, fino alla pozza accanto (m/s): da lì comincia l'avviso del motore.
@export var velocita_avvicinamento := 4.0

@export_group("Dove")
## Come esce (AcquaDiLei.modo). MANO (la scelta dell'utente: il braccio di fianco, la mano che sbatte sul grigliato e i
## tentacoli lungo la passerella): i punti d'uscita sono sul grigliato appena fuori dal bordo di ogni pozza del bordo,
## alla quota del grigliato, con +Z verso fuori (due per le pozze d'angolo: vale quello più vicino al giocatore).
## INTERA, il segnaposto finché la mano non c'è: lei esce dal centro della pozza, al pelo.
@export var modo := AcquaDiLei.Modo.MANO
## Con INTERA, quanto sotto il pelo parte la salita (m).
@export var profondita_uscita := 1.5
## La prima uscita, almeno così lontana dal giocatore (m).
@export var distanza_dimostrativa := 4.0
## Oltre questa distanza dalla pozza più vicina non la chiama (m): la luce gira e basta.
@export var distanza_attenzione := 6.0
## Mentre aspira, la pozza deve essere entro questo angolo da dove guarda (gradi).
@export var angolo_vista := 50.0
## Per la via di salvezza: a che velocità il giocatore si allontana camminando (m/s) e dopo quanto reagisce (s).
@export var velocita_fuga := 3.4
@export var reazione := 0.8
## Quanto oltre la portata deve poter arrivare (m).
@export var margine_fuga := 0.5

## Il motore di lei.
var acqua: AcquaDiLei
## Il punto d'uscita dove sta venendo (o null).
var uscita_scelta: Marker3D
var fase := Fase.DORME
## La pozza dove sta venendo (o null).
var bersaglio: WaterTank
## La pozza dove sta la luce.
var luce_in: WaterTank
## Quante uscite e come sono finite, per i test.
var uscite := 0
var prese := 0
var respinte := 0
var cacciate := 0

var _enigma: EnigmaPozze
var _t := 0.0
## Il punto d'uscita di ogni pozza del bordo.
var _uscite := {}
## La luce sta facendo un tratto (o se ne sta andando): si aspetta che finisca.
var _in_giro := false
## Le pozze del tratto che sta facendo.
var _giro: Array = []
var _t_riprova := 0.0
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
	_metti_motore()


## Il motore di lei con un punto d'uscita per ogni pozza del bordo.
func _metti_motore() -> void:
	acqua = AcquaDiLei.new()
	acqua.name = "AcquaDiLei"
	acqua.automatica = false
	acqua.prima_volta_dimostrativa = true
	acqua.letale = letale
	acqua.portata = portata
	acqua.modo = modo
	acqua.profondita = profondita_uscita
	add_child(acqua)
	# (il pelo dell'acqua piena: con la mano il punto d'uscita è sul grigliato, non sull'acqua)
	acqua.pelo = _enigma.to_global(Vector3(0.0, _enigma.profondita * (_enigma.pieno - 1.0), 0.0)).y
	var lista: Array[Node3D] = []
	for t in _enigma.pozze():
		if not _sul_bordo(t):
			continue
		var pose := _pose_uscita(t)
		var ms: Array[Marker3D] = []
		for k in pose.size():
			var m := Marker3D.new()
			m.name = "Uscita_" + String(t.name) + ("" if k == 0 else "_%d" % k)
			acqua.add_child(m)
			m.global_transform = pose[k]
			ms.append(m)
			lista.append(m)
		_uscite[t] = ms
	acqua.punti_uscita = lista
	acqua.fase_cambiata.connect(_su_fase_motore)
	acqua.uscita.connect(func(): uscite += 1)
	acqua.presa.connect(func(): prese += 1)
	acqua.respinta.connect(func(): respinte += 1)
	acqua.percorso_finito.connect(_su_percorso_finito)


## I punti d'uscita della pozza del bordo [param t], con +Z verso fuori. MANO: dove sbatte la mano, sul grigliato a filo
## del bordino esterno, uno per ogni lato sulla passerella, di fronte al centro della pozza. INTERA: il centro della
## pozza al pelo dell'acqua piena.
func _pose_uscita(t: WaterTank) -> Array[Transform3D]:
	var c := _locale(t.global_position)
	var lati: Array[Vector3] = []
	var m := _enigma.passo * 2.0 - 0.01
	if absf(c.x) >= m:
		lati.append(Vector3(signf(c.x), 0, 0))
	if absf(c.z) >= m:
		lati.append(Vector3(0, 0, signf(c.z)))
	var out: Array[Transform3D] = []
	if modo == AcquaDiLei.Modo.MANO:
		var bordo := _enigma.passo * 2.5 + 0.05   # (il bordino esterno: 2,75 più mezzo bordino)
		for l in lati:
			var q := Vector3(c.x, 0.0, c.z)
			if l.x != 0.0:
				q.x = l.x * bordo
			else:
				q.z = l.z * bordo
			out.append(_posa(q, l))
	else:
		var fuori := Vector3.ZERO
		for l in lati:
			fuori += l
		out.append(_posa(Vector3(c.x, _enigma.profondita * (_enigma.pieno - 1.0), c.z), fuori.normalized()))
	return out


## La posa in [param q] (coordinate dell'enigma) con +Z verso [param fuori].
func _posa(q: Vector3, fuori: Vector3) -> Transform3D:
	var z := (_enigma.global_basis * fuori).normalized()
	return Transform3D(Basis.looking_at(-z, Vector3.UP), _enigma.to_global(q))


## Il punto d'uscita della pozza [param t]: con due (pozza d'angolo con la mano), quello più vicino al giocatore.
func uscita_di(t: WaterTank) -> Marker3D:
	var ms: Array = _uscite.get(t, [])
	if ms.size() <= 1:
		return ms[0] if ms.size() == 1 else null
	var g := _giocatore()
	if g == null:
		return ms[0]
	var meglio: Marker3D = null
	var dm := INF
	for m: Marker3D in ms:
		var d := Vector2(m.global_position.x - g.global_position.x, m.global_position.z - g.global_position.z).length()
		if d < dm:
			dm = d
			meglio = m
	return meglio


## Tutti i punti d'uscita della pozza [param t].
func uscite_di(t: WaterTank) -> Array:
	return _uscite.get(t, [])


## Fin dove arriva la presa adesso, in pianta dal punto d'uscita (m): quella della mano o, col segnaposto, [member portata].
func portata_effettiva() -> float:
	if acqua == null:
		return portata
	return acqua.portata_mano if acqua.modo == AcquaDiLei.Modo.MANO else acqua.portata


## Il nome della fase adesso.
func nome_fase() -> StringName:
	return NOMI[fase]


func _vai(f: Fase) -> void:
	fase = f
	_t = 0.0
	fase_cambiata.emit(NOMI[f])


func _su_colore_tolto(_c: String) -> void:
	if fase == Fase.DORME and _enigma.stato == EnigmaPozze.Stato.APERTO:
		_sveglia()


func _sveglia() -> void:
	bersaglio = null
	luce_in = _pozza_a_caso(null)
	_in_giro = false
	_vai(Fase.GIRA)
	_t = -prima_attesa


## Lei è tornata sotto (o se n'è andata): la pausa, poi di nuovo.
func _riposa() -> void:
	bersaglio = null
	uscita_scelta = null
	_in_giro = false
	_vai(Fase.GIRA)
	_t = -_rng.randf_range(pausa_min, maxf(pausa_min, pausa_max))


func _su_colore_cominciato(c: String) -> void:
	# una pozza che si svuota è una porta che si chiude: se stava venendo lì, viene cacciata
	if fase == Fase.VIENE and bersaglio and String(bersaglio.fill_pigment) == c and _manda_via():
		cacciate += 1
		cacciata.emit()
	elif fase == Fase.GIRA and acqua.in_giro() and _giro.any(func(t): return String(t.fill_pigment) == c):
		# (la luce girava per quelle pozze: se ne va, e riprende da una pozza piena)
		_manda_via()


func _su_risolto() -> void:
	# (anche con la luce ferma fra un tratto e l'altro: il motore se la terrebbe, accesa, per sempre)
	if fase == Fase.VIENE or acqua.in_giro():
		_manda_via()
	bersaglio = null
	if acqua:
		acqua.abilitata = false
	if fase != Fase.FINITA:
		_vai(Fase.FINITA)


## Manda via lei: se non è ancora uscita (la luce che gira o l'avviso) la luce se ne va, se è fuori torna sotto. Falso
## se è troppo tardi (presa) o se ne sta già andando.
func _manda_via() -> bool:
	match acqua.fase:
		AcquaDiLei.Fase.ARRIVA, AcquaDiLei.Fase.SPEGNE, AcquaDiLei.Fase.SILENZIO:
			acqua.manda_via()
			# (la luce se ne va in un secondo: si riparte quando ha finito, a percorso_finito)
			_in_giro = true
			return true
		AcquaDiLei.Fase.LONTANA:
			if not acqua.in_giro():
				return false
			acqua.manda_via()
			_in_giro = true
			return true
		AcquaDiLei.Fase.ESCE, AcquaDiLei.Fase.SU:
			# (già fuori: torna sotto, come respinta)
			acqua.manda_via()
			return true
	return false


func _su_fase_motore(f: AcquaDiLei.Fase) -> void:
	if fase == Fase.VIENE and (f == AcquaDiLei.Fase.CALMA or f == AcquaDiLei.Fase.LONTANA):
		_riposa()
	elif fase == Fase.FINITA and (f == AcquaDiLei.Fase.CALMA or f == AcquaDiLei.Fase.LONTANA):
		# (risolto mentre era fuori: tornata sotto, se ne va del tutto, senza la luce che riprenderebbe a girare)
		acqua.lascia()


func _physics_process(delta: float) -> void:
	match fase:
		Fase.DORME:
			# ripreso da un salvataggio con un colore già tolto: si sveglia subito
			if _enigma.stato == EnigmaPozze.Stato.APERTO and not _enigma.tolti.is_empty():
				_sveglia()
		Fase.GIRA:
			_t += delta
			if _enigma.stato == EnigmaPozze.Stato.RISOLTO:
				return
			# la luce gira di tratto in tratto (il prossimo lo fa partire _su_percorso_finito); se adesso lei non può
			# venire (un'altra lei in vista, un bambino), si riprova ogni tanto
			_t_riprova -= delta
			if _in_giro and not acqua.in_giro() and acqua.fase == AcquaDiLei.Fase.LONTANA:
				# (il motore non sta facendo niente: il tratto è finito senza dirlo)
				_in_giro = false
			if not _in_giro and acqua.fase == AcquaDiLei.Fase.LONTANA and _t_riprova <= 0.0:
				_t_riprova = riprova
				_prossimo_tratto()
		Fase.VIENE:
			# (rete di sicurezza: il motore è tornato lontano senza dirlo)
			_t += delta
			if _t > 1.0 and acqua.fase == AcquaDiLei.Fase.LONTANA:
				_riposa()


## La pozza dove venire adesso (la prima volta quella dimostrativa), o null.
func _scegli() -> WaterTank:
	return _bersaglio_dimostrativo() if prossima_dimostrativa() else _bersaglio()


## Finito un tratto (o all'inizio): finita la pausa, se c'è una pozza dove venire la luce ci va per pozze piene fino a
## quella accanto e da lì comincia l'avviso; se no gira ancora.
func _prossimo_tratto() -> void:
	if _t >= 0.0:
		var b := _scegli()
		if b:
			if luce_in and _piena(luce_in) and (luce_in == b or luce_in in _vicine(b)):
				if _chiama(b):
					return
			else:
				var da: WaterTank = luce_in if luce_in and _piena(luce_in) else null
				var strada: Array = _strada(da, b) if da else []
				strada.pop_back()
				# (dalla pozza dove sta la luce, fino a quella accanto alla scelta)
				if not strada.is_empty() and (strada[0] in _vicine(da) or strada[0] == da):
					strada.push_front(da)
					if _percorri(strada, velocita_avvicinamento):
						return
	_percorri(_giro_a_caso(), velocita_luce)


func _su_percorso_finito() -> void:
	_in_giro = false
	if fase == Fase.GIRA:
		_prossimo_tratto()


## La luce fa il tratto [param pozze] (sotto il pelo, come la luce del motore; la prima è quella dove sta) e resta accesa
## all'ultima.
func _percorri(pozze: Array, v: float) -> bool:
	if pozze.size() < 2:
		return false
	var punti := PackedVector3Array()
	for t: WaterTank in pozze:
		punti.append(_sotto(t))
	if not acqua.percorri(punti, v, null, 0.0):
		return false
	_in_giro = true
	_giro = pozze
	luce_in = pozze.back()
	return true


## Il punto sotto la pozza [param t] dove passa la luce: 0,6 m sotto il pelo dell'acqua piena (come nel motore).
func _sotto(t: WaterTank) -> Vector3:
	var c := t.to_global(Vector3(0.0, t.inner_size.y * _enigma.pieno, 0.0))
	return c - Vector3(0.0, 0.6, 0.0)


## Un tratto a caso di pozze piene vicine, da dove sta la luce (o da una pozza piena a caso) e poi altre
## [member passi_giro].
func _giro_a_caso() -> Array:
	var out: Array = []
	var t := luce_in if luce_in and _piena(luce_in) else _pozza_a_caso(null)
	if t == null:
		return out
	out.append(t)
	var prima: WaterTank = null
	while out.size() < passi_giro + 1:
		var vicine := _vicine(t).filter(func(u): return _piena(u) and u != prima)
		if vicine.is_empty():
			vicine = _vicine(t).filter(func(u): return _piena(u))
		if vicine.is_empty():
			break
		prima = t
		t = vicine[_rng.randi() % vicine.size()]
		out.append(t)
	return out


## Chiama lei nella pozza [param t]: la luce è già nella pozza accanto (o in quella), e da lì comincia l'avviso.
func _chiama(t: WaterTank) -> bool:
	var m := uscita_di(t)
	if m == null:
		return false
	if not acqua.chiama(m):
		return false
	uscita_scelta = m
	bersaglio = t
	luce_in = t
	_vai(Fase.VIENE)
	return true


## Vero se la prossima uscita è quella dimostrativa (una volta per partita, la tiene il motore).
func prossima_dimostrativa() -> bool:
	return acqua != null and acqua.prossima_dimostrativa()


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


## Distanza in pianta del punto [param p] dal punto d'uscita della pozza [param t]: la misura della portata del motore.
func _distanza_punto(p: Vector3, t: WaterTank) -> float:
	var m := uscita_di(t)
	var c := m.global_position if m else t.global_position
	return Vector2(p.x - c.x, p.z - c.z).length()


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


## Vero se dal punto [param da], camminando lungo la passerella per il tempo dell'avviso del motore (meno la reazione),
## si arriva a un punto a più della portata ([method portata_effettiva]) + [member margine_fuga] dal punto d'uscita
## della pozza [param t].
func via_di_salvezza(da: Vector3, t: WaterTank) -> bool:
	var q := _locale(da)
	var r := _mezza() + 0.6   # la linea di mezzo della passerella
	var corsa := maxf(acqua.avviso - reazione, 0.0) * velocita_fuga
	var s0 := _anello_s(q, r)
	var perimetro := 8.0 * r
	# (dal punto di partenza alla linea di mezzo della passerella ci si arriva in linea retta: quel tratto si conta)
	var p0 := _anello_punto(s0, r)
	var d0 := Vector2(p0.x - q.x, p0.y - q.z).length()
	var k := 0.0
	while k + d0 <= corsa:
		for verso in [-1.0, 1.0]:
			var p := _anello_punto(fposmod(s0 + verso * k, perimetro), r)
			if _distanza_punto(_enigma.global_transform * Vector3(p.x, 0.0, p.y), t) > portata_effettiva() + margine_fuga:
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
