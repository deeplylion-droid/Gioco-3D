extends Node3D
## Il fiume lento nel gioco (aspetto A, "giungla finta", scelta dell'utente del 19 ottobre), lungo la
## strada di risalita della tappa 7 (GDD, "Allungare il capitolo"; logica approvata il 18 ottobre in
## docs/proposte/fiume_infermeria/nota_logica.md). Costruisce da solo, all'avvio, il capannone con il
## canale, le banchine, la giungla finta, le luci e la logica di enigma-logica (FiumeLento, TrattoFiume,
## ParatiaFiume, CartelloUscita).
##
## La pianta (coordinate locali, banchine a quota 0, la corrente gira in senso orario visto da sopra):
## - al centro la vasca dell'imbarco, con la ciambella ormeggiata nell'angolo nord-ovest;
## - dall'imbarco il canale va a nord e diventa un anello di raggio [constant R] che gira per tre quarti:
##   bivio 1 a est, bivio 2 a sud, bivio 3 a ovest;
## - a ogni bivio il ramo sbagliato è un raggio che torna dritto alla vasca dell'imbarco (corto e più
##   veloce, finisce con uno scivolo); il ramo giusto continua sull'anello;
## - dopo il bivio 3 il ramo giusto esce a ovest fino all'approdo, con la scaletta e la porta di servizio
##   verso la zona del personale;
## - si entra dalla porta nel muro nord, nel quarto nord-ovest dove non passa il canale, e si arriva a
##   piedi alla vasca dell'imbarco.
## I tre bivi seguono la nota: al 1 la paratia manda nel ramo sbagliato (il disco a strisce si vede
## dritto davanti), al 2 è già giusta, al 3 il disco è dietro una colonna e si vede solo dopo esserci
## passati. I cartelli verdi d'uscita sono accesi solo sopra i rami giusti.
## I nomi dei nodi che usano i test e il livello: FiumeLento (con i tratti Imbarco, Giusto1, Giusto2,
## Uscita, Sbagliato1..3 e le paratie Paratia1..3), Marker/Ingresso, Marker/Imbarco, Marker/Approdo,
## Marker/PortaPersonale.

const DIR := "res://assets/fiume_lento/"
## Raggio dell'anello (asse del canale), larghezza dell'acqua, fondo e pelo.
const R := 24.0
const W := 3.2
const FONDO := -0.9
const ACQUA := -0.22
## La ciambella galleggia poco sotto il pelo.
const GALLA := ACQUA - 0.12
## Banchine lungo l'anello (dal bordo dell'acqua), la vasca dell'imbarco (mezzo lato), le conche dei bivi
## (mezzo lato).
const BANCA := 1.4
const VASCA := 3.6
const CONCA := 3.0
## Il capannone: da X0 a X1, da Z0 a Z1, alto TETTO.
const X0 := -41.0
const X1 := 28.6
const Z0 := -28.6
const Z1 := 28.6
const TETTO := 7.6
## L'approdo in fondo al ramo d'uscita (centro della conca) e la porta di servizio nel muro ovest.
const APPRODO := Vector2(-34.0, 0.0)
## La porta d'ingresso nel muro nord (x).
const INGRESSO_X := -26.0
## Dove è ormeggiata la ciambella, nell'angolo nord-ovest della vasca: ci arrivano anche i rami sbagliati.
const ORMEGGIO := Vector3(-2.9, 0, -2.9)
## I muri che chiudono la parte dove si cammina: a ovest l'approdo, a est la fascia lungo il muro nord
## (oltre il raggio d'imbarco); Z_PIAZZA_NORD è il bordo nord del canale dove passa quel muro.
const MURO_APPRODO := -30.5
const MURO_PIAZZA := 3.6
const Z_PIAZZA_NORD := -22.2
## Dove finisce la fila delle transenne, davanti alla cabina dell'imbarco.
const FINE_FILA := Vector3(-VASCA - 3.2, 0, -VASCA - 3.4)
## Velocità dei rami sbagliati (m/s).
const VELOCITA_RITORNO := 3.0
## Lo scivolo in fondo ai rami sbagliati (scelta B dell'utente, 22 ottobre): negli ultimi SCIVOLO_L metri
## prima della vasca dell'imbarco un canale stretto (largo 2 x SCIVOLO_A) di vetroresina colorata, con
## l'acqua veloce che scende di SCIVOLO_DISCESA e sbocca nella vasca. Il fiume resta alla stessa altezza:
## lungo il raggio, prima dello scivolo, il pelo sale piano (1,4%, non si nota) di quanto poi scende.
const SCIVOLO_L := 4.0
const SCIVOLO_A := 0.7
const SCIVOLO_DISCESA := 0.2

var mat_vasca: Material
var mat_banca: Material
var mat_acqua: Material
var mat_roccia: Material

## L'order del checkpoint dell'ingresso; quello dell'approdo è il successivo (prima dell'infermeria, 12).
@export var ordine_checkpoint := 10

var fiume: FiumeLento
var tratti := {}
## L'acqua: le strisce dei canali ([punti 2D, larghezza]) e le conche (poligoni 2D).
var _strisce: Array = []
var _conche: Array = []
var _collisioni: StaticBody3D
var _barriere: StaticBody3D
var _poligoni_acqua_cache: Array = []
var _mat_globo: StandardMaterial3D
var _mat_faro: StandardMaterial3D
## Vero: _ready non costruisce niente, lo fa [method costruisci_a_pezzi] un po' per fotogramma.
var costruzione_a_pezzi := false
var costruita := false
## Quanto lavora al massimo un pezzo della costruzione (microsecondi); con [method accelera] i pezzi più grandi.
const PEZZO_US := 12000
const PEZZO_SVELTO_US := 25000
## Le estrazioni dal generatore comune fatte finora (vero: randf_range, falso: randf), per rimetterlo com'era a
## ogni ripresa ([method _pausa]).
var _tiri: Array[bool] = []
var _t_pezzo := 0
var _pezzo_us := PEZZO_US


func _ready() -> void:
	if not costruzione_a_pezzi:
		_costruisci()


## Costruisce il capannone a pezzi, qualche millisecondo per fotogramma (la Risalita caricata a gioco avviato):
## il nodo va messo nella scena con [member costruzione_a_pezzi] vero, poi si aspetta questa.
func costruisci_a_pezzi() -> void:
	if not costruita:
		await _costruisci()


## I pezzi rimasti più grandi (il giocatore è arrivato prima che finisse): sempre a pezzi, mai tutto in un fotogramma
## (collaudo del 23 ottobre: 503 ms di fermo nella sala pompe).
func accelera() -> void:
	_pezzo_us = PEZZO_SVELTO_US


func _costruisci() -> void:
	_t_pezzo = Time.get_ticks_usec()
	seed(1021)
	_tiri.clear()
	mat_vasca = load(DIR + "mat_mosaico_blu.tres")
	mat_banca = load(DIR + "mat_cemento.tres")
	mat_acqua = load(DIR + "acqua_fiume.tres")
	mat_roccia = load(DIR + "mat_roccia_ocra.tres")
	_mat_globo = StandardMaterial3D.new()
	_mat_globo.albedo_color = Color(1.0, 0.85, 0.55)
	_mat_globo.emission_enabled = true
	_mat_globo.emission = Color(1.0, 0.7, 0.35)
	_mat_globo.emission_energy_multiplier = 3.0
	_mat_faro = StandardMaterial3D.new()
	_mat_faro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_faro.albedo_color = Color(0.75, 0.95, 1.0) * 0.45
	_collisioni = StaticBody3D.new()
	_collisioni.name = "Collisioni"
	add_child(_collisioni)
	_barriere = StaticBody3D.new()
	_barriere.name = "Barriere"
	_barriere.collision_layer = Layers.BARRIERS
	_barriere.collision_mask = 0
	add_child(_barriere)
	_tracciato()
	await _pausa()
	await _acqua_e_banchine()
	await _pausa()
	await _capannone()
	await _pausa()
	await _logica()
	await _pausa()
	_bivi()
	await _pausa()
	await _giungla()
	await _pausa()
	await _imbarco()
	await _pausa()
	_approdo()
	_marker()
	_checkpoint()
	costruita = true


## Nella costruzione a pezzi, passato il tempo di un pezzo, il resto al fotogramma dopo. Altrimenti niente (e la
## costruzione resta tutta nello stesso fotogramma, come prima).
func _pausa() -> void:
	if costruzione_a_pezzi and Time.get_ticks_usec() - _t_pezzo > _pezzo_us:
		await get_tree().process_frame
		_t_pezzo = Time.get_ticks_usec()
		# fra un fotogramma e l'altro il generatore comune l'hanno usato altri (luci che sfarfallano, suoni): lo si
		# rimette dov'era, così rocce, palme e transenne vengono come costruite tutte insieme
		seed(1021)
		for r in _tiri:
			if r:
				randf_range(0.0, 1.0)
			else:
				randf()


func _randf() -> float:
	_tiri.append(false)
	return randf()


func _randf_range(da: float, a: float) -> float:
	_tiri.append(true)
	return randf_range(da, a)


# --- il tracciato -----------------------------------------------------------------------------------

## Un punto dell'anello all'angolo [param gradi] (da nord, in senso orario visto da sopra).
static func anello(gradi: float, raggio := R) -> Vector3:
	var a := deg_to_rad(gradi)
	return Vector3(raggio * sin(a), 0.0, -raggio * cos(a))


static func _arco(da: float, a: float, passo := 7.5) -> Array:
	var out := []
	var n := maxi(int(ceil(absf(a - da) / passo)), 1)
	for i in n + 1:
		out.append(anello(lerpf(da, a, float(i) / n)))
	return out


## Le curve dei tratti (a quota 0: la ciambella è più giù di GALLA).
func percorsi() -> Dictionary:
	var imb := [ORMEGGIO, Vector3(-0.9, 0, -3.8), Vector3(0, 0, -6.5), Vector3(0, 0, -14.0), Vector3(2.8, 0, -20.6)]
	imb.append_array(_arco(25.0, 90.0))
	return {
		"Imbarco": imb,
		"Giusto1": _arco(90.0, 180.0),
		"Giusto2": _arco(180.0, 270.0),
		"Uscita": [anello(270.0), Vector3(-29.0, 0, 0.0), Vector3(APPRODO.x + 0.6, 0, APPRODO.y)],
		"Sbagliato1": [anello(90.0), Vector3(12.0, 0, 0), Vector3(VASCA + 0.2, 0, 0), Vector3(0.6, 0, -1.2), ORMEGGIO],
		"Sbagliato2": [anello(180.0), Vector3(0, 0, 12.0), Vector3(0, 0, VASCA + 0.2), Vector3(-1.4, 0, 0.2), ORMEGGIO],
		"Sbagliato3": [anello(270.0), Vector3(-12.0, 0, 0), Vector3(-VASCA - 0.2, 0, 0), Vector3(-3.0, 0, -1.2), ORMEGGIO],
	}


