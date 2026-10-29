class_name SalaTorre
extends Node3D
## La sala della torre (dopo la tappa 8, scelta dell'utente del 18 ottobre: la versione A, "la struttura
## mastodontica"): quattro torri di traliccio e decine di scivoli colorati, che non si scalano ma si
## SCENDONO, dal portone (in cima, alla quota della sala grande) fino alla vasca del fondo, 20 m più giù.
##
## La geometria viene da tools/blender/torre_proposte.py A --gioco (assets/ambiente/torre/):
## - torre_struttura.glb, torre_scivoli.glb, torre_prop.glb: i nomi con "-col" hanno la collisione fatta
##   dall'importatore (trimesh), i prop una scatola convessa;
## - torre_gioco.json: checkpoint, tratti e salti della discesa, Polaroid, balconata, pozzo, vasca del fondo;
## - torre_luci.json: lampeggianti rossi, lampade da lavoro, fari sui tralicci, gocce.
## Le coordinate dei JSON sono di Blender: (x, y, z) diventa (x, z, -y).
##
## La discesa è fatta dei canali "discesa_<tratto>_<pezzo>": i loro corpi statici sono nel gruppo
## "scivolo" (accordo con grafica: chi ci sta sopra scivola seguendo la pendenza, il salto a fine pezzo
## viene dalla velocità, il getto verso il basso in aria dà la spinta). Qui ci sono:
## - un checkpoint su ogni pedana d'arrivo (e all'ingresso);
## - la strada si legge (S1 e S2, scelte dell'utente del 21 ottobre): sopra ogni imbocco della discesa il
##   portale ha i led verdi e la lampada verde; le bocche degli scivoli che non si fanno sono chiuse dal
##   cancello a strisce, e sopra i cancelli la lampada è rossa e guasta (sfarfalla) o spenta;
## - chi sbaglia un salto cade nella vasca di raccolta sotto, senza morire, e la scaletta di servizio lo
##   riporta sulla pedana da cui era partito (V1); si muore solo per una caduta vera, lunga e visibile:
##   toccando qualcosa dopo [member caduta_mortale] metri di caduta libera;
## - la Polaroid 10 sul lettino della pedana NO a -12;
## - la balconata dei bambini: al primo salto, un lampo e per un attimo si vede la fila di bambini;
## - la luce di lei che sale dal pozzo, più forte man mano che scendi;
## - la vasca del fondo: da lì la bocca del tubo porta all'inseguimento (SalaInseguimento, figlia di
##   questa sala: [member inseguimento_scena]); il capitolo finisce con SB1, alla sua fine
##   ([signal discesa_finita]). Senza inseguimento la discesa finisce entrando nella vasca.

signal discesa_finita

const DIR := "res://assets/ambiente/torre/"
const ROSSO := Color(1.0, 0.035, 0.02)
const CALDO := Color(1.0, 0.66, 0.36)
const ROSA := Color(1.0, 0.32, 0.62)
## La quota del fondo della sala (Blender, torre_proposte.FONDO).
const FONDO_Z := -20.0
const BAMBINI := ["res://scenes/creature/bambino_cubo.tscn", "res://scenes/creature/bambino_agnello.tscn"]

## Ordine del primo checkpoint della torre (dopo quelli della sala grande e del ritorno).
@export var ordine_base := 20
## Metri di caduta libera oltre i quali si muore toccando qualcosa (V1: niente regole invisibili, si muore
## solo per una caduta vera, lunga e visibile).
@export var caduta_mortale := 8.0
## Luce di lei: energia in cima e in fondo alla discesa.
@export var lei_in_cima := 1.5
@export var lei_in_fondo := 14.0
## Le luci accese (per i test e le macchine lente si possono spegnere).
@export var crea_luci := true
## Guida agli imbocchi: nei primi metri di ogni tratto, finché si va piano, la velocità si allinea al canale
## e riporta verso il centro (si entra anche arrivando spostati o storti).
@export var guida_metri := 1.2
@export var guida_forza := 7.0
@export var guida_fino_a := 4.0      ## m/s: più veloce di così la guida non serve più
## L'oblò con lei sul muro est, accanto alla bocca del tubo (scelta dell'utente del 24 ottobre): il raggio del vetro
## (la piastra resta di 1,9 m: grande come gli oblò della Risalita, o piccolo perché l'occhio lo riempia) e la posa.
@export var oblo_raggio_vetro := ObloLei.RAGGIO_VETRO
@export var oblo_posa := "occhio"
## Falso: niente oblò (le prove della discesa senza di lei).
@export var oblo_lei := true
var oblo: ObloLei

var dati := {}
var checkpoint: Array[Checkpoint] = []
var _quote_cp: Array[float] = []          ## quota (y di Godot) di ogni checkpoint
var _lei: Array[Light3D] = []
var _lampo_fatto := false
var _bambini: Array[Node3D] = []
var _finita := false
var _in_aria := false
var _quota_stacco := 0.0
var _imbocchi: Array[PackedVector3Array] = []   ## i primi metri della linea di fondo di ogni tratto


static func b(v: Array) -> Vector3:
	return Vector3(v[0], v[2], -v[1])


## I tre GLB della sala (struttura, scivoli, prop), nell'ordine: stanno qui e non come figli della scena
## così si caricano col thread ma entrano nella sala uno per passo (un GLB intero fa un fotogramma lungo).
## Vuoto: si caricano da DIR.
@export var modelli: Array[PackedScene] = []
## L'inseguimento I1 e il finale SB1, dietro il muro est (vuoto: niente inseguimento).
@export var inseguimento_scena: PackedScene
## Vero: dopo SB1 il capitolo continua nel tunnel del viaggio sottomarino (SalaInseguimento.dopo_sb1_continua).
@export var inseguimento_continua := false
## Le condotte sono nella sala (anche costruite a pezzi, dopo).
signal inseguimento_aggiunto(nodo: Node3D)
var inseguimento: Node3D
## Vero quando la sala è costruita del tutto (vedi [method costruisci_a_pezzi]).
var costruita := false
## Se vero, _ready non costruisce niente: la costruisce chi la aggiunge, con [method costruisci_a_pezzi]
## (la sala principale, mentre il giocatore è all'enigma degli acquari, senza fotogrammi lunghi).
var costruzione_a_pezzi := false
var _a_pezzi := false
## Il fotogramma più carico della costruzione a pezzi: quanti ms di passi ci sono finiti dentro (per i test).
var fotogramma_piu_carico_ms := 0.0
var _coda: Array = []
signal pronta


func _ready() -> void:
	if not costruzione_a_pezzi:
		for passo in _passi():
			(passo as Callable).call()
		costruita = true


