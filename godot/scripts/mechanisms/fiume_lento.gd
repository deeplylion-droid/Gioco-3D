class_name FiumeLento
extends Node3D
## Il fiume lento (prototipo di enigma-logica, docs/proposte/fiume_infermeria/nota_logica.md): un
## canale con la corrente che porta il giocatore seduto su una ciambella. La strada è fatta di tratti
## (TrattoFiume, Path3D figli) collegati tra loro; ai bivi una paratia (ParatiaFiume) sceglie il tratto
## dopo e si gira col getto. I rami sbagliati riportano all'imbarco; il tratto con l'uscita finisce
## all'approdo, dove si scende.
## - Sulla ciambella il giocatore non cammina, ma si guarda intorno, spara e aspira; il serbatoio si
##   ricarica da solo (l'acqua scorre).
## - Col getto ci si spinge: sparando all'indietro si accelera, in avanti si frena
##   ([member velocita_min], [member velocita_max]); poi la corrente torna piano alla sua velocità.
## - La corrente c'è solo dopo che le pompe sono ripartite ([member dopo_le_pompe]: GameState.luci
##   non più PRIMA_DEL_RISVEGLIO); prima la ciambella non si muove.
## - Nei checkpoint si riparte all'imbarco, giù dalla ciambella; le paratie restano come erano.
## - Lo squalo (SqualoFiume di mascotte, build 0.5.0, scelta A del GDD): dopo il primo bivio segue la ciambella
##   lungo i tratti, anche nei rami sbagliati; nel tratto d'imbarco non c'è. Questo nodo gli fa da guida
##   ([method ciambella], [method dietro], [method avanti], [method velocita], [method puo_attaccare],
##   [method durata_giro]). Se morde: nero, e si riparte sulla ciambella all'imbarco con le paratie come le si era
##   lasciate, senza ricaricare la zona (conta come una morte); con [member squalo_letale] spento urta e fa girare la
##   ciambella.

signal salito
signal ricominciato
signal uscito
## Lo squalo ha morso: nero, e si riparte sulla ciambella all'imbarco (emesso a ripartenza fatta).
signal morso_dallo_squalo

## Il primo tratto, dall'imbarco.
@export var imbarco: TrattoFiume
## La velocità della corrente e i limiti con la spinta del getto (m/s).
@export var velocita := 2.2
@export var velocita_min := 1.2
@export var velocita_max := 3.2
## Quanto spinge il getto (m/s² a getto pieno, nella direzione della corrente).
@export var spinta := 2.5
## Quanto in fretta la corrente torna alla sua velocità senza getto (m/s²).
@export var ritorno := 0.6
## Litri al secondo che entrano nel serbatoio stando sulla ciambella.
@export var ricarica := 8.0
## Vero: la corrente c'è solo dopo le pompe (tappa 6).
@export var dopo_le_pompe := true
## Dove si scende all'approdo, rispetto alla fine del tratto d'uscita (globale, in più).
@export var discesa := Vector3(0.0, 0.0, 0.0)
## La ciambella ondeggia piano (m) e nelle curve gira un po' su sé stessa (giri per radiante di curva).
@export var ondeggio := 0.04
@export var giro_nelle_curve := 0.12
## Il modello della ciambella (vuoto: un toro rosso provvisorio).
@export var modello_ciambella: PackedScene

@export_group("Squalo")
## Lo squalo c'è (spento: non compare) e morde (spento: urta la ciambella e la fa girare).
@export var squalo_attivo := true:
	set(v):
		squalo_attivo = v
		_passa_allo_squalo()
@export var squalo_letale := true:
	set(v):
		squalo_letale = v
		_passa_allo_squalo()
## Quanto sta sotto la ciambella il pelo dell'acqua (m): la guida dà i punti sul pelo.
@export var pelo_sopra_la_ciambella := 0.12
## In fondo ai rami sbagliati (lo scivolo e la vasca dell'imbarco) lo squalo non attacca: per quanti metri.
@export var calmo_in_fondo_ai_rami := 14.0
## Il nero del morso: quanto ci mette a scendere, quanto resta, quanto a schiarirsi (s).
@export var nero_giu := 0.25
@export var nero_fermo := 0.6
@export var nero_su := 0.8
## Urtata dallo squalo, la ciambella gira su sé stessa (giri al secondo, all'inizio).
@export var giri_urto := 0.6
## Dopo quanti morsi nello stesso giro di fiume lo squalo smette di mordere e urta soltanto, fino all'approdo (regola
## B del coordinatore, 15 novembre: chi non lo respinge mai finisce il giro al terzo tentativo). Il conto non si
## azzera ripartendo dall'imbarco dopo un morso; si azzera all'approdo (e col suo checkpoint) e con la partita nuova.
@export var morsi_per_giro := 2
## Negli ultimi metri prima di un bivio lo squalo non comincia un attacco: un urto lì farebbe perdere il disco.
@export var calmo_prima_del_bivio := 20.0