func _tracciato() -> void:
	# l'acqua: i canali tra una conca e l'altra (l'anello si interrompe nelle conche dei bivi)
	var bivi := [90.0, 180.0, 270.0]
	_striscia(_punti2([Vector3(0, 0, -VASCA + 0.2), Vector3(0, 0, -14.0), Vector3(2.8, 0, -20.6)] + _arco(25.0, 90.0 - 7.0)))
	_striscia(_punti2(_arco(90.0 + 7.0, 180.0 - 7.0)))
	_striscia(_punti2(_arco(180.0 + 7.0, 270.0 - 7.0)))
	_striscia(_punti2([anello(270.0) + Vector3(-CONCA + 0.2, 0, 0), Vector3(APPRODO.x + 2.0, 0, APPRODO.y)]))
	for g in bivi:
		var c := anello(g)
		var verso := -Vector2(c.x, c.z).normalized()
		var dentro := Vector2(c.x, c.z) + verso * (CONCA - 0.2)
		var fine := verso * (VASCA - 0.2) * -1.0
		_striscia(_punti2([Vector3(dentro.x, 0, dentro.y), Vector3(fine.x, 0, fine.y)]))
		# la conca del bivio: un quadrato allineato al raggio
		_conche.append(_quadrato(Vector2(c.x, c.z), CONCA, atan2(verso.y, verso.x)))
	_conche.append(_quadrato(Vector2.ZERO, VASCA, 0.0))
	# l'approdo
	_conche.append(PackedVector2Array([APPRODO + Vector2(-2.2, -2.4), APPRODO + Vector2(2.2, -2.4), APPRODO + Vector2(2.2, 2.4), APPRODO + Vector2(-2.2, 2.4)]))


func _punti2(punti: Array) -> PackedVector2Array:
	var pts := _campiona(punti)
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x, p.z))
	return out


func _striscia(pts2: PackedVector2Array) -> void:
	_strisce.append(pts2)


static func _quadrato(c: Vector2, mezzo: float, ang: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 4:
		var a := ang + PI * 0.25 + PI * 0.5 * k
		out.append(c + Vector2(cos(a), sin(a)) * mezzo * sqrt(2.0))
	return out


## Curva liscia per i punti (maniglie di Catmull-Rom), campionata ogni 0,5 m.
static func _campiona(punti: Array) -> PackedVector3Array:
	var c := Curve3D.new()
	c.up_vector_enabled = false
	for i in punti.size():
		var p: Vector3 = punti[i]
		var a: Vector3 = punti[maxi(i - 1, 0)]
		var b: Vector3 = punti[mini(i + 1, punti.size() - 1)]
		var t := (b - a) * 0.22
		c.add_point(p, -t, t)
	c.bake_interval = 0.5
	return c.get_baked_points()


# --- acqua, canali e banchine -------------------------------------------------------------------------

## Il poligono di una striscia: la polilinea allargata di W/2 (a punte quadre).
func _poligoni_acqua() -> Array:
	var polys: Array = []
	for s in _strisce:
		for p in Geometry2D.offset_polyline(s, W * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_BUTT):
			polys.append(p)
	polys.append_array(_conche)
	return polys


func _acqua_e_banchine() -> void:
	var polys := _poligoni_acqua()
	_poligoni_acqua_cache = polys
	# Il pavimento del capannone a quadrotti da 2 m meno l'acqua: un quadrotto non può contenere tutto
	# un canale largo 3,2 m o una conca, quindi niente buchi da triangolare. I lati dei pezzi che non
	# stanno sulla griglia dei quadrotti sono il bordo dell'acqua: lì scendono le pareti del canale.
	var pav := SurfaceTool.new()
	pav.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pareti := SurfaceTool.new()
	pareti.begin(Mesh.PRIMITIVE_TRIANGLES)
	var barriere := PackedVector3Array()
	var x := X0
	while x < X1 - 0.001:
		await _pausa()
		var z := Z0
		while z < Z1 - 0.001:
			var xa := minf(x + 2.0, X1)
			var za := minf(z + 2.0, Z1)
			var pezzi: Array = [PackedVector2Array([Vector2(x, z), Vector2(xa, z), Vector2(xa, za), Vector2(x, za)])]
			for w in polys:
				var dopo: Array = []
				for pz in pezzi:
					dopo.append_array(Geometry2D.clip_polygons(pz, w))
				pezzi = dopo
			for pz in pezzi:
				var tri := Geometry2D.triangulate_polygon(pz)
				for k in range(0, tri.size(), 3):
					var t := [pz[tri[k]], pz[tri[k + 1]], pz[tri[k + 2]]]
					# il triangolo con la faccia in su (in Godot la faccia davanti gira in senso orario)
					if (t[1] - t[0]).cross(t[2] - t[0]) < 0.0:
						t = [t[0], t[2], t[1]]
					for v in t:
						pav.set_normal(Vector3.UP)
						pav.set_uv(v * 0.5)
						pav.add_vertex(Vector3(v.x, 0, v.y))
				for i in pz.size():
					var a: Vector2 = pz[i]
					var b: Vector2 = pz[(i + 1) % pz.size()]
					if _sulla_griglia(a, b, x, xa, z, za) or a.distance_to(b) < 0.001:
						continue
					# la normale verso l'acqua (fuori dal pezzo di pavimento)
					var m := (a + b) * 0.5
					var n := (b - a).orthogonal().normalized()
					if Geometry2D.is_point_in_polygon(m + n * 0.01, pz):
						n = -n
					_parete(pareti, a, b, Vector3(n.x, 0, n.y))
					for q in [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x, 2.0, b.y),
							Vector3(a.x, 0, a.y), Vector3(b.x, 2.0, b.y), Vector3(a.x, 2.0, a.y)]:
						barriere.append(q)
			z += 2.0
		x += 2.0
	_mesh(pav, mat_banca, true, true)
	_mesh(pareti, mat_vasca, true, true)
	# Muro invisibile lungo il bordo dell'acqua (livello "barriere": ferma il giocatore, non il getto né
	# il raggio del tasto E): nel canale non si cade, e sulla ciambella si sale dalla banchina.
	var fb := CollisionShape3D.new()
	var cs := ConcavePolygonShape3D.new()
	cs.set_faces(barriere)
	cs.backface_collision = true
	fb.shape = cs
	_barriere.add_child(fb)
	# il fondo: un piano sotto tutto il capannone
	var fondo := SurfaceTool.new()
	fondo.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(fondo, [Vector3(X0, FONDO, Z1), Vector3(X1, FONDO, Z1), Vector3(X1, FONDO, Z0), Vector3(X0, FONDO, Z0)])
	_mesh(fondo, mat_vasca, false, true, false)
	# il pelo dell'acqua: nastri lungo le strisce (scorrono), lastre ferme nelle conche
	for i in _strisce.size():
		_nastro(_strisce[i], i >= _strisce.size() - 3)   # le ultime tre sono i raggi dei rami sbagliati
	for c in _conche:
		_lastra(c)
	_scivoli()


## Gli scivoli dei rami sbagliati: in ogni raggio, dall'inizio dello scivolo al bordo della vasca, la vasca
## a U di vetroresina (blu dentro, con l'acqua che scende), il bordo e due falde gialle che la raccordano alle
## banchine, chiuse in testa e in fondo.
func _scivoli() -> void:
	var giallo := _vetroresina(Color(0.89, 0.66, 0.06))
	var blu := _vetroresina(Color(0.12, 0.31, 0.63))
	var st_g := SurfaceTool.new()
	st_g.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_b := SurfaceTool.new()
	st_b.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_a := SurfaceTool.new()
	st_a.begin(Mesh.PRIMITIVE_TRIANGLES)
	const T := 0.06          # spessore del bordo
	const SOPRA := 0.3       # il bordo sopra il pelo
	const SOTTO := 0.14      # il fondo sotto il pelo
	var a := SCIVOLO_A
	var b := W * 0.5
	var d0 := VASCA
	var d1 := VASCA + SCIVOLO_L
	for g in [90.0, 180.0, 270.0]:
		var u := anello(g).normalized()
		var r := u.cross(Vector3.UP).normalized()
		var pt := func(d: float, s: float, y: float) -> Vector3: return u * d + r * s + Vector3.UP * y
		var n := 16
		for i in n:
			var da := lerpf(d0, d1, float(i) / n)
			var db := lerpf(d0, d1, float(i + 1) / n)
			var ya := ACQUA + quota_raggio(da)
			var yb := ACQUA + quota_raggio(db)
			# dentro: il profilo a U, da sinistra a destra
			var prof := [Vector2(-a, SOPRA), Vector2(-a, -SOTTO + 0.08), Vector2(-a + 0.08, -SOTTO), Vector2(a - 0.08, -SOTTO),
					Vector2(a, -SOTTO + 0.08), Vector2(a, SOPRA)]
			for k in prof.size() - 1:
				var p0: Vector2 = prof[k]
				var p1: Vector2 = prof[k + 1]
				var verso := Vector3.UP * (1.0 if p0.y < 0.0 and p1.y < 0.0 else 0.3) - r * signf(p0.x + p1.x)
				_faccia(st_b, [pt.call(da, p0.x, ya + p0.y), pt.call(da, p1.x, ya + p1.y), pt.call(db, p1.x, yb + p1.y), pt.call(db, p0.x, yb + p0.y)], verso)
			for lato in [-1.0, 1.0]:
				# il bordo e la falda fino alla banchina (quota 0)
				_faccia(st_g, [pt.call(da, lato * a, ya + SOPRA), pt.call(da, lato * (a + T), ya + SOPRA), pt.call(db, lato * (a + T), yb + SOPRA), pt.call(db, lato * a, yb + SOPRA)], Vector3.UP)
				_faccia(st_g, [pt.call(da, lato * (a + T), ya + SOPRA), pt.call(da, lato * b, 0.0), pt.call(db, lato * b, 0.0), pt.call(db, lato * (a + T), yb + SOPRA)], Vector3.UP + r * lato)
			# l'acqua dello scivolo
			_faccia(st_a, [pt.call(da, -a + 0.02, ya), pt.call(da, a - 0.02, ya), pt.call(db, a - 0.02, yb), pt.call(db, -a + 0.02, yb)], Vector3.UP)
		# il bordo arrotondato della vasca a U, come i bordi degli scivoli del parco
		for lato in [-1.0, 1.0]:
			var ra: Vector3 = pt.call(d0, lato * (a + T * 0.5), ACQUA + SOPRA + 0.02)
			var rb: Vector3 = pt.call(d1, lato * (a + T * 0.5), ACQUA + quota_raggio(d1) + SOPRA + 0.02)
			var bordo := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.045
			cm.bottom_radius = 0.045
			cm.height = ra.distance_to(rb)
			cm.radial_segments = 12
			bordo.mesh = cm
			bordo.material_override = giallo
			var asse := (rb - ra).normalized()
			var x := asse.cross(Vector3.UP).normalized()
			bordo.transform = Transform3D(Basis(x, asse, x.cross(asse)), (ra + rb) * 0.5)
			add_child(bordo)
		# le teste delle falde: in cima verso il canale, in fondo verso la vasca, fin sotto il pelo
		for lato in [-1.0, 1.0]:
			var y1 := ACQUA + quota_raggio(d1)
			_faccia(st_g, [pt.call(d1, lato * a, y1 + SOPRA), pt.call(d1, lato * b, 0.0), pt.call(d1, lato * b, y1 - 0.1), pt.call(d1, lato * a, y1 - 0.1)], u)
			_faccia(st_g, [pt.call(d0, lato * a, ACQUA + SOPRA), pt.call(d0, lato * b, 0.0), pt.call(d0, lato * b, ACQUA - 0.15), pt.call(d0, lato * a, ACQUA - 0.15)], -u)
	_mesh(st_g, giallo, true, false, false).name = "ScivoliFalde"
	_mesh(st_b, blu, true, false, false).name = "ScivoliVasca"
	_mesh(st_a, mat_acqua, false, false, false).name = "AcquaScivoli"   # "acqua...": il controllo di posizionamento lo riconosce