## La costruzione divisa in passi brevi, uno per fotogramma (al più [param ms_per_fotogramma] ms di fila).
func costruisci_a_pezzi(ms_per_fotogramma := 8.0) -> void:
	_a_pezzi = true
	var t0 := Time.get_ticks_usec()
	var k := 0
	_coda = _passi()
	while not _coda.is_empty():
		var passo: Callable = _coda.pop_front()
		var tp := Time.get_ticks_usec()
		passo.call()
		if OS.has_environment("TORRE_TEMPI"):
			print("passo %d (%s): %.1f ms" % [k, passo.get_method(), (Time.get_ticks_usec() - tp) / 1000.0])
		k += 1
		if (Time.get_ticks_usec() - t0) / 1000.0 >= ms_per_fotogramma:
			fotogramma_piu_carico_ms = maxf(fotogramma_piu_carico_ms, (Time.get_ticks_usec() - t0) / 1000.0)
			if OS.has_environment("TORRE_TEMPI"):
				print("-- fine fotogramma dopo il passo %d (%.0f ms di passi)" % [k - 1, (Time.get_ticks_usec() - t0) / 1000.0])
			await get_tree().process_frame
			# tolta dall'albero mentre si costruiva (una morte ricarica la sala): non serve più
			if not is_inside_tree():
				return
			t0 = Time.get_ticks_usec()
	fotogramma_piu_carico_ms = maxf(fotogramma_piu_carico_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	if inseguimento and inseguimento.has_method(&"costruisci_a_pezzi"):
		await inseguimento.call(&"costruisci_a_pezzi", ms_per_fotogramma)
	costruita = true
	pronta.emit()


## Lo strato di disegno usato da [method prepara_materiali] e da RiscaldamentoShader (strato 16, "preparazione"): la
## camera del giocatore e quelle dei riflessi dell'acqua non lo disegnano, e le luci messe lì non le illuminano. Era
## 1 << 19, lo stesso dell'acqua (WaterBody.WATER_LAYER) e di quello che il lampo della tempesta esclude, che la camera
## del giocatore disegna (collaudo del 25 ottobre).
const STRATO_PREPARA := 1 << 15
## Il muro est della torre, in comune con la sala delle condotte (x, come X0 di tools/blender/inseguimento_proposte.py).
const MURO_CONDOTTE_X := 40.0


## Disegna la sala una volta fuori vista (una camera sua in un SubViewport con le stesse impostazioni di
## [param principale] e lo stesso mondo), così il motore compila adesso le pipeline dei suoi materiali e
## al primo fotogramma vero non si ferma (riscontro sul primo spruzzo: l'utente nota ogni blocco).
## Intanto la sala sta su uno strato che la camera del gioco non disegna (anche le sue luci, che così il gioco non
## usa). Alla fine torna com'era (nascosta, se lo era).
func prepara_materiali(principale: Viewport, fotogrammi := 4) -> void:
	if principale == null or not is_inside_tree():
		return
	# lei dietro l'oblò, visibile e ferma nella sua posa, si disegna con la torre (oblò leggeri di mascotte): a metà nella
	# posa del distacco, e alla fine il giro intorno all'oblò nella sua luce (con la lancia sotto una luce come la sua),
	# ancora sullo strato fuori vista
	var con_oblo := oblo != null and is_instance_valid(oblo)
	if con_oblo:
		oblo.mostra_per_preparare()
	var a_meta := func() -> void:
		if oblo and is_instance_valid(oblo):
			oblo.stacco_per_preparare()
	var alla_fine := func() -> void:
		if oblo and is_instance_valid(oblo) and is_inside_tree():
			await oblo.giro_nella_sua_luce(principale)
	await RiscaldamentoShader.disegna_fuori_vista(self, principale, fotogrammi, a_meta if con_oblo else Callable(),
			alla_fine if con_oblo else Callable())
	if con_oblo and is_instance_valid(oblo):
		oblo.fine_preparazione()


## Il rosso dentro la vasca dell'oblò (scelta B dell'utente del 29 ottobre, "com'era prima: si rimette un po' di rosso
## solo dentro la vasca"). Fino alla 0.3.15 tutta la vasca (l'acqua dietro di lei, lei, le sue mani) prendeva il rosso
## della lampada d'emergenza del muro est, che senza ombra passava il muro e accendeva la nebbia dentro la vasca (e
## faceva la riga rossa nelle condotte). Ora quella lampada fa ombra; il suo rosso lo ridanno i veli dell'acqua torbida
## della vasca e il vetro dell'oblò appena accesi (ObloLei.veli_colore e vetro_colore), senza luci: non passa niente,
## né nelle condotte né nella torre (una luce o la nebbia dentro la vasca riportavano la riga nelle condotte, prove del
## 29 ottobre: docs/report/collaudo_29ottobre_g2/torre_rosso).
@export var oblo_veli_rossi := ROSSO * 0.1
@export var oblo_vetro_rosso := ROSSO * 0.5


## I passi della costruzione, in ordine. Quelli lunghi (scivoli, luci) sono divisi in tanti passi piccoli.
func _passi() -> Array:
	var out: Array = []
	for i in 3:
		out.append(func(): _modello(i))
	out.append(_prepara_dati)
	out.append_array(_passi_scivoli())
	out.append_array([_prepara_imbocchi, _checkpoint, _raccolta, _polaroid])
	out.append_array(_passi_balconata())
	out.append(_vasca_fondo)
	out.append(_oblo_lei)
	# lei dietro l'oblò nasce in tre passi suoi, nascosta e ferma (prepara_materiali la disegna con la torre): quando
	# compare non si istanzia e non si compila niente (riscontro della v0.3.14)
	for fase in 3:
		out.append(func(): if oblo: oblo.prepara_lei(fase))
	if crea_luci:
		out.append_array(_passi_luci())
	out.append(_luce_lei)
	out.append(_aggiungi_inseguimento)
	out.append(_fuori_dal_blackout)
	return out


func _aggiungi_inseguimento() -> void:
	if inseguimento_scena == null or inseguimento:
		return
	inseguimento = inseguimento_scena.instantiate() as Node3D
	inseguimento.set(&"costruzione_a_pezzi", _a_pezzi)
	inseguimento.set(&"crea_luci", crea_luci)
	inseguimento.set(&"dopo_sb1_continua", inseguimento_continua)
	add_child(inseguimento)
	inseguimento_aggiunto.emit(inseguimento)
	if inseguimento.has_signal(&"capitolo_finito"):
		inseguimento.connect(&"capitolo_finito", func():
			if not _finita:
				_finita = true
				discesa_finita.emit())


## Mette nella sala il GLB [param i] (0 struttura, 1 scivoli, 2 prop): da [member modelli] (caricati
## col thread insieme alla scena) o, se la sala è creata da codice, da DIR.
func _modello(i: int) -> void:
	var nome: String = ["torre_struttura", "torre_scivoli", "torre_prop"][i]
	var nodo: String = nome.capitalize().replace(" ", "")
	if get_node_or_null(nodo) != null:
		return
	var scena: PackedScene = modelli[i] if i < modelli.size() and modelli[i] else load(DIR + nome + ".glb")
	var glb: Node3D = scena.instantiate()
	glb.name = nodo
	if not _a_pezzi:
		add_child(glb)
		return
	# A pezzi: il GLB entra vuoto e i suoi nodi lo raggiungono uno per passo (ogni nodo entra senza
	# figli, e i figli vengono dopo: una mesh grande con la sua collisione è già un passo lungo).
	_coda = _passi_figli(glb, _stacca_figli(glb)) + _coda
	add_child(glb)


func _stacca_figli(n: Node) -> Array:
	var figli := n.get_children()
	for c in figli:
		# (l'owner si toglie qui e si rimette quando il nodo rientra: rientrato con l'owner di prima, Godot avvisava
		# "owner inconsistent" per ogni nodo)
		if c.owner:
			c.set_meta(&"_proprietario", c.owner)
			c.owner = null
		n.remove_child(c)
	return figli


func _rimetti_proprietario(c: Node) -> void:
	if not c.has_meta(&"_proprietario"):
		return
	var o: Node = c.get_meta(&"_proprietario")
	c.remove_meta(&"_proprietario")
	if is_instance_valid(o) and o.is_ancestor_of(c):
		c.owner = o


## Un passo per ogni nodo di [param figli], da mettere sotto [param padre]: ognuno entra senza i suoi
## figli, che entrano nei passi subito dopo.
func _passi_figli(padre: Node, figli: Array) -> Array:
	var passi: Array = []
	for c in figli:
		passi.append(func():
			var nipoti := _stacca_figli(c)
			var tp := Time.get_ticks_usec()
			padre.add_child(c)
			_rimetti_proprietario(c)
			if OS.has_environment("TORRE_TEMPI") and Time.get_ticks_usec() - tp > 5000:
				print("  nodo %s (%s): %.1f ms" % [c.name, c.get_class(), (Time.get_ticks_usec() - tp) / 1000.0])
			if not nipoti.is_empty():
				_coda = _passi_figli(c, nipoti) + _coda)
	return passi


func _prepara_dati() -> void:
	dati = JSON.parse_string(FileAccess.get_file_as_string(DIR + "torre_gioco.json"))
	var acqua: Material = load(ACQUA)
	for m in find_children("acqua*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = acqua


## I corpi statici dei canali della discesa vanno nel gruppo "scivolo". Tutte le forme trimesh della sala
## collidono da tutte e due le facce (l'importatore le fa da una sola: dentro i canali e i tubi si passerebbe
## attraverso le sponde viste dall'altra parte).
func _scivoli() -> void:
	for passo in _passi_scivoli():
		(passo as Callable).call()


## I passi di [method _scivoli]: le sponde dalle due facce, poi un tratto della discesa per passo.
func _passi_scivoli() -> Array:
	# le sponde dalle due facce: cambiare backface_collision ricostruisce la forma (le più grandi
	# costano decine di ms), una per passo
	var forme: Array = []
	var out: Array = [func():
		for f in find_children("*", "CollisionShape3D", true, false):
			var forma := (f as CollisionShape3D).shape as ConcavePolygonShape3D
			if forma and not forma.backface_collision:
				forme.append(forma)]
	for i in 400:
		out.append(func():
			if i < forme.size():
				(forme[i] as ConcavePolygonShape3D).backface_collision = true)
	out.append(func():
		# i canali della discesa: un corpo per pezzo, costruito dalla linea del fondo come nella scena di
		# prova degli scivoli di grafica (scenes/test/scivoli_prova.gd: canale a U tondo, sponde a 84 gradi)
		var radice := Node3D.new()
		radice.name = "CollisioniDiscesa"
		add_child(radice))
	# quanti tratti ci sono si sa solo dopo _prepara_dati: i passi leggono dati quando partono
	for i in 64:
		out.append(func():
			if i >= (dati["tratti"] as Array).size():
				return
			var radice := get_node(^"CollisioniDiscesa")
			var t: Dictionary = dati["tratti"][i]
			for j in (t["pezzi"] as Array).size():
				var linea := PackedVector3Array()
				for q in t["linee"][j]:
					linea.append(b(q))
				radice.add_child(_corpo_scivolo(String(t["pezzi"][j]), linea))
				if j == 0:
					radice.add_child(_rampa_imbocco(String(t["pezzi"][j]) + "_rampa", linea)))
	return out


const RAGGIO_CANALE := 1.05
const SPONDA_CANALE := 84.0


## L'imbocco svasato: davanti all'inizio del canale un fondo curvo largo e quasi piano (raggio da 3 m fino a
## quello del canale) che parte a filo della grata della pedana e sale di pochi centimetri fino al fondo del
## canale. Chi entra spostato dal centro ci sale sopra invece di urtare il bordo del canale, e non c'è una
## cresta che lo faccia decollare.
func _rampa_imbocco(nome: String, linea: PackedVector3Array) -> StaticBody3D:
	var tg := Vector3(linea[1].x - linea[0].x, 0.0, linea[1].z - linea[0].z).normalized()
	var lato := tg.cross(Vector3.UP).normalized()
	var colonne := 12
	var anelli: Array[PackedVector3Array] = []
	for passo in [[-0.7, 3.0, -0.06], [-0.35, 2.0, -0.035], [0.0, 1.4, -0.01], [0.35, 1.15, -0.03]]:
		var s_: float = passo[0]
		var r: float = passo[1]
		var base: Vector3 = linea[0] + tg * s_ + Vector3.UP * float(passo[2])
		if s_ > 0.0:
			base = linea[0].lerp(linea[1], s_ / linea[0].distance_to(linea[1])) + Vector3.UP * float(passo[2])
		var largo := minf(1.25, r * 0.9)
		var anello := PackedVector3Array()
		for k in colonne + 1:
			var x := lerpf(-largo, largo, float(k) / colonne)
			anello.append(base + lato * x + Vector3.UP * (r - sqrt(r * r - x * x)))
		anelli.append(anello)
	var facce := PackedVector3Array()
	for i in anelli.size() - 1:
		for k in colonne:
			facce.append_array([anelli[i][k], anelli[i + 1][k], anelli[i][k + 1],
					anelli[i][k + 1], anelli[i + 1][k], anelli[i + 1][k + 1]])
	var corpo := StaticBody3D.new()
	corpo.name = nome
	corpo.add_to_group(&"scivolo")
	corpo.set_meta(&"superficie", &"scivolo")
	corpo.set_meta(&"bagnato", true)
	var cs := CollisionShape3D.new()
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(facce)
	forma.backface_collision = true
	cs.shape = forma
	corpo.add_child(cs)
	return corpo


func _corpo_scivolo(nome: String, punti: PackedVector3Array) -> StaticBody3D:
	var linea := _campiona(punti, 0.3)
	var colonne := 18
	var facce := PackedVector3Array()
	var anelli: Array[PackedVector3Array] = []
	for i in linea.size():
		var t := (linea[mini(i + 1, linea.size() - 1)] - linea[maxi(i - 1, 0)]).normalized()
		var lato := t.cross(Vector3.UP).normalized()
		var su := lato.cross(t).normalized()
		var anello := PackedVector3Array()
		for k in colonne + 1:
			var a := deg_to_rad(lerpf(-SPONDA_CANALE, SPONDA_CANALE, float(k) / colonne))
			anello.append(linea[i] + lato * sin(a) * RAGGIO_CANALE + su * (1.0 - cos(a)) * RAGGIO_CANALE)
		anelli.append(anello)
	for i in anelli.size() - 1:
		for k in colonne:
			facce.append_array([anelli[i][k], anelli[i + 1][k], anelli[i][k + 1],
					anelli[i][k + 1], anelli[i + 1][k], anelli[i + 1][k + 1]])
	var corpo := StaticBody3D.new()
	corpo.name = nome
	corpo.add_to_group(&"scivolo")
	corpo.set_meta(&"superficie", &"scivolo")
	corpo.set_meta(&"bagnato", true)
	var cs := CollisionShape3D.new()
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(facce)
	forma.backface_collision = true
	cs.shape = forma
	corpo.add_child(cs)
	return corpo


## La linea del fondo: Catmull-Rom tra i punti, un campione ogni [param passo] metri circa.
static func _campiona(punti: PackedVector3Array, passo: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in punti.size() - 1:
		var p0: Vector3 = punti[maxi(i - 1, 0)]
		var p1: Vector3 = punti[i]
		var p2: Vector3 = punti[i + 1]
		var p3: Vector3 = punti[mini(i + 2, punti.size() - 1)]
		var n := maxi(1, ceili(p1.distance_to(p2) / passo))
		for k in n:
			var t := float(k) / n
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(punti[punti.size() - 1])
	return out


func corpi_scivolo() -> Array[Node]:
	return get_tree().get_nodes_in_group(&"scivolo").filter(func(c): return is_ancestor_of(c))


func _checkpoint() -> void:
	var i := 0
	for cp in dati["checkpoint"]:
		var a := Checkpoint.new()
		a.name = "Checkpoint_%s" % String(cp["nome"]).replace(" ", "").replace("-", "m")
		a.order = ordine_base + i
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.0, 2.6, 3.0)
		forma.shape = box
		forma.position = Vector3(0, 1.3, 0)
		a.add_child(forma)
		add_child(a)
		var pos := b(cp["pos"])
		a.global_position = pos
		# si riparte un metro dietro l'inizio del tratto dopo, rivolti nella sua direzione
		var rip := Marker3D.new()
		rip.name = "Ripartenza"
		a.add_child(rip)
		var sp := b(cp.get("spawn", cp["pos"]))
		var guarda := b(cp["guarda"])
		guarda.y = sp.y
		rip.global_position = sp
		if guarda.distance_to(sp) > 0.1:
			rip.look_at(guarda, Vector3.UP)
		a.spawn_point = rip
		checkpoint.append(a)
		_quote_cp.append(pos.y)
		i += 1


## Il fondo della sala fuori dalla vasca d'arrivo è una zona di caduta (cadere da 5-20 m non perdona).
## Le vasche di raccolta sotto i salti (V1): l'acqua (ci si cade dentro senza farsi niente) e la scaletta di
## servizio che riporta sulla pedana da cui si era partiti.
func _raccolta() -> void:
	var k := 0
	for v in dati.get("raccolta", []):
		var r: Array = v["rett"]
		var w := WaterVolume.new()
		w.name = "Raccolta%d" % k
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var alto: float = float(v["acqua"]) - float(v["fondo"])
		box.size = Vector3(r[2] - r[0] - 0.36, alto, r[3] - r[1] - 0.36)
		cs.shape = box
		w.add_child(cs)
		add_child(w)
		w.global_position = b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(v["fondo"]) + alto / 2.0])
		var sc: Dictionary = v["scala"]
		var l := Ladder.new()
		l.name = "ScalaRaccolta%d" % k
		l.show_model = false
		l.width = 0.6
		l.height = float(sc["z1"]) - float(sc["z0"])
		add_child(l)
		l.global_position = b([sc["x"], sc["y"], sc["z0"]])
		# il lato -Z della scala sta contro la pedana: il +Z (chi sale) guarda verso la vasca
		var verso := Vector3(float(sc["verso"][0]), 0.0, -float(sc["verso"][1]))
		l.look_at(l.global_position - verso, Vector3.UP)
		k += 1


