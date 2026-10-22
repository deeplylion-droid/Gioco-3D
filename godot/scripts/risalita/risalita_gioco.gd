extends Node3D
## Le stanze nuove della strada di risalita (tappa 7, GDD "Allungare il capitolo", nota approvata il 18
## ottobre in docs/proposte/fiume_infermeria/nota_logica.md), messe nello scafo:
## - il capannone del fiume lento (scenes/risalita/fiume.tscn), a sud del raccordo e a ovest della sala
##   pompe, con il pavimento 5,4 m sotto la sala grande;
## - dalla porta di servizio dell'approdo, la zona del personale (un corridoio corto) e l'infermeria
##   (scenes/risalita/infermeria.tscn);
## - dalla porta nord dell'infermeria la scala di servizio, che sale di 5,4 m e arriva nel corridoio C3,
##   davanti al magazzino dei gonfiabili (il punto dove arrivava il corridoio di prima).
## Coordinate della sala principale (questo nodo sta nell'origine). Dal raccordo si arriva al capannone
## con [method _scala_fiume] (scelta β dell'utente, 21 ottobre): dalla porta di servizio nel tratto basso
## del corridoio C2 una scala scende di 3,6 m e un corridoio porta all'ingresso del capannone.
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
## La porta di servizio nel muro est del tratto basso di C2 (x da 4,6 a 5,6, pavimento a -1,8; la fa
## tools/blender/ambienti2_raccordo.py) e la faccia esterna di quel muro.
const PORTA_C2 := Vector3(5.1, -1.8, 47.16)
## La fascia della scala verso il fiume (z): oltre il muro est della sala pompe (z 48) e prima del vano
## scala del raccordo (z 51,7); in basso passa sopra il corridoio R1 (soffitto a -6).
const SCALA_FIUME_Z := 48.2
## Il corridoio che sale verso nord fino all'ingresso del capannone, tra il suo muro (x -6,1) e il
## raccordo (x -2,7).
const CORRIDOIO_FIUME_X := -5.9
## La scala di servizio: larga 2 m, corre verso est lungo z = PORTA_C3.z.
const SCALA_LARGA := 2.0
const ALZATA := 0.18
const PEDATA := 0.28

var fiume: Node3D
var infermeria: Node3D
var _corpo: StaticBody3D
var _mat_cemento: StandardMaterial3D
var _mat_lamiere: StandardMaterial3D
var _mat_pav: Material
var _zone: Array[AABB] = []


func _ready() -> void:
	# gli stessi materiali dei muri del raccordo (tools/blender/ambienti2_raccordo.py): zoccolo e soffitto di
	# cemento, sopra lamiere rivettate; in proiezione dal mondo, così i pezzi si continuano
	_mat_cemento = _materiale("Concrete042C", 2.5)
	_mat_lamiere = _materiale("MetalPlates013", 2.0)
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
	_scala_fiume()
	# le zone dove le stanze si vedono: il capannone, l'infermeria con i corridoi, e un margine
	_zone.append(AABB(Vector3(-64.0, Y - 2.0, 50.0), Vector3(58.5, 12.0, 71.0)))
	_zone.append(AABB(Vector3(-41.0, Y - 2.0, 36.5), Vector3(26.0, 11.0, 15.0)))
	_zone.append(AABB(Vector3(CORRIDOIO_FIUME_X, Y - 1.0, 46.0), Vector3(13.0, 7.0, 22.0)))


# --- pezzi di corridoio --------------------------------------------------------------------------------

