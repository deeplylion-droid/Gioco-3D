class_name LeiSalaAlBuio
extends Node3D
## La sala al buio della build 0.4.0 («L'acqua è sua», GDD del 15 novembre): dopo il blackout, mentre il giocatore
## attraversa la sala, la luce rosa di lei gira sott'acqua nella vasca grande (VascaArrivo) e nelle vasche dei bimbi
## che si riempiono. Se il giocatore è sul bordo della vasca grande quando la luce passa lì, lei sale come nelle
## condotte (AcquaDiLei, uscita intera) e, se lui resta nella portata, lo prende ([member letale]). Quando il
## giocatore arriva vicino all'area bimbi il giro finisce: la luce va nella fossa e da lì la scena di oggi
## (LeiSbuca: affacciata, il getto, il tuffo, la luce che si allontana) non cambia.
## Le vasche dei bimbi sono basse (43 cm): lì passa solo la luce, lei esce solo dalla vasca grande.
## I punti d'uscita e il giro si calcolano dalle vasche (WaterTank) quando parte il giro: il livello dell'acqua cambia.

@export var abilitata := true
## Se spento lei esce, incombe e torna sotto, ma non prende mai («solo paura»).
@export var letale := true
## La vasca grande: lì gira la luce e da lì esce lei.
@export var vasca_grande: WaterTank
## Le vasche dei bimbi che si riempiono: lì gira solo la luce.
@export var vasche_bimbi: Array[WaterTank] = []
## La scena della fossa (tappa 8): si affaccia quando il giro finisce.
@export var lei_sbuca: LeiSbuca
## Il giocatore più vicino di così alla fossa (in pianta): il giro finisce e lei va alla fossa, se lui non è sul bordo
## della vasca grande vicino a un punto d'uscita (lì può ancora uscire). 13 m (collaudo della 0.4.0, scelta A del
## coordinatore): è quando lascia la vasca grande verso la fossa (il centro della vasca è a 9,8 m dalla fossa, i suoi
## punti d'uscita fra 7 e 12 m). Poi l'avviso intero (la luce sotto la fossa, il canto che arriva e si spegne, il
## silenzio: 3,5 s) e lei viene alla fossa senza sorprendere (LeiSbuca._prova_a_venire).
@export var distanza_fossa := 13.0
## Lontano dal bordo della vasca grande (più lontano di così da ogni punto d'uscita, in pianta: la portata di lei, 3 m,
## più un margine) il passaggio alla fossa parte già a [member distanza_fossa_lontano] m: dopo l'avviso intero lei sbuca
## in vista col giocatore che cammina ancora a 8-9 m, la scena della 0.3.25 (scelta del coordinatore, «A in più»). Vicino
## al bordo resta il giro (le uscite dalla vasca) e il passaggio parte a [member distanza_fossa].
@export var lontano_dal_bordo := 5.0
@export var distanza_fossa_lontano := 21.0
## (non più usato: dalla 0.4.0 collaudata la luce va alla fossa con l'avviso intero, AcquaDiLei.annuncia)
@export var tempo_alla_fossa := 1.5
## Il giocatore più vicino di così (in pianta) al punto d'uscita sopra cui passa la luce: è sul bordo, lei sale.
@export var distanza_bordo := 3.0
## La luce passa sopra un punto d'uscita se è più vicina di così (m, in pianta).
@export var raggio_luce := 1.8
## Quanto dentro la vasca grande stanno i punti d'uscita, dal bordo (m): lei sta in acqua e non tocca il muro.
## (2,4 m: più vicino al bordo i suoi tentacoli entrano nelle griglie dei bordi e nel pavimento; da 2,4 m la presa,
## 2,4 m davanti a lei, arriva al giocatore sul bordo; sonda_ingombro_acqua_di_lei.gd)
@export var rientro := 2.4
## Quando arriva la luce, i giocattoli che galleggiano nella vasca grande si scostano dal punto d'uscita fino a
## tanto (m, in pianta): così lei uscendo non li attraversa.
@export var spazio_galleggianti := 3.6
## Velocità della luce nel giro (m/s).
@export var velocita := 1.8
## La sala al buio, nel mondo: il giro parte solo col giocatore qui dentro (dall'uscita della serranda, z 19,3, in
## poi; al piano della sala, non nella sala pompe o nel pozzo sotto) e, se ne esce prima della fossa, finisce e lei
## torna libera. Dal blackout (la leva della sala pompe) alla serranda passano raccordo, fiume, pozze e infermeria:
## lì lei deve poter venire.
@export var zona := AABB(Vector3(-32.0, -3.0, -32.0), Vector3(64.0, 7.0, 51.0))

