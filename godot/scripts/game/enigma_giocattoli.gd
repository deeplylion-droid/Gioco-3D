class_name EnigmaGiocattoli
extends Node3D
## L'enigma dei giocattoli nella piscina a onde (tappa 5; GDD, scelte del 28 ottobre: idea A "I giocattoli al loro
## posto", docs/proposte/enigma_nuovo/ e docs/proposte/enigma_giocattoli/). Sul fondo della parte profonda, attorno
## alla botola, ci sono tre cerchi di mosaico (giallo, rosso, blu): sono piatti che scendono col peso, la serratura
## della botola. Nella pozza galleggiano tre giocattoli grandi, di gomma e mezzi pieni d'acqua: la paperella gialla,
## il pallone rosso e la balena blu. Il disegno a pastello dei bambini sul muro della parte profonda mostra ognuno nel
## suo cerchio.
## - Col getto li spingi: sull'acqua e, a piscina vuota, anche sul fondo, un po' più piano (nota dell'utente: "ma
##   facciamo che puoi spingere i giocattoli anche una volta che hai svuotato la piscina"). Più sei vicino più spinge.
##   Vicino al suo cerchio un giocattolo ci scivola dentro da solo.
## - Un giocattolo sul suo cerchio lo accende appena (il bordo fosforescente); appoggiato sul fondo asciutto il piatto
##   scende col tonfo e il bordo si accende tutto, e il giocattolo resta lì.
## - L'ordine è libero: prima i giocattoli e poi lo svuotamento (scendono quando l'acqua cala) o il contrario.
## - Scesi tutti e tre, un risucchio lungo dagli scarichi e la luce del pulsante della botola passa da gialla a verde:
##   colpito col getto, la botola si apre come prima (PiscinaOnde, [member PiscinaOnde.serratura]).
## Lo stato (posti dei giocattoli e piatti scesi) si salva con i checkpoint.
## I nodi figli hanno nomi fissi: Cerchi/CerchioGiallo, Cerchi/CerchioRosso, Cerchi/CerchioBlu, Giocattoli/Paperella,
## Giocattoli/Pallone, Giocattoli/Balena, Disegno. I modelli e i materiali veri (ambienti-1, lavoro/enigma-giocattoli-
## modelli) sono in [constant DIR]: finché non ci sono, segnaposto semplici con le stesse misure.

signal piatto_sceso(indice: int)
signal risolto
## Un giocattolo è arrivato sul suo cerchio (galleggiando o sul fondo): il bordo si accende appena.
signal cerchio_acceso(indice: int)

const DIR := "res://assets/models/enigma_giocattoli/"
const NOMI_CERCHI := ["CerchioGiallo", "CerchioRosso", "CerchioBlu"]
const NOMI_GIOCATTOLI := ["Paperella", "Pallone", "Balena"]
const FILE_GIOCATTOLI := ["paperella.glb", "pallone.glb", "balena.glb"]
const FILE_CERCHI := ["cerchio_giallo.tres", "cerchio_rosso.tres", "cerchio_blu.tres"]
const COLORI := [Color(1.0, 0.82, 0.12), Color(0.86, 0.12, 0.1), Color(0.12, 0.36, 0.9)]
## Le forme dei giocattoli per le collisioni fra loro e coi bordi: raggio in pianta, altezza, pescaggio (quanto
## affondano galleggiando: sono mezzi pieni d'acqua).
const RAGGI := [0.22, 0.25, 0.3]
const ALTEZZE := [0.39, 0.5, 0.38]
const PESCAGGI := [0.13, 0.17, 0.12]
## L'impronta sul fondo (mezze misure in x e z, nel sistema del giocattolo): dove appoggia la base.
const IMPRONTE := [Vector2(0.14, 0.2), Vector2(0.1, 0.1), Vector2(0.18, 0.3)]
## Quanto sopra la superficie restano appoggiati (sotto i 5 mm del controllo di posizionamento: toccano).
const STACCO := 0.003

## L'acqua della parte profonda (la Pozza).
@export var vasca: WaterTank
## La piscina a onde (svuotamento, pulsante e lampeggiante della botola).
@export var piscina: PiscinaOnde
## I centri dei tre cerchi (giallo, rosso, blu), nel sistema del nodo: x e z; la quota la trova Posa sul fondo.
@export var cerchi: Array[Vector3] = [Vector3(-3.9, 0, 3.3), Vector3(3.9, 0, 3.3), Vector3(-3.9, 0, -0.1)]
## Dove galleggiano i giocattoli all'inizio (x, z) e come sono girati (y, in gradi), nel sistema del nodo.
@export var partenze: Array[Vector3] = [Vector3(0.4, 30, 0.6), Vector3(4.4, 0, -0.6), Vector3(-0.2, 120, -0.8)]
## Dove possono andare i giocattoli in pianta (la parte profonda): x e z minimi, larghezza e lunghezza, nel sistema del
## nodo. Lontano dai muri (x ±7, z 5) quanto basta perché il giocatore si metta fra il giocattolo e il muro e lo
## spinga via: arrivava a 40 cm dai muri, e negli angoli e sotto le scalette un giocattolo restava incastrato (collaudo
## di ambienti-2, 29 ottobre). A nord è la pendenza verso la spiaggia, dove si cammina.
@export var area := Rect2(-5.9, -3.5, 11.8, 7.45)
## Posti da lasciare liberi sul fondo (x, z, raggio, nel sistema del nodo): la ripartenza del checkpoint della pozza
## vuota (le scalette sono fuori dall'[member area]). La P5 la si tiene libera da sola finché c'è ([member polaroid]), e
## i gonfiabili già sul fondo (i MeshInstance3D "ogg_*" della sala nella parte profonda) sono ostacoli
## ([method _ostacoli_fondo]). Valgono solo per i giocattoli appoggiati sul fondo: galleggiando ci passano sopra.
@export var liberi: Array[Vector3] = [Vector3(1.4, 0.4, 0.45)]
## La sala (per trovare i gonfiabili sul fondo).
@export var sala: Node3D
## La Polaroid sul fondo (P5): finché c'è, i giocattoli non ci vanno sopra.
@export var polaroid: Node3D

