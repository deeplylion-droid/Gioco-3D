class_name MascotteSala
extends Node3D
## Le statue-mascotte e il nome di Jilly Jubilee nella sala principale (scelte dell'utente del 19
## ottobre, docs/riscontri/2026-10-19_scelte.md; GDD, "Nuove mascotte" e "Il suo nome è Jilly Jubilee").
## - Statue di vetroresina: lo squalo A in S2, sul bordo est della piscina a onde accanto alla sedia del
##   bagnino; il polpo A in A3, all'ingresso dell'area bimbi; il polpo B in B1, nell'area bimbi contro il
##   muro ovest accanto al fungo. Hanno una collisione che segue la forma della statua.
## - Stile B, molto invecchiato (assets_src/mascotte/jilly_gioco.py): la targa sul lato ovest della vasca
##   di Jilly, il manifesto dello spettacolo sul muro ovest vicino all'ingresso, l'insegna in alto sul muro
##   ovest sopra la vasca d'arrivo con le sue due lampade a collo d'oca (luce calda e debole solo sul
##   pannello; al blackout si spengono come le altre luci della sala).
## Posizioni: quelle degli scatti approvati (docs/proposte/mascotte/), con il pavimento e le pareti
## trovati da proposte/mascotte/sonda_posti.gd.

const STATUE := [
	{nome = &"StatuaSqualo", modello = "res://assets/models/mascotte/statua_squalo_A.glb",
		pos = Vector3(10.0, 0.0, 1.5), gradi = -90.0},
	{nome = &"StatuaPolpoA", modello = "res://assets/models/mascotte/statua_polpo_A.glb",
		pos = Vector3(-5.5, 0.0, -18.0), gradi = -12.0},
	{nome = &"StatuaPolpoB", modello = "res://assets/models/mascotte/statua_polpo_B.glb",
		pos = Vector3(-18.3, 0.0, -8.0), gradi = 90.0},
]
## Oggetti da parete: il retro (z = 0 del modello) sulla parete, il davanti verso [code]normale[/code]. Il
## manifesto sta 3 cm fuori dalla collisione: le piastrelle visibili sporgono.
const JILLY := [
	{nome = &"TargaJilly", modello = "res://assets/models/mascotte/jilly/targa.glb",
		pos = Vector3(-3.003, 0.62, 10.0), normale = Vector3(-1, 0, 0)},
	{nome = &"ManifestoJilly", modello = "res://assets/models/mascotte/jilly/manifesto.glb",
		pos = Vector3(-19.97, 1.4, 13.95), normale = Vector3(1, 0, 0)},
	{nome = &"InsegnaJilly", modello = "res://assets/models/mascotte/jilly/insegna.glb",
		pos = Vector3(-19.997, 4.7, 5.35), normale = Vector3(1, 0, 0)},
]

## Energia delle due lampade dell'insegna (come negli scatti approvati).
@export var energia_lampade := 1.4

var _lampade: Array[SpotLight3D] = []
var _lampadine: Array[MeshInstance3D] = []
var _lampadina_spenta: StandardMaterial3D


func _ready() -> void:
	for s in STATUE:
		_metti_statua(s)
	for j in JILLY:
		var ob := (load(j.modello) as PackedScene).instantiate() as Node3D
		ob.name = j.nome
		add_child(ob)
		ob.transform = Transform3D(Basis.looking_at(-j.normale, Vector3.UP), j.pos)
		_accendi_lampade(ob)
	GameState.luci_cambiate.connect(func(_f): _aggiorna_lampade())
	_aggiorna_lampade()


func _metti_statua(s: Dictionary) -> void:
	var st := (load(s.modello) as PackedScene).instantiate() as Node3D
	st.name = s.nome
	add_child(st)
	st.position = s.pos
	st.rotation.y = deg_to_rad(s.gradi)
	# Collisione con la forma vera della statua (mondo: ferma il giocatore e il getto).
	var corpo := StaticBody3D.new()
	corpo.name = "Collisione"
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	st.add_child(corpo)
	for mi in st.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var cs := CollisionShape3D.new()
		cs.shape = m.create_trimesh_shape()
		corpo.add_child(cs)
		cs.global_transform = (mi as MeshInstance3D).global_transform


## Le lampade a collo d'oca dell'insegna: gli empty luce_* del modello diventano faretti caldi e deboli
## puntati al pannello.
func _accendi_lampade(ob: Node3D) -> void:
	for e in ob.find_children("luce_*", "Node3D", true, false):
		var l := SpotLight3D.new()
		l.name = "Faretto"
		l.light_color = Color(1.0, 0.72, 0.42)
		l.light_energy = energia_lampade
		l.spot_range = 2.0
		l.spot_angle = 40.0
		l.spot_attenuation = 1.2
		l.shadow_enabled = true
		l.light_volumetric_fog_energy = 0.3
		(e as Node3D).add_child(l)
		var loc := ob.to_local((e as Node3D).global_position)
		l.look_at(ob.to_global(Vector3(loc.x * 0.4, -0.05, 0.15)), ob.global_basis.y)
		_lampade.append(l)
	for mi in ob.find_children("*lampadina*", "MeshInstance3D", true, false):
		_lampadine.append(mi as MeshInstance3D)


func _aggiorna_lampade() -> void:
	var accese := GameState.luci != GameState.Luci.BLACKOUT
	for l in _lampade:
		l.visible = accese
	if _lampadina_spenta == null:
		_lampadina_spenta = StandardMaterial3D.new()
		_lampadina_spenta.albedo_color = Color(0.35, 0.3, 0.24)
		_lampadina_spenta.roughness = 0.3
	for mi in _lampadine:
		mi.material_override = null if accese else _lampadina_spenta


## Le lampade accese (per i test).
func lampade_accese() -> int:
	return _lampade.filter(func(l: SpotLight3D): return l.visible).size()
