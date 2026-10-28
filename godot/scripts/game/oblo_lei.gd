class_name ObloLei
extends Node3D
## Un oblò grosso nel muro con dietro una vasca allagata, e lei che ti guarda attaccata al vetro (richiesta
## dell'utente del 24 ottobre sera, GDD "Jilly dietro gli oblò": "attraverso dei grossi oblò da cui proviene la sua
## luce luminescente, si possa vedere Jilly che ci osserva attaccata al vetro, durante il percorso"). Un pezzo solo,
## lo stesso nei tre corridoi della Risalita e nella torre.
##
## Il nodo sta al centro dell'oblò, sulla faccia del muro dalla parte di chi guarda; +Z è la normale verso il
## corridoio, la vasca sta verso -Z. Il muro intorno lo fa chi mette l'oblò, con un buco quadrato di
## [member piastra] metri al centro (vedi [method buco]); l'oblò ci mette la piastra d'acciaio rivettata, a filo
## delle due facce del muro, col bordo d'ottone e il vetro, e dietro la vasca: una cisterna dello scafo piena d'acqua
## torbida e scura (pareti di lamiera, tre veli d'acqua sempre più scuri verso il fondo, niente luce sua: la luce
## rosa è quella di lei).
##
## Lei (LeiOblo di mascotte: la posa, l'occhio che segue, la luce rosa con le ombre, il distacco, i tentacoli fuori dal
## vetro e dalla vasca con le [method forme]) compare una volta sola; il modello c'è solo mentre si vede:
## - solo al buio dopo la sala pompe ([member GameState.luci] BLACKOUT) e col giocatore nella [member zona];
## - quando il vetro non si vede (fuori dal cono di [member angolo_fuori] gradi o dietro un muro): mai sotto gli occhi;
## - resta finché il giocatore non l'ha vista bene (il vetro entro [member angolo_vista] gradi per
##   [member tempo_vista] secondi), poi si stacca piano e sparisce nel buio dell'acqua quando lui guarda via per
##   [member tempo_via] secondi, o quando si avvicina sotto [member vicino] metri (anche prima di averla vista).
##   "Dovrebbe restare finché non la vedi bene o ti avvicini";
## - se il giocatore se ne va senza averla vista, lei se ne va quando non la vede (e torna la volta dopo);
## - sparita, l'oblò resta vuoto: lo stato si salva coi checkpoint (gruppo "persist").
##
## Niente blocchi quando lei compare (riscontro dell'utente sulla v0.3.14): chi mette l'oblò chiama
## [method prepara_lei] mentre costruisce la zona (lei nasce lì, nascosta e ferma, con le forme e l'interno abbassato) e
## poi [method prepara_materiali_lei] (o lo fa SalaTorre.prepara_materiali), che la disegna fuori vista, così le
## pipeline dei suoi materiali si compilano lì. Alla comparsa lei si mostra e basta; a fine distacco
## si ripone (nascosta e ferma), non si libera. Senza preparazione si crea e si riscalda al momento, come prima.

signal comparsa
signal vista
signal staccata
signal finita

enum Stato {ATTESA, PRONTA, VISTA, VIA, FINITA}

## Di serie: il lato della piastra quadrata (e del buco nel muro), il raggio del vetro, del bordo d'ottone e del cerchio
## dei rivetti (vedi [member piastra] e [member raggio_vetro]: bordo e rivetti seguono il vetro in proporzione).
const PIASTRA := 1.9
const RAGGIO_VETRO := 0.6
const RAGGIO_BORDO := 0.7
const RAGGIO_RIVETTI := 0.82
const RIVETTI := 24
## Di quanto la faccia della vasca resta dietro il retro del muro (così non si sovrappone alla sua faccia).
const STACCO_VASCA := 0.02
## Lo spessore delle forme della vasca per i tentacoli (fuori dall'interno).
const FORMA := 0.3

## Il lato della piastra quadrata (e del buco da lasciare nel muro) e il raggio del vetro visibile, per questo oblò.
@export var piastra := PIASTRA
@export var raggio_vetro := RAGGIO_VETRO
## La posa di lei: "schiacciata", "sbircia" o "capovolta" (le fa mascotte).
@export var posa := "schiacciata"
## Per "sbircia": da che lato del vetro, visto dal corridoio (1 a destra, -1 a sinistra).
@export var lato_sbircia := 1.0
## Dove deve stare il giocatore perché lei compaia (nel mondo). Vuota: entro [member raggio] dal vetro.
@export var zona := AABB()
@export var raggio := 10.0
## Lo spessore del muro (la piastra lo riempie, il vetro sta a filo del retro, dalla parte dell'acqua).
@export var spessore_muro := 0.2
## La vasca dietro: larga (lungo il muro), profonda (dietro il muro), quanto scende sotto il centro e quanto sale.
@export var vasca_larga := 3.2
@export var vasca_fonda := 2.7
@export var vasca_sotto := 5.2
@export var vasca_sopra := 1.8
## Di quanto il centro della vasca è spostato di lato rispetto all'oblò (lungo il muro, +X del nodo).
@export var vasca_spostata := 0.0
## La vasca a L: sotto la quota y (dal centro del vetro) si allarga di x metri verso +X (per esempio sotto il pavimento
## della stanza accanto, dove sopra non c'è posto). Zero: una scatola sola.
@export var vasca_gradino := Vector2.ZERO
## Sotto questa distanza dal vetro lei si stacca.
@export var vicino := 1.6
## Il vetro "si vede" entro questo angolo dal centro della vista, fino a [member vista_max] metri.
@export var angolo_vista := 22.0
@export var vista_max := 12.0
## Lei compare solo col vetro oltre questo angolo dal centro della vista (o dietro un muro).
@export var angolo_fuori := 40.0
@export var tempo_vista := 1.2
## Dopo averla vista: il vetro oltre [member angolo_via] gradi per [member tempo_via] secondi e lei va via.
@export var angolo_via := 35.0
@export var tempo_via := 0.35
## Il muro della stanza attorno all'oblò (scelta dell'utente del 25 ottobre: niente piastra quadrata scura, il muro arriva
## fino alla cornice tonda d'ottone): fasce orizzontali [{"materiale": Material, "da": y, "a": y, "uv": Transform2D}] in
## coordinate del nodo; la faccia davanti della piastra prende il materiale della fascia (con "uv", le coordinate del
## nodo (x, y) diventano quelle del materiale del muro; senza, il materiale è triplanare nel mondo; con "colore", il
## colore dei vertici del muro). Vuoto: la piastra d'acciaio rivettata.
@export var muro: Array = []
## Vero: il muro della stanza ha già il suo foro tondo fino sotto la cornice (lo fa chi mette l'oblò, come i muri della
## Risalita): niente faccia davanti, solo la flangia d'ottone sul muro.
@export var muro_col_foro_tondo := false
## Falso: niente lei (per esempio prima del blackout lo decide chi mette l'oblò con [member pronto]).
@export var attivo := true

