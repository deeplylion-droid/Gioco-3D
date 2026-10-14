class_name WaterKnockback
extends Node
## Spinta indietro di un nemico colpito dal getto.
## Si collega al segnale water_hit di un WaterHitbox; lo script del nemico aggiunge
## [member velocity] al suo movimento e non avanza mentre [method is_stunned] è vero.

signal knocked_back(direction: Vector3)

## Il bersaglio da ascoltare (vuoto = il primo WaterHitbox tra i figli del genitore).
@export var hitbox: WaterHitbox
## Velocità aggiunta per ogni litro d'acqua ricevuto (m/s per litro).
@export var strength := 2.5
## Velocità massima della spinta (m/s).
@export var max_speed := 6.0
## Smorzamento della spinta (1/s): più alto = si ferma prima.
@export var damping := 3.5
## Secondi in cui il nemico resta "stordito" dopo l'ultimo colpo.
@export var stun_time := 0.5
## Se vero la spinta resta orizzontale.
@export var horizontal_only := true

var velocity := Vector3.ZERO
var _stun_left := 0.0


func _ready() -> void:
	if hitbox == null and get_parent():
		for c in get_parent().get_children():
			if c is WaterHitbox:
				hitbox = c
				break
	if hitbox:
		hitbox.water_hit.connect(_on_water_hit)
	else:
		push_warning("WaterKnockback: nessun WaterHitbox da ascoltare")


func is_stunned() -> bool:
	return _stun_left > 0.0


func _on_water_hit(amount: float, _point: Vector3, direction: Vector3) -> void:
	var d := direction
	if horizontal_only:
		d.y = 0.0
	if d.length_squared() < 0.0001:
		return
	d = d.normalized()
	velocity += d * strength * amount
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	_stun_left = stun_time
	knocked_back.emit(d)


func _physics_process(delta: float) -> void:
	velocity = velocity.lerp(Vector3.ZERO, 1.0 - exp(-damping * delta))
	_stun_left = maxf(0.0, _stun_left - delta)