@export_group("Fischio")
## (build 0.5.0, l'agnellino che la chiama) Una volta per attraversamento della sala, dal buio, lontano dal giocatore, un
## fischio corto (Audio &"fischietto"); poi la luce rosa va alla vasca vicina al giocatore (il punto d'uscita più vicino) con
## l'avviso intero e lei esce come sempre. Mai durante un'uscita già in corso, mai dopo la fossa.
@export var fischio := true
## Il fischio arriva solo dopo tanti secondi di giro (s)...
@export var fischio_dopo := 1.5
## ...col giocatore più lontano di [member distanza_bordo] e più vicino di così (m, in pianta) al punto d'uscita più vicino.
@export var fischio_entro := 14.0
## Da quanto lontano dal giocatore (m, in pianta), dalla parte opposta alla vasca grande.
@export var fischio_lontano := 13.0
## Dal fischio a quando la luce parte verso il giocatore (s).
@export var fischio_luce := 0.7
@export_group("")

## Il fischio dal buio (per l'audio e i test): [param dove] nel mondo.
signal fischiato(dove: Vector3)

enum Stato { ATTESA, GIRO, FINITO }
var stato := Stato.ATTESA
## Il fischio c'è già stato in questo attraversamento (si azzera quando il giocatore esce dalla sala).
var fischio_fatto := false
var _t_giro := 0.0
var _t_fischio := -1.0
## Da quanto (s) la sala è caricata e pronta: nei primi istanti lo schermo è ancora nero.
var _appena_caricata := 0.0
var acqua: AcquaDiLei
var _punti: Array[Node3D] = []
## Quando è partito l'avviso della fossa (ms, Time.get_ticks_msec; -1: mai): per i test.
var avviso_fossa_da := -1


func _ready() -> void:
	if not abilitata or vasca_grande == null:
		return
	acqua = AcquaDiLei.new()
	acqua.name = "AcquaDiLei"
	acqua.letale = letale
	add_child(acqua)
	# un punto d'uscita a metà di ogni lato della vasca grande, sul fondo (la posa vuole il pelo 0,88 m sopra)
	var mezzo := vasca_grande.inner_size * 0.5
	for d in [Vector3(mezzo.x - rientro, 0, 0), Vector3(-mezzo.x + rientro, 0, 0), Vector3(0, 0, mezzo.z - rientro), Vector3(0, 0, -mezzo.z + rientro)]:
		var m := Marker3D.new()
		m.name = "Uscita%d" % _punti.size()
		acqua.add_child(m)
		m.global_position = vasca_grande.to_global(d)
		_punti.append(m)
	acqua.punti_uscita = _punti
	acqua.profondita = 5.0
	acqua.pelo = vasca_grande.get_surface_global_y()
	# (la luce passa solo nell'acqua vera: fra una vasca e l'altra è spenta)
	var volumi: Array[Node3D] = [vasca_grande]
	for v in vasche_bimbi:
		if v:
			volumi.append(v)
	acqua.acque = volumi
	acqua.arriva.connect(func(_dove: Vector3): prepara_uscita(acqua.get(&"_punto"), 1.6))
	# la fossa aspetta il giro (anche se la sala si carica prima del blackout: ripartendo da più avanti o con le luci
	# del lampo lei non deve affacciarsi alla fossa da sola, al blackout, lontano dal giocatore)
	if lei_sbuca:
		lei_sbuca.aspetta_il_giro = true


