@tool
class_name WaterTankLink
extends WaterBody
## Acqua vera per le vasche del gioco gia' esistenti (WaterTank e WaterVolume del progetto):
## un WaterBody che copia da `tank` posizione, dimensioni e livello a ogni fotogramma.
## La logica (litri, riempimento, scarico, aspirazione dello zaino) resta nel nodo originale;
## qui c'e' solo la grafica: superficie, caustiche, gorgo sullo scarico, increspature, schizzi.
## Il segnaposto grigio della vasca originale viene nascosto (le si assegna un materiale invisibile).
##
## Compatibile con nodi che hanno:
## - WaterTank: inner_size, fill, max_fill, get_surface_global_y(), get_floor_global_y(),
##   get_drain_strength(), segnale level_changed;
## - WaterVolume (Area3D con una BoxShape3D): get_surface_height().
## Per qualsiasi altro nodo si puo' chiamare set_level() a mano.

const INVISIBLE_SHADER := preload("res://addons/acqua/shaders/invisible.gdshader")

## La vasca del gioco da seguire.
@export var tank: Node3D:
	set(v):
		tank = v
		if is_inside_tree():
			_sync_shape()
## Posizione dello scarico rispetto al centro della vasca (in pianta), per il gorgo.
@export var drain_offset := Vector3.ZERO
## Nasconde la superficie segnaposto della vasca originale.
@export var hide_placeholder := true

var _rising := 0.0
var _falling := 0.0
var _synced := false


func _ready() -> void:
	_sync_shape()
	super._ready()
	if Engine.is_editor_hint():
		return
	if tank and hide_placeholder and "water_material" in tank:
		var m := ShaderMaterial.new()
		m.shader = INVISIBLE_SHADER
		tank.water_material = m


func _process(delta: float) -> void:
	_rising = maxf(_rising - delta, 0.0)
	_falling = maxf(_falling - delta, 0.0)
	if tank and is_instance_valid(tank) and not Engine.is_editor_hint():
		_sync_level()
		_sync_drain(delta)
	super._process(delta)


## Vero mentre la vasca del gioco si sta riempiendo (accende le bocchette WaterInlet).
func is_filling() -> bool:
	return _rising > 0.0 or super.is_filling()


## Vero mentre la vasca del gioco si sta svuotando (scarico o aspirazione).
func is_draining() -> bool:
	return _falling > 0.0 or super.is_draining()


## Imposta il livello dell'acqua (quota y nel mondo), per i nodi senza un'interfaccia nota.
func set_level(y: float) -> void:
	level = clampf(y, bottom, maxf(max_level, bottom))


func _sync_shape() -> void:
	if tank == null or not is_inside_tree():
		return
	if "inner_size" in tank:
		var s: Vector3 = tank.inner_size
		global_position = tank.global_position
		size = Vector2(s.x, s.z)
		bottom = tank.get_floor_global_y() if tank.has_method("get_floor_global_y") else tank.global_position.y
		var mf: float = tank.max_fill if "max_fill" in tank else 1.0
		max_level = bottom + s.y * mf
	else:
		# WaterVolume: la prima BoxShape3D figlia
		for c in tank.get_children(true):
			var cs := c as CollisionShape3D
			if cs and cs.shape is BoxShape3D:
				var bs: Vector3 = (cs.shape as BoxShape3D).size
				var sc := cs.global_basis.get_scale()
				global_position = cs.global_position
				size = Vector2(bs.x * sc.x, bs.z * sc.z)
				bottom = cs.global_position.y - bs.y * sc.y * 0.5
				max_level = cs.global_position.y + bs.y * sc.y * 0.5
				break


func _sync_level() -> void:
	var y := level
	if tank.has_method("get_surface_global_y"):
		var f: float = tank.fill if "fill" in tank else 1.0
		y = tank.get_surface_global_y() if f > 0.001 else bottom
	elif tank.has_method("get_surface_height"):
		y = tank.get_surface_height()
	if absf(y - level) > 1e-6:
		if _synced:
			if y > level:
				_rising = 0.35
			else:
				_falling = 0.35
		level = y
		target_level = y
	_synced = true


func _sync_drain(delta: float) -> void:
	if not tank.has_method("get_drain_strength"):
		return
	var k: float = tank.get_drain_strength()
	var f: float = tank.fill if "fill" in tank else 1.0
	var depth_left := clampf((level - bottom) / 0.12, 0.0, 1.0)
	var want := k * depth_left if f > 0.001 else 0.0
	var cur: float = _flows[0][0].w
	var s := move_toward(cur, want, delta * 0.8)
	var dp := global_position + global_basis * drain_offset
	set_flow(0, dp, drain_vortex_radius, s, drain_swirl, drain_funnel_depth * depth_left, 0.35, 0.9)
	if s > 0.2:
		add_impulse(dp, drain_vortex_radius * 0.15, -0.004 * s, 0.03)
