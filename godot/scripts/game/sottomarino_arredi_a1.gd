class_name SottomarinoArrediA1
extends Node3D
## Gli arredi di metà del tunnel del viaggio sottomarino (ambienti-1): la parata dei pesci (240-315), la volta della
## tartaruga (315-390), gli oblò dell'abisso (390-470) e l'approdo (470-535; dopo, fino al portello, è di ambienti-2).
## L'aspetto è il fiume B approvato (GDD, "Il tunnel del viaggio sottomarino... scelte del 24 ottobre").
##
## Le regole del tunnel: le banchine e il canale sono strada (fino a 2 m sopra non c'è niente, salvo gli ostacoli di
## ambienti-2) e sopra il canale c'è lo spazio di lei (a meno di 3,6 m dall'asse fra -29,22 e -24,22, con 20 cm di
## margine). Gli arredi stanno sui muri sopra i 2 m, nella volta sopra di lei o a filo dei pavimenti. Ognuno si appoggia
## alla superficie vera (raggi sui triangoli del tunnel), così non resta staccato neanche dove il muro è a faccette.
##
## Si costruisce a pezzi con il tunnel: [method passi] dà i passi da aggiungere a quelli di [SalaSottomarino].

const DIR_FIUME := "res://assets/fiume_lento/"
const DIR := "res://assets/ambiente/sottomarino/"

## La tartaruga appesa alla chiave della volta (s, scala) e il margine sopra la testa di lei.
const TARTARUGA_S := 366.0
const TARTARUGA_SCALA := 1.5
const SOPRA_LEI := -24.0
## Il buco nella volta sopra le macerie a 348 (s del centro, mezza lunghezza lungo la strada; angolo sulla mezza
## ellisse della volta, da sinistra, e mezza ampiezza): sopra la banchina destra, fuori dallo spazio di lei.
const BUCO_S := 349.6
const BUCO_MEZZO_S := 1.5
const BUCO_THETA := 2.52
const BUCO_MEZZO_THETA := 0.26
## Le reti con le stelle marine sui muri (s, lato, quota del bordo basso sopra le banchine).
const RETI := [[325.0, -1.0, 2.3], [333.5, 1.0, 2.3], [388.3, -1.0, 2.45]]
## Le bitte dell'approdo sul bordo delle banchine (s, lato): basse, sotto i 35 cm.
const BITTE := [[497.0, -1.0], [503.0, 1.0], [517.0, -1.0], [524.0, 1.0]]
## I cartelli a disegni (il portello col volantino e la freccia), a bandiera sui muri, girati verso chi arriva.
const CARTELLI := [[494.0, 1.0], [521.0, -1.0]]
## I fanali d'approdo: rosso a sinistra, verde a destra, dove l'approdo si apre sul portello.
const FANALI_S := 531.0
## Il salvagente fosforescente al muro destro.
const SALVAGENTE_S := 510.0
## Dove stava la vetrina del diorama caduta sulla banchina sinistra a 484 (le staffe vuote e il segno sul muro).
const VETRINA_S := 482.2
const VETRINA_LARGA := 2.48
const VETRINA_ALTA := 1.6
const VETRINA_FONDA := 1.0
const VETRINA_BASSO := 2.05
## L'abisso: le lampade blu (una ogni [constant ABISSO_LAMPADE_OGNI] m, alternate) e le lucine a filo del bordo delle
## banchine (una ogni [constant LUCINE_OGNI] m).
const ABISSO_LAMPADE_OGNI := 18.0
const LUCINE_OGNI := 3.0

var sala: SalaSottomarino
var _tri_pezzi := {}


## I passi da costruire (dopo le luci del tunnel).
static func passi(s: SalaSottomarino) -> Array:
	var a := SottomarinoArrediA1.new()
	a.name = "ArrediA1"
	a.sala = s
	s.add_child(a)
	return [a._tartaruga, a._reti, a._buco_volta, a._abisso_lampade, a._abisso_lucine, a._approdo]


## Vero se a [param s] le luci normali del tunnel (lampade a gabbia e oblò piccoli) non vanno: nell'abisso le fa
## questo file, blu e poche.
static func senza_luci_normali(s: SalaSottomarino, at: float) -> bool:
	return String(s.dati["ambienti"][s.ambiente(at)]["nome"]) == "abisso"


# --- la volta della tartaruga ------------------------------------------------------------------------------------

