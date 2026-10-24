class_name SalaSottomarino
extends Node3D
## Il tunnel del viaggio sottomarino: l'inseguimento allungato dopo SB1 (scelte dell'utente del 24 ottobre, GDD
## "Il tunnel del viaggio sottomarino"). Oltre la porta di servizio in cima alla scaletta del bacino della sala
## delle condotte comincia un tunnel a volta di mosaico blu (l'aspetto B del fiume lento, "viaggio sottomarino",
## del 19 ottobre) con un canale basso nel mezzo e due banchine ai lati. Lei riemerge dalla presa d'acqua profonda
## in testa al tunnel e ti insegue fluttuando sopra il canale, a bocca spalancata; tu corri sulle banchine, passi
## da una all'altra saltando sui gommoni quando un ostacolo ti chiude la strada, ti accovacci nei passaggi bassi e
## la spruzzi in faccia per rallentarla. In fondo, il portello da sottomarino.
##
## La strada (la linea del canale, le quote, la sezione, gli ambienti) viene da tools/blender/sottomarino_strada.py,
## nel JSON [constant STRADA]: tutta la geometria del tunnel si costruisce qui, a pezzi, da quella linea.
## Coordinate: quelle del mondo (il tunnel sta sotto i -22 m, dove nel livello non c'è niente).

const DIR_FIUME := "res://assets/fiume_lento/"
const STRADA := "res://assets/ambiente/sottomarino/sottomarino_strada.json"
## Ogni quanti metri di strada un pezzo di tunnel (mesh e collisione a parte, per il culling).
const PEZZO := 24.0
## Il passo delle sezioni della geometria (m): la linea ha un punto ogni 0,5 m.
const PASSO_SEZIONE := 1.0
## La testa del tunnel: quanti metri prima della presa (s = 0) finisce, chiusa da un muro.
const TESTA := 4.5
## La porta del bacino (sul muro est della testa) e quanto è larga e alta.
const PORTA_LARGA := 1.5
const PORTA_ALTA := 2.2
## Dove sta la porta lungo la strada (m dalla presa): sul muro est della testa, davanti alla porta del bacino.
const PORTA_S := 2.0
## La presa d'acqua profonda in testa: il canale scende fino a qui (lei sale da lì sotto).
const PRESA_FONDO := -36.0
const GRADINO_LARGO := 0.4   # il gradino continuo lungo il bordo del canale
const GRADINO_SU := 0.45     # sopra il fondo (il pelo è a 0,5)
const GRADINO_R := 0.05      # lo spigolo arrotondato
const PRESA_FINO := 6.0
## L'approdo (scelta 11A dell'utente): nel muro di fondo la porta del portello sta in alto, a [constant SOGLIA] sopra
## le banchine, con l'oblò all'altezza degli occhi di lei che fluttua sopra il canale; davanti, il ballatoio profondo
## [constant BALLATOIO] con la scala dalla banchina sinistra. L'acqua resta al ginocchio fino in fondo (da lì si esce
## col gradino continuo).
const SOGLIA := 3.0
const BALLATOIO := 1.0
const PORTELLO_LARGO := 1.3
const PORTELLO_ALTO := 1.8
const PORTELLO_APERTO := 95.0
## L'oblò e il volantino sul battente (dalla soglia).
const OBLO_Y := 1.3
const OBLO_R := 0.2
const VOLANTINO_Y := 0.75
## Nel canale si va a guado, accovacciati a tanto (m/s; scelta del coordinatore del 24 ottobre; a piedi e di corsa
## vedi [member velocita_guado]). Il rallentamento lo fa il Player coi volumi d'acqua del canale.
const VELOCITA_GUADO_ACCOVACCIATO := 1.2
## Le gallerie di servizio (i passaggi bassi, scelta 4C dell'utente): dietro il muro, larghe [constant GALLERIA_LARGA]
## e alte [constant GALLERIA_ALTA] (ci si passa solo accovacciati), con le due bocche lunghe [constant GALLERIA_BOCCA].
const GALLERIA_ALTA := 1.25
const GALLERIA_LARGA := 1.5
const GALLERIA_BOCCA := 1.4

## Gli ostacoli lungo la strada (s, lungo, lato, tipo): a turno chiudono la banchina dove sei e passi all'altra
## saltando sui gommoni (scelta 2C dell'utente, con la sua nota); ognuno ha un motivo vero e una luce. Si entra a
## sinistra (la porta del bacino). Dove c'è una galleria di servizio, sotto il suo muro la banchina è crollata (a
## guado si passa, ma piano) e anche quella di fronte.
## - crollo: un pezzo di banchina caduto nel canale, con le lastre rotte nell'acqua;
## - carico: il carico del relitto caduto (casse impilate, il forziere, l'ancora appoggiata);
## - galleria: il passaggio basso dietro il muro;
## - cancello: il cancello di servizio chiuso con la catena e il lucchetto;
## - macerie: le lastre di mosaico cadute dalla volta, impilate contro il muro;
## - vetrina: la vetrina del diorama dell'approdo caduta di traverso sulla banchina.
var ostacoli: Array = [
	{"s": 74.0, "lungo": 8.0, "lato": -1.0, "tipo": "crollo"},
	{"s": 138.5, "lungo": 2.6, "lato": 1.0, "tipo": "carico"},
	{"s": 205.0, "lungo": 12.0, "lato": -1.0, "tipo": "galleria"},
	{"s": 203.6, "lungo": 14.8, "lato": 1.0, "tipo": "crollo"},
	{"s": 268.0, "lungo": 0.3, "lato": -1.0, "tipo": "cancello"},
	{"s": 348.0, "lungo": 3.2, "lato": 1.0, "tipo": "macerie"},
	{"s": 425.0, "lungo": 12.0, "lato": -1.0, "tipo": "galleria"},
	{"s": 423.6, "lungo": 14.8, "lato": 1.0, "tipo": "crollo"},
	{"s": 484.0, "lungo": 1.0, "lato": -1.0, "tipo": "vetrina"},
]
## Gli attraversamenti sui gommoni delle rapide (scelta 2C dell'utente, con la sua nota: "sei costretto a fare parkour
## sui galleggianti che stanno sul corso d'acqua per passare da un lato all'altro del canale"): prima di ogni ostacolo
## che chiude la banchina dove sei, da 2 a 4 gommoni sfalsati lungo il canale, con salti veri da bordo a bordo, più
## lunghi andando avanti. [s dell'ostacolo, salti: dalla banchina al primo gommone, fra un gommone e l'altro,
## dall'ultimo all'altra banchina]. Il salto vero del Player sul gommone arriva a circa 3,1 m camminando e 5,3 m
## correndo (tests/test_parkour_gommoni.gd): il più lungo qui, 2,4 m, lascia almeno 0,7 m camminando.
var attraversamenti: Array = [
	[74.0, [1.0, 1.4, 1.0]],
	[138.5, [1.2, 1.8, 1.2]],
	[268.0, [1.4, 1.8, 1.8, 1.4]],
	[348.0, [1.6, 2.2, 2.0, 1.6]],
	[484.0, [1.8, 2.4, 2.2, 2.4, 1.8]],
]
## L'ultimo gommone di un attraversamento sta almeno tanto prima dell'ostacolo (m, dal bordo del tubolare).
const ATTRAVERSAMENTO_MARGINE := 2.0
## I gommoni (s, scostamento dall'asse verso destra), dagli attraversamenti (vedi [method _disponi_gommoni]).
var gommoni: Array = []
## I gommoni costruiti: [nodo, corpo, s, scostamento, fase].
var _gommoni: Array = []
## Raggio dell'anello del tubolare, raggio del tubolare e quanto sta sotto il pelo la base del gommone.
const GOMMONE_R := 1.15
const GOMMONE_T := 0.32
const GOMMONE_SOTTO := 0.15
## La collisione del tubolare: spicchi e lati della sua sezione (dodecagono: la cima e le facce a 30 gradi si
## camminano, i fianchi no).
const GOMMONE_SPICCHI := 24
const GOMMONE_LATI := 12
## Le corde: agli anelli della parete più vicina, tanto prima e dopo il gommone lungo il canale (lontano dalle linee
## di salto, che vanno di traverso), e quanto sono più lunghe della distanza all'inizio (pendono di qualche cm).
const CORDA_LUNGO := 2.2
const CORDA_LASCO := 0.012

var dati := {}
var _asse: Array = []          ## [{s, pos, dir, ambiente}]
var _s: PackedFloat32Array
var piano := -30.0
var acqua := -30.42
var fondo := -30.92
var imposta := -25.82
var chiave := -22.42
var canale := 2.6
var banchina := 2.6
var muro := 5.2
var spessore := 0.5

var mat_mosaico: Material
var mat_graniglia: Material
var mat_acqua: Material

## Vero quando il tunnel è tutto costruito.
var costruita := false
var _coda: Array = []


func _ready() -> void:
	dati = JSON.parse_string(FileAccess.get_file_as_string(STRADA))
	_asse = dati["asse"]
	_s = PackedFloat32Array()
	for p in _asse:
		_s.append(float(p["s"]))
	var q: Dictionary = dati["quote"]
	piano = q["piano_banchine"]
	acqua = q["acqua"]
	fondo = q["fondo_canale"]
	imposta = q["imposta_volta"]
	chiave = q["chiave_volta"]
	var se: Dictionary = dati["sezione"]
	canale = se["mezza_larghezza_canale"]
	banchina = se["larghezza_banchina"]
	muro = se["asse_muro"]
	spessore = se["spessore_muri"]
	_disponi_gommoni()
	mat_mosaico = load(DIR_FIUME + "mat_mosaico_blu.tres")
	mat_graniglia = load(DIR_FIUME + "mat_graniglia.tres")
	mat_acqua = load(DIR_FIUME + "acqua_fiume.tres")


## Costruisce tutto subito (scene di prova, test).
func costruisci() -> void:
	for passo in _passi():
		(passo as Callable).call()
	costruita = true


## Costruisce un passo per volta, senza superare [param ms_per_fotogramma] millisecondi per fotogramma (mentre
## si è ancora nella sala delle condotte).
func costruisci_a_pezzi(ms_per_fotogramma := 6.0) -> void:
	var passi := _passi()
	var t0 := Time.get_ticks_usec()
	for passo in passi:
		if not is_inside_tree():
			return
		(passo as Callable).call()
		if (Time.get_ticks_usec() - t0) / 1000.0 > ms_per_fotogramma:
			await get_tree().process_frame
			t0 = Time.get_ticks_usec()
	costruita = true


func _passi() -> Array:
	var out: Array = []
	var lung := lunghezza()
	var s0 := -TESTA
	while s0 < lung - 0.01:
		var s1 := minf(s0 + PEZZO, lung)
		out.append(_pezzo.bind(s0, s1))
		s0 = s1
	out.append(_testa)
	out.append(_fine)
	out.append(_luci)
	for o in ostacoli:
		if o["tipo"] == "galleria":
			out.append(_galleria.bind(o))
		elif o["tipo"] != "crollo" or not _sotto_galleria(o):
			out.append(_ostacolo.bind(o))
	for g in gommoni:
		out.append(_gommone.bind(float(g[0]), float(g[1])))
	out.append(_parapetto_presa)
	out.append(_checkpoint)
	out.append(_lei_crea)
	return out


## Vero se il crollo [param o] è quello di fronte a una galleria (lì il motivo è la galleria stessa).
func _sotto_galleria(o: Dictionary) -> bool:
	for g in ostacoli:
		if g["tipo"] == "galleria" and absf(float(g["s"]) - float(o["s"])) < 3.0:
			return true
	return false


# --- la linea ------------------------------------------------------------------------------------------------------

func lunghezza() -> float:
	return _s[_s.size() - 1]


## Il punto dell'asse del canale a [param s] metri dalla presa (alla quota dell'acqua); prima della presa e dopo
## l'approdo la linea continua dritta.
func punto(s: float) -> Vector3:
	var n := _s.size()
	if s <= 0.0:
		return _pos(0) + direzione(0.0) * s
	if s >= _s[n - 1]:
		return _pos(n - 1) + direzione(_s[n - 1]) * (s - _s[n - 1])
	var i := _indice(s)
	var f := (s - _s[i]) / maxf(_s[i + 1] - _s[i], 1e-6)
	return _pos(i).lerp(_pos(i + 1), f)


## La direzione della strada (orizzontale, verso l'approdo) a [param s].
func direzione(s: float) -> Vector3:
	var i := clampi(_indice(clampf(s, 0.0, _s[_s.size() - 1])), 0, _s.size() - 2)
	var d: Array = _asse[i]["dir"]
	var e: Array = _asse[i + 1]["dir"]
	var f := clampf((s - _s[i]) / maxf(_s[i + 1] - _s[i], 1e-6), 0.0, 1.0)
	return Vector3(d[0], 0, d[2]).lerp(Vector3(e[0], 0, e[2]), f).normalized()


## La destra della strada (guardando verso l'approdo).
func destra(s: float) -> Vector3:
	return direzione(s).cross(Vector3.UP).normalized()


## L'ambiente (indice in dati["ambienti"]) a [param s].
func ambiente(s: float) -> int:
	var amb: Array = dati["ambienti"]
	for k in amb.size():
		if s < float(amb[k]["fino_a"]):
			return k
	return amb.size() - 1


