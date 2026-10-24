class_name GommoneParkour
extends AnimatableBody3D
## Il gommone tondo delle rapide (sei posti) ormeggiato nel canale del tunnel sottomarino, per il parkour: "sei
## costretto a fare parkour sui galleggianti che stanno sul corso d'acqua per passare da un lato all'altro del
## canale" (GDD, scelte del 24 ottobre). Ondeggia piano sull'acqua (AnimatableBody3D con sync_to_physics: chi ci
## sta sopra viene portato) ed è legato con corde chiare ad anelli nel muro del canale; le corde partono dalle
## maniglie del gommone, arrivano agli anelli e si muovono con lui.
##
## La collisione segue il modello (tools/blender/inseguimento_proposte.py, gommone()): il tubolare è un anello di
## spicchi a sezione di dodecagono (la cima e le facce a 30 gradi si camminano, i fianchi no, e niente sta sospeso
## sopra la gomma), il fondo e i sei sedili a raggiera: dal fondo si risale sul tubolare camminando, sedile dopo
## sedile, coi gradini del Player.
## Si posa con [method posa] dalla strada del tunnel (SalaSottomarino).

## Le misure del modello (m): raggio dell'anello del tubolare, raggio del tubolare.
const R := 1.15
const RT := 0.32
## Sotto il pelo dell'acqua: la base del gommone (il tubolare sta 50 cm sopra l'acqua, come in
## tools/blender/sottomarino_strada.py).
const IMMERSIONE := 0.14
## Le sei maniglie: sul fianco esterno del tubolare, all'altezza dove si legano le corde.
const MANIGLIA_R := R + RT * 0.9
const MANIGLIA_Y := RT * 1.2
## Spicchi del tubolare e lati della sua sezione.
const SPICCHI := 24
const LATI := 12
## La corda: raggio (m) e quanto è più lunga della distanza che copre all'inizio (lasco).
const CORDA_R := 0.016
const LASCO := 0.012

## Il modello del gommone (la scena col suo colore); se manca resta solo la collisione.
@export var modello: PackedScene
## Gli anelli nel muro (posizioni globali): ogni corda va dalla maniglia più vicina al suo anello.
@export var anelli: Array[Vector3] = []
## Il verso in cui guarda ogni anello (fuori dal muro), uno per anello.
@export var versi_anelli: Array[Vector3] = []
## Ondeggiamento: su e giù (m), rollio e beccheggio (gradi), periodo (s), deriva orizzontale (m).
@export var ampiezza := 0.025
@export var rollio := 1.4
@export var periodo := 3.6
@export var deriva := 0.05
## Sfasa l'ondeggiamento dei gommoni vicini.
@export var fase := 0.0

var _base: Transform3D
var _t := 0.0
## Le corde: [{maniglia (locale), anello (globale), lunghezza, mesh}]
var _corde: Array = []
var _mat_corda: StandardMaterial3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	sync_to_physics = true
	set_meta(&"superficie", &"gomma")
	_base = global_transform
	_collisioni()
	if modello:
		var m := modello.instantiate() as Node3D
		m.name = "Modello"
		add_child(m)
	_crea_anelli_e_corde()
	_aggiorna_corde()


func _physics_process(delta: float) -> void:
	_t += delta
	global_transform = posa_al_tempo(_t)
	_aggiorna_corde()


## Dove sta il gommone al tempo [param t] (s): lo stesso ondeggiamento per il gioco, i test e il controllo di
## posizionamento.
func posa_al_tempo(t: float) -> Transform3D:
	var w := TAU / periodo
	var y := ampiezza * sin(w * t + fase)
	var rx := deg_to_rad(rollio) * sin(w * t / 1.37 + fase * 1.9)
	var rz := deg_to_rad(rollio) * sin(w * t / 1.13 + fase * 2.7)
	var spinta := Vector3(deriva * sin(w * t / 2.3 + fase), 0.0, deriva * sin(w * t / 2.9 + fase * 1.3))
	return Transform3D(_base.basis * Basis.from_euler(Vector3(rx, 0.0, rz)), _base.origin + Vector3(0.0, y, 0.0) + _base.basis * spinta)