var giocatore: Player
var tratto: TrattoFiume
var s := 0.0
var v := 0.0
var giri := 0
var arrivato := false

## Lo squalo (SqualoFiume), o null.
var squalo: Node3D:
	set(v):
		squalo = v
		_attacca_squalo()
## Quante volte lo squalo ha morso da quando si è saliti (per i test), e quante in questo giro (fino all'approdo).
var morsi := 0
var morsi_giro := 0

var _ciambella: Node3D
var _sali: Interactable
var _t := 0.0
var _giro := 0.0
var _dir_prima := Vector3.ZERO
## I tratti fatti prima di quello di adesso, dal più recente (per la guida dello squalo: i punti dietro).
var _storia: Array[TrattoFiume] = []
## Il nero del morso in corso (la ciambella ferma), e l'urto (secondi che restano di giro su sé stessa).
var _nel_nero := false
var _urto := 0.0
var _urto_durata := 3.0


func _ready() -> void:
	add_to_group(&"persist")
	tratto = imbarco
	_ciambella = Node3D.new()
	_ciambella.name = "Ciambella"
	add_child(_ciambella)
	if modello_ciambella:
		_ciambella.add_child(modello_ciambella.instantiate())
	else:
		var mi := MeshInstance3D.new()
		var toro := TorusMesh.new()
		toro.inner_radius = 0.35
		toro.outer_radius = 0.75
		mi.mesh = toro
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.3, 0.25)
		mi.material_override = mat
		_ciambella.add_child(mi)
	_sali = Interactable.new()
	_sali.name = "Sali"
	_sali.prompt = "Sali"
	var forma := CollisionShape3D.new()
	var sfera := SphereShape3D.new()
	sfera.radius = 0.9
	forma.shape = sfera
	_sali.add_child(forma)
	_ciambella.add_child(_sali)
	_sali.interacted.connect(func(by: Node):
		if by is Player:
			sali(by))
	_metti_ciambella()


func corrente_accesa() -> bool:
	return not dopo_le_pompe or GameState.luci != GameState.Luci.PRIMA_DEL_RISVEGLIO


func a_bordo() -> bool:
	return giocatore != null


## Il giocatore si siede sulla ciambella.
func sali(p: Player) -> void:
	if giocatore or arrivato:
		return
	giocatore = p
	p.set_physics_process(false)
	p.velocity = Vector3.ZERO
	_sali.enabled = false
	v = velocita
	_porta_giocatore()
	p.reset_physics_interpolation()
	salito.emit()


## Si scende (all'approdo, o ripartendo da un checkpoint).
func scendi(dove: Vector3) -> void:
	if giocatore == null:
		return
	var p := giocatore
	giocatore = null
	p.set_physics_process(true)
	p.teleport(dove, p.yaw, p.pitch)


func _physics_process(delta: float) -> void:
	_aggiorna_paratie()
	if giocatore == null or not corrente_accesa() or _nel_nero:
		return
	var pack := giocatore.water_pack
	# La spinta del getto lungo la corrente: all'indietro accelera, in avanti frena.
	var d := tratto.direzione(s)
	var fissa := tratto.velocita > 0.0
	if not fissa:
		if pack and pack.is_spraying and pack.flow > 0.05:
			var mira := -giocatore.get_aim_basis().z
			v -= mira.dot(d) * spinta * pack.flow * delta
		else:
			v = move_toward(v, velocita, ritorno * delta)
		v = clampf(v, velocita_min, velocita_max)
	if pack:
		pack.refill(ricarica * delta)
	s += (tratto.velocita if fissa else v) * delta
	# Nelle curve la ciambella gira un po' su sé stessa (verso la curva), poi rallenta.
	_t += delta
	var dn := tratto.direzione(s)
	if _dir_prima != Vector3.ZERO:
		_giro += _dir_prima.signed_angle_to(dn, Vector3.UP) * giro_nelle_curve * TAU
	_giro *= exp(-0.15 * delta)
	if _urto > 0.0:
		# urtata dallo squalo: gira su sé stessa, sempre più piano; il giocatore gira con lei
		var d_giro := TAU * giri_urto * (_urto / _urto_durata) * delta
		_giro += d_giro
		giocatore.set_look(giocatore.yaw + d_giro, giocatore.pitch)
		_urto = maxf(0.0, _urto - delta)
	_dir_prima = dn
	while s >= tratto.lunghezza():
		var dopo := tratto.seguente()
		if tratto.uscita or dopo == null:
			s = tratto.lunghezza()
			_porta_giocatore()
			_arriva()
			return
		s -= tratto.lunghezza()
		var sbagliato := tratto.ramo_sbagliato
		var dall_imbarco := tratto == imbarco
		_storia.push_front(tratto)
		if _storia.size() > 4:
			_storia.resize(4)
		tratto = dopo
		if sbagliato and tratto == imbarco:
			giri += 1
			v = velocita
			# (di nuovo nel tratto d'imbarco: calmo, lo squalo se ne va e torna dopo il primo bivio)
			if squalo:
				squalo.call(&"ferma")
			ricominciato.emit()
		elif dall_imbarco and squalo and squalo_attivo:
			# passato il primo bivio: arriva lo squalo
			squalo.call(&"comincia")
	_porta_giocatore()