## Il punto della strada più vicino a [param p] (in pianta): [s, distanza dall'asse con segno, a destra positiva].
func proietta(p: Vector3) -> Array:
	var best := INF
	var bs := 0.0
	var i := 0
	while i < _s.size() - 1:
		var a := _pos(i)
		var b := _pos(i + 1)
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(p.x - a.x, p.z - a.z)
		var f := clampf(ap.dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var d := (ap - ab * f).length_squared()
		if d < best:
			best = d
			bs = _s[i] + (_s[i + 1] - _s[i]) * f
		i += 1
	var lato := (p - punto(bs)).dot(destra(bs))
	return [bs, lato]


func _pos(i: int) -> Vector3:
	var a: Array = _asse[i]["pos"]
	return Vector3(a[0], a[1], a[2])


func _indice(s: float) -> int:
	var lo := 0
	var hi := _s.size() - 1
	while hi - lo > 1:
		var m := (lo + hi) >> 1
		if _s[m] <= s:
			lo = m
		else:
			hi = m
	return lo


# --- il guscio -----------------------------------------------------------------------------------------------------

## Com'è un lato del tunnel (lato -1 a sinistra, 1 a destra) a [param s]: "crollo" se lì la banchina è crollata nel
## canale (si passa solo a guado), e quanto è alta l'apertura nel muro (0: niente; la porta del bacino, le bocche
## delle gallerie di servizio).
func _lato(s: float, lato: float) -> Dictionary:
	var out := {"crollo": false, "apertura": 0.0}
	for o in ostacoli:
		if float(o["lato"]) == lato and o["tipo"] in ["crollo", "galleria"] and s > float(o["s"]) and s < float(o["s"]) + float(o["lungo"]):
			out["crollo"] = true
	for a in _aperture():
		if float(a[2]) == lato and s > float(a[0]) and s < float(a[1]):
			out["apertura"] = float(a[3])
	return out


## Le aperture nei muri: [da s, a s, lato, alta].
func _aperture() -> Array:
	var out: Array = [[PORTA_S - PORTA_LARGA * 0.5, PORTA_S + PORTA_LARGA * 0.5, -1.0, PORTA_ALTA]]
	for o in ostacoli:
		if o["tipo"] == "galleria":
			var s0: float = o["s"]
			var s1: float = s0 + float(o["lungo"])
			out.append([s0 - GALLERIA_BOCCA, s0, float(o["lato"]), GALLERIA_ALTA])
			out.append([s1, s1 + GALLERIA_BOCCA, float(o["lato"]), GALLERIA_ALTA])
	return out


## La sezione del tunnel fra [param s] e [param t] (com'è a metà): i pezzi della sezione in coordinate (di lato
## dall'asse, quota) alle due quote [param s] e [param t] uguali, col materiale e il verso in cui guardano. Il fondo
## del canale, le sue pareti, il piano delle banchine, i muri e la volta a mezza ellisse; dove la banchina è crollata
## il fondo arriva fino al muro.
func _profilo(s: float, m: float) -> Array:
	var f := fondo_a(s)
	var c := canale
	var mu := muro
	var sx := _lato(m, -1.0)
	var dx := _lato(m, 1.0)
	var out: Array = []
	# (ogni pezzo: [a, b, materiale, verso della faccia in coordinate (lato, su), tipo])
	var cg := c - GRADINO_LARGO
	var f0 := -mu if sx["crollo"] else -cg
	var f1 := mu if dx["crollo"] else cg
	out.append([Vector2(f0, f), Vector2(f1, f), "mosaico", Vector2(0, 1), "fondo"])
	if not sx["crollo"]:
		out.append([Vector2(-c, piano), Vector2(-c, fondo + GRADINO_SU), "mosaico", Vector2(1, 0), "parete"])
		_gradino(out, -1.0, f)
		out.append([Vector2(-mu, piano), Vector2(-c, piano), "graniglia", Vector2(0, 1), "banchina"])
	if not dx["crollo"]:
		out.append([Vector2(c, fondo + GRADINO_SU), Vector2(c, piano), "mosaico", Vector2(-1, 0), "parete"])
		_gradino(out, 1.0, f)
		out.append([Vector2(c, piano), Vector2(mu, piano), "graniglia", Vector2(0, 1), "banchina"])
	# il muro parte dal piano, dal fondo dove la banchina è crollata, dalla cima di un'apertura
	var base_sx: float = piano + float(sx["apertura"]) if float(sx["apertura"]) > 0.0 else (f if sx["crollo"] else piano)
	var base_dx: float = piano + float(dx["apertura"]) if float(dx["apertura"]) > 0.0 else (f if dx["crollo"] else piano)
	out.append([Vector2(-mu, imposta), Vector2(-mu, base_sx), "mosaico", Vector2(1, 0), "muro"])
	out.append([Vector2(mu, base_dx), Vector2(mu, imposta), "mosaico", Vector2(-1, 0), "muro"])
	var seg := 12
	for k in seg:
		var a0 := PI * float(k) / seg
		var a1 := PI * float(k + 1) / seg
		var p0 := Vector2(-cos(a0) * mu, imposta + sin(a0) * (chiave - imposta))
		var p1 := Vector2(-cos(a1) * mu, imposta + sin(a1) * (chiave - imposta))
		var mid := (p0 + p1) * 0.5
		out.append([p0, p1, "mosaico", (Vector2(0, imposta) - mid).normalized(), "volta"])
	return out


## Il gradino continuo lungo il bordo del canale, dal lato [param lato] (decisione del coordinatore con enigmi, 24
## ottobre: dall'acqua si esce sempre, con due saltelli): largo [constant GRADINO_LARGO], [constant GRADINO_SU]
## sopra il fondo (appena sotto il pelo), stesso mosaico, lo spigolo arrotondato. Scende fino a [param f] (nella
## presa il fondo è più basso).
func _gradino(out: Array, lato: float, f: float) -> void:
	var c := canale
	var g := fondo + GRADINO_SU
	var n := c - GRADINO_LARGO                  # il naso del gradino
	var rr := GRADINO_R
	var pts := [Vector2(c, g), Vector2(n + rr, g)]
	for k in range(1, 4):
		var a := PI * 0.5 * float(k) / 4.0
		pts.append(Vector2(n + rr - sin(a) * rr, g - rr + cos(a) * rr))
	pts.append(Vector2(n, g - rr))
	pts.append(Vector2(n, f))
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var tg := (b - a).normalized()
		var nr := Vector2(tg.y, -tg.x)          # verso l'acqua, per il lato destro
		if lato > 0.0:
			out.append([a, b, "mosaico", nr, "gradino"])
		else:
			out.append([Vector2(-a.x, a.y), Vector2(-b.x, b.y), "mosaico", Vector2(-nr.x, nr.y), "gradino"])


## Un pezzo di tunnel da [param s0] a [param s1]: mesh per materiale e collisione.
func _pezzo(s0: float, s1: float) -> void:
	var nodo := Node3D.new()
	nodo.name = "Tunnel_%03d" % int(s0 + TESTA)
	add_child(nodo)
	var st := {"mosaico": SurfaceTool.new(), "graniglia": SurfaceTool.new()}
	for k in st:
		(st[k] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	var facce := PackedVector3Array()
	var sez := _sezioni(s0, s1)
	for j in sez.size() - 1:
		var s: float = sez[j]
		var t: float = sez[j + 1]
		var m := (s + t) * 0.5
		var pa := punto(s)
		var pb := punto(t)
		var ra := destra(s)
		var rb := destra(t)
		var prof_a := _profilo(s, m)
		var prof_b := _profilo(t, m)
		for k in prof_a.size():
			var a: Array = prof_a[k]
			var b: Array = prof_b[k]
			var q := [_al(pa, ra, a[0]), _al(pa, ra, a[1]), _al(pb, rb, b[1]), _al(pb, rb, b[0])]
			var v: Vector2 = a[3]
			var verso := ra * v.x + Vector3.UP * v.y
			_quad(st[a[2]], q, verso)
			_facce_quad(facce, q)
			# il retro, spesso [member spessore]: muri e volta pieni (con una faccia sola l'illuminazione globale
			# passava attraverso e faceva macchie scure sulla volta)
			if a[4] == "muro" or a[4] == "volta":
				var vn := verso.normalized()
				_quad(st[a[2]], [q[0] - vn * spessore, q[1] - vn * spessore, q[2] - vn * spessore, q[3] - vn * spessore], -vn)
		# il bordo delle banchine verso il canale: la graniglia sporge di 4 cm sul canale, spessa 6 cm (sopra, davanti e
		# sotto, così da sopra non si vede il retro)
		for lato: float in [-1.0, 1.0]:
			if _lato(m, lato)["crollo"]:
				continue
			var x0 := lato * canale
			var x1 := lato * (canale - 0.04)
			var y1 := piano - 0.06
			var pezzi_bordo := [
				[[_al(pa, ra, Vector2(x0, piano)), _al(pb, rb, Vector2(x0, piano)), _al(pb, rb, Vector2(x1, piano)), _al(pa, ra, Vector2(x1, piano))], Vector3.UP],
				[[_al(pa, ra, Vector2(x1, piano)), _al(pb, rb, Vector2(x1, piano)), _al(pb, rb, Vector2(x1, y1)), _al(pa, ra, Vector2(x1, y1))], -ra * lato],
				[[_al(pa, ra, Vector2(x0, y1)), _al(pb, rb, Vector2(x0, y1)), _al(pb, rb, Vector2(x1, y1)), _al(pa, ra, Vector2(x1, y1))], Vector3.DOWN],
			]
			for pz in pezzi_bordo:
				_quad(st["graniglia"], pz[0], pz[1])
	# le teste della banchina dove comincia e finisce un crollo (la banchina tagliata, dal fondo al piano)
	for o in ostacoli:
		if not o["tipo"] in ["crollo", "galleria"]:
			continue
		for sc: float in [float(o["s"]), float(o["s"]) + float(o["lungo"])]:
			if sc < s0 or sc >= s1:
				continue
			var lato: float = o["lato"]
			var p := punto(sc)
			var r := destra(sc)
			var verso := direzione(sc) * (1.0 if sc == float(o["s"]) else -1.0)
			var q := [_al(p, r, Vector2(lato * canale, fondo)), _al(p, r, Vector2(lato * muro, fondo)),
					_al(p, r, Vector2(lato * muro, piano)), _al(p, r, Vector2(lato * canale, piano))]
			_quad(st["graniglia"], q, verso)
			_facce_quad(facce, q)
			# (e la testa del gradino continuo, tagliato col crollo)
			var g := fondo + GRADINO_SU
			var qg := [_al(p, r, Vector2(lato * (canale - GRADINO_LARGO), fondo)), _al(p, r, Vector2(lato * canale, fondo)),
					_al(p, r, Vector2(lato * canale, g)), _al(p, r, Vector2(lato * (canale - GRADINO_LARGO), g))]
			_quad(st["mosaico"], qg, verso)
			_facce_quad(facce, qg)
	if s0 <= PORTA_S and PORTA_S < s1:
		_passaggio_porta(st, facce)
	for k in st:
		var mi := MeshInstance3D.new()
		mi.name = k
		mi.mesh = (st[k] as SurfaceTool).commit()
		mi.material_override = mat_mosaico if k == "mosaico" else mat_graniglia
		nodo.add_child(mi)
	_corpo(nodo, facce)
	_acqua(nodo, s0, s1)


## Le quote lungo la strada delle sezioni di un pezzo: ogni [constant PASSO_SEZIONE] metri, più i bordi delle
## aperture e dei crolli.
func _sezioni(s0: float, s1: float) -> PackedFloat32Array:
	var bordi: Array = []
	for a in _aperture():
		bordi.append_array([float(a[0]), float(a[1])])
	for o in ostacoli:
		if o["tipo"] in ["crollo", "galleria"]:
			bordi.append_array([float(o["s"]), float(o["s"]) + float(o["lungo"])])
	var out: Array = []
	var s := s0
	while s < s1 - 0.001:
		out.append(s)
		s += PASSO_SEZIONE
	out.append(s1)
	for b in bordi:
		if b > s0 + 0.001 and b < s1 - 0.001:
			out.append(b)
	out.sort()
	var pulito := PackedFloat32Array()
	for v in out:
		if pulito.is_empty() or v - pulito[pulito.size() - 1] > 0.01:
			pulito.append(v)
	return pulito


## Il passaggio dalla porta del bacino (nel muro della sala delle condotte, x 40) al tunnel: pavimento, fianchi
## e soffitto, lunghi quanto lo spessore fra i due muri.
func _passaggio_porta(st: Dictionary, facce: PackedVector3Array) -> void:
	var p := punto(PORTA_S)
	var r := destra(PORTA_S)
	var d := direzione(PORTA_S)
	var a := _al(p, r, Vector2(-muro, 0.0))                 # sul muro del tunnel
	var verso_fuori := -r                                    # verso la sala delle condotte
	var lungo := 40.0 - a.x if absf(verso_fuori.x) > 0.5 else 0.8
	var b := a + verso_fuori * (lungo + 0.02)
	var h := d * PORTA_LARGA * 0.5
	var y0 := Vector3.UP * piano
	var y1 := Vector3.UP * (piano + PORTA_ALTA)
	var pezzi := [
		[[a - h + y0, b - h + y0, b + h + y0, a + h + y0], "graniglia", Vector3.UP],
		[[a - h + y1, a + h + y1, b + h + y1, b - h + y1], "mosaico", Vector3.DOWN],
		[[a - h + y0, a - h + y1, b - h + y1, b - h + y0], "mosaico", d],
		[[a + h + y0, b + h + y0, b + h + y1, a + h + y1], "mosaico", -d],
	]
	for pz in pezzi:
		_quad(st[pz[1]], pz[0], pz[2])
		_facce_quad(facce, pz[0])


## Il pelo dell'acqua del canale da [param s0] a [param s1] (una striscia col materiale del fiume) e i volumi
## d'acqua per il giocatore (passi, guado) e per lo zaino (si aspira dove si vuole, l'acqua non finisce).
## Niente WaterBody: con la testa fuori dall'acqua la vista resta quella normale.
func _acqua(nodo: Node3D, s0: float, s1: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sez := _sezioni(s0, s1)
	for j0 in sez.size() - 1:
		var s: float = sez[j0]
		var t: float = sez[j0 + 1]
		var mm := (s + t) * 0.5
		# dove la banchina è crollata l'acqua arriva al muro
		var wl := (muro if _lato(mm, -1.0)["crollo"] else canale) - 0.01
		var wr := (muro if _lato(mm, 1.0)["crollo"] else canale) - 0.01
		var pa := punto(s)
		var pb := punto(t)
		var ra := destra(s)
		var rb := destra(t)
		var q := [pa - ra * wl, pa + ra * wr, pb + rb * wr, pb - rb * wl]
		for j in 4:
			q[j].y = acqua
		var uv := [Vector2(0, s / 5.0), Vector2(1, s / 5.0), Vector2(1, t / 5.0), Vector2(0, t / 5.0)]
		var n: Vector3 = ((q[1] as Vector3) - q[0]).cross((q[3] as Vector3) - q[0])
		var ordine := [0, 2, 1, 0, 3, 2] if n.y > 0.0 else [0, 1, 2, 0, 2, 3]
		for idx in ordine:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[idx])
			st.add_vertex(q[idx])
	var mi := MeshInstance3D.new()
	mi.name = "Acqua"
	mi.mesh = st.commit()
	mi.material_override = mat_acqua
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nodo.add_child(mi)
	# i volumi: scatole lunghe 4 m lungo il canale, dal fondo al pelo
	var s2 := s0
	while s2 < s1 - 0.001:
		var t2 := minf(s2 + 4.0, s1)
		var m := (s2 + t2) * 0.5
		var c := punto(m)
		var fondo_qui := minf(fondo_a(s2), fondo_a(t2))
		var wl := muro if (_lato(s2 + 0.01, -1.0)["crollo"] or _lato(t2 - 0.01, -1.0)["crollo"]) else canale
		var wr := muro if (_lato(s2 + 0.01, 1.0)["crollo"] or _lato(t2 - 0.01, 1.0)["crollo"]) else canale
		var vol := WaterVolume.new()
		vol.name = "Canale_%d" % int(m)
		vol.velocita_guado = velocita_guado
		vol.velocita_guado_accovacciato = VELOCITA_GUADO_ACCOVACCIATO
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(wl + wr, acqua - fondo_qui, t2 - s2 + 0.3)
		cs.shape = b
		vol.add_child(cs)
		nodo.add_child(vol)
		var cc := c + destra(m) * (wr - wl) * 0.5
		vol.global_transform = Transform3D(Basis.looking_at(direzione(m), Vector3.UP), Vector3(cc.x, (acqua + fondo_qui) * 0.5, cc.z))
		s2 = t2


## La testa del tunnel: il muro di fondo dietro la presa, con la porta del bacino nel muro est.
func _testa() -> void:
	var nodo := Node3D.new()
	nodo.name = "Testa"
	add_child(nodo)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facce := PackedVector3Array()
	var s := -TESTA
	var p := punto(s)
	var r := destra(s)
	var d := direzione(s)
	# il muro di testa: chiude la sezione (dalla quota del fondo della presa alla volta), guarda verso l'approdo
	var pts := [Vector2(-muro, PRESA_FONDO), Vector2(muro, PRESA_FONDO), Vector2(muro, imposta)]
	var seg := 12
	for k in range(1, seg):
		var a := PI * float(k) / seg
		pts.append(Vector2(cos(a) * muro, imposta + sin(a) * (chiave - imposta)))
	pts.append(Vector2(-muro, imposta))
	var tri := Geometry2D.triangulate_polygon(PackedVector2Array(pts))
	for k in range(0, tri.size(), 3):
		var t := [_al(p, r, pts[tri[k]]), _al(p, r, pts[tri[k + 1]]), _al(p, r, pts[tri[k + 2]])]
		_tri(st, t, d)
		facce.append_array(PackedVector3Array(t))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat_mosaico
	nodo.add_child(mi)
	_corpo(nodo, facce)


## Il fondo del canale a [param s]: la presa profonda in testa (lei sale da lì), poi l'acqua al ginocchio.
func fondo_a(s: float) -> float:
	if s < PRESA_FINO:
		return lerpf(PRESA_FONDO, fondo, clampf((s + 0.5) / (PRESA_FINO + 0.5), 0.0, 1.0))
	return fondo


## La fine del tunnel: il muro di fondo con la porta del portello in alto (la soglia a [constant SOGLIA] sopra le
## banchine), il ballatoio davanti con la scala dalla banchina sinistra, la camera stagna dietro, il portello col
## volantino.
func _fine() -> void:
	var nodo := Node3D.new()
	nodo.name = "Approdo"
	add_child(nodo)
	var st := {"mosaico": SurfaceTool.new(), "graniglia": SurfaceTool.new()}
	for k in st:
		(st[k] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	var facce := PackedVector3Array()
	var L := lunghezza()
	var p := punto(L)
	var r := destra(L)
	var d := direzione(L)
	var sg := piano + SOGLIA
	var cima := sg + PORTELLO_ALTO
	var mz := PORTELLO_LARGO * 0.5
	# il muro di fondo: la sagoma della sezione (fondo, muri, volta) meno la porta. Tagliata in due a metà della porta,
	# così ogni metà ha la porta sul bordo (niente buchi da triangolare)
	var sagoma := [Vector2(-muro, fondo), Vector2(muro, fondo), Vector2(muro, imposta)]
	for k in range(1, 24):
		var a := PI * float(k) / 24
		sagoma.append(Vector2(cos(a) * muro, imposta + sin(a) * (chiave - imposta)))
	sagoma.append(Vector2(-muro, imposta))
	var porta := PackedVector2Array([Vector2(-mz, sg), Vector2(mz, sg), Vector2(mz, cima), Vector2(-mz, cima)])
	for meta: float in [-1.0, 1.0]:
		var mezza := PackedVector2Array([Vector2(0, fondo - 1.0), Vector2(meta * (muro + 1.0), fondo - 1.0),
				Vector2(meta * (muro + 1.0), chiave + 1.0), Vector2(0, chiave + 1.0)])
		for parte in Geometry2D.intersect_polygons(PackedVector2Array(sagoma), mezza):
			for poly in Geometry2D.clip_polygons(parte, porta):
				if Geometry2D.is_polygon_clockwise(poly) and poly.size() < 3:
					continue
				var tri := Geometry2D.triangulate_polygon(poly)
				for k in range(0, tri.size(), 3):
					var t := [_al(p, r, poly[tri[k]]), _al(p, r, poly[tri[k + 1]]), _al(p, r, poly[tri[k + 2]])]
					_tri(st["mosaico"], t, -d)
					facce.append_array(PackedVector3Array(t))
	# la camera stagna dietro il muro: pavimento alla soglia, soffitto, due fianchi e il fondo
	var cl := 3.0
	var ca := 2.5
	var cm := 1.4
	var c0 := p
	var c1 := p + d * cl
	var cam := [
		[[_al(c0, r, Vector2(-cm, sg)), _al(c1, r, Vector2(-cm, sg)), _al(c1, r, Vector2(cm, sg)), _al(c0, r, Vector2(cm, sg))], "graniglia", Vector3.UP],
		[[_al(c0, r, Vector2(-cm, sg + ca)), _al(c1, r, Vector2(-cm, sg + ca)), _al(c1, r, Vector2(cm, sg + ca)), _al(c0, r, Vector2(cm, sg + ca))], "mosaico", Vector3.DOWN],
		[[_al(c0, r, Vector2(-cm, sg)), _al(c1, r, Vector2(-cm, sg)), _al(c1, r, Vector2(-cm, sg + ca)), _al(c0, r, Vector2(-cm, sg + ca))], "mosaico", r],
		[[_al(c0, r, Vector2(cm, sg)), _al(c1, r, Vector2(cm, sg)), _al(c1, r, Vector2(cm, sg + ca)), _al(c0, r, Vector2(cm, sg + ca))], "mosaico", -r],
		[[_al(c1, r, Vector2(-cm, sg)), _al(c1, r, Vector2(cm, sg)), _al(c1, r, Vector2(cm, sg + ca)), _al(c1, r, Vector2(-cm, sg + ca))], "mosaico", -d],
		# (il muro dalla parte della camera, attorno alla porta)
		[[_al(c0, r, Vector2(-cm, sg)), _al(c0, r, Vector2(-mz, sg)), _al(c0, r, Vector2(-mz, sg + ca)), _al(c0, r, Vector2(-cm, sg + ca))], "mosaico", d],
		[[_al(c0, r, Vector2(mz, sg)), _al(c0, r, Vector2(cm, sg)), _al(c0, r, Vector2(cm, sg + ca)), _al(c0, r, Vector2(mz, sg + ca))], "mosaico", d],
		[[_al(c0, r, Vector2(-mz, cima)), _al(c0, r, Vector2(mz, cima)), _al(c0, r, Vector2(mz, sg + ca)), _al(c0, r, Vector2(-mz, sg + ca))], "mosaico", d],
	]
	for pz in cam:
		_quad(st[pz[1]], pz[0], pz[2])
		_facce_quad(facce, pz[0])
	# il ballatoio davanti al muro, dalla scala alla porta (spesso 20 cm), e la scala lungo il muro sinistro
	var b0 := p - d * BALLATOIO
	var bu0 := -muro
	var bu1 := mz + 0.2
	var ball := [
		[[_al(b0, r, Vector2(bu0, sg)), _al(p, r, Vector2(bu0, sg)), _al(p, r, Vector2(bu1, sg)), _al(b0, r, Vector2(bu1, sg))], Vector3.UP],
		[[_al(b0, r, Vector2(bu0, sg - 0.2)), _al(p, r, Vector2(bu0, sg - 0.2)), _al(p, r, Vector2(bu1, sg - 0.2)), _al(b0, r, Vector2(bu1, sg - 0.2))], Vector3.DOWN],
		[[_al(b0, r, Vector2(bu0, sg - 0.2)), _al(b0, r, Vector2(bu1, sg - 0.2)), _al(b0, r, Vector2(bu1, sg)), _al(b0, r, Vector2(bu0, sg))], -d],
		[[_al(b0, r, Vector2(bu1, sg - 0.2)), _al(p, r, Vector2(bu1, sg - 0.2)), _al(p, r, Vector2(bu1, sg)), _al(b0, r, Vector2(bu1, sg))], r],
	]
	for pz in ball:
		_quad(st["graniglia"], pz[0], pz[1])
		_facce_quad(facce, pz[0])
	var gradini := 12
	var alzata := SOGLIA / gradini
	for k in gradini:
		var sk := L - BALLATOIO - (gradini - k) * 0.32 + 0.16
		var pk := punto(sk)
		var rk := destra(sk)
		var alto := alzata * (k + 1)
		_scatola(st["graniglia"], facce, _al(pk, rk, Vector2(-muro + 0.5, piano + alto * 0.5)), rk, direzione(sk), Vector3(1.0, alto, 0.32))
	# il corrimano della scala e del ballatoio dalla parte del vuoto (la vasca): pali e tubo
	var corr := _mat_ferro()
	for k in range(0, gradini + 1, 2):
		var sk := L - BALLATOIO - (gradini - k) * 0.32
		var pk := punto(sk)
		var base := _al(pk, destra(sk), Vector2(-muro + 0.95, piano + alzata * float(k)))
		_palo(nodo, base, base + Vector3.UP * 1.0, 0.025, corr)
	var p_ball := [_al(b0, r, Vector2(-muro + 0.95, sg)), _al(b0, r, Vector2(-mz - 0.6, sg))]
	for q in p_ball:
		_palo(nodo, q, q + Vector3.UP * 1.0, 0.025, corr)
	_palo(nodo, p_ball[0] + Vector3.UP * 1.0, p_ball[1] + Vector3.UP * 1.0, 0.025, corr)
	var su0 := _al(punto(L - BALLATOIO - gradini * 0.32), destra(L - BALLATOIO - gradini * 0.32), Vector2(-muro + 0.95, piano + 1.0))
	_palo(nodo, su0, p_ball[0] + Vector3.UP * 1.0, 0.025, corr)
	for k in st:
		var mi := MeshInstance3D.new()
		mi.name = k
		mi.mesh = (st[k] as SurfaceTool).commit()
		mi.material_override = mat_mosaico if k == "mosaico" else mat_graniglia
		nodo.add_child(mi)
	_corpo(nodo, facce)
	_portello(nodo, p, r, d, sg)
	# le luci: la lampada sopra il portello dalla parte del tunnel, e una piccola nella camera sul volantino
	_lampada(nodo, L - BALLATOIO - 2.0, -1.0, sg + 2.2, 4.0)
	var lc := OmniLight3D.new()
	lc.light_color = Color(1.0, 0.86, 0.66)
	lc.light_energy = 1.6
	lc.omni_range = 4.0
	nodo.add_child(lc)
	lc.global_position = _al(p + d * 1.6, r, Vector2(0.0, sg + 2.2))


## Un palo (o un tubo) di ferro da [param a] a [param b].
func _palo(nodo: Node3D, a: Vector3, b: Vector3, raggio: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = raggio
	cm.bottom_radius = raggio
	cm.height = a.distance_to(b)
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = m
	nodo.add_child(mi)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.global_transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)


## Il portello da sottomarino nella porta in alto del muro di fondo: il battente d'acciaio con l'oblò (vetro vero:
## da dentro la vedi), aperto contro il muro dalla parte del tunnel; il volantino dalla parte della camera,
## illuminato. Dalla camera con E si chiude: il battente si chiude, il volantino gira (in senso orario, per
## serrare) restando attaccato al battente, e lei ci sbatte contro (vedi [method _finale]).
func _portello(nodo: Node3D, p: Vector3, r: Vector3, d: Vector3, sg: float) -> void:
	var mz := PORTELLO_LARGO * 0.5
	var acciaio := _mat("acciaio_portello", Color(0.32, 0.36, 0.38), 0.45, 0.8)
	# la cornice sul muro dalla parte del tunnel
	var f_st := SurfaceTool.new()
	f_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var f_facce := PackedVector3Array()
	var spor := 0.08
	for q in [[Vector2(0, sg + PORTELLO_ALTO + 0.08), Vector3(PORTELLO_LARGO + 0.32, 0.16, spor)],
			[Vector2(-mz - 0.08, sg + PORTELLO_ALTO * 0.5), Vector3(0.16, PORTELLO_ALTO, spor)],
			[Vector2(mz + 0.08, sg + PORTELLO_ALTO * 0.5), Vector3(0.16, PORTELLO_ALTO, spor)]]:
		var v: Vector2 = q[0]
		_scatola(f_st, f_facce, _al(p - d * spor * 0.5, r, v), r, d, q[1])
	var fm := MeshInstance3D.new()
	fm.mesh = f_st.commit()
	fm.material_override = acciaio
	nodo.add_child(fm)
	_corpo(nodo, f_facce)
	# il battente: un perno sul lato sinistro della porta; il battente gira attorno alla verticale del perno
	var perno := Node3D.new()
	perno.name = "PortelloPerno"
	nodo.add_child(perno)
	perno.global_transform = Transform3D(Basis(r, Vector3.UP, -d), _al(p, r, Vector2(-mz, sg)))
	# (il perno a sinistra della porta guardando dal tunnel: il battente si apre verso la camera, contro il suo
	# fianco sinistro, e non ingombra il ballatoio)
	var battente := CSGCombiner3D.new()
	battente.name = "Battente"
	battente.use_collision = true
	battente.collision_layer = Layers.WORLD
	perno.add_child(battente)
	var lastra := CSGBox3D.new()
	lastra.size = Vector3(PORTELLO_LARGO - 0.04, PORTELLO_ALTO - 0.04, 0.1)
	lastra.position = Vector3(mz, PORTELLO_ALTO * 0.5, 0.0)
	lastra.material = acciaio
	battente.add_child(lastra)
	var buco := CSGCylinder3D.new()
	buco.radius = OBLO_R
	buco.height = 0.3
	buco.sides = 24
	buco.operation = CSGShape3D.OPERATION_SUBTRACTION
	buco.rotation_degrees.x = 90
	buco.position = Vector3(mz, OBLO_Y, 0.0)
	battente.add_child(buco)
	var vetro := MeshInstance3D.new()
	var vm := CylinderMesh.new()
	vm.top_radius = OBLO_R
	vm.bottom_radius = OBLO_R
	vm.height = 0.02
	vm.radial_segments = 24
	vetro.mesh = vm
	vetro.material_override = _mat_vetro_oblo()
	vetro.rotation_degrees.x = 90
	vetro.position = Vector3(mz, OBLO_Y, 0.0)
	perno.add_child(vetro)
	for lato: float in [-1.0, 1.0]:
		var an := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = OBLO_R - 0.01
		tm.outer_radius = OBLO_R + 0.07
		an.mesh = tm
		an.material_override = _mat_ottone()
		an.rotation_degrees.x = 90
		an.position = Vector3(mz, OBLO_Y, lato * 0.055)
		perno.add_child(an)
	# il volantino dalla parte della camera (z negativo del perno: verso la camera), sotto l'oblò, illuminato
	var volantino := Node3D.new()
	volantino.name = "Volantino"
	volantino.position = Vector3(mz, VOLANTINO_Y, -0.11)
	perno.add_child(volantino)
	var ruota := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.22
	rm.outer_radius = 0.27
	ruota.mesh = rm
	ruota.material_override = _mat_volantino()
	ruota.rotation_degrees.x = 90
	volantino.add_child(ruota)
	for k in 4:
		var raggio := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.025, 0.46, 0.025)
		raggio.mesh = bm
		raggio.material_override = _mat_volantino()
		raggio.rotation_degrees.z = 45.0 * k
		volantino.add_child(raggio)
	var mozzo := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.05
	mm.bottom_radius = 0.05
	mm.height = 0.12
	mozzo.mesh = mm
	mozzo.material_override = acciaio
	mozzo.rotation_degrees.x = 90
	mozzo.position.z = 0.05
	volantino.add_child(mozzo)
	# aperto: il battente contro il muro dalla parte del tunnel
	perno.rotation_degrees.y += PORTELLO_APERTO
	_perno = perno
	_volantino = volantino
	_perno_chiuso = perno.global_transform.basis.rotated(Vector3.UP, deg_to_rad(-PORTELLO_APERTO))
	# l'interazione: nella camera, guardando la porta
	var usa := Interactable.new()
	usa.name = "ChiudiPortello"
	usa.prompt = "Chiudi"
	usa.one_shot = true
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(PORTELLO_LARGO, PORTELLO_ALTO, 0.6)
	cs.shape = bx
	usa.add_child(cs)
	nodo.add_child(usa)
	usa.global_transform = Transform3D(Basis(r, Vector3.UP, -d), _al(p + d * 0.35, r, Vector2(0.0, sg + PORTELLO_ALTO * 0.5)))
	usa.interacted.connect(func(_by): chiudi_portello())
	_usa_portello = usa


var _perno: Node3D
var _volantino: Node3D
var _perno_chiuso: Basis
var _usa_portello: Interactable
var finito := false
signal fine_demo


func _mat_vetro_oblo() -> StandardMaterial3D:
	if not _materiali.has("vetro_oblo"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.8, 0.85, 0.18)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiali["vetro_oblo"] = m
	return _materiali["vetro_oblo"]


## Il volantino illuminato: vernice rossa con un filo di luce (si trova subito al buio).
func _mat_volantino() -> StandardMaterial3D:
	return _mat("volantino", Color(0.75, 0.1, 0.08), 0.45, 0.3, Color(0.9, 0.15, 0.1), 0.6)


## Il giocatore nella camera stagna chiude il portello (scelta 11A): il battente si chiude, il volantino gira per
## serrarlo restando attaccato, poi lei ci sbatte contro con la faccia sull'oblò e la bocca spalancata; nero e
## "FINE DELLA DEMO" ([signal fine_demo]).
func chiudi_portello() -> void:
	if finito:
		return
	finito = true
	var tw := create_tween()
	var da := _perno.global_transform.basis
	tw.tween_method(func(k: float):
		_perno.global_transform.basis = da.slerp(_perno_chiuso, k), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Audio.suona(&"cancello_fine", _volantino.global_position, 0.0, 0.7))
	# il volantino: tre quarti di giro in senso orario visto da chi lo gira (dalla camera, che guarda lungo il +z del
	# perno: lì una rotazione positiva attorno a z si vede oraria)
	tw.tween_property(_volantino, "rotation:z", TAU * 0.75, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_finale)


## Lei sbatte contro il portello: arriva dal fondo della vasca dell'approdo e ci schiaccia la faccia sull'oblò.
func _finale() -> void:
	if lei:
		lei_stato = Lei.PRESA     # (ferma: la muove il finale)
		lei.visible = true
		var oblo := _perno.global_transform * Vector3(PORTELLO_LARGO * 0.5, OBLO_Y, -0.06)
		var d := direzione(lunghezza())
		var occhio_rel := (lei.get_eye_position() - lei.global_position) if lei.get_eye_position() != Vector3.ZERO else Vector3.UP * 3.4
		lei.global_transform.basis = Basis.looking_at(d, Vector3.UP, true)
		occhio_rel = lei.get_eye_position() - lei.global_position if lei.get_eye_position() != Vector3.ZERO else occhio_rel
		var arrivo := oblo - d * 0.35 - occhio_rel
		var partenza := arrivo - d * 5.0 - Vector3.UP * 2.0
		lei.global_position = partenza
		_anima_lei(&"inseguimento/presa", 0.1)
		lei.attacca(0.3, &"")
		var tw := create_tween()
		tw.tween_property(lei, "global_position", arrivo, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): Audio.suona(&"cancello_fine", oblo, 2.0, 0.6))
		tw.tween_interval(2.2)
		tw.tween_callback(_nero)
	else:
		_nero()


func _nero() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 80
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(fade)
	add_child(cl)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.2)
	tw.tween_callback(func(): fine_demo.emit())