func _physics_process(_delta: float) -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p) or GameState.is_dying:
		return
	var y := p.global_position.y
	# la caduta vera: da quando si stacca da tutto (non scivolando, non sulla scala, non nell'acqua) a quando
	# tocca di nuovo qualcosa; oltre caduta_mortale metri si muore lì
	var appoggiato := p.is_on_floor() or p.is_sliding or p.is_on_ladder() or p.is_in_water()
	if _in_sala(p.global_position):
		if appoggiato:
			if _in_aria and _quota_stacco - y > caduta_mortale:
				_in_aria = false
				GameState.kill_player(&"caduta")
				return
			_in_aria = false
		elif not _in_aria:
			_in_aria = true
			_quota_stacco = y
		else:
			_quota_stacco = maxf(_quota_stacco, y)
	else:
		_in_aria = false
	_guida_imbocchi(p, _delta)
	# la luce di lei sale dal pozzo: più forte man mano che scendi
	var k := clampf((_quote_cp[0] - y) / maxf(_quote_cp[0] - _quote_cp[-1], 1.0), 0.0, 1.0)
	for l in _lei:
		l.light_energy = float(l.get_meta(&"base")) * lerpf(lei_in_cima, lei_in_fondo, k) / lei_in_fondo


func _prepara_imbocchi() -> void:
	for tr in dati["tratti"]:
		var linea: Array = tr["linee"][0]
		var pts := PackedVector3Array()
		var lung := 0.0
		for i in linea.size():
			var q := b(linea[i])
			if i > 0:
				lung += q.distance_to(pts[i - 1])
			pts.append(q)
			if lung > guida_metri:
				break
		_imbocchi.append(pts)