func _physics_process(_delta: float) -> void:
	# (il tempo dal caricamento della sala, contato da quando il livello è pronto: nei primi istanti lo schermo è nero)
	if not GameState.is_restoring():
		_appena_caricata += _delta
	# (mentre il livello si ripristina il giocatore nuovo non è ancora al checkpoint: niente decisioni sulla sua posizione)
	if acqua == null or GameState.luci != GameState.Luci.BLACKOUT or GameState.is_dying or GameState.is_restoring():
		return
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	acqua.letale = letale
	if stato != Stato.FINITO:
		acqua.pelo = vasca_grande.get_surface_global_y()
	var d_fossa := AcquaDiLei._in_pianta(p.global_position, lei_sbuca.punto_sbuca.global_position) \
			if lei_sbuca != null and lei_sbuca.punto_sbuca != null else INF
	var vicino_fossa := d_fossa <= distanza_fossa or (d_fossa <= distanza_fossa_lontano and _lontano_dal_bordo(p))
	_aggiorna_luce_fossa(_delta)
	var in_sala := zona.has_point(p.global_position)
	match stato:
		Stato.ATTESA:
			# la fossa c'è già stata (ripartendo da un checkpoint dopo, o con Continua): lei se n'è andata, niente giro
			if lei_sbuca and (lei_sbuca.fase == LeiSbuca.Fase.FUGA or lei_sbuca.fase == LeiSbuca.Fase.FINITA):
				stato = Stato.FINITO
				acqua.lascia()
				acqua.abilitata = false
				return
			if not in_sala:
				return
			if vicino_fossa:
				# ripartendo vicino alla fossa: appena caricata la sala (lo schermo è ancora nero) lei è già affacciata, come
				# quando la scena ricomincia dopo una presa; se no (arrivati lì senza giro) l'avviso e poi la fossa
				if _appena_caricata < 0.5 and lei_sbuca and lei_sbuca.affaccia_alla_ripartenza():
					stato = Stato.FINITO
					acqua.lascia()
					acqua.abilitata = false
				else:
					_finisci(false)
			elif acqua.gira(_giro(), velocita):
				stato = Stato.GIRO
				_t_giro = 0.0
		Stato.GIRO:
			if not in_sala:
				# uscito dalla sala prima della fossa: lei se ne va, il giro ripartirà quando torna
				if acqua.fase == AcquaDiLei.Fase.LONTANA or acqua.fase == AcquaDiLei.Fase.CALMA:
					acqua.lascia()
					stato = Stato.ATTESA
					fischio_fatto = false
					_t_fischio = -1.0
				return
			# (non mentre il fischio sta chiamando la luce verso il giocatore)
			if vicino_fossa and acqua.fase == AcquaDiLei.Fase.LONTANA and not _sul_bordo(p) and _t_fischio < 0.0:
				_finisci(true)
				return
			if acqua.fase != AcquaDiLei.Fase.LONTANA:
				_t_fischio = -1.0
				return
			_t_giro += _delta
			if _fischio(p, _delta):
				return
			var q := acqua.punto_vicino_alla_luce(raggio_luce)
			if q and AcquaDiLei._in_pianta(p.global_position, q.global_position) <= distanza_bordo:
				acqua.chiama(q)
		Stato.FINITO:
			# l'avviso della fossa interrotto (il giocatore uscito dalla zona, o lei non poteva venire): si riprova, così
			# lei non arriva mai alla fossa senza l'avviso
			if lei_sbuca and lei_sbuca.aspetta_il_giro and acqua.abilitata and acqua.fase == AcquaDiLei.Fase.LONTANA \
					and in_sala:
				_annuncia_la_fossa()


func _finisci(_con_la_luce: bool) -> void:
	stato = Stato.FINITO
	if lei_sbuca == null or lei_sbuca.punto_sbuca == null:
		acqua.lascia()
		acqua.abilitata = false
		return
	# l'avviso intero (collaudo della 0.4.0), anche ripartendo vicino alla fossa: la luce lascia le vasche e va sotto la
	# fossa (accesa solo nell'acqua), il canto fa «arriva» e si spegne, mezzo secondo di silenzio
	# ([member AcquaDiLei.avviso], 3,5 s), poi lei viene alla fossa: sbuca se si può senza sorprendere, se no aspetta
	# (LeiSbuca._prova_a_venire). Se adesso lei non può essere qui, si riprova a ogni fotogramma (Stato.FINITO): alla
	# fossa non arriva mai senza l'avviso.
	if acqua.fase != AcquaDiLei.Fase.LONTANA:
		acqua.lascia()
	_annuncia_la_fossa()