var stato := Stato.ATTESA
## La lei che sta dietro il vetro, se c'è.
var lei: LeiOblo
## Nel distacco lei si dissolve (la trasparenza delle sue mesh) mentre la sua luce si spegne: quando viene tolta non si
## vede più (D5 del collaudo: alla fine spariva tutta insieme, ancora illuminata dall'ambiente; nella torre è vicina al
## vetro anche alla fine). Si dissolve da questo punto del distacco (0-1) alla fine.
const DISSOLVE_DA := 0.35
var _dissolve: Tween
var _t_vista := 0.0
## Vero quando le pipeline di lei sono già compilate (disegnata fuori vista): alla comparsa niente riscaldamento.
var _riscaldata := false
var _t_via := 0.0
var _corpo: StaticBody3D


func _ready() -> void:
	add_to_group(&"persist")
	_costruisci()


## Il buco quadrato da lasciare nel muro (nel sistema del nodo, sul piano del muro): [centro, mezzo lato].
func buco() -> Array:
	return [Vector2.ZERO, Vector2.ONE * piastra * 0.5]


func _raggio_bordo() -> float:
	return RAGGIO_BORDO * raggio_vetro / RAGGIO_VETRO


## Il centro del vetro dalla parte dell'acqua e la normale verso chi guarda, nel mondo.
func centro_vetro() -> Vector3:
	return global_transform * Vector3(0, 0, -spessore_muro)


func normale() -> Vector3:
	return global_basis.z.normalized()


## I pezzi della vasca, nel sistema del nodo: [x da, x a, y da, y a] (la profondità è la stessa per tutti): uno, o due
## con il [member vasca_gradino] (sopra quello stretto, sotto quello largo).
func pezzi_vasca() -> Array:
	var xa := vasca_spostata - vasca_larga * 0.5
	var xb := vasca_spostata + vasca_larga * 0.5
	if vasca_gradino.x <= 0.0:
		return [[xa, xb, -vasca_sotto, vasca_sopra]]
	var yg := vasca_gradino.y
	return [[xa, xb, yg, vasca_sopra], [xa, xb + vasca_gradino.x, -vasca_sotto, yg]]


## Le forme della vasca per i tentacoli di lei (MorbidezzaLei.aggiungi_scatola): [trasformazione nel mondo, mezze
## misure]. Le cinque pareti, spesse [constant FORMA], e il muro col vetro.
func forme() -> Array:
	var out := []
	var f := FORMA
	var z0 := -spessore_muro - STACCO_VASCA
	var z1 := z0 - vasca_fonda
	var zm := (z0 + z1) * 0.5
	var zh := (z0 - z1) * 0.5
	var xa := vasca_spostata - vasca_larga * 0.5
	var xb := vasca_spostata + vasca_larga * 0.5
	var xe := xb + maxf(vasca_gradino.x, 0.0)
	var y0 := -vasca_sotto
	var y1 := vasca_sopra
	var yg := vasca_gradino.y if vasca_gradino.x > 0.0 else y0
	var xm := (xa + xe) * 0.5
	var scatole := [
		[Vector3(xm, (y0 + y1) * 0.5, z1 - f * 0.5), Vector3((xe - xa) * 0.5 + f, (y1 - y0) * 0.5 + f, f * 0.5)],     # fondo
		[Vector3(xa - f * 0.5, (y0 + y1) * 0.5, zm), Vector3(f * 0.5, (y1 - y0) * 0.5 + f, zh)],                      # sinistra
		[Vector3(xb + f * 0.5, (yg + y1) * 0.5, zm), Vector3(f * 0.5, (y1 - yg) * 0.5 + f, zh)],                      # destra
		[Vector3(xm, y0 - f * 0.5, zm), Vector3((xe - xa) * 0.5 + f, f * 0.5, zh)],                                   # sotto
		[Vector3((xa + xb) * 0.5, y1 + f * 0.5, zm), Vector3((xb - xa) * 0.5 + f, f * 0.5, zh)],                      # sopra
		[Vector3(xm, (y0 + y1) * 0.5, z0 * 0.5), Vector3((xe - xa) * 0.5 + f, (y1 - y0) * 0.5 + f, -z0 * 0.5)],      # muro e vetro
	]
	if xe > xb:
		scatole.append([Vector3(xe + f * 0.5, (y0 + yg) * 0.5, zm), Vector3(f * 0.5, (yg - y0) * 0.5 + f, zh)])     # destra, sotto
		scatole.append([Vector3((xb + xe) * 0.5 + f * 0.5, yg + f * 0.5, zm), Vector3((xe - xb) * 0.5 + f * 0.5, f * 0.5, zh)])   # il gradino
	for s in scatole:
		out.append([global_transform * Transform3D(Basis.IDENTITY, s[0]), s[1] as Vector3])
	return out


# --- come è fatto ------------------------------------------------------------------------------------------------

