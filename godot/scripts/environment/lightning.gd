class_name Lightning
extends Node
## Lampi della tempesta: ogni tanto la luce che entra dalla cupola si accende forte per un
## attimo (a volte doppio lampo), insieme al vetro della cupola e allo sfondo.
## Emette [signal flashed] per il tuono (audio futuro).

signal flashed(strength: float)

## La luce della tempesta che entra dalla cupola.
@export var light: DirectionalLight3D
## Energia normale della luce (notte).
@export var base_energy := 0.25
## Energia aggiunta al massimo del lampo.
@export var flash_energy := 4.0
## Materiale del vetro della cupola (si illumina col lampo).
@export var glass_material: StandardMaterial3D
@export var glass_base_emission := 0.15
@export var glass_flash_emission := 2.5
## Ambiente: lo sfondo si schiarisce col lampo.
@export var environment: Environment
@export var background_flash := 6.0
@export var min_interval := 7.0
@export var max_interval := 18.0
## Primo lampo dopo questi secondi.
@export var first_delay := 3.0

var _wait := 0.0
var _t := -1.0
var _pattern: Array = []
var _strength := 1.0


func _ready() -> void:
	_wait = first_delay
	_apply(0.0)


## Fa partire subito un lampo (per scene scriptate).
func strike(strength := 1.0) -> void:
	_strength = strength
	_t = 0.0
	# Coppie (inizio, durata, intensità): lampo principale ed eventuali riprese.
	_pattern = [[0.0, 0.09, 1.0]]
	if randf() < 0.6:
		_pattern.append([0.16, 0.07, 0.55])
	if randf() < 0.35:
		_pattern.append([0.32, 0.12, 0.8])
	flashed.emit(strength)


func _process(delta: float) -> void:
	if _t < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			strike(randf_range(0.6, 1.0))
			_wait = randf_range(min_interval, max_interval)
		return
	_t += delta
	var k := 0.0
	var finished := true
	for p in _pattern:
		var start: float = p[0]
		var dur: float = p[1]
		if _t < start + dur + 0.25:
			finished = false
		if _t >= start:
			var local := _t - start
			var env := 1.0 if local < dur else exp(-(local - dur) * 14.0)
			k = maxf(k, env * float(p[2]))
	_apply(k * _strength)
	if finished:
		_t = -1.0
		_apply(0.0)


func _apply(k: float) -> void:
	if light:
		light.light_energy = base_energy + flash_energy * k
	if glass_material:
		glass_material.emission_energy_multiplier = glass_base_emission + glass_flash_emission * k
	if environment:
		environment.background_energy_multiplier = 1.0 + background_flash * k