## Il disegno dei bambini sul muro ovest della parte profonda (un decal di 1,2 x 0,9 m che guarda a est), visto da
## est: a destra è nord, in alto è ovest (la piscina dall'alto come la vede chi guarda il muro).
@export var disegno_posizione := Vector3(-6.97, -0.8, -0.2)
@export var disegno_misura := Vector2(1.2, 0.9)
## Un filo di luce propria del disegno (pastelli fosforescenti, come il bordo dei cerchi): al buio della piscina, senza,
## da 4 m non si legge (prove del 29 ottobre: a 0,3 sembra uno schermo acceso). Da approvare con l'enigma.
@export_range(0.0, 1.0) var luce_disegno := 0.12

@export_group("Spinta")
## Accelerazione data dal getto che colpisce un giocattolo (m/s² con lo zaino a 4 m).
@export var spinta_diretta := 2.6
## Il getto che colpisce l'acqua o il fondo vicino a un giocattolo lo spinge anche lui (l'onda), dove va il getto; un
## muro colpito vicino lo respinge via dal muro: fino a questa distanza, sempre meno.
@export var raggio_corrente := 1.4
@export var spinta_corrente := 2.2
## Sul fondo vuoto si spingono un po' più piano, ma non molto (strisciano sulle piastrelle).
@export var spinta_sul_fondo := 0.85
## Più sei vicino più spinge: a 2 m il 130%, a 10 m il 60%.
@export var vicino_m := 2.0
@export var lontano_m := 10.0
@export var attrito_acqua := 1.1
@export var attrito_fondo := 1.2
@export var velocita_max := 2.4

@export_group("Cerchi")
## Il raggio dei cerchi (1 m di diametro) e quanto sporgono i piatti prima di scendere.
@export var raggio_cerchio := 0.5
@export var sporgenza := 0.03
@export var corsa := 0.025
## Entro questa distanza dal centro del suo cerchio un giocattolo lento ci scivola dentro da solo.
@export var raggio_aggancio := 0.42
## Entro questa distanza dal centro (e fermo sul fondo) il piatto scende.
@export var tolleranza := 0.22
## Il bordo che si accende appena col giocattolo sopra, e tutto col piatto sceso.
@export var bordo_appena := 0.35

## Vero quando i tre piatti sono scesi (resta vero).
var risolto_ok := false
var _giu: Array[bool] = [false, false, false]
var _cerchi: Array[Node3D] = []
var _piatti: Array[Node3D] = []
var _dischi: Array[CylinderMesh] = []
var _forme_piatti: Array[CylinderShape3D] = []
var _ostacoli: Array[Vector3] = []
## Le collisioni dei gonfiabili sul fondo (per i test: la quota del fondo vero sotto un giocattolo).
var _rid_gonfiabili: Array[RID] = []
var _mat_cerchi: Array[Material] = []
var _giocattoli: Array[AnimatableBody3D] = []
var _vel: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _yaw_vel: Array[float] = [0.0, 0.0, 0.0]
var _y: Array[float] = [0.0, 0.0, 0.0]
var _acceso: Array[float] = [0.0, 0.0, 0.0]
var _sopra: Array[bool] = [false, false, false]
## Fermo sul fondo e appoggiato con Posa (sulla mesh che si vede, non solo sulla collisione).
var _assestato: Array[bool] = [false, false, false]
## Dov'era (in pianta) quando si è assestato: se qualcosa lo sposta (un gonfiabile, un altro giocattolo) si riassesta.
var _fermo_in: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
## L'imbardata di ogni giocattolo (a parte: appoggiato si inclina come la superficie sotto) e quella superficie.
var _yaw: Array[float] = [0.0, 0.0, 0.0]
var _normale: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP]
var _fondo_cerchi: Array[float] = [0.0, 0.0, 0.0]
var _t := 0.0
var _zaino_collegato: Node
var _risucchio_t := -1.0
## Quanto sono bagnati i cerchi (1 sott'acqua, poi si asciugano piano a piscina vuota) e quanto lo sono nel materiale.
var _umido := 1.0
var _bagnato := -1.0
var _pronto := false


func _ready() -> void:
	add_to_group(&"persist")
	_costruisci()
	_appoggia.call_deferred()


## I cerchi e i giocattoli (i figli coi nomi fissi; quelli che mancano si fanno qui).
func _costruisci() -> void:
	var radice_c := _figlio(self, "Cerchi")
	var radice_g := _figlio(self, "Giocattoli")
	for i in 3:
		var c := _figlio(radice_c, NOMI_CERCHI[i])
		c.position = Vector3(cerchi[i].x, 0.0, cerchi[i].z)
		_cerchi.append(c)
		var piatto := c.get_node_or_null(^"Piatto") as Node3D
		if piatto == null:
			piatto = _piatto(i)
			c.add_child(piatto)
		_piatti.append(piatto)
		_altezza_piatto(i, sporgenza)
		var g := radice_g.get_node_or_null(NOMI_GIOCATTOLI[i]) as AnimatableBody3D
		if g == null:
			g = _giocattolo(i)
			radice_g.add_child(g)
		g.position = Vector3(partenze[i].x, 0.0, partenze[i].z)
		g.rotation_degrees.y = partenze[i].y
		_yaw[i] = g.rotation.y
		_giocattoli.append(g)
	if get_node_or_null(^"Disegno") == null:
		add_child(_disegno())


## Il disegno: il decal col disegno vero di ambienti-1 se c'è (disegno_piscina.png), se no un segnaposto fatto qui con
## la piscina dall'alto, la botola e i tre giocattoli nei loro cerchi (solo disegni, niente scritte).
func _disegno() -> Decal:
	var d := Decal.new()
	d.name = "Disegno"
	d.size = Vector3(disegno_misura.x, 0.3, disegno_misura.y)
	# guarda a est: lo strato -Y del decal va dentro il muro (ovest), la x del disegno verso nord, la z verso il basso
	d.basis = Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
	d.position = disegno_posizione
	var vero := DIR + "disegno_piscina.png"
	d.texture_albedo = load(vero) as Texture2D if ResourceLoader.exists(vero) else _disegno_segnaposto()
	d.texture_emission = d.texture_albedo
	d.emission_energy = luce_disegno
	d.upper_fade = 0.0
	d.lower_fade = 0.0
	d.cull_mask = 1
	return d