func _costruisci() -> void:
	var acciaio := _mat_lamiera(Color(0.42, 0.45, 0.46), 1.2)
	# la piastra rivettata, a filo delle due facce del muro, col buco tondo
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var con_muro := not muro.is_empty() or muro_col_foro_tondo
	_piastra(st, _raggio_bordo() - 0.02, not con_muro)
	# (nella torre c'è anche un vetro piccolo, che l'occhio di lei riempie: meno rivetti, almeno 12)
	var k_vetro := raggio_vetro / RAGGIO_VETRO
	var rivetti := maxi(12, roundi(RIVETTI * k_vetro))
	if not con_muro:
		for k in rivetti:
			var a := TAU * float(k) / rivetti
			_rivetto(st, Vector3(cos(a), sin(a), 0.0) * RAGGIO_RIVETTI * k_vetro, 0.016)
		# e i rivetti lungo i lati (la piastra è chiodata al muro)
		for k in 7:
			var u := -piastra * 0.5 + 0.08 + (piastra - 0.16) * float(k) / 6.0
			for v in [-piastra * 0.5 + 0.08, piastra * 0.5 - 0.08]:
				_rivetto(st, Vector3(u, v, 0.0), 0.014)
				if k > 0 and k < 6:
					_rivetto(st, Vector3(v, u, 0.0), 0.014)
	else:
		# il muro della stanza fino alla cornice, e la cornice d'ottone: una flangia tonda sottile sul muro coi rivetti
		if not muro.is_empty():
			_faccia_muro(_raggio_bordo() - 0.02)
		# (poco più larga del vetro: 10 cm oltre il bordo d'ottone, i rivetti nel mezzo)
		_flangia(_raggio_bordo() - 0.02, _raggio_bordo() + 0.1, rivetti, _raggio_bordo() + 0.05)
	st.generate_normals()
	var mp := MeshInstance3D.new()
	mp.name = "struttura_piastra_oblo"
	mp.mesh = st.commit()
	mp.material_override = acciaio
	add_child(mp)
	# il bordo d'ottone: un anello nel buco, con la faccia davanti 1 cm fuori dal muro
	var bordo := MeshInstance3D.new()
	bordo.name = "BordoOttone"
	var tm := TorusMesh.new()
	tm.inner_radius = raggio_vetro
	tm.outer_radius = _raggio_bordo()
	tm.rings = 48
	tm.ring_segments = 12
	bordo.mesh = tm
	bordo.rotation_degrees.x = 90.0
	bordo.position.z = 0.01 - (_raggio_bordo() - raggio_vetro) * 0.5
	bordo.material_override = _mat_ottone()
	add_child(bordo)
	# il vetro, a filo del retro del muro (dalla parte dell'acqua), un po' dentro la piastra tutto intorno
	var vetro := MeshInstance3D.new()
	vetro.name = "Vetro"
	var cm := CylinderMesh.new()
	cm.top_radius = _raggio_bordo() - 0.02
	cm.bottom_radius = _raggio_bordo() - 0.02
	cm.height = 0.03
	cm.radial_segments = 48
	cm.rings = 1
	vetro.mesh = cm
	vetro.rotation_degrees.x = 90.0
	vetro.position.z = -spessore_muro + 0.015
	vetro.material_override = _mat_vetro()
	vetro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # la luce rosa di lei passa
	add_child(vetro)
	# il corpo: piastra e vetro chiudono il buco del muro
	_corpo = StaticBody3D.new()
	_corpo.name = "Corpo"
	_corpo.collision_layer = Layers.WORLD
	add_child(_corpo)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(piastra, piastra, spessore_muro)
	cs.shape = bs
	cs.position.z = -spessore_muro * 0.5
	_corpo.add_child(cs)
	_vasca()


## La piastra quadrata col buco tondo di raggio [param r]: le due facce (davanti a z 0, dietro a -spessore), il
## bordo del buco e i quattro lati.
func _piastra(st: SurfaceTool, r: float, davanti := true) -> void:
	var n := 48
	var h := piastra * 0.5
	var dz := Vector3(0, 0, -spessore_muro)
	for k in n:
		var a0 := TAU * float(k) / n
		var a1 := TAU * float(k + 1) / n
		var c0 := Vector3(cos(a0), sin(a0), 0.0) * r
		var c1 := Vector3(cos(a1), sin(a1), 0.0) * r
		var q0 := _sul_quadrato(a0, h)
		var q1 := _sul_quadrato(a1, h)
		if davanti:
			_quad(st, c0, q0, q1, c1, Vector3.BACK)                  # davanti
		_quad(st, c0 + dz, q0 + dz, q1 + dz, c1 + dz, Vector3.FORWARD)  # dietro
		_quad(st, c0, c1, c1 + dz, c0 + dz, -(c0 + c1))                 # il bordo del buco, verso il centro
	var ang := [Vector3(-h, -h, 0), Vector3(h, -h, 0), Vector3(h, h, 0), Vector3(-h, h, 0)]
	for k in 4:
		var a: Vector3 = ang[k]
		var b: Vector3 = ang[(k + 1) % 4]
		_quad(st, a, b, b + dz, a + dz, a + b)                          # i lati, dentro il muro


## La faccia davanti della piastra col muro della stanza ([member muro]): il quadrato meno il buco tondo di raggio
## [param r], a fasce orizzontali, ognuna col suo materiale (tagliato in due a metà, così il buco sta sul bordo).
func _faccia_muro(r: float) -> void:
	var h := piastra * 0.5
	var cerchio := PackedVector2Array()
	for k in 64:
		var a := TAU * float(k) / 64
		cerchio.append(Vector2(cos(a), sin(a)) * r)
	for fascia in muro:
		var da := maxf(float(fascia.get("da", -INF)), -h)
		var a_ := minf(float(fascia.get("a", INF)), h)
		if a_ - da < 0.001:
			continue
		var uv: Transform2D = fascia.get("uv", Transform2D.IDENTITY)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for meta in [PackedVector2Array([Vector2(-h, da), Vector2(0, da), Vector2(0, a_), Vector2(-h, a_)]),
				PackedVector2Array([Vector2(0, da), Vector2(h, da), Vector2(h, a_), Vector2(0, a_)])]:
			for poly in Geometry2D.clip_polygons(meta, cerchio):
				if Geometry2D.is_polygon_clockwise(poly):
					continue
				var tri := Geometry2D.triangulate_polygon(poly)
				for k in range(0, tri.size(), 3):
					var t := [poly[tri[k]], poly[tri[k + 1]], poly[tri[k + 2]]]
					# (davanti: verso +Z, in senso orario visto da lì)
					if (t[1] - t[0]).cross(t[2] - t[0]) > 0.0:
						t = [t[0], t[2], t[1]]
					for q: Vector2 in t:
						# (col colore dei vertici del muro, se il suo materiale lo usa come albedo: collaudo D1 della torre)
						if fascia.has("colore"):
							st.set_color(fascia["colore"])
						st.set_normal(Vector3.BACK)
						st.set_uv(uv * q)
						st.add_vertex(Vector3(q.x, q.y, 0.0))
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.name = "struttura_muro_oblo"
		mi.mesh = st.commit()
		mi.material_override = fascia["materiale"]
		add_child(mi)