func _vetroresina(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	m.normal_enabled = true
	m.normal_texture = load("res://assets/ambiente/torre/torre_scivoli_vetroresina_nrm.jpg")
	m.normal_scale = 0.5
	# la vetroresina vecchia: lucida a chiazze (la rugosità della torre degli scivoli)
	m.roughness = 1.0
	m.roughness_texture = load("res://assets/ambiente/torre/torre_scivoli_vetroresina_orm.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.5
	return m


## Un quadrilatero con la faccia verso [param verso] (in Godot la faccia davanti gira in senso orario).
func _faccia(st: SurfaceTool, q: Array, verso: Vector3) -> void:
	var g: Vector3 = (q[1] - q[0]).cross(q[2] - q[0])
	if g.length() < 0.000001:
		g = (q[2] - q[0]).cross(q[3] - q[0])
	var idx := [0, 1, 2, 0, 2, 3]
	if g.dot(verso) > 0.0:
		idx = [0, 2, 1, 0, 3, 2]
	var nn := g.normalized() * (-1.0 if g.dot(verso) > 0.0 else 1.0) * -1.0
	for k in idx:
		st.set_normal(nn)
		st.add_vertex(q[k])


## Vero se il lato a-b sta su un bordo del quadrotto (non è bordo d'acqua).
static func _sulla_griglia(a: Vector2, b: Vector2, x0: float, x1: float, z0: float, z1: float) -> bool:
	for gx in [x0, x1]:
		if absf(a.x - gx) < 0.001 and absf(b.x - gx) < 0.001:
			return true
	for gz in [z0, z1]:
		if absf(a.y - gz) < 0.001 and absf(b.y - gz) < 0.001:
			return true
	return false


## Una parete del canale dal bordo a-b giù fino al fondo, con la faccia verso [param n] (l'acqua).
func _parete(st: SurfaceTool, a: Vector2, b: Vector2, n: Vector3) -> void:
	var q := [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x, FONDO, b.y), Vector3(a.x, FONDO, a.y)]
	var nq: Vector3 = (q[1] - q[0]).cross(q[3] - q[0])
	if (-nq).dot(n) < 0.0:
		q = [q[1], q[0], q[3], q[2]]
	var d := (b - a).normalized()
	for idx in [0, 2, 1, 0, 3, 2]:
		var v: Vector3 = q[idx]
		st.set_normal(n)
		st.set_uv(Vector2(v.x * d.x + v.z * d.y, -v.y) * 0.5)
		st.add_vertex(q[idx])


## Quanto sta più su il pelo lungo un raggio sbagliato, a distanza [param d] dal centro: sale piano dalla
## conca del bivio fino all'inizio dello scivolo, poi scende di SCIVOLO_DISCESA fino alla vasca.
static func quota_raggio(d: float) -> float:
	var cima := VASCA + SCIVOLO_L
	if d >= R - CONCA or d <= VASCA:
		return 0.0
	if d >= cima:
		return SCIVOLO_DISCESA * (R - CONCA - d) / (R - CONCA - cima)
	return SCIVOLO_DISCESA * (d - VASCA) / SCIVOLO_L


func _nastro(pts: PackedVector2Array, raggio := false) -> void:
	if raggio:
		# il pelo del canale finisce dove comincia lo scivolo (l'acqua dello scivolo la fa _scivoli)
		var corti := PackedVector2Array()
		var cima := VASCA + SCIVOLO_L
		for i in pts.size():
			if pts[i].length() >= cima:
				corti.append(pts[i])
			elif i > 0 and pts[i - 1].length() > cima:
				corti.append(pts[i].normalized() * cima)
		pts = corti
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	var w := W * 0.5 - 0.01
	for i in pts.size() - 1:
		var y0 := ACQUA + (quota_raggio(pts[i].length()) if raggio else 0.0)
		var y1 := ACQUA + (quota_raggio(pts[i + 1].length()) if raggio else 0.0)
		var p0 := Vector3(pts[i].x, y0, pts[i].y)
		var p1 := Vector3(pts[i + 1].x, y1, pts[i + 1].y)
		var t0 := _tangente2(pts, i)
		var t1 := _tangente2(pts, i + 1)
		var r0 := t0.cross(Vector3.UP).normalized()
		var r1 := t1.cross(Vector3.UP).normalized()
		var d1 := dist + p0.distance_to(p1)
		var aq := [p0 - r0 * w, p0 + r0 * w, p1 + r1 * w, p1 - r1 * w]
		var uv := [Vector2(dist / 5.0, 0), Vector2(dist / 5.0, 1), Vector2(d1 / 5.0, 1), Vector2(d1 / 5.0, 0)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[idx])
			st.add_vertex(aq[idx])
		dist = d1
	_mesh(st, mat_acqua, false, false).name = "acqua_nastro"   # il pelo dell'acqua (il controllo di posizionamento lo riconosce dal nome)


func _lastra(c: PackedVector2Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := Geometry2D.triangulate_polygon(c)
	for k in range(0, tri.size(), 3):
		for j in [0, 2, 1]:
			var v: Vector2 = c[tri[k + j]]
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.y) * 0.2)
			st.add_vertex(Vector3(v.x, ACQUA + 0.002, v.y))
	var m := (mat_acqua as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter(&"flow_speed", 0.25)
	_mesh(st, m, false, false).name = "acqua_lastra"


static func _tangente2(pts: PackedVector2Array, i: int) -> Vector3:
	var a := pts[maxi(i - 1, 0)]
	var b := pts[mini(i + 1, pts.size() - 1)]
	var t := b - a
	return Vector3(t.x, 0, t.y).normalized()


func _quad(st: SurfaceTool, q: Array) -> void:
	var n: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
	if n.length() < 0.5:
		n = Vector3.UP
	for idx in [0, 2, 1, 0, 3, 2]:
		st.set_normal(-n)
		st.add_vertex(q[idx])


func _mesh(st: SurfaceTool, m: Material, ombre: bool, collisione: bool, con_uv := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	st.index()
	if con_uv:
		st.generate_tangents()
	mi.mesh = st.commit()
	mi.material_override = m
	if not ombre:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if collisione:
		var f := CollisionShape3D.new()
		f.shape = mi.mesh.create_trimesh_shape()
		_collisioni.add_child(f)
	return mi


# --- il capannone --------------------------------------------------------------------------------------

func _cemento() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.29, 0.27)
	m.roughness = 0.9
	return m


## I muri di cemento del capannone (con i vani della porta d'ingresso a nord e della porta di servizio
## a ovest) e il tetto di lamiera con le capriate, come nella proposta approvata.
func _capannone() -> void:
	var muro := mat_banca
	var h := TETTO
	var sp := 0.3
	# nord, col vano della porta (1,2 x 2,3)
	var vano := 0.7
	_muro_box(Vector3(INGRESSO_X - vano - X0, h, sp), Vector3((X0 + INGRESSO_X - vano) * 0.5, h * 0.5, Z0 - sp * 0.5), muro)
	_muro_box(Vector3(X1 - INGRESSO_X - vano, h, sp), Vector3((X1 + INGRESSO_X + vano) * 0.5, h * 0.5, Z0 - sp * 0.5), muro)
	_muro_box(Vector3(vano * 2.0, h - 2.3, sp), Vector3(INGRESSO_X, 2.3 + (h - 2.3) * 0.5, Z0 - sp * 0.5), muro)
	# sud ed est pieni
	_muro_box(Vector3(X1 - X0 + sp * 2.0, h, sp), Vector3((X0 + X1) * 0.5, h * 0.5, Z1 + sp * 0.5), muro)
	_muro_box(Vector3(sp, h, Z1 - Z0), Vector3(X1 + sp * 0.5, h * 0.5, (Z0 + Z1) * 0.5), muro)
	# ovest, col vano della porta di servizio dell'approdo
	var zp := APPRODO.y
	_muro_box(Vector3(sp, h, zp - vano - Z0), Vector3(X0 - sp * 0.5, h * 0.5, (Z0 + zp - vano) * 0.5), muro)
	_muro_box(Vector3(sp, h, Z1 - zp - vano), Vector3(X0 - sp * 0.5, h * 0.5, (Z1 + zp + vano) * 0.5), muro)
	_muro_box(Vector3(sp, h - 2.3, vano * 2.0), Vector3(X0 - sp * 0.5, 2.3 + (h - 2.3) * 0.5, zp), muro)
	# il muro che chiude la piazza a est, lungo il muro nord, fino al canale del raggio d'imbarco
	_muro_box(Vector3(0.3, TETTO, Z_PIAZZA_NORD - Z0), Vector3(MURO_PIAZZA, TETTO * 0.5, (Z0 + Z_PIAZZA_NORD) * 0.5), muro)
	# le due porte: il telaio d'acciaio e l'anta spalancata verso dentro
	await _pausa()
	_porta_aperta(Vector3(INGRESSO_X, 0, Z0), 0.0)
	await _pausa()
	_porta_aperta(Vector3(X0, 0, APPRODO.y), 90.0)
	await _pausa()
	_tetto()


## Il telaio di una porta di servizio nel vano del muro (largo 1,4 m, alto 2,3) e l'anta spalancata
## contro il muro, dalla parte del capannone: la porta guarda verso +Z girata di [param rot] gradi.
func _porta_aperta(pos: Vector3, rot: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot
	add_child(n)
	var telaio := StandardMaterial3D.new()
	telaio.albedo_color = Color(0.3, 0.33, 0.31)
	telaio.metallic = 0.6
	telaio.roughness = 0.5
	var anta := StandardMaterial3D.new()
	anta.albedo_color = Color(0.42, 0.45, 0.43)
	anta.metallic = 0.5
	anta.roughness = 0.6
	for lato in [-1.0, 1.0]:
		_scatola_in(n, Vector3(0.08, 2.3, 0.36), Vector3(lato * 0.66, 1.15, 0.0), telaio)
		# gli stipiti hanno la loro collisione: senza, chi passa la porta ci entrava con la spalla e la testa
		var fs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.08, 2.3, 0.36)
		fs.shape = bs
		fs.transform = n.transform * Transform3D(Basis(), Vector3(lato * 0.66, 1.15, 0.0))
		_collisioni.add_child(fs)
	_scatola_in(n, Vector3(1.4, 0.1, 0.36), Vector3(0, 2.28, 0.0), telaio)
	# l'anta spalancata fin contro il muro (175 gradi: lo stipite non la lascia andare oltre; a 95 gradi quella
	# dell'ingresso entrava nella prima transenna), con la sua collisione
	var cardine := Node3D.new()
	cardine.position = Vector3(0.62, 0, 0.2)
	cardine.rotation_degrees.y = 175.0
	n.add_child(cardine)
	_scatola_in(cardine, Vector3(1.22, 2.2, 0.05), Vector3(-0.61, 1.1, -0.03), anta)
	_scatola_in(cardine, Vector3(0.16, 0.04, 0.06), Vector3(-1.08, 1.05, -0.085), telaio)
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.22, 2.2, 0.05)
	f.shape = b
	f.transform = n.transform * cardine.transform * Transform3D(Basis(), Vector3(-0.61, 1.1, -0.03))
	_collisioni.add_child(f)