func _guida_imbocchi(p: Player, delta: float) -> void:
	var hv := Vector3(p.velocity.x, 0.0, p.velocity.z)
	if hv.length() > guida_fino_a or p.slide_launched:
		return
	var pos := p.global_position
	for pts in _imbocchi:
		# il segmento più vicino (in pianta) dei primi metri del canale, o il prolungamento davanti all'imbocco
		var migliore := -1
		var dm := 1.5
		for i in pts.size() - 1:
			if pos.y - pts[i].y > 2.0 or pos.y - pts[i].y < -1.0:
				continue
			var a := Vector2(pts[i].x, pts[i].z)
			var c := Vector2(pts[i + 1].x, pts[i + 1].z)
			if i == 0:
				a -= (c - a).normalized() * 1.2      # davanti all'imbocco, dentro l'imbuto
			var d := Geometry2D.get_closest_point_to_segment(Vector2(pos.x, pos.z), a, c).distance_to(Vector2(pos.x, pos.z))
			if d < dm:
				dm = d
				migliore = i
		if migliore < 0:
			continue
		var t := Vector3(pts[migliore + 1].x - pts[migliore].x, 0.0, pts[migliore + 1].z - pts[migliore].z).normalized()
		# solo chi va verso il canale (o ci scivola già): l'acqua lo porta dentro e al centro
		if hv.dot(t) < 0.1 and not p.is_sliding:
			return
		var lat := Vector3(-t.z, 0.0, t.x)
		var e := (pos - pts[migliore]).dot(lat)
		var voluta := (t - lat * clampf(e, -1.0, 1.0) * 0.9).normalized() * maxf(hv.length(), 2.6)
		hv = hv.lerp(voluta, clampf(guida_forza * delta, 0.0, 1.0))
		p.velocity.x = hv.x
		p.velocity.z = hv.z
		return


func _in_sala(pos: Vector3) -> bool:
	return pos.x > 20.2 and pos.x < 40.0 and pos.z > -26.0 and pos.z < -4.0


## Indice dell'ultimo checkpoint della torre raggiunto (-1 se nessuno).
func checkpoint_raggiunto() -> int:
	var key := String(GameState.snapshot.get("checkpoint", ""))
	for i in range(checkpoint.size() - 1, -1, -1):
		if is_instance_valid(checkpoint[i]) and GameState.persist_key(checkpoint[i]) == key:
			return i
	var ordine := int(GameState.snapshot.get("order", -1))
	return clampi(ordine - ordine_base, -1, checkpoint.size() - 1) if ordine >= ordine_base else -1


func _polaroid() -> void:
	var foto: Node3D = (load("res://scenes/props/polaroid.tscn") as PackedScene).instantiate()
	foto.name = "Polaroid10"
	if &"photo" in foto:
		foto.set(&"photo", 10)
	# Appoggiata sul sedile, lungo la stecca: con lo snap (raggio dall'alto) finiva in cima allo schienale,
	# o 5 cm sopra il sedile se il lettino non era ancora costruito (tests/polaroid_libere.gd).
	foto.set(&"snap_to_surface", false)
	add_child(foto)
	# il fondo mezzo millimetro sopra la stecca più alta sotto la foto (a -11,670; collaudo del 23 ottobre: a +1 cm
	# restava 8 mm sopra il sedile, posata sul doppione di sotto)
	foto.global_position = b(dati["polaroid_10"]) + Vector3(0, 0.0023, 0)
	foto.global_rotation = Vector3(0.0, PI * 0.5, 0.0)
	# la Polaroid ferma del modello (torre_a.py, per i render) è un doppione sotto quella vera: copriva quella da
	# raccogliere e la teneva staccata dal lettino
	var doppione := find_child("torre_polaroid_10", true, false)
	if doppione:
		doppione.queue_free()
	# la Polaroid 12 (l'ultima sera di festa, col temporale lontano, proposta del 25 ottobre notte): in cima, per terra
	# nell'angolo sud-est del pianerottolo del portone, alle spalle di chi entra e va verso il primo scivolo (a nord)
	# (sul grigliato: l'altezza sulle barre, sotto tutta la foto, è calcolata una volta da tests/posa_polaroid12.gd; a
	# gioco avviato i raggi mentre la torre si costruisce facevano fotogrammi da 130 ms, test_attesa_zone del 29 ottobre)
	var p12 := b([22.1, 13.95, 0.0])
	p12.y = -0.0063
	PolaroidPhoto.metti(self, 12, p12, 30.0, true)


## La fila di bambini sulla balconata: invisibili; al primo salto un lampo li mostra per un attimo.
func _balconata() -> void:
	for passo in _passi_balconata():
		(passo as Callable).call()


## I passi di [method _balconata]: un bambino per passo (ognuno costa decine di ms), poi il lampo.
func _passi_balconata() -> Array:
	var out: Array = []
	for i in 4:
		out.append(func(): _bambino_balconata(i))
	out.append(_lampo_balconata)
	return out


func _bambino_balconata(i: int) -> void:
	var c := b(dati["balconata"]["centro"])
	var salto := b(dati["balconata"]["primo_salto"])
	var bimbo: Node3D = (load(BAMBINI[i % 2]) as PackedScene).instantiate()
	bimbo.name = "BambinoBalconata%d" % i
	add_child(bimbo)
	bimbo.global_position = c + Vector3(-1.8 + 1.2 * i, 0.0, -0.3)
	var verso := Vector3(salto.x, bimbo.global_position.y, salto.z)
	if verso.distance_to(bimbo.global_position) > 0.1:
		bimbo.look_at(verso, Vector3.UP, true)
	bimbo.visible = false
	bimbo.process_mode = Node.PROCESS_MODE_DISABLED
	_bambini.append(bimbo)


func _lampo_balconata() -> void:
	var c := b(dati["balconata"]["centro"])
	var salto := b(dati["balconata"]["primo_salto"])
	var area := Area3D.new()
	area.name = "LampoBalconata"
	area.collision_layer = 0
	area.collision_mask = Layers.PLAYER
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var sfera := SphereShape3D.new()
	sfera.radius = 2.2
	forma.shape = sfera
	area.add_child(forma)
	add_child(area)
	area.global_position = salto
	area.body_entered.connect(func(corpo):
		if corpo is Player and not _lampo_fatto:
			lampo())
	var luce := OmniLight3D.new()
	luce.name = "LuceLampo"
	luce.light_color = Color(0.85, 0.9, 1.0)
	luce.light_energy = 0.0
	luce.omni_range = 9.0
	luce.shadow_enabled = true
	add_child(luce)
	luce.global_position = c + Vector3(0, 2.6, 1.2)


## Il lampo: la luce bianca sopra la balconata scatta, i bambini si vedono per un istante e spariscono.
func lampo() -> void:
	if _lampo_fatto:
		return
	_lampo_fatto = true
	var luce := get_node_or_null("LuceLampo") as OmniLight3D
	for bimbo in _bambini:
		bimbo.visible = true
	if luce:
		luce.light_energy = 14.0
	await get_tree().create_timer(0.12, false).timeout
	if luce:
		luce.light_energy = 2.0
	await get_tree().create_timer(0.08, false).timeout
	if luce:
		luce.light_energy = 16.0
	await get_tree().create_timer(0.22, false).timeout
	if luce:
		luce.light_energy = 0.0
	for bimbo in _bambini:
		if is_instance_valid(bimbo):
			bimbo.queue_free()
	_bambini.clear()