## La tartaruga di vetroresina appesa sull'asse alla chiave della volta con tre catene, sopra lo spazio di lei; due
## faretti sui muri la illuminano da sotto.
func _tartaruga() -> void:
	var nodo := _nodo("Tartaruga")
	var p := sala.punto(TARTARUGA_S)
	var d := sala.direzione(TARTARUGA_S)
	var r := sala.destra(TARTARUGA_S)
	var t := _modello(nodo, "tartaruga", Vector3(p.x, 0.0, p.z), d, TARTARUGA_SCALA)
	t.name = "tartaruga"
	# appena girata, come se nuotasse verso chi arriva salendo
	t.rotate_object_local(Vector3.RIGHT, deg_to_rad(-8.0))
	var tri_t := _triangoli(t)
	var basso := INF
	for v in tri_t:
		basso = minf(basso, v.y)
	t.position.y += SOPRA_LEI + 0.06 - basso
	tri_t = _triangoli(t)
	# le catene: dal guscio (davanti, dietro a sinistra, dietro a destra) dritte su fino alla volta
	var k := 0
	for off: Vector2 in [Vector2(0.0, -0.55), Vector2(-0.45, 0.45), Vector2(0.45, 0.45)]:
		var base := Vector3(p.x, 0.0, p.z) + r * off.x + d * off.y
		var giu = _raggio(tri_t, Vector3(base.x, -21.0, base.z), Vector3(base.x, -25.0, base.z))
		var su = _raggio(_tri_tunnel(TARTARUGA_S), Vector3(base.x, -24.5, base.z), Vector3(base.x, -21.0, base.z))
		if giu == null or su == null:
			push_warning("tartaruga: catena %d senza attacco" % k)
			continue
		var a: Vector3 = giu
		var b: Vector3 = su
		_piastra(nodo, b, "piastra_tartaruga_%d" % k)
		_catena(nodo, a + Vector3.DOWN * 0.008, b + Vector3.DOWN * 0.012, "catena_tartaruga_%d" % k)
		k += 1
	# i faretti: sui muri, prima e dopo, puntati da sotto sulla pancia
	var centro := Vector3(p.x, SOPRA_LEI + 0.4, p.z)
	_faretto(nodo, TARTARUGA_S - 4.0, -1.0, 3.7, centro, Color(0.75, 0.95, 1.0), 6.0)
	_faretto(nodo, TARTARUGA_S + 3.0, 1.0, 3.7, centro, Color(0.75, 0.95, 1.0), 6.0)


## Le reti con le stelle marine appese ai muri sopra i 2 m.
func _reti() -> void:
	var nodo := _nodo("Reti")
	for q in RETI:
		var s: float = q[0]
		var lato: float = q[1]
		var w = _muro(s, lato, sala.piano + float(q[2]) + 0.47)
		if w == null:
			continue
		var n := _modello(nodo, "rete_stelle", Vector3.ZERO, Vector3.ZERO, 1.0)
		n.name = "rete_stelle_%d" % int(s)
		_a_muro(n, w[0], w[1], sala.piano + float(q[2]))