## Il segnaposto del disegno: la piscina vista dall'alto (da est: a destra nord, in alto ovest), segni a pastello.
func _disegno_segnaposto() -> Texture2D:
	var w := 480
	var h := 360
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# la piscina: da z = 5 (sinistra) a z = -13 (destra), da x = -7 (in alto) a x = 7 (in basso)
	var a_px := func(x: float, z: float) -> Vector2: return Vector2(remap(z, 5.5, -13.5, 20, w - 20), remap(x, -7.5, 7.5, 20, h - 20))
	var azzurro := Color(0.35, 0.65, 0.95, 0.9)
	_rettangolo(img, a_px.call(-7.0, 5.0), a_px.call(7.0, -13.0), azzurro, 3)
	# la botola (grigia, con la croce)
	var b0: Vector2 = a_px.call(-0.7, 2.7)
	var b1: Vector2 = a_px.call(0.7, 1.3)
	_rettangolo(img, b0, b1, Color(0.4, 0.4, 0.42, 0.95), 3)
	_linea(img, b0, b1, Color(0.4, 0.4, 0.42, 0.95), 2)
	_linea(img, Vector2(b0.x, b1.y), Vector2(b1.x, b0.y), Color(0.4, 0.4, 0.42, 0.95), 2)
	for i in 3:
		var c: Vector2 = a_px.call(cerchi[i].x, cerchi[i].z)
		var r := 26.0
		_cerchio(img, c, r, COLORI[i], 3)
		match i:
			0:
				_disco(img, c + Vector2(-3, 4), 11, COLORI[0])
				_disco(img, c + Vector2(7, -7), 7, COLORI[0])
				_disco(img, c + Vector2(14, -6), 3, Color(1.0, 0.45, 0.05))
			1:
				_disco(img, c, 13, COLORI[1])
				_linea(img, c + Vector2(-12, 0), c + Vector2(12, 0), Color(1, 1, 1, 0.9), 2)
			2:
				_disco(img, c + Vector2(-3, 0), 9, COLORI[2])
				_disco(img, c + Vector2(6, 0), 9, COLORI[2])
				_linea(img, c + Vector2(13, 0), c + Vector2(19, -7), COLORI[2], 3)
				_linea(img, c + Vector2(13, 0), c + Vector2(19, 7), COLORI[2], 3)
				_linea(img, c + Vector2(-2, -10), c + Vector2(-2, -18), azzurro, 2)
	return ImageTexture.create_from_image(img)


func _linea(img: Image, a: Vector2, b: Vector2, col: Color, spessore: int) -> void:
	var n := int(a.distance_to(b)) + 1
	for k in n + 1:
		var p := a.lerp(b, float(k) / float(n))
		# (a pastello: il segno trema un po' e lascia dei buchi)
		var t := p + Vector2(sin(k * 0.7) * 0.8, cos(k * 0.5) * 0.8)
		for dx in range(-spessore / 2, spessore / 2 + 1):
			for dy in range(-spessore / 2, spessore / 2 + 1):
				var x := int(t.x) + dx
				var y := int(t.y) + dy
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and (x * 7 + y * 13) % 11 != 0:
					img.set_pixel(x, y, col)


func _rettangolo(img: Image, a: Vector2, b: Vector2, col: Color, spessore: int) -> void:
	_linea(img, Vector2(a.x, a.y), Vector2(b.x, a.y), col, spessore)
	_linea(img, Vector2(b.x, a.y), Vector2(b.x, b.y), col, spessore)
	_linea(img, Vector2(b.x, b.y), Vector2(a.x, b.y), col, spessore)
	_linea(img, Vector2(a.x, b.y), Vector2(a.x, a.y), col, spessore)


func _cerchio(img: Image, c: Vector2, r: float, col: Color, spessore: int) -> void:
	var n := 40
	for k in n:
		var a1 := TAU * k / n
		var a2 := TAU * (k + 1) / n
		_linea(img, c + Vector2(cos(a1), sin(a1)) * r, c + Vector2(cos(a2), sin(a2)) * r, col, spessore)


