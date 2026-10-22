class_name CassaforteRotelle
extends Node3D
## La cassaforte nel muro dell'infermeria: tre rotelle con le cifre da 0 a 9, segnate testa, corpo e
## coda di agnello (i tre gruppi di puntini della radiografia sul negatoscopio). Ogni rotella è un
## Interactable: con E avanza di una cifra. Con il [member codice] giusto lo sportello si apre
## ([signal aperta]) e il [member contenuto] (la keycard, la Polaroid della pecora) si può prendere.
## Grafica provvisoria (le cifre sono Label3D) o quella vera. Lo stato si salva.

signal aperta

@export var codice := PackedInt32Array([4, 1, 7])
## Cosa c'è dentro (Interactable, di solito Pickup): si attiva quando si apre.
@export var contenuto: Array[Interactable] = []
## Distanza tra le rotelle (m, lungo X locale).
@export var passo := 0.16
## Falso: lo sportello vero ([member modello_sportello], cardini a sinistra) con le rotelle vere, cilindri
## con le cifre ([member cifre_tex]) che girano di 36 gradi a cifra, e sopra ognuna il suo simbolo
## ([member simboli]: testa, corpo, coda). Lo sportello è largo [member largo_sportello].
@export var mostra_segnaposto := true
@export var modello_sportello: PackedScene
@export var cifre_tex: Texture2D
@export var simboli: Array[Texture2D] = []
@export var largo_sportello := 0.56
## Lo spessore dello sportello vero: il nodo gira sullo spigolo davanti (i cardini), lo sportello sta dietro, così
## aprendosi non entra nella cornice del vano.
@export var spessore_sportello := 0.0
## La faccia dello sportello vero (z nel nodo dello sportello), dietro le rotelle: il loro supporto ci arriva e i
## simboli ci stanno sopra (prima restavano 3,4 cm davanti, staccati). 0: come prima.
@export var faccia_sportello := 0.0

var cifre := PackedInt32Array([0, 0, 0])
var aperta_ora := false

var _rotelle: Array[Interactable] = []
var _scritte: Array[Label3D] = []
var _sportello: Node3D
var _cilindri: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group(&"persist")
	_sportello = Node3D.new()
	_sportello.name = "Sportello"
	add_child(_sportello)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.35)
	if mostra_segnaposto or modello_sportello == null:
		Graybox.box(_sportello, Vector3(0.6, 0.5, 0.05), Vector3(0.3, 0.0, 0.0), mat)
	else:
		var porta := modello_sportello.instantiate() as Node3D
		porta.position = Vector3(largo_sportello * 0.5, 0.0, -spessore_sportello)
		_sportello.add_child(porta)
		# il supporto delle rotelle: un pezzo per rotella, suo figlio (_rotella_vera), la rotella mezza dentro
	cifre.resize(codice.size())
	var segni := ["testa", "corpo", "coda"]
	for i in codice.size():
		var r := Interactable.new()
		r.name = "Rotella%d" % (i + 1)
		r.prompt = "Gira la rotella (%s)" % (segni[i] if i < segni.size() else str(i + 1))
		var forma := CollisionShape3D.new()
		var sfera := SphereShape3D.new()
		sfera.radius = 0.06 if mostra_segnaposto else 0.044   # (vera: non entra nel supporto della rotella accanto)
		forma.shape = sfera
		r.add_child(forma)
		var scritta := Label3D.new()
		scritta.font_size = 48
		scritta.pixel_size = 0.002
		scritta.modulate = Color(0.95, 0.9, 0.7)
		r.add_child(scritta)
		_sportello.add_child(r)
		r.position = Vector3(0.3 + (i - (codice.size() - 1) * 0.5) * passo, 0.0, 0.04)
		if not mostra_segnaposto:
			scritta.visible = false
			r.position = Vector3(largo_sportello * 0.5 + (i - (codice.size() - 1) * 0.5) * passo, 0.03, 0.135 - spessore_sportello)
			_rotella_vera(r, i)
		r.interacted.connect(gira.bind(i).unbind(1))
		_rotelle.append(r)
		_scritte.append(scritta)
	_metti()


## Il cilindro con le cifre (asse lungo X, la cifra davanti verso +Z) e il simbolo sopra.
func _rotella_vera(r: Interactable, i: int) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = cifre_tex
	m.uv1_scale = Vector3(1, 2, 1)   # il lato del CylinderMesh usa solo metà della V
	m.roughness = 0.5
	var cil := MeshInstance3D.new()
	cil.name = "Cilindro"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = minf(passo, 0.09) * 0.95
	cil.mesh = cm
	cil.material_override = m
	r.add_child(cil)
	_cilindri.append(cil)
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.15, 0.15, 0.15)
	ms.metallic = 0.8
	ms.roughness = 0.4
	var zr := r.position.z
	var dietro := faccia_sportello - zr + 0.001 if faccia_sportello != 0.0 else -0.065   # 1 mm davanti alla faccia
	Graybox.box(r, Vector3(minf(passo, 0.09) - 0.01, 0.1, -0.005 - dietro), Vector3(0, 0, (dietro - 0.005) * 0.5), ms)   # 1 cm fra un pezzo e l'altro
	if i < simboli.size() and simboli[i]:
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = simboli[i]
		sm.roughness = 0.4
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.09, 0.09)
		q.mesh = qm
		q.material_override = sm
		q.position = Vector3(0, 0.13, (faccia_sportello - zr + 0.002) if faccia_sportello != 0.0 else -0.065)
		r.add_child(q)


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
		if i < _cilindri.size():
			# l'asse lungo X; ogni cifra è un decimo di giro
			_cilindri[i].transform = Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, deg_to_rad(36.0 * cifre[i])), Vector3.ZERO)
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