## Il buco nella volta da cui sono cadute le macerie a 348 (l'ostacolo di ambienti-2, sulla banchina destra): segue
## la volta vera (raggi sui suoi triangoli), con il bordo rotto che parte 1 cm dentro il mosaico e sale di 4 cm, l'interno
## scuro e i ferri dell'armatura che partono dai bordi. Grande quanto le lastre cadute.
func _buco_volta() -> void:
	var nodo := _nodo("BucoVolta")
	var sc := BUCO_S
	var tri := _tri_tunnel(sc)
	var mu := sala.muro
	var ki := sala.chiave - sala.imposta
	var n_ang := 28
	var anelli := [1.0, 0.93, 0.85, 0.6, 0.3, 0.0]
	var alzo := [-0.01, 0.04, 0.015, 0.015, 0.015, 0.015]
	var rng := RandomNumberGenerator.new()
	rng.seed = 348
	var raggio_j := PackedFloat32Array()
	for j in n_ang:
		raggio_j.append(1.0 + rng.randf_range(-0.16, 0.12) + 0.06 * sin(float(j) * 1.7))
	# ogni vertice: (anello, spicchio) -> punto sulla volta vera e sua normale
	var pv := []
	var nv := []
	for k in anelli.size():
		var riga := []
		var rn := []
		for j in n_ang:
			var a := TAU * float(j) / n_ang
			var f: float = anelli[k] * raggio_j[j]
			var s := sc + cos(a) * BUCO_MEZZO_S * f
			var th := BUCO_THETA + sin(a) * BUCO_MEZZO_THETA * f
			var p := sala.punto(s)
			var r := sala.destra(s)
			var su := Vector2(-cos(th) * mu, sala.imposta + sin(th) * ki)
			var da := sala._al(p, r, Vector2(su.x * 0.8, sala.imposta + (su.y - sala.imposta) * 0.8))
			var fino := sala._al(p, r, Vector2(su.x * 1.1, sala.imposta + (su.y - sala.imposta) * 1.1))
			var h = _raggio(tri, da, fino, true)
			if h == null:
				push_warning("buco nella volta: niente volta a s %.2f" % s)
				return
			riga.append((h[0] as Vector3) + (h[1] as Vector3) * float(alzo[k]))
			rn.append(h[1])
		pv.append(riga)
		nv.append(rn)
	var st_b := SurfaceTool.new()
	st_b.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_i := SurfaceTool.new()
	st_i.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in anelli.size() - 1:
		var st := st_b if k < 2 else st_i
		for j in n_ang:
			var j2 := (j + 1) % n_ang
			var verso: Vector3 = nv[k][j]
			if k == anelli.size() - 2:
				sala._tri(st, [pv[k][j], pv[k][j2], pv[k + 1][j]], verso)
			else:
				sala._quad(st, [pv[k][j], pv[k][j2], pv[k + 1][j2], pv[k + 1][j]], verso)
	var bordo := MeshInstance3D.new()
	bordo.name = "buco_volta_bordo"
	bordo.mesh = st_b.commit()
	bordo.material_override = _mat("cemento_rotto", Color(0.46, 0.45, 0.42), 0.95)
	nodo.add_child(bordo)
	var dentro := MeshInstance3D.new()
	dentro.name = "buco_volta_dentro"
	dentro.mesh = st_i.commit()
	dentro.material_override = _mat("buio_buco", Color(0.03, 0.03, 0.035), 1.0)
	nodo.add_child(dentro)
	# i ferri dell'armatura: da un punto del bordo a uno di fronte, piegati verso il basso (sono rimasti appesi)
	var mf := _mat("ferro_armatura", Color(0.24, 0.16, 0.11), 0.85, 0.4)
	for q in [[2, 15, 0.12], [6, 19, 0.2], [9, 24, 0.08], [12, 26, 0.16]]:
		# (i capi 1 cm dentro la volta, sotto il bordo rotto: escono dal cemento)
		var a: Vector3 = pv[0][q[0]]
		var b: Vector3 = pv[0][q[1]]
		var nm: Vector3 = ((nv[1][q[0]] as Vector3) + (nv[1][q[1]] as Vector3)).normalized()
		var m := (a + b) * 0.5 + nm * float(q[2])
		var ferro := Node3D.new()
		ferro.name = "ferro_armatura_%d" % q[0]
		nodo.add_child(ferro)
		sala._palo(ferro, a, m, 0.008, mf)
		sala._palo(ferro, m, b, 0.008, mf)


# --- gli oblò dell'abisso ----------------------------------------------------------------------------------------

## Le lampade dell'abisso: poche e blu scure, alternate sui muri.
func _abisso_lampade() -> void:
	var nodo := _nodo("AbissoLampade")
	var amb := _ambiente("abisso")
	var s := float(amb[0]) + 6.0
	var lato := 1.0
	while s < float(amb[1]) - 3.0:
		if _sala_ha_lampada_vicina(s, lato):
			s += 2.0
			continue
		sala._lampada(nodo, s, lato, sala.piano + 3.0, 1.6)
		var l := nodo.get_child(nodo.get_child_count() - 2) as Node3D
		var g := l.find_child("globo", true, false) as MeshInstance3D
		if g:
			g.material_override = _mat("globo_blu", Color(0.35, 0.5, 1.0), 0.4, 0.0, Color(0.25, 0.42, 1.0), 2.5)
		var o := nodo.get_child(nodo.get_child_count() - 1) as OmniLight3D
		o.light_color = Color(0.32, 0.48, 1.0)
		s += ABISSO_LAMPADE_OGNI
		lato = -lato