## La cornice d'ottone sul muro: una flangia tonda spessa 6 mm da [param r0] a [param r1], coi rivetti sul cerchio
## [param r_rivetti].
func _flangia(r0: float, r1: float, rivetti: int, r_rivetti: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := 0.006
	var n := 64
	for k in n:
		var a0 := TAU * float(k) / n
		var a1 := TAU * float(k + 1) / n
		var d0 := Vector3(cos(a0), sin(a0), 0.0)
		var d1 := Vector3(cos(a1), sin(a1), 0.0)
		_quad(st, d0 * r0 + Vector3(0, 0, z), d0 * r1 + Vector3(0, 0, z), d1 * r1 + Vector3(0, 0, z), d1 * r0 + Vector3(0, 0, z), Vector3.BACK)
		_quad(st, d0 * r1, d1 * r1, d1 * r1 + Vector3(0, 0, z), d0 * r1 + Vector3(0, 0, z), d0 + d1)
	for k in rivetti:
		var a := TAU * float(k) / rivetti
		_rivetto(st, Vector3(cos(a), sin(a), 0.0) * r_rivetti + Vector3(0, 0, z), 0.016)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "FlangiaOttone"
	mi.mesh = st.commit()
	mi.material_override = _mat_ottone()
	add_child(mi)


## Il punto del bordo del quadrato di mezzo lato [param h] nella direzione [param a].
static func _sul_quadrato(a: float, h: float) -> Vector3:
	var d := Vector2(cos(a), sin(a))
	var m := maxf(absf(d.x), absf(d.y))
	return Vector3(d.x / m * h, d.y / m * h, 0.0)


## Un triangolo che si vede da [param verso] (Godot: davanti in senso orario).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, verso: Vector3) -> void:
	st.add_vertex(a)
	if (b - a).cross(c - a).dot(verso) > 0.0:
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(b)
		st.add_vertex(c)


## Un rivetto: una cupoletta di raggio [param r] sulla faccia davanti, che sporge di 0,6 r.
func _rivetto(st: SurfaceTool, c: Vector3, r: float) -> void:
	var seg := 8
	var su := r * 0.6
	for k in seg:
		var a0 := TAU * float(k) / seg
		var a1 := TAU * float(k + 1) / seg
		var p0 := c + Vector3(cos(a0), sin(a0), 0.0) * r
		var p1 := c + Vector3(cos(a1), sin(a1), 0.0) * r
		var m0 := c + Vector3(cos(a0), sin(a0), 0.0) * r * 0.6 + Vector3(0, 0, su * 0.8)
		var m1 := c + Vector3(cos(a1), sin(a1), 0.0) * r * 0.6 + Vector3(0, 0, su * 0.8)
		var cima := c + Vector3(0, 0, su)
		_quad(st, p0, p1, m1, m0, (p0 + p1) * 0.5 - c + Vector3(0, 0, r * 0.3))
		_tri(st, m0, m1, cima, Vector3.BACK)


## La vasca dietro il muro: l'interno di una cisterna di lamiera (sei facce che guardano dentro, quella davanti col
## buco della piastra) e tre veli d'acqua torbida paralleli al vetro, sempre più scuri verso il fondo.
func _vasca() -> void:
	var z0 := -spessore_muro - STACCO_VASCA
	var z1 := z0 - vasca_fonda
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pz := pezzi_vasca()
	var h := piastra * 0.5
	for i in pz.size():
		var r: Array = pz[i]
		var xa: float = r[0]
		var xb: float = r[1]
		var ya: float = r[2]
		var yb: float = r[3]
		# (ogni faccia si vede da dentro) il fondo, e davanti intorno al buco della piastra (se è in questo pezzo)
		_quad(st, Vector3(xa, ya, z1), Vector3(xb, ya, z1), Vector3(xb, yb, z1), Vector3(xa, yb, z1), Vector3.BACK)
		var davanti: Array = [[xa, xb, ya, yb]]
		if ya < -h and yb > h and xa < -h and xb > h:
			davanti = [[xa, -h, ya, yb], [h, xb, ya, yb], [-h, h, ya, -h], [-h, h, h, yb]]
		for d in davanti:
			_quad(st, Vector3(d[0], d[2], z0), Vector3(d[1], d[2], z0), Vector3(d[1], d[3], z0), Vector3(d[0], d[3], z0), Vector3.FORWARD)
		# i lati: a sinistra sempre; a destra, sopra e sotto dove non c'è l'altro pezzo
		_quad(st, Vector3(xa, ya, z1), Vector3(xa, yb, z1), Vector3(xa, yb, z0), Vector3(xa, ya, z0), Vector3.RIGHT)
		_quad(st, Vector3(xb, ya, z1), Vector3(xb, yb, z1), Vector3(xb, yb, z0), Vector3(xb, ya, z0), Vector3.LEFT)
		if i == pz.size() - 1:
			_quad(st, Vector3(xa, ya, z1), Vector3(xb, ya, z1), Vector3(xb, ya, z0), Vector3(xa, ya, z0), Vector3.UP)
		if i == 0:
			_quad(st, Vector3(xa, yb, z1), Vector3(xb, yb, z1), Vector3(xb, yb, z0), Vector3(xa, yb, z0), Vector3.DOWN)
		elif i == 1:
			# il gradino: il soffitto della parte larga, oltre quella stretta
			var xs: float = pz[0][1]
			_quad(st, Vector3(xs, yb, z1), Vector3(xb, yb, z1), Vector3(xb, yb, z0), Vector3(xs, yb, z0), Vector3.DOWN)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "struttura_vasca_oblo"
	mi.mesh = st.commit()
	mi.material_override = _mat_vasca()
	add_child(mi)
	# l'acqua torbida: veli che si vedono dal vetro, a pezzi come la vasca (una "superficie d'acqua" per i controlli)
	var acqua := Node3D.new()
	acqua.name = "AcquaTorbida"
	add_child(acqua)
	var veli := [0.45, 1.05, 1.75]
	for k in veli.size():
		var rett: Array = [[pz[0][0], pz[0][1], -vasca_sotto, vasca_sopra]]
		if pz.size() > 1:
			rett.append([pz[0][1], pz[1][1], -vasca_sotto, vasca_gradino.y])
		for j in rett.size():
			var r: Array = rett[j]
			var v := MeshInstance3D.new()
			v.name = "Velo%d_%d" % [k, j]
			var qm := QuadMesh.new()
			qm.size = Vector2(float(r[1]) - float(r[0]) - 0.02, float(r[3]) - float(r[2]) - 0.02)
			v.mesh = qm
			v.position = Vector3((float(r[0]) + float(r[1])) * 0.5, (float(r[2]) + float(r[3])) * 0.5, z0 - float(veli[k]))
			v.material_override = _mat_velo(0.22 + 0.08 * k)
			v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			acqua.add_child(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, verso: Vector3) -> void:
	_tri(st, a, b, c, verso)
	_tri(st, a, c, d, verso)


static var _materiali := {}


static func _mat_lamiera(tinta: Color, metri: float) -> StandardMaterial3D:
	var chiave := "lamiera_%s_%s" % [tinta.to_html(), metri]
	if not _materiali.has(chiave):
		const T := "res://assets/ambienti_tecnici/texture/"
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(T + "MetalPlates013_Color.jpg")
		m.albedo_color = tinta
		m.normal_enabled = true
		m.normal_texture = load(T + "MetalPlates013_NormalGL.jpg")
		m.roughness_texture = load(T + "MetalPlates013_Metalness-MetalPlates013_Roughness.jpg")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.metallic_texture = m.roughness_texture
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		m.metallic = 1.0
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / metri
		_materiali[chiave] = m
	return _materiali[chiave]


static func _mat_ottone() -> StandardMaterial3D:
	if not _materiali.has("ottone"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.42, 0.2)
		m.metallic = 0.85
		m.roughness = 0.35
		_materiali["ottone"] = m
	return _materiali["ottone"]


## La lamiera della vasca, che si vede da tutte e due le parti: da fuori, da una fessura qualunque (la soglia di una
## porta, un giunto), si vede la lamiera scura e mai l'interno con lei (D7 del collaudo degli oblò).
static func _mat_vasca() -> StandardMaterial3D:
	if not _materiali.has("vasca"):
		var m := _mat_lamiera(Color(0.16, 0.2, 0.2), 1.6).duplicate() as StandardMaterial3D
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiali["vasca"] = m
	return _materiali["vasca"]


static func _mat_vetro() -> StandardMaterial3D:
	if not _materiali.has("vetro"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.4, 0.6, 0.6, 0.16)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiali["vetro"] = m
	return _materiali["vetro"]


static func _mat_velo(alfa: float) -> StandardMaterial3D:
	var chiave := "velo_%s" % alfa
	if not _materiali.has(chiave):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.03, 0.09, 0.09, alfa)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 1.0
		m.metallic_specular = 0.0
		_materiali[chiave] = m
	return _materiali[chiave]


