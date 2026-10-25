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
## Di quanto sta spostato il gruppo delle rotelle vere lungo X, dal centro dello sportello (m): per lasciare libera la
## maniglia dello sportello.
@export var spostamento_rotelle := 0.0
## Falso: lo sportello vero ([member modello_sportello], cardini a sinistra) con le rotelle vere: tamburi di metallo
## con le cifre stampate ([member cifre_tex]) che girano di 36 gradi a cifra, i tappi lisci, ognuno nella sua forcella con
## la finestrella che inquadra la cifra di adesso, e sopra il suo simbolo ([member simboli]: testa, corpo, coda). Lo
## sportello è largo [member largo_sportello].
## La texture delle cifre: dieci celle in fila lungo la U (la circonferenza), la cifra n nella cella n, con l'alto verso
## la U che cala; il CylinderMesh mette la U = 0 a +Z e la fa crescere verso +X. Davanti (+Z, verso chi guarda) c'è il
## centro della cella [member cifre][i], dritto: vedi [method giro_rotella].
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
## Quanto sta il pavimento sotto l'origine (m). Aperto, lo sportello sporge nella stanza all'altezza del petto: con
## un valore, sotto lo sportello aperto c'è una barriera fino a terra e non ci si passa (come sotto i cassetti tirati).
## 0: niente barriera.
@export var barriera_fino_a_terra := 0.0

var cifre := PackedInt32Array([0, 0, 0])
var aperta_ora := false

var _rotelle: Array[Interactable] = []
var _scritte: Array[Label3D] = []
var _sportello: Node3D
var _cilindri: Array[MeshInstance3D] = []
var _barriera: StaticBody3D

## Il raggio del tamburo, lo spessore dei tappi, delle guance e della mascherina, e metà dell'altezza della finestrella
## (una cifra è un decimo di giro: 2 x 0,06 x sin 18° = 3,7 cm).
const RAGGIO := 0.06
const TAPPO := 0.005
const GUANCIA := 0.006
const MASCHERINA := 0.008
const FINESTRA := 0.02


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
		r.prompt = tr("Gira la rotella (%s)") % (tr(segni[i]) if i < segni.size() else str(i + 1))
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
			r.position = Vector3(largo_sportello * 0.5 + spostamento_rotelle + (i - (codice.size() - 1) * 0.5) * passo, 0.03, 0.135 - spessore_sportello)
			_rotella_vera(r, i)
		r.interacted.connect(gira.bind(i).unbind(1))
		_rotelle.append(r)
		_scritte.append(scritta)
	if barriera_fino_a_terra > 0.0:
		_metti_barriera()
	_metti()


## La barriera sotto lo sportello aperto: dal pavimento al suo bordo di sopra, larga quanto lo sportello aperto.
func _metti_barriera() -> void:
	var giro := _sportello.rotation
	_sportello.rotation = Vector3(0.0, -1.9, 0.0)
	var b := AABB()
	var primo := true
	for mi in _sportello.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var k: Node = mi
		while k != self:
			xf = (k as Node3D).transform * xf
			k = k.get_parent()
		var bb: AABB = xf * (mi as MeshInstance3D).get_aabb()
		b = bb if primo else b.merge(bb)
		primo = false
	_sportello.rotation = giro
	_barriera = StaticBody3D.new()
	_barriera.name = "BarrieraSportello"
	_barriera.collision_layer = Layers.BARRIERS
	_barriera.collision_mask = 0
	var f := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(b.size.x, b.end.y + barriera_fino_a_terra, b.size.z)
	f.shape = bs
	f.position = Vector3(b.get_center().x, (b.end.y - barriera_fino_a_terra) * 0.5, b.get_center().z)
	_barriera.add_child(f)
	add_child(_barriera)