func _scatola_in(padre: Node3D, size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	padre.add_child(mi)


func _muro_box(size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	var f := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	f.shape = bs
	f.position = pos
	_collisioni.add_child(f)


## Un parallelepipedo aggiunto a [param st] (per fondere in una mesh sola capriate e travi).
func _box_in(st: SurfaceTool, size: Vector3, xf: Transform3D) -> void:
	var h := size * 0.5
	var facce := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
			[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
			[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	for f in facce:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := n * h
		var du := u * h
		var dv := v * h
		var q := [c - du - dv, c - du + dv, c + du + dv, c + du - dv]
		var nn := (xf.basis * n).normalized()
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nn)
			st.add_vertex(xf * q[idx])


func _tetto() -> void:
	var ferro := StandardMaterial3D.new()
	ferro.albedo_color = Color(0.2, 0.21, 0.2)
	ferro.metallic = 0.7
	ferro.roughness = 0.65
	var lamiera := StandardMaterial3D.new()
	lamiera.albedo_color = Color(0.17, 0.18, 0.18)
	lamiera.metallic = 0.5
	lamiera.roughness = 0.7
	var tetto := Node3D.new()
	tetto.name = "Tetto"
	add_child(tetto)
	var sl := SurfaceTool.new()
	sl.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box_in(sl, Vector3(X1 - X0, 0.06, Z1 - Z0), Transform3D(Basis.IDENTITY, Vector3((X0 + X1) * 0.5, TETTO + 0.03, (Z0 + Z1) * 0.5)))
	var ml := MeshInstance3D.new()
	ml.mesh = sl.commit()
	ml.material_override = lamiera
	tetto.add_child(ml)
	# capriate lungo X ogni 5 m: correnti, montanti e diagonali; arcarecci lungo Z ogni 3 m
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lx := X1 - X0
	var cx := (X0 + X1) * 0.5
	var z := Z0 + 2.0
	while z < Z1:
		_box_in(st, Vector3(lx, 0.18, 0.14), Transform3D(Basis.IDENTITY, Vector3(cx, TETTO - 0.12, z)))
		_box_in(st, Vector3(lx, 0.14, 0.12), Transform3D(Basis.IDENTITY, Vector3(cx, TETTO - 1.1, z)))
		var x := X0
		var k := 0
		while x < X1:
			_box_in(st, Vector3(0.08, 0.9, 0.08), Transform3D(Basis.IDENTITY, Vector3(x, TETTO - 0.6, z)))
			_box_in(st, Vector3(0.06, 1.35, 0.06), Transform3D(Basis(Vector3.BACK, deg_to_rad(48.0 if k % 2 == 0 else -48.0)), Vector3(x + 1.0, TETTO - 0.6, z)))
			x += 2.0
			k += 1
		z += 5.0
	var xa := X0 + 1.0
	while xa < X1:
		_box_in(st, Vector3(0.1, 0.16, Z1 - Z0), Transform3D(Basis.IDENTITY, Vector3(xa, TETTO - 0.3, (Z0 + Z1) * 0.5)))
		xa += 3.0
	var mf := MeshInstance3D.new()
	mf.mesh = st.commit()
	mf.material_override = ferro
	tetto.add_child(mf)
	# le lampade a campana appese alle capriate: poche accese e deboli, le altre spente o storte
	var punti := [[Vector3(-4.0, 0, -7.0), true], [Vector3(14.0, 0, -18.0), false], [Vector3(22.0, 0, 8.0), true],
			[Vector3(8.0, 0, 22.0), false], [Vector3(-16.0, 0, 17.0), true], [Vector3(-27.0, 0, -3.0), true],
			[Vector3(-10.0, 0, -18.0), false], [Vector3(4.0, 0, 9.0), false]]
	for pt in punti:
		var p: Vector3 = pt[0]
		var zc: float = Z0 + 2.0 + roundf((p.z - Z0 - 2.0) / 5.0) * 5.0
		# la catena dalla lampada all'attacco, una piastrina sotto il corrente basso della capriata (fondo a TETTO - 1,17):
		# prima la catena entrava 7 cm nel corrente, senza attacco (collaudo del 22 ottobre)
		var attacco := MeshInstance3D.new()
		var ab := BoxMesh.new()
		ab.size = Vector3(0.08, 0.02, 0.08)
		attacco.mesh = ab
		attacco.material_override = ferro
		attacco.position = Vector3(p.x, TETTO - 1.18, zc)
		tetto.add_child(attacco)
		var catena := MeshInstance3D.new()
		var cb := BoxMesh.new()
		# (il capo di sotto entra 4 mm nell'occhiello in cima alla lampada, pieno da -1,2 a -7,5 mm: prima finiva a filo
		# della cima, accanto all'occhiello, e il controllo dei capi lo dava nel vuoto)
		cb.size = Vector3(0.02, 1.814, 0.02)
		catena.mesh = cb
		catena.material_override = ferro
		catena.position = Vector3(p.x, TETTO - 3.004 + 0.907, zc)
		catena.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tetto.add_child(catena)
		var l := _metti("lampada_capannone", Vector3(p.x, TETTO - 3.0, zc))
		if pt[1]:
			_luce(Vector3(p.x, TETTO - 3.3, zc), Color(1.0, 0.8, 0.55), 2.2, 10.0)
		else:
			l.rotation_degrees.z = _randf_range(-6.0, 6.0)


# --- modelli e luci --------------------------------------------------------------------------------------

func _glb(nome: String) -> Node3D:
	var p := DIR + nome + ".glb"
	if not ResourceLoader.exists(p):
		push_warning("manca " + p)
		return Node3D.new()
	return (load(p) as PackedScene).instantiate()


func _metti(nome: String, pos: Vector3, rot_y := 0.0, scala := 1.0) -> Node3D:
	var n := _glb(nome)
	n.name = nome
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * scala
	add_child(n, true)   # nomi leggibili (palma_finta2...) anche nei rapporti del controllo di posizionamento
	return n


## Porta [param n] (figlio della scena) a terra: il suo punto più basso 1 mm sopra la quota [param y].
func _a_terra(n: Node3D, y := 0.0) -> void:
	var basso := INF
	var io := global_transform.affine_inverse()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var xf := io * (mi as MeshInstance3D).global_transform
		for v in (mi as MeshInstance3D).mesh.get_faces():
			basso = minf(basso, (xf * v).y)
	n.position.y += y + 0.001 - basso


## La quota del punto più alto di [param n] (figlio della scena), coi vertici veri.
func _cima(n: Node3D) -> float:
	var alto := -INF
	var io := global_transform.affine_inverse()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var xf := io * (mi as MeshInstance3D).global_transform
		for v in (mi as MeshInstance3D).mesh.get_faces():
			alto = maxf(alto, (xf * v).y)
	return alto


## Una forma di collisione (cilindro) per un oggetto grande sulle banchine.
func _ostacolo(pos: Vector3, raggio: float, alto: float) -> void:
	var f := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = raggio
	c.height = alto
	f.shape = c
	f.position = pos + Vector3(0, alto * 0.5, 0)
	_collisioni.add_child(f)


func _luce(pos: Vector3, colore: Color, energia: float, raggio: float, ombre := false) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = colore
	o.light_energy = energia
	o.omni_range = raggio
	o.omni_attenuation = 1.3
	o.shadow_enabled = ombre
	o.light_volumetric_fog_energy = 1.5
	o.set_meta(&"risveglio_ignora", true)
	add_child(o)
	return o


## Lampada di servizio a gabbia (la stessa del portone della torre) con la lampadina calda accesa,
## sul muro o sulla roccia: dà la luce neutra che serve a leggere l'ambiente senza torcia.
func _lampada_calda(pos: Vector3, rot_y: float, energia := 3.0, roccia: Node3D = null) -> void:
	var l := (load("res://assets/enigma_acquari/lampada_gabbia.glb") as PackedScene).instantiate() as Node3D
	l.position = pos
	l.rotation_degrees.y = rot_y
	add_child(l)
	var g := l.find_child("globo", true, false) as MeshInstance3D
	if energia <= 0.0:
		# rotta: il vetro spento e sporco, la gabbia storta
		l.rotation_degrees.z = 9.0
	if roccia:
		await _appoggia_su_roccia(l, roccia, Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, 0, 1))
	pos = l.position
	if energia <= 0.0:
		if g:
			var mr := StandardMaterial3D.new()
			mr.albedo_color = Color(0.25, 0.24, 0.2)
			mr.roughness = 0.3
			g.material_override = mr
		return
	if g:
		g.material_override = _mat_globo
	var dir := Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, 0, 1)
	_luce(pos + dir * 0.35, Color(1.0, 0.76, 0.5), energia, 11.0)


## Lampada d'emergenza rossa (modello Meshy + luce), che guarda verso [param verso]: [param pos] è sulla faccia
## del muro (o della roccia), dove la staffa si appoggia con la sua piastra.
func _lampada_rossa(pos: Vector3, verso: Vector3, roccia: Node3D = null) -> void:
	var l := LampadaMuro.monta(self, pos, verso)
	if roccia:
		# sulla roccia la piastra non sta dove [param pos] (il centro della staffa è più su o più giù): si misura la
		# sporgenza della roccia proprio sotto la sua impronta, e la lampada va avanti o indietro finché la piastra la
		# tocca (prima a volte restava a più di 5 mm dal rilievo)
		var n := Vector3(verso.x, 0.0, verso.z).normalized()
		var pi := l.get_node("Piastra") as Node3D
		var dietro := to_local(pi.global_position) - n * LampadaMuro.PIASTRA.z * 0.5
		var punto: Vector3 = await _su_roccia(roccia, dietro, n, LampadaMuro.PIASTRA.x * 0.5 - 0.01, LampadaMuro.PIASTRA.y * 0.5 - 0.01)
		l.position += n * ((punto - dietro).dot(n) + 0.001)
	_luce(l.position + verso.normalized() * 0.3, Color(1.0, 0.18, 0.12), 2.6, 9.0)


## Porta [param l] contro la faccia vera di [param roccia], guardando lungo [param davanti]: dai vertici veri del suo retro
## (fino a 3 cm dal punto più indietro) raggi verso la roccia; la lampada va avanti o indietro finché il vertice più vicino
## sta a 1 mm dalla roccia (con la sporgenza presa su una griglia di 9 punti a volte nessun vertice del retro le stava a
## meno di 5 mm: controllo con la distanza vera, 22 ottobre notte).
func _appoggia_su_roccia(l: Node3D, roccia: Node3D, davanti: Vector3) -> void:
	var d := Vector3(davanti.x, 0.0, davanti.z).normalized()
	var retro := PackedVector3Array()
	var minimo := INF
	for mi in l.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var k: Node = mi
		while k != self and k != null:
			xf = (k as Node3D).transform * xf
			k = k.get_parent()
		for v in (mi as MeshInstance3D).mesh.get_faces():
			var w := xf * v
			retro.append(w)
			minimo = minf(minimo, w.dot(d))
	var tri: PackedVector3Array = await _triangoli_roccia(roccia, l.position, d, 0.35)
	var dietro := PackedVector3Array()
	var visti := {}
	for w in retro:
		if w.dot(d) <= minimo + 0.03 and not visti.has(w):
			visti[w] = true
			dietro.append(w)
	# (al più 80 vertici del retro, sparsi: i raggi sono in GDScript, e il fiume si costruisce mentre ci si arriva)
	var passo := maxi(1, dietro.size() / 80)
	var meglio := INF
	for j in range(0, dietro.size(), passo):
		await _pausa()
		var w := dietro[j]
		var da := w + d * 1.0
		for i in range(0, tri.size(), 3):
			var h = Geometry3D.ray_intersects_triangle(da, -d, tri[i], tri[i + 1], tri[i + 2])
			if h != null:
				meglio = minf(meglio, da.distance_to(h) - 1.0)
	if meglio < INF:
		l.position -= d * (meglio - 0.001)


## I triangoli di [param roccia] (nel sistema del fiume) vicini a [param dove], di lato e in altezza entro [param raggio].
func _triangoli_roccia(roccia: Node3D, dove: Vector3, davanti: Vector3, raggio: float) -> PackedVector3Array:
	var lato := davanti.cross(Vector3.UP).normalized()
	var tri := PackedVector3Array()
	for mi in roccia.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var k: Node = mi
		while k != self and k != null:
			xf = (k as Node3D).transform * xf
			k = k.get_parent()
		var f := (mi as MeshInstance3D).mesh.get_faces()
		for i in range(0, f.size(), 3):
			if i % 6000 == 0:
				await _pausa()
			var a := xf * f[i]
			var w := a - dove
			if absf(w.dot(lato)) < raggio and absf(w.y) < raggio:
				tri.append_array([a, xf * f[i + 1], xf * f[i + 2]])
	return tri


## Faro subacqueo nella parete del canale: oblò sotto il pelo e luce nell'acqua. Senza ombreggiatura e
## scuro (la sua luce lo bruciava in una macchia bianca), la luce senza riflessi.
func _faro_subacqueo(pos: Vector3, rot_y: float) -> void:
	var dir := Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, 0, 1)
	var f := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.1
	cm.height = 0.03
	f.mesh = cm
	f.material_override = _mat_faro
	f.position = pos + dir * 0.01
	f.rotation_degrees = Vector3(90, rot_y, 0)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(f)
	var o := _luce(pos + dir * 0.4, Color(0.75, 0.95, 1.0), 1.6, 4.5)
	o.light_specular = 0.0