func _arriva() -> void:
	arrivato = true
	morsi_giro = 0
	_passa_allo_squalo()
	if squalo:
		squalo.call(&"ferma")
	var fine := tratto.punto(tratto.lunghezza())
	scendi(fine + tratto.direzione(tratto.lunghezza()) * 1.2 + discesa)
	uscito.emit()


## I bersagli rispondono solo dalla ciambella, sul tratto che arriva al loro bivio.
func _aggiorna_paratie() -> void:
	for t in find_children("*", "TrattoFiume", true, false):
		var tf := t as TrattoFiume
		if tf.paratia:
			tf.paratia.attiva = giocatore != null and tratto == tf and corrente_accesa()


func _metti_ciambella() -> void:
	if tratto == null or _ciambella == null:
		return
	var d := tratto.direzione(s)
	var su := Vector3.UP * ondeggio * sin(_t * 1.3) if giocatore else Vector3.ZERO
	_ciambella.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP).rotated(Vector3.UP, _giro), tratto.punto(s) + su)


func _porta_giocatore() -> void:
	_metti_ciambella()
	if giocatore:
		giocatore.global_position = _ciambella.global_position + Vector3(0.0, 0.05, 0.0)
		giocatore.velocity = Vector3.ZERO


# --- Lo squalo ---------------------------------------------------------------------------------

## La guida che SqualoFiume vuole (ciambella, dietro, avanti, velocita, puo_attaccare, durata_giro): un oggetto a
## parte, perché qui «velocita» è già la velocità della corrente.
class GuidaSqualo extends RefCounted:
	var fiume: FiumeLento

	func _init(f: FiumeLento) -> void:
		fiume = f

	func ciambella() -> Vector3:
		return fiume.ciambella()

	func dietro(m: float) -> Vector3:
		return fiume.dietro(m)

	func avanti(m: float) -> Vector3:
		return fiume.avanti(m)

	func velocita() -> float:
		return fiume.velocita_ciambella()

	func puo_attaccare() -> bool:
		return fiume.puo_attaccare()

	func durata_giro() -> float:
		return fiume.durata_giro()


var _guida: GuidaSqualo


func _attacca_squalo() -> void:
	if squalo == null:
		return
	if _guida == null:
		_guida = GuidaSqualo.new(self)
	squalo.set(&"guida", _guida)
	if squalo.has_signal(&"morde") and not squalo.is_connected(&"morde", _su_morso):
		squalo.connect(&"morde", _su_morso)
	if squalo.has_signal(&"urta") and not squalo.is_connected(&"urta", _su_urto):
		squalo.connect(&"urta", _su_urto)
	_passa_allo_squalo()


func _passa_allo_squalo() -> void:
	if squalo == null or not is_instance_valid(squalo):
		return
	squalo.set(&"abilitato", squalo_attivo)
	squalo.set(&"letale", squalo_letale and morsi_giro < morsi_per_giro)
	if not squalo_attivo:
		squalo.call(&"ferma")


## La guida dello squalo: dove sta la ciambella, sul pelo.
func ciambella() -> Vector3:
	return _sul_pelo(tratto.punto(s)) if tratto else global_position


## Il punto del fiume [param m] metri dietro la ciambella, lungo la strada fatta (prima dell'imbarco, dritto
## all'indietro), sul pelo.
func dietro(m: float) -> Vector3:
	if tratto == null:
		return global_position
	var t := tratto
	var ss := s - m
	var i := 0
	while ss < 0.0:
		if i >= _storia.size() or not is_instance_valid(_storia[i]):
			return _sul_pelo(t.punto(0.0) + t.direzione(0.0) * ss)
		t = _storia[i]
		i += 1
		ss += t.lunghezza()
	return _sul_pelo(t.punto(ss))