func _vasca_fondo() -> void:
	var v: Array = dati["vasca_fondo"]["rett"]
	var area := Area3D.new()
	area.name = "VascaFondo"
	area.collision_layer = 0
	area.collision_mask = Layers.PLAYER
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(v[2] - v[0] - 0.4, 1.4, v[3] - v[1] - 0.4)
	forma.shape = box
	area.add_child(forma)
	add_child(area)
	area.global_position = b([(v[0] + v[2]) / 2.0, (v[1] + v[3]) / 2.0, float(dati["vasca_fondo"]["acqua"]) - 0.2])
	area.body_entered.connect(func(corpo):
		if corpo is Player and not _finita and inseguimento_scena == null:
			_finita = true
			discesa_finita.emit())


## L'oblò con lei (ObloLei di enigmi, con la posa di mascotte) nel foro del muro est che il GLB lascia accanto alla
## bocca del tubo (torre_a.py, OBLO_*): dietro, nella sala delle condotte, la cisterna piena d'acqua (il fuori lo fa
## inseguimento_proposte.py, l'interno l'oblò). Il muro con la piastra va dalla faccia della torre (x 40) a quella delle
## condotte (x 40,4). Lei compare una volta sola al fondo della discesa, prima dell'inseguimento: entrando nella bocca
## (o quando lei compare nelle condotte) se ne va col suo distacco lento, e non torna più.
func _oblo_lei() -> void:
	if not oblo_lei or not dati.has("oblo_lei") or oblo:
		return
	var d: Dictionary = dati["oblo_lei"]
	var centro := b(d["centro"])
	var normale := b(d["normale"]).normalized()
	oblo = ObloLei.new()
	oblo.name = "ObloLei"
	oblo.posa = oblo_posa if oblo_posa in LeiOblo.POSE else "schiacciata"
	oblo.raggio_vetro = oblo_raggio_vetro
	oblo.spessore_muro = 0.4
	# la cisterna profonda 3,6 m (mascotte: la posa "occhio" arrivando e staccandosi va fino a 3,4 m dietro il vetro);
	# il fuori è nel GLB delle condotte (inseguimento_proposte.py, OBLO_VASCA)
	oblo.vasca_fonda = 3.6
	# (le ombre della luce di lei più strette che negli altri oblò: con i bias di serie passava dagli spigoli sottili
	# della cisterna, righe rosa nella sala delle condotte, collaudo finale del 25 ottobre)
	oblo.bias_ombre = Vector2(0.03, 0.2)
	# (e attorno alla vasca il guscio che fa solo ombra: la cisterna fuori, nel GLB delle condotte, è di lamiere da una
	# faccia sola, e dal suo spigolo in alto passava ancora una riga rosa; ricontrollo del 29 ottobre)
	oblo.guscio_ombra = 0.03
	oblo.veli_colore = oblo_veli_rossi
	oblo.vetro_colore = oblo_vetro_rosso
	# lei compare col giocatore al fondo (sul pavimento, in vasca o sui gradini della bocca), non sugli scivoli sopra
	var v: Array = dati["vasca_fondo"]["rett"]
	var lo := b([30.0, float(v[3]) + 6.0, FONDO_Z - 0.5])
	var hi := b([float(d["centro"][0]) - 0.1, float(v[1]) - 5.0, FONDO_Z + 2.6])
	oblo.zona = AABB(lo.min(hi), (hi - lo).abs())
	var xf := Transform3D(Basis.looking_at(-normale, Vector3.UP), centro)
	oblo.muro = _muro_oblo()
	oblo.transform = global_transform.affine_inverse() * xf
	add_child(oblo)
	# entrando nella bocca del tubo parte l'inseguimento: lei se ne va (e non compare più)
	var bocca := Area3D.new()
	bocca.name = "BoccaOblo"
	bocca.collision_layer = 0
	bocca.collision_mask = Layers.PLAYER
	bocca.monitorable = false
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.0, 2.0)
	forma.shape = box
	bocca.add_child(forma)
	add_child(bocca)
	bocca.global_position = b([38.8, 17.4, FONDO_Z + 1.6])
	bocca.body_entered.connect(func(corpo):
		if corpo is Player:
			_oblo_via())
	inseguimento_aggiunto.connect(func(ins: Node3D):
		if ins.has_signal(&"lei_compare"):
			ins.connect(&"lei_compare", func(_dove): _oblo_via()))


## Il muro della torre attorno all'oblò (scelta dell'utente del 25 ottobre: niente piastra quadrata scura, le
## piastrelle e l'intonaco arrivano fino alla cornice d'ottone): le fasce di ObloLei.muro, lette da [constant MURO_OBLO]
## (calcolate una volta da [method calcola_muro_oblo]: farlo qui costava più di 100 ms in un passo, collaudo della CI)
## coi materiali veri di torre_A.
const MURO_OBLO := "res://assets/ambiente/torre/oblo_muro.json"


func _muro_oblo() -> Array:
	var out := []
	var mi := find_child("torre_A", true, false) as MeshInstance3D
	if mi == null or mi.mesh == null or not FileAccess.file_exists(MURO_OBLO):
		return out
	for f in JSON.parse_string(FileAccess.get_file_as_string(MURO_OBLO)):
		var i := int(f["superficie"])
		if i >= mi.mesh.get_surface_count() or mi.get_active_material(i) == null or mi.get_active_material(i).resource_name != String(f["materiale"]):
			push_warning("torre: il muro dell'oblò non corrisponde più a torre_A (rifai tests/aggiorna_muro_oblo_torre.gd)")
			return []
		var u: Array = f["uv"]
		var fascia := {"materiale": mi.get_active_material(i), "da": float(f["da"]), "a": float(f["a"]),
				"uv": Transform2D(Vector2(u[0], u[1]), Vector2(u[2], u[3]), Vector2(u[4], u[5]))}
		if f.has("colore"):
			var c: Array = f["colore"]
			fascia["colore"] = Color(c[0], c[1], c[2], c[3])
		out.append(fascia)
	return out


## Il muro della torre attorno all'oblò, calcolato dalla mesh (lento: guarda tutti i triangoli di torre_A; lo usa
## tests/aggiorna_muro_oblo_torre.gd, che lo salva in [constant MURO_OBLO]): per ogni superficie di torre_A che sta nel
## piano del muro dove c'è il foro, il nome del materiale, le quote che copre, come le sue UV seguono il muro (ricavate da
## un suo triangolo) e la media dei colori dei vertici, nelle coordinate dell'oblò [param xf].
static func calcola_muro_oblo(mi: MeshInstance3D, xf: Transform3D, h: float) -> Array:
	var out := []
	var verso := xf.affine_inverse() * mi.global_transform
	for i in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(i)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var idx = arr[Mesh.ARRAY_INDEX]
		if uv.is_empty():
			continue
		var col = arr[Mesh.ARRAY_COLOR]
		var somma := Color(0, 0, 0, 0)
		var quanti := 0
		var y0 := INF
		var y1 := -INF
		var t := Transform2D()
		var trovata := false
		var n: int = (idx as PackedInt32Array).size() if idx != null else v.size()
		for k in range(0, n, 3):
			var ii := [idx[k], idx[k + 1], idx[k + 2]] if idx != null else [k, k + 1, k + 2]
			var p := [verso * v[ii[0]], verso * v[ii[1]], verso * v[ii[2]]]
			# (nel piano del muro, la faccia verso la sala, vicino al foro)
			if absf(p[0].z) > 0.01 or absf(p[1].z) > 0.01 or absf(p[2].z) > 0.01:
				continue
			var lo := Vector2(minf(p[0].x, minf(p[1].x, p[2].x)), minf(p[0].y, minf(p[1].y, p[2].y)))
			var hi := Vector2(maxf(p[0].x, maxf(p[1].x, p[2].x)), maxf(p[0].y, maxf(p[1].y, p[2].y)))
			if hi.x < -h - 0.5 or lo.x > h + 0.5 or hi.y < -h - 0.5 or lo.y > h + 0.5:
				continue
			var e1 := Vector2(p[1].x - p[0].x, p[1].y - p[0].y)
			var e2 := Vector2(p[2].x - p[0].x, p[2].y - p[0].y)
			var det := e1.x * e2.y - e1.y * e2.x
			if absf(det) < 1e-4:
				continue
			y0 = minf(y0, lo.y)
			y1 = maxf(y1, hi.y)
			if col != null and not (col as PackedColorArray).is_empty():
				for j in ii:
					somma += (col as PackedColorArray)[j]
					quanti += 1
			if not trovata:
				# uv = A (x, y) + b: A = F E^-1
				var f1 := uv[ii[1]] - uv[ii[0]]
				var f2 := uv[ii[2]] - uv[ii[0]]
				var ei := Transform2D(Vector2(e2.y, -e1.y) / det, Vector2(-e2.x, e1.x) / det, Vector2.ZERO)
				var fa := Transform2D(f1, f2, Vector2.ZERO)
				t = fa * ei
				t.origin = uv[ii[0]] - t.basis_xform(Vector2(p[0].x, p[0].y))
				trovata = true
		if trovata:
			var fascia := {"superficie": i, "materiale": mi.get_active_material(i).resource_name, "da": y0, "a": y1,
					"uv": [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]}
			# (i materiali della torre usano il colore dei vertici come albedo: la faccia nuova prende la media di quelli del
			# muro attorno, se no veniva più chiara; collaudo D1)
			if quanti > 0:
				var cm := somma / float(quanti)
				fascia["colore"] = [cm.r, cm.g, cm.b, cm.a]
			out.append(fascia)
	return out