## Le lucine a filo del bordo delle banchine, azzurre: di notte disegnano dove finisce la banchina.
func _abisso_lucine() -> void:
	var amb := _ambiente("abisso")
	var xf: Array[Transform3D] = []
	for lato: float in [-1.0, 1.0]:
		var s := float(amb[0]) + 1.5
		while s < float(amb[1]):
			if not sala._lato(s, lato)["crollo"] and not sala._lato(s - 0.2, lato)["crollo"] and not sala._lato(s + 0.2, lato)["crollo"]:
				var p := sala.punto(s)
				var r := sala.destra(s)
				var c := sala._al(p, r, Vector2(lato * (sala.canale + 0.12), sala.piano + 0.004))
				xf.append(Transform3D(Basis(), c))
			s += LUCINE_OGNI
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.05
	cm.height = 0.012
	cm.radial_segments = 16
	cm.rings = 1
	cm.material = _mat("lucina", Color(0.5, 0.85, 1.0), 0.3, 0.0, Color(0.35, 0.8, 1.0), 4.0)
	mm.mesh = cm
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "lucine_banchine"
	mmi.multimesh = mm
	mmi.set_meta(&"trasformazioni", xf)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# --- l'approdo ---------------------------------------------------------------------------------------------------

func _approdo() -> void:
	var nodo := _nodo("Approdo")
	for b in BITTE:
		_bitta(nodo, float(b[0]), float(b[1]))
	for c in CARTELLI:
		_cartello(nodo, float(c[0]), float(c[1]))
	_fanale(nodo, FANALI_S, -1.0, Color(1.0, 0.12, 0.08), "fanale_rosso")
	_fanale(nodo, FANALI_S, 1.0, Color(0.15, 1.0, 0.3), "fanale_verde")
	_salvagente(nodo)
	_vetrina_vuota(nodo)


## Una bitta d'ottone scuro sul bordo della banchina: base, collo e testa a fungo, alta 28 cm.
func _bitta(nodo: Node3D, s: float, lato: float) -> void:
	var p := sala.punto(s)
	var r := sala.destra(s)
	var c := sala._al(p, r, Vector2(lato * (sala.canale + 0.3), sala.piano))
	var n := Node3D.new()
	n.name = "bitta_%d" % int(s)
	nodo.add_child(n)
	n.position = c
	var m := _mat("ghisa", Color(0.12, 0.12, 0.13), 0.55, 0.6)
	for q in [[0.15, 0.17, 0.05, 0.025], [0.08, 0.09, 0.2, 0.15], [0.13, 0.11, 0.05, 0.255]]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = q[0]
		cm.bottom_radius = q[1]
		cm.height = q[2]
		cm.radial_segments = 20
		mi.mesh = cm
		mi.material_override = m
		mi.position.y = q[3]
		n.add_child(mi)
	var corpo := StaticBody3D.new()
	corpo.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.15
	cy.height = 0.28
	cs.shape = cy
	cs.position.y = 0.14
	corpo.add_child(cs)
	n.add_child(corpo)


## Un cartello quadrato a disegni a bandiera sul muro sopra i 2 m: la staffa dal muro e la lastra girata verso chi
## arriva, col portello e la freccia avanti.
func _cartello(nodo: Node3D, s: float, lato: float) -> void:
	var y := sala.piano + 2.55
	var w = _muro(s, lato, y)
	if w == null:
		return
	var punto_muro: Vector3 = w[0]
	var nrm: Vector3 = w[1]
	var d := sala.direzione(s)
	var n := Node3D.new()
	n.name = "cartello_portello_%d" % int(s)
	nodo.add_child(n)
	var mz := _mat("zincato", Color(0.55, 0.56, 0.55), 0.5, 0.8)
	# la staffa: la piastra a muro e il braccio
	var piastra := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.12, 0.62, 0.01)
	piastra.mesh = pb
	piastra.material_override = mz
	n.add_child(piastra)
	piastra.transform = Transform3D(Basis.looking_at(-nrm, Vector3.UP), punto_muro + nrm * 0.006)
	var braccio := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.03, 0.03, 0.62)
	braccio.mesh = bb
	braccio.material_override = mz
	n.add_child(braccio)
	braccio.transform = Transform3D(Basis.looking_at(-nrm, Vector3.UP), punto_muro + nrm * (0.008 + 0.31) + Vector3.UP * 0.29)
	# la lastra appesa sotto il braccio, perpendicolare al muro: la faccia col disegno guarda chi arriva (-d)
	var lastra := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.5, 0.5, 0.015)
	lastra.mesh = lb
	lastra.material_override = mz
	n.add_child(lastra)
	var centro := punto_muro + nrm * 0.33 + Vector3.DOWN * 0.0
	var base_l := Basis.looking_at(d, Vector3.UP)          # -z verso d: il davanti (+z) guarda chi arriva
	lastra.transform = Transform3D(base_l, centro)
	var faccia := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.48, 0.48)
	faccia.mesh = q
	var mf := StandardMaterial3D.new()
	mf.albedo_texture = load(DIR + "cartello_portello.jpg")
	mf.roughness = 0.6
	faccia.material_override = mf
	n.add_child(faccia)
	faccia.transform = Transform3D(base_l, centro - d * 0.0085)
	# i due ganci fra il braccio e la lastra
	for k: float in [-0.18, 0.18]:
		var g := MeshInstance3D.new()
		var gc := CylinderMesh.new()
		gc.top_radius = 0.006
		gc.bottom_radius = 0.006
		gc.height = 0.04
		g.mesh = gc
		g.material_override = mz
		n.add_child(g)
		g.position = punto_muro + nrm * (0.33 + k) + Vector3.UP * 0.26


