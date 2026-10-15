class_name LevaGrande
extends Node3D
## La leva grande della sala pompe (tappa 6), in alto dietro una grata: si colpisce col getto.
## Finché le tre pompe non sono avviate è bloccata (il getto la fa solo sbattere); poi, con
## abbastanza acqua, scatta in basso e parte il risveglio ([signal tirata]).
## Il nodo sta sul mozzo della leva, con la rotazione della scena degli ambienti tecnici: il suo
## asse X è quello perpendicolare al muro, intorno a cui gira la leva.
## La grata e la gabbia sono di rete: la loro collisione non deve fermare il getto (la leva è a
## 3,6 m, il giocatore non ci arriva comunque), quindi qui si tolgono dai livelli fisici.

signal tirata
signal colpita_bloccata

## Il braccio della leva (LEVA del modello, origine sul mozzo).
@export var leva_path: NodePath
## Grata e gabbia davanti alla leva: senza collisione per il getto.
@export var reti: Array[NodePath] = []
## Litri d'acqua che servono per tirarla giù.
@export var litri_per_tirarla := 1.2
## Angolo della leva abbassata (gradi, intorno all'asse X del nodo) e tempo per arrivarci.
@export var angolo := -70.0
@export var durata := 0.45
## Bersaglio del getto: centro e dimensioni (coordinate del nodo).
@export var centro_bersaglio := Vector3(0.0, 0.28, 0.0)
@export var dimensioni_bersaglio := Vector3(0.6, 0.8, 1.3)

## Vero quando le tre pompe girano: solo allora si può tirare.
var sbloccata := false
var abbassata := false

var _leva: Node3D
var _riposo := Transform3D.IDENTITY
var _acqua := 0.0
var _t := 1.0
var _sbattuta := 0.0


func _ready() -> void:
	add_to_group(&"persist")
	_leva = get_node_or_null(leva_path) as Node3D
	if _leva:
		_riposo = _leva.global_transform
	for r in reti:
		var n := get_node_or_null(r)
		if n:
			_togli_collisione(n)
	var hit := WaterHitbox.new()
	hit.name = "Bersaglio"
	add_child(hit)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensioni_bersaglio
	cs.shape = shape
	cs.position = centro_bersaglio
	hit.add_child(cs)
	hit.water_hit.connect(_on_water_hit)


static func _togli_collisione(n: Node) -> void:
	var corpi := n.find_children("*", "CollisionObject3D", true, false)
	if n is CollisionObject3D:
		corpi.append(n)
	for c in corpi:
		(c as CollisionObject3D).collision_layer = 0
		(c as CollisionObject3D).collision_mask = 0


func _on_water_hit(amount: float, _point: Vector3, _direction: Vector3) -> void:
	if abbassata:
		return
	if not sbloccata:
		# Bloccata: sbatte un poco e basta.
		if _sbattuta <= 0.0:
			colpita_bloccata.emit()
		_sbattuta = 0.25
		return
	_acqua += amount
	if _acqua >= litri_per_tirarla:
		tira()


## La leva scatta in basso (anche da codice, per esempio nei test).
func tira() -> void:
	if abbassata:
		return
	abbassata = true
	_t = 0.0
	tirata.emit()


func _process(delta: float) -> void:
	if _leva == null:
		return
	var asse := global_basis.x.normalized()
	if abbassata and _t < 1.0:
		_t = minf(_t + delta / maxf(durata, 0.01), 1.0)
		# Scatta: parte piano, arriva in fondo e rimbalza un poco.
		var k := _t * _t * (3.0 - 2.0 * _t) + sin(_t * PI) * 0.08 * _t
		_ruota(asse, deg_to_rad(angolo) * k)
	elif not abbassata:
		if _sbattuta > 0.0:
			_sbattuta = maxf(_sbattuta - delta, 0.0)
			_ruota(asse, deg_to_rad(-3.0) * sin(_sbattuta * 40.0) * _sbattuta * 4.0)
		elif _leva.global_transform != _riposo:
			_leva.global_transform = _riposo


func _ruota(asse: Vector3, ang: float) -> void:
	var perno := _riposo.origin
	_leva.global_transform = Transform3D(Basis(asse, ang) * _riposo.basis, perno)


func save_state() -> Dictionary:
	return {"abbassata": abbassata}


func load_state(data: Dictionary) -> void:
	if bool(data.get("abbassata", false)):
		abbassata = true
		_t = 0.999