func _disco(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r), int(c.y + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			if Vector2(x, y).distance_to(c) <= r and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() \
					and (x * 3 + y * 5) % 7 != 0:
				img.set_pixel(x, y, col)


func _figlio(padre: Node, nome: String) -> Node3D:
	var n := padre.get_node_or_null(NodePath(nome)) as Node3D
	if n == null:
		n = Node3D.new()
		n.name = nome
		padre.add_child(n)
	return n


## Il piatto: un disco di mosaico di 1 m appoggiato sul fondo, alto [member sporgenza], che si cammina (strato del
## mondo). Scendendo si abbassa di [member corsa] restando appoggiato (il disco si accorcia: niente dentro il fondo).
func _piatto(i: int) -> Node3D:
	var piatto := StaticBody3D.new()
	piatto.name = "Piatto"
	piatto.collision_layer = Layers.WORLD
	piatto.collision_mask = 0
	# sopra il mosaico: un quadrato di 1 m con le UV 0..1 (lo shader dei cerchi disegna solo il cerchio)
	var mi := MeshInstance3D.new()
	mi.name = "Mosaico"
	var quadro := PlaneMesh.new()
	quadro.size = Vector2(raggio_cerchio * 2.0, raggio_cerchio * 2.0)
	mi.mesh = quadro
	var mat := _materiale_cerchio(i)
	mi.material_override = mat
	_mat_cerchi.append(mat)
	piatto.add_child(mi)
	# il fianco del piatto: cemento chiaro, appena sotto il mosaico
	var fianco := MeshInstance3D.new()
	fianco.name = "Fianco"
	var disco := CylinderMesh.new()
	disco.top_radius = raggio_cerchio - 0.003
	disco.bottom_radius = raggio_cerchio - 0.003
	disco.radial_segments = 48
	disco.rings = 1
	disco.cap_top = false
	fianco.mesh = disco
	var cemento := StandardMaterial3D.new()
	cemento.albedo_color = Color(0.55, 0.55, 0.52)
	cemento.roughness = 0.8
	fianco.material_override = cemento
	piatto.add_child(fianco)
	var cs := CollisionShape3D.new()
	var forma := CylinderShape3D.new()
	forma.radius = raggio_cerchio
	cs.shape = forma
	piatto.add_child(cs)
	_dischi.append(disco)
	_forme_piatti.append(forma)
	return piatto


## Il piatto alto [param h] sopra il fondo (da [member sporgenza] a [member sporgenza] - [member corsa]).
func _altezza_piatto(i: int, h: float) -> void:
	_dischi[i].height = h
	_forme_piatti[i].height = h
	if i >= _piatti.size():
		return
	for n in _piatti[i].get_children():
		if n is Node3D:
			(n as Node3D).position.y = h if n.name == &"Mosaico" else h * 0.5


## Il materiale del cerchio: quello vero di ambienti-1 se c'è (uniform bordo_acceso e bagnato), se no il segnaposto.
func _materiale_cerchio(i: int) -> Material:
	var vero: String = DIR + FILE_CERCHI[i]
	if ResourceLoader.exists(vero):
		return (load(vero) as Material).duplicate() as Material
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/game/enigma_giocattoli_cerchio.gdshader") as Shader
	m.set_shader_parameter(&"colore", COLORI[i])
	return m


## Il giocattolo: un corpo che si muove da script (galleggia, si spinge, si appoggia), solido come i gonfiabili già
## sul fondo (strato del mondo: il giocatore ci sbatte e ci sale; il getto lo colpisce), col modello vero se c'è.
func _giocattolo(i: int) -> AnimatableBody3D:
	var g := AnimatableBody3D.new()
	g.name = NOMI_GIOCATTOLI[i]
	g.sync_to_physics = false
	g.collision_layer = Layers.WORLD | Layers.PROPS
	g.collision_mask = 0
	var vero: String = DIR + FILE_GIOCATTOLI[i]
	var modello: Node3D
	if ResourceLoader.exists(vero):
		modello = (load(vero) as PackedScene).instantiate() as Node3D
	else:
		modello = _segnaposto(i)
	modello.name = "Modello"
	g.add_child(modello)
	var cs := CollisionShape3D.new()
	cs.name = "Forma"
	match i:
		1:
			var s := SphereShape3D.new()
			s.radius = RAGGI[i]
			cs.shape = s
			cs.position.y = RAGGI[i]
		_:
			var c := CylinderShape3D.new()
			c.radius = RAGGI[i] * (0.9 if i == 0 else 0.6)
			c.height = ALTEZZE[i]
			cs.shape = c
			cs.position.y = ALTEZZE[i] * 0.5
			if i == 2:
				var cap := CapsuleShape3D.new()
				cap.radius = ALTEZZE[i] * 0.5
				cap.height = RAGGI[i] * 2.4
				cs.shape = cap
				cs.rotation_degrees.x = 90.0
	g.add_child(cs)
	return g


## Segnaposto con le misure dei modelli (paperella 45x38 cm, pallone 50 cm, balena 75x35 cm): gomma colorata, una
## mesh sola (un pezzo unico, come sarà il modello vero).
func _segnaposto(i: int) -> Node3D:
	var mi := MeshInstance3D.new()
	var gomma := StandardMaterial3D.new()
	gomma.albedo_color = COLORI[i].darkened(0.1)
	gomma.roughness = 0.55
	var sfera := SphereMesh.new()
	sfera.radial_segments = 32
	sfera.rings = 16
	match i:
		0:
			sfera.radius = 0.2
			sfera.height = 0.38
			mi.scale = Vector3(1.1, 1.0, 1.2)
		1:
			sfera.radius = 0.25
			sfera.height = 0.5
		2:
			sfera.radius = 0.175
			sfera.height = 0.35
			mi.scale = Vector3(1.0, 1.0, 2.1)
	mi.mesh = sfera
	mi.material_override = gomma
	mi.position.y = sfera.height * 0.5
	var n := Node3D.new()
	n.add_child(mi)
	return n


## Il fondo sotto i cerchi (Posa, lo strumento comune) e i giocattoli sul pelo dell'acqua; poi il riscaldamento: tutto
## disegnato una volta fuori vista (strato 1<<15), così a metà enigma non si compila niente.
func _appoggia() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	for i in 3:
		var c := _cerchi[i]
		# (Posa guarda in giù da appena sopra il nodo: si parte sotto il pelo dell'acqua, se no si appoggia lì)
		if vasca:
			c.global_position.y = vasca.get_floor_global_y() + 0.4
		var escludi: Array[RID] = []
		for p in _piatti:
			if p is CollisionObject3D:
				escludi.append((p as CollisionObject3D).get_rid())
		for g in _giocattoli:
			escludi.append(g.get_rid())
		Posa.appoggia_a_terra(c, 0.0, false, escludi)
		_inclina_come_il_fondo(c, escludi)
		_fondo_cerchi[i] = c.global_position.y
		_metti_piatto(i, _giu[i])
	_ostacoli = _ostacoli_fondo()
	for i in 3:
		# (sul piatto sceso la quota è quella del piatto; gli altri sul pelo dell'acqua o sul fondo)
		_y[i] = _cerchi[i].global_position.y + sporgenza - corsa + STACCO if _giu[i] else _quota_bersaglio(i)
		_giocattoli[i].global_position.y = _y[i]
		if _giu[i]:
			_giocattoli[i].global_basis = Basis(Quaternion(Vector3.UP, _cerchi[i].global_basis.y.normalized())) \
				* Basis(Vector3.UP, _yaw[i])
			_bordo(_mat_cerchi[i], 1.0)
			_acceso[i] = 1.0
	_pronto = true
	if not Engine.is_editor_hint() and get_viewport():
		await RiscaldamentoShader.disegna_fuori_vista(self, get_viewport(), 4, func(): _accendi_tutti(1.0))
		_aggiorna_bordi(1.0)


## Il fondo sotto un cerchio curva di 1-2 cm sul metro del disco (la conca della botola; misure di ambienti-1): il
## piatto si inclina come il piano che passa meglio per il fondo sotto il suo bordo, e si alza quanto serve perché
## nessun punto del bordo entri nel fondo (resta a filo, non sospeso).
func _inclina_come_il_fondo(c: Node3D, escludi: Array[RID]) -> void:
	var spazio := get_world_3d().direct_space_state
	var punti: Array[Vector3] = []
	for k in 8:
		var a := TAU * k / 8.0
		var d := Vector3(cos(a), 0.0, sin(a)) * (raggio_cerchio - 0.02)
		var da := c.global_position + d + Vector3.UP * 0.3
		var q := PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 0.8, Layers.WORLD, escludi)
		var h := spazio.intersect_ray(q)
		if not h.is_empty():
			punti.append(h.position)
	if punti.size() < 6:
		return
	# il piano z = a x + b z + c, ai minimi quadrati, nelle coordinate relative al centro
	var o := c.global_position
	var sxx := 0.0
	var szz := 0.0
	var sxz := 0.0
	var sxy := 0.0
	var szy := 0.0
	for p in punti:
		var r := p - o
		sxx += r.x * r.x
		szz += r.z * r.z
		sxz += r.x * r.z
		sxy += r.x * r.y
		szy += r.z * r.y
	var det := sxx * szz - sxz * sxz
	if absf(det) < 0.000001:
		return
	var a := (sxy * szz - szy * sxz) / det
	var b := (szy * sxx - sxy * sxz) / det
	var n := Vector3(-a, 1.0, -b).normalized()
	c.global_basis = Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, c.global_rotation.y)
	# il punto del bordo più alto rispetto al piano decide la quota (niente dentro il fondo)
	var su := 0.0
	for p in punti:
		su = maxf(su, (p - c.global_position).dot(n))
	c.global_position += n * su