## Ferma il gommone a un istante dell'ondeggiamento (controllo di posizionamento, scatti).
func ferma_a(t: float) -> void:
	_t = t
	global_transform = posa_al_tempo(t)
	_aggiorna_corde()


# --- collisione ----------------------------------------------------------------------------------------------------

func _collisioni() -> void:
	# il tubolare: SPICCHI pezzi convessi, ognuno la sezione a dodecagono spazzata fra due angoli
	for k in SPICCHI:
		var a0 := TAU * k / SPICCHI
		var a1 := TAU * (k + 1) / SPICCHI
		var punti := PackedVector3Array()
		for a in [a0, a1]:
			var d := Vector3(cos(a), 0.0, -sin(a))
			for j in LATI:
				# il dodecagono circoscritto al tubolare (la cima piatta in alto): la gomma tocca le facce
				var b := TAU * (j + 0.5) / LATI
				var rr := RT / cos(PI / LATI)
				punti.append(d * (R + rr * cos(b)) + Vector3.UP * (RT + rr * sin(b)))
		var forma := ConvexPolygonShape3D.new()
		forma.points = punti
		_forma(forma, Transform3D.IDENTITY, "Tubolare%d" % k)
	# il fondo: un disco sottile dentro il tubolare
	var fondo := CylinderShape3D.new()
	fondo.radius = R - RT * 0.6
	fondo.height = 0.06
	_forma(fondo, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0)), "Fondo")
	# i sei sedili a raggiera (0,42 x 0,13 x 0,18, al centro a 0,55 m e a 0,22 di altezza)
	for k in 6:
		var a := TAU * k / 6.0
		var d := Vector3(cos(a), 0.0, -sin(a))
		var sedile := BoxShape3D.new()
		sedile.size = Vector3(0.42, 0.18, 0.13)
		var bas := Basis(d, Vector3.UP, d.cross(Vector3.UP))
		_forma(sedile, Transform3D(bas, d * 0.55 + Vector3.UP * 0.22), "Sedile%d" % k)


func _forma(forma: Shape3D, t: Transform3D, nome: String) -> void:
	var cs := CollisionShape3D.new()
	cs.name = nome
	cs.shape = forma
	cs.transform = t
	add_child(cs)


# --- anelli e corde ------------------------------------------------------------------------------------------------

## Le maniglie del gommone (locali).
static func maniglie() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in 6:
		var a := TAU * k / 6.0
		out.append(Vector3(cos(a) * MANIGLIA_R, MANIGLIA_Y, -sin(a) * MANIGLIA_R))
	return out


func _crea_anelli_e_corde() -> void:
	_mat_corda = StandardMaterial3D.new()
	_mat_corda.albedo_color = Color(0.86, 0.82, 0.70)
	_mat_corda.roughness = 0.9
	var mat_ferro := StandardMaterial3D.new()
	mat_ferro.albedo_color = Color(0.32, 0.33, 0.34)
	mat_ferro.metallic = 0.7
	mat_ferro.roughness = 0.45
	var man := maniglie()
	var usate := {}
	for i in anelli.size():
		var anello: Vector3 = anelli[i]
		var verso: Vector3 = versi_anelli[i] if i < versi_anelli.size() else Vector3.FORWARD
		# la maniglia più vicina all'anello, una corda per maniglia
		var best := -1
		for k in man.size():
			if usate.has(k):
				continue
			if best < 0 or (_base * man[k]).distance_to(anello) < (_base * man[best]).distance_to(anello):
				best = k
		usate[best] = true
		# l'anello nel muro: la piastra contro il muro e l'anello che ne esce
		var piastra := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.12, 0.02)
		piastra.mesh = bm
		piastra.material_override = mat_ferro
		piastra.name = "Piastra%d" % i
		var tor := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.035
		tm.outer_radius = 0.052
		tor.mesh = tm
		tor.material_override = mat_ferro
		tor.name = "Anello%d" % i
		var ancoraggi := Node3D.new()
		ancoraggi.name = "AncoraggioMuro%d" % i
		ancoraggi.top_level = true
		add_child(ancoraggi)
		var z := verso.normalized()
		var x := Vector3.UP.cross(z).normalized()
		ancoraggi.global_transform = Transform3D(Basis(x, Vector3.UP, z), anello)
		ancoraggi.add_child(piastra)
		piastra.position = Vector3(0, 0, 0.01)
		ancoraggi.add_child(tor)
		tor.rotation = Vector3(0, 0, PI / 2.0)
		tor.position = Vector3(0, 0, 0.02 + 0.052)
		var mi := MeshInstance3D.new()
		mi.name = "Corda%d" % i
		mi.top_level = true
		mi.material_override = _mat_corda
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var capo := anello + z * (0.02 + 0.052 * 2.0 - 0.02)
		_corde.append({"maniglia": man[best], "anello": capo, "lunghezza": (_base * man[best]).distance_to(capo) * (1.0 + LASCO), "mesh": mi})