## I materiali dell'oblò (per il riscaldamento: si compilano prima, dove si costruisce la sala).
static func materiali() -> Array:
	return [_mat_lamiera(Color(0.42, 0.45, 0.46), 1.2), _mat_vasca(), _mat_ottone(),
			_mat_vetro(), _mat_velo(0.22), _mat_velo(0.3), _mat_velo(0.38)]


# --- lei -----------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if stato == Stato.FINITA or stato == Stato.VIA:
		return
	var p := GameState.player
	if p == null or not is_instance_valid(p) or p.camera == null:
		return
	var cam := p.camera
	var dentro := _dentro(p.global_position)
	if stato == Stato.ATTESA and not (attivo and dentro and GameState.luci == GameState.Luci.BLACKOUT):
		return   # (lontano: niente raggi)
	var d := cam.global_position.distance_to(_davanti())
	var ang := _angolo(cam)
	var libera := _vista_libera(cam)
	match stato:
		Stato.ATTESA:
			if attivo and dentro and GameState.luci == GameState.Luci.BLACKOUT and (ang > angolo_fuori or not libera):
				_mostra()
		Stato.PRONTA:
			if libera and ang < angolo_vista and d < vista_max:
				_t_vista += delta
			else:
				_t_vista = maxf(0.0, _t_vista - delta * 0.5)
			if d < vicino:
				_stacca()
			elif _t_vista >= tempo_vista:
				stato = Stato.VISTA
				vista.emit()
			elif not dentro and (ang > angolo_fuori or not libera):
				# se n'è andato senza vederla: via senza farsi vedere, e la volta dopo ricompare
				_togli_lei()
				stato = Stato.ATTESA
		Stato.VISTA:
			if d < vicino:
				_stacca()
				return
			if ang > angolo_via or not libera:
				_t_via += delta
				if _t_via >= tempo_via:
					_stacca()
			else:
				_t_via = 0.0


func _dentro(pos: Vector3) -> bool:
	if zona.size != Vector3.ZERO:
		return zona.has_point(pos)
	return pos.distance_to(global_position) < raggio


