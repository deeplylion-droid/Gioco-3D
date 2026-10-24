@tool
class_name WaterVolume
extends Area3D
## Un volume d'acqua (piscina, pozza profonda, canale), livello fisico "volumi_acqua".
## Il giocatore lo usa per i passi nell'acqua; lo zaino può aspirarne l'acqua (riserva
## infinita) se [member suckable] è vero. La superficie è il bordo superiore della prima
## BoxShape3D figlia. Per una vasca con il livello che sale e scende usa WaterTank.

## Lo zaino può aspirare da qui (riserva infinita).
@export var suckable := true
## Acqua da guadare (il canale del tunnel sottomarino): con l'acqua sopra il ginocchio il giocatore non va più
## veloce di così, a piedi e di corsa (m/s). 0 = l'acqua non rallenta.
@export var velocita_guado := 0.0
## Come [member velocita_guado], accovacciati (m/s).
@export var velocita_guado_accovacciato := 0.0


func _init() -> void:
	collision_layer = Layers.WATER_VOLUMES
	collision_mask = 0
	monitoring = false


func _ready() -> void:
	if not Engine.is_editor_hint() and suckable:
		add_to_group(&"water_sources")


func _first_box() -> CollisionShape3D:
	for c in get_children(true):
		var cs := c as CollisionShape3D
		if cs and not cs.disabled and cs.shape is BoxShape3D:
			return cs
	return null


## Quota (y globale) della superficie dell'acqua.
func get_surface_height() -> float:
	var cs := _first_box()
	if cs == null:
		return global_position.y
	var half := (cs.shape as BoxShape3D).size.y * 0.5
	return (cs.global_transform * Vector3(0.0, half, 0.0)).y


## Vero se il punto è sott'acqua (dentro il volume).
func contains_point(p: Vector3) -> bool:
	var cs := _first_box()
	if cs == null:
		return false
	var local := cs.global_transform.affine_inverse() * p
	var half := (cs.shape as BoxShape3D).size * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## Per l'aspirazione: frazione del segmento a→b in cui scende sotto la superficie, o -1.
func suction_hit_fraction(a: Vector3, b: Vector3) -> float:
	var cs := _first_box()
	if cs == null:
		return -1.0
	var inv := cs.global_transform.affine_inverse()
	var la := inv * a
	var lb := inv * b
	var half := (cs.shape as BoxShape3D).size * 0.5
	if la.y < half.y or lb.y >= half.y:
		return -1.0
	var t := (la.y - half.y) / (la.y - lb.y)
	var p := la.lerp(lb, t)
	if absf(p.x) <= half.x and absf(p.z) <= half.z:
		return t
	return -1.0


func can_give_water() -> bool:
	return suckable


## L'acqua di un volume semplice non finisce: dà sempre tutto quello che si chiede.
func take_water(liters: float) -> float:
	return liters if suckable else 0.0
