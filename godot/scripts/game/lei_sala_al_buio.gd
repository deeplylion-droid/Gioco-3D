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
## della vasca grande vicino a un punto d'uscita (lì può ancora uscire). Sulla scia, a 9 m dalla fossa ha ancora circa
## 6,5 m di strada prima della presa: lei è già affacciata quando arriva, come oggi.
@export var distanza_fossa := 9.0
## Quanto ci mette la luce ad andare dalla vasca alla fossa quando il giro finisce (s).
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

enum Stato { ATTESA, GIRO, FINITO }
var stato := Stato.ATTESA
var acqua: AcquaDiLei
var _punti: Array[Node3D] = []


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
	acqua.arriva.connect(func(_dove: Vector3): prepara_uscita(acqua.get(&"_punto"), 1.6))
	# la fossa aspetta il giro (anche se la sala si carica prima del blackout: ripartendo da più avanti o con le luci
	# del lampo lei non deve affacciarsi alla fossa da sola, al blackout, lontano dal giocatore)
	if lei_sbuca:
		lei_sbuca.aspetta_il_giro = true


func _physics_process(_delta: float) -> void:
	if acqua == null or GameState.luci != GameState.Luci.BLACKOUT or GameState.is_dying:
		return
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	acqua.letale = letale
	acqua.pelo = vasca_grande.get_surface_global_y()
	var vicino_fossa := lei_sbuca != null and lei_sbuca.punto_sbuca != null \
			and AcquaDiLei._in_pianta(p.global_position, lei_sbuca.punto_sbuca.global_position) <= distanza_fossa
	var in_sala := zona.has_point(p.global_position)
	match stato:
		Stato.ATTESA:
			if not in_sala:
				return
			if vicino_fossa:
				# ripartendo dalla fossa (o arrivati lì senza giro): la scena di oggi
				_finisci(false)
			elif acqua.gira(_giro(), velocita):
				stato = Stato.GIRO
		Stato.GIRO:
			if not in_sala:
				# uscito dalla sala prima della fossa: lei se ne va, il giro ripartirà quando torna
				if acqua.fase == AcquaDiLei.Fase.LONTANA or acqua.fase == AcquaDiLei.Fase.CALMA:
					acqua.lascia()
					stato = Stato.ATTESA
				return
			if vicino_fossa and acqua.fase == AcquaDiLei.Fase.LONTANA and not _sul_bordo(p):
				_finisci(true)
				return
			if acqua.fase != AcquaDiLei.Fase.LONTANA:
				return
			var q := acqua.punto_vicino_alla_luce(raggio_luce)
			if q and AcquaDiLei._in_pianta(p.global_position, q.global_position) <= distanza_bordo:
				acqua.chiama(q)


func _finisci(con_la_luce: bool) -> void:
	stato = Stato.FINITO
	if con_la_luce and lei_sbuca and lei_sbuca.punto_sbuca:
		var fossa := lei_sbuca.punto_sbuca.global_position
		acqua.smetti_giro(fossa + Vector3.DOWN * 0.6, tempo_alla_fossa)
		get_tree().create_timer(tempo_alla_fossa, false).timeout.connect(func():
			# (dopo la fossa la sua luce se ne va: gli acquari sono una pausa, niente canto da qui)
			acqua.abilitata = false
			if is_instance_valid(lei_sbuca):
				lei_sbuca.vai_alla_fossa())
	else:
		acqua.lascia()
		acqua.abilitata = false
		if lei_sbuca:
			lei_sbuca.vai_alla_fossa()


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
