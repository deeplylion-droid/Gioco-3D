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
## Per la memoria (23 ottobre, le schede da 4 GB) le due stanze non stanno sempre nella sala: si caricano in un
## thread dalla sala pompe in poi ([method _serve]) e si scaricano quando il giocatore è andato oltre il
## magazzino; lo stato dei loro oggetti lo tiene GameState ([method GameState.parcheggia]). I corridoi e le scale
## di qui (pochi box) restano sempre.

const SCENA_FIUME := "res://scenes/risalita/fiume.tscn"
const SCENA_INFERMERIA := "res://scenes/risalita/infermeria.tscn"
## I file che le due stanze caricano con load() mentre si costruiscono (modelli, materiali, texture): il thread li
## carica prima, così la costruzione non ferma il gioco. Lo rifà tests/aggiorna_risorse_risalita.gd;
## test_risalita_tardi controlla che sia completo.
const ELENCO_RISORSE := "res://scenes/risalita/risorse_stanze.json"
## Un materiale senza texture per ogni shader delle stanze che la sala non ha già: tenuti da subito, come quelli della
## torre (SalaTorre.materiali_campione), così quegli shader non si compilano a gioco avviato. Lo rifà lo stesso
## strumento.
const CAMPIONI := "res://scenes/risalita/materiali_campione.tres"
## I collezionabili delle stanze: contano nel totale anche quando le stanze non sono caricate (il visore delle
## Polaroid mostra "x su 10" dall'inizio). test_risalita controlla che siano tutti qui.
const COLLEZIONABILI := [[&"polaroid", &"PolaroidPecora"]]
## Distanza dalle zone delle stanze sotto cui si disegnano (e devono esserci: se il thread non ha finito, si
## finisce di caricarle lì, con un attimo di fermo).
const VICINO := 4.0
## Margine attorno alle zone dentro cui le stanze devono essere finite (si accelera la costruzione, o si caricano lì
## se il thread non le ha ancora): stretto, così la metà nord della sala pompe, sotto il corridoio del fiume ma
## dentro il margine di [constant VICINO], ne resta fuori (collaudo del 23 ottobre).
const DENTRO := 1.0
## Distanza sotto cui servono anche fuori dal tratto della strada nuova (tornando indietro dal magazzino), e
## sopra cui, se non servono, si scaricano.
const RITORNO := 10.0
const LONTANO := 14.0
## I checkpoint della strada nuova: dalla sala pompe (6) al magazzino escluso (la serranda, 16).
const ORDINE_DA := 6
const ORDINE_A := 16
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
## Gli oblò con lei dietro il vetro (GDD "Jilly dietro gli oblò", richiesta dell'utente del 24 ottobre sera: "Mettilo
## in tutti e tre"): il centro sulla faccia del muro dalla parte del corridoio, a 1,5 m dal pavimento. Dietro ogni muro
## c'è il vuoto dello scafo per la vasca (controllato con tests/collaudo/sonda_spazi.gd) e le vasche sono grandi quanto
## lei, ferma e mentre si stacca (le sue ossa, misurate posa per posa): nel corridoio verso il fiume a est, verso il
## raccordo (libero da z 54,5 e per quasi 10 m); nel corridoio del personale a ovest, fra infermeria e capannone (largo
## solo 2,56 m, profondo quanto si vuole); nel tratto in piano della scala di servizio a nord (libero per 6,7 m, da -6 a
## 14 m d'altezza: lei a testa in giù ha il corpo in alto).
## Il raggio del foro tondo nel muro per gli oblò: fra il bordo del vetro e quello della flangia d'ottone (0,68-0,8 m).
const FORO_OBLO := 0.74
const OBLO_FIUME := Vector3(-3.9, Y + 1.5, 58.0)
const OBLO_PERSONALE := Vector3(-36.0, Y + 1.5, 49.6)
const OBLO_SERVIZIO := Vector3(-21.5, 1.5, 37.45)
const ALZATA := 0.18
const PEDATA := 0.28

## Falso: le stanze si caricano subito in _ready e restano sempre, come prima (strumenti e test che le vogliono
## sempre). Lo stesso con Engine.set_meta(&"risalita_subito", true).
@export var a_richiesta := true
var fiume: Node3D
var infermeria: Node3D
var _in_caricamento := false
# i file chiesti al thread, e quelli già arrivati (tenuti finché le stanze non sono costruite)
var _richiesti: PackedStringArray = []
var _tenuti: Array[Resource] = []
# il capannone che si sta costruendo a pezzi (fiume resta vuoto finché non è finito)
var _fiume_nuovo: Node3D
## Vero: il giocatore è arrivato prima che le stanze fossero pronte, si costruiscono a pezzi più grandi.
var _accelerata := false
var _campioni: Array = []
var _corpo: StaticBody3D
var _mat_cemento: StandardMaterial3D
var _mat_lamiere: StandardMaterial3D
var _mat_pericolo: StandardMaterial3D
var _mat_giallo: StandardMaterial3D
var _mat_pav: Material
var _zone: Array[AABB] = []


