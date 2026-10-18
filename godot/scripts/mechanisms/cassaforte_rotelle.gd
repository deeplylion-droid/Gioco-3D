class_name CassaforteRotelle
extends Node3D
## La cassaforte nel muro dell'infermeria: tre rotelle con le cifre da 0 a 9, segnate testa, corpo e
## coda di agnello (i tre gruppi di puntini della radiografia sul negatoscopio). Ogni rotella è un
## Interactable: con E avanza di una cifra. Con il [member codice] giusto lo sportello si apre
## ([signal aperta]) e il [member contenuto] (la keycard, la Polaroid della pecora) si può prendere.
## Grafica provvisoria: le cifre sono Label3D. Lo stato si salva.

signal aperta

@export var codice := PackedInt32Array([4, 1, 7])
## Cosa c'è dentro (Interactable, di solito Pickup): si attiva quando si apre.
@export var contenuto: Array[Interactable] = []
## Distanza tra le rotelle (m, lungo X locale).
@export var passo := 0.16

var cifre := PackedInt32Array([0, 0, 0])
var aperta_ora := false

var _rotelle: Array[Interactable] = []
var _scritte: Array[Label3D] = []
var _sportello: Node3D


func _ready() -> void:
	add_to_group(&"persist")
	_sportello = Node3D.new()
	_sportello.name = "Sportello"
	add_child(_sportello)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.35)
	Graybox.box(_sportello, Vector3(0.6, 0.5, 0.05), Vector3(0.3, 0.0, 0.0), mat)
	cifre.resize(codice.size())
	var segni := ["testa", "corpo", "coda"]
	for i in codice.size():
		var r := Interactable.new()
		r.name = "Rotella%d" % (i + 1)
		r.prompt = "Gira la rotella (%s)" % (segni[i] if i < segni.size() else str(i + 1))
		var forma := CollisionShape3D.new()
		var sfera := SphereShape3D.new()
		sfera.radius = 0.06
		forma.shape = sfera
		r.add_child(forma)
		var scritta := Label3D.new()
		scritta.font_size = 48
		scritta.pixel_size = 0.002
		scritta.modulate = Color(0.95, 0.9, 0.7)
		r.add_child(scritta)
		_sportello.add_child(r)
		r.position = Vector3(0.3 + (i - (codice.size() - 1) * 0.5) * passo, 0.0, 0.04)
		r.interacted.connect(gira.bind(i).unbind(1))
		_rotelle.append(r)
		_scritte.append(scritta)
	_metti()


func rotella(i: int) -> Interactable:
	return _rotelle[i]


## Avanza di una cifra la rotella [param i] (0..9 e poi di nuovo 0).
func gira(i: int) -> void:
	if aperta_ora:
		return
	cifre[i] = (cifre[i] + 1) % 10
	_metti()
	if cifre == codice:
		aperta_ora = true
		_metti()
		aperta.emit()


func _metti() -> void:
	for i in _scritte.size():
		_scritte[i].text = str(cifre[i])
		_rotelle[i].enabled = not aperta_ora
	# Aperta, lo sportello gira sui cardini a sinistra.
	_sportello.rotation = Vector3(0.0, -1.9 if aperta_ora else 0.0, 0.0)
	for c in contenuto:
		if is_instance_valid(c):
			c.enabled = aperta_ora
			c.visible = aperta_ora


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"cifre": Array(cifre), "aperta": aperta_ora}


func load_state(data: Dictionary) -> void:
	var c: Array = data.get("cifre", [])
	for i in mini(c.size(), cifre.size()):
		cifre[i] = int(c[i])
	aperta_ora = bool(data.get("aperta", false))
	_metti()
