@tool
class_name WaterStyle
extends Resource
## Aspetto dell'acqua di una vasca. I preset sono in res://addons/acqua/presets/.
## WaterBody copia questi valori nel materiale della superficie, nella tabella globale
## (caustiche, nebbia sott'acqua) e nell'effetto sott'acqua.

@export_group("Volume")
## Assorbimento per metro (rosso, verde, blu): piu' alto = l'acqua si scurisce prima.
@export var absorption := Vector3(0.45, 0.10, 0.07)
## Diffusione per metro: acqua lattiginosa o torbida.
@export_range(0.0, 6.0, 0.01) var turbidity := 0.06
## Colore della luce diffusa dal volume (lo illuminano le luci della scena).
@export_color_no_alpha var scatter_color := Color(0.10, 0.45, 0.55)
## Luce propria minima del volume.
@export_range(0.0, 2.0, 0.001) var scatter_ambient := 0.02

@export_group("Superficie")
@export_range(0.0, 1.0, 0.001) var roughness := 0.035
@export_range(0.0, 2.0, 0.01) var wave_strength_a := 0.07
@export_range(0.0, 2.0, 0.01) var wave_strength_b := 0.06
@export_range(0.0, 1.0, 0.001) var wave_speed := 0.05
@export_range(0.0, 1.0, 0.01) var refraction_strength := 0.18
@export_range(0.0, 2.0, 0.01) var reflection_strength := 1.0

@export_group("Schiuma e sporco")
@export_color_no_alpha var foam_color := Color(0.82, 0.85, 0.84)
@export_range(0.0, 2.0, 0.01) var foam_shore_amount := 0.6
@export_range(0.0, 4.0, 0.01) var foam_ripple_amount := 1.0
## Patina galleggiante (alghe, polvere).
@export_range(0.0, 1.0, 0.01) var scum_amount := 0.0
@export_color_no_alpha var scum_color := Color(0.16, 0.17, 0.09)

@export_group("Caustiche")
@export_range(0.0, 3.0, 0.01) var caustics_strength := 1.0
## Metri coperti da una ripetizione del motivo.
@export_range(0.2, 8.0, 0.01) var caustics_scale := 1.4

@export_group("Luci immerse")
## Quanto la luce delle WaterGlowLight (es. la campana della medusa) si diffonde nel volume.
@export_range(0.0, 10.0, 0.01) var glow_scatter := 1.0

@export_group("Sott'acqua")
## Colore della nebbia vista da sott'acqua (luce diffusa nel volume).
@export_color_no_alpha var underwater_fog_color := Color(0.006, 0.03, 0.035)
## Distorsione dell'immagine da sott'acqua.
@export_range(0.0, 0.05, 0.0005) var underwater_distortion := 0.006
## Moltiplicatore dell'assorbimento per la vista da sott'acqua.
@export_range(0.0, 4.0, 0.01) var underwater_density := 1.0
