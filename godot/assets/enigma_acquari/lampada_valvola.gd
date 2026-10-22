extends Node3D
## La lampada di servizio a gabbia che illumina la valvola rossa del gorgo (prova dell'utente del 19
## ottobre: "illuminare la valvola di reset che non si vede"). È la stessa lampada a gabbia del fiume
## lento, stretta al tirante dell'acquario blu e girata verso la valvola: qui si accende il globo
## (la luce vera è lo SpotLight3D accanto).

@export var colore := Color(1.0, 0.85, 0.6)
@export var energia := 8.0


func _ready() -> void:
	var g := find_child("globo", true, false) as MeshInstance3D
	if g == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.9, 0.7)
	m.emission_enabled = true
	m.emission = colore
	m.emission_energy_multiplier = energia
	m.roughness = 0.3
	g.material_override = m