## Il fischio dal buio: una volta per attraversamento, poi la luce va al punto d'uscita più vicino al giocatore. Vero mentre
## è in corso (il giro non chiama altre uscite).
func _fischio(p: Node3D, delta: float) -> bool:
	if _t_fischio >= 0.0:
		_t_fischio += delta
		if _t_fischio >= fischio_luce:
			_t_fischio = -1.0
			var q := _uscita_vicina(p)
			if q:
				acqua.chiama(q)
		return true
	if not fischio or fischio_fatto or _t_giro < fischio_dopo:
		return false
	var q := _uscita_vicina(p)
	if q == null:
		return false
	var d := AcquaDiLei._in_pianta(p.global_position, q.global_position)
	if d <= distanza_bordo or d > fischio_entro:
		return false
	fischio_fatto = true
	_t_fischio = 0.0
	# il più possibile dalla parte opposta alla vasca grande, a [member fischio_lontano] m, dentro la sala
	var via := p.global_position - vasca_grande.global_position
	via.y = 0.0
	via = via.normalized() if via.length() > 0.1 else Vector3.FORWARD
	var dove := Vector3.INF
	var meglio := -INF
	for k in 16:
		var dir := via.rotated(Vector3.UP, TAU * k / 16.0)
		var c := p.global_position + dir * fischio_lontano
		if c.x < zona.position.x + 1.0 or c.x > zona.end.x - 1.0 or c.z < zona.position.z + 1.0 or c.z > zona.end.z - 1.0:
			continue
		if dir.dot(via) > meglio:
			meglio = dir.dot(via)
			dove = c
	if dove == Vector3.INF:
		dove = p.global_position + via * fischio_lontano
	dove.y = p.global_position.y + 1.0
	var audio := get_node_or_null(^"/root/Audio")
	if audio:
		audio.call(&"suona", &"fischietto", dove)
	fischiato.emit(dove)
	return true


func _uscita_vicina(p: Node3D) -> Node3D:
	var meglio: Node3D = null
	var d_meglio := INF
	for q in _punti:
		var d := AcquaDiLei._in_pianta(p.global_position, q.global_position)
		if d < d_meglio:
			d_meglio = d
			meglio = q
	return meglio


## L'avviso della fossa: la luce va sotto la fossa, il canto arriva e si spegne, il silenzio; poi lei viene alla fossa
## (LeiSbuca.vai_alla_fossa). Falso se adesso lei non può essere qui.
func _annuncia_la_fossa() -> bool:
	var m := acqua.get_node_or_null(^"SottoLaFossa") as Marker3D
	if m == null:
		m = Marker3D.new()
		m.name = "SottoLaFossa"
		acqua.add_child(m)
	# (al centro della fossa, davanti al bordo dove si affaccia: dove fa lo schizzo quando sbuca)
	m.global_position = lei_sbuca.punto_sbuca.global_transform * Vector3(0.0, 0.0, 1.4)
	var pelo := lei_sbuca.pelo_fossa()
	acqua.pelo = pelo
	# la fossa è acqua anche se non è una vasca: lì la luce è accesa
	acqua.acque_extra = [AABB(Vector3(m.global_position.x - 1.2, pelo - lei_sbuca.profondita, m.global_position.z - 1.2),
			Vector3(2.4, lei_sbuca.profondita - 0.05, 2.4))]
	avviso_fossa_da = Time.get_ticks_msec()
	return acqua.annuncia(m, func():
			acqua.abilitata = false
			if is_instance_valid(lei_sbuca):
				lei_sbuca.vai_alla_fossa())


## Vero se il giocatore è lontano dalla vasca grande: oltre [member lontano_dal_bordo] m da tutti i punti d'uscita e fuori
## dalla sua fascia (la striscia larga quanto la vasca più [member lontano_dal_bordo] m per parte, per tutta la sala lungo
## la vasca): chi arriva dalla serranda, che è dritta davanti alla vasca, ci va incontro e resta nel giro, con le uscite
## dal bordo (riscontro del coordinatore: le uscite dalla vasca contano più della sbucata alla fossa).
func _lontano_dal_bordo(p: Node3D) -> bool:
	var l := vasca_grande.to_local(p.global_position)
	if absf(l.x) <= vasca_grande.inner_size.x * 0.5 + lontano_dal_bordo:
		return false
	for q in _punti:
		if AcquaDiLei._in_pianta(p.global_position, q.global_position) <= lontano_dal_bordo:
			return false
	return true