func _accendi_tutti(k: float) -> void:
	for m in _mat_cerchi:
		_bordo(m, k)


func _bordo(m: Material, k: float) -> void:
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter(&"bordo_acceso", k)


func _metti_piatto(i: int, giu: bool) -> void:
	_altezza_piatto(i, sporgenza - corsa if giu else sporgenza)


# --- Il getto -----------------------------------------------------------------------------------------------------

func _collega_zaino() -> void:
	var p := GameState.player
	var z: Node = p.water_pack if p and is_instance_valid(p) and p.water_pack else null
	if z == _zaino_collegato:
		return
	if is_instance_valid(_zaino_collegato) and _zaino_collegato.is_connected(&"jet_hit", _su_getto):
		_zaino_collegato.disconnect(&"jet_hit", _su_getto)
	_zaino_collegato = z
	if z:
		z.connect(&"jet_hit", _su_getto)


## Il getto arriva in [param punto]: se colpisce un giocattolo lo spinge lungo il getto; se colpisce l'acqua o il fondo
## vicino a un giocattolo lo spinge anche lui, meno (l'onda), e un muro colpito vicino lo respinge via dal muro.
func _su_getto(collider: Object, punto: Vector3, normale: Vector3) -> void:
	if risolto_ok or not _pronto:
		return
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	var dt := get_physics_process_delta_time()
	var occhio: Vector3 = p.get_eye_position()
	var dir3 := punto - occhio
	var dir := Vector2(dir3.x, dir3.z)
	if dir.length() < 0.05:
		return
	dir = dir.normalized()
	for i in 3:
		if _giu[i]:
			continue
		var g := _giocattoli[i]
		var gp := g.global_position
		var k := 0.0
		var verso := dir
		if collider == g:
			k = spinta_diretta
		else:
			if absf(punto.y - (gp.y + ALTEZZE[i] * 0.5)) > 0.9:
				continue
			var d := Vector2(gp.x - punto.x, gp.z - punto.z)
			var dist := maxf(d.length() - RAGGI[i], 0.0)
			if dist > raggio_corrente:
				continue
			k = spinta_corrente * (1.0 - dist / raggio_corrente)
			# l'acqua colpita lo porta dove va il getto (davanti o un po' oltre lui, sempre lontano da chi spruzza); un
			# muro colpito lo respinge via dal muro (di sponda: così lo si stacca da un muro)
			if absf(normale.y) < 0.5 and d.length() > 0.01:
				verso = d.normalized()
			# l'acqua o il fondo colpiti non lo spingono contro il bordo dell'area se ci è già contro (prima il getto che
			# cadeva davanti al muro lo rimandava sotto la scaletta, collaudo di ambienti-2)
			verso = _non_verso_il_bordo(g, verso)
		var lontano := Vector2(gp.x - occhio.x, gp.z - occhio.z).length()
		k *= remap(clampf(lontano, vicino_m, lontano_m), vicino_m, lontano_m, 1.3, 0.6)
		if not _galleggia(i):
			k *= spinta_sul_fondo
		_vel[i] += _a_locale(verso) * k * dt
		# (un colpo di lato lo fa anche girare un po')
		var lato := Vector2(punto.x - gp.x, punto.z - gp.z)
		_yaw_vel[i] += clampf(lato.cross(dir), -0.4, 0.4) * k * dt * 2.0


## [param verso] (in pianta, nel mondo) senza la parte che porta il giocattolo [param g] fuori dall'[member area], se è a
## meno di 40 cm dal bordo.
func _non_verso_il_bordo(g: Node3D, verso: Vector2) -> Vector2:
	var l := _a_locale(verso)
	var pos := Vector2(g.position.x, g.position.z)
	if (pos.x < area.position.x + 0.4 and l.x < 0.0) or (pos.x > area.end.x - 0.4 and l.x > 0.0):
		l.x = 0.0
	if (pos.y < area.position.y + 0.4 and l.y < 0.0) or (pos.y > area.end.y - 0.4 and l.y > 0.0):
		l.y = 0.0
	var m := global_basis * Vector3(l.x, 0.0, l.y)
	return Vector2(m.x, m.z)


## Una direzione orizzontale del mondo nel sistema del nodo (in pianta).
func _a_locale(v: Vector2) -> Vector2:
	var l := global_basis.inverse() * Vector3(v.x, 0.0, v.y)
	return Vector2(l.x, l.z)


# --- Il movimento ---------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _pronto:
		return
	_t += delta
	_collega_zaino()
	for i in 3:
		_muovi(i, delta)
	_separa()
	for i in 3:
		_controlla_cerchio(i)
	_umido = 1.0 if vasca == null or vasca.fill > 0.001 else maxf(0.0, _umido - delta / 45.0)
	if absf(_umido - _bagnato) > 0.01 or (_umido == 0.0 and _bagnato != 0.0):
		_bagnato = _umido
		for m in _mat_cerchi:
			if m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter(&"bagnato", _bagnato)
	if _risucchio_t >= 0.0:
		_risucchio_t += delta
		if _risucchio_t >= 0.7:
			_risucchio_t = -1.0
			_fine()