## Un pannello di roccia finta (4,2 x 3,2 m, alzato fino a 4,9) col retro verso [param rot] + 180: girato
## e specchiato a caso perché non si veda che è sempre lo stesso. Ha la sua collisione.
func _roccia(pos: Vector3, rot: float, specchio = null) -> Node3D:
	var r := _metti("roccia_parete", pos, rot)
	for mi in r.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat_roccia
	# (quelli doppi, dietro: specchiati o no come dice [param specchio], senza toccare la sequenza casuale degli altri)
	var sx := (-1.0 if specchio else 1.0) if specchio != null else (1.0 if _randf() < 0.5 else -1.0)
	var sy := 1.5 if specchio != null else _randf_range(1.4, 1.6)
	r.scale = Vector3(sx * (1.0 if specchio != null else _randf_range(0.95, 1.1)), sy, 1.0)
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(4.2, 3.24 * sy, 0.5)
	f.shape = b
	f.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(rot)), pos + Basis(Vector3.UP, deg_to_rad(rot)) * Vector3(0, 3.24 * sy * 0.5, 0.25))
	_collisioni.add_child(f)
	return r


## Il retro piatto dei pannelli si vedeva dalle banchine e dai canali degli altri rami: dietro ogni pannello
## [param rocce] ([posizione, rotazione]) un secondo pannello girato, schiena contro schiena, così da tutte e due le
## parti c'è roccia. Non serve dove dietro c'è già il retro di un altro pannello; non va dove non ci sta.
func _rocce_doppie(rocce: Array) -> void:
	var fatte := 0
	var coperte := 0
	var senza := []
	for i in rocce.size():
		await _pausa()
		var p: Vector3 = rocce[i][0]
		var rot: float = rocce[i][1]
		var b := Basis(Vector3.UP, deg_to_rad(rot))
		var dietro := -(b * Vector3.BACK)
		var lato := b * Vector3.RIGHT
		var coperta := false
		for j in rocce.size():
			var w: Vector3 = rocce[j][0] - p
			if j != i and w.dot(dietro) > -0.1 and w.dot(dietro) < 1.5 and absf(w.dot(lato)) < 2.5 \
					and (Basis(Vector3.UP, deg_to_rad(rocce[j][1])) * Vector3.BACK).dot(dietro) > 0.7:
				coperta = true
				break
		if coperta:
			coperte += 1
			continue
		if not _ci_sta(p + dietro * 0.002, rot + 180.0, 4.0, 0.6):
			senza.append(p)
			continue
		_roccia(p + dietro * 0.002, rot + 180.0, i % 2 == 0)
		fatte += 1
	print("rocce: %d, doppie %d, già coperte %d, senza posto %d %s" % [rocce.size(), fatte, coperte, senza.size(), senza])


## Il punto della faccia di [param roccia] davanti a [param dove] (a quota, sull'asse della roccia), guardando da
## [param davanti] verso la roccia: raggi contro i triangoli del modello su tutta l'impronta della piastra (28 x 20
## cm); vale la sporgenza più avanti, così la piastra poggia sul rilievo e non entra nella roccia.
func _su_roccia(roccia: Node3D, dove: Vector3, davanti: Vector3, mezzo_largo := 0.14, mezzo_alto := 0.1) -> Vector3:
	var lato := davanti.cross(Vector3.UP).normalized()
	var tri := PackedVector3Array()
	for mi in roccia.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var k: Node = mi
		while k != self and k != null:
			xf = (k as Node3D).transform * xf
			k = k.get_parent()
		var f := (mi as MeshInstance3D).mesh.get_faces()
		for i in range(0, f.size(), 3):
			if i % 6000 == 0:
				await _pausa()
			# solo i triangoli davanti all'impronta della piastra (la roccia ne ha 40 mila)
			var a := xf * f[i]
			var w := a - dove
			if absf(w.dot(lato)) < 0.45 and absf(w.y) < 0.4:
				tri.append_array([a, xf * f[i + 1], xf * f[i + 2]])
	var meglio := INF
	for du in [-mezzo_largo, 0.0, mezzo_largo]:
		for dv in [-mezzo_alto, 0.0, mezzo_alto]:
			await _pausa()
			var da: Vector3 = dove + lato * du + Vector3(0, dv, 0) + davanti * 2.0
			for i in range(0, tri.size(), 3):
				var h = Geometry3D.ray_intersects_triangle(da, -davanti, tri[i], tri[i + 1], tri[i + 2])
				if h != null:
					meglio = minf(meglio, da.distance_to(h))
	if meglio == INF:
		return dove + davanti * 0.62
	return dove + davanti * (2.0 - meglio)