## La luce rosa che resta nella fossa e pulsa, in silenzio, mentre lei aspetta di poter venire senza sorprendere (dopo
## l'avviso: scelta B del coordinatore). Si spegne quando sbuca o si affaccia.
var _luce_fossa: OmniLight3D
var _t_luce := 0.0


func _aggiorna_luce_fossa(delta: float) -> void:
	var accesa := lei_sbuca != null and lei_sbuca.sta_aspettando() and not lei_sbuca.aspetta_il_giro
	if not accesa and _luce_fossa == null:
		return
	if _luce_fossa == null:
		_luce_fossa = OmniLight3D.new()
		_luce_fossa.name = "LuceFossa"
		_luce_fossa.light_color = AcquaDiLei.ROSA
		_luce_fossa.omni_range = AcquaDiLei.LUCE_SOTTO_PORTATA
		_luce_fossa.shadow_enabled = false
		_luce_fossa.light_energy = 0.0
		add_child(_luce_fossa)
		var c := lei_sbuca.punto_sbuca.global_transform * Vector3(0.0, 0.0, 1.4)
		_luce_fossa.global_position = Vector3(c.x, lei_sbuca.pelo_fossa() - 0.6, c.z)
	_t_luce += delta
	var voluta := AcquaDiLei.LUCE_SOTTO * (0.85 + 0.15 * sin(_t_luce * 9.0)) if accesa else 0.0
	# (si accende subito, al posto della luce dell'avviso; si spegne in 0,4 s)
	_luce_fossa.light_energy = voluta if accesa else move_toward(_luce_fossa.light_energy, 0.0, AcquaDiLei.LUCE_SOTTO * delta / 0.4)
	_luce_fossa.visible = _luce_fossa.light_energy > 0.01


## Per i test: la luce della fossa è accesa.
func luce_fossa_accesa() -> bool:
	return _luce_fossa != null and _luce_fossa.visible and _luce_fossa.light_energy > 0.05


## Vero se il giocatore è sul bordo della vasca grande vicino a un punto d'uscita (dove lei può uscire).
func _sul_bordo(p: Node3D) -> bool:
	for q in _punti:
		if AcquaDiLei._in_pianta(p.global_position, q.global_position) <= distanza_bordo:
			return true
	return false


## Il giro della luce: dentro la vasca grande (un anello 1,2 m dentro i bordi, 0,6 m sotto il pelo), poi in ogni
## vasca dei bimbi (al centro, appena sopra il fondo) e di nuovo nella vasca grande. Fra una vasca e l'altra passa
## sotto il pavimento: la luce senza ombre non illumina il pavimento dal sotto.
func _giro() -> PackedVector3Array:
	var out := PackedVector3Array()
	var y := vasca_grande.get_surface_global_y() - 0.6
	var m := vasca_grande.inner_size * 0.5 - Vector3(1.2, 0, 1.2)
	for c in [Vector3(-m.x, 0, -m.z), Vector3(m.x, 0, -m.z), Vector3(m.x, 0, m.z), Vector3(-m.x, 0, m.z), Vector3(-m.x, 0, -m.z)]:
		var g := vasca_grande.to_global(c)
		out.append(Vector3(g.x, y, g.z))
	for v in vasche_bimbi:
		if v == null:
			continue
		var g := v.global_position
		out.append(Vector3(g.x, v.get_floor_global_y() + 0.12, g.z))
	return out


## I giocattoli che galleggiano nella vasca grande (ogg_* della sala, alla quota del pelo, dentro la vasca): l'elenco si
## fa la prima volta e si tiene; con ognuno il raggio in pianta (dalle mesh) e dove stava (per tornarci).
func _galleggianti() -> Array[Node3D]:
	if _elenco_galleggianti_fatto:
		var vivi: Array[Node3D] = []
		for g in _elenco_galleggianti:
			if is_instance_valid(g):
				vivi.append(g)
		return vivi
	_elenco_galleggianti_fatto = true
	var scena := get_tree().current_scene if is_inside_tree() else null
	if scena == null or vasca_grande == null:
		return _elenco_galleggianti
	var pelo := vasca_grande.get_surface_global_y()
	var mezzo := vasca_grande.inner_size * 0.5
	for n in scena.find_children("ogg_*", "Node3D", true, false):
		var g := n as Node3D
		if g.get_parent() and String(g.get_parent().name).begins_with("ogg_"):
			continue
		var l := vasca_grande.to_local(g.global_position)
		if absf(l.x) <= mezzo.x and absf(l.z) <= mezzo.z and absf(g.global_position.y - pelo) < 0.6:
			_elenco_galleggianti.append(g)
			_raggi[g] = _raggio_in_pianta(g)
	return _elenco_galleggianti