## Un fanale d'approdo sul muro (il vetro colorato acceso e una luce debole), a 3,2 m.
func _fanale(nodo: Node3D, s: float, lato: float, colore: Color, nome: String) -> void:
	var w = _muro(s, lato, sala.piano + 3.2)
	if w == null:
		return
	var pm: Vector3 = w[0]
	var nrm: Vector3 = w[1]
	var n := Node3D.new()
	n.name = nome
	nodo.add_child(n)
	n.transform = Transform3D(Basis.looking_at(-nrm, Vector3.UP), pm)
	var ottone := sala._mat_ottone()
	var base := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.24, 0.34, 0.03)
	base.mesh = bb
	base.material_override = ottone
	base.position = Vector3(0, 0, 0.016)
	n.add_child(base)
	var vetro := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.075
	cm.bottom_radius = 0.075
	cm.height = 0.18
	vetro.mesh = cm
	vetro.material_override = _mat("fanale_" + nome, colore, 0.2, 0.0, colore, 3.0)
	vetro.position = Vector3(0, 0, 0.031 + 0.075)
	n.add_child(vetro)
	for y: float in [-0.1, 0.1]:
		var anello := MeshInstance3D.new()
		var ca := CylinderMesh.new()
		ca.top_radius = 0.085
		ca.bottom_radius = 0.085
		ca.height = 0.02
		anello.mesh = ca
		anello.material_override = ottone
		anello.position = Vector3(0, y, 0.031 + 0.075)
		n.add_child(anello)
	var o := OmniLight3D.new()
	o.light_color = colore
	o.light_energy = 1.2
	o.omni_range = 5.0
	o.shadow_enabled = false
	o.position = Vector3(0, 0, 0.35)
	n.add_child(o)


## Il salvagente fosforescente al muro destro, col suo palo di legno, sopra i 2 m: si trova anche al buio.
func _salvagente(nodo: Node3D) -> void:
	var w = _muro(SALVAGENTE_S, 1.0, sala.piano + 2.75)
	if w == null:
		return
	var n := _modello(nodo, "salvagente", Vector3.ZERO, Vector3.ZERO, 1.0)
	n.name = "salvagente_fosforescente"
	_a_muro(n, w[0], w[1], sala.piano + 2.03)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var base := m.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			var mt := base.duplicate() as StandardMaterial3D
			mt.emission_enabled = true
			mt.emission = Color(1.0, 0.75, 0.45)
			mt.emission_texture = base.albedo_texture
			mt.emission_energy_multiplier = 0.7
			m.set_surface_override_material(i, mt)