## Le luci del tunnel: lampade a gabbia sui muri ogni 9 m, alternate, e oblò illuminati.
func _luci() -> void:
	var nodo := Node3D.new()
	nodo.name = "Luci"
	add_child(nodo)
	var s := 3.0
	var lato := 1.0
	while s < lunghezza():
		var p := punto(s)
		var r := destra(s)
		var muro_p := p + r * lato * (muro - 0.02)
		var l := (load("res://assets/enigma_acquari/lampada_gabbia.glb") as PackedScene).instantiate() as Node3D
		nodo.add_child(l)
		l.global_position = Vector3(muro_p.x, piano + 3.0, muro_p.z)
		l.look_at(l.global_position - r * lato * 2.0, Vector3.UP)
		l.rotate_object_local(Vector3.UP, PI)
		var g := l.find_child("globo", true, false) as MeshInstance3D
		if g:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1.0, 0.85, 0.55)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.7, 0.35)
			m.emission_energy_multiplier = 3.0
			g.material_override = m
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.76, 0.5)
		o.light_energy = 4.0
		o.omni_range = 12.0
		o.omni_attenuation = 1.3
		o.shadow_enabled = false
		nodo.add_child(o)
		o.global_position = Vector3(muro_p.x, piano + 3.0, muro_p.z) - r * lato * 0.4
		# fra una lampada e l'altra, sull'altro muro, un oblò col mare finto illuminato dietro
		_oblo(nodo, s + 4.5, -lato)
		s += 9.0
		lato = -lato