## Il punto davanti al vetro, dalla parte di chi guarda (dove si misura se lo si vede).
func _davanti() -> Vector3:
	return global_transform * Vector3(0, 0, 0.05)


## L'angolo (gradi) fra dove guarda la camera e il vetro; 180 se la camera sta dietro il muro.
func _angolo(cam: Camera3D) -> float:
	var v := _davanti() - cam.global_position
	if v.dot(normale()) > -0.05:
		return 180.0
	return rad_to_deg((-cam.global_basis.z).angle_to(v))


## Vero se fra la camera e il vetro non c'è niente.
func _vista_libera(cam: Camera3D) -> bool:
	var spazio := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, _davanti(), Layers.WORLD)
	var p := GameState.player
	if p:
		q.exclude = [p.get_rid()]
	return spazio.intersect_ray(q).is_empty()


## Crea lei adesso, nascosta e ferma dietro il vetro (con le forme, le ossa morbide, l'interno abbassato e le copie
## dei materiali per lo scuro): da chiamare mentre si costruisce la zona, così alla comparsa non si istanzia niente.
## Con [param fase] 0, 1, 2 una parte alla volta, in fotogrammi diversi (la costruzione a pezzi della torre): il
## modello, le ossa morbide, i materiali. Senza, tutto insieme. Ogni parte una volta sola.
func prepara_lei(fase := -1) -> void:
	if Engine.has_meta(&"oblo_senza_preparazione"):
		return
	if fase <= 0 and lei == null:
		_crea_lei()
		lei.prepara(centro_vetro(), normale(), posa, false)
	if lei == null or not lei.tieni:
		return
	if fase < 0 or fase == 1:
		lei.prepara_morbidezza()
	if (fase < 0 or fase == 2) and _scuri.is_empty():
		_abbassa_interno()
		_copie_scure()


func _crea_lei() -> void:
	lei = LeiOblo.new()
	lei.name = "Lei"
	lei.lato_sbircia = 1 if lato_sbircia >= 0.0 else -1
	add_child(lei)
	lei.sparita.connect(_sparita)
	lei.aggiungi_forme(forme())


## Lei vista dal corridoio per un attimo, per chi la disegna fuori vista (SalaTorre.prepara_materiali, o
## [method prepara_materiali_lei]): visibile, ferma, nella sua posa. [method fine_preparazione] la rimette via.
func mostra_per_preparare() -> void:
	if lei == null or stato != Stato.ATTESA:
		return
	lei.mostra(centro_vetro(), normale(), posa)
	if lei.lei:
		lei.lei.process_mode = Node.PROCESS_MODE_DISABLED
	# la sua luce accesa (nella posa "occhio" parte da spenta e si accende piano: qui il tween è fermo), così si
	# compilano anche le ombre della zona nella sua luce
	if lei._tw:
		lei._tw.kill()
	if lei._luce:
		lei._luce.light_energy = 4.0


## Per chi la disegna fuori vista: la mette nella posa del distacco, a [param frazione] della sua durata (staccata dal
## vetro, più in fondo nella vasca: altre luci e altre ombre della zona).
func stacco_per_preparare(frazione := 0.6) -> void:
	if lei == null or lei.lei == null or lei._ap == null or stato != Stato.ATTESA or lei.posa == "":
		return
	var nome := "oblo_" + lei.posa + "_stacca"
	lei._anima(nome, 0.0)
	lei._ap.advance(lei._durata(nome) * frazione)


func fine_preparazione() -> void:
	if lei == null or stato != Stato.ATTESA:
		return
	lei.riponi()
	_riscaldata = true


## Disegna lei una volta fuori vista (una camera sua in un SubViewport con le impostazioni di [param principale] e lo
## stesso mondo; lei e la sua luce su uno strato che la camera del gioco non disegna): le pipeline dei suoi materiali,
## e quelle dell'oblò e del corridoio nella sua luce, si compilano adesso. Da chiamare dopo [method prepara_lei], a schermo nero o col vetro fuori vista.
func prepara_materiali_lei(principale: Viewport, fotogrammi := 6) -> void:
	if lei == null or principale == null or not is_inside_tree() or stato != Stato.ATTESA or _riscaldata:
		return
	if DisplayServer.get_name() == "headless":
		_riscaldata = true
		return
	mostra_per_preparare()
	var strati := {}
	for v in lei.find_children("*", "VisualInstance3D", true, false):
		var vi := v as VisualInstance3D
		if not vi.is_visible_in_tree():
			continue   # (come nella torre: lo strato delle parti nascoste non si tocca)
		strati[vi] = vi.layers
		vi.layers = SalaTorre.STRATO_PREPARA
		# (la sua luce no: illumina e mette in ombra la vasca e il corridoio come nel gioco, così si compilano anche le
		# pipeline delle ombre dei muri nella sua luce)
	var sv := _vista_preparazione(principale)
	var cam := sv.get_child(0) as Camera3D
	# (da dove la vede il giocatore nel corridoio, larga: anche i muri intorno nella sua luce)
	cam.look_at_from_position(global_transform * Vector3(0.2, 0.1, 2.6), global_transform * Vector3(0, -0.3, -1.0))
	for i in fotogrammi + 1:
		if i == fotogrammi / 2:
			stacco_per_preparare()
		await get_tree().process_frame
		if not is_inside_tree():
			break
	sv.queue_free()
	if is_inside_tree():
		await giro_nella_sua_luce(principale)
	for vi in strati:
		if is_instance_valid(vi):
			(vi as VisualInstance3D).layers = strati[vi]
	fine_preparazione()


