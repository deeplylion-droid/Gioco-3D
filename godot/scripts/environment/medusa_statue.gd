@tool
class_name MedusaStatue
extends Node3D
## La medusa ferma come una statua sul piedistallo (scena S1, "il benvenuto").
## Carica il GLB della medusa (la posa di riposo è già la statua, con le mani giunte), mette lo
## shader "a gelatina" sulla campana e tiene i canali appena accesi. Con pulse() i canali
## pulsano a tempo per un attimo (quando parte la sigla).
## Il nodo va messo con l'origine all'altezza della vita della medusa: le punte dei tentacoli
## stanno [member feet_depth] metri più in basso, sul piano del piedistallo.

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild()
## Materiale della campana (superficie "M_campana" della mesh Medusa).
@export var bell_material: ShaderMaterial:
	set(value):
		bell_material = value
		_rebuild()
## Distanza tra l'origine (vita) e le punte dei tentacoli.
@export var feet_depth := 2.2
@export_group("Campana")
## Luce dei canali da ferma: appena accesi.
@export var idle_channel_light := 0.9
## Luce dei canali al massimo della sigla.
@export var pulse_channel_light := 6.0
## Pulsazioni al secondo durante la sigla.
@export var pulse_rate := 1.6

var _instance: Node3D
var _bell: ShaderMaterial
var _pulse_left := 0.0
var _pulse_total := 1.0
var _t := 0.0


func _ready() -> void:
	_rebuild()


## I canali della campana pulsano a tempo per [param seconds] secondi.
func pulse(seconds := 6.0) -> void:
	_pulse_left = seconds
	_pulse_total = maxf(seconds, 0.01)


func get_model_instance() -> Node3D:
	return _instance


func _process(delta: float) -> void:
	if _bell == null:
		return
	_t += delta
	var light := idle_channel_light
	if _pulse_left > 0.0:
		_pulse_left = maxf(_pulse_left - delta, 0.0)
		# Sale in fretta, pulsa e si spegne piano verso la fine.
		var p := 1.0 - _pulse_left / _pulse_total
		var env := smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.7, 1.0, p))
		var beat := 0.5 + 0.5 * sin(_t * pulse_rate * TAU)
		light = lerpf(idle_channel_light, pulse_channel_light * (0.45 + 0.55 * beat), env)
	_bell.set_shader_parameter(&"luce_canali", light)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_instance):
		_instance.queue_free()
		_instance = null
	_bell = null
	if model == null:
		return
	_instance = model.instantiate() as Node3D
	if _instance == null:
		return
	_instance.name = "Modello"
	add_child(_instance, false, Node.INTERNAL_MODE_FRONT)
	if bell_material:
		_bell = bell_material.duplicate() as ShaderMaterial
		_bell.set_shader_parameter(&"pulsazione_al_secondo", 0.0)
		_bell.set_shader_parameter(&"luce_canali", idle_channel_light)
		for mi in _instance.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			if m == null:
				continue
			for s in m.get_surface_count():
				var mat := m.surface_get_material(s)
				if mat and mat.resource_name == "M_campana":
					(mi as MeshInstance3D).set_surface_override_material(s, _bell)