## Dove stava la vetrina del diorama: le due staffe vuote sotto (sopra i 2 m) con i tiranti al muro e il segno più
## chiaro sul mosaico, dove la vetrina l'ha tenuto pulito.
func _vetrina_vuota(nodo: Node3D) -> void:
	var lato := -1.0
	var n := Node3D.new()
	n.name = "vetrina_vuota"
	nodo.add_child(n)
	var mf := sala._mat_ferro()
	for ds: float in [-VETRINA_LARGA * 0.5 + 0.2, VETRINA_LARGA * 0.5 - 0.2]:
		var s := VETRINA_S + ds
		var w = _muro(s, lato, sala.piano + VETRINA_BASSO)
		if w == null:
			continue
		var pm: Vector3 = w[0]
		var nrm: Vector3 = w[1]
		var bs := Basis.looking_at(-nrm, Vector3.UP)
		# la piastra a muro, il braccio orizzontale (la vetrina ci poggiava) e il tirante su al muro
		var piastra := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.1, 0.14, 0.01)
		piastra.mesh = pb
		piastra.material_override = mf
		n.add_child(piastra)
		piastra.transform = Transform3D(bs, pm + nrm * 0.006 + Vector3.UP * 0.05)
		var braccio := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.05, 0.04, VETRINA_FONDA)
		braccio.mesh = bb
		braccio.material_override = mf
		n.add_child(braccio)
		braccio.transform = Transform3D(bs, pm + nrm * (0.008 + VETRINA_FONDA * 0.5) + Vector3.UP * 0.05)
		var w2 = _muro(s, lato, sala.piano + VETRINA_BASSO + 0.9)
		if w2 != null:
			var alto: Vector3 = w2[0]
			var capo := pm + nrm * (0.008 + VETRINA_FONDA - 0.06) + Vector3.UP * 0.07
			sala._palo(n, capo, alto + nrm * 0.009, 0.012, mf)
			n.get_child(n.get_child_count() - 1).name = "tirante_vetrina"
			var p2 := MeshInstance3D.new()
			var pb2 := BoxMesh.new()
			pb2.size = Vector3(0.08, 0.1, 0.01)
			p2.mesh = pb2
			p2.material_override = mf
			n.add_child(p2)
			p2.transform = Transform3D(bs, alto + nrm * 0.006)
	# il segno: un decal più chiaro sul mosaico dove stava il fondo della vetrina
	var wc = _muro(VETRINA_S, lato, sala.piano + VETRINA_BASSO + VETRINA_ALTA * 0.5)
	if wc != null:
		var dc := Decal.new()
		dc.name = "segno_vetrina"
		dc.size = Vector3(VETRINA_LARGA, 0.2, VETRINA_ALTA)
		dc.texture_albedo = _texture_segno()
		dc.modulate = Color(0.75, 0.9, 1.0, 0.28)
		dc.upper_fade = 0.0
		dc.lower_fade = 0.0
		n.add_child(dc)
		var nrm: Vector3 = wc[1]
		# il decal proietta lungo il suo -y: verso il muro
		var x := Vector3.UP.cross(nrm).normalized()
		dc.transform = Transform3D(Basis(x, nrm, x.cross(nrm).normalized()), (wc[0] as Vector3) + nrm * 0.05)


var _segno: ImageTexture


func _texture_segno() -> ImageTexture:
	if _segno == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var bx := minf(minf(x, 63 - x), minf(y, 63 - y)) / 6.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf(bx, 0.0, 1.0)))
		_segno = ImageTexture.create_from_image(img)
	return _segno


# --- aiuti -------------------------------------------------------------------------------------------------------

func _nodo(nome: String) -> Node3D:
	var n := Node3D.new()
	n.name = nome
	add_child(n)
	return n


## [da s, a s] dell'ambiente [param nome].
func _ambiente(nome: String) -> Array:
	var amb: Array = sala.dati["ambienti"]
	var da := 0.0
	for a in amb:
		if a["nome"] == nome:
			return [da, float(a["fino_a"])]
		da = float(a["fino_a"])
	return [0.0, 0.0]


## Un modello del fiume (come [method SalaSottomarino._modello], ma con le coordinate della sala).
func _modello(nodo: Node3D, nome: String, pos: Vector3, verso: Vector3, scala: float) -> Node3D:
	var n := (load(DIR_FIUME + nome + ".glb") as PackedScene).instantiate() as Node3D
	nodo.add_child(n)
	var b := Basis.looking_at(verso, Vector3.UP) if verso.length_squared() > 0.0 else Basis()
	n.transform = Transform3D(b.scaled(Vector3.ONE * scala), pos)
	return n