func _galleggia(i: int) -> bool:
	return vasca != null and vasca.fill > 0.0005 and vasca.get_surface_global_y() - PESCAGGI[i] > _fondo(i) + 0.005


## La quota del fondo sotto il giocattolo (il fondo della piscina o un piatto), senza i giocattoli.
func _fondo(i: int) -> float:
	var g := _giocattoli[i]
	var p := g.global_position
	var escludi: Array[RID] = []
	for x in _giocattoli:
		escludi.append(x.get_rid())
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 1.2, p.z), Vector3(p.x, p.y - 3.0, p.z), Layers.WORLD, escludi)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return p.y
	_normale[i] = h.normal if (h.normal as Vector3).y > 0.85 else Vector3.UP
	return (h.position as Vector3).y


## Posa il giocattolo [param i] fermo sul fondo: sotto la sua impronta Posa (lo strumento comune: le mesh e le collisioni)
## trova quello che si vede; il giocattolo si inclina come il piano che passa meglio per quei punti e scende finché il
## più alto lo tocca ([constant STACCO] sopra), come una cosa piatta su un fondo curvo. Se sotto non trova niente,
## resta a [param prima].
func _posa_sul_fondo(i: int, escludi: Array[RID], prima: float) -> void:
	var g := _giocattoli[i]
	var e: Vector2 = IMPRONTE[i]
	var o := Vector3(g.global_position.x, prima, g.global_position.z)
	var punti: Array[Vector3] = []
	for k in 9:
		var l := Vector3.ZERO if k == 8 else Vector3(cos(TAU * k / 8.0) * e.x, 0.0, sin(TAU * k / 8.0) * e.y)
		var p := o + Basis(Vector3.UP, _yaw[i]) * l
		var h: Dictionary = Posa._raggio(g, Vector3(p.x, prima + 0.4, p.z), Vector3(p.x, prima - 0.5, p.z), escludi)
		if not h.is_empty():
			punti.append(h.position)
	if punti.size() < 5:
		g.global_position.y = prima
		return
	# il piano y = a x + b z + c (ai minimi quadrati, attorno all'origine del giocattolo)
	var sxx := 0.0
	var szz := 0.0
	var sxz := 0.0
	var sxy := 0.0
	var szy := 0.0
	var sy := 0.0
	for p in punti:
		var r := p - o
		sxx += r.x * r.x
		szz += r.z * r.z
		sxz += r.x * r.z
		sxy += r.x * r.y
		szy += r.z * r.y
		sy += r.y
	var det := sxx * szz - sxz * sxz
	var n := Vector3.UP
	if absf(det) > 0.000001:
		n = Vector3(-(sxy * szz - szy * sxz) / det, 1.0, -(szy * sxx - sxy * sxz) / det).normalized()
	if n.y < 0.85:
		n = Vector3.UP
	var m := -INF
	for p in punti:
		m = maxf(m, (p - o).dot(n))
	g.global_basis = Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, _yaw[i])
	g.global_position = Vector3(o.x, o.y + (m + STACCO) / n.y, o.z)
	_y[i] = g.global_position.y


func _quota_bersaglio(i: int) -> float:
	var f := _fondo(i)
	if vasca and vasca.fill > 0.0005:
		return maxf(f, vasca.get_surface_global_y() - PESCAGGI[i])
	return f


func _muovi(i: int, delta: float) -> void:
	var g := _giocattoli[i]
	if _giu[i]:
		return
	var a_galla := _galleggia(i)
	var v := _vel[i]
	v *= exp(-(attrito_acqua if a_galla else attrito_fondo) * delta)
	# vicino al suo cerchio, se va piano, ci scivola dentro (non serve la precisione al centimetro)
	var c := Vector2(_cerchi[i].position.x, _cerchi[i].position.z)
	var pos := Vector2(g.position.x, g.position.z)
	var al_centro := c - pos
	var prima := pos
	if al_centro.length() < raggio_aggancio and v.length() < 0.7:
		v += al_centro * 4.0 * delta
		v *= exp(-2.5 * delta)
	if v.length() > velocita_max:
		v = v.normalized() * velocita_max
	pos += v * delta
	# dentro la parte profonda, fuori dai posti da lasciare liberi
	if pos.x < area.position.x:
		pos.x = area.position.x
		v.x = absf(v.x) * 0.2
	elif pos.x > area.end.x:
		pos.x = area.end.x
		v.x = -absf(v.x) * 0.2
	if pos.y < area.position.y:
		pos.y = area.position.y
		v.y = absf(v.y) * 0.2
	elif pos.y > area.end.y:
		pos.y = area.end.y
		v.y = -absf(v.y) * 0.2
	if not a_galla:
		# sul fondo: i gonfiabili e i posti liberi lo respingono (morbidi: chi ci arriva sopra calando l'acqua ne
		# scivola giù in mezzo secondo)
		for l in _posti_liberi():
			var d := pos - Vector2(l.x, l.y)
			var minimo: float = l.z + RAGGI[i]
			if d.length() < minimo:
				# (proprio nel centro, come posato dall'acqua nel mezzo di una ciambella: scivola verso il centro dell'area)
				var n := d.normalized() if d.length() > 0.0001 else (area.get_center() - pos).normalized()
				var dentro := minimo - d.length()
				pos += n * minf(dentro, maxf(dentro * 8.0 * delta, 0.004))
				# chi ci arriva da fuori spinto dal getto non entra più di 1 cm (il getto continuo vinceva la spinta morbida:
				# il pallone entrava 20 cm nella ciambella e ci saliva sopra, collaudo di ambienti-2); chi ci arriva sopra
				# calando l'acqua ne scivola giù in mezzo secondo
				if minimo - (prima - Vector2(l.x, l.y)).length() <= 0.01:
					var dopo := minimo - (pos - Vector2(l.x, l.y)).length()
					if dopo > 0.01:
						pos += n * (dopo - 0.01)
				var vn := v.dot(n)
				if vn < 0.0:
					v -= n * vn * 1.3
	_vel[i] = v
	g.position.x = pos.x
	g.position.z = pos.y
	_yaw_vel[i] *= exp(-1.5 * delta)
	_yaw[i] += _yaw_vel[i] * delta
	# la quota: sul pelo dell'acqua (col dondolio) o appoggiato sul fondo
	var bersaglio := _quota_bersaglio(i)
	if a_galla:
		_y[i] = lerpf(_y[i], bersaglio, 1.0 - exp(-5.0 * delta))
		g.global_position.y = _y[i] + sin(_t * 1.3 + i * 2.1) * 0.012
		g.rotation = Vector3(sin(_t * 0.9 + i) * 0.04, _yaw[i], sin(_t * 1.1 + i * 1.7) * 0.04)
	else:
		# (spostato anche da fermo, da un gonfiabile o da un altro giocattolo: si riassesta, se no resta alla quota di
		# prima, anche per aria)
		if v.length() > 0.03 or (_assestato[i] and pos.distance_to(_fermo_in[i]) > 0.003):
			_assestato[i] = false
		if not _assestato[i]:
			_y[i] = maxf(bersaglio, _y[i] - 1.5 * delta) if _y[i] > bersaglio else bersaglio
			g.global_position.y = _y[i]
		# mentre si muove, inclinato come la superficie sotto (il fondo della conca, un piatto); fermo lo posa
		# _posa_sul_fondo e resta così finché non lo si spinge
		if not _assestato[i]:
			var su := g.global_basis.y.normalized().slerp(_normale[i], 1.0 - exp(-8.0 * delta))
			g.global_basis = Basis(Quaternion(Vector3.UP, su)) * Basis(Vector3.UP, _yaw[i])
		# fermo, già giù e a piscina vuota: lo appoggia Posa, una volta, sulla prima superficie che si vede sotto di lui
		# (dove la collisione e la mesh non coincidono, come sul coperchio della botola, resterebbe sospeso o dentro)
		if not _assestato[i] and v.length() < 0.02 and absf(_y[i] - bersaglio) < 0.002 \
				and (vasca == null or vasca.fill <= 0.0005):
			_assestato[i] = true
			_fermo_in[i] = pos
			var escludi: Array[RID] = []
			for x in _giocattoli:
				escludi.append(x.get_rid())
			_posa_sul_fondo(i, escludi, bersaglio)