func _ready() -> void:
	# gli stessi materiali dei muri del raccordo (tools/blender/ambienti2_raccordo.py): zoccolo e soffitto di
	# cemento, sopra lamiere rivettate; in proiezione dal mondo, così i pezzi si continuano
	_mat_cemento = _materiale("Concrete042C", 2.5)
	_mat_lamiere = _materiale("MetalPlates013", 2.0)
	_mat_pericolo = _materiale("PaintedMetal016", 0.6)
	_mat_giallo = _materiale("PaintedMetal006", 1.0)
	_mat_giallo.albedo_texture = load("res://assets/ambienti_tecnici/texture/vernice_giallo_Color.jpg")
	_mat_pav = load("res://assets/fiume_lento/mat_cemento.tres")
	_corpo = StaticBody3D.new()
	_corpo.name = "Corridoi"
	add_child(_corpo)
	for c in COLLEZIONABILI:
		GameState.register_collectible(c[0], c[1])
	if a_richiesta and not Engine.has_meta(&"risalita_subito") and ResourceLoader.exists(CAMPIONI):
		_campioni = load(CAMPIONI).get_meta(&"materiali", [])
		for m in _campioni:
			(m as Material).get_rid()   # lo shader si crea adesso, non al primo uso
	_zona_personale()
	_scala_di_servizio()
	_scala_fiume()
	# le zone dove le stanze si vedono: il capannone, l'infermeria con i corridoi, e un margine
	_zone.append(AABB(Vector3(-64.0, Y - 2.0, 50.0), Vector3(58.5, 12.0, 71.0)))
	_zone.append(AABB(Vector3(-41.0, Y - 2.0, 36.5), Vector3(26.0, 11.0, 15.0)))
	_zone.append(AABB(Vector3(CORRIDOIO_FIUME_X, Y - 1.0, 46.0), Vector3(13.0, 7.0, 22.0)))
	# subito: senza richiesta, senza giocatore (strumenti), o ripartendo vicino alle stanze (un checkpoint
	# della strada nuova: l'istantanea si applica dopo, alle stanze già al loro posto)
	# (il giocatore qui non c'è ancora: viene dopo nella sala)
	if Engine.has_meta(&"risalita_subito"):
		a_richiesta = false
	var subito := not a_richiesta
	if not subito and GameState.is_restoring():
		var pos: Array = (GameState.snapshot.get("player", {}) as Dictionary).get("position", [])
		subito = pos.size() == 3 and _vicino(Vector3(pos[0], pos[1], pos[2]))
	if subito:
		_metti_stanze(load(SCENA_FIUME) as PackedScene, load(SCENA_INFERMERIA) as PackedScene, false)


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


## Un muro come quelli del raccordo: zoccolo di cemento alto 1 m sopra [param base], lamiere sopra. [param buco]:
## [centro nel mondo, mezzo lato] di un buco quadrato (per un oblò, ObloLei.buco()), o vuoto.
func _muro(size: Vector3, pos: Vector3, base: float, buco := []) -> void:
	var y0 := pos.y - size.y * 0.5
	var zc := minf(base + 1.0, y0 + size.y)
	if zc > y0 + 0.01:
		_box_bucato(Vector3(size.x, zc - y0, size.z), Vector3(pos.x, (y0 + zc) * 0.5, pos.z), _mat_cemento, buco)
	var y1 := y0 + size.y
	if y1 > zc + 0.01:
		_box_bucato(Vector3(size.x, y1 - zc, size.z), Vector3(pos.x, (zc + y1) * 0.5, pos.z), _mat_lamiere, buco)