## Mette il modello [param n] col dorso (il suo -z... il lato più vicino al muro) a filo del muro in [param pm] di
## normale [param nrm], col bordo basso alla quota [param basso].
func _a_muro(n: Node3D, pm: Vector3, nrm: Vector3, basso: float) -> void:
	# il modello guarda fuori dal muro (+z verso la normale)
	n.transform = Transform3D(Basis.looking_at(-nrm, Vector3.UP) * Basis.from_scale(n.transform.basis.get_scale()), pm)
	var tri := _triangoli(n)
	var dietro := INF
	var sotto := INF
	for v in tri:
		dietro = minf(dietro, (v - pm).dot(nrm))
		sotto = minf(sotto, v.y)
	n.position += nrm * (-dietro - 0.002) + Vector3.UP * (basso - sotto)


## Il punto del muro dal lato [param lato] a [param s] alla quota [param y] e la sua normale (verso il tunnel), dai
## triangoli veri; null se non c'è.
func _muro(s: float, lato: float, y: float):
	var p := sala.punto(s)
	var r := sala.destra(s)
	var da := sala._al(p, r, Vector2(lato * (sala.muro - 1.0), y))
	var a := sala._al(p, r, Vector2(lato * (sala.muro + 0.3), y))
	var tri := _tri_tunnel(s)
	var h = _raggio(tri, da, a, true)
	if h == null:
		return null
	return h


func _sala_ha_lampada_vicina(s: float, lato: float) -> bool:
	for o in sala.ostacoli:
		var sm := float(o["s"]) + float(o["lungo"]) * 0.5
		if absf(sm - s) < 2.5 and float(o["lato"]) == lato:
			return true
	return false