func _oblo_via() -> void:
	if oblo and is_instance_valid(oblo):
		oblo.attivo = false
		oblo.via()


# --- luci ------------------------------------------------------------------------------------------

func _luce_lei() -> void:
	var p := b(dati["pozzo"])
	var fondo := MeshInstance3D.new()
	fondo.name = "FondoPozzo"
	var cil := CylinderMesh.new()
	# largo quanto il pozzo dentro (r 1,75 in torre_proposte.pozzo_lei): incastrato tra le pareti, non sospeso
	cil.top_radius = 1.75
	cil.bottom_radius = 1.75
	cil.height = 0.05
	fondo.mesh = cil
	fondo.material_override = _materiale_fondo_pozzo()
	add_child(fondo)
	fondo.global_position = p + Vector3(0, -5.0, 0)
	for d in [[Vector3(0, -0.8, 0), 14.0, 10.0, false], [Vector3(0, -3.5, 0), 10.0, 4.0, false]]:
		var o := OmniLight3D.new()
		o.light_color = ROSA
		o.omni_range = d[2]
		o.light_volumetric_fog_energy = 3.0
		o.set_meta(&"base", d[1])
		o.set_meta(&"risveglio_ignora", true)
		add_child(o)
		o.global_position = p + d[0]
		_lei.append(o)
	var s := SpotLight3D.new()
	s.light_color = ROSA
	s.spot_range = 30.0
	s.spot_angle = 16.0
	s.shadow_enabled = true
	s.light_volumetric_fog_energy = 4.0
	s.set_meta(&"base", 22.0)
	s.set_meta(&"risveglio_ignora", true)
	add_child(s)
	s.global_position = p + Vector3(0, -2.5, 0)
	s.rotation_degrees = Vector3(90, 0, 0)
	_lei.append(s)


## Le luci della torre restano accese col blackout (dopo la tappa 6 la torre è illuminata così).
## LuciRisveglio, alla ripartenza da un checkpoint nella torre, spegne tutte le luci della scena che non
## hanno risveglio_ignora: e la torre, che lì si costruisce subito, diventava tutta buia.
func _fuori_dal_blackout() -> void:
	for l in find_children("*", "Light3D", true, false):
		l.set_meta(&"risveglio_ignora", true)


func _luci(d: Dictionary) -> void:
	for passo in _passi_luci(d):
		(passo as Callable).call()


## I passi di [method _luci]: una lampada (o un faro, o un gocciolatoio) per passo.
func _passi_luci(d: Dictionary = {}) -> Array:
	if d.is_empty():
		d = JSON.parse_string(FileAccess.get_file_as_string(DIR + "torre_luci.json"))
	var versi := {"e": Vector3.RIGHT, "o": Vector3.LEFT, "n": Vector3.FORWARD, "s": Vector3.BACK}
	var out: Array = [func():
		var radice := Node3D.new()
		radice.name = "Luci"
		add_child(radice)]
	var luci := func() -> Node3D: return get_node(^"Luci") as Node3D
	for e in d["emergenza"]:
		out.append(func(): _emergenza(luci.call(), b(e[0]), versi[e[1]]))
	for p in d["lavoro"]:
		out.append(func(): _lampada(luci.call(), b(p), str(p[3]) if (p as Array).size() > 3 else ""))
	for f in d["fari"]:
		out.append(func(): _faro(luci.call(), b(f[0]), b(f[1]), b(f[2]) if (f as Array).size() > 2 else null))
	for g in d["gocce"]:
		out.append(func(): _gocce(luci.call(), b(g)))
	out.append(func(): _catena(luci.call(), b(d["lei"])))
	out.append(func(): _segnali_strada(luci.call()))
	return out


const VERDE := Color(0.1, 1.0, 0.3)