## Un oblò sul muro (dal lato [param lato]) a [param s]: anello d'ottone e vetro col mare finto illuminato dietro,
## come nel fiume B; fa luce da sé (niente luce in più).
func _oblo(nodo: Node3D, s: float, lato: float) -> void:
	if s > lunghezza() - 1.0:
		return
	var p := punto(s)
	var r := destra(s)
	var n := Node3D.new()
	n.name = "Oblo"
	nodo.add_child(n)
	var pos := Vector3(p.x, piano + 1.9, p.z) + r * lato * (muro - 0.005)
	n.global_position = pos
	n.look_at(pos - r * lato, Vector3.UP)
	var anello := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.36
	tm.outer_radius = 0.46
	anello.mesh = tm
	anello.rotation_degrees.x = 90
	anello.position.z = -0.04
	anello.material_override = _mat_ottone()
	n.add_child(anello)
	var vetro := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.37
	cm.bottom_radius = 0.37
	cm.height = 0.03
	vetro.mesh = cm
	vetro.rotation_degrees.x = 90
	vetro.position.z = -0.015
	vetro.material_override = _mat_oblo()
	n.add_child(vetro)


var _ottone: StandardMaterial3D
var _vetro_oblo: StandardMaterial3D


func _mat_ottone() -> StandardMaterial3D:
	if _ottone == null:
		_ottone = StandardMaterial3D.new()
		_ottone.albedo_color = Color(0.55, 0.42, 0.2)
		_ottone.metallic = 0.85
		_ottone.roughness = 0.35
	return _ottone


func _mat_oblo() -> StandardMaterial3D:
	if _vetro_oblo == null:
		_vetro_oblo = StandardMaterial3D.new()
		_vetro_oblo.albedo_color = Color(0.05, 0.25, 0.35)
		_vetro_oblo.emission_enabled = true
		_vetro_oblo.emission = Color(0.1, 0.45, 0.6)
		_vetro_oblo.emission_energy_multiplier = 2.2
		_vetro_oblo.roughness = 0.1
	return _vetro_oblo


# --- lei che insegue (scelte 6B, 7B, 8A, 9A dell'utente) -------------------------------------------------------------

signal lei_riemersa
signal lei_respinta
signal lei_morde
signal giocatore_preso

enum Lei { VIA, SALE, INSEGUE, RESPINTA, PRESA }

## Fra quanti metri (lungo la strada) lei ti sta dietro: sotto [member distanza_min] si avvicina (ti raggiunge se
## ti fermi, se vai a guado o se sbagli), sopra [member distanza_max] corre per rientrare. Sotto
## [member distanza_presa] ti prende; sotto [member distanza_morsi] morde a vuoto ogni 1-2 s.
@export var distanza_min := 8.0
@export var distanza_max := 18.0
@export var distanza_presa := 2.5
@export var distanza_morsi := 7.0
## La sua velocità normale (m/s): poco meno della corsa del giocatore (5,8), più del passo (3,4) e del guado (2).
@export var velocita_lei := 4.6
## Quanto corre per rientrare quando è più lontana di [member distanza_max].
@export var velocita_rincorsa := 7.5
## Mezzo secondo di getto in faccia (litri) la ferma per [member fermo_dopo_getto] secondi e la rimanda indietro di
## [member indietro_dopo_getto] metri; si ritrae strizzando l'occhio, rallenta e riparte.
@export var getto_in_faccia := 0.6
@export var fermo_dopo_getto := 2.0
@export var indietro_dopo_getto := 6.0
## Quanto sta sopra l'acqua l'origine del modello (fluttua intera sopra il canale; le pose provvisorie finché non
## arrivano le animazioni di mascotte).
@export var lei_sopra_acqua := 1.3
## A guado nel canale (velocità massima a piedi e di corsa, m/s): la danno i volumi d'acqua del canale
## (WaterVolume.velocita_guado), che il Player legge da solo.
@export var velocita_guado := 2.0
## I checkpoint lungo la strada (m): all'ingresso e poi lungo il tunnel. Si riparte col serbatoio pieno e lei a
## [member distanza_max] metri.
@export var checkpoint_s := PackedFloat32Array([6.0, 160.0, 300.0, 445.0])
## Il primo ordine dei checkpoint del tunnel (dopo quelli dell'inseguimento, che partono da 40).
@export var ordine_base := 60
## Appena parte (riemersa dalla presa, a pochi metri dalla porta), se il giocatore è più vicino di
## [member distanza_min] lei resta lì a mordere per questi secondi: il tempo di voltarsi e correre.
@export var vantaggio := 2.5
## Chi insegue (vuoto: il giocatore); i test lo cambiano.
var bersaglio: Node3D