## Un box di muro (sottile in x o in z) col buco quadrato [param buco] ([centro, mezzo lato], vedi [method _muro]):
## fino a quattro box intorno al buco, o il box intero se il buco non lo tocca.
func _box_bucato(size: Vector3, pos: Vector3, m: Material, buco: Array) -> void:
	if buco.is_empty():
		_box(size, pos, m)
		return
	var c: Vector3 = buco[0]
	var r: float = buco[1]
	var asse := 2 if size.x < size.z else 0          # l'asse lungo, orizzontale, del muro
	var lo := pos - size * 0.5
	var hi := pos + size * 0.5
	if buco.size() > 2:
		_box_bucato_tondo(size, pos, m, c, float(buco[2]), asse)
		return
	var b0 := Vector2(c[asse] - r, c.y - r)
	var b1 := Vector2(c[asse] + r, c.y + r)
	if b1.x <= lo[asse] or b0.x >= hi[asse] or b1.y <= lo.y or b0.y >= hi.y:
		_box(size, pos, m)
		return
	b0 = Vector2(maxf(b0.x, lo[asse]), maxf(b0.y, lo.y))
	b1 = Vector2(minf(b1.x, hi[asse]), minf(b1.y, hi.y))
	# [da, a lungo il muro, da, a in altezza]
	for q in [[lo[asse], b0.x, lo.y, hi.y], [b1.x, hi[asse], lo.y, hi.y], [b0.x, b1.x, lo.y, b0.y], [b0.x, b1.x, b1.y, hi.y]]:
		if q[1] - q[0] < 0.005 or q[3] - q[2] < 0.005:
			continue
		var s := size
		var p := pos
		s[asse] = q[1] - q[0]
		p[asse] = (q[0] + q[1]) * 0.5
		s.y = q[3] - q[2]
		p.y = (q[2] + q[3]) * 0.5
		_box(s, p, m)


## Un box di muro col buco tondo di raggio [param rt] centrato in [param c] (per un oblò senza piastra, scelta
## dell'utente del 25 ottobre: il muro arriva fino alla cornice d'ottone). Lo stesso muro (stesso materiale triplanare,
## stessi box): sopra e sotto il buco i box interi, nella fascia del buco strisce alte 4 cm a destra e a sinistra della
## corda (il gradino resta sotto la flangia d'ottone, larga 12 cm).
func _box_bucato_tondo(size: Vector3, pos: Vector3, m: Material, c: Vector3, rt: float, asse: int) -> void:
	var lo := pos - size * 0.5
	var hi := pos + size * 0.5
	if c[asse] + rt <= lo[asse] or c[asse] - rt >= hi[asse] or c.y + rt <= lo.y or c.y - rt >= hi.y:
		_box(size, pos, m)
		return
	# [da, a lungo il muro, da, a in altezza]
	var pezzi := []
	if c.y - rt > lo.y:
		pezzi.append([lo[asse], hi[asse], lo.y, minf(c.y - rt, hi.y)])
	if c.y + rt < hi.y:
		pezzi.append([lo[asse], hi[asse], maxf(c.y + rt, lo.y), hi.y])
	var passo := 0.04
	var y := maxf(c.y - rt, lo.y)
	var y_fine := minf(c.y + rt, hi.y)
	while y < y_fine - 0.001:
		var y2 := minf(y + passo, y_fine)
		# (la corda più larga della striscia: il punto della striscia più vicino al centro)
		var dy := 0.0 if (y <= c.y and y2 >= c.y) else minf(absf(y - c.y), absf(y2 - c.y))
		var mezza := sqrt(maxf(rt * rt - dy * dy, 0.0))
		pezzi.append([lo[asse], minf(c[asse] - mezza, hi[asse]), y, y2])
		pezzi.append([maxf(c[asse] + mezza, lo[asse]), hi[asse], y, y2])
		y = y2
	for q in pezzi:
		if q[1] - q[0] < 0.003 or q[3] - q[2] < 0.003:
			continue
		var s := size
		var p := pos
		s[asse] = q[1] - q[0]
		p[asse] = (q[0] + q[1]) * 0.5
		s.y = q[3] - q[2]
		p.y = (q[2] + q[3]) * 0.5
		_box(s, p, m)


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
## in [param muri] ("n" a -Z, "s" a +Z, "o" a -X, "e" a +X); vuoto: i due lati lungo l'asse più lungo. [param buchi]:
## per lato, un buco quadrato nel muro (vedi [method _muro]).
func _corridoio(lo: Vector3, hi: Vector3, alto := 2.6, muri := "", buchi := {}) -> void:
	var c := (lo + hi) * 0.5
	var s := hi - lo
	_box(Vector3(s.x, 0.2, s.z), Vector3(c.x, lo.y - 0.1, c.z), _mat_pav)
	if muri == "":
		muri = "ns" if s.x >= s.z else "oe"
	# il soffitto copre i muri fino alla loro faccia di fuori (quelli a nord e a sud sporgono di 20 cm anche ai
	# lati); dove non c'è muro finisce col corridoio (prima sporgeva di 20 cm anche lì, senza niente sotto)
	var ns := "n" in muri or "s" in muri
	var x0 := lo.x - (0.2 if ns or "o" in muri else 0.0)
	var x1 := hi.x + (0.2 if ns or "e" in muri else 0.0)
	var z0 := lo.z - (0.2 if "n" in muri else 0.0)
	var z1 := hi.z + (0.2 if "s" in muri else 0.0)
	_box(Vector3(x1 - x0, 0.2, z1 - z0), Vector3((x0 + x1) * 0.5, lo.y + alto + 0.1, (z0 + z1) * 0.5), _mat_cemento)
	if "n" in muri:
		_muro(Vector3(s.x + 0.4, alto, 0.2), Vector3(c.x, lo.y + alto * 0.5, lo.z - 0.1), lo.y, buchi.get("n", []))
	if "s" in muri:
		_muro(Vector3(s.x + 0.4, alto, 0.2), Vector3(c.x, lo.y + alto * 0.5, hi.z + 0.1), lo.y, buchi.get("s", []))
	if "o" in muri:
		_muro(Vector3(0.2, alto, s.z), Vector3(lo.x - 0.1, lo.y + alto * 0.5, c.z), lo.y, buchi.get("o", []))
	if "e" in muri:
		_muro(Vector3(0.2, alto, s.z), Vector3(hi.x + 0.1, lo.y + alto * 0.5, c.z), lo.y, buchi.get("e", []))