## Punti a passo [param passo] lungo i punti, dal metro [param inizio], a distanza [param d] dall'asse sui
## due lati: [posizione a quota 0, rotazione Y (gradi) che guarda l'asse, lato (+1 destra, -1 sinistra)].
func _lungo(pts: PackedVector2Array, d: float, passo: float, inizio: float, fine_margine := 0.0) -> Array:
	var out := []
	var tot := 0.0
	for i in pts.size() - 1:
		tot += pts[i].distance_to(pts[i + 1])
	var dist := 0.0
	var prossimo := inizio
	for i in pts.size() - 1:
		dist += pts[i].distance_to(pts[i + 1])
		if dist < prossimo or dist > tot - fine_margine:
			continue
		prossimo += passo
		var t := _tangente2(pts, i)
		var dx := t.cross(Vector3.UP).normalized()
		var p := Vector3(pts[i].x, 0, pts[i].y)
		for lato in [1.0, -1.0]:
			var verso: Vector3 = -dx * lato
			out.append([p + dx * lato * d, rad_to_deg(atan2(verso.x, verso.z)), lato])
	return out


## Vero se il punto sta nella parte del capannone dove si cammina: la piazza davanti all'imbarco, tra
## il muro nord, il raggio d'imbarco, il ramo ovest e il muro dell'approdo.
static func in_piazza(p: Vector3) -> bool:
	if p.x < MURO_APPRODO or p.z > -W * 0.5:
		return false
	return p.x < -W * 0.5 or (p.z < Z_PIAZZA_NORD and p.x < MURO_PIAZZA)


## Vero se il punto (a quota 0) è sulla banchina libera: non nell'acqua, né troppo vicino al bordo.
func _sulla_banchina(p: Vector3, margine := 0.6) -> bool:
	if p.x < X0 + 0.3 or p.x > X1 - 0.3 or p.z < Z0 + 0.3 or p.z > Z1 - 0.3:
		return false
	var v := Vector2(p.x, p.z)
	for w in _poligoni_acqua_cache:
		if Geometry2D.is_point_in_polygon(v, w):
			return false
		for i in w.size():
			var a: Vector2 = w[i]
			var b: Vector2 = w[(i + 1) % w.size()]
			if Geometry2D.get_closest_point_to_segment(v, a, b).distance_to(v) < margine:
				return false
	return true


# --- la logica -----------------------------------------------------------------------------------------

func _logica() -> void:
	fiume = FiumeLento.new()
	fiume.name = "FiumeLento"
	var p := percorsi()
	for nome in p:
		var t := TrattoFiume.new()
		t.name = nome
		t.curve = Curve3D.new()
		for v in _campiona(p[nome]):
			var q := quota_raggio(Vector2(v.x, v.z).length()) if nome.begins_with("Sbagliato") else 0.0
			t.curve.add_point(Vector3(v.x, GALLA + q, v.z))
		if nome.begins_with("Sbagliato"):
			t.ramo_sbagliato = true
			t.velocita = VELOCITA_RITORNO
		fiume.add_child(t)
		tratti[nome] = t
	tratti["Uscita"].uscita = true
	for nome in ["Sbagliato1", "Sbagliato2", "Sbagliato3"]:
		tratti[nome].prossimo = tratti["Imbarco"]
	fiume.imbarco = tratti["Imbarco"]
	# all'approdo si scende sulla banchina, oltre la conca
	fiume.discesa = global_basis * Vector3(-2.6, 0.0, 0.0) + Vector3(0.0, -GALLA + 0.05, 0.0)
	fiume.modello_ciambella = load(DIR + "ciambella.glb")
	# (il fiume entra coi suoi tratti, poi le paratie una per pezzo, al loro posto fra i figli: dopo i tratti, prima
	# della ciambella. Tutto insieme era il pezzo più lungo della costruzione a pezzi, 70 ms)
	add_child(fiume)
	# A ogni bivio la destra è il raggio verso l'imbarco (il ramo sbagliato), la sinistra continua.
	var bivi := [["Imbarco", "Paratia1", 90.0, "Giusto1", "Sbagliato1", true, 55.0, false],
		["Giusto1", "Paratia2", 180.0, "Giusto2", "Sbagliato2", false, 145.0, false],
		["Giusto2", "Paratia3", 270.0, "Uscita", "Sbagliato3", true, 232.0, true]]
	for i in bivi.size():
		await _pausa()
		var b: Array = bivi[i]
		tratti[b[0]].paratia = _paratia(b[1], b[2], tratti[b[3]], tratti[b[4]], b[5], b[6], b[7])
		fiume.move_child(tratti[b[0]].paratia, tratti.size() + i)


func _paratia(nome: String, gradi: float, sx: TrattoFiume, dx: TrattoFiume, a_destra: bool, gradi_bersaglio: float, interno: bool) -> ParatiaFiume:
	var par := ParatiaFiume.new()
	par.name = nome
	par.position = anello(gradi)
	par.sinistra = sx
	par.destra = dx
	par.a_destra = a_destra
	var rb := R - W * 0.5 - 0.55 if interno else R + W * 0.5 + 0.55
	par.posizione_bersaglio = global_transform * (anello(gradi_bersaglio, rb) + Vector3(0, 2.0, 0))
	par.raggio_bersaglio = 0.4
	par.mostra_segnaposto = false
	par.materiale_disco = _mat_disco()
	par.modello_lampada = load(DIR + "lampada_emergenza.glb")
	# il disco guarda chi arriva: un punto del canale 8 m a monte (al bivio 3, a valle: ci si gira)
	var da := gradi_bersaglio + (14.0 if interno else -22.0)
	par.guarda_da = global_transform * (anello(da) + Vector3(0, 1.0, 0))
	fiume.add_child(par)
	return par


func _marker() -> void:
	var m := Node3D.new()
	m.name = "Marker"
	add_child(m)
	for d in [["Ingresso", Vector3(INGRESSO_X, 0, Z0 + 1.2), 0.0], ["FineFila", FINE_FILA, 0.0], ["Imbarco", Vector3(-VASCA - 0.45, 0, -VASCA - 0.45), -135.0],
			["Approdo", Vector3(APPRODO.x - 3.2, 0, APPRODO.y), -90.0], ["PortaPersonale", Vector3(X0, 0, APPRODO.y), -90.0]]:
		var k := Marker3D.new()
		k.name = d[0]
		k.position = d[1]
		k.rotation_degrees.y = d[2]
		m.add_child(k)


## I checkpoint della strada nuova: appena entrati dall'ingresso e all'approdo (si riparte lì, girati
## verso dentro). Senza, morendo nel capannone si ripartiva dal pianerottolo del raccordo.
func _checkpoint() -> void:
	var n := Node3D.new()
	n.name = "Checkpoint"
	add_child(n)
	for i in 2:
		var dove := get_node("Marker/" + ["Ingresso", "Approdo"][i]) as Node3D
		var cp := Checkpoint.new()
		cp.name = ["CheckpointIngresso", "CheckpointApprodo"][i]
		cp.order = ordine_checkpoint + i
		cp.position = dove.position + Vector3(0, 1.5, 0)
		n.add_child(cp)
		var f := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(3.0, 3.0, 3.0)
		f.shape = b
		cp.add_child(f)
		var spawn := Marker3D.new()
		spawn.name = "Ripartenza"
		spawn.position = Vector3(0, -1.5, 0)
		spawn.rotation_degrees.y = [180.0, 90.0][i]   # verso il capannone; all'approdo verso la porta del personale
		cp.add_child(spawn)
		cp.spawn_point = spawn


# --- i bivi: chiuse, pilastri, travi e cartelli d'uscita --------------------------------------------------

var _chiuse := []   # [paratia, nodo della chiusa a sinistra, a destra, luce a sinistra, a destra]


func _bivi() -> void:
	var faccia: Texture2D = load(DIR + "texture/uscita_faccia.jpg")
	var mferro := StandardMaterial3D.new()
	mferro.albedo_color = Color(0.2, 0.2, 0.21)
	mferro.metallic = 0.7
	mferro.roughness = 0.6
	for i in 3:
		var g: float = [90.0, 180.0, 270.0][i]
		var par := fiume.get_node("Paratia%d" % (i + 1)) as ParatiaFiume
		var c := anello(g)
		var t := Vector3(cos(deg_to_rad(g)), 0, sin(deg_to_rad(g)))
		var dentro := -c.normalized()
		# le due bocche: a destra il raggio verso l'imbarco; a sinistra l'anello che continua (al bivio 3
		# il ramo d'uscita, verso fuori)
		var sx: Vector3 = t if i < 2 else -dentro
		var dx: Vector3 = dentro
		var nodi := [par]
		var luci := []
		for k in 2:
			var d: Vector3 = sx if k == 0 else dx
			var e := d.cross(Vector3.UP).normalized()
			var bocca := c + d * CONCA
			# la chiusa a saracinesca nel suo telaio, di traverso alla bocca
			var ch := _metti("paratia", bocca + d * 0.25 + Vector3(0, FONDO, 0))
			ch.basis = Basis(e, Vector3.UP, -d)
			ch.set_meta(&"y_chiusa", FONDO)
			nodi.append(ch)
			# i due pali ai lati della bocca, la trave in alto e il cartello d'uscita sotto la trave
			for lato in [-1.0, 1.0]:
				_palo_trave(bocca + e * lato * (W * 0.5 + 0.4) - d * 0.3, mferro)
			# le guide della chiusa: ai due lati, nel suo piano, dal fondo del canale fin sopra la chiusa alzata (che
			# prima restava sospesa fra i pali, senza toccare niente), con la traversa in cima
			for lato in [-1.0, 1.0]:
				_guida_chiusa(Vector3(0.1, 4.05 - FONDO, 0.62), bocca + d * 0.25 + e * lato * 1.75 + Vector3(0, (FONDO + 4.05) * 0.5, 0), e, d, mferro, true)
			_guida_chiusa(Vector3(3.6, 0.14, 0.62), bocca + d * 0.25 + Vector3(0, 4.05 + 0.07, 0), e, d, mferro, false)
			var trave := MeshInstance3D.new()
			var tb := BoxMesh.new()
			tb.size = Vector3(W + 0.8 + 0.3, 0.22, 0.18)
			trave.mesh = tb
			trave.material_override = mferro
			add_child(trave)
			trave.transform = Transform3D(Basis(e, Vector3.UP, e.cross(Vector3.UP)), bocca - d * 0.3 + Vector3(0, 3.6, 0))
			var cart := CartelloUscita.new()
			cart.name = "Cartello%d%s" % [i + 1, "Sx" if k == 0 else "Dx"]
			cart.tratto = par.sinistra if k == 0 else par.destra
			cart.mostra_segnaposto = false
			cart.faccia = faccia
			add_child(cart)
			# la faccia guarda dentro la conca, verso chi arriva
			# appeso sotto la trave, a contatto (prima stava 3 cm più giù e 12 cm più avanti, nel vuoto)
			cart.transform = Transform3D(Basis.looking_at(d, Vector3.UP), bocca - d * 0.3 + Vector3(0, 3.6 - 0.11 - 0.21, 0))
			# la luce sul lato aperto (dove va la corrente)
			var sp := SpotLight3D.new()
			add_child(sp)
			sp.position = bocca - d * 1.0 + Vector3(0, 3.3, 0)
			sp.look_at(global_transform * (bocca + d * 1.5 + Vector3(0, ACQUA, 0)), Vector3.UP)
			sp.light_color = Color(1.0, 0.85, 0.55)
			sp.light_energy = 2.5
			sp.spot_range = 7.0
			sp.spot_angle = 35.0
			sp.set_meta(&"risveglio_ignora", true)
			luci.append(sp)
		_chiuse.append(nodi + luci)
	_aggiorna_chiuse(1.0)
	# Bivio 3: la colonna che nasconde il disco a chi arriva (ci si gira dopo averla passata)
	var p3 := fiume.get_node("Paratia3") as ParatiaFiume
	var b3: Vector3 = to_local(p3.posizione_bersaglio)
	var verso_monte := Vector3(cos(deg_to_rad(232.0 - 90.0)), 0, sin(deg_to_rad(232.0 - 90.0)))
	var col := anello(229.0, R - W * 0.5 - 0.75)
	var colonna := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.0, 4.6, 1.0)
	colonna.mesh = cm
	colonna.material_override = mat_banca
	colonna.position = col + Vector3(0, 2.3, 0)
	add_child(colonna)
	var fc := CollisionShape3D.new()
	var bc := BoxShape3D.new()
	bc.size = cm.size
	fc.shape = bc
	fc.position = colonna.position
	_collisioni.add_child(fc)
	if b3 == Vector3.ZERO or verso_monte == Vector3.ZERO:
		push_warning("bivio 3 senza disco")