var lei: MedusaAffacciata
var lei_stato := Lei.VIA
var lei_s := 0.0
var _lei_t := 0.0
var _getto_preso := 0.0
var _morso_tra := 1.5
var _s_bersaglio := 0.0
var _lei_testa: WaterHitbox
var checkpoint: Array[Checkpoint] = []


func _lei_crea() -> void:
	lei = MedusaAffacciata.new()
	lei.name = "Lei"
	lei.model = load("res://assets/models/medusa/medusa.glb")
	lei.bell_material = load("res://assets/models/medusa/medusa_campana.tres")
	lei.material_map = {
		"M_capelli": load("res://assets/models/medusa/medusa_capelli_bagnata.tres"),
		"M_ciocche": load("res://assets/models/medusa/medusa_ciocche_bagnata.tres"),
		"M_mani": load("res://assets/models/medusa/medusa_mani_bagnata.tres"),
		"M_occhio_bulbo": load("res://assets/models/medusa/medusa_occhio.tres"),
		"M_orbita": load("res://assets/models/medusa/medusa_orbita_bagnata.tres"),
		"M_pelle": load("res://assets/models/medusa/medusa_pelle_bagnata.tres"),
		"M_tentacoli": load("res://assets/models/medusa/medusa_tentacoli_bagnata.tres"),
	}
	lei.animazioni_inseguimento = true
	lei.animazione = &"inseguimento/incombe"
	lei.visible = false
	add_child(lei)
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.32, 0.62)
	luce.light_energy = 6.0
	luce.omni_range = 9.0
	luce.light_volumetric_fog_energy = 3.0
	luce.shadow_enabled = true
	luce.position = Vector3(0, 2.4, 0.9)
	luce.set_meta(&"risveglio_ignora", true)
	lei.add_child(luce)
	# il viso: un getto lì la ferma e la ricaccia indietro
	_lei_testa = WaterHitbox.new()
	_lei_testa.name = "Viso"
	var cs := CollisionShape3D.new()
	var sf := SphereShape3D.new()
	sf.radius = 0.9
	cs.shape = sf
	_lei_testa.add_child(cs)
	_lei_testa.position = Vector3(0, 3.4, 0.6)
	lei.add_child(_lei_testa)
	_lei_testa.water_hit.connect(func(litri: float, _p: Vector3, _d: Vector3):
		if lei_stato == Lei.INSEGUE or lei_stato == Lei.SALE:
			_getto_preso += litri
			if _getto_preso >= getto_in_faccia:
				respingi())


## I checkpoint del tunnel, lungo la strada ([member checkpoint_s]): un'area da banchina a banchina, la ripartenza
## sulla banchina sinistra (dove si arriva) girata verso l'approdo.
func _checkpoint() -> void:
	var i := 0
	for s in checkpoint_s:
		var a := Checkpoint.new()
		a.name = "Checkpoint_%d" % int(s)
		a.order = ordine_base + i
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(muro * 2.0, 2.4, 2.0)
		forma.shape = box
		a.add_child(forma)
		add_child(a)
		var p := punto(s)
		a.global_transform = Transform3D(Basis.looking_at(direzione(s), Vector3.UP), Vector3(p.x, piano + 1.2, p.z))
		var rip := Marker3D.new()
		rip.name = "Ripartenza"
		a.add_child(rip)
		rip.global_transform = Transform3D(Basis.looking_at(direzione(s), Vector3.UP),
				_al(p, destra(s), Vector2(-(canale + banchina * 0.5), piano)))
		a.spawn_point = rip
		checkpoint.append(a)
		i += 1


func _bersaglio() -> Node3D:
	if bersaglio:
		return bersaglio
	var p := GameState.player
	return p if p and is_instance_valid(p) else null


## Lei comincia a inseguire da [param s] (la riemersione dalla presa, o la ripartenza da un checkpoint: 18 m dietro).
func insegui_da(s: float) -> void:
	lei_s = s
	lei_stato = Lei.INSEGUE
	_lei_t = 0.0
	_getto_preso = 0.0
	lei.visible = true
	_anima_lei(&"inseguimento/incombe", 0.3)
	lei.attacca(0.7, &"")       # la bocca spalancata e l'occhio pieno di vene, per tutta la fase
	_metti_lei(0.0)


## Lei riemerge dalla presa in testa al tunnel (quando il giocatore la guarda dalla porta): sale dall'acqua e
## parte.
func riemergi() -> void:
	if lei_stato != Lei.VIA:
		return
	lei_stato = Lei.SALE
	_lei_t = 0.0
	lei_s = -1.0
	lei.visible = true
	_metti_lei(0.0)
	var durata := _anima_lei(&"inseguimento/sale_dall_acqua", 0.0)
	lei.attacca(0.7, &"")
	lei_riemersa.emit()
	get_tree().create_timer(minf(durata, 2.5), false).timeout.connect(func():
		if lei_stato == Lei.SALE:
			insegui_da(lei_s))


## Il getto in faccia: si ritrae strizzando l'occhio, si ferma [member fermo_dopo_getto] secondi tornando indietro
## di [member indietro_dopo_getto] metri, poi riparte.
func respingi() -> void:
	if lei_stato != Lei.INSEGUE and lei_stato != Lei.SALE:
		return
	lei_stato = Lei.RESPINTA
	_lei_t = 0.0
	_getto_preso = 0.0
	_anima_lei(&"inseguimento/respinta", 0.12)
	lei.chiudi_occhio(0.8)
	lei_respinta.emit()


func _prendi() -> void:
	if lei_stato == Lei.PRESA:
		return
	lei_stato = Lei.PRESA
	_anima_lei(&"inseguimento/presa", 0.12)
	lei.attacca(0.4, &"")
	lei.add_to_group(&"medusa_che_prende")
	giocatore_preso.emit()
	if bersaglio == null:
		GameState.kill_player(&"medusa")


func _anima_lei(nome: StringName, fondi: float) -> float:
	lei.animazione = nome
	var ap := lei.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(nome):
		return 1.0
	ap.play(nome, fondi)
	return ap.get_animation(nome).length


## Mette lei sull'asse del canale a [member lei_s], sopra l'acqua, girata verso chi insegue.
func _metti_lei(delta: float) -> void:
	var p := punto(lei_s)
	var pos := Vector3(p.x, acqua + lei_sopra_acqua, p.z)
	if lei_stato == Lei.SALE:
		# sale dalla presa: dal fondo fino alla sua quota in 1,6 s
		pos.y = lerpf(PRESA_FONDO, acqua + lei_sopra_acqua, clampf(_lei_t / 1.6, 0.0, 1.0))
	lei.global_position = pos
	var b := _bersaglio()
	var guarda := (b.global_position if b else pos + direzione(lei_s)) - pos
	guarda.y = 0.0
	if guarda.length() > 0.1:
		var voluta := Basis.looking_at(guarda.normalized(), Vector3.UP, true)
		lei.global_transform.basis = lei.global_transform.basis.slerp(voluta, clampf(delta * 4.0, 0.0, 1.0)) if delta > 0.0 else voluta


func _process(delta: float) -> void:
	if attivo and not _curva_passata and bersaglio == null and _s_bersaglio > PRIMA_CURVA:
		_curva_passata = true
		prima_curva_passata.emit()
	if attivo and lei and lei_stato == Lei.VIA and bersaglio == null:
		_guarda_la_presa()
	var pg := GameState.player
	if attivo and pg and is_instance_valid(pg) and bersaglio == null:
		pg.accovacciato_forzato = in_tubo(pg.global_position)
	if lei == null or lei_stato == Lei.VIA or lei_stato == Lei.PRESA:
		return
	_lei_t += delta
	var b := _bersaglio()
	if b:
		_s_bersaglio = _s_vicino(b.global_position, _s_bersaglio)
	var gap := _s_bersaglio - lei_s
	match lei_stato:
		Lei.SALE:
			pass
		Lei.INSEGUE:
			var v := velocita_rincorsa if gap > distanza_max else velocita_lei
			if gap < distanza_min and _lei_t < vantaggio:
				v = 0.0
			lei_s = minf(lei_s + v * delta, minf(_s_bersaglio - 0.5, lunghezza() - BALLATOIO - 1.5))
			gap = _s_bersaglio - lei_s
			if gap < distanza_morsi:
				_morso_tra -= delta
				if _morso_tra <= 0.0:
					_morso_tra = randf_range(1.0, 2.0)
					lei_morde.emit()
			if gap <= distanza_presa and b and _raggiungibile(b.global_position):
				_prendi()
		Lei.RESPINTA:
			# indietro di 6 m nel primo secondo, poi ferma fino a 2 s, poi riparte
			var f := clampf(_lei_t / 1.0, 0.0, 1.0)
			lei_s -= indietro_dopo_getto * delta * (1.0 if f < 1.0 else 0.0)
			lei_s = maxf(lei_s, -1.0)
			if _lei_t >= fermo_dopo_getto:
				lei_stato = Lei.INSEGUE
				_anima_lei(&"inseguimento/incombe", 0.3)
	_metti_lei(delta)


## Vero se [param piedi] sono in una galleria di servizio (dietro il muro, sotto il soffitto basso): lì si sta
## accovacciati per forza, come nei tubi delle condotte (lo usano il gioco e il controllo di posizionamento).
func in_tubo(piedi: Vector3) -> bool:
	for o in ostacoli:
		if o["tipo"] != "galleria":
			continue
		var s0: float = float(o["s"]) - GALLERIA_BOCCA
		var s1: float = float(o["s"]) + float(o["lungo"]) + GALLERIA_BOCCA
		var pr := proietta_vicino(piedi, (s0 + s1) * 0.5, (s1 - s0) * 0.5 + 2.0)
		var u := float(pr[1]) * float(o["lato"])
		if float(pr[0]) > s0 - 0.05 and float(pr[0]) < s1 + 0.05 and u > muro - 0.05 and absf(piedi.y - piano) < 0.6:
			return true
	return false


## Vero se lei arriva a [param pos]: dentro il tunnel (non nella galleria di servizio, dietro il muro).
func _raggiungibile(pos: Vector3) -> bool:
	var pr := proietta_vicino(pos, _s_bersaglio)
	return absf(float(pr[1])) < muro - 0.1


## Come [method proietta], ma cerca solo vicino a [param s_prima] (ogni fotogramma: la strada è lunga).
func proietta_vicino(p: Vector3, s_prima: float, raggio := 30.0) -> Array:
	var i0 := maxi(_indice(maxf(s_prima - raggio, 0.0)), 0)
	var i1 := mini(_indice(minf(s_prima + raggio, lunghezza())) + 1, _s.size() - 1)
	var best := INF
	var bs := s_prima
	for i in range(i0, i1):
		var a := _pos(i)
		var c := _pos(i + 1)
		var ab := Vector2(c.x - a.x, c.z - a.z)
		var ap := Vector2(p.x - a.x, p.z - a.z)
		var f := clampf(ap.dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var d := (ap - ab * f).length_squared()
		if d < best:
			best = d
			bs = _s[i] + (_s[i + 1] - _s[i]) * f
	return [bs, (p - punto(bs)).dot(destra(bs))]


func _s_vicino(p: Vector3, s_prima: float) -> float:
	return float(proietta_vicino(p, s_prima)[0])


# --- nel gioco: dopo SB1, la prima curva, le ripartenze --------------------------------------------------------------

## La prima curva del tunnel è passata (torre e condotte non si vedono più: si possono liberare).
signal prima_curva_passata

## Dopo quanti metri di tunnel la prima curva è alle spalle.
const PRIMA_CURVA := 55.0
## Lei riemerge quando la guardi dalla porta; se non la guardi, comunque quando hai fatto questi metri.
const RIEMERGE_COMUNQUE := 14.0

## Vero quando il tunnel è nel gioco (dopo SB1, o ripartendo da un suo checkpoint).
var attivo := false
var _curva_passata := false


## Il tunnel entra nel gioco: lei aspetta nella presa che il giocatore la guardi.
func attiva_tunnel() -> void:
	attivo = true


## Si riparte dal checkpoint a [param s]: il serbatoio pieno, lei [member distanza_max] metri dietro (dal primo
## checkpoint, all'ingresso, riemerge di nuovo dalla presa dopo 2 s).
func riparti_da(s: float) -> void:
	attivo = true
	_curva_passata = s > PRIMA_CURVA
	_s_bersaglio = s
	# (il serbatoio pieno quando il giocatore è rimesso al checkpoint: la ripartenza rimette anche lo zaino com'era)
	GameState.player_respawned.connect(func():
		var p := GameState.player
		if p and is_instance_valid(p) and p.water_pack:
			p.water_pack.tank_amount = p.water_pack.tank_capacity, CONNECT_ONE_SHOT)
	if s < 20.0:
		lei_stato = Lei.VIA
		get_tree().create_timer(2.0, false).timeout.connect(riemergi)
	else:
		insegui_da(s - distanza_max)


## Lei riemerge? Il giocatore è nel tunnel e guarda la presa (o è già andato avanti).
func _guarda_la_presa() -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p) or p.camera == null:
		return
	var pr := proietta_vicino(p.global_position, maxf(_s_bersaglio, 2.0), 40.0)
	_s_bersaglio = float(pr[0])
	if absf(float(pr[1])) > muro + 0.5:
		return
	if _s_bersaglio > RIEMERGE_COMUNQUE:
		riemergi()
		return
	var presa := punto(-1.0) + Vector3.UP * 2.0
	var verso := (presa - p.camera.global_position).normalized()
	if -p.camera.global_transform.basis.z.dot(verso) > 0.85:
		riemergi()


