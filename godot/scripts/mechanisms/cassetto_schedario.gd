class_name CassettoSchedario
extends Interactable
## Un cassetto dello schedario dell'infermeria: con E si apre (scorre in fuori) e resta aperto. Quello
## giusto ha l'adesivo rosa fosforescente ([member adesivo]: si vede al buio, come nella Polaroid del
## medico) e dentro ha la radiografia ([member contenuto], un Pickup che si può prendere solo a
## cassetto aperto). Grafica provvisoria. Lo stato si salva.

signal aperto_ora

## L'adesivo rosa fosforescente sul frontale.
@export var adesivo := false
## Cosa c'è dentro (un Pickup, figlio o no): si attiva quando il cassetto si apre.
@export var contenuto: Interactable
## Di quanto scorre in fuori (m, lungo +Z locale).
@export var corsa := 0.4

var aperto := false

var _frontale: Node3D


func _init() -> void:
	super()
	prompt = "Apri"


func _ready() -> void:
	add_to_group(&"persist")
	_frontale = Node3D.new()
	_frontale.name = "Frontale"
	add_child(_frontale)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.57, 0.6)
	Graybox.box(_frontale, Vector3(0.45, 0.28, 0.03), Vector3.ZERO, mat)
	if adesivo:
		var ma := StandardMaterial3D.new()
		ma.albedo_color = Color(1.0, 0.4, 0.75)
		ma.emission_enabled = true
		ma.emission = Color(1.0, 0.4, 0.75)
		ma.emission_energy_multiplier = 1.5
		Graybox.box(_frontale, Vector3(0.08, 0.08, 0.005), Vector3(0.12, 0.06, 0.02), ma)
	_metti()


func can_interact(by: Node) -> bool:
	return enabled and not aperto and by is Player


func _on_interact(_by: Node) -> void:
	aperto = true
	_metti()
	aperto_ora.emit()


func _metti() -> void:
	_frontale.position = Vector3(0.0, 0.0, corsa if aperto else 0.0)
	if is_instance_valid(contenuto):
		contenuto.enabled = aperto
		contenuto.visible = aperto


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"aperto": aperto}


func load_state(data: Dictionary) -> void:
	aperto = bool(data.get("aperto", false))
	_metti()
