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
## Illuminazione globale già calcolata (tools/bake_voxel_gi.gd): se c'è, il preset Alto non
## deve calcolarla all'avvio.
const GI_CALCOLATA := "res://assets/ambiente/sala/voxel_gi_sala.res"

@export_group("Monumento")
@export var energia_fari := 9.5
@export var energia_faretti_bassi := 0.6
## Materiali che si accendono con i lampi (per esempio il vetro della cupola).
@export var materiali_lampo: Array[ShaderMaterial] = []


func _ready() -> void:
	super._ready()
	var gi := get_node_or_null(^"VoxelGI_Sala") as VoxelGI
	if gi:
		gi.size = SALA_LUNGA_DIMENSIONI
		gi.position = SALA_LUNGA_CENTRO
		if ResourceLoader.exists(GI_CALCOLATA):
			gi.data = load(GI_CALCOLATA) as VoxelGIData
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
	# Luci nuove del GLB che LookSala non conosce ancora: plafoniere calde e insegne al neon.
	var l := n as Light3D
	if l:
		if l.name.begins_with("luce_calda"):
			l.light_color = Color(1.0, 0.72, 0.45)
			l.light_energy = 1.8
			l.shadow_enabled = false
			l.light_volumetric_fog_energy = 0.8
			if l is OmniLight3D:
				(l as OmniLight3D).omni_range = 7.0
			elif l is SpotLight3D:
				(l as SpotLight3D).spot_range = 8.0
		elif l.name.begins_with("luce_insegna_") and l.name != "luce_insegna_rosa":
			l.light_energy = 2.2
			l.shadow_enabled = false
			l.light_volumetric_fog_energy = 1.4
			if l is OmniLight3D:
				(l as OmniLight3D).omni_range = 6.0
	for c in n.get_children():
		_regola_monumento(c)