## I gonfiabili già sul fondo della parte profonda (x, z, raggio nel sistema del nodo): i MeshInstance3D "ogg_*" della
## sala che stanno lì sotto, con la loro misura vera (il riquadro della mesh girato con lei: col riquadro del mondo una
## ciambella girata contava 10 cm in più e i tubi di traverso meno del vero). I lunghi (i tubi) diventano una fila di
## cerchi lungo l'asse, fino in fondo. Raccoglie anche le loro collisioni ([member _rid_gonfiabili]).
func _ostacoli_fondo() -> Array[Vector3]:
	var out: Array[Vector3] = []
	_rid_gonfiabili.clear()
	if sala == null:
		return out
	for n in sala.find_children("ogg_*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var bb := mi.global_transform * mi.get_aabb()
		var c := to_local(bb.get_center())
		if bb.position.y > -1.2 or not area.grow(0.5).has_point(Vector2(c.x, c.z)):
			continue
		for co in mi.find_children("*", "CollisionObject3D", true, false):
			_rid_gonfiabili.append((co as CollisionObject3D).get_rid())
		# i due lati in pianta della mesh, girati come lei, nel sistema del nodo
		var la := mi.get_aabb()
		var b := global_basis.inverse() * mi.global_basis
		var ax := Vector2(b.x.x, b.x.z) * la.size.x * 0.5
		var az := Vector2(b.z.x, b.z.z) * la.size.z * 0.5
		var lungo := ax if ax.length() >= az.length() else az
		var corto := az if ax.length() >= az.length() else ax
		var r := corto.length()
		if lungo.length() <= r * 1.2:
			out.append(Vector3(c.x, c.z, lungo.length()))
			continue
		var asse := lungo.normalized()
		var meta := lungo.length() - r
		var passi := maxi(1, ceili(meta / (r * 0.5)))
		for k in passi + 1:
			var q := Vector2(c.x, c.z) + asse * lerpf(-meta, meta, float(k) / passi)
			out.append(Vector3(q.x, q.y, r))
	return out


## I posti da lasciare liberi sul fondo (x, z, raggio nel sistema del nodo): quelli fissi, i gonfiabili, la P5 finché
## c'è e i cerchi con i giocattoli già scesi.
func _posti_liberi() -> Array[Vector3]:
	var out: Array[Vector3] = liberi.duplicate()
	out.append_array(_ostacoli)
	if is_instance_valid(polaroid) and polaroid.is_inside_tree():
		var l := to_local(polaroid.global_position)
		out.append(Vector3(l.x, l.z, 0.35))
	# e gli altri cerchi, coi giocattoli già scesi
	for j in 3:
		if _giu[j]:
			out.append(Vector3(_cerchi[j].position.x, _cerchi[j].position.z, RAGGI[j]))
	return out


## I giocattoli non si compenetrano: si separano e si scambiano un po' di velocità.
func _separa() -> void:
	for a in 3:
		for b in range(a + 1, 3):
			var ga := _giocattoli[a]
			var gb := _giocattoli[b]
			var d := Vector2(gb.position.x - ga.position.x, gb.position.z - ga.position.z)
			var minimo: float = RAGGI[a] + RAGGI[b]
			if d.length() >= minimo or d.length() < 0.0001:
				continue
			var n := d.normalized()
			var dentro := minimo - d.length()
			var fa := 0.0 if _giu[a] else (0.5 if not _giu[b] else 1.0)
			var fb := 0.0 if _giu[b] else (0.5 if not _giu[a] else 1.0)
			ga.position.x -= n.x * dentro * fa
			ga.position.z -= n.y * dentro * fa
			gb.position.x += n.x * dentro * fb
			gb.position.z += n.y * dentro * fb
			var rel := (_vel[b] - _vel[a]).dot(n)
			if rel < 0.0:
				_vel[a] += n * rel * 0.6 * fa * 2.0
				_vel[b] -= n * rel * 0.6 * fb * 2.0


# --- I cerchi -------------------------------------------------------------------------------------------------------

func _controlla_cerchio(i: int) -> void:
	if _giu[i]:
		return
	var g := _giocattoli[i]
	var c := Vector2(_cerchi[i].position.x, _cerchi[i].position.z)
	var d := Vector2(g.position.x, g.position.z).distance_to(c)
	var sopra := d < raggio_cerchio - 0.1
	if sopra and not _sopra[i]:
		cerchio_acceso.emit(i)
	_sopra[i] = sopra
	_acceso[i] = move_toward(_acceso[i], bordo_appena if sopra else 0.0, get_physics_process_delta_time() * 0.8)
	_bordo(_mat_cerchi[i], _acceso[i])
	# fermo e appoggiato sul piatto, a piscina vuota: il piatto scende
	if d < tolleranza and not _galleggia(i) and _vel[i].length() < 0.3 and absf(_y[i] - _fondo(i)) < 0.01 \
			and (vasca == null or vasca.fill <= 0.0005):
		_scendi(i, true)


func _scendi(i: int, col_suono: bool) -> void:
	_giu[i] = true
	_vel[i] = Vector2.ZERO
	_yaw_vel[i] = 0.0
	var g := _giocattoli[i]
	g.position.x = _cerchi[i].position.x
	g.position.z = _cerchi[i].position.z
	# sul piatto: inclinato come lui
	g.global_basis = Basis(Quaternion(Vector3.UP, _cerchi[i].global_basis.y.normalized())) * Basis(Vector3.UP, _yaw[i])
	if col_suono:
		var tw := create_tween().set_parallel()
		tw.tween_method(func(h: float): _altezza_piatto(i, h), sporgenza, sporgenza - corsa, 0.18) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		var giu := _cerchi[i].global_position.y + sporgenza - corsa + STACCO
		tw.tween_method(func(y: float): g.global_position.y = y, g.global_position.y, giu, 0.18) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_method(func(k: float): _bordo(_mat_cerchi[i], k), _acceso[i], 1.0, 0.5)
		Audio.suona(&"saracinesca_fine", _cerchi[i].global_position, -4.0, 0.75)
	else:
		_metti_piatto(i, true)
		g.global_position.y = _cerchi[i].global_position.y + sporgenza - corsa + STACCO
		_bordo(_mat_cerchi[i], 1.0)
	_y[i] = g.global_position.y
	_acceso[i] = 1.0
	piatto_sceso.emit(i)
	if not risolto_ok and _giu.count(true) == 3:
		if col_suono:
			_risucchio_t = 0.0
		else:
			_fine(false)


## Scesi tutti e tre: il risucchio lungo dagli scarichi e la serratura della botola si apre.
func _fine(col_suono := true) -> void:
	if risolto_ok:
		return
	risolto_ok = true
	if col_suono and piscina:
		Audio.suona(&"piscina_vuota", piscina.call(&"_centro_scarico") if piscina.has_method(&"_centro_scarico") else global_position, 2.0, 0.6)
	risolto.emit()


## Vero quando la serratura della botola è aperta (PiscinaOnde lo chiede per il pulsante).
func aperta() -> bool:
	return risolto_ok


func _aggiorna_bordi(k: float) -> void:
	for i in 3:
		_bordo(_mat_cerchi[i], 1.0 if _giu[i] else _acceso[i] * k)


## Scorciatoia per i test e le partenze di prova: i giocattoli sui loro cerchi (galleggiando, se c'è l'acqua); a
## piscina vuota i piatti scendono da soli al prossimo passo.
func metti_al_posto() -> void:
	for i in 3:
		metti_al_posto_uno(i)


## Scorciatoia per gli scatti: solo il giocattolo [param i] sul suo cerchio.
func metti_al_posto_uno(i: int) -> void:
	if _giu[i]:
		return
	_giocattoli[i].position.x = _cerchi[i].position.x
	_giocattoli[i].position.z = _cerchi[i].position.z
	_vel[i] = Vector2.ZERO
	# (spostato senza spinta: si riposa sul piatto, se no resta alla quota di prima, anche dentro la conca)
	_assestato[i] = false


## Vero se il giocattolo [param i] galleggia (per i test).
func galleggia(i: int) -> bool:
	return _galleggia(i)


## I giocattoli (per i test e gli scatti).
func giocattolo(i: int) -> AnimatableBody3D:
	return _giocattoli[i]


func cerchio(i: int) -> Node3D:
	return _cerchi[i]


func piatto_giu(i: int) -> bool:
	return _giu[i]


## Quanto è acceso il bordo del cerchio [param i] (0..1).
func cerchio_acceso_quanto(i: int) -> float:
	return 1.0 if _giu[i] else _acceso[i]


## La velocità del giocattolo [param i] in pianta (m/s).
func velocita(i: int) -> float:
	return _vel[i].length()


# --- Checkpoint -----------------------------------------------------------------------------------------------------

func save_state() -> Dictionary:
	var pos := []
	for g in _giocattoli:
		pos.append([g.position.x, g.position.z, _yaw[_giocattoli.find(g)]])
	return {"pos": pos, "giu": _giu.duplicate(), "risolto": risolto_ok}


func load_state(data: Dictionary) -> void:
	var pos: Array = data.get("pos", [])
	var giu: Array = data.get("giu", [])
	var tutto := bool(data.get("risolto", false))
	for i in 3:
		_vel[i] = Vector2.ZERO
		_yaw_vel[i] = 0.0
		if i < pos.size():
			_giocattoli[i].position.x = float(pos[i][0])
			_giocattoli[i].position.z = float(pos[i][1])
			_yaw[i] = float(pos[i][2])
			_giocattoli[i].rotation.y = _yaw[i]
		var su_giu := tutto or (i < giu.size() and bool(giu[i]))
		if su_giu and not _giu[i]:
			if _pronto:
				_scendi(i, false)
			else:
				_giu[i] = true
				_giocattoli[i].position.x = _cerchi[i].position.x
				_giocattoli[i].position.z = _cerchi[i].position.z
		elif not su_giu and _giu[i]:
			_giu[i] = false
			_metti_piatto(i, false)
	if tutto or _giu.count(true) == 3:
		risolto_ok = true
	if _pronto:
		for i in 3:
			if not _giu[i]:
				_y[i] = _quota_bersaglio(i)
				_giocattoli[i].global_position.y = _y[i]
				_assestato[i] = false
