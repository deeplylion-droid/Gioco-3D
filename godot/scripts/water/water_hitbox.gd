class_name WaterHitbox
extends Area3D
## Bersaglio del getto d'acqua dello zaino-pompa (livello fisico "bersagli_acqua").
## Serve una CollisionShape3D figlia. Turbine, pulsanti e nemici si collegano a water_hit.

## Colpito dal getto. [param amount]: litri arrivati in questo tick fisico.
## [param point]: punto d'impatto. [param direction]: direzione dell'acqua (normalizzata).
signal water_hit(amount: float, point: Vector3, direction: Vector3)

## Moltiplica l'acqua ricevuta (per bersagli più o meno sensibili).
@export var multiplier := 1.0

## Litri ricevuti in totale.
var total_received := 0.0
var _last_hit_msec := -100000


func _init() -> void:
	collision_layer = Layers.WATER_TARGETS
	collision_mask = 0
	monitoring = false


func receive_water(amount: float, point: Vector3, direction: Vector3) -> void:
	var a := amount * multiplier
	total_received += a
	_last_hit_msec = Time.get_ticks_msec()
	water_hit.emit(a, point, direction)


## Vero se è stato colpito negli ultimi [param seconds] secondi.
func is_being_hit(seconds := 0.15) -> bool:
	return Time.get_ticks_msec() - _last_hit_msec <= int(seconds * 1000.0)