## Il tamburo con le cifre (asse lungo X, la cifra davanti verso +Z), i tappi, la forcella con la finestrella e il simbolo
## sopra.
func _rotella_vera(r: Interactable, i: int) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = cifre_tex
	m.uv1_scale = Vector3(1, 2, 1)   # il lato del CylinderMesh usa solo metà della V (l'altra metà è dei tappi, che qui non ci sono)
	m.metallic = 0.6
	m.roughness = 0.35
	var cil := MeshInstance3D.new()
	cil.name = "Cilindro"
	var cm := CylinderMesh.new()
	cm.top_radius = RAGGIO
	cm.bottom_radius = RAGGIO
	cm.height = minf(passo, 0.09) * 0.95
	# niente tappi col materiale delle cifre (le cifre finivano anche di lato): i tappi sono dischi di metallo liscio
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 40
	cil.mesh = cm
	cil.material_override = m
	r.add_child(cil)
	_cilindri.append(cil)
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.15, 0.15, 0.15)
	ms.metallic = 0.8
	ms.roughness = 0.4
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.55, 0.56, 0.57)
	mt.metallic = 0.85
	mt.roughness = 0.3
	var td := CylinderMesh.new()
	td.top_radius = RAGGIO + 0.001
	td.bottom_radius = RAGGIO + 0.001
	td.height = TAPPO
	td.radial_segments = 40
	for lato in [-1.0, 1.0]:
		var t := MeshInstance3D.new()
		t.name = "Tappo"
		t.mesh = td
		t.material_override = mt
		t.position = Vector3(0, lato * (cm.height + TAPPO) * 0.5, 0)   # a filo della fine del tamburo, fuori
		cil.add_child(t)
	var zr := r.position.z
	var dietro := faccia_sportello - zr + 0.001 if faccia_sportello != 0.0 else -0.065   # 1 mm davanti alla faccia
	Graybox.box(r, Vector3(minf(passo, 0.09) - 0.01, 0.1, -0.005 - dietro), Vector3(0, 0, (dietro - 0.005) * 0.5), ms)   # 1 cm fra un pezzo e l'altro
	# la custodia: due guance dalla faccia dello sportello a poco davanti al tamburo, 1 mm fuori dai tappi, il coperchio
	# sopra e sotto (da sopra si vedevano le altre cifre), e davanti la mascherina d'acciaio chiaro con la finestrella
	# alta una cifra; niente collisione, la rotella si gira da davanti. È un pezzo della rotella: col suo ingombro (quello
	# del tasto E e del controllo di posizionamento) dentro, con lo sportello aperto e girato non la "tocca"
	var mezzo := cm.height * 0.5 + TAPPO
	var davanti := RAGGIO + 0.004
	var alto := RAGGIO + 0.0075
	for lato in [-1.0, 1.0]:
		var g := Graybox.box(r, Vector3(GUANCIA, 2.0 * alto, davanti + MASCHERINA - dietro),
				Vector3(lato * (mezzo + 0.001 + GUANCIA * 0.5), 0, (davanti + MASCHERINA + dietro) * 0.5), ms)
		g.name = "Guancia"
		var c := Graybox.box(r, Vector3(2.0 * (mezzo + 0.001), GUANCIA, davanti - dietro),
				Vector3(0, lato * (alto - GUANCIA * 0.5), (davanti + dietro) * 0.5), ms)
		c.name = "Coperchio"
		var b := Graybox.box(r, Vector3(2.0 * (mezzo + 0.001), alto - FINESTRA, MASCHERINA),
				Vector3(0, lato * (FINESTRA + alto) * 0.5, davanti + MASCHERINA * 0.5), mt)
		b.name = "Mascherina"
	# il simbolo sopra è dello sportello, non della rotella (dentro il suo ingombro arrivava alla custodia accanto)
	if i < simboli.size() and simboli[i]:
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = simboli[i]
		sm.roughness = 0.4
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.09, 0.09)
		q.mesh = qm
		q.material_override = sm
		q.name = "Simbolo%d" % (i + 1)
		q.position = r.position + Vector3(0, 0.13, (faccia_sportello - zr + 0.002) if faccia_sportello != 0.0 else -0.065)
		_sportello.add_child(q)


## Come sta il tamburo con la cifra [param n] davanti: l'asse del CylinderMesh (Y) lungo +X, poi un decimo di giro a
## cifra attorno all'asse, in modo che a +Z ci sia il centro della cella n della texture, U = (n + 0,5) / 10. Con l'asse
## verso +X la U che cresce scende sul davanti, e l'alto delle cifre (la U che cala) sta in alto: si leggono dritte.
## Passando alla cifra dopo il davanti del tamburo sale, come in un contachilometri: la cifra nuova arriva da sotto.
## (Prima: asse verso -X e nessuna mezza cella, così davanti c'era il confine fra due cifre, contate al contrario e
## capovolte; con le rotelle a 4-1-7 a vista la cassaforte non si apriva.)
static func giro_rotella(n: int) -> Basis:
	return Basis(Vector3.BACK, -PI * 0.5) * Basis(Vector3.UP, -TAU * (n + 0.5) / 10.0)


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
			_cilindri[i].transform = Transform3D(giro_rotella(cifre[i]), Vector3.ZERO)
	# Aperta, lo sportello gira sui cardini a sinistra.
	_sportello.rotation = Vector3(0.0, -1.9 if aperta_ora else 0.0, 0.0)
	for c in contenuto:
		if is_instance_valid(c):
			c.enabled = aperta_ora
			c.visible = aperta_ora
	if _barriera:
		for c in _barriera.get_children():
			(c as CollisionShape3D).set_deferred(&"disabled", not aperta_ora)


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"cifre": Array(cifre), "aperta": aperta_ora}


func load_state(data: Dictionary) -> void:
	var c: Array = data.get("cifre", [])
	for i in mini(c.size(), cifre.size()):
		cifre[i] = int(c[i])
	aperta_ora = bool(data.get("aperta", false))
	_metti()