## Una vista fuori schermo per la preparazione: un SubViewport con le impostazioni di [param principale] e lo stesso
## mondo, con una camera larga che vede tutti gli strati (figlio di questo nodo; chi la usa la libera).
func _vista_preparazione(principale: Viewport) -> SubViewport:
	var sv := SubViewport.new()
	sv.name = "PreparaLei"
	sv.size = Vector2i(320, 180)
	sv.msaa_3d = principale.msaa_3d
	sv.screen_space_aa = principale.screen_space_aa
	sv.use_taa = principale.use_taa
	sv.use_debanding = principale.use_debanding
	sv.use_hdr_2d = principale.use_hdr_2d
	sv.positional_shadow_atlas_size = principale.positional_shadow_atlas_size
	sv.positional_shadow_atlas_16_bits = principale.positional_shadow_atlas_16_bits
	sv.world_3d = principale.find_world_3d()
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	var cam_gioco := principale.get_camera_3d()
	if cam_gioco:
		cam.environment = cam_gioco.environment
		cam.attributes = cam_gioco.attributes
	cam.fov = 100.0
	sv.add_child(cam)
	add_child(sv)
	cam.current = true
	return sv


## Il giro nella sua luce (collaudo di grafica-2: alla comparsa, con la camera vera, 8 pipeline "draw" e 22 s di
## fotogramma su llvmpipe). Nel blackout intorno all'oblò nessuna luce omni tocca i muri, il pavimento, la cornice o la
## lancia in mano: il motore li disegna con le luci omni spente (una specializzazione), e quando si accende la luce rosa
## di lei deve compilare quella con le luci accese. Qui, con lei mostrata e la sua luce accesa (sullo strato fuori
## vista), una camera fuori schermo si gira intorno dal corridoio davanti al vetro (sei direzioni, larga), guarda dai
## punti della [member zona], e poi guarda il modello in mano al giocatore sotto una luce di prova come la sua (sullo
## stesso strato: il gioco non la usa).
func giro_nella_sua_luce(principale: Viewport, fotogrammi := 2) -> void:
	if lei == null or lei.lei == null or not lei.lei.visible or principale == null or not is_inside_tree():
		return
	var sv := _vista_preparazione(principale)
	var cam := sv.get_child(0) as Camera3D
	var centro := global_transform * Vector3(0.0, -0.4, 2.0)
	var b := global_basis
	for d: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.DOWN, Vector3.UP]:
		var dove := (b * d).normalized()
		cam.look_at_from_position(centro, centro + dove, Vector3.UP if absf(dove.y) < 0.9 else b * Vector3.FORWARD)
		for i in fotogrammi:
			await get_tree().process_frame
			if not is_inside_tree():
				sv.queue_free()
				return
	# e dagli occhi del giocatore nei punti della zona da cui può vederla (il centro e i quattro angoli), verso il vetro
	# e dalla parte opposta
	if zona.size != Vector3.ZERO:
		var vetro := centro_vetro()
		var punti: Array[Vector3] = [zona.get_center()]
		for sx in [0.15, 0.85]:
			for sz in [0.15, 0.85]:
				punti.append(zona.position + zona.size * Vector3(sx, 0.5, sz))
		for p0 in punti:
			var pt := Vector3(p0.x, zona.position.y + 1.6, p0.z)
			for verso: float in [1.0, -1.0]:
				var mira := pt + (vetro - pt) * verso
				if mira.distance_to(pt) < 0.1:
					continue
				cam.look_at_from_position(pt, mira, Vector3.UP)
				for i in fotogrammi:
					await get_tree().process_frame
					if not is_inside_tree():
						sv.queue_free()
						return
	var gioc := GameState.player
	if gioc and is_instance_valid(gioc) and gioc.camera and gioc.is_inside_tree():
		var luce := OmniLight3D.new()
		luce.layers = SalaTorre.STRATO_PREPARA   # (prima di entrare nell'albero: nessuno strato cambiato dopo)
		luce.light_color = LeiOblo.ROSA
		luce.light_energy = 4.0
		luce.omni_range = 4.0
		luce.shadow_enabled = true
		luce.position = Vector3(0.0, 0.6, -1.5)
		gioc.camera.add_child(luce)
		cam.fov = gioc.camera.fov
		cam.global_transform = gioc.camera.global_transform
		for i in fotogrammi + 1:
			await get_tree().process_frame
		luce.queue_free()
	sv.queue_free()


func _mostra() -> void:
	if lei == null:
		_crea_lei()
		lei.mostra(centro_vetro(), normale(), posa)
		_abbassa_interno()
	else:
		lei.mostra(centro_vetro(), normale(), posa)
	_scurisci(0.0)
	_t_vista = 0.0
	_t_via = 0.0
	stato = Stato.PRONTA
	comparsa.emit()
	if not _riscaldata:
		_riscalda()


## La struttura interna della campana di lei (Medusa_Interno) si accende da sola, con emissione 4 pensata per la sala.
## Nel buio della vasca, vista attraverso la gelatina che la rifrange, quando la capovolta si stacca e la campana passa
## nel vetro sembrava bruciata in giallo, a righe verticali (D4 del collaudo degli oblò): qui la si abbassa. Si cambia
## una copia del materiale, quello della sala resta com'è. (Patch di enigmi.)
const EMISSIONE_INTERNO := 0.6


