extends Node3D
## Le stanze nuove della strada di risalita (tappa 7, GDD "Allungare il capitolo", nota approvata il 18
## ottobre in docs/proposte/fiume_infermeria/nota_logica.md), messe nello scafo:
## - il capannone del fiume lento (scenes/risalita/fiume.tscn), a sud del raccordo e a ovest della sala
##   pompe, con il pavimento 5,4 m sotto la sala grande;
## - dalla porta di servizio dell'approdo, la zona del personale (un corridoio corto) e l'infermeria
##   (scenes/risalita/infermeria.tscn);
## - dalla porta nord dell'infermeria la scala di servizio, che sale di 5,4 m e arriva nel corridoio C3,
##   davanti al magazzino dei gonfiabili (il punto dove arrivava il corridoio di prima).
## Coordinate della sala principale (questo nodo sta nell'origine). Il collegamento dal raccordo
## all'ingresso del capannone lo fa [method _corridoio_ingresso].
## Per non disegnare il capannone (quasi 3 milioni di triangoli e una sessantina di luci) quando non si
## vede, le stanze sono visibili solo col giocatore dentro la strada nuova o vicino alle sue porte.

const FIUME := preload("res://scenes/risalita/fiume.tscn")
const INFERMERIA := preload("res://scenes/risalita/infermeria.tscn")
const F := preload("res://scripts/risalita/fiume_gioco.gd")
const I := preload("res://scripts/risalita/infermeria_gioco.gd")

## La quota dei pavimenti nuovi (la sala grande è a 0).
const Y := -5.4
## Il capannone: girato di -90 gradi (il suo ovest, con l'approdo, guarda a nord), centro dell'anello.
const CENTRO_FIUME := Vector3(-35.0, Y, 92.0)
## L'infermeria: la porta sud allineata con la porta dell'approdo, 3 m più a nord.
const CENTRO_INFERMERIA := Vector3(-35.0 - I.PORTA_SUD, Y, 51.0 - 3.0 - I.L)
## La porta nel muro ovest del corridoio C3 (z da 37,95 a 38,95, tra i gonfiabili e gli oggetti appesi).
const PORTA_C3 := Vector3(-16.15, 0.0, 38.45)
## La scala di servizio: larga 2 m, corre verso est lungo z = PORTA_C3.z.
const SCALA_LARGA := 2.0
const ALZATA := 0.18
const PEDATA := 0.28

var fiume: Node3D
var infermeria: Node3D
var _corpo: StaticBody3D
var _mat_cemento: StandardMaterial3D
var _mat_pav: Material
var _zone: Array[AABB] = []


func _ready() -> void:
	_mat_cemento = StandardMaterial3D.new()
	_mat_cemento.albedo_color = Color(0.42, 0.41, 0.39)
	_mat_cemento.roughness = 0.9
	_mat_pav = load("res://assets/fiume_lento/mat_cemento.tres")
	_corpo = StaticBody3D.new()
	_corpo.name = "Corridoi"
	add_child(_corpo)
	fiume = FIUME.instantiate()
	fiume.name = "Fiume"
	fiume.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), CENTRO_FIUME)
	add_child(fiume)
	infermeria = INFERMERIA.instantiate()
	infermeria.name = "Infermeria"
	infermeria.position = CENTRO_INFERMERIA
	add_child(infermeria)
	_zona_personale()
	_scala_di_servizio()
	# le zone dove le stanze si vedono: il capannone, l'infermeria con i corridoi, e un margine
	_zone.append(AABB(Vector3(-64.0, Y - 2.0, 50.0), Vector3(58.5, 12.0, 71.0)))
	_zone.append(AABB(Vector3(-41.0, Y - 2.0, 36.5), Vector3(26.0, 11.0, 15.0)))


# --- pezzi di corridoio --------------------------------------------------------------------------------