var _elenco_galleggianti: Array[Node3D] = []
var _elenco_galleggianti_fatto := false
var _raggi := {}


## Il raggio in pianta di un giocattolo (dai vertici delle sue mesh: anche senza schermo, dove le AABB sono vuote).
static func _raggio_in_pianta(g: Node3D) -> float:
	var r := 0.3
	var mesh_g: Array = g.find_children("*", "MeshInstance3D", true, false)
	if g is MeshInstance3D:
		mesh_g.append(g)
	for m in mesh_g:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var facce := mi.mesh.get_faces()
		for k in range(0, facce.size(), 3):
			var c := mi.global_transform * facce[k] - g.global_position
			r = maxf(r, Vector2(c.x, c.z).length())
	return r


## Prima che lei esca dal punto [param q]: i giocattoli che galleggiano lì vicino si scostano (l'acqua che si muove),
## in [param secondi] (0: subito), restando dentro la vasca lontani dal bordo e senza toccarsi fra loro.
func prepara_uscita(q: Node3D, secondi := 1.6) -> void:
	if q == null:
		return
	var mezzo := vasca_grande.inner_size * 0.5
	var centro3 := vasca_grande.to_local(q.global_position)
	var centro := Vector2(centro3.x, centro3.z)
	var lista := _galleggianti()
	# dove sono adesso (in pianta, nella vasca) quelli che restano fermi, e dove vanno quelli che si spostano
	var posti := {}
	for g in lista:
		var l := vasca_grande.to_local(g.global_position)
		posti[g] = Vector2(l.x, l.z)
	var da_spostare: Array[Node3D] = []
	for g in lista:
		if (posti[g] as Vector2).distance_to(centro) < spazio_galleggianti + float(_raggi.get(g, 0.3)):
			da_spostare.append(g)
	for g in da_spostare:
		var r := float(_raggi.get(g, 0.3))
		var via: Vector2 = (posti[g] as Vector2) - centro
		if via.length() < 0.05:
			via = -centro if centro.length() > 0.05 else Vector2.RIGHT
		var meglio := Vector2.INF
		# si prova la direzione in cui già sta, poi girando a passi di 15 gradi da una parte e dall'altra
		for k in 25:
			var ang := deg_to_rad(15.0 * floorf((k + 1) / 2.0) * (1.0 if k % 2 == 1 else -1.0))
			var d := via.normalized().rotated(ang)
			var meta := centro + d * (spazio_galleggianti + r)
			meta.x = clampf(meta.x, -mezzo.x + r + 0.15, mezzo.x - r - 0.15)
			meta.y = clampf(meta.y, -mezzo.z + r + 0.15, mezzo.z - r - 0.15)
			if meta.distance_to(centro) < spazio_galleggianti + r - 0.05:
				continue
			var libero := true
			for h in lista:
				if h != g and (posti[h] as Vector2).distance_to(meta) < r + float(_raggi.get(h, 0.3)) + 0.05:
					libero = false
					break
			if libero:
				meglio = meta
				break
		if meglio == Vector2.INF:
			continue    # (nessun posto libero: resta dov'è)
		posti[g] = meglio
		var l := vasca_grande.to_local(g.global_position)
		var arrivo := vasca_grande.to_global(Vector3(meglio.x, l.y, meglio.y))
		if secondi <= 0.0:
			g.global_position = arrivo
		else:
			var tw := g.create_tween()
			tw.tween_property(g, "global_position", arrivo, secondi).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Per i test e il controllo di posizionamento: i giocattoli che galleggiano, col loro raggio in pianta.
func galleggianti_e_raggi() -> Dictionary:
	var out := {}
	for g in _galleggianti():
		out[g] = float(_raggi.get(g, 0.3))
	return out