## [param pos]: 5 cm davanti al muro, all'altezza della lampada; la lampada si appoggia al muro con la staffa.
func _lampada_rossa(pos: Vector3, verso: Vector3) -> void:
	var n := Vector3(verso.x, 0.0, verso.z).normalized()
	var l := LampadaMuro.monta(self, pos - n * 0.05, verso)
	var o := OmniLight3D.new()
	o.position = l.position + verso.normalized() * 0.3
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
	# dalla faccia di fuori del muro sud dell'infermeria (z 48,1) a quella del muro ovest del capannone (z 50,7,
	# spesso 30 cm): prima il corridoio andava da 48 a 51 ed entrava di 10 e 30 cm nei due muri
	_corridoio(Vector3(x - 1.0, Y, CENTRO_INFERMERIA.z + I.L + 0.1), Vector3(x + 1.0, Y, CENTRO_FIUME.z + F.X0 - 0.3), 2.6, "",
			{"o": [OBLO_PERSONALE, ObloLei.PIASTRA * 0.5, FORO_OBLO]})
	# la soglia della porta del capannone: il pavimento anche nello spessore del suo muro (30 cm). Prima lì c'era una
	# fessura, e da dentro si vedeva sotto il pavimento, fino nella vasca dell'oblò (D7 del collaudo degli oblò); dalla
	# parte dell'infermeria il pavimento c'è già
	var soglia := CENTRO_FIUME.z + F.X0 - 0.3
	_box(Vector3(2.0, 0.2, 0.3), Vector3(x, Y - 0.1, soglia + 0.15), _mat_pav)
	# l'oblò nel muro ovest, fra infermeria e capannone: la vasca è stretta (2,56 m, spostata verso il capannone) e
	# sotto il pavimento dell'infermeria (1,8 m sotto il centro del vetro, 5 cm sotto la soletta, che arriva a y -5,65)
	# si allarga di 1,6 m verso sud, dove ci sono le punte dei tentacoli di lei e il fianco di lei quando si stacca
	# (a 2 m la sua pelle entrava di 6 mm nella parete). Lei sbircia dal bordo destro (a sud, verso l'infermeria): si vede entrando dalla porta
	# del capannone. Il corridoio è largo 2 m: "troppo vicino" è col naso sul vetro. Compare già mentre arrivi dal
	# capannone, col muro in mezzo.
	_oblo("ObloPersonale", OBLO_PERSONALE, Vector3.RIGHT, "sbircia", AABB(Vector3(-37.0, Y - 0.2, 48.1), Vector3(4.0, 3.0, 6.0)),
			{"vasca_larga": 2.56, "vasca_spostata": 0.2, "vasca_fonda": 5.6, "vasca_sotto": 7.0, "vasca_gradino": Vector2(1.6, -1.8),
			"vicino": 0.9, "lato_sbircia": 1.0})
	# le due porte sono nei muri del capannone e dell'infermeria: qui i muri di testa non servono
	_lampada_rossa(Vector3(x + 0.95, Y + 2.2, 49.5), Vector3(-1, -0.5, 0))


