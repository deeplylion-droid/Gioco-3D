class_name WetZone
extends Area3D
## Zona di pavimento bagnato (pozzanghere): i passi dentro quest'area escono come "bagnati".
## Serve una CollisionShape3D figlia che copra il pavimento.


func _init() -> void:
	collision_layer = Layers.WATER_VOLUMES
	collision_mask = 0
	monitoring = false
	add_to_group(&"zona_bagnata")
