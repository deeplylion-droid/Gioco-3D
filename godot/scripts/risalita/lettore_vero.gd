extends Node3D
## L'aspetto vero del lettore della keycard accanto alla serranda del magazzino (scelta dell'utente del
## 19 ottobre: il lettore 1, a strisciata anni '90, plastica beige, spia tonda in alto), dalla proposta
## approvata (proposte/tessera_aspetto/lettore_aspetto.gd). Va sotto LettoreTessera (con
## mostra_segnaposto falso), che lo colora con [method colora] e lo fa lampeggiare con [method luce].
## La luce verde è più debole che negli scatti della proposta (riscontro dell'utente). Guarda verso +Z
## (il retro del modello sta sul muro, nell'origine).

const ROSSO := Color(1.0, 0.08, 0.05)
const VERDE := Color(0.1, 1.0, 0.25)
## Quanto si accendono la spia e la sua luce, rossa e verde (la verde più debole).
const EMISSIONE := {"rosso": 2.5, "verde": 1.1}
const LUCE := {"rosso": 0.6, "verde": 0.22}

var sbloccato := false

var _mat: StandardMaterial3D
var _luce: OmniLight3D


func _ready() -> void:
	var m := (load("res://assets/tessera/lettore_1.glb") as PackedScene).instantiate() as Node3D
	m.scale = Vector3.ONE * 1.3   # 13 cm: si legge meglio da lontano
	add_child(m)
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	var spia := MeshInstance3D.new()
	spia.name = "Spia"
	spia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var c := CylinderMesh.new()
	c.top_radius = 0.011
	c.bottom_radius = 0.011
	c.height = 0.004
	spia.mesh = c
	spia.rotation_degrees.x = 90.0
	spia.position = Vector3(-0.008, 0.026, 0.092)
	spia.material_override = _mat
	add_child(spia)
	# il tubo dei cavi che sale lungo il muro dalla scatola (nel modello c'è solo il raccordo)
	var tubo := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.011
	tm.bottom_radius = 0.011
	tm.height = 1.4
	tubo.mesh = tm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.3, 0.31, 0.3)
	mt.metallic = 0.6
	mt.roughness = 0.5
	tubo.material_override = mt
	tubo.position = Vector3(0.0, 0.13 + 0.7, 0.02)
	add_child(tubo)
	_luce = OmniLight3D.new()
	_luce.name = "Luce"
	# un po' davanti: illumina il muro intorno senza bruciare la scatola
	_luce.position = spia.position + Vector3(0, 0, 0.35)
	_luce.omni_range = 1.8
	_luce.shadow_enabled = false
	_luce.set_meta(&"risveglio_ignora", true)
	add_child(_luce)
	colora(sbloccato)


func colora(verde: bool) -> void:
	sbloccato = verde
	luce(1.0)


## La spia accesa a [param k] (1 piena, meno durante il lampeggio del rifiuto).
func luce(k: float) -> void:
	if _mat == null:
		return
	var c := VERDE if sbloccato else ROSSO
	var nome := "verde" if sbloccato else "rosso"
	_mat.albedo_color = c
	_mat.emission = c
	_mat.emission_energy_multiplier = float(EMISSIONE[nome]) * k
	_luce.light_color = c
	_luce.light_energy = float(LUCE[nome]) * k