## La scala di servizio: dalla porta nord dell'infermeria un pianerottolo, poi verso est due rampe da
## 15 gradini (18 cm) con un pianerottolo in mezzo, fino alla quota della sala, e un corridoio dritto
## fino alla porta nel muro ovest di C3.
func _scala_di_servizio() -> void:
	var xp := CENTRO_INFERMERIA.x + I.PORTA_NORD           # la porta nord dell'infermeria
	var zn := CENTRO_INFERMERIA.z - I.L - 0.1               # la faccia di fuori del suo muro nord (spesso 10 cm)
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
	_corridoio(Vector3(x, 0.0, z0), Vector3(PORTA_C3.x - 0.15, 0.0, z1), 2.6, "", {"n": [OBLO_SERVIZIO, ObloLei.PIASTRA * 0.5, FORO_OBLO]})
	# l'oblò nel muro nord del tratto in piano, a sinistra salendo verso C3: lei a testa in giù, col corpo in alto
	# (la vasca sale 5,8 m sopra il centro); compare mentre sali le rampe
	_oblo("ObloServizio", OBLO_SERVIZIO, Vector3.BACK, "capovolta", AABB(Vector3(-40.0, Y - 0.2, 37.3), Vector3(24.0, 8.4, 4.3)),
			{"vasca_larga": 10.2, "vasca_spostata": -0.3, "vasca_fonda": 5.6, "vasca_sotto": 3.6, "vasca_sopra": 5.8})
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
	_corridoio(Vector3(xc, Y, z1), Vector3(xc + 2.0, Y, fine), 2.6, "es", {"e": [OBLO_FIUME, ObloLei.PIASTRA * 0.5, FORO_OBLO]})
	# l'oblò nel muro est, a destra andando verso il capannone, fra le due lampade rosse: lei schiacciata sul vetro;
	# compare mentre scendi la scala
	_oblo("ObloFiume", OBLO_FIUME, Vector3.LEFT, "schiacciata", AABB(Vector3(xc - 0.2, Y - 0.2, z0), Vector3(x_fondo - xc + 0.2, 3.0, fine - z0)),
			{"vasca_larga": 6.6, "vasca_fonda": 5.6, "vasca_sotto": 8.0})
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


## Un oblò con lei dietro il vetro (ObloLei): [param centro] sulla faccia del muro dalla parte del corridoio,
## [param normale] verso il corridoio; lei compare col giocatore nella [param zona]. [param opzioni]: le proprietà da
## cambiare (la vasca, la distanza "troppo vicino", il lato da cui sbircia).
func _oblo(nome: String, centro: Vector3, normale: Vector3, posa: String, zona: AABB, opzioni := {}) -> ObloLei:
	var o := ObloLei.new()
	o.name = nome
	o.posa = posa
	o.zona = zona
	# il muro del corridoio fino alla cornice d'ottone (niente piastra quadrata scura, scelta dell'utente del 25 ottobre):
	# il foro nel muro è tondo (vedi FORO_OBLO), l'oblò mette solo la flangia
	o.muro_col_foro_tondo = true
	for k in opzioni:
		o.set(k, opzioni[k])
	o.transform = Transform3D(Basis.looking_at(-normale, Vector3.UP), centro)
	add_child(o)
	return o