func _abbassa_interno() -> void:
	if lei == null:
		return
	for n in lei.find_children("Medusa_Interno", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m and m.emission_enabled and m.emission_energy_multiplier > EMISSIONE_INTERNO:
				var copia := m.duplicate() as BaseMaterial3D
				copia.emission_energy_multiplier = EMISSIONE_INTERNO
				mi.set_surface_override_material(s, copia)


## Il riscaldamento (regola: niente scatti la prima volta che si vede qualcosa): appena lei è comparsa, col vetro fuori
## dalla vista, una camera nascosta in una vista piccola guarda il vetro dal corridoio per qualche fotogramma, con lo
## stesso mondo e le stesse luci (come il tunnel, SalaSottomarino._riscalda): le pipeline dei suoi materiali si
## compilano lì e non quando il giocatore si gira.
func _riscalda() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var vista := get_viewport()
	var vp := SubViewport.new()
	vp.name = "Riscaldamento"
	vp.size = Vector2i(160, 90)
	vp.world_3d = vista.find_world_3d()
	vp.msaa_3d = vista.msaa_3d
	vp.use_taa = vista.use_taa
	vp.screen_space_aa = vista.screen_space_aa
	vp.positional_shadow_atlas_size = vista.positional_shadow_atlas_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	vp.add_child(cam)
	var cam_gioco := vista.get_camera_3d()
	if cam_gioco:
		cam.environment = cam_gioco.environment
		cam.attributes = cam_gioco.attributes
		cam.fov = cam_gioco.fov
	cam.current = true
	cam.look_at_from_position(global_transform * Vector3(0.3, 0.1, 1.6), global_transform * Vector3(0, -0.3, -1.0))
	for i in 7:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	vp.queue_free()
	_riscaldata = true


## Lei va via adesso, col suo distacco lento, se è dietro il vetro (per chi la vuole altrove: nella torre prima che
## parta l'inseguimento); poi l'oblò resta vuoto. Se non è ancora comparsa, non compare più.
func via() -> void:
	if stato == Stato.PRONTA or stato == Stato.VISTA:
		_stacca()
	elif stato == Stato.ATTESA:
		stato = Stato.FINITA


func _stacca() -> void:
	stato = Stato.VIA
	staccata.emit()
	if lei:
		lei.stacca()
		_dissolvi()
	else:
		_sparita()


## La dissolvenza del distacco: lei si scurisce fino al nero ([method _scurisci]) dalla [constant DISSOLVE_DA] della
## sua durata alla fine (quando lei viene tolta).
func _dissolvi() -> void:
	var d: float = lei.call(&"_durata", "oblo_" + lei.posa + "_stacca") if lei.posa != "" else 2.6
	if _dissolve:
		_dissolve.kill()
	_dissolve = create_tween()
	_dissolve.tween_method(_scurisci, 0.0, 1.0, d * (1.0 - DISSOLVE_DA)).set_delay(d * DISSOLVE_DA)


## Lo scuro del distacco, da 0 (com'è) a 1 (nera: niente colore, luce propria né riflessi). Prima era la trasparenza
## dei nodi, ma le parti trasparenti si ordinavano male e la palpebra finiva sotto l'occhio ("quando Jilly va via
## nell'oblò le si toglie la palpebra", riscontro dell'utente). Sulle copie dei materiali di lei ([method _copie_scure]),
## col parametro "scurisci" per la campana e l'occhio: cambiano solo dei valori, nessuna pipeline nuova.
func _scurisci(x: float) -> void:
	if lei == null or not is_instance_valid(lei):
		return
	if _scuri.is_empty() and x > 0.0:
		_copie_scure()
	# (al quadrato: il corpo perde anche la luce rosa di lei, che si spegne insieme; l'occhio, che ha luce propria,
	# così si spegne con lui e non resta acceso da solo)
	var k := pow(1.0 - clampf(x, 0.0, 1.0), 2.0)
	for m in _scuri_shader:
		(m as ShaderMaterial).set_shader_parameter(&"scurisci", 1.0 - k)
	for e in _scuri:
		var m := e[0] as BaseMaterial3D
		var da: Dictionary = e[1]
		for prop in da:
			var v = da[prop]
			if v is Color:
				var c: Color = v
				m.set(prop, Color(c.r * k, c.g * k, c.b * k, c.a))
			else:
				m.set(prop, float(v) * k)


## I valori dei materiali normali che lo scuro abbassa (tutti fino a 0).
const _SCURI := [&"albedo_color", &"emission_energy_multiplier", &"metallic_specular", &"clearcoat", &"rim",
		&"backlight", &"subsurf_scatter_strength", &"subsurf_scatter_transmittance_boost"]
var _scuri: Array = []          # [copia del materiale, {proprietà: valore di partenza}]
var _scuri_shader: Array = []   # i materiali della campana e dell'occhio di lei (col parametro "scurisci")


## Le copie dei materiali di lei, sue (quelli della sala restano come sono). Gli shader con "scurisci" (la campana,
## l'occhio) si copiano solo se sono quelli condivisi del file: la campana è già una copia della medusa (MedusaStatue
## ci fa pulsare i canali), e resta quella. Una volta, quando lei nasce (in [method prepara_lei]; senza preparazione
## al primo distacco).
func _copie_scure() -> void:
	_scuri.clear()
	_scuri_shader.clear()
	var copie := {}
	for g in _parti_lei():
		var mi := g as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is ShaderMaterial:
				var sh := (m as ShaderMaterial).shader
				if sh == null or not sh.code.contains("scurisci"):
					continue
				if not copie.has(m):
					var c: ShaderMaterial = m.duplicate() if m.resource_path != "" else m
					copie[m] = c
					_scuri_shader.append(c)
				if copie[m] != m:
					mi.set_surface_override_material(s, copie[m])
			elif m is BaseMaterial3D:
				if not copie.has(m):
					var c := m.duplicate() as BaseMaterial3D
					copie[m] = c
					var da := {}
					for prop in _SCURI:
						da[prop] = c.get(prop)
					_scuri.append([c, da])
				mi.set_surface_override_material(s, copie[m])


## Le mesh di lei (il modello, senza la luce).
func _parti_lei() -> Array:
	return lei.find_children("*", "GeometryInstance3D", true, false) if lei and is_instance_valid(lei) else []


func _sparita() -> void:
	_togli_lei()
	stato = Stato.FINITA
	finita.emit()


func _togli_lei() -> void:
	if _dissolve:
		_dissolve.kill()
		_dissolve = null
	if lei and is_instance_valid(lei):
		if lei.tieni:
			# (preparata: si ripone, nascosta e ferma; liberarla costerebbe un attimo di fermo, e può servire ancora)
			_scurisci(0.0)
			lei.riponi()
			return
		lei.queue_free()
	lei = null


func save_state() -> Dictionary:
	return {"finito": stato == Stato.FINITA}


func load_state(s: Dictionary) -> void:
	if bool(s.get("finito", false)):
		_togli_lei()
		stato = Stato.FINITA
	elif stato != Stato.ATTESA:
		# ripartendo da prima che sparisse: di nuovo in attesa, senza lei
		_togli_lei()
		stato = Stato.ATTESA