## La porta del bacino si chiude alle spalle (quando torre e condotte non ci sono più): il battente d'acciaio nel
## passaggio, chiuso.
func chiudi_porta_bacino() -> void:
	if find_child("PortaBacinoChiusa", true, false):
		return
	var p := punto(PORTA_S)
	var r := destra(PORTA_S)
	var d := direzione(PORTA_S)
	var porta := CSGBox3D.new()
	porta.name = "PortaBacinoChiusa"
	porta.size = Vector3(PORTA_LARGA, PORTA_ALTA, 0.06)
	porta.use_collision = true
	porta.collision_layer = Layers.WORLD
	porta.material = _mat("acciaio_portello", Color(0.32, 0.36, 0.38), 0.45, 0.8)
	add_child(porta)
	# a metà del passaggio fra il muro del tunnel e il muro della sala delle condotte
	var c := _al(p, r, Vector2(-muro - 0.35, piano + PORTA_ALTA * 0.5))
	porta.global_transform = Transform3D(Basis(d, Vector3.UP, -r), c)


## Il parapetto lungo la presa profonda (sui due bordi del canale, dalla testa a dove l'acqua torna al ginocchio):
## lì non si cade. Pali e due correnti di ferro.
func _parapetto_presa() -> void:
	var nodo := Node3D.new()
	nodo.name = "ParapettoPresa"
	add_child(nodo)
	var ferro := _mat_ferro()
	for lato: float in [-1.0, 1.0]:
		var s := -TESTA + 0.1
		var prima := Vector3.ZERO
		while s <= PRESA_FINO + 0.01:
			var q := _al(punto(s), destra(s), Vector2(lato * (canale + 0.06), piano))
			_palo(nodo, q, q + Vector3.UP * 1.05, 0.03, ferro)
			if prima != Vector3.ZERO:
				for h in [0.5, 1.0]:
					_palo(nodo, prima + Vector3.UP * h, q + Vector3.UP * h, 0.022, ferro)
			prima = q
			s += 1.75
	# (la collisione: un muretto invisibile alto 1,05 m lungo i due bordi, dove ci sono i pali)
	var facce := PackedVector3Array()
	for lato: float in [-1.0, 1.0]:
		var a := _al(punto(-TESTA), destra(-TESTA), Vector2(lato * (canale + 0.06), piano))
		var b := _al(punto(PRESA_FINO), destra(PRESA_FINO), Vector2(lato * (canale + 0.06), piano))
		_facce_quad(facce, [a, b, b + Vector3.UP * 1.05, a + Vector3.UP * 1.05])
	_corpo(nodo, facce)


# --- gli ostacoli (scelte 2C e 4C dell'utente) ------------------------------------------------------------------------

## La galleria di servizio [param o] (un passaggio basso, voluto dall'utente): dietro il muro dal lato della galleria,
## dalla bocca d'entrata (prima del crollo) a quella d'uscita (dopo). Pavimento, soffitto basso, muro esterno, le
## teste e gli stipiti delle bocche nello spessore del muro; dentro, due plafoniere a filo del soffitto. Sopra le
## bocche la fascia gialla e nera e una lampada: si vedono al buio.
func _galleria(o: Dictionary) -> void:
	var nodo := Node3D.new()
	nodo.name = "Galleria_%d" % int(o["s"])
	add_child(nodo)
	var st := {"mosaico": SurfaceTool.new(), "graniglia": SurfaceTool.new()}
	for k in st:
		(st[k] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	var facce := PackedVector3Array()
	var lato: float = o["lato"]
	var s0: float = float(o["s"]) - GALLERIA_BOCCA
	var s1: float = float(o["s"]) + float(o["lungo"]) + GALLERIA_BOCCA
	var u0 := muro                                  # il muro del tunnel (dentro)
	var u1 := muro + spessore                       # il retro del muro
	var u2 := u1 + GALLERIA_LARGA                   # il muro esterno della galleria
	var y0 := piano
	var y1 := piano + GALLERIA_ALTA
	var s := s0
	while s < s1 - 0.001:
		var t := minf(s + 0.5, s1)
		var pa := punto(s)
		var pb := punto(t)
		var ra := destra(s) * lato
		var rb := destra(t) * lato
		var pezzi := [
			[[_al(pa, ra, Vector2(u0, y0)), _al(pb, rb, Vector2(u0, y0)), _al(pb, rb, Vector2(u2, y0)), _al(pa, ra, Vector2(u2, y0))], "graniglia", Vector3.UP],
			[[_al(pa, ra, Vector2(u0, y1)), _al(pb, rb, Vector2(u0, y1)), _al(pb, rb, Vector2(u2, y1)), _al(pa, ra, Vector2(u2, y1))], "mosaico", Vector3.DOWN],
			[[_al(pa, ra, Vector2(u2, y0)), _al(pb, rb, Vector2(u2, y0)), _al(pb, rb, Vector2(u2, y1)), _al(pa, ra, Vector2(u2, y1))], "mosaico", -ra],
		]
		# fra le bocche il muro del tunnel, visto dalla galleria (il suo retro c'è già, sopra la galleria; qui sotto lo
		# fa questa faccia)
		var m := (s + t) * 0.5
		if m > float(o["s"]) and m < float(o["s"]) + float(o["lungo"]):
			pezzi.append([[_al(pa, ra, Vector2(u1, y0)), _al(pb, rb, Vector2(u1, y0)), _al(pb, rb, Vector2(u1, y1)), _al(pa, ra, Vector2(u1, y1))], "mosaico", ra])
		for pz in pezzi:
			_quad(st[pz[1]], pz[0], pz[2])
			_facce_quad(facce, pz[0])
		s = t
	# le teste della galleria (in fondo alle bocche) e gli stipiti nello spessore del muro
	for sc: float in [s0, s1]:
		var p := punto(sc)
		var r := destra(sc) * lato
		var verso := direzione(sc) * (1.0 if sc == s0 else -1.0)
		var q := [_al(p, r, Vector2(u0, y0)), _al(p, r, Vector2(u2, y0)), _al(p, r, Vector2(u2, y1)), _al(p, r, Vector2(u0, y1))]
		_quad(st["mosaico"], q, verso)
		_facce_quad(facce, q)
	for sc: float in [float(o["s"]), float(o["s"]) + float(o["lungo"])]:
		var p := punto(sc)
		var r := destra(sc) * lato
		var verso := direzione(sc) * (-1.0 if sc == float(o["s"]) else 1.0)
		var q := [_al(p, r, Vector2(u0, y0)), _al(p, r, Vector2(u1, y0)), _al(p, r, Vector2(u1, y1)), _al(p, r, Vector2(u0, y1))]
		_quad(st["mosaico"], q, verso)
		_facce_quad(facce, q)
	for k in st:
		var mi := MeshInstance3D.new()
		mi.name = k
		mi.mesh = (st[k] as SurfaceTool).commit()
		mi.material_override = mat_mosaico if k == "mosaico" else mat_graniglia
		nodo.add_child(mi)
	_corpo(nodo, facce)
	# la fascia gialla e nera sopra le bocche (sul muro, dal lato del tunnel) e una lampada a gabbia sopra ognuna
	for sb: float in [float(o["s"]) - GALLERIA_BOCCA * 0.5, float(o["s"]) + float(o["lungo"]) + GALLERIA_BOCCA * 0.5]:
		var p := punto(sb)
		var r := destra(sb) * lato
		var fascia := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(GALLERIA_BOCCA + 0.4, 0.3, 0.02)
		fascia.mesh = bm
		fascia.material_override = _mat_strisce()
		nodo.add_child(fascia)
		fascia.global_transform = Transform3D(Basis.looking_at(-r, Vector3.UP), _al(p, r, Vector2(u0 - 0.01, y1 + 0.17)))
		_lampada(nodo, sb, lato, y1 + 0.75, 3.0)
	# dentro: due plafoniere a filo del soffitto
	for f in [0.33, 0.66]:
		var sp: float = lerpf(float(o["s"]), float(o["s"]) + float(o["lungo"]), f)
		var p := punto(sp)
		var r := destra(sp) * lato
		var c := _al(p, r, Vector2((u1 + u2) * 0.5, y1 - 0.02))
		var pl := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.5, 0.04, 0.25)
		pl.mesh = pm
		pl.material_override = _mat_plafoniera()
		nodo.add_child(pl)
		pl.global_transform = Transform3D(Basis.looking_at(direzione(sp), Vector3.UP), c)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.86, 0.66)
		l.light_energy = 1.4
		l.omni_range = 4.0
		nodo.add_child(l)
		l.global_position = c - Vector3.UP * 0.15