## I triangoli dei pezzi di tunnel intorno a [param s] (coordinate della sala).
func _tri_tunnel(s: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k: int in [-1, 0, 1]:
		var i := int(floor((s + SalaSottomarino.TESTA) / SalaSottomarino.PEZZO)) + k
		if i < 0:
			continue
		if not _tri_pezzi.has(i):
			var n := sala.get_node_or_null("Tunnel_%03d" % int(i * SalaSottomarino.PEZZO)) as Node3D
			_tri_pezzi[i] = PackedVector3Array() if n == null else _triangoli(n)
		out.append_array(_tri_pezzi[i])
	return out


## I triangoli delle mesh sotto [param n], nelle coordinate della sala.
func _triangoli(n: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mis: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		mis.append(n)
	for x in mis:
		var mi := x as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := _xf(mi)
		for v in mi.mesh.get_faces():
			out.append(xf * v)
	return out


## La trasformazione di [param n] rispetto alla sala (anche fuori dall'albero).
func _xf(n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != sala:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Il primo punto dei triangoli [param tri] sul segmento da [param da] ad [param a] (null se non c'è); con
## [param normale] anche la normale verso [param da].
func _raggio(tri: PackedVector3Array, da: Vector3, a: Vector3, normale := false):
	var best := INF
	var hit = null
	var nb := Vector3.ZERO
	var lo := da.min(a) - Vector3.ONE * 0.01
	var hi := da.max(a) + Vector3.ONE * 0.01
	for i in range(0, tri.size(), 3):
		var t0 := tri[i]
		var t1 := tri[i + 1]
		var t2 := tri[i + 2]
		if maxf(t0.x, maxf(t1.x, t2.x)) < lo.x or minf(t0.x, minf(t1.x, t2.x)) > hi.x:
			continue
		if maxf(t0.z, maxf(t1.z, t2.z)) < lo.z or minf(t0.z, minf(t1.z, t2.z)) > hi.z:
			continue
		if maxf(t0.y, maxf(t1.y, t2.y)) < lo.y or minf(t0.y, minf(t1.y, t2.y)) > hi.y:
			continue
		var h = Geometry3D.segment_intersects_triangle(da, a, t0, t1, t2)
		if h != null:
			var dd := da.distance_to(h)
			if dd < best:
				best = dd
				hit = h
				nb = (t1 - t0).cross(t2 - t0).normalized()
	if hit == null:
		return null
	if not normale:
		return hit
	if nb.dot(da - a) < 0.0:
		nb = -nb
	return [hit, nb]


## Una piastra tonda d'ottone con l'occhiello, a filo della volta in [param p].
func _piastra(nodo: Node3D, p: Vector3, nome: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = 0.02
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = sala._mat_ottone()
	nodo.add_child(mi)
	mi.position = p + Vector3.DOWN * 0.008


## Una catena dritta da [param a] a [param b]: maglie ovali alternate, in una mesh sola.
func _catena(nodo: Node3D, a: Vector3, b: Vector3, nome: String) -> void:
	var asse := b - a
	var lung := asse.length()
	var passo := 0.05
	var nm := maxi(int(round(lung / passo)), 1)
	passo = lung / nm
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var su := asse.normalized()
	var x0 := su.cross(Vector3.FORWARD if absf(su.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z0 := su.cross(x0)
	var rf := 0.006
	var rx := 0.016
	var ry := passo * 0.5 + rf
	for k in nm:
		var c := a + su * (passo * (k + 0.5))
		var lx := x0 if k % 2 == 0 else z0
		var lz := z0 if k % 2 == 0 else -x0
		var seg := 12
		var lati := 6
		for i in seg:
			for j in lati:
				var pts := []
				for di in [0, 1]:
					for dj in [0, 1]:
						var u := TAU * float(i + di) / seg
						var v := TAU * float(j + dj) / lati
						var centro := c + lx * cos(u) * rx + su * sin(u) * minf(ry, passo * 0.5 + rf)
						var rad := (lx * cos(u) * rx + su * sin(u) * ry).normalized()
						pts.append(centro + (rad * cos(v) + lz * sin(v)) * rf)
				var nrm: Vector3 = ((pts[0] + pts[1] + pts[2] + pts[3]) * 0.25 - c).normalized()
				sala._quad(st, [pts[0], pts[2], pts[3], pts[1]], nrm)
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = st.commit()
	mi.material_override = sala._mat_ferro()
	nodo.add_child(mi)


## Un faretto a muro (lato, quota) puntato su [param verso_p]: la staffa, il barattolo e la luce.
func _faretto(nodo: Node3D, s: float, lato: float, y: float, verso_p: Vector3, colore: Color, energia: float) -> void:
	var w = _muro(s, lato, sala.piano + y)
	if w == null:
		return
	var pm: Vector3 = w[0]
	var nrm: Vector3 = w[1]
	var n := Node3D.new()
	n.name = "faretto_%d" % int(s)
	nodo.add_child(n)
	var mf := sala._mat_ferro()
	var piastra := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.12, 0.12, 0.012)
	piastra.mesh = pb
	piastra.material_override = mf
	n.add_child(piastra)
	piastra.transform = Transform3D(Basis.looking_at(-nrm, Vector3.UP), pm + nrm * 0.007)
	var testa := pm + nrm * 0.2
	sala._palo(n, pm + nrm * 0.01, testa, 0.015, mf)
	n.get_child(n.get_child_count() - 1).name = "braccio_faretto"
	var dir := (verso_p - testa).normalized()
	var can := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.075
	cm.height = 0.18
	can.mesh = cm
	can.material_override = mf
	n.add_child(can)
	# il barattolo col fondo sulla testa del braccio, aperto verso la tartaruga
	var bs := Basis.looking_at(dir, nrm if absf(dir.dot(nrm)) < 0.95 else Vector3.UP)
	var b_can := Basis(bs.x, -bs.z, bs.y)
	can.transform = Transform3D(b_can, testa + dir * 0.08)
	var vetro := MeshInstance3D.new()
	var vc := CylinderMesh.new()
	vc.top_radius = 0.058
	vc.bottom_radius = 0.058
	vc.height = 0.006
	vetro.mesh = vc
	vetro.material_override = _mat("vetro_faretto", Color(0.9, 0.97, 1.0), 0.2, 0.0, colore, 2.5)
	n.add_child(vetro)
	vetro.transform = Transform3D(b_can, testa + dir * 0.168)
	var sp := SpotLight3D.new()
	sp.light_color = colore
	sp.light_energy = energia
	sp.spot_range = 9.0
	sp.spot_angle = 24.0
	sp.shadow_enabled = false
	n.add_child(sp)
	sp.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), testa + dir * 0.2)


var _materiali := {}


func _mat(nome: String, colore: Color, ruvido := 0.7, metallo := 0.0, emissione := Color.BLACK, forza := 0.0) -> StandardMaterial3D:
	if not _materiali.has(nome):
		var m := StandardMaterial3D.new()
		m.albedo_color = colore
		m.roughness = ruvido
		m.metallic = metallo
		if forza > 0.0:
			m.emission_enabled = true
			m.emission = emissione
			m.emission_energy_multiplier = forza
		_materiali[nome] = m
	return _materiali[nome]
