class_name LookSalaLunga
extends LookSala
## LookSala (addon grafica) per la sala allungata di 8 m verso sud (muro sud a z = 20, con il
## monumento della statua): stessi valori del look, ma illuminazione globale, sonde, nebbia e
## polvere coprono anche la parte nuova; in più regola le luci del monumento (fari sulla
## ringhiera, faretti nel gradino) e aggiunge il vetro della cupola ai materiali dei lampi.
## Quando l'addon avrà i volumi nuovi, basterà tornare a LookSala.

## Volume della sala lunga (x -20..20, z -24..20, dal fondo della piscina alla cupola).
const SALA_LUNGA_CENTRO := Vector3(0.0, 7.5, -2.0)
const SALA_LUNGA_DIMENSIONI := Vector3(41.0, 21.0, 45.0)

@export_group("Monumento")
@export var energia_fari := 6.5
@export var energia_faretti_bassi := 1.4
## Materiali che si accendono con i lampi (per esempio il vetro della cupola).
@export var materiali_lampo: Array[ShaderMaterial] = []


func _ready() -> void:
	super._ready()
	var gi := get_node_or_null(^"VoxelGI_Sala") as VoxelGI
	if gi:
		gi.size = SALA_LUNGA_DIMENSIONI
		gi.position = SALA_LUNGA_CENTRO
	var sonda := get_node_or_null(^"Sonda_Sala") as ReflectionProbe
	if sonda:
		sonda.size = Vector3(40.0, 13.0, 44.0)
		sonda.position = Vector3(0.0, 4.0, -2.0)
	var nebbia := get_node_or_null(^"NebbiaBassa") as FogVolume
	if nebbia:
		nebbia.size = Vector3(40.0, 3.5, 44.0)
		nebbia.position = Vector3(0.0, -0.6, -2.0)
	for c in get_children():
		if c is Pulviscolo:
			(c as Pulviscolo).volume = Vector3(38.0, 9.0, 42.0)
			(c as Node3D).position = Vector3(0.0, 4.5, -2.0)
	if tempesta:
		for m in materiali_lampo:
			if m and not tempesta.materiali.has(m):
				tempesta.materiali.append(m)
	_regola_monumento(self)


func _regola_monumento(n: Node) -> void:
	var s := n as SpotLight3D
	if s:
		if s.name.begins_with("luce_faro"):
			# Fari sulla ringhiera della galleria sud: la luce principale sulla statua.
			s.light_color = Color(1.0, 0.92, 0.8)
			s.light_energy = energia_fari
			s.spot_range = 16.0
			s.spot_angle = 13.0
			s.spot_angle_attenuation = 0.6
			s.shadow_enabled = true
			s.light_size = 0.04
			s.light_volumetric_fog_energy = 1.6
			s.set_meta(&"grafica_priorita_ombra", 0)
		elif s.name.begins_with("luce_monumento_basso"):
			s.light_energy = energia_faretti_bassi
			s.spot_range = 6.5
			s.spot_angle = 26.0
			s.shadow_enabled = false
			s.light_volumetric_fog_energy = 0.6
	for c in n.get_children():
		_regola_monumento(c)