func _box(size: Vector3, pos: Vector3, m: Material, collisione := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	if collisione:
		var f := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		f.shape = s
		f.position = pos
		_corpo.add_child(f)
	return mi


## Un tratto di corridoio tra due angoli (pavimento a lo.y): pavimento, soffitto e i muri dei lati
## in [param muri] ("n" a -Z, "s" a +Z, "o" a -X, "e" a +X); vuoto: i due lati lungo l'asse più lungo.
func _corridoio(lo: Vector3, hi: Vector3, alto := 2.6, muri := "") -> void:
	var c := (lo + hi) * 0.5
	var s := hi - lo
	_box(Vector3(s.x, 0.2, s.z), Vector3(c.x, lo.y - 0.1, c.z), _mat_pav)
	_box(Vector3(s.x + 0.4, 0.2, s.z + 0.4), Vector3(c.x, lo.y + alto + 0.1, c.z), _mat_cemento)
	if muri == "":
		muri = "ns" if s.x >= s.z else "oe"
	if "n" in muri:
		_box(Vector3(s.x + 0.4, alto, 0.2), Vector3(c.x, lo.y + alto * 0.5, lo.z - 0.1), _mat_cemento)
	if "s" in muri:
		_box(Vector3(s.x + 0.4, alto, 0.2), Vector3(c.x, lo.y + alto * 0.5, hi.z + 0.1), _mat_cemento)
	if "o" in muri:
		_box(Vector3(0.2, alto, s.z), Vector3(lo.x - 0.1, lo.y + alto * 0.5, c.z), _mat_cemento)
	if "e" in muri:
		_box(Vector3(0.2, alto, s.z), Vector3(hi.x + 0.1, lo.y + alto * 0.5, c.z), _mat_cemento)


func _lampada_rossa(pos: Vector3, verso: Vector3) -> void:
	var l := (load("res://assets/fiume_lento/lampada_emergenza.glb") as PackedScene).instantiate() as Node3D
	add_child(l)
	l.position = pos
	l.look_at(pos + verso, Vector3.UP)
	var o := OmniLight3D.new()
	o.position = pos + verso.normalized() * 0.35
	o.light_color = Color(1.0, 0.18, 0.12)
	o.light_energy = 1.8
	o.omni_range = 7.0
	o.omni_attenuation = 1.3
	o.set_meta(&"risveglio_ignora", true)
	add_child(o)


## La zona del personale: il corridoio di 3 m dalla porta di servizio dell'approdo alla porta sud
## dell'infermeria, con una lampada d'emergenza.
func _zona_personale() -> void:
	var x := -35.0
	_corridoio(Vector3(x - 1.0, Y, 48.0), Vector3(x + 1.0, Y, 51.0))
	# le due porte sono nei muri del capannone e dell'infermeria: qui i muri di testa non servono
	_lampada_rossa(Vector3(x + 0.95, Y + 2.2, 49.5), Vector3(-1, -0.5, 0))


## La scala di servizio: dalla porta nord dell'infermeria un pianerottolo, poi verso est due rampe da
## 15 gradini (18 cm) con un pianerottolo in mezzo, fino alla quota della sala, e un corridoio dritto
## fino alla porta nel muro ovest di C3.
func _scala_di_servizio() -> void:
	var xp := CENTRO_INFERMERIA.x + I.PORTA_NORD           # la porta nord dell'infermeria
	var zn := CENTRO_INFERMERIA.z - I.L                     # il suo muro nord
	var z0 := PORTA_C3.z - SCALA_LARGA * 0.5
	var z1 := PORTA_C3.z + SCALA_LARGA * 0.5
	# dalla porta al corridoio della scala
	_corridoio(Vector3(xp - 1.0, Y, z1), Vector3(xp + 1.0, Y, zn))
	var x := xp - 1.0
	# il pianerottolo in basso, davanti alla porta (a sud si apre verso l'infermeria)
	_corridoio(Vector3(x, Y, z0), Vector3(x + 2.0, Y, z1), 2.6, "no")
	x += 2.0
	var y := Y
	for rampa in 2:
		_rampa(Vector3(x, y, z0), 15)
		x += 15 * PEDATA
		y += 15 * ALZATA
		if rampa == 0:
			_corridoio(Vector3(x, y, z0), Vector3(x + 1.5, y, z1), 2.6, "ns")
			x += 1.5
	# il corridoio in piano fino a C3
	_corridoio(Vector3(x, 0.0, z0), Vector3(PORTA_C3.x - 0.15, 0.0, z1), 2.6)
	_lampada_rossa(Vector3(x + 0.5, 2.2, z1 - 0.05), Vector3(0, -0.5, -1))
	_lampada_rossa(Vector3(xp + 0.9, Y + 2.2, z0 + 0.05), Vector3(0, -0.5, 1))
	var m := Node3D.new()
	m.name = "Marker"
	add_child(m)
	for d in [["CimaScala", Vector3(x + 1.0, 0.0, PORTA_C3.z)], ["PortaC3", PORTA_C3 + Vector3(-0.6, 0, 0)]]:
		var k := Marker3D.new()
		k.name = d[0]
		k.position = d[1]
		m.add_child(k)


## Una rampa di [param n] gradini che sale verso est da [param lo] (angolo basso a ovest-nord):
## gradini visibili e una rampa liscia sotto per la collisione, i muri, il soffitto inclinato.
func _rampa(lo: Vector3, n: int) -> void:
	var lungo := n * PEDATA
	var su := n * ALZATA
	var zc := lo.z + SCALA_LARGA * 0.5
	for i in n:
		_box(Vector3(PEDATA, ALZATA * (i + 1), SCALA_LARGA), Vector3(lo.x + PEDATA * (i + 0.5), lo.y + ALZATA * (i + 1) * 0.5, zc), _mat_pav, false)
	# la rampa liscia (36 gradi circa): ci si sale camminando
	var ang := atan2(su, lungo)
	var l := sqrt(lungo * lungo + su * su)
	var f := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(l, 0.1, SCALA_LARGA)
	f.shape = s
	f.transform = Transform3D(Basis(Vector3.BACK, ang), Vector3(lo.x + lungo * 0.5, lo.y + su * 0.5 - 0.05 / cos(ang), zc))
	_corpo.add_child(f)
	for z in [lo.z - 0.1, lo.z + SCALA_LARGA + 0.1]:
		_box(Vector3(lungo, su + 2.6, 0.2), Vector3(lo.x + lungo * 0.5, lo.y + (su + 2.6) * 0.5, z), _mat_cemento)
	var soff := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(l, 0.2, SCALA_LARGA + 0.4)
	soff.mesh = b
	soff.material_override = _mat_cemento
	soff.transform = Transform3D(Basis(Vector3.BACK, ang), Vector3(lo.x + lungo * 0.5, lo.y + su * 0.5 + 2.7, zc))
	add_child(soff)


# --- visibilità ----------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var p: Node3D = GameState.player if GameState.player and is_instance_valid(GameState.player) else null
	var dentro := p == null
	if p:
		for z in _zone:
			if z.grow(4.0).has_point(p.global_position):
				dentro = true
				break
	if fiume and fiume.visible != dentro:
		fiume.visible = dentro
		infermeria.visible = dentro
