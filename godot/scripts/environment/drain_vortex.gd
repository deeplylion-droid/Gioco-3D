class_name DrainVortex
extends MeshInstance3D
## Gorgo sulla superficie dell'acqua mentre la vasca si svuota dallo scarico.
## Va messo sopra lo scarico (x, z); la quota segue da sola la superficie.

@export var tank: WaterTank
@export var radius := 1.6

var _material: ShaderMaterial


func _ready() -> void:
	var m := PlaneMesh.new()
	m.size = Vector2(radius * 2.0, radius * 2.0)
	mesh = m
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/vortex.gdshader")
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(_delta: float) -> void:
	if tank == null:
		visible = false
		return
	var k := tank.get_drain_strength() if tank.fill > 0.01 else 0.0
	visible = k > 0.01
	if visible:
		global_position.y = tank.get_surface_global_y() + 0.015
		_material.set_shader_parameter(&"strength", clampf(k * 1.5, 0.0, 1.0))