## Il punto [param m] metri davanti alla ciambella, lungo i tratti che verranno (con le paratie di adesso), sul pelo.
func avanti(m: float) -> Vector3:
	if tratto == null:
		return global_position
	var t := tratto
	var ss := s + m
	while ss > t.lunghezza():
		var dopo := t.seguente()
		if dopo == null or t.uscita:
			return _sul_pelo(t.punto(t.lunghezza()) + t.direzione(t.lunghezza()) * (ss - t.lunghezza()))
		ss -= t.lunghezza()
		t = dopo
	return _sul_pelo(t.punto(ss))


## La velocità della ciambella (m/s).
func velocita_ciambella() -> float:
	if tratto and tratto.velocita > 0.0:
		return tratto.velocita
	return v if giocatore else 0.0


## Lo squalo può attaccare: col giocatore sulla ciambella e la corrente accesa, fuori dal tratto d'imbarco, non in
## fondo a un ramo sbagliato (lo scivolo e la vasca), non nel nero del morso.
func puo_attaccare() -> bool:
	if giocatore == null or arrivato or _nel_nero or not corrente_accesa() or tratto == null or tratto == imbarco:
		return false
	if tratto.ramo_sbagliato and s > tratto.lunghezza() - calmo_in_fondo_ai_rami:
		return false
	if tratto.paratia and s > tratto.lunghezza() - calmo_prima_del_bivio:
		return false
	return true


## Quanto dura un giro (s): i tratti giusti, alla velocità della corrente.
func durata_giro() -> float:
	var l := 0.0
	for t in find_children("*", "TrattoFiume", true, false):
		if not (t as TrattoFiume).ramo_sbagliato:
			l += (t as TrattoFiume).lunghezza()
	return l / maxf(velocita, 0.1)


func _sul_pelo(q: Vector3) -> Vector3:
	return q + Vector3(0.0, pelo_sopra_la_ciambella, 0.0)


## Il morso: nero, e si riparte sulla ciambella all'imbarco con le paratie come sono; conta come una morte. La zona
## non si ricarica (non passa da GameState.kill_player).
func _su_morso() -> void:
	if _nel_nero or giocatore == null:
		return
	_nel_nero = true
	morsi += 1
	morsi_giro += 1
	if GameState.get(&"morti_totali") != null:
		GameState.set(&"morti_totali", int(GameState.get(&"morti_totali")) + 1)
	var velo := Dissolvenza.di(get_tree())
	await velo.scurisci(nero_giu)
	if not is_inside_tree():
		return
	tratto = imbarco
	s = 0.0
	v = velocita
	_storia.clear()
	_giro = 0.0
	_urto = 0.0
	_dir_prima = Vector3.ZERO
	if squalo:
		squalo.call(&"riparti", false)
	# (dopo [member morsi_per_giro] morsi, fino all'approdo urta soltanto)
	_passa_allo_squalo()
	_porta_giocatore()
	if giocatore:
		giocatore.reset_physics_interpolation()
		giocatore.set_look(_ciambella.global_basis.get_euler().y + PI, 0.0)
	await get_tree().create_timer(nero_fermo, false).timeout
	if not is_inside_tree():
		return
	_nel_nero = false
	velo.schiarisci(nero_su)
	morso_dallo_squalo.emit()


## L'urto (squalo non letale): la ciambella gira su sé stessa.
func _su_urto() -> void:
	_urto_durata = float(squalo.get(&"giro_urto")) if squalo and squalo.get(&"giro_urto") != null else 3.0
	_urto = _urto_durata


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"arrivato": arrivato, "morsi_giro": morsi_giro}


## Si riparte all'imbarco, giù dalla ciambella (il checkpoint mette il giocatore al suo posto).
func load_state(data: Dictionary) -> void:
	if giocatore:
		giocatore.set_physics_process(true)
		giocatore = null
	arrivato = bool(data.get("arrivato", false))
	morsi_giro = int(data.get("morsi_giro", 0))
	_passa_allo_squalo()
	tratto = imbarco
	s = 0.0
	v = velocita
	_storia.clear()
	_urto = 0.0
	# (ripartendo da un checkpoint lo squalo non c'è: torna calmo dopo il primo bivio)
	if squalo:
		squalo.call(&"ferma")
	_sali.enabled = not arrivato
	_metti_ciambella()