## Un ostacolo su una banchina (vedi [member ostacoli]): la sua forma, la collisione e la luce.
func _ostacolo(o: Dictionary) -> void:
	var nodo := Node3D.new()
	nodo.name = "Ostacolo_%s_%d" % [o["tipo"], int(o["s"])]
	add_child(nodo)
	var lato: float = o["lato"]
	var s0: float = o["s"]
	var lungo: float = o["lungo"]
	var sm := s0 + lungo * 0.5
	var p := punto(sm)
	var r := destra(sm) * lato
	var d := direzione(sm)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facce := PackedVector3Array()
	var mat: Material = mat_graniglia
	match String(o["tipo"]):
		"crollo":
			# le lastre della banchina cadute nel canale: inclinate, appoggiate al fondo e al bordo rotto
			mat = mat_graniglia
			for k in 4:
				var f := (float(k) + 0.5) / 4.0
				var sk := s0 + lungo * f
				var pk := punto(sk)
				var rk := destra(sk) * lato
				var dk := direzione(sk)
				var giro := 0.35 + 0.15 * float(k % 2)
				var ax := (rk * cos(giro) + Vector3.UP * sin(giro)).normalized()
				var c := _al(pk, rk, Vector2(muro - 0.75 - 0.25 * float(k % 2), fondo + 0.42))
				_scatola_ruotata(st, facce, c, ax, dk, Vector3(1.5, 0.22, lungo / 4.0 - 0.1))
		"carico":
			# il carico del relitto caduto sulla banchina: due colonne di casse a filo (le grandi sotto), il davanti dritto
			# alto 1,6 m (non ci si sale), il forziere sopra e l'ancora appoggiata al muro dietro
			mat = _mat_cassa()
			var uw := muro - 0.62
			var uc := canale + 0.62
			var largo_w := 1.2
			var largo_c := 1.2
			var lato_s := lungo
			_scatola(st, facce, _al(p, r, Vector2(uw, piano + 0.45)), r, d, Vector3(largo_w, 0.9, lato_s))
			_scatola(st, facce, _al(p, r, Vector2(uw, piano + 0.9 + 0.35)), r, d, Vector3(largo_w, 0.7, lato_s))
			_scatola(st, facce, _al(p, r, Vector2(uc, piano + 0.4)), r, d, Vector3(largo_c, 0.8, lato_s))
			_scatola(st, facce, _al(p, r, Vector2(uc, piano + 0.8 + 0.375)), r, d, Vector3(largo_c, 0.75, lato_s))
			_modello(nodo, "forziere", _al(p + d * 0.2, r, Vector2(uc, piano + 1.55)), -d, 1.0)
			var an := _modello(nodo, "ancora", _al(p + d * (lato_s * 0.5 + 0.2), r, Vector2(muro - 0.14, piano)), r, 1.25)
			an.rotate_object_local(Vector3.RIGHT, deg_to_rad(-6.0))
			_collisione_modello(an)
		"cancello":
			_cancello(nodo, st, facce, s0, lato)
			mat = _mat_ferro()
		"macerie":
			# un pezzo di volta caduto: il lastrone in piedi di traverso sulla banchina (alto 1,9 m, appena inclinato) e
			# dietro le lastre più piccole ammucchiate contro il muro, le grandi sotto
			mat = mat_mosaico
			var ax := (d * cos(1.42) - Vector3.UP * sin(1.42)).normalized()
			_scatola_ruotata(st, facce, _al(p - d * (lungo * 0.5 - 0.25), r, Vector2((canale + muro) * 0.5, piano + 0.95)), ax, r,
					Vector3(1.9, 0.3, banchina - 0.08))
			for q in [[muro - 0.7, 0.15, 1.3, 0.3, 0.25], [canale + 0.8, 0.12, 1.5, 0.24, 0.3], [muro - 0.6, 0.42, 1.1, 0.24, 0.45],
					[canale + 0.9, 0.36, 1.2, 0.24, 0.5], [muro - 0.55, 0.68, 0.9, 0.24, 0.6], [canale + 1.1, 0.6, 1.0, 0.24, 0.65]]:
				var c := _al(p + d * (float(q[4]) * lungo - lungo * 0.5 + 0.3), r, Vector2(float(q[0]), piano + float(q[1])))
				_scatola(st, facce, c, r, d, Vector3(float(q[2]), float(q[3]), 1.0))
			var ax2 := (r * cos(1.35) + Vector3.UP * sin(1.35)).normalized()
			_scatola_ruotata(st, facce, _al(p + d * 0.6, r, Vector2(muro - 0.28, piano + 0.9 + 0.65)), ax2, d, Vector3(1.3, 0.2, 1.0))
		"vetrina":
			# la vetrina del diorama dell'approdo caduta di traverso sulla banchina: dal bordo del canale al muro, alta
			# 1,6 m. La cornice di metallo, il fondo di sabbia e dentro un corallo; il vetro scuro (il diorama è spento)
			mat = _mat_ferro()
			var u0 := canale + 0.08
			var u1 := muro - 0.04
			var uc := (u0 + u1) * 0.5
			var lw := u1 - u0
			var h := 1.6
			for y in [0.03, h - 0.03]:
				for z in [-0.5, 0.5]:
					_scatola(st, facce, _al(p + d * z, r, Vector2(uc, piano + y)), r, d, Vector3(lw, 0.06, 0.06))
			for u in [u0 + 0.03, u1 - 0.03]:
				for z in [-0.5, 0.5]:
					_scatola(st, facce, _al(p + d * z, r, Vector2(u, piano + h * 0.5)), r, d, Vector3(0.06, h, 0.06))
				_scatola(st, facce, _al(p, r, Vector2(u, piano + 0.03)), r, d, Vector3(0.06, 0.06, 1.0))
				_scatola(st, facce, _al(p, r, Vector2(u, piano + h - 0.03)), r, d, Vector3(0.06, 0.06, 1.0))
			var vetro := MeshInstance3D.new()
			var vb := BoxMesh.new()
			vb.size = Vector3(lw - 0.06, h - 0.06, 0.94)
			vetro.mesh = vb
			vetro.material_override = _mat_vetro()
			nodo.add_child(vetro)
			vetro.global_transform = Transform3D(Basis(r, Vector3.UP, r.cross(Vector3.UP)), _al(p, r, Vector2(uc, piano + h * 0.5)))
			var cv := _mat("sabbia", Color(0.62, 0.55, 0.4), 0.95)
			var sabbia := MeshInstance3D.new()
			var sbm := BoxMesh.new()
			sbm.size = Vector3(lw - 0.12, 0.18, 0.86)
			sabbia.mesh = sbm
			sabbia.material_override = cv
			nodo.add_child(sabbia)
			sabbia.global_transform = Transform3D(Basis(r, Vector3.UP, r.cross(Vector3.UP)), _al(p, r, Vector2(uc, piano + 0.15)))
			_modello(nodo, "corallo", _al(p, r, Vector2(uc, piano + 0.24)), d, 1.0)
			# (il vetro chiude la vetrina anche per chi la urta: la collisione è la scatola intera)
			_scatola_solo_collisione(facce, _al(p, r, Vector2(uc, piano + h * 0.5)), r, d, Vector3(lw, h, 1.0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	nodo.add_child(mi)
	_corpo(nodo, facce)
	# la luce: una lampada a gabbia sul muro sopra l'ostacolo (si vede al buio da lontano)
	_lampada(nodo, sm, lato, piano + 3.1, 4.0)


## Il cancello di servizio chiuso col lucchetto, di traverso sulla banchina da [param lato] a [param s]: due pali
## (uno contro il muro, l'altro sul bordo del canale), la cornice, le sbarre, la catena col lucchetto.
func _cancello(nodo: Node3D, st: SurfaceTool, facce: PackedVector3Array, s: float, lato: float) -> void:
	var p := punto(s)
	var r := destra(s) * lato
	var d := direzione(s)
	var a := canale + 0.12
	var b := muro - 0.04
	var alto := 2.3
	for u in [a, b]:
		_scatola(st, facce, _al(p, r, Vector2(u, piano + alto * 0.5)), r, d, Vector3(0.08, alto, 0.08))
	for y in [0.15, alto - 0.1, alto * 0.5]:
		_scatola(st, facce, _al(p, r, Vector2((a + b) * 0.5, piano + y)), r, d, Vector3(b - a, 0.05, 0.05))
	var n := 14
	for k in n:
		var u := lerpf(a + 0.1, b - 0.1, float(k) / (n - 1))
		_scatola(st, facce, _al(p, r, Vector2(u, piano + alto * 0.5)), r, d, Vector3(0.025, alto - 0.3, 0.025))
	# la catena attorno al palo sul bordo e al cancello, col lucchetto
	var c := _al(p, r, Vector2(a + 0.18, piano + 1.1))
	for k in 5:
		var anello := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.025
		tm.outer_radius = 0.045
		anello.mesh = tm
		anello.material_override = _mat_ferro()
		nodo.add_child(anello)
		anello.global_position = c + Vector3.UP * (0.06 * float(k) - 0.12) - r * 0.09
		anello.global_transform.basis = Basis(d if k % 2 == 0 else r, PI * 0.5)
	var lucchetto := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.09, 0.11, 0.04)
	lucchetto.mesh = lb
	lucchetto.material_override = _mat_ottone()
	nodo.add_child(lucchetto)
	lucchetto.global_position = c - Vector3.UP * 0.2 - r * 0.09


## Dove vanno i gommoni di ogni attraversamento ([member attraversamenti]): si parte dal lato dell'ostacolo e si
## arriva a quello di fronte; il primo gommone sta al salto giusto dalla banchina di partenza, l'ultimo da quella di
## arrivo, quelli in mezzo in fila fra i due; lungo il canale sono sfalsati quanto serve perché fra un tubolare e
## l'altro ci sia il salto voluto. L'ultimo finisce [constant ATTRAVERSAMENTO_MARGINE] m prima dell'ostacolo.
func _disponi_gommoni() -> void:
	gommoni = []
	var rg := GOMMONE_R + GOMMONE_T
	for att in attraversamenti:
		var s_ost: float = att[0]
		var salti: Array = att[1]
		var da := 1.0
		for o in ostacoli:
			if absf(float(o["s"]) - s_ost) < 0.01:
				da = float(o["lato"])
		var n := salti.size() - 1
		var lat0 := da * (canale - rg - float(salti[0]))
		var lat1 := -da * (canale - rg - float(salti[n]))
		var lats: Array = []
		for k in n:
			lats.append(lerpf(lat0, lat1, float(k) / maxf(n - 1, 1)))
		var lungo: Array = [0.0]
		for k in range(1, n):
			var dl: float = float(lats[k]) - float(lats[k - 1])
			var c := 2.0 * rg + float(salti[k])
			lungo.append(float(lungo[k - 1]) + sqrt(maxf(c * c - dl * dl, 0.0)))
		var s_ultimo := s_ost - ATTRAVERSAMENTO_MARGINE - rg
		for k in n:
			gommoni.append([s_ultimo - float(lungo[n - 1]) + float(lungo[k]), lats[k]])


## Un gommone tondo delle rapide (sei posti) a [param s], scostato di [param off] dall'asse, che galleggia nel canale
## e dondola appena (chi ci sta sopra viene portato: AnimatableBody3D con sync_to_physics); legato con due corde ad
## anelli nella parete del canale più vicina, prima e dopo lungo il canale. La collisione segue la gomma: il tubolare
## a spicchi (ci si cammina sopra), il fondo e i sedili; dal fondo si risale sul tubolare saltando.
func _gommone(s: float, off: float) -> void:
	var p := punto(s)
	var r := destra(s)
	var d := direzione(s)
	# (tutti sotto "Gommoni": il controllo di posizionamento li guarda a parte, fermi in tre istanti del dondolio)
	var gruppo := get_node_or_null(^"Gommoni")
	if gruppo == null:
		gruppo = Node3D.new()
		gruppo.name = "Gommoni"
		add_child(gruppo)
	var nodo := Node3D.new()
	nodo.name = "Gommone_%d" % int(s)
	gruppo.add_child(nodo)
	var centro := Vector3(p.x, acqua - GOMMONE_SOTTO, p.z) + r * off
	var corpo := AnimatableBody3D.new()
	corpo.name = "Gommone"
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	corpo.sync_to_physics = true
	corpo.set_meta(&"superficie", &"gomma")
	nodo.add_child(corpo)
	var giro := float(int(s * 13.0) % 60) * 0.1
	# (la posa di partenza la si tiene a parte: con sync_to_physics il corpo la prende al passo della fisica)
	var posa0 := Transform3D(Basis.looking_at(d, Vector3.UP).rotated(Vector3.UP, giro), centro)
	corpo.global_transform = posa0
	_collisione_gommone(corpo)
	var colori := [Color(0.95, 0.42, 0.12), Color(0.2, 0.62, 0.3), Color(0.95, 0.78, 0.15)]
	var gomma := StandardMaterial3D.new()
	gomma.albedo_color = colori[int(s) % 3]
	gomma.roughness = 0.55
	var nera := StandardMaterial3D.new()
	nera.albedo_color = Color(0.06, 0.06, 0.07)
	nera.roughness = 0.7
	var tubo := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = GOMMONE_R - GOMMONE_T
	tm.outer_radius = GOMMONE_R + GOMMONE_T
	tm.rings = 48
	tm.ring_segments = 14
	tubo.mesh = tm
	tubo.material_override = gomma
	tubo.position = Vector3.UP * GOMMONE_T
	corpo.add_child(tubo)
	var disco := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = GOMMONE_R
	dm.bottom_radius = GOMMONE_R
	dm.height = 0.06
	disco.mesh = dm
	disco.material_override = nera
	disco.position = Vector3.UP * 0.03
	corpo.add_child(disco)
	for k in 6:
		var a := TAU * float(k) / 6.0
		var sedile := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.84, 0.36, 0.26)
		sedile.mesh = sb
		sedile.material_override = gomma
		corpo.add_child(sedile)
		sedile.transform = Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * 0.55 + Vector3.UP * 0.22)
	# le sei maniglie sul fianco del tubolare (anelli di gomma nera, come nel modello delle rapide)
	var maniglie: Array = []
	for k in 6:
		var a := TAU * float(k) / 6.0 + PI / 6.0
		var m := Vector3(cos(a), 0.0, sin(a))
		var q := m * (GOMMONE_R + GOMMONE_T * 0.9) + Vector3.UP * GOMMONE_T * 1.2
		var man := MeshInstance3D.new()
		var mm := TorusMesh.new()
		mm.inner_radius = 0.07
		mm.outer_radius = 0.105
		mm.rings = 12
		mm.ring_segments = 6
		man.mesh = mm
		man.material_override = nera
		corpo.add_child(man)
		# l'anello sta di piatto contro il tubolare, girato lungo il fianco
		man.transform = Transform3D(Basis(Vector3.UP, m, Vector3.UP.cross(m)), q + m * 0.02)
		maniglie.append(q + m * 0.11)
	# le corde: dalle due maniglie più vicine agli anelli della parete più vicina, prima e dopo lungo il canale
	var lato := 1.0 if off >= 0.0 else -1.0
	var corde: Array = []
	var usate := {}
	for k: float in [-1.0, 1.0]:
		var sa := s + k * CORDA_LUNGO
		var pa := punto(sa)
		var ra := destra(sa)
		# la piastra sul muro, e l'anello che ne esce di piatto, girato lungo il canale: la corda passa nell'anello
		var muro_q := _al(pa, ra, Vector2(lato * canale, acqua + 0.3))
		var dentro := -ra * lato
		var piastra := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.14, 0.14, 0.02)
		piastra.mesh = pm
		piastra.material_override = _mat_ferro()
		nodo.add_child(piastra)
		piastra.global_transform = Transform3D(Basis.looking_at(dentro, Vector3.UP), muro_q + dentro * 0.01)
		var attacco := MeshInstance3D.new()
		var am := TorusMesh.new()
		am.inner_radius = 0.035
		am.outer_radius = 0.06
		attacco.mesh = am
		attacco.material_override = _mat_ferro()
		nodo.add_child(attacco)
		var da := direzione(sa)
		# (l'anello tocca la piastra col bordo; la corda passa nel suo foro, dalla parte del canale)
		attacco.global_transform = Transform3D(Basis(dentro, da, dentro.cross(da)), muro_q + dentro * 0.08)
		var anello := muro_q + dentro * 0.11
		var best := -1
		for j in maniglie.size():
			if usate.has(j):
				continue
			if best < 0 or (posa0 * (maniglie[j] as Vector3)).distance_to(anello) < (posa0 * (maniglie[best] as Vector3)).distance_to(anello):
				best = j
		usate[best] = true
		var corda := MeshInstance3D.new()
		corda.name = "Corda"
		corda.mesh = ImmediateMesh.new()
		corda.material_override = _mat_corda()
		corda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nodo.add_child(corda)
		var lunga := (posa0 * (maniglie[best] as Vector3)).distance_to(anello) * (1.0 + CORDA_LASCO)
		corde.append({"mesh": corda, "anello": anello, "maniglia": maniglie[best], "lunga": lunga})
	_gommoni.append({"nodo": nodo, "corpo": corpo, "centro": centro, "base": posa0.basis,
			"fase": float(int(s * 7.0) % 10) * 0.6, "corde": corde})
	_aggiorna_gommone(_gommoni[_gommoni.size() - 1], 0.0)


