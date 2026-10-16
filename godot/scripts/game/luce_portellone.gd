class_name LucePortellone
extends Node3D
## La luce del portellone sul fondo della piscina a onde (riscontro della v0.3.1, punto 3): il
## giocatore deve capire dove arrivare già dalla spiaggia, a piscina piena e torbida.
## Un anello di luce color ambra intorno al portellone (come i fari subacquei delle piscine) e una
## WaterGlowLight dell'addon acqua appena sopra: fa brillare il volume d'acqua intorno, e il bagliore
## si vede anche da fuori, attraverso la superficie. A piscina vuota resta solo l'anello, più tenue.
## Si spegne col blackout, come le altre luci della sala.
## Prova della v0.3.2 (punto 9, "la luce è sull'acqua, deve essere sotto, sul portellone"): la luce sta
## a pochi centimetri dal portellone e il bagliore nell'acqua è piccolo e raccolto intorno a lei; quello
## che si vede da sopra è soprattutto l'anello sul fondo, attraverso l'acqua.

## Il portellone (la sua mesh: il centro si prende dal suo AABB, a portellone chiuso).
@export var portellone: Node3D
## L'acqua della piscina: col livello si regola il bagliore.
@export var vasca: WaterTank
@export var colore := Color(1.0, 0.58, 0.16)
## Anello: raggio interno ed esterno (m), quanto sta sopra il portellone, quanto brilla.
@export var raggio_anello := 0.68
@export var spessore_anello := 0.09
@export var quota_anello := 0.03
@export var emissione_anello := 24.0
## La luce sopra il portellone: quota, energia e portata; il bagliore nell'acqua.
@export var quota_luce := 0.08
@export var energia := 3.0
@export var portata := 2.6
@export var bagliore := 4.0
@export var raggio_bagliore := 1.4

var centro := Vector3.ZERO
var _luce: OmniLight3D
var _anello: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	if portellone == null:
		return
	centro = _centro_portellone()
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = colore.darkened(0.3)
	_mat.emission_enabled = true
	_mat.emission = colore
	_mat.emission_energy_multiplier = emissione_anello
	_mat.roughness = 0.3
	var toro := TorusMesh.new()
	toro.inner_radius = raggio_anello
	toro.outer_radius = raggio_anello + spessore_anello
	toro.rings = 48
	toro.ring_segments = 8
	toro.material = _mat
	_anello = MeshInstance3D.new()
	_anello.name = "Anello"
	_anello.mesh = toro
	_anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_anello)
	_anello.global_position = centro + Vector3.UP * quota_anello
	# La luce dentro l'acqua: l'addon la usa anche per far brillare il volume d'acqua.
	var glow_script := load("res://addons/acqua/scripts/water_glow_light.gd") as Script
	_luce = OmniLight3D.new() if glow_script == null else glow_script.new() as OmniLight3D
	_luce.name = "LuceSubacquea"
	_luce.light_color = colore
	_luce.light_energy = energia
	_luce.omni_range = portata
	_luce.omni_attenuation = 1.4
	_luce.shadow_enabled = false
	_luce.light_volumetric_fog_energy = 0.0
	if glow_script:
		_luce.set(&"glow_strength", bagliore)
		_luce.set(&"glow_radius", raggio_bagliore)
	add_child(_luce)
	_luce.global_position = centro + Vector3.UP * quota_luce
	GameState.luci_cambiate.connect(func(_f): _aggiorna())
	_aggiorna()


## Il centro del portellone chiuso, in coordinate globali.
func _centro_portellone() -> Vector3:
	var mi := portellone as MeshInstance3D
	if mi == null:
		for c in portellone.find_children("*", "MeshInstance3D", true, false):
			mi = c as MeshInstance3D
			break
	if mi and mi.mesh:
		return mi.global_transform * mi.get_aabb().get_center()
	return portellone.global_position


## Quanta acqua copre il portellone (m): 0 a piscina vuota.
func profondita() -> float:
	if vasca == null:
		return 0.0
	return maxf(0.0, vasca.get_surface_global_y() - centro.y) if vasca.fill > 0.001 else 0.0


func _physics_process(_delta: float) -> void:
	_aggiorna()


func _aggiorna() -> void:
	if _luce == null:
		return
	var acceso := GameState.luci != GameState.Luci.BLACKOUT
	_anello.visible = acceso
	_luce.visible = acceso
	# A piscina vuota niente bagliore nell'acqua, luce più bassa: il portellone si vede già.
	var k := clampf(profondita() / 0.3, 0.0, 1.0)
	_luce.light_energy = energia * (0.45 + 0.55 * k)
	if _luce.has_method(&"get_glow_rows"):
		_luce.set(&"glow_strength", bagliore * k)
	_mat.emission_energy_multiplier = emissione_anello * (0.5 + 0.5 * k)