## La strada che si legge (S1, S2): sul portale di ogni imbocco della discesa i led verdi lungo i montanti e la
## traversa e la lampada verde che illumina il canale; sopra i cancelli delle bocche chiuse una lampada
## rossa, guasta che sfarfalla o spenta (una sì e una no). Dai dati di torre_gioco.json.
func _segnali_strada(radice: Node3D) -> void:
	var led := SphereMesh.new()
	led.radius = 0.035
	led.height = 0.07
	led.radial_segments = 8
	led.rings = 4
	var m_led := _emissivo(VERDE, 1.8)   # più forte si brucia in bianco e il verde non si legge
	for im in dati.get("imbocchi", []):
		var base := b(im["base"])
		var v := Vector3(float(im["verso"][0]), 0.0, -float(im["verso"][1])).normalized()
		var lat := v.cross(Vector3.UP).normalized()
		var mezza: float = im["mezza"]
		var alto: float = im["alto"]
		var punti := PackedVector3Array()
		for sg in [-1.0, 1.0]:
			var y := 0.35
			while y < alto - 0.05:
				punti.append(base + lat * (sg * mezza) + Vector3.UP * y - v * 0.08)
				y += 0.25
		var x := -mezza + 0.2
		var sp := get_world_3d().direct_space_state if is_inside_tree() else null
		while x < mezza - 0.1:
			var q := base + lat * x + Vector3.UP * (alto - 0.09) - v * 0.06
			if sp:
				# appoggiato alla traversa: il led va a contatto con la cosa più vicina sopra o dietro (dai dati restava
				# staccato di qualche centimetro), infilato di 5 mm
				var meglio := INF
				var spinta := Vector3.ZERO
				for dir in [Vector3.UP, v]:
					var h := sp.intersect_ray(PhysicsRayQueryParameters3D.create(q, q + dir * 0.2, Layers.WORLD))
					if not h.is_empty():
						var d := q.distance_to(h.position as Vector3)
						if d < meglio:
							meglio = d
							spinta = dir * maxf(d - led.radius + 0.005, 0.0)
				q += spinta
			punti.append(q)
			x += 0.25
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = led
		mm.instance_count = punti.size()
		var tr: Array[Transform3D] = []
		for i in punti.size():
			tr.append(Transform3D(Basis.IDENTITY, punti[i]))
			mm.set_instance_transform(i, tr[i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "LedImbocco"
		mi.multimesh = mm
		# per il controllo di posizionamento: senza schermo il MultiMesh non conserva le trasformazioni
		mi.set_meta(&"trasformazioni", tr)
		mi.material_override = m_led
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		radice.add_child(mi)
		# la lampada verde sopra la traversa, puntata sull'imbocco
		var lampada := base + Vector3.UP * (alto + 0.47)
		_lampada_segnale(radice, lampada, VERDE, true)
		var s_ := SpotLight3D.new()
		s_.light_color = VERDE
		s_.light_energy = 9.0
		s_.spot_range = 7.0
		s_.spot_angle = 32.0
		s_.light_volumetric_fog_energy = 1.5
		s_.set_meta(&"risveglio_ignora", true)
		radice.add_child(s_)
		s_.global_position = lampada - v * 0.2
		s_.look_at(base + v * 1.6, Vector3.UP)
		var o := OmniLight3D.new()
		o.light_color = VERDE
		o.light_energy = 1.2
		o.omni_range = 4.0
		o.set_meta(&"risveglio_ignora", true)
		radice.add_child(o)
		o.global_position = base + Vector3.UP * (alto - 0.4) - v * 0.5
	var k := 0
	for bc in dati.get("bocche_chiuse", []):
		if bool(bc["tubo"]):
			continue     # i tubi chiusi dalla grata restano al buio
		var p := b(bc["pos"]) + Vector3.UP * 2.45
		var accesa := k % 2 == 0
		var luce := _lampada_segnale(radice, p, ROSSO, accesa)
		if accesa:
			_sfarfalla(luce, k)
		k += 1


## Una lampada di segnalazione appoggiata sotto (base nera, vetro colorato). Torna la sua luce (null se spenta).
func _lampada_segnale(radice: Node3D, p: Vector3, colore: Color, accesa: bool) -> OmniLight3D:
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.11
	bm.bottom_radius = 0.13
	bm.height = 0.08
	base.mesh = bm
	base.material_override = _metallo_scuro()
	radice.add_child(base)
	base.global_position = p + Vector3.UP * 0.04
	var vetro := MeshInstance3D.new()
	var vm := CylinderMesh.new()
	vm.top_radius = 0.07
	vm.bottom_radius = 0.09
	vm.height = 0.16
	vetro.mesh = vm
	vetro.material_override = _emissivo(colore, 2.2 if accesa else 0.0)
	vetro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	radice.add_child(vetro)
	vetro.global_position = p + Vector3.UP * 0.16
	if not accesa:
		(vetro.material_override as StandardMaterial3D).albedo_color = colore.darkened(0.6)
		return null
	var l := OmniLight3D.new()
	l.light_color = colore
	l.light_energy = 1.6
	l.omni_range = 3.5
	l.set_meta(&"risveglio_ignora", true)
	radice.add_child(l)
	l.global_position = p + Vector3.UP * 0.2
	l.set_meta(&"vetro", vetro)
	return l


## La lampada rossa guasta: si spegne e riaccende a scatti (ognuna col suo ritmo).
func _sfarfalla(l: OmniLight3D, seme: int) -> void:
	var vetro := l.get_meta(&"vetro") as MeshInstance3D
	var mat := vetro.material_override as StandardMaterial3D
	var ritmo := [0.9, 0.06, 0.12, 0.05, 1.6, 0.08, 0.4, 0.07]
	l.set_meta(&"sfarfalla", true)      # guasta, ma accesa (per i controlli delle luci)
	var tw := create_tween().set_loops()
	for i in ritmo.size():
		var d: float = ritmo[(i + seme) % ritmo.size()]
		# l'energia, non visible: accendere e spegnere la luce rifà gli abbinamenti luce-geometria del renderer
		tw.tween_callback(func():
			var accesa := l.light_energy < 0.5
			l.light_energy = 1.6 if accesa else 0.0
			mat.emission_energy_multiplier = 2.2 if accesa else 0.3)
		tw.tween_interval(d)


static func _emissivo(colore: Color, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.emission_enabled = true
	m.emission = colore
	m.emission_energy_multiplier = energia
	return m


func _emergenza(radice: Node3D, p: Vector3, verso: Vector3) -> void:
	var corpo := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.16, 0.3, 0.3) if absf(verso.x) > 0.5 else Vector3(0.3, 0.3, 0.16)
	corpo.mesh = bx
	corpo.material_override = _emissivo(ROSSO, 6.0)
	radice.add_child(corpo)
	corpo.global_position = p
	# appoggiata al muro dietro (il retro della scatola, 8 cm dietro il centro): dai dati restava a 1-3 cm
	Posa.fissa_al_muro(corpo, verso, 0.08)
	# davanti a un tubo il raggio dal centro non trova il punto più sporgente sotto il retro: 9 raggi su tutto il retro e
	# la scatola si appoggia al più sporgente (collaudo del 24 ottobre: una lampada a 8 mm dal tubo, senza niente sotto)
	var v := verso.normalized()
	var a1 := v.cross(Vector3.UP).normalized() if absf(v.y) < 0.9 else Vector3.RIGHT
	var a2 := v.cross(a1).normalized()
	var p0 := corpo.global_position
	var davanti := -INF
	for i in [-1, 0, 1]:
		for j in [-1, 0, 1]:
			var o: Vector3 = a1 * (i * 0.14) + a2 * (j * 0.14)
			var h := Posa._raggio(corpo, p0 + o + v * 0.3, p0 + o - v * Posa.PORTATA, [])
			if not h.is_empty():
				davanti = maxf(davanti, (h.position as Vector3).dot(v))
	if davanti > -INF:
		corpo.global_position = p0 + v * (davanti + 0.08 - p0.dot(v))
	p = corpo.global_position
	var l := OmniLight3D.new()
	l.light_color = ROSSO
	l.light_energy = 3.5
	l.omni_range = 7.5
	l.light_volumetric_fog_energy = 1.5
	# sul muro est, quello in comune con la sala delle condotte, con l'ombra: senza, la luce passava il muro e faceva
	# una riga rossa su uno spigolo delle condotte accanto alla cisterna dell'oblò (ricontrollo del 29 ottobre)
	l.shadow_enabled = absf(p.x - MURO_CONDOTTE_X) < 1.0
	radice.add_child(l)
	l.global_position = p + verso * 0.4


func _lampada(radice: Node3D, p: Vector3, appoggio := "") -> void:
	# lampada da cantiere: bulbo caldo in una gabbia, su un palo dalla pedana o su una staffa al muro
	var bulbo := MeshInstance3D.new()
	var sf := SphereMesh.new()
	sf.radius = 0.07
	sf.height = 0.14
	bulbo.mesh = sf
	bulbo.material_override = _emissivo(Color(1.0, 0.55, 0.25), 1.2)
	radice.add_child(bulbo)
	bulbo.global_position = p
	var metallo := _metallo_scuro()
	var gabbia := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.1
	gm.bottom_radius = 0.1
	gm.height = 0.24
	gm.radial_segments = 8
	gm.rings = 2
	gabbia.mesh = gm
	gabbia.material_override = _materiale_gabbia()
	radice.add_child(gabbia)
	gabbia.global_position = p
	var cappello := MeshInstance3D.new()
	var cp := CylinderMesh.new()
	cp.top_radius = 0.06
	cp.bottom_radius = 0.13
	cp.height = 0.07
	cappello.mesh = cp
	cappello.material_override = metallo
	radice.add_child(cappello)
	cappello.global_position = p + Vector3(0, 0.15, 0)
	# il portalampada: il bulbo è avvitato sotto il cappello (senza, galleggiava dentro la gabbia)
	_asta(radice, p + Vector3(0, 0.05, 0), p + Vector3(0, 0.13, 0), 0.028, metallo)
	if appoggio == "palo":
		# il palo fino alla pedana vera sotto (dai dati finiva 1 cm sopra), piantato 2 cm
		var giu := p + Vector3(0, -1.25, 0)
		var sp := get_world_3d().direct_space_state if is_inside_tree() else null
		if sp:
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, -0.2, 0), p + Vector3(0, -3.0, 0), Layers.WORLD)
			var h := sp.intersect_ray(q)
			if not h.is_empty():
				giu = (h.position as Vector3) + Vector3(0, -0.02, 0)
		_asta(radice, p + Vector3(0, 0.18, 0), giu, 0.03, metallo)
	elif appoggio.begins_with("muro_"):
		var verso: Vector3 = {"muro_n": Vector3.FORWARD, "muro_s": Vector3.BACK, "muro_e": Vector3.RIGHT, "muro_o": Vector3.LEFT}[appoggio]
		# il braccio fino al muro vero (a 0,4 m fissi restava 5 cm prima: collaudo del 22 sera)
		var da := p + Vector3(0, 0.18, 0)
		_asta(radice, da, _fino_al_sostegno(da, da + verso * 0.4), 0.025, metallo)
	var l := OmniLight3D.new()
	l.light_color = CALDO
	l.light_energy = 4.0
	l.omni_range = 8.0
	radice.add_child(l)
	l.global_position = p + Vector3(0, -0.15, 0)