## Un pezzo del telaio della chiusa (size: lungo e, alto, lungo d), con la collisione se [param solido].
func _guida_chiusa(size: Vector3, centro: Vector3, e: Vector3, d: Vector3, m: Material, solido: bool) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	add_child(mi)
	mi.transform = Transform3D(Basis(e, Vector3.UP, d), centro)
	if solido:
		var f := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		f.shape = bs
		f.transform = mi.transform
		_collisioni.add_child(f)


func _palo_trave(p: Vector3, m: Material) -> void:
	# dal fondo del canale (la bocca della conca è acqua: prima i pali finivano a quota 0, 22 cm sopra il pelo, e il
	# portale non toccava niente) fino a 3,8 m
	var pil := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.3, 3.8 - FONDO, 0.3)
	pil.mesh = cm
	pil.material_override = m
	pil.position = p + Vector3(0, (3.8 + FONDO) * 0.5, 0)
	add_child(pil)
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = cm.size
	f.shape = b
	f.position = pil.position
	_collisioni.add_child(f)


## Le chiuse seguono le paratie: quella del lato dove va la corrente è alzata (2,3 m) e illuminata.
func _aggiorna_chiuse(k: float) -> void:
	for c in _chiuse:
		var par := c[0] as ParatiaFiume
		for lato in 2:
			var ch := c[1 + lato] as Node3D
			var luce := c[3 + lato] as SpotLight3D
			var aperta := par.a_destra == (lato == 1)
			var y := float(ch.get_meta(&"y_chiusa")) + (2.3 if aperta else 0.0)
			ch.position.y = lerpf(ch.position.y, y, k)
			luce.light_energy = lerpf(luce.light_energy, 2.5 if aperta else 0.0, k)


func _process(delta: float) -> void:
	if not _chiuse.is_empty():
		_aggiorna_chiuse(clampf(delta * 2.5, 0.0, 1.0))


# --- la giungla finta -------------------------------------------------------------------------------------

## Vero se un oggetto largo [param largo] in [param p], girato di [param rot] (gradi), sta sulle banchine
## senza toccare l'acqua, i muri, le zone da lasciare libere.
func _ci_sta(p: Vector3, rot: float, largo: float, profondo: float) -> bool:
	var e := Basis(Vector3.UP, deg_to_rad(rot)) * Vector3.RIGHT
	var f := Basis(Vector3.UP, deg_to_rad(rot)) * Vector3.BACK
	for q in [p, p + e * largo * 0.5, p - e * largo * 0.5, p + f * profondo, p + f * profondo + e * largo * 0.5, p + f * profondo - e * largo * 0.5]:
		if not _sulla_banchina(q, 0.25):
			return false
		for libera in _zone_libere:
			if Vector2(q.x, q.z).distance_to(libera[0]) < libera[1]:
				return false
	return true


## Le zone dove non va niente: il passaggio dall'ingresso all'imbarco, i dischi dei bersagli, la
## colonna del bivio 3, le bocche dei bivi, l'approdo. [centro 2D, raggio]
var _zone_libere: Array = []


func _giungla() -> void:
	_zone_libere = [[Vector2(-VASCA, -VASCA), 5.0], [Vector2(INGRESSO_X, Z0), 3.0], [Vector2(APPRODO.x - 3.0, APPRODO.y), 4.0]]
	for i in 3:
		var par := fiume.get_node("Paratia%d" % (i + 1)) as ParatiaFiume
		var b := to_local(par.posizione_bersaglio)
		_zone_libere.append([Vector2(b.x, b.z), 2.6])
		var c := anello([90.0, 180.0, 270.0][i])
		_zone_libere.append([Vector2(c.x, c.z), CONCA + 2.4])
	var col := anello(229.0, R - W * 0.5 - 0.75)
	_zone_libere.append([Vector2(col.x, col.z), 2.4])
	# pareti di roccia finta lungo i canali, dietro le banchine, con le lampade calde e le rosse
	var n := 0
	var rocce := []
	for s in _strisce:
		for v in _lungo(s, W * 0.5 + BANCA, 3.9, 1.0):
			await _pausa()
			var p: Vector3 = v[0]
			var rot: float = v[1]
			if not _ci_sta(p, rot, 4.0, 0.6):
				continue
			# dalla piazza dell'imbarco (dove si cammina) si vedrebbe il retro piatto del pannello
			var dietro := p - Basis(Vector3.UP, deg_to_rad(rot)) * Vector3.BACK * 1.0
			if in_piazza(dietro):
				continue
			var roccia := _roccia(p, rot)
			rocce.append([p, rot])
			n += 1
			var davanti := Basis(Vector3.UP, deg_to_rad(rot)) * Vector3.BACK
			# le lampade sulla faccia vera della roccia (prima a 62 cm dal suo centro: a volte staccate, a volte dentro)
			if n % 3 == 0:
				await _lampada_calda(await _su_roccia(roccia, p + Vector3(0, 3.0, 0), davanti), rot, 3.0, roccia)
			elif n % 11 == 5:
				await _lampada_rossa(await _su_roccia(roccia, p + Vector3(0, 3.2, 0), davanti), davanti + Vector3(0, -0.5, 0), roccia)
			elif n % 13 == 7:
				await _lampada_calda(await _su_roccia(roccia, p + Vector3(0, 3.0, 0), davanti), rot, 0.0, roccia)
			elif n % 4 == 1 and _randf() < 0.6:
				_metti("liane", p + davanti * 0.45 + Vector3(0, 4.5, 0), rot)
	await _pausa()
	await _rocce_doppie(rocce)
	await _pausa()
	# i fari subacquei nelle pareti dei canali, alternati
	for s in _strisce:
		var k := 0
		for v in _lungo(s, W * 0.5, 4.5, 2.0, 1.5):
			k += 1
			if k % 2 == (0 if v[2] > 0 else 1):
				_faro_subacqueo(v[0] + Vector3(0, FONDO + 0.25, 0), v[1])
	# palme di plastica nelle fioriere, fiori, maschere tiki, il pappagallo e la scimmia di vetroresina
	var cose := [["palma_finta", 1.0, 0.9], ["fiori", 0.6, 0.5], ["palma_finta", 1.0, 0.9], ["pappagallo", 0.5, 0.4],
			["fiori", 0.6, 0.5], ["scimmia", 0.8, 0.5], ["palma_finta", 1.0, 0.9], ["totem_tiki", 0.8, 0.6]]
	var j := 0
	for s in _strisce:
		for v in _lungo(s, W * 0.5 + 0.85, 7.3, 4.0):
			await _pausa()
			if _randf() < 0.45:
				continue
			var p: Vector3 = v[0]
			var cosa: Array = cose[j % cose.size()]
			if not _sulla_banchina(p, cosa[2]) or not _ci_sta(p, v[1], cosa[1], 0.1):
				continue
			j += 1
			var m := _metti(cosa[0], p, v[1] + (_randf_range(-30.0, 30.0) if cosa[0] != "palma_finta" else _randf() * 360.0))
			if cosa[0] == "palma_finta":
				_ostacolo(p, 0.35, 1.2)
			elif cosa[0] == "totem_tiki":
				_ostacolo(p, 0.4, 2.5)
	# le maschere tiki sui pali, qualche salvagente, scalette d'emergenza nel canale
	var k2 := 0
	for s in _strisce:
		for v in _lungo(s, W * 0.5 - 0.05, 13.0, 6.5, 3.0):
			k2 += 1
			if k2 % 3 == 0:
				_metti("scaletta_banchina", v[0] + Vector3(0, FONDO + 0.05, 0), v[1])