func _materiale(nome: String, metri: float) -> StandardMaterial3D:
	const T := "res://assets/ambienti_tecnici/texture/"
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(T + nome + "_Color.jpg")
	m.normal_enabled = true
	m.normal_texture = load(T + nome + "_NormalGL.jpg")
	m.roughness_texture = load(T + nome + "_Metalness-" + nome + "_Roughness.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_texture = m.roughness_texture
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.metallic = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / metri
	return m


## Un muro come quelli del raccordo: zoccolo di cemento alto 1 m sopra [param base], lamiere sopra.
func _muro(size: Vector3, pos: Vector3, base: float) -> void:
	var y0 := pos.y - size.y * 0.5
	var zc := minf(base + 1.0, y0 + size.y)
	if zc > y0 + 0.01:
		_box(Vector3(size.x, zc - y0, size.z), Vector3(pos.x, (y0 + zc) * 0.5, pos.z), _mat_cemento)
	var y1 := y0 + size.y
	if y1 > zc + 0.01:
		_box(Vector3(size.x, y1 - zc, size.z), Vector3(pos.x, (zc + y1) * 0.5, pos.z), _mat_lamiere)


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
		_muro(Vector3(s.x + 0.4, alto, 0.2), Vector3(c.x, lo.y + alto * 0.5, lo.z - 0.1), lo.y)
	if "s" in muri:
		_muro(Vector3(s.x + 0.4, alto, 0.2), Vector3(c.x, lo.y + alto * 0.5, hi.z + 0.1), lo.y)
	if "o" in muri:
		_muro(Vector3(0.2, alto, s.z), Vector3(lo.x - 0.1, lo.y + alto * 0.5, c.z), lo.y)
	if "e" in muri:
		_muro(Vector3(0.2, alto, s.z), Vector3(hi.x + 0.1, lo.y + alto * 0.5, c.z), lo.y)


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


## Dalla porta di servizio di C2 all'ingresso del capannone: un pianerottolo dietro la porta, la scala
## di 20 gradini che scende verso ovest (sopra il corridoio R1), un pianerottolo in fondo e il corridoio
## verso nord fino alla porta del capannone (z da 65,3 a 66,7 nel suo muro est, x -6,1).
func _scala_fiume() -> void:
	var z0 := SCALA_FIUME_Z
	var z1 := z0 + SCALA_LARGA
	var y0 := PORTA_C2.y
	var x_cima := PORTA_C2.x - 1.0              # dove comincia la scala (in cima)
	var x_fondo := x_cima - 20 * PEDATA          # dove finisce, in basso
	var xc := CORRIDOIO_FIUME_X
	# il pianerottolo dietro la porta: dal muro di C2 fino alla scala, chiuso a est e a nord
	_corridoio(Vector3(x_cima, y0, PORTA_C2.z), Vector3(x_cima + 2.0, y0, z1), 2.6, "se")
	_muro(Vector3(0.2, 2.6, z0 - PORTA_C2.z), Vector3(x_cima - 0.1, y0 + 1.3, (PORTA_C2.z + z0) * 0.5), y0)
	# la scala (sale verso est: la si costruisce dal fondo)
	_rampa(Vector3(x_fondo, Y, z0), 20)
	# in fondo: il pianerottolo che gira verso nord, poi il corridoio fino al capannone
	_corridoio(Vector3(xc, Y, z0), Vector3(x_fondo, Y, z1), 2.6, "no")
	var porta0 := 65.3
	var porta1 := 66.7
	var fine := porta1 + 0.6
	_corridoio(Vector3(xc, Y, z1), Vector3(xc + 2.0, Y, fine), 2.6, "es")
	_muro(Vector3(x_fondo - xc - 2.0, 2.6, 0.2), Vector3((xc + 2.0 + x_fondo) * 0.5, Y + 1.3, z1 + 0.1), Y)
	# il muro ovest, aperto davanti alla porta del capannone (alta 2,3 m come la sua)
	_muro(Vector3(0.2, 2.6, porta0 - z1), Vector3(xc - 0.1, Y + 1.3, (z1 + porta0) * 0.5), Y)
	_muro(Vector3(0.2, 2.6, fine - porta1), Vector3(xc - 0.1, Y + 1.3, (porta1 + fine) * 0.5), Y)
	_box(Vector3(0.2, 0.3, porta1 - porta0), Vector3(xc - 0.1, Y + 2.45, (porta0 + porta1) * 0.5), _mat_lamiere)
	# tra il nostro muro e quello del capannone (x -6,1): il pavimento sotto la porta
	_box(Vector3(0.5, 0.2, porta1 - porta0), Vector3(xc - 0.25, Y - 0.1, (porta0 + porta1) * 0.5), _mat_pav)
	_lampada_rossa(Vector3(x_cima + 1.95, y0 + 2.2, (z0 + z1) * 0.5), Vector3(-1, -0.5, 0))
	_lampada_rossa(Vector3(xc + 1.95, Y + 2.2, z1 + 1.0), Vector3(-1, -0.5, 0))
	_lampada_rossa(Vector3(xc + 1.95, Y + 2.2, porta0 - 3.0), Vector3(-1, -0.5, 0))
	var m := get_node("Marker") as Node3D
	for d in [["PortaC2", Vector3(PORTA_C2.x, y0, PORTA_C2.z - 0.8)], ["CimaScalaFiume", Vector3(x_cima + 1.0, y0, (z0 + z1) * 0.5)],
			["FondoScalaFiume", Vector3(xc + 1.0, Y, (z0 + z1) * 0.5)], ["PortaFiume", Vector3(xc + 1.0, Y, (porta0 + porta1) * 0.5)]]:
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
		_muro(Vector3(lungo, su + 2.6, 0.2), Vector3(lo.x + lungo * 0.5, lo.y + (su + 2.6) * 0.5, z), lo.y)
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