## Faro da cantiere su un braccio dalla colonna del traliccio: corpo tondo di metallo, cornice e lente
## tonda calda (non abbagliante), staffa a U. La luce è quella di prima.
func _faro(radice: Node3D, p: Vector3, mira: Vector3, attacco = null) -> void:
	var metallo := _metallo_scuro()
	var corpo := Node3D.new()
	radice.add_child(corpo)
	corpo.global_position = p
	corpo.look_at(mira)
	var guscio := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.2
	cm.height = 0.3
	guscio.mesh = cm
	guscio.material_override = metallo
	corpo.add_child(guscio)
	guscio.rotation_degrees = Vector3(-90, 0, 0)
	var cornice := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.17
	tm.outer_radius = 0.22
	cornice.mesh = tm
	cornice.material_override = metallo
	corpo.add_child(cornice)
	cornice.rotation_degrees = Vector3(90, 0, 0)
	cornice.position = Vector3(0, 0, -0.15)
	var lente := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.175
	lm.bottom_radius = 0.175
	lm.height = 0.02
	lente.mesh = lm
	lente.material_override = _emissivo(Color(1.0, 0.6, 0.28), 0.9)
	corpo.add_child(lente)
	lente.rotation_degrees = Vector3(90, 0, 0)
	lente.position = Vector3(0, 0, -0.145)
	# staffa a U attorno al corpo e braccio fino alla colonna; i due perni reggono il corpo nella staffa (senza, il
	# corpo stava sospeso a 4 cm dai bracci)
	for sg in [-1.0, 1.0]:
		_asta(corpo, Vector3(sg * 0.24, 0, 0), Vector3(sg * 0.24, -0.26, 0), 0.02, metallo, false)
		_asta(corpo, Vector3(sg * 0.25, 0, 0), Vector3(sg * 0.16, 0, 0), 0.025, metallo, false)
	_asta(corpo, Vector3(-0.24, -0.26, 0), Vector3(0.24, -0.26, 0), 0.02, metallo, false)
	if attacco != null:
		# il braccio fino alla superficie della colonna (fino all'asse restava dentro la colonna, senza toccarne la
		# superficie: collaudo del 22 sera)
		var da := corpo.to_global(Vector3(0, -0.26, 0))
		_asta(radice, da, _fino_al_sostegno(da, attacco), 0.04, metallo)
	var l := SpotLight3D.new()
	l.light_color = Color(1.0, 0.88, 0.72)
	l.light_energy = 16.0
	l.spot_range = 30.0
	l.spot_angle = 24.0
	l.spot_attenuation = 0.6
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 0.8
	radice.add_child(l)
	l.global_position = p
	l.look_at(mira)


static func _materiale_gabbia() -> StandardMaterial3D:
	var mg := _metallo_scuro()
	mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mg.albedo_texture = _griglia()
	mg.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mg


static func _materiale_gocce() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.8, 0.85, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	return m


static func _materiale_fondo_pozzo() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = ROSA
	m.emission_enabled = true
	m.emission = ROSA
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## L'acqua torbida delle vasche (la stessa della sala principale).
const ACQUA := "res://assets/materials/sala/acqua_torbida.tres"


## Un materiale per ogni tipo che la torre crea da codice (lampade, gabbie, gocce, fondo del pozzo, l'oblò), più
## l'acqua torbida. Godot fa uno shader per tipo di materiale e lo condivide, ma la prima volta lo crea sul
## thread principale: con il gruppo di shader avanzato acceso (nel gioco lo è sempre, vedi
## Grafica._attiva_shader_avanzati) costa 100-150 ms sulla CPU della CI, troppo per un passo della
## costruzione a pezzi. La sala principale li crea entrando (a schermo nero) e li tiene finché c'è: i passi
## ritrovano gli shader pronti. Chi li chiama deve tenere l'array (gli shader vivono finché c'è un materiale).
static func materiali_campione(crea := true) -> Array[Material]:
	var out: Array[Material] = [_emissivo(Color.WHITE, 1.0), _metallo_scuro(), _materiale_gabbia(),
			_materiale_gocce(), _materiale_fondo_pozzo(), load(ACQUA) as Material]
	# (l'oblò con lei sul muro est: piastra, vasca, ottone, vetro e veli d'acqua)
	for m in ObloLei.materiali():
		out.append(m as Material)
	# (e lei dietro l'oblò, che nasce in tre passi della costruzione: i suoi materiali bagnati, la campana, l'occhio)
	for m in LeiOblo.materiali_campione():
		out.append(m)
	if crea:
		for m in out:
			m.get_rid()   # lo shader si crea adesso, non al primo uso
	return out


static func _metallo_scuro() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.31, 0.29)
	m.metallic = 0.7
	m.roughness = 0.45
	return m


static var _tex_griglia: ImageTexture


static func _griglia() -> ImageTexture:
	if _tex_griglia == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for i in 32:
			for j in 32:
				if i % 8 < 2 or j % 16 < 2:
					img.set_pixel(i, j, Color(1, 1, 1, 1))
		_tex_griglia = ImageTexture.create_from_image(img)
	return _tex_griglia


## Un'asta tonda da a a b (in coordinate del padre se globale = false).
## Il punto dove un braccio che va da [param da] verso [param verso_punto] incontra il sostegno vero (muro, colonna:
## la loro collisione), 5 mm dentro; se non c'è niente, [param verso_punto].
func _fino_al_sostegno(da: Vector3, verso_punto: Vector3) -> Vector3:
	var dir := (verso_punto - da).normalized()
	var sp := get_world_3d().direct_space_state if is_inside_tree() else null
	if sp == null:
		return verso_punto
	var q := PhysicsRayQueryParameters3D.create(da + dir * 0.05, verso_punto + dir * 0.3, Layers.WORLD)
	var h := sp.intersect_ray(q)
	return (h.position as Vector3) + dir * 0.005 if not h.is_empty() else verso_punto


func _asta(padre: Node3D, a: Vector3, b_: Vector3, r: float, m: Material, globale := true) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b_)
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	padre.add_child(mi)
	var centro := (a + b_) * 0.5
	var asse := (b_ - a).normalized()
	var t := Transform3D()
	var su := asse
	var lato := su.cross(Vector3.FORWARD if absf(su.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	t.basis = Basis(lato, su, lato.cross(su))
	t.origin = centro
	if globale:
		mi.global_transform = t
	else:
		mi.transform = t


func _gocce(radice: Node3D, p: Vector3) -> void:
	var g := CPUParticles3D.new()
	var sf := SphereMesh.new()
	sf.radius = 0.012
	sf.height = 0.05
	g.mesh = sf
	g.material_override = _materiale_gocce()
	g.amount = 40
	g.lifetime = 2.0
	g.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	g.emission_box_extents = Vector3(0.3, 0.02, 0.3)
	g.direction = Vector3.DOWN
	g.initial_velocity_min = 0.2
	g.initial_velocity_max = 0.6
	g.gravity = Vector3(0, -9.8, 0)
	radice.add_child(g)
	g.global_position = p


## Una catena appesa al centro del soffitto con tre grappoli di lampade da cantiere.
func _catena(radice: Node3D, fondo: Vector3) -> void:
	var cavo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	var basso := fondo.y + 6.0
	# il cavo arriva all'ultimo braccetto (20 cm sotto l'ultimo grappolo): prima finiva sopra e i braccetti più bassi
	# partivano dal vuoto, poi 10 cm sotto, con il capo libero
	var fine := basso - 0.2 - 0.005
	cm.height = 14.0 - fine
	cavo.mesh = cm
	var nero := StandardMaterial3D.new()
	nero.albedo_color = Color(0.06, 0.06, 0.06)
	nero.metallic = 0.8
	cavo.material_override = nero
	radice.add_child(cavo)
	cavo.global_position = Vector3(fondo.x + 1.2, (14.0 + fine) / 2.0, fondo.z)
	for y in [9.0, -3.0, basso]:
		for k in 3:
			var a := TAU * k / 3.0
			var bulbo := MeshInstance3D.new()
			var sf := SphereMesh.new()
			sf.radius = 0.08
			sf.height = 0.16
			bulbo.mesh = sf
			bulbo.material_override = _emissivo(CALDO, 9.0)
			radice.add_child(bulbo)
			bulbo.global_position = Vector3(fondo.x + 1.2 + cos(a) * 0.35, y - 0.1 * k, fondo.z + sin(a) * 0.35)
			# il braccetto dal cavo alla lampadina (senza, le lampadine galleggiavano intorno al cavo)
			_asta(radice, Vector3(fondo.x + 1.2, y - 0.1 * k, fondo.z), bulbo.global_position, 0.012, nero)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.62)
		l.light_energy = 6.0
		l.omni_range = 15.0
		l.omni_attenuation = 0.8
		l.shadow_enabled = true
		l.light_volumetric_fog_energy = 0.6
		radice.add_child(l)
		l.global_position = Vector3(fondo.x + 1.2, y - 0.2, fondo.z)