## I punti della corda fra la maniglia (dove sta ora) e l'anello: una parabola con la freccia che viene dal lasco.
func punti_corda(c: Dictionary, n := 12) -> PackedVector3Array:
	var a: Vector3 = global_transform * (c["maniglia"] as Vector3)
	var b: Vector3 = c["anello"]
	var d := a.distance_to(b)
	var lunga: float = c["lunghezza"]
	var freccia := sqrt(maxf(0.0, 3.0 * d * (lunga - d) / 8.0))
	var out := PackedVector3Array()
	for i in n + 1:
		var f := float(i) / n
		out.append(a.lerp(b, f) + Vector3.DOWN * freccia * 4.0 * f * (1.0 - f))
	return out


func _aggiorna_corde() -> void:
	for c in _corde:
		var pts := punti_corda(c)
		var am := ArrayMesh.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var lati := 6
		for i in pts.size() - 1:
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var t := (p1 - p0).normalized()
			var u := t.cross(Vector3.UP)
			if u.length() < 0.01:
				u = t.cross(Vector3.RIGHT)
			u = u.normalized()
			var v := t.cross(u)
			for j in lati:
				var b0 := TAU * j / lati
				var b1 := TAU * (j + 1) / lati
				var n0 := u * cos(b0) + v * sin(b0)
				var n1 := u * cos(b1) + v * sin(b1)
				var q := [p0 + n0 * CORDA_R, p1 + n0 * CORDA_R, p1 + n1 * CORDA_R, p0 + n1 * CORDA_R]
				var nn := [n0, n0, n1, n1]
				for idx in [0, 1, 2, 0, 2, 3]:
					st.set_normal(nn[idx])
					st.add_vertex(q[idx])
		st.commit(am)
		(c["mesh"] as MeshInstance3D).mesh = am


# --- posa nel tunnel -----------------------------------------------------------------------------------------------

## Mette un gommone nel canale della [param sala] a [param s] metri dalla presa, [param di_lato] metri a destra
## dell'asse, girato di [param giro] gradi; lo lega con due corde ad anelli nei muri del canale, [param corda_lungo]
## metri prima e dopo lungo il canale (lontano dalle linee di salto, che vanno di traverso).
static func posa(sala: SalaSottomarino, s: float, di_lato := 0.0, giro := 0.0, scena: PackedScene = null,
		corda_lungo := 2.4, fase_ := 0.0) -> GommoneParkour:
	var g := GommoneParkour.new()
	g.name = "Gommone_%d" % int(s)
	g.modello = scena
	g.fase = fase_
	var p := sala.punto(s) + sala.destra(s) * di_lato
	var dir := sala.direzione(s)
	var bas := Basis.looking_at(dir, Vector3.UP).rotated(Vector3.UP, deg_to_rad(giro))
	g.transform = Transform3D(bas, Vector3(p.x, sala.acqua - IMMERSIONE, p.z))
	# gli anelli: sul muro del canale verso cui è più vicino il gommone, uno prima e uno dopo
	var lato := 1.0 if di_lato >= 0.0 else -1.0
	for k in [-1.0, 1.0]:
		var sa := s + k * corda_lungo
		var q := sala.punto(sa) + sala.destra(sa) * lato * sala.canale
		g.anelli.append(Vector3(q.x, sala.acqua + 0.2, q.z))
		g.versi_anelli.append(-sala.destra(sa) * lato)
	return g
