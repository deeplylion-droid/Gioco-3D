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
## Quanto c'è dal centro del cassetto al pavimento: aperto, sotto il cassetto tirato fuori non si passa (barriera
## che ferma il giocatore, non il raggio del tasto E). 0: niente barriera.
@export var fino_a_terra := 0.0
## Falso: il cassetto vero sta nel modello dello schedario; qui c'è il cassetto tirato fuori (frontale,
## fianchi e fondo, misura [member misura], tinta [member tinta]) che si vede solo aperto. L'adesivo
## vero lo mette la scena dentro "Frontale", e si muove col cassetto.
@export var mostra_segnaposto := true
@export var misura := Vector3(0.36, 0.22, 0.4)
@export var tinta := Color(1.0, 0.8, 0.86)

var aperto := false

var _frontale: Node3D
var _tirato: Node3D
var _barriera: StaticBody3D


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
	if not mostra_segnaposto:
		_vassoio()
		_metti()
		return
	Graybox.box(_frontale, Vector3(0.45, 0.28, 0.03), Vector3.ZERO, mat)
	if adesivo:
		var ma := StandardMaterial3D.new()
		ma.albedo_color = Color(1.0, 0.4, 0.75)
		ma.emission_enabled = true
		ma.emission = Color(1.0, 0.4, 0.75)
		ma.emission_energy_multiplier = 1.5
		Graybox.box(_frontale, Vector3(0.08, 0.08, 0.005), Vector3(0.12, 0.06, 0.02), ma)
	_metti()


## Il cassetto tirato fuori: si vede solo aperto (chiuso c'è quello del modello).
func _vassoio() -> void:
	_tirato = Node3D.new()
	_tirato.name = "Tirato"
	_frontale.add_child(_tirato)
	var m := StandardMaterial3D.new()
	m.albedo_color = tinta
	m.metallic = 0.3
	m.roughness = 0.55
	var dentro := StandardMaterial3D.new()
	dentro.albedo_color = tinta * 0.55
	dentro.roughness = 0.8
	var s := misura
	# il davanti a filo del frontale del modello (2 mm dietro l'origine), così l'adesivo sta sopra tutti e due
	Graybox.box(_tirato, Vector3(s.x, s.y, 0.02), Vector3(0, 0, -0.012), m)
	Graybox.box(_tirato, Vector3(s.x - 0.02, 0.01, s.z), Vector3(0, -s.y * 0.5 + 0.03, -s.z * 0.5), dentro)
	for lato in [-1.0, 1.0]:
		Graybox.box(_tirato, Vector3(0.01, s.y * 0.7, s.z), Vector3(lato * (s.x * 0.5 - 0.01), -s.y * 0.12, -s.z * 0.5), dentro)
	# la maniglia
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.75, 0.75, 0.72)
	mm.metallic = 0.9
	mm.roughness = 0.3
	Graybox.box(_tirato, Vector3(0.1, 0.025, 0.03), Vector3(0, s.y * 0.15, 0.013), mm)
	if fino_a_terra > 0.0:
		_barriera = StaticBody3D.new()
		_barriera.name = "Barriera"
		_barriera.collision_layer = Layers.BARRIERS
		_barriera.collision_mask = 0
		var fb := CollisionShape3D.new()
		var bb := BoxShape3D.new()
		bb.size = Vector3(s.x + 0.02, fino_a_terra + s.y * 0.5, corsa)
		fb.shape = bb
		fb.position = Vector3(0, (s.y * 0.5 - fino_a_terra) * 0.5, corsa * 0.5)
		_barriera.add_child(fb)
		add_child(_barriera)


func can_interact(by: Node) -> bool:
	return enabled and not aperto and by is Player


func _on_interact(_by: Node) -> void:
	aperto = true
	_metti()
	aperto_ora.emit()


func _metti() -> void:
	_frontale.position = Vector3(0.0, 0.0, corsa if aperto else 0.0)
	if _tirato:
		_tirato.visible = aperto
	# aperto, il cassetto non ferma più il raggio del tasto E (dentro c'è da prendere il contenuto)
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred(&"disabled", aperto)
	if is_instance_valid(contenuto):
		contenuto.enabled = aperto
		contenuto.visible = aperto
	if _barriera:
		for c in _barriera.get_children():
			(c as CollisionShape3D).set_deferred(&"disabled", not aperto)


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"aperto": aperto}


func load_state(data: Dictionary) -> void:
	aperto = bool(data.get("aperto", false))
	_metti()