## La collisione di un gommone, nel suo spazio: il tubolare come anello di spicchi convessi a sezione di dodecagono
## (circoscritto: la gomma tocca le facce, niente sta sospeso sopra), il fondo e i sedili come nel disegno.
func _collisione_gommone(corpo: AnimatableBody3D) -> void:
	var rr := GOMMONE_T / cos(PI / GOMMONE_LATI)
	for k in GOMMONE_SPICCHI:
		var punti := PackedVector3Array()
		for a in [TAU * k / GOMMONE_SPICCHI, TAU * (k + 1) / GOMMONE_SPICCHI]:
			var m := Vector3(cos(a), 0.0, sin(a))
			for j in GOMMONE_LATI:
				var b := TAU * (j + 0.5) / GOMMONE_LATI
				punti.append(m * (GOMMONE_R + rr * cos(b)) + Vector3.UP * (GOMMONE_T + rr * sin(b)))
		var forma := ConvexPolygonShape3D.new()
		forma.points = punti
		var cs := CollisionShape3D.new()
		cs.name = "Tubolare%d" % k
		cs.shape = forma
		corpo.add_child(cs)
	var fondo := CylinderShape3D.new()
	fondo.radius = GOMMONE_R - GOMMONE_T * 0.5
	fondo.height = 0.06
	var cf := CollisionShape3D.new()
	cf.name = "Fondo"
	cf.shape = fondo
	cf.position = Vector3.UP * 0.03
	corpo.add_child(cf)
	for k in 6:
		var a := TAU * float(k) / 6.0
		var sb := BoxShape3D.new()
		sb.size = Vector3(0.84, 0.36, 0.26)
		var cs := CollisionShape3D.new()
		cs.name = "Sedile%d" % k
		cs.shape = sb
		cs.transform = Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * 0.55 + Vector3.UP * 0.22)
		corpo.add_child(cs)


var _tempo_gommoni := 0.0


func _physics_process(delta: float) -> void:
	_tempo_gommoni += delta
	for g in _gommoni:
		_aggiorna_gommone(g, _tempo_gommoni)


## Ferma i gommoni all'istante [param t] del dondolio (controllo di posizionamento, scatti, test).
func ferma_gommoni(t: float) -> void:
	_tempo_gommoni = t
	for g in _gommoni:
		_aggiorna_gommone(g, t)


## Il dondolio di un gommone al tempo [param t] (pochi centimetri, si atterra sicuri) e le sue corde, che lo seguono.
func posa_gommone(g: Dictionary, t: float) -> Transform3D:
	var f: float = g["fase"]
	var su := 0.02 * sin(t * 1.3 + f)
	var giro := 0.025 * sin(t * 0.7 + f)
	var rollio := deg_to_rad(1.2) * sin(t * 0.9 + f * 1.7)
	return Transform3D((g["base"] as Basis) * Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, rollio), (g["centro"] as Vector3) + Vector3.UP * su)


func _aggiorna_gommone(g: Dictionary, t: float) -> void:
	var corpo: AnimatableBody3D = g["corpo"]
	var posa := posa_gommone(g, t)
	corpo.global_transform = posa
	# (con sync_to_physics il corpo prende la posa al passo della fisica: le corde seguono quella nuova da subito,
	# anche coi gommoni fermati per il controllo di posizionamento e gli scatti)
	corpo.set_meta(&"posa", posa)
	for c in g["corde"]:
		_corda(c["mesh"], punti_corda(corpo, c))


## I punti di una corda fra la sua maniglia (dove sta ora il gommone) e l'anello: una parabola con la freccia che
## viene dal lasco (più il gommone si avvicina all'anello, più pende).
func punti_corda(corpo: Node3D, c: Dictionary, n := 10) -> PackedVector3Array:
	var posa: Transform3D = corpo.get_meta(&"posa", corpo.global_transform)
	var a: Vector3 = posa * (c["maniglia"] as Vector3)
	var b: Vector3 = c["anello"]
	var dd := a.distance_to(b)
	var freccia := sqrt(maxf(0.0, 3.0 * dd * (float(c["lunga"]) - dd) / 8.0))
	var out := PackedVector3Array()
	for k in n + 1:
		var f := float(k) / n
		out.append(a.lerp(b, f) + Vector3.DOWN * freccia * 4.0 * f * (1.0 - f))
	return out


## Una corda morbida per i punti [param pts], fatta di nastri.
func _corda(mi: MeshInstance3D, pts: PackedVector3Array) -> void:
	var im := mi.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 0.018
	for k in range(1, pts.size()):
		var prev := pts[k - 1]
		var q := pts[k]
		var dir := (q - prev).normalized()
		var lat := dir.cross(Vector3.UP).normalized() * r
		var su := lat.cross(dir).normalized() * r
		for o in [[lat, su], [su, -lat], [-lat, -su], [-su, lat]]:
			var v0: Vector3 = o[0]
			var v1: Vector3 = o[1]
			for v in [prev + v0, q + v0, q + v1, prev + v0, q + v1, prev + v1]:
				im.surface_set_normal(((v - prev) - dir * (v - prev).dot(dir)).normalized())
				im.surface_add_vertex(v)
	im.surface_end()


## Un modello Meshy del fiume (assets/fiume_lento) a [param pos], girato verso [param verso], scalato.
func _modello(nodo: Node3D, nome: String, pos: Vector3, verso: Vector3, scala: float) -> Node3D:
	var n := (load(DIR_FIUME + nome + ".glb") as PackedScene).instantiate() as Node3D
	nodo.add_child(n)
	n.global_transform = Transform3D(Basis.looking_at(verso, Vector3.UP).scaled(Vector3.ONE * scala), pos)
	return n


## La collisione di un modello: per ogni sua mesh la forma convessa (si sbatte contro la sua sagoma, non contro una
## scatola invisibile più grande).
func _collisione_modello(n: Node3D) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "Collisione"
	corpo.collision_layer = Layers.WORLD
	n.add_child(corpo)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var cs := CollisionShape3D.new()
		cs.shape = m.mesh.create_convex_shape(true, true)
		corpo.add_child(cs)
		cs.global_transform = m.global_transform


## Abbassa o alza [param n] finché il suo punto più basso sta a [param quota] (poggia).
func _appoggia(n: Node3D, quota: float) -> void:
	var basso := INF
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := m.global_transform
		for v in m.mesh.get_faces():
			basso = minf(basso, (xf * v).y)
	if basso < INF:
		n.global_position.y += quota - basso


## Una lampada a gabbia sul muro dal lato [param lato] a [param s], alla quota [param y], con la sua luce.
func _lampada(nodo: Node3D, s: float, lato: float, y: float, energia: float) -> void:
	var p := punto(s)
	var r := destra(s) * lato
	var muro_p := _al(p, r, Vector2(muro - 0.02, y))
	var l := (load("res://assets/enigma_acquari/lampada_gabbia.glb") as PackedScene).instantiate() as Node3D
	nodo.add_child(l)
	l.global_position = muro_p
	l.look_at(muro_p - r * 2.0, Vector3.UP)
	l.rotate_object_local(Vector3.UP, PI)
	var g := l.find_child("globo", true, false) as MeshInstance3D
	if g:
		g.material_override = _mat_globo()
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.76, 0.5)
	o.light_energy = energia
	o.omni_range = 10.0
	o.omni_attenuation = 1.3
	nodo.add_child(o)
	o.global_position = muro_p - r * 0.4


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


func _mat_ferro() -> StandardMaterial3D:
	return _mat("ferro", Color(0.22, 0.23, 0.24), 0.5, 0.75)


func _mat_vetro() -> StandardMaterial3D:
	if not _materiali.has("vetro"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.08, 0.2, 0.22, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.08
		m.metallic_specular = 0.8
		_materiali["vetro"] = m
	return _materiali["vetro"]


func _mat_cassa() -> StandardMaterial3D:
	return _mat("cassa", Color(0.36, 0.25, 0.15), 0.85)


func _mat_corda() -> StandardMaterial3D:
	return _mat("corda", Color(0.62, 0.55, 0.4), 0.9)


func _mat_globo() -> StandardMaterial3D:
	return _mat("globo", Color(1.0, 0.85, 0.55), 0.4, 0.0, Color(1.0, 0.7, 0.35), 3.0)


func _mat_plafoniera() -> StandardMaterial3D:
	return _mat("plafoniera", Color(1.0, 0.95, 0.85), 0.4, 0.0, Color(1.0, 0.86, 0.66), 2.0)


## La fascia a strisce gialle e nere (pericolo: si passa accovacciati).
func _mat_strisce() -> StandardMaterial3D:
	if not _materiali.has("strisce"):
		var img := Image.create(64, 8, false, Image.FORMAT_RGB8)
		for x in 64:
			for y in 8:
				img.set_pixel(x, y, Color(0.95, 0.75, 0.1) if int((x + y) / 8) % 2 == 0 else Color(0.05, 0.05, 0.05))
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.roughness = 0.6
		_materiali["strisce"] = m
	return _materiali["strisce"]


## Solo la collisione di una scatola (centro, asse x lungo [param ax], asse z lungo [param az], misure).
func _scatola_solo_collisione(f: PackedVector3Array, c: Vector3, ax: Vector3, az: Vector3, misure: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_scatola(st, f, c, ax, az, misure)


## Una scatola con l'asse x lungo [param ax] (non per forza orizzontale) e l'asse z lungo [param az].
func _scatola_ruotata(st: SurfaceTool, f: PackedVector3Array, c: Vector3, ax: Vector3, az: Vector3, misure: Vector3) -> void:
	var x := ax.normalized()
	var z := (az - x * az.dot(x)).normalized()
	var y := z.cross(x).normalized()
	var X := x * misure.x * 0.5
	var Y := y * misure.y * 0.5
	var Z := z * misure.z * 0.5
	var v := func(i: int, j: int, k: int) -> Vector3: return c + X * i + Y * j + Z * k
	var facce_box := [
		[v.call(1, -1, -1), v.call(1, 1, -1), v.call(1, 1, 1), v.call(1, -1, 1), X],
		[v.call(-1, -1, 1), v.call(-1, 1, 1), v.call(-1, 1, -1), v.call(-1, -1, -1), -X],
		[v.call(-1, 1, -1), v.call(-1, 1, 1), v.call(1, 1, 1), v.call(1, 1, -1), Y],
		[v.call(-1, -1, -1), v.call(1, -1, -1), v.call(1, -1, 1), v.call(-1, -1, 1), -Y],
		[v.call(-1, -1, 1), v.call(1, -1, 1), v.call(1, 1, 1), v.call(-1, 1, 1), Z],
		[v.call(1, -1, -1), v.call(-1, -1, -1), v.call(-1, 1, -1), v.call(1, 1, -1), -Z],
	]
	for q in facce_box:
		_quad(st, [q[0], q[1], q[2], q[3]], q[4])
		_facce_quad(f, [q[0], q[1], q[2], q[3]])


# --- utilità ---------------------------------------------------------------------------------------------------------

func _al(p: Vector3, r: Vector3, v: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.z) + r * v.x + Vector3.UP * v.y


## Un quadrilatero che si vede dal verso [param verso].
func _quad(st: SurfaceTool, q: Array, verso: Vector3) -> void:
	_tri(st, [q[0], q[1], q[2]], verso)
	_tri(st, [q[0], q[2], q[3]], verso)


## Un triangolo che si vede dal verso [param verso] (in Godot la faccia davanti gira in senso orario).
func _tri(st: SurfaceTool, t: Array, verso: Vector3) -> void:
	var n: Vector3 = ((t[1] as Vector3) - t[0]).cross((t[2] as Vector3) - t[0])
	if n.length_squared() < 1e-12:
		return
	var ordine := [0, 1, 2] if n.dot(verso) < 0.0 else [0, 2, 1]
	for i in ordine:
		st.set_normal(verso.normalized())
		st.add_vertex(t[i])


func _facce_quad(f: PackedVector3Array, q: Array) -> void:
	f.append_array(PackedVector3Array([q[0], q[1], q[2], q[0], q[2], q[3]]))


## Una scatola (centro, asse x lungo [param ax], asse z lungo [param az], misure) nella mesh e nella collisione.
func _scatola(st: SurfaceTool, f: PackedVector3Array, c: Vector3, ax: Vector3, az: Vector3, misure: Vector3) -> void:
	var x := ax.normalized() * misure.x * 0.5
	var y := Vector3.UP * misure.y * 0.5
	var z := az.normalized() * misure.z * 0.5
	var v := func(i: int, j: int, k: int) -> Vector3: return c + x * i + y * j + z * k
	var facce_box := [
		[v.call(1, -1, -1), v.call(1, 1, -1), v.call(1, 1, 1), v.call(1, -1, 1), x],
		[v.call(-1, -1, 1), v.call(-1, 1, 1), v.call(-1, 1, -1), v.call(-1, -1, -1), -x],
		[v.call(-1, 1, -1), v.call(-1, 1, 1), v.call(1, 1, 1), v.call(1, 1, -1), y],
		[v.call(-1, -1, -1), v.call(1, -1, -1), v.call(1, -1, 1), v.call(-1, -1, 1), -y],
		[v.call(-1, -1, 1), v.call(1, -1, 1), v.call(1, 1, 1), v.call(-1, 1, 1), z],
		[v.call(1, -1, -1), v.call(-1, -1, -1), v.call(-1, 1, -1), v.call(1, 1, -1), -z],
	]
	for q in facce_box:
		_quad(st, [q[0], q[1], q[2], q[3]], q[4])
		_facce_quad(f, [q[0], q[1], q[2], q[3]])


func _corpo(nodo: Node3D, facce: PackedVector3Array) -> void:
	if facce.is_empty():
		return
	var corpo := StaticBody3D.new()
	corpo.name = "Collisione"
	corpo.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(facce)
	sh.backface_collision = true
	cs.shape = sh
	corpo.add_child(cs)
	nodo.add_child(corpo)