func _imbarco() -> void:
	# la cabina dell'imbarco con la tettoia di paglia e la luce ambra, la fila con le transenne
	# (70 cm più in là di prima, lontano dalla strada fra la fine della fila e l'imbarco: la gronda della tettoia,
	# a 1,1-1,6 m, ci passava sopra all'altezza della testa)
	var cab := Vector3(-VASCA - 2.6 - 0.5, 0, -VASCA - 0.6 + 0.48)
	_metti("tornello_imbarco", cab, 45.0)
	_ostacolo(cab, 0.45, 1.35)
	var tet := _metti("tettoia_paglia", cab + Vector3(-0.4, 0, -0.4), 45.0)
	tet.scale = Vector3.ONE * 0.8
	# la gronda di paglia scende fino a 1,1 m: sotto la tettoia non si passa (barriera, non ferma il getto)
	var bt := StaticBody3D.new()
	bt.name = "BarrieraTettoia"
	bt.collision_layer = Layers.BARRIERS
	bt.collision_mask = 0
	var ft := CollisionShape3D.new()
	var bxt := BoxShape3D.new()
	bxt.size = Vector3(4.0 * 0.8, 2.4, 3.42 * 0.8)
	ft.shape = bxt
	ft.transform = tet.transform.orthonormalized() * Transform3D(Basis(), Vector3(0, 1.2, 0))
	bt.add_child(ft)
	add_child(bt)
	_luce(cab + Vector3(0, 1.9, 0), Color(1.0, 0.6, 0.25), 2.5, 7.0, true)
	await _pausa()
	# la fila dell'imbarco: due file di transenne dall'ingresso alla cabina, che guidano alla vasca
	var da := Vector3(INGRESSO_X, 0, Z0 + 1.0)
	var a := FINE_FILA
	var dir := (a - da).normalized()
	var lato := dir.cross(Vector3.UP).normalized()
	var rot := rad_to_deg(atan2(-dir.z, dir.x))   # il lato lungo della transenna lungo la fila
	var lungo := da.distance_to(a)
	var k := 0
	while k * 2.1 + 1.0 < lungo:
		await _pausa()
		var c := da + dir * (k * 2.1 + 1.0)
		for sgn in [-1.0, 1.0]:
			var tp: Vector3 = c + lato * sgn * 0.85
			if _randf() < 0.12:
				# una transenna caduta
				var t := _metti("transenna", tp + lato * sgn * 0.5, rot + _randf_range(-20.0, 20.0))
				t.rotation_degrees.x = 88.0
				_a_terra(t)   # (prima a 27 cm a occhio: restava 5 mm sopra il pavimento)
				# a terra anche lei ferma i piedi (prima ci si passava attraverso)
				var fc := CollisionShape3D.new()
				var bc := BoxShape3D.new()
				bc.size = Vector3(2.0, 1.2, 0.2)
				fc.shape = bc
				fc.transform = t.transform * Transform3D(Basis(), Vector3(0, 0.6, 0))
				_collisioni.add_child(fc)
			else:
				_metti("transenna", tp, rot)
				var f := CollisionShape3D.new()
				var bx := BoxShape3D.new()
				bx.size = Vector3(2.0, 1.2, 0.2)
				f.shape = bx
				f.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(rot)), tp + Vector3(0, 0.6, 0))
				_collisioni.add_child(f)
		k += 1
	await _pausa()
	# la luce lungo la fila: lampade calde sul muro nord e sul muro dell'approdo
	for x in [INGRESSO_X + 6.0, -12.0, -2.0]:
		_lampada_calda(Vector3(x, 3.0, Z0), 0.0, 3.0)
	for z in [-18.0, -9.0]:
		_lampada_calda(Vector3(MURO_APPRODO + 0.15, 3.0, z), 90.0, 2.5 if z < -10.0 else 0.0)
	await _pausa()
	# la pila di ciambelle di ricambio, le ciambelle alla deriva nella vasca e nei canali
	# (ognuna appoggiata a quella sotto coi vertici veri: prima la prima stava 5 cm sopra il pavimento)
	var sotto := 0.0
	for i in 3:
		await _pausa()
		var ci := _metti("ciambella", Vector3(-VASCA - 1.0, 0.0, -VASCA - 5.6), i * 37.0)
		_a_terra(ci, sotto)
		sotto = _cima(ci)
	_ostacolo(Vector3(-VASCA - 1.0, 0, -VASCA - 5.6), 0.6, sotto)
	# (quella della conca del bivio 1 un po' più in là: toccava la guida della chiusa)
	for c in [[Vector3(2.2, GALLA, 2.0), 60.0], [Vector3(-1.4, GALLA, 2.4), 10.0], [Vector3(23.6, GALLA, 1.8), 130.0],
			[Vector3(-12.0, GALLA, 22.0), 80.0], [Vector3(-30.0, GALLA, 0.6), 15.0]]:
		await _pausa()
		_metti("ciambella", c[0], c[1])
	await _pausa()
	# la capanna tiki, il totem, i cartelli a pittogrammi
	_metti("capanna_tiki", Vector3(-14.0, 0, -6.0), 60.0)
	# (la collisione fin dove arriva la tettoia di paglia, 1,55 m dal centro fra 1 e 1,5 m d'altezza: con 1,3 m ci si
	# entrava con la testa, controllo del 23 ottobre)
	_ostacolo(Vector3(-14.0, 0, -6.0), 1.6, 2.1)
	_metti("totem_tiki", Vector3(-VASCA - 0.9, 0, -VASCA - 7.4), 135.0)
	_ostacolo(Vector3(-VASCA - 0.9, 0, -VASCA - 7.4), 0.4, 2.5)
	_cartello_palo(Vector3(-VASCA - 0.6, 0, -VASCA - 2.4), 90.0, "cartello_tuffi")
	_cartello_palo(Vector3(INGRESSO_X + 2.2, 0, Z0 + 1.05), 160.0, "cartello_bimbi")   # (prima il palo stava dentro la prima transenna)
	_metti("salvagente", Vector3(-2.6, 0, -8.5), -90.0)
	_ostacolo(Vector3(-2.6, 0, -8.5), 0.5, 1.4)
	_lampada_calda(Vector3(INGRESSO_X + 1.4, 3.0, Z0), 0.0, 3.0)
	_lampada_rossa(Vector3(INGRESSO_X - 1.2, 2.6, Z0), Vector3(0, -0.4, 1))
	# (la prima stava fra le transenne della fila, a 67 cm dal suo asse: ora 2,2 m fuori, sullo stesso lato)
	await _pausa()
	for p in [Vector3(-9.9, 0, -13.5), Vector3(-VASCA - 9.0, 0, -VASCA - 2.5), Vector3(-VASCA - 0.8, 0, -VASCA - 10.5)]:
		_metti("palma_finta", p, _randf() * 360.0)
		# le foglie cominciano a 1,75 m e arrivano a 93 cm dal tronco: non ci si passa sotto con la testa
		_ostacolo(p, 0.95, 2.0)
	_metti("ciabatta", Vector3(-VASCA - 2.2, 0, -VASCA - 1.8), 35.0)
	_metti("paperella", Vector3(1.0, ACQUA - 0.02, 0.6), 70.0)
	_metti("secchiello", Vector3(-VASCA - 5.0, 0, -VASCA - 4.2), 20.0)
	_metti("detriti", Vector3(-VASCA - 7.6, 0, -VASCA - 1.2), 30.0)


## Palo zincato con un cartello quadrato a pittogrammi (50 cm) in cima, verso [param rot_y].
func _cartello_palo(pos: Vector3, rot_y: float, tex: String) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	var mz := StandardMaterial3D.new()
	mz.albedo_color = Color(0.55, 0.56, 0.55)
	mz.metallic = 0.8
	mz.roughness = 0.5
	var palo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.035
	cm.height = 2.2
	palo.mesh = cm
	palo.material_override = mz
	palo.position = Vector3(0, 1.1, 0)
	n.add_child(palo)
	var lastra := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.52, 0.52, 0.015)
	lastra.mesh = b
	lastra.material_override = mz
	lastra.position = Vector3(0, 1.85, 0.03 + 0.0075 + 0.001)   # appoggiata al palo (prima 7,5 mm davanti)
	n.add_child(lastra)
	var f := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	f.mesh = q
	var mf := StandardMaterial3D.new()
	mf.albedo_texture = load(DIR + "texture/" + tex + ".jpg")
	mf.roughness = 0.6
	f.material_override = mf
	f.position = Vector3(0, 1.85, 0.03 + 0.015 + 0.002)
	n.add_child(f)
	# il palo e la lastra all'altezza della testa: una collisione da terra, così non ci si passa sotto
	var fc := CollisionShape3D.new()
	var bc := BoxShape3D.new()
	bc.size = Vector3(0.55, 2.3, 0.12)
	fc.shape = bc
	fc.transform = n.transform * Transform3D(Basis(), Vector3(0, 1.15, 0))
	_collisioni.add_child(fc)


## L'approdo: la stanza a ovest separata dal resto da due muri (il canale passa in mezzo), la conca con
## la scaletta, la banchina e la porta di servizio verso la zona del personale.
func _approdo() -> void:
	var xm := MURO_APPRODO
	_muro_box(Vector3(0.3, TETTO, -W * 0.5 - BANCA * 0.0 - Z0), Vector3(xm, TETTO * 0.5, (Z0 - W * 0.5) * 0.5), mat_banca)
	_muro_box(Vector3(0.3, TETTO, Z1 - W * 0.5), Vector3(xm, TETTO * 0.5, (Z1 + W * 0.5) * 0.5), mat_banca)
	# sopra il canale il muro continua (il canale passa in un'apertura alta 3 m)
	_muro_box(Vector3(0.3, TETTO - 3.0, W), Vector3(xm, 3.0 + (TETTO - 3.0) * 0.5, 0.0), mat_banca)
	var x1 := APPRODO.x - 2.2
	var sc := _metti("scaletta_banchina", Vector3(x1 + 0.05, FONDO + 0.05, APPRODO.y + 1.2), 90.0)
	sc.name = "Scaletta"
	_metti("ciambella", Vector3(APPRODO.x + 0.8, GALLA, APPRODO.y - 1.4), 15.0)
	_metti("salvagente", Vector3(x1 - 1.0, 0, APPRODO.y - 2.9), 90.0)
	_ostacolo(Vector3(x1 - 1.0, 0, APPRODO.y - 2.9), 0.5, 1.4)
	_cartello_palo(Vector3(x1 - 0.7, 0, APPRODO.y + 2.9), 90.0, "cartello_tuffi")
	var cb := _metti("corrimano_bambu", Vector3(x1 - 0.25, 0, APPRODO.y - 1.9), 90.0)
	var fcb := CollisionShape3D.new()
	var bcb := BoxShape3D.new()
	bcb.size = Vector3(2.0, 1.0, 0.12)
	fcb.shape = bcb
	fcb.transform = cb.transform * Transform3D(Basis(), Vector3(0, 0.5, 0))
	_collisioni.add_child(fcb)
	_metti("detriti", Vector3(X0 + 1.0, 0, APPRODO.y + 1.8), 0.0)
	_metti("ciabatta", Vector3(x1 - 1.6, 0, APPRODO.y + 0.9), 200.0)
	_lampada_calda(Vector3(X0, 3.0, APPRODO.y - 1.6), 90.0, 3.0)
	_lampada_rossa(Vector3(X0, 2.9, APPRODO.y + 1.4), Vector3(1, -0.6, 0))
	for z in [-14.0, 14.0]:
		_lampada_calda(Vector3(xm - 0.15, 3.0, z), -90.0, 2.5 if z < 0.0 else 0.0)



func _mat_disco() -> ShaderMaterial:
	var md := ShaderMaterial.new()
	md.shader = load(DIR + "disco_strisce.gdshader")
	return md
