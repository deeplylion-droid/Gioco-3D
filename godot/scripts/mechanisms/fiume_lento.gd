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

signal salito
signal ricominciato
signal uscito

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

var giocatore: Player
var tratto: TrattoFiume
var s := 0.0
var v := 0.0
var giri := 0
var arrivato := false

var _ciambella: Node3D
var _sali: Interactable
var _t := 0.0
var _giro := 0.0
var _dir_prima := Vector3.ZERO


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
	if giocatore == null or not corrente_accesa():
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
		tratto = dopo
		if sbagliato and tratto == imbarco:
			giri += 1
			v = velocita
			ricominciato.emit()
	_porta_giocatore()


func _arriva() -> void:
	arrivato = true
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


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"arrivato": arrivato}


## Si riparte all'imbarco, giù dalla ciambella (il checkpoint mette il giocatore al suo posto).
func load_state(data: Dictionary) -> void:
	if giocatore:
		giocatore.set_physics_process(true)
		giocatore = null
	arrivato = bool(data.get("arrivato", false))
	tratto = imbarco
	s = 0.0
	v = velocita
	_sali.enabled = not arrivato
	_metti_ciambella()
