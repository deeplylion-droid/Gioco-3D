class_name GiranteTurbina
extends Node
## Fa girare la girante di una turbina d'avviamento del modello (TURBINA_n della sala pompe)
## intorno al suo centro, alla velocità della Turbine che la comanda. Serve perché l'origine
## della girante nel modello è sul bordo basso: ruotarla sul suo asse (external_rotor) la
## farebbe girare intorno al bordo. La sua collisione (TURBINA_n_disco) è figlia e gira con lei.

## La turbina che comanda (la sua velocità angolare).
@export var turbina: Turbine
## La girante del modello.
@export var girante_path: NodePath

var _girante: Node3D
var _riposo := Transform3D.IDENTITY
var _centro := Vector3.ZERO
var _asse := Vector3.BACK
var _angolo := 0.0


func _ready() -> void:
	_girante = get_node_or_null(girante_path) as Node3D
	if _girante == null:
		return
	_riposo = _girante.global_transform
	var mi := _girante as MeshInstance3D
	var box := mi.get_aabb() if mi else AABB()
	_centro = _riposo * box.get_center()
	_asse = _riposo.basis.z.normalized()


func _physics_process(delta: float) -> void:
	if _girante == null or turbina == null or turbina.angular_speed <= 0.0:
		return
	_angolo = fmod(_angolo + turbina.angular_speed * delta, TAU)
	var su_centro := Transform3D(Basis.IDENTITY, _centro)
	_girante.global_transform = su_centro * Transform3D(Basis(_asse, _angolo), Vector3.ZERO) * su_centro.affine_inverse() * _riposo
