extends Node3D
## Proposta d'aspetto del lettore della keycard accanto alla serranda del magazzino (enigma-ambiente,
## 19 ottobre): il modello Meshy sul muro, con la spia che si vede al buio, rossa finché è bloccato e
## verde dopo la keycard. Guarda verso +Z (il retro del modello sta sul muro, nell'origine).
## variante 1: lettore a strisciata anni '90, plastica beige, spia tonda in alto;
## variante 2: lettore industriale d'acciaio, anello luminoso intorno al riquadro di lettura.
## Per la scena vera: questo nodo sotto LettoreTessera (con mostra_segnaposto falso), che ne cambia
## il colore.

@export_enum("1", "2") var variante := "1"
@export var sbloccato := false
const ROSSO := Color(1.0, 0.08, 0.05)
const VERDE := Color(0.1, 1.0, 0.25)

var _mat: StandardMaterial3D
var _luce: OmniLight3D


func _ready() -> void:
	var m := (load("res://assets/tessera/lettore_%s.glb" % variante) as PackedScene).instantiate() as Node3D
	m.scale = Vector3.ONE * 1.3   # 13 cm: si legge meglio da lontano
	add_child(m)
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = 2.5
	var spia := MeshInstance3D.new()
	spia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if variante == "1":
		var c := CylinderMesh.new()
		c.top_radius = 0.011
		c.bottom_radius = 0.011
		c.height = 0.004
		spia.mesh = c
		spia.rotation_degrees.x = 90.0
		spia.position = Vector3(-0.008, 0.026, 0.092)
	else:
		var t := TorusMesh.new()
		t.inner_radius = 0.021
		t.outer_radius = 0.026
		spia.mesh = t
		spia.rotation_degrees.x = 90.0
		spia.position = Vector3(0.0, 0.0, 0.055)
	spia.material_override = _mat
	add_child(spia)
	if variante == "2":
		# nel 2 si accende anche la finestrella di stato in alto
		var st := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.06, 0.028)
		st.mesh = q
		st.material_override = _mat
		st.position = Vector3(0.0, 0.085, 0.053)
		add_child(st)
	# il tubo dei cavi che sale lungo il muro dalla scatola (nel modello 1 c'è solo il raccordo)
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
	tubo.position = Vector3(0.0, 0.13 + 0.7, 0.02) if variante == "1" else Vector3(0.0, -0.15 - 0.7, 0.02)
	add_child(tubo)
	_luce = OmniLight3D.new()
	# la luce un po' davanti: illumina il muro intorno senza bruciare la scatola
	_luce.position = spia.position + Vector3(0, 0, 0.35)
	_luce.omni_range = 1.8
	_luce.light_energy = 0.6
	_luce.shadow_enabled = false
	add_child(_luce)
	colora(sbloccato)


func colora(verde: bool) -> void:
	sbloccato = verde
	var c := VERDE if verde else ROSSO
	if _mat:
		_mat.albedo_color = c
		_mat.emission = c
	if _luce:
		_luce.light_color = c