## Una rampa di [param n] gradini che sale verso est da [param lo] (angolo basso a ovest-nord):
## gradini visibili e una rampa liscia sotto per la collisione, i muri, il soffitto inclinato.
func _rampa(lo: Vector3, n: int) -> void:
	var lungo := n * PEDATA
	var su := n * ALZATA
	var zc := lo.z + SCALA_LARGA * 0.5
	for i in n:
		_box(Vector3(PEDATA, ALZATA * (i + 1), SCALA_LARGA), Vector3(lo.x + PEDATA * (i + 0.5), lo.y + ALZATA * (i + 1) * 0.5, zc), _mat_pav, false)
		# il bordo del gradino a strisce di pericolo, come le scale del raccordo
		_box(Vector3(0.06, 0.035, SCALA_LARGA), Vector3(lo.x + PEDATA * i + 0.03, lo.y + ALZATA * (i + 1) - 0.0165, zc), _mat_pericolo, false)
	# il corrimano giallo lungo il muro nord, 95 cm sopra i bordi dei gradini, con le staffe al muro
	# (un oggetto solo: il tubo passa nei collari delle staffe, e ogni staffa va dal collare al muro; gli anelli
	# del tubo cadono sui collari, a 1/6, 1/2 e 5/6)
	var ra := Vector3(lo.x, lo.y + ALZATA + 0.95, lo.z + SCALA_LARGA - 0.07)
	var rb := Vector3(lo.x + lungo - PEDATA, lo.y + su + 0.95, ra.z)
	var corrimano := Node3D.new()
	corrimano.name = "Corrimano"
	add_child(corrimano)
	var asse := Basis(Vector3.BACK, atan2(rb.y - ra.y, rb.x - ra.x) - PI * 0.5)
	var tubo := MeshInstance3D.new()
	tubo.name = "Tubo"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = ra.distance_to(rb)
	cm.radial_segments = 12
	cm.rings = 5
	tubo.mesh = cm
	tubo.material_override = _mat_giallo
	tubo.transform = Transform3D(asse, (ra + rb) * 0.5)
	corrimano.add_child(tubo)
	var collare := CylinderMesh.new()
	collare.top_radius = 0.028
	collare.bottom_radius = 0.028
	collare.height = 0.03
	collare.radial_segments = 12
	var braccio := BoxMesh.new()
	braccio.size = Vector3(0.03, 0.03, 0.06)
	for k in 3:
		var pk := ra.lerp(rb, (k + 0.5) / 3.0)
		for d in [[collare, Transform3D(asse, pk), "Collare"], [braccio, Transform3D(Basis(), pk + Vector3(0, 0, 0.04)), "Braccio"]]:
			var mi := MeshInstance3D.new()
			mi.name = "%s%d" % [d[2], k + 1]
			mi.mesh = d[0]
			mi.material_override = _mat_giallo
			mi.transform = d[1]
			corrimano.add_child(mi)
	# la rampa liscia (36 gradi circa): ci si sale camminando
	var ang := atan2(su, lungo)
	var l := sqrt(lungo * lungo + su * su)
	var f := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(l, 0.1, SCALA_LARGA)
	f.shape = s
	f.transform = Transform3D(Basis(Vector3.BACK, ang), Vector3(lo.x + lungo * 0.5, lo.y + su * 0.5 - 0.05 / cos(ang), zc))
	_corpo.add_child(f)
	# i muri dei lati finiscono 20 cm prima della cima: lì ci sono già i muri del pianerottolo di sopra (che sporgono di
	# 20 cm), con lo zoccolo di cemento alla loro quota. Arrivando fino in cima le facce erano le stesse, una di lamiera
	# e una di cemento, e lampeggiavano (z-fighting; riscontro dell'utente sulla v0.3.11, "subito oltre il nuovo
	# ingresso la texture del cemento si glitcha con il muro"). Sotto quei 20 cm c'è l'ultimo gradino.
	for z in [lo.z - 0.1, lo.z + SCALA_LARGA + 0.1]:
		_muro(Vector3(lungo - 0.2, su + 2.6, 0.2), Vector3(lo.x + (lungo - 0.2) * 0.5, lo.y + (su + 2.6) * 0.5, z), lo.y)
	var soff := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(l, 0.2, SCALA_LARGA + 0.4)
	soff.mesh = b
	soff.material_override = _mat_cemento
	soff.transform = Transform3D(Basis(Vector3.BACK, ang), Vector3(lo.x + lungo * 0.5, lo.y + su * 0.5 + 2.7, zc))
	add_child(soff)


# --- caricamento e visibilità ---------------------------------------------------------------------------

## Le stanze al loro posto, costruite subito. [param dopo]: a gioco avviato (non in _ready): i materiali si
## unificano come quelli della sala (UnificaMateriali) e gli oggetti riprendono il loro stato.
func _metti_stanze(scena_fiume: PackedScene, scena_infermeria: PackedScene, dopo: bool) -> void:
	if fiume or scena_fiume == null or scena_infermeria == null:
		return
	var f := scena_fiume.instantiate() as Node3D
	f.name = "Fiume"
	f.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), CENTRO_FIUME)
	# davanti ai corridoi, come quando si costruivano per prime in _ready
	add_child(f)
	move_child(f, 1)
	_metti_infermeria(scena_infermeria, f, dopo)


func _metti_infermeria(scena_infermeria: PackedScene, f: Node3D, dopo: bool) -> void:
	infermeria = scena_infermeria.instantiate() as Node3D
	infermeria.name = "Infermeria"
	infermeria.position = CENTRO_INFERMERIA
	add_child(infermeria)
	move_child(infermeria, f.get_index() + 1)
	fiume = f
	_tenuti.clear()
	AttesaZone.pronta(&"risalita")
	if dopo:
		UnificaMateriali.unifica(fiume)
		UnificaMateriali.unifica(infermeria)
		GameState.ripristina.call_deferred(fiume)
		GameState.ripristina.call_deferred(infermeria)
		_aggiorna_visibilita()


## Le stanze a gioco avviato, coi file già caricati dal thread: il capannone si costruisce a pezzi (nascosto e
## fermo), qualche millisecondo per fotogramma, poi l'infermeria (poca roba) e si mostrano.
func _costruisci_stanze(scena_fiume: PackedScene, scena_infermeria: PackedScene) -> void:
	if fiume or _fiume_nuovo:
		return
	var f := scena_fiume.instantiate() as Node3D
	f.name = "Fiume"
	f.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), CENTRO_FIUME)
	f.set(&"costruzione_a_pezzi", true)
	if _accelerata:
		f.call(&"accelera")
	f.visible = false
	f.process_mode = Node.PROCESS_MODE_DISABLED
	_fiume_nuovo = f
	GameState.in_costruzione(f)
	add_child(f)
	move_child(f, 1)
	await f.call(&"costruisci_a_pezzi")
	# (una ripartenza ha ricaricato la sala mentre si costruiva, o le stanze non servono più e si sono tolte)
	if not is_instance_valid(f) or f != _fiume_nuovo or not f.is_inside_tree():
		return
	# l'infermeria e i materiali delle due stanze ognuno in un fotogramma (tutto insieme erano 80 ms)
	await get_tree().process_frame
	if not is_instance_valid(f) or f != _fiume_nuovo or not f.is_inside_tree():
		return
	var inf := scena_infermeria.instantiate() as Node3D
	inf.name = "Infermeria"
	inf.position = CENTRO_INFERMERIA
	inf.visible = false
	inf.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.in_costruzione(inf)
	inf.set(&"costruzione_a_pezzi", true)
	add_child(inf)
	move_child(inf, f.get_index() + 1)
	# (anche l'infermeria un passo per fotogramma: tutta insieme erano 275 ms)
	await inf.call(&"costruisci_a_pezzi")
	if not is_instance_valid(f) or f != _fiume_nuovo or not f.is_inside_tree():
		if is_instance_valid(inf):
			inf.queue_free()
		return
	for n in [f, inf]:
		await get_tree().process_frame
		if not is_instance_valid(f) or f != _fiume_nuovo or not f.is_inside_tree():
			if is_instance_valid(inf):
				inf.queue_free()
			return
		UnificaMateriali.unifica(n)
	_fiume_nuovo = null
	fiume = f
	infermeria = inf
	_tenuti.clear()
	_accelerata = false
	AttesaZone.pronta(&"risalita")
	for n in [f, inf]:
		n.process_mode = Node.PROCESS_MODE_INHERIT
		GameState.ripristina.call_deferred(n)
	_aggiorna_visibilita()


## Le stanze via, con lo stato dei loro oggetti messo da parte in GameState.
func _togli_stanze() -> void:
	if is_instance_valid(_fiume_nuovo):
		remove_child(_fiume_nuovo)
		_fiume_nuovo.queue_free()
	_fiume_nuovo = null
	_tenuti.clear()
	if fiume == null:
		return
	for n in [fiume, infermeria]:
		if is_instance_valid(n):
			GameState.parcheggia(n)
			remove_child(n)
			n.queue_free()
	fiume = null
	infermeria = null
	AttesaZone.non_pronta(&"risalita")


## Distanza del punto dalle zone delle stanze (0 dentro).
func _distanza(p: Vector3) -> float:
	var d := INF
	for z in _zone:
		d = minf(d, p.clamp(z.position, z.end).distance_to(p))
	return d


## Il punto è dentro le zone delle stanze (con [constant DENTRO] di margine): lì devono esserci.
func _dentro(p: Vector3) -> bool:
	for z in _zone:
		if z.grow(DENTRO).has_point(p):
			return true
	return false


## Il punto è dove le stanze si disegnano (dentro le zone, con [constant VICINO] di margine).
func _vicino(p: Vector3) -> bool:
	for z in _zone:
		if z.grow(VICINO).has_point(p):
			return true
	return false


## Le stanze servono: col giocatore vicino, o dalla sala pompe al magazzino (gli ultimi checkpoint), o tornando
## indietro dopo.
func _serve(p: Vector3) -> bool:
	var ordine := int(GameState.snapshot.get("order", -1))
	return _vicino(p) or (ordine >= ORDINE_DA and (ordine < ORDINE_A or _distanza(p) < RITORNO))


func _process(_delta: float) -> void:
	var p: Node3D = GameState.player if GameState.player and is_instance_valid(GameState.player) else null
	if p == null or not a_richiesta:
		# senza giocatore (strumenti, scene di prova) o senza richiesta: le stanze ci sono sempre
		_carica_subito()
	elif not Game.uscendo:
		var pos := p.global_position
		var serve := _serve(pos)
		if fiume == null and serve:
			if _dentro(pos):
				_urgente()
			elif not _in_caricamento and _fiume_nuovo == null:
				_richiedi_tutto()
		elif fiume and not serve and _distanza(pos) > LONTANO:
			_togli_stanze()
		if _in_caricamento:
			_controlla_thread()
	_aggiorna_visibilita()


## Chiede al thread le due scene e i file che usano mentre si costruiscono.
func _richiedi_tutto() -> void:
	_richiesti = [SCENA_FIUME, SCENA_INFERMERIA]
	var elenco = JSON.parse_string(FileAccess.get_file_as_string(ELENCO_RISORSE)) if FileAccess.file_exists(ELENCO_RISORSE) else []
	for percorso in (elenco if elenco is Array else []):
		if String(percorso).begins_with("res://") and ResourceLoader.exists(percorso):
			_richiesti.append(percorso)
	_tenuti.clear()
	_in_caricamento = true
	for percorso in _richiesti:
		# (già chiesto da questa sala prima di una ripartenza: non si richiede)
		var stato := ResourceLoader.load_threaded_get_status(percorso)
		if stato != ResourceLoader.THREAD_LOAD_IN_PROGRESS and stato != ResourceLoader.THREAD_LOAD_LOADED:
			Game.carica_in_thread(percorso)


## Il caricamento nel thread: quando è finito tutto, le stanze si costruiscono (se servono ancora); quello che il
## thread non ha caricato lo carica la costruzione stessa.
func _controlla_thread() -> void:
	for percorso in _richiesti:
		if ResourceLoader.load_threaded_get_status(percorso) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
	_in_caricamento = false
	var scene: Array[PackedScene] = []
	for percorso in _richiesti:
		var r: Resource = null
		if ResourceLoader.load_threaded_get_status(percorso) == ResourceLoader.THREAD_LOAD_LOADED:
			r = ResourceLoader.load_threaded_get(percorso)
		if r == null:
			push_warning("Risalita: %s non caricato nel thread" % percorso)
		elif percorso == SCENA_FIUME or percorso == SCENA_INFERMERIA:
			scene.append(r as PackedScene)
		else:
			_tenuti.append(r)
	_richiesti.clear()
	var p: Node3D = GameState.player if GameState.player and is_instance_valid(GameState.player) else null
	if p and not _serve(p.global_position):
		_tenuti.clear()
		return
	if scene.size() == 2 and scene[0] and scene[1]:
		_costruisci_stanze(scene[0], scene[1])
	else:
		_carica_subito()


## Il giocatore è già dove le stanze si vedono e non sono pronte: niente blocchi (prima qui si aspettava il thread
## e si costruiva tutto in un fotogramma: 17 s nella misura del 25 ottobre). Il thread finisce da solo, la
## costruzione resta a pezzi ma più grandi; cosa si vede intanto lo decide AttesaZone.
func _urgente() -> void:
	if fiume:
		return
	AttesaZone.attendi(&"risalita")
	_accelerata = true
	if _fiume_nuovo:
		_fiume_nuovo.call(&"accelera")
	elif not _in_caricamento:
		_richiedi_tutto()


## Le stanze servono adesso: si aspetta il thread (se è partito) o si caricano qui, e si costruiscono subito
## (strumenti, prove, la ripartenza dietro lo schermo nero, o il thread fallito).
func _carica_subito() -> void:
	if fiume:
		return
	if _fiume_nuovo:
		# si stanno costruendo a pezzi: il resto a pezzi più grandi
		_fiume_nuovo.call(&"accelera")
		return
	var f: PackedScene
	var i: PackedScene
	if _in_caricamento:
		_in_caricamento = false
		for percorso in _richiesti:
			var r := ResourceLoader.load_threaded_get(percorso)
			if percorso == SCENA_FIUME:
				f = r as PackedScene
			elif percorso == SCENA_INFERMERIA:
				i = r as PackedScene
			elif r:
				_tenuti.append(r)
		_richiesti.clear()
	if f == null:
		f = load(SCENA_FIUME) as PackedScene
	if i == null:
		i = load(SCENA_INFERMERIA) as PackedScene
	_metti_stanze(f, i, true)


## Per gli strumenti e i test che vogliono le stanze subito, dovunque sia il giocatore.
func carica_subito() -> void:
	_carica_subito()


func _aggiorna_visibilita() -> void:
	var p: Node3D = GameState.player if GameState.player and is_instance_valid(GameState.player) else null
	var dentro := p == null or _vicino(p.global_position)
	if fiume and fiume.visible != dentro:
		fiume.visible = dentro
		infermeria.visible = dentro
