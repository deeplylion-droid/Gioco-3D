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
# il gradino continuo lungo il bordo del canale: due scalini che si salgono camminando (al più Player.step_height,
# 0,32; dall'acqua non si salta, richiesta dell'utente del 25 ottobre)
const GRADINO_LARGO := 0.5   # i due scalini insieme
const GRADINO_SU := 0.61     # lo scalino alto, sopra il fondo (il pelo è a 0,5; poi 0,31 fino alla banchina)
const GRADINO_BASSO := 0.30  # lo scalino basso, sopra il fondo
const GRADINO_R := 0.05      # lo spigolo arrotondato
const PRESA_FINO := 6.0
## L'approdo (scelta 11A dell'utente): nel muro di fondo la porta del portello sta in alto, a [constant SOGLIA] sopra
## le banchine, con l'oblò all'altezza degli occhi di lei che fluttua sopra il canale; davanti, il ballatoio profondo
## [constant BALLATOIO] con la scala dalla banchina sinistra. L'acqua resta al ginocchio fino in fondo (da lì si esce
## col gradino continuo).
const SOGLIA := 3.0
const BALLATOIO := 1.0
## Lo schianto di lei sull'oblò (scelta B con mascotte, 24 ottobre): davanti al portello, sull'asse, lei ci arriva
## intera, quindi il ballatoio non passa davanti alla porta. Il pontile viene dalla scala lungo il muro di fondo e si
## ferma a [constant PONTILE_FINO] dall'asse, a sbalzo: all'altezza della sua lastra lei, schiacciata sul portello, è
## larga al più 0,86 m per lato (misure di mascotte), e sotto, entro 2,1 m dall'asse, ci sono i suoi tentacoli e non
## c'è niente. Davanti alla porta resta la soglia d'acciaio, profonda [constant SOGLIA_PROFONDA] (lei sta a 0,35 m dal
## portello). Il portello resta quello approvato, col volantino e l'oblò in mezzo: dalla testa del pontile si passa
## sulla soglia ed entra di lato.
const PONTILE_FINO := -0.95
const SOGLIA_PROFONDA := 0.25
const PORTA_SX := -0.65
## Il telaio rivettato attorno alla porta: largo, quanto sporge verso il tunnel e quanto dietro il muro (camera).
const TELAIO := 0.13
const TELAIO_DAVANTI := 0.05
const TELAIO_DIETRO := 0.03
## Il battente: quanto è più grande della porta (si chiude contro il telaio) e quanto è spesso.
const BATTENTE_DI := 0.07
const BATTENTE_SPESSO := 0.08
const PORTELLO_LARGO := 1.3
const PORTELLO_ALTO := 2.35      # (l'arco della porta resta sopra i 2 m dove si passa, testa compresa)
const PORTELLO_APERTO := 90.0
## L'oblò e il volantino sul battente (dalla soglia).
const OBLO_Y := 1.3
## Gli oblò sui muri del tunnel: il centro sopra il piano delle banchine (la cornice d'ottone sopra i 2 m).
const OBLO_MURO_SU := 2.55
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
## Lo smusso dello spigolo fra lo stipite della bocca e il muro della galleria (si gira dentro senza fermarsi).
const GALLERIA_SMUSSO := 0.25

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
## I tratti di canale degli attraversamenti: [s inizio, s fine].
var _zone_attraversamento: Array = []
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
## Le posizioni dell'asse ([member _asse] "pos"), pronte: [method proietta] le leggeva dal dizionario a ogni punto, e
## in _occupati_muri degli arredi erano 200-330 ms in un passo. Stessi numeri, stessi risultati.
var _posizioni: PackedVector3Array
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
## I passi ancora da fare: un passo può aggiungerne altri davanti ([method aggiungi_passi]).
var _coda: Array = []


func _ready() -> void:
	dati = JSON.parse_string(FileAccess.get_file_as_string(STRADA))
	_asse = dati["asse"]
	_s = PackedFloat32Array()
	_posizioni = PackedVector3Array()
	for p in _asse:
		_s.append(float(p["s"]))
		var a: Array = p["pos"]
		_posizioni.append(Vector3(a[0], a[1], a[2]))
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
	_coda = _passi()
	while not _coda.is_empty():
		(_coda.pop_front() as Callable).call()
	costruita = true
	# costruito tutto subito: la scaletta dopo SB1 si può aprire (nel gioco lo dice la sala, dopo il riscaldamento)
	AttesaZone.pronta(&"tunnel")


## Un passo lungo si divide: [param altri] si fanno subito dopo il passo che li aggiunge (uno per volta, nella
## costruzione a pezzi).
func aggiungi_passi(altri: Array) -> void:
	_coda = altri + _coda


## Fine dei passi della costruzione a pezzi (prima del riscaldamento e delle forme).
signal passi_finiti
var _costruendo := false
var _ms_pezzo := 6.0


## Costruisce un passo per volta, senza superare [param ms_per_fotogramma] millisecondi per fotogramma (mentre
## si è ancora nella sala delle condotte).
## Chiamata di nuovo mentre si costruisce (il giocatore è arrivato prima della fine) non ricomincia: alza i
## millisecondi per fotogramma e aspetta la fine dei passi.
func costruisci_a_pezzi(ms_per_fotogramma := 6.0) -> void:
	if _costruendo:
		_ms_pezzo = maxf(_ms_pezzo, ms_per_fotogramma)
		await passi_finiti
		return
	_costruendo = true
	_ms_pezzo = ms_per_fotogramma
	_coda = _passi()
	var t0 := Time.get_ticks_usec()
	while not _coda.is_empty():
		var passo: Callable = _coda.pop_front()
		if not is_inside_tree():
			_costruendo = false
			return
		var tp := Time.get_ticks_usec()
		passo.call()
		if OS.has_environment("TORRE_TEMPI") and Time.get_ticks_usec() - tp > 20000:
			print("tunnel passo %s: %.1f ms" % [passo.get_method(), (Time.get_ticks_usec() - tp) / 1000.0])
		if (Time.get_ticks_usec() - t0) / 1000.0 > _ms_pezzo:
			await get_tree().process_frame
			t0 = Time.get_ticks_usec()
	costruita = true
	_costruendo = false
	passi_finiti.emit()
	await _riscalda()
	# le forme del tunnel per i tentacoli di lei (FormeTunnel di grafica, circa 1 s di calcolo a pezzi)
	if is_inside_tree():
		await FormeTunnel.prepara_a_pezzi(self)


## I punti da cui il controllo di posizionamento riempie lo spazio "dove si cammina" (regola dell'utente: niente fino
## a 2 m sopra dove si cammina): le due banchine ogni 3 m (dove ci sono), la scala, il pontile e la camera stagna
## dell'approdo. Il riempimento parte da qui e segue i pavimenti.
func punti_dove_si_cammina() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var s := -TESTA + 0.5
	while s < lunghezza() - 0.5:
		for lato: float in [-1.0, 1.0]:
			if not _lato(s, lato)["crollo"]:
				out.append(_al(punto(s), destra(s), Vector2(lato * (canale + banchina * 0.5), piano)))
		s += 3.0
	var L := lunghezza()
	var p := punto(L)
	var r := destra(L)
	var d := direzione(L)
	var sg := piano + SOGLIA
	out.append(_al(p - d * 0.5, r, Vector2(PONTILE_FINO - 0.6, sg)))
	out.append(_al(p - d * 0.5, r, Vector2(-muro + 0.5, sg)))
	out.append(_al(p + d * 1.5, r, Vector2(0.0, sg)))
	return out


## Le viste del riscaldamento: [s, lato] (una per ambiente, ostacolo e arredo: ogni materiale almeno una volta).
const VISTE_RISCALDA := [[0.0, -1.0], [6.0, 1.0], [70.0, 1.0], [90.0, -1.0], [127.0, -1.0], [140.0, 1.0],
		[152.0, 1.0], [190.0, 1.0], [205.0, -1.0], [211.0, -1.0], [268.0, -1.0], [348.0, 1.0], [430.0, -1.0],
		[484.0, -1.0], [545.0, 0.0], [553.5, 0.0]]


## Il riscaldamento dei materiali (regola: niente scatti la prima volta che si vede qualcosa): costruito il tunnel,
## mentre il giocatore è ancora nella sala delle condotte, una camera nascosta in una vista piccola guarda ogni parte
## del tunnel per qualche fotogramma, con lo stesso mondo, le stesse luci e la stessa resa della vista del gioco. Così
## le pipeline degli shader si compilano lì e non quando si entra (senza: 18 compilazioni al primo sguardo).
func _riscalda() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var vista := get_viewport()
	var vp := SubViewport.new()
	vp.name = "Riscaldamento"
	vp.size = Vector2i(320, 180)
	vp.world_3d = vista.find_world_3d()
	vp.msaa_3d = vista.msaa_3d
	vp.use_taa = vista.use_taa
	vp.screen_space_aa = vista.screen_space_aa
	vp.use_debanding = vista.use_debanding
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
	for v in VISTE_RISCALDA:
		if not is_inside_tree():
			return
		var s: float = minf(float(v[0]), lunghezza())
		var p := punto(s)
		var occhio := _al(p, destra(s), Vector2(-float(v[1]) * (canale + 0.5), piano + 1.6))
		if s > lunghezza() - 0.5:
			occhio = _al(p, destra(s), Vector2(0.0, piano + SOGLIA + 1.6)) + direzione(s) * (float(v[0]) - lunghezza())
		cam.look_at_from_position(occhio, _al(p, destra(s), Vector2(float(v[1]) * muro, piano + 1.2)) + direzione(s) * 3.0)
		for i in 3:
			await get_tree().process_frame
	vp.queue_free()


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
	out.append_array(SottomarinoArrediA2.passi(self))
	# gli arredi di pesci, tartaruga, abisso e approdo (ambienti-1)
	out.append_array(SottomarinoArrediA1.passi(self))
	for o in ostacoli:
		if o["tipo"] == "galleria":
			out.append(_galleria.bind(o))
		else:
			out.append(_ostacolo.bind(o))
	for g in gommoni:
		out.append(_gommone.bind(float(g[0]), float(g[1])))
	out.append(_parapetto_presa)
	out.append(_acqua_presa)
	out.append(_checkpoint)
	out.append(_lei_crea)
	return out


## L'acqua profonda della presa (da s -4,5 a 6, il fondo scende fino a -36): una WaterBody solo per la vista
## subacquea di chi ci cade (con la testa sotto il pelo), senza la sua superficie (il pelo è la striscia del canale) e
## senza increspature né riflessi; nel resto del canale, al ginocchio, niente WaterBody (la vista resta normale).
## Torbida come le vasche: lei sale da lì e non si deve vedere sotto (grafica, 24 ottobre).
func _acqua_presa() -> void:
	var a := punto(-TESTA)
	var b := punto(PRESA_FINO)
	var wb := WaterBody.new()
	wb.name = "AcquaPresa"
	wb.simulate_ripples = false
	wb.capture_env_cubemap = false
	wb.planar_reflection_on_high = false
	wb.style = load("res://addons/acqua/presets/stile_2_torbida.tres")
	# (il primo ramo corre lungo z: il rettangolo dritto della WaterBody ci sta)
	wb.size = Vector2(canale * 2.0, absf(b.z - a.z))
	add_child(wb)
	wb.global_position = Vector3((a.x + b.x) * 0.5, acqua, (a.z + b.z) * 0.5)
	wb.bottom = PRESA_FONDO
	wb.max_level = acqua
	wb.level = acqua
	for c in wb.get_children(true):
		if c.name == "Surface":
			(c as Node3D).visible = false


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
	var pos := _posizioni
	while i < _s.size() - 1:
		var a := pos[i]
		var b := pos[i + 1]
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
	return _posizioni[i]


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


## Il gradino continuo lungo il bordo del canale, dal lato [param lato]: due scalini (il basso a
## [constant GRADINO_BASSO], l'alto a [constant GRADINO_SU] sopra il fondo, poi la banchina), che si salgono camminando
## (prima, decisione del coordinatore con enigmi del 24 ottobre, uno scalino solo che si saliva con due saltelli; dal 25
## ottobre nell'acqua del canale non si salta). Larghi in tutto [constant GRADINO_LARGO], stesso mosaico, gli spigoli
## arrotondati. Scende fino a [param f] (nella presa il fondo è più basso). Con [param vivo] gli spigoli vivi: è la
## forma della collisione (sullo spigolo arrotondato il corpo del giocatore si appoggiava come su una rampa e non saliva).
func _gradino(out: Array, lato: float, f: float, vivo := false) -> void:
	var c := canale
	var g2 := fondo + GRADINO_SU
	var g1 := fondo + GRADINO_BASSO
	var n1 := c - GRADINO_LARGO * 0.5           # il naso dello scalino alto
	var n2 := c - GRADINO_LARGO                 # il naso dello scalino basso
	var rr := GRADINO_R
	var pts := [Vector2(c, g2)]
	for naso in [[n1, g2, g1], [n2, g1, f]]:
		var n: float = naso[0]
		var g: float = naso[1]
		if vivo:
			pts.append(Vector2(n, g))
		else:
			pts.append(Vector2(n + rr, g))
			for k in range(1, 4):
				var a := PI * 0.5 * float(k) / 4.0
				pts.append(Vector2(n + rr - sin(a) * rr, g - rr + cos(a) * rr))
			pts.append(Vector2(n, g - rr))
		pts.append(Vector2(n, naso[2]))
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
			if a[4] != "gradino":
				_facce_quad(facce, q)
			# il retro, spesso [member spessore]: muri e volta pieni (con una faccia sola l'illuminazione globale
			# passava attraverso e faceva macchie scure sulla volta)
			if a[4] == "muro" or a[4] == "volta":
				var vn := verso.normalized()
				_quad(st[a[2]], [q[0] - vn * spessore, q[1] - vn * spessore, q[2] - vn * spessore, q[3] - vn * spessore], -vn)
		# il gradino nella collisione: a spigoli vivi
		for lato: float in [-1.0, 1.0]:
			if _lato(m, lato)["crollo"]:
				continue
			var ga: Array = []
			var gb: Array = []
			_gradino(ga, lato, fondo_a(s), true)
			_gradino(gb, lato, fondo_a(t), true)
			for k in ga.size():
				_facce_quad(facce, [_al(pa, ra, ga[k][0]), _al(pa, ra, ga[k][1]), _al(pb, rb, gb[k][1]), _al(pb, rb, gb[k][0])])
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
			# (e la testa del gradino continuo, tagliato col crollo: i due scalini)
			for sc_g in [[canale - GRADINO_LARGO, canale - GRADINO_LARGO * 0.5, fondo + GRADINO_BASSO],
					[canale - GRADINO_LARGO * 0.5, canale, fondo + GRADINO_SU]]:
				var qg := [_al(p, r, Vector2(lato * float(sc_g[0]), fondo)), _al(p, r, Vector2(lato * float(sc_g[1]), fondo)),
						_al(p, r, Vector2(lato * float(sc_g[1]), float(sc_g[2]))), _al(p, r, Vector2(lato * float(sc_g[0]), float(sc_g[2])))]
				_quad(st["mosaico"], qg, verso)
				_facce_quad(facce, qg)
	if s0 <= PORTA_S and PORTA_S < s1:
		_passaggio_porta(st, facce)
	for k in st:
		var mi := MeshInstance3D.new()
		mi.name = "struttura_" + k     # (architettura per il controllo di posizionamento: muri e pavimenti)
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


## Il passaggio dalla porta del bacino (nel muro della sala delle condotte, x 40,4) al tunnel: pavimento, fianchi
## e soffitto, lunghi quanto lo spessore fra i due muri.
const MURO_CONDOTTE_X := 40.4
func _passaggio_porta(st: Dictionary, facce: PackedVector3Array) -> void:
	var p := punto(PORTA_S)
	var r := destra(PORTA_S)
	var d := direzione(PORTA_S)
	var a := _al(p, r, Vector2(-muro, 0.0))                 # sul muro del tunnel
	var verso_fuori := -r                                    # verso la sala delle condotte
	# (fino al muro ovest della sala delle condotte, che nel gioco sta a x 40,4: inseguimento_proposte.py, X0_GIOCO.
	# Finiva a x 40: fra i due restavano 40 cm senza pavimento, soffitto e fianchi, e dalla porta si vedeva fuori dal
	# livello; segnalazione dell'utente sulla v0.3.14)
	var lungo := MURO_CONDOTTE_X - a.x if absf(verso_fuori.x) > 0.5 else 0.8
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
		vol.senza_salto = true
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
	# il muro di fondo: la sagoma della sezione (fondo, muri, volta) meno la porta. Tagliata in due a metà della porta,
	# così ogni metà ha la porta sul bordo (niente buchi da triangolare)
	var sagoma := [Vector2(-muro, fondo), Vector2(muro, fondo), Vector2(muro, imposta)]
	for k in range(1, 24):
		var a := PI * float(k) / 24
		sagoma.append(Vector2(cos(a) * muro, imposta + sin(a) * (chiave - imposta)))
	sagoma.append(Vector2(-muro, imposta))
	var px1 := PORTA_SX + PORTELLO_LARGO
	# (il buco nel muro è grande quanto il telaio del portello, che lo riempie)
	var porta := PackedVector2Array()
	for q in sagoma_portello(TELAIO):
		porta.append(Vector2(q.x, sg + q.y))
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
	var ca := 2.75
	var cm := 1.4
	var c0 := p
	var c1 := p + d * cl
	var cam := [
		[[_al(c0, r, Vector2(-cm, sg)), _al(c1, r, Vector2(-cm, sg)), _al(c1, r, Vector2(cm, sg)), _al(c0, r, Vector2(cm, sg))], "graniglia", Vector3.UP],
		[[_al(c0, r, Vector2(-cm, sg + ca)), _al(c1, r, Vector2(-cm, sg + ca)), _al(c1, r, Vector2(cm, sg + ca)), _al(c0, r, Vector2(cm, sg + ca))], "mosaico", Vector3.DOWN],
		[[_al(c0, r, Vector2(-cm, sg)), _al(c1, r, Vector2(-cm, sg)), _al(c1, r, Vector2(-cm, sg + ca)), _al(c0, r, Vector2(-cm, sg + ca))], "mosaico", r],
		[[_al(c0, r, Vector2(cm, sg)), _al(c1, r, Vector2(cm, sg)), _al(c1, r, Vector2(cm, sg + ca)), _al(c0, r, Vector2(cm, sg + ca))], "mosaico", -r],
		[[_al(c1, r, Vector2(-cm, sg)), _al(c1, r, Vector2(cm, sg)), _al(c1, r, Vector2(cm, sg + ca)), _al(c1, r, Vector2(-cm, sg + ca))], "mosaico", -d],
	]
	for pz in cam:
		_quad(st[pz[1]], pz[0], pz[2])
		_facce_quad(facce, pz[0])
	# il muro dalla parte della camera, attorno al telaio (tagliato in due a metà della porta)
	for meta: float in [-1.0, 1.0]:
		var mezza := PackedVector2Array([Vector2(0.0, sg), Vector2(meta * cm, sg), Vector2(meta * cm, sg + ca), Vector2(0.0, sg + ca)])
		for poly in Geometry2D.clip_polygons(mezza, porta):
			var tri := Geometry2D.triangulate_polygon(poly)
			for k in range(0, tri.size(), 3):
				# (1 cm dentro la camera, nello spessore del telaio: nello stesso piano del muro di fondo il suo retro si vedeva
				# dal tunnel a tratti, collaudo D3)
				var tc := [_al(c0 + d * 0.01, r, poly[tri[k]]), _al(c0 + d * 0.01, r, poly[tri[k + 1]]), _al(c0 + d * 0.01, r, poly[tri[k + 2]])]
				_tri(st["mosaico"], tc, d)
				facce.append_array(PackedVector3Array(tc))
	# il pontile davanti al muro di fondo, dalla scala fino a PONTILE_FINO dall'asse, e la soglia d'acciaio davanti alla
	# porta (spessi 20 cm, a sbalzo dal muro), poi la scala lungo il muro sinistro
	var b0 := p - d * BALLATOIO
	var pezzi_pontile := [[-muro, PONTILE_FINO, BALLATOIO], [PONTILE_FINO, px1 + 0.2, SOGLIA_PROFONDA]]
	for pz in pezzi_pontile:
		var u0: float = pz[0]
		var u1: float = pz[1]
		var q0 := p - d * float(pz[2])
		var facce_p := [
			[[_al(q0, r, Vector2(u0, sg)), _al(p, r, Vector2(u0, sg)), _al(p, r, Vector2(u1, sg)), _al(q0, r, Vector2(u1, sg))], Vector3.UP],
			[[_al(q0, r, Vector2(u0, sg - 0.2)), _al(p, r, Vector2(u0, sg - 0.2)), _al(p, r, Vector2(u1, sg - 0.2)), _al(q0, r, Vector2(u1, sg - 0.2))], Vector3.DOWN],
			[[_al(q0, r, Vector2(u0, sg - 0.2)), _al(q0, r, Vector2(u1, sg - 0.2)), _al(q0, r, Vector2(u1, sg)), _al(q0, r, Vector2(u0, sg))], -d],
			[[_al(q0, r, Vector2(u1, sg - 0.2)), _al(p, r, Vector2(u1, sg - 0.2)), _al(p, r, Vector2(u1, sg)), _al(q0, r, Vector2(u1, sg))], r],
		]
		# (la testa del pontile verso l'asse, dove il pontile è più profondo della soglia)
		if u1 == PONTILE_FINO:
			facce_p[3] = [[_al(q0, r, Vector2(u1, sg - 0.2)), _al(p - d * SOGLIA_PROFONDA, r, Vector2(u1, sg - 0.2)),
					_al(p - d * SOGLIA_PROFONDA, r, Vector2(u1, sg)), _al(q0, r, Vector2(u1, sg))], r]
		for fp in facce_p:
			_quad(st["graniglia"], fp[0], fp[1])
			_facce_quad(facce, fp[0])
	# le mensole d'acciaio sotto il pontile, lontano dall'asse (oltre 2,1 m: lì sotto ci sono i tentacoli di lei)
	for um: float in [-2.6, -4.6]:
		for k in 3:
			var lk := BALLATOIO * (1.0 - 0.3 * k) - 0.05
			# (tre gradoni di graniglia sotto il pontile, sempre più corti verso il basso: il più basso a 2,05 m sopra la
			# banchina)
			_scatola(st["graniglia"], facce, _al(p - d * (lk * 0.5), r, Vector2(um, sg - 0.2 - 0.125 - 0.25 * k + 0.0005)), r, d,
					Vector3(0.12, 0.25, lk))
	var gradini := 12
	var alzata := SOGLIA / gradini
	for k in gradini:
		var sk := L - BALLATOIO - (gradini - k) * 0.32 + 0.16
		var pk := punto(sk)
		var rk := destra(sk)
		var alto := alzata * (k + 1)
		# (a filo del muro e del pavimento, 2 mm più in qua: le facce sulla stessa superficie del muro si confondevano)
		_scatola(st["graniglia"], facce, _al(pk, rk, Vector2(-muro + 0.502, piano + alto * 0.5 + 0.001)), rk, direzione(sk), Vector3(0.996, alto - 0.002, 0.32))
	# il corrimano della scala e del ballatoio dalla parte del vuoto (la vasca): pali e tubo
	var corr := _mat_ferro()
	for k in range(0, gradini + 1, 2):
		var sk := L - BALLATOIO - (gradini - k) * 0.32
		var pk := punto(sk)
		var base := _al(pk, destra(sk), Vector2(-muro + 0.95, piano + alzata * float(k)))
		_palo(nodo, base, base + Vector3.UP * 1.0, 0.025, corr)
	# (lungo il bordo del pontile verso il canale, e sulla sua testa fino a 0,8 m dal muro: di lì si va alla porta)
	var p_ball := [_al(b0, r, Vector2(-muro + 0.95, sg)), _al(b0, r, Vector2(PONTILE_FINO - 0.05, sg)),
			_al(p - d * 0.8, r, Vector2(PONTILE_FINO - 0.05, sg))]
	for q in p_ball:
		_palo(nodo, q, q + Vector3.UP * 1.0, 0.025, corr)
	_palo(nodo, p_ball[0] + Vector3.UP * 1.0, p_ball[1] + Vector3.UP * 1.0, 0.025, corr)
	_palo(nodo, p_ball[1] + Vector3.UP * 1.0, p_ball[2] + Vector3.UP * 1.0, 0.025, corr)
	var su0 := _al(punto(L - BALLATOIO - gradini * 0.32), destra(L - BALLATOIO - gradini * 0.32), Vector2(-muro + 0.95, piano + 1.0))
	_palo(nodo, su0, p_ball[0] + Vector3.UP * 1.0, 0.025, corr)
	for k in st:
		var mi := MeshInstance3D.new()
		mi.name = "struttura_" + k     # (architettura per il controllo di posizionamento: muri e pavimenti)
		mi.mesh = (st[k] as SurfaceTool).commit()
		mi.material_override = mat_mosaico if k == "mosaico" else mat_graniglia
		nodo.add_child(mi)
	_corpo(nodo, facce)
	_portello(nodo, p, r, d, sg)
	# le luci: la lampada sopra il portello dalla parte del tunnel, e una piccola nella camera sul volantino
	# (sul muro destro, sotto l'imposta della volta: sul sinistro c'è la scala, e sopra la scala ci si passa)
	_lampada(nodo, L - BALLATOIO - 2.0, 1.0, piano + 3.5, 4.0)
	# una sul muro sinistro appena prima della scala, che la illumina dal basso (le lampade del tunnel lì finiscono)
	_lampada(nodo, L - BALLATOIO - 12 * 0.32 - 1.2, -1.0, piano + 3.0, 3.5)
	# e una sul muro di fondo sopra il pontile, dalla parte della scala (2,4 m sopra il pontile): la scala e il
	# ballatoio si devono vedere senza torcia
	var lf := (load("res://assets/enigma_acquari/lampada_gabbia.glb") as PackedScene).instantiate() as Node3D
	nodo.add_child(lf)
	lf.global_position = _al(p, r, Vector2(-3.2, sg + 2.4)) - d * 0.05
	lf.look_at(lf.global_position - d * 2.0, Vector3.UP)
	lf.rotate_object_local(Vector3.UP, PI)
	_a_filo_del_muro(lf, -d)
	var gf := lf.find_child("globo", true, false) as MeshInstance3D
	if gf:
		gf.material_override = _mat_globo()
	var of := OmniLight3D.new()
	of.light_color = Color(1.0, 0.76, 0.5)
	of.light_energy = 3.5
	of.omni_range = 9.0
	of.omni_attenuation = 1.3
	nodo.add_child(of)
	of.global_position = lf.global_position - d * 0.4
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
	# (le ringhiere fermano chi cammina: la collisione del palo, un cilindro come la mesh)
	var corpo := StaticBody3D.new()
	corpo.collision_layer = Layers.WORLD
	mi.add_child(corpo)
	var cs := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = raggio
	cil.height = cm.height
	cs.shape = cil
	corpo.add_child(cs)


## Il portello da sottomarino nella porta in alto del muro di fondo, come quello approvato del fiume B (assets_src/
## fiume_lento/meshy/portello): quasi tondo (l'arco in alto, gli angoli in basso arrotondati, alto 2,05 m perché ci si
## passi in piedi), d'acciaio grigio-verde sbiadito, il telaio rivettato attorno alla porta, il battente con l'oblò
## dal bordo d'ottone in mezzo (lì lei sbatte la faccia) e il volantino rosso sotto, dalla parte della camera,
## illuminato. Il battente è più grande della porta e si chiude contro il telaio dalla parte della camera (niente
## fessure). Aperto nella camera stagna; dalla camera con E si chiude: il battente gira sulle cerniere, il volantino
## gira (in senso orario, per serrare) restando attaccato al battente, e lei ci sbatte contro (vedi [method _finale]).
## Coordinate della porta: u lungo il muro dall'asse (destra), v dalla soglia in su, z verso il tunnel.
func _portello(nodo: Node3D, p: Vector3, r: Vector3, d: Vector3, sg: float) -> void:
	# (l'acciaio grigio-azzurro sbiadito del portello approvato)
	var acciaio := _mat("acciaio_portello", Color(0.46, 0.53, 0.55), 0.55, 0.35)
	var porta_xf := Transform3D(Basis(r, Vector3.UP, -d), _al(p, r, Vector2(0.0, sg)))
	# il telaio: una corona larga TELAIO attorno alla porta, da TELAIO_DIETRO dietro il muro (camera) a TELAIO_DAVANTI
	# davanti (tunnel); il muro ha il buco grande quanto la corona
	var telaio := Node3D.new()
	telaio.name = "Telaio"
	nodo.add_child(telaio)
	telaio.global_transform = porta_xf
	var t_st := SurfaceTool.new()
	t_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t_facce := PackedVector3Array()
	_lastra_bucata(t_st, t_facce, sagoma_portello(TELAIO), sagoma_portello(0.0), 0.0, -TELAIO_DIETRO, TELAIO_DAVANTI)
	var tm := MeshInstance3D.new()
	tm.name = "TelaioPortello"
	tm.mesh = t_st.commit()
	tm.material_override = acciaio
	telaio.add_child(tm)
	_corpo(telaio, t_facce)
	# i rivetti del telaio, sulle due facce (teste a mezza sfera appoggiate alla faccia)
	_rivetti(telaio, sagoma_portello(TELAIO * 0.5), TELAIO_DAVANTI, 1.0, acciaio)
	# i quattro serraggi sul telaio dalla parte del tunnel, come nel portello approvato: due sull'arco, due sui fianchi
	var cy := PORTELLO_ALTO - PORTELLO_LARGO * 0.5
	var w := PORTELLO_LARGO * 0.5 + TELAIO * 0.5
	for pos: Vector2 in [Vector2(cos(PI * 0.25) * w, cy + sin(PI * 0.25) * w), Vector2(-cos(PI * 0.25) * w, cy + sin(PI * 0.25) * w),
			Vector2(w, 0.55), Vector2(-w, 0.55)]:
		var serr := MeshInstance3D.new()
		serr.name = "Serraggio"
		var sb := BoxMesh.new()
		sb.size = Vector3(0.08, 0.13, 0.035)
		serr.mesh = sb
		serr.material_override = acciaio
		telaio.add_child(serr)
		# (appoggiato alla faccia del telaio, girato lungo il bordo)
		serr.position = Vector3(pos.x, pos.y, TELAIO_DAVANTI + 0.0175)
		serr.rotation.z = atan2(pos.y - cy, pos.x) if pos.y > cy else 0.0
	# (dalla parte della camera fuori dal battente chiuso, che copre il telaio per BATTENTE_DI)
	_rivetti(telaio, sagoma_portello(TELAIO * 0.78), -TELAIO_DIETRO, -1.0, acciaio)
	# il battente gira sulle cerniere: il perno è il loro asse, sul lato sinistro della porta, dietro il telaio
	var px := -(PORTELLO_LARGO * 0.5 + BATTENTE_DI + 0.04)     # (l'asse 4 cm fuori dal bordo del battente)
	var pz := -TELAIO_DIETRO - BATTENTE_SPESSO * 0.5
	var perno := Node3D.new()
	perno.name = "PortelloPerno"
	nodo.add_child(perno)
	perno.global_transform = porta_xf * Transform3D(Basis.IDENTITY, Vector3(px, 0.0, pz))
	# il battente: la sagoma della porta allargata di BATTENTE_DI (copre il telaio dalla parte della camera), spessa
	# BATTENTE_SPESSO, col buco dell'oblò; nelle coordinate del perno (x = u - px, z = z - pz)
	var ox := -px                                               # l'oblò, sull'asse
	var cerchio := PackedVector2Array()
	for k in 32:
		var a := TAU * float(k) / 32.0
		cerchio.append(Vector2(ox + cos(a) * OBLO_R, OBLO_Y + sin(a) * OBLO_R))
	var sagoma_b := PackedVector2Array()
	for q in sagoma_portello(BATTENTE_DI, 0.0):
		sagoma_b.append(Vector2(q.x - px, maxf(q.y, 0.01)))
	var b_st := SurfaceTool.new()
	b_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b_facce := PackedVector3Array()
	var mezzo := BATTENTE_SPESSO * 0.5
	_lastra_bucata(b_st, b_facce, sagoma_b, cerchio, ox, -mezzo, mezzo)
	var battente := AnimatableBody3D.new()
	battente.name = "Battente"
	battente.collision_layer = Layers.WORLD
	battente.sync_to_physics = false
	perno.add_child(battente)
	var lastra := MeshInstance3D.new()
	lastra.name = "Lastra"
	lastra.mesh = b_st.commit()
	lastra.material_override = acciaio
	battente.add_child(lastra)
	var b_cs := CollisionShape3D.new()
	var b_forma := ConcavePolygonShape3D.new()
	b_forma.set_faces(b_facce)
	b_cs.shape = b_forma
	battente.add_child(b_cs)
	# i rivetti del battente lungo il bordo, dalla parte della camera
	var giro_rivetti := PackedVector2Array()
	for q in sagoma_portello(BATTENTE_DI - 0.05, -0.05):
		giro_rivetti.append(Vector2(q.x - px, q.y))
	_rivetti(perno, giro_rivetti, -mezzo, -1.0, acciaio)
	# le due cerniere sull'asse del perno, raggio 4 cm: toccano il bordo del battente e la faccia del telaio dalla parte
	# della camera
	for yc: float in [0.35, PORTELLO_ALTO - 0.45]:
		var cern := MeshInstance3D.new()
		cern.name = "Cerniera"
		var cmh := CylinderMesh.new()
		cmh.top_radius = 0.04
		cmh.bottom_radius = 0.04
		cmh.height = 0.24
		cern.mesh = cmh
		cern.material_override = acciaio
		cern.position = Vector3(0.0, yc, 0.0)
		perno.add_child(cern)
	var vetro := MeshInstance3D.new()
	var vm := CylinderMesh.new()
	# (un filo più stretto del buco, che è un poligono di 32 lati: così il bordo del vetro tocca senza entrare)
	vm.top_radius = OBLO_R * cos(PI / 32.0) - 0.001
	vm.bottom_radius = OBLO_R * cos(PI / 32.0) - 0.001
	vm.height = 0.02
	vm.radial_segments = 24
	vetro.mesh = vm
	vetro.material_override = _mat_vetro_oblo()
	vetro.rotation_degrees.x = 90
	vetro.position = Vector3(ox, OBLO_Y, 0.0)
	perno.add_child(vetro)
	for lato: float in [-1.0, 1.0]:
		var an := MeshInstance3D.new()
		var tom := TorusMesh.new()
		tom.inner_radius = OBLO_R - 0.01
		tom.outer_radius = OBLO_R + 0.07
		an.mesh = tom
		an.material_override = _mat_ottone()
		an.rotation_degrees.x = 90
		# (la cornice d'ottone sulla faccia del battente, a 2 mm)
		an.position = Vector3(ox, OBLO_Y, lato * (mezzo + 0.04 + 0.002))
		perno.add_child(an)
	# il volantino dalla parte della camera (z negativo del perno), sotto l'oblò, illuminato
	var volantino := Node3D.new()
	volantino.name = "Volantino"
	volantino.position = Vector3(ox, VOLANTINO_Y, -mezzo - 0.06)
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
	# (il mozzo va dalla ruota al battente, fino a 2 mm dal battente)
	mm.height = 0.06 - 0.002
	mozzo.mesh = mm
	mozzo.material_override = acciaio
	mozzo.rotation_degrees.x = 90
	mozzo.position.z = (0.06 - 0.002) * 0.5
	volantino.add_child(mozzo)
	# aperto: il battente dentro la camera stagna
	perno.rotation_degrees.y += PORTELLO_APERTO
	_perno = perno
	_volantino = volantino
	_perno_chiuso = perno.global_transform.basis.rotated(Vector3.UP, deg_to_rad(-PORTELLO_APERTO))
	# l'interazione: dalla camera, guardando la porta o il battente aperto col volantino. Due zone sottili (collaudo P1:
	# la zona di prima era profonda 0,6 m nella camera e da vicino il raggio ci partiva dentro, senza colpirla): una
	# nel vano della porta, una attorno al battente (si muove con lui)
	var usa := Interactable.new()
	usa.name = "ChiudiPortello"
	usa.prompt = "Chiudi"
	usa.one_shot = true
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(PORTELLO_LARGO, PORTELLO_ALTO, 0.06)
	cs.shape = bx
	usa.add_child(cs)
	nodo.add_child(usa)
	usa.global_transform = Transform3D(Basis(r, Vector3.UP, -d), _al(p + d * 0.04, r, Vector2(0.0, sg + PORTELLO_ALTO * 0.5)))
	usa.interacted.connect(func(_by): chiudi_portello())
	_usa_portello = usa
	var usa_b := Interactable.new()
	usa_b.name = "ChiudiPortelloBattente"
	usa_b.prompt = "Chiudi"
	usa_b.one_shot = true
	var cs_b := CollisionShape3D.new()
	var bx_b := BoxShape3D.new()
	bx_b.size = Vector3(PORTELLO_LARGO + BATTENTE_DI * 2.0, PORTELLO_ALTO, BATTENTE_SPESSO + 0.2)
	cs_b.shape = bx_b
	usa_b.add_child(cs_b)
	perno.add_child(usa_b)
	usa_b.position = Vector3(-px, PORTELLO_ALTO * 0.5, 0.0)
	usa_b.interacted.connect(func(_by): chiudi_portello())
	_usa_battente = usa_b


## La sagoma della porta del portello, quasi tonda: larga PORTELLO_LARGO, alta PORTELLO_ALTO, l'arco in alto e gli
## angoli in basso arrotondati, nelle coordinate della porta (u, v), allargata di [param di] (in basso di
## [param giu], di solito 0: la soglia resta a filo del pavimento). Il verso è antiorario.
static func sagoma_portello(di: float, giu := 0.0) -> PackedVector2Array:
	var w := PORTELLO_LARGO * 0.5 + di
	var rb := 0.15 + di
	var cy := PORTELLO_ALTO - PORTELLO_LARGO * 0.5
	var v0 := -giu
	var out := PackedVector2Array()
	for k in 7:
		var a := -PI * 0.5 + PI * 0.5 * float(k) / 6.0
		out.append(Vector2(w - rb + cos(a) * rb, v0 + rb + sin(a) * rb))
	for k in 25:
		var a := PI * float(k) / 24.0
		out.append(Vector2(cos(a) * w, cy + sin(a) * w))
	for k in 7:
		var a := PI + PI * 0.5 * float(k) / 6.0
		out.append(Vector2(-w + rb + cos(a) * rb, v0 + rb + sin(a) * rb))
	return out


## Una lastra spessa da [param z0] a [param z1] (coordinate locali: x, y nel piano, z lo spessore) col profilo
## [param fuori] meno il [param buco] (tutto dentro): le facce davanti e dietro tagliate in due alla x [param taglio]
## (così ogni metà ha il buco sul bordo e si triangola), i fianchi esterni e quelli del buco.
func _lastra_bucata(st: SurfaceTool, facce: PackedVector3Array, fuori: PackedVector2Array, buco: PackedVector2Array,
		taglio: float, z0: float, z1: float) -> void:
	var b := Rect2(fuori[0], Vector2.ZERO)
	for q in fuori:
		b = b.expand(q)
	var meta := [PackedVector2Array([Vector2(b.position.x - 1.0, b.position.y - 1.0), Vector2(taglio, b.position.y - 1.0),
			Vector2(taglio, b.end.y + 1.0), Vector2(b.position.x - 1.0, b.end.y + 1.0)]),
			PackedVector2Array([Vector2(taglio, b.position.y - 1.0), Vector2(b.end.x + 1.0, b.position.y - 1.0),
			Vector2(b.end.x + 1.0, b.end.y + 1.0), Vector2(taglio, b.end.y + 1.0)])]
	for m in meta:
		for parte in Geometry2D.intersect_polygons(fuori, m):
			for poly in Geometry2D.clip_polygons(parte, buco):
				var tri := Geometry2D.triangulate_polygon(poly)
				for k in range(0, tri.size(), 3):
					for zf: float in [z0, z1]:
						var tt := [Vector3(poly[tri[k]].x, poly[tri[k]].y, zf), Vector3(poly[tri[k + 1]].x, poly[tri[k + 1]].y, zf),
								Vector3(poly[tri[k + 2]].x, poly[tri[k + 2]].y, zf)]
						_tri(st, tt, Vector3(0, 0, 1.0 if zf == z1 else -1.0))
						facce.append_array(PackedVector3Array(tt))
	# i fianchi: fuori con la normale in fuori, il buco con la normale verso il suo centro (tutti e due antiorari)
	for giro in [[fuori, 1.0], [buco, -1.0]]:
		var g: PackedVector2Array = giro[0]
		for k in g.size():
			var e0: Vector2 = g[k]
			var e1: Vector2 = g[(k + 1) % g.size()]
			var e := (e1 - e0).normalized()
			var n := Vector3(e.y, -e.x, 0.0) * float(giro[1])
			var q := [Vector3(e0.x, e0.y, z0), Vector3(e1.x, e1.y, z0), Vector3(e1.x, e1.y, z1), Vector3(e0.x, e0.y, z1)]
			_quad(st, q, n)
			_facce_quad(facce, q)


## I rivetti: teste a mezza sfera ogni 16 cm lungo [param giro] (coordinate locali di [param nodo]), appoggiate alla
## faccia a z [param z] e rivolte verso [param verso] (1: +z, -1: -z); niente rivetti sul bordo basso, nella soglia.
func _rivetti(nodo: Node3D, giro: PackedVector2Array, z: float, verso: float, m: Material) -> void:
	var punti := PackedVector2Array()
	var resto := 0.0
	for k in giro.size():
		var a: Vector2 = giro[k]
		var b: Vector2 = giro[(k + 1) % giro.size()]
		var l := a.distance_to(b)
		var t := resto
		while t < l:
			var q := a.lerp(b, t / l)
			if q.y > 0.08:
				punti.append(q)
			t += 0.16
		resto = t - l
	var testa := SphereMesh.new()
	testa.radius = 0.022
	testa.height = 0.022
	testa.is_hemisphere = true
	testa.radial_segments = 8
	testa.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = testa
	mm.instance_count = punti.size()
	# (la mezza sfera ha la base piatta in y = 0 e la cupola verso +y: girata verso la faccia)
	var giro_b := Basis(Vector3.RIGHT, -PI * 0.5) if verso > 0.0 else Basis(Vector3.RIGHT, PI * 0.5)
	for i in punti.size():
		mm.set_instance_transform(i, Transform3D(giro_b, Vector3(punti[i].x, punti[i].y, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Rivetti"
	mmi.multimesh = mm
	mmi.material_override = m
	nodo.add_child(mmi)


var _perno: Node3D
var _volantino: Node3D
var _perno_chiuso: Basis
var _usa_portello: Interactable
var _usa_battente: Interactable
## Dove va il giocatore quando chiude il portello: sull'asse della camera stagna, a questa distanza dalla porta (fuori
## da dove passa il battente, che chiudendosi spazza fino a 1,6 m dalla cerniera; collaudo P1).
const CAMERA_DOVE_GUARDA := 2.2
var _guarda_oblo := false
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
## "FINE DEL CAPITOLO 1" ([signal fine_demo]).
func chiudi_portello() -> void:
	if finito:
		return
	finito = true
	for u in [_usa_portello, _usa_battente]:
		if u:
			u.enabled = false
	# il giocatore fa da solo un passo indietro sull'asse della camera, guardando l'oblò, mentre il battente si chiude:
	# così il battente non lo spinge e lo schianto si vede tutto, al centro della vista (collaudo P1)
	var pl := GameState.player
	if pl and is_instance_valid(pl) and _in_camera(pl.global_position):
		pl.input_enabled = false
		pl.velocity = Vector3.ZERO
		var L := lunghezza()
		var dove := punto(L) + direzione(L) * CAMERA_DOVE_GUARDA
		dove.y = pl.global_position.y
		var da_p := pl.global_position
		var oblo := _oblo_chiuso()
		_guarda_oblo = true
		var tp := create_tween()
		tp.tween_method(func(k: float):
			if is_instance_valid(pl):
				pl.global_position = da_p.lerp(dove, k)
				pl.velocity = Vector3.ZERO
				pl.look_at_point(oblo), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tp.finished
	var tw := create_tween()
	var da := _perno.global_transform.basis
	tw.tween_method(func(k: float):
		_perno.global_transform.basis = da.slerp(_perno_chiuso, k), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Audio.suona(&"cancello_fine", _volantino.global_position, 0.0, 0.7))
	# il volantino: tre quarti di giro in senso orario visto da chi lo gira (dalla camera, che guarda lungo il +z del
	# perno: lì una rotazione positiva attorno a z si vede oraria)
	tw.tween_property(_volantino, "rotation:z", TAU * 0.75, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_finale)


## Vero se [param q] sta nella camera stagna (dietro la porta, fino al fondo).
func _in_camera(q: Vector3) -> bool:
	var L := lunghezza()
	var v := q - punto(L)
	var dentro := v.dot(direzione(L))
	return dentro > -0.2 and dentro < 3.2 and absf(v.dot(destra(L))) < 1.6


## Il centro dell'oblò a portello chiuso, dalla parte della camera (dove guarda il giocatore).
func _oblo_chiuso() -> Vector3:
	var ox := PORTELLO_LARGO * 0.5 + BATTENTE_DI + 0.04
	return Transform3D(_perno_chiuso, _perno.global_position) * Vector3(ox, OBLO_Y, -BATTENTE_SPESSO * 0.5)


## Durante la chiusura e lo schianto il giocatore guarda l'oblò (i comandi sono spenti).
func _process_oblo() -> void:
	if not _guarda_oblo:
		return
	var pl := GameState.player
	if pl and is_instance_valid(pl) and not pl.input_enabled:
		pl.look_at_point(_oblo_chiuso())


## Lei sbatte contro il portello: arriva dal fondo della vasca dell'approdo e ci schiaccia la faccia sull'oblò.
func _finale() -> void:
	if lei_tunnel:
		lei_stato = Lei.PRESA     # (ferma: la muove lo schianto)
		# (il centro dell'oblò dalla parte del tunnel: la faccia della cornice d'ottone, dove arriva la faccia di lei)
		var ox := PORTELLO_LARGO * 0.5 + BATTENTE_DI + 0.04
		var oblo := _perno.global_transform * Vector3(ox, OBLO_Y, BATTENTE_SPESSO * 0.5 + 0.082)
		# (lei si era fermata a 2,5 m dal portello: se è lì, prima ci arriva di corsa lungo l'asse, così lo schianto
		# parte da dove è lei, senza salti; se è lontana o non c'è, lo schianto comincia subito)
		var arrivo := lunghezza() - 0.95
		if lei_s < arrivo - 0.05 and lei_s > arrivo - 6.0 and lei_tunnel.stato != LeiTunnel.Stato.VIA:
			var tw := create_tween()
			tw.tween_method(func(s: float):
				lei_s = s
				_metti_lei(get_process_delta_time()), lei_s, arrivo, (arrivo - lei_s) / velocita_rincorsa)
			await tw.finished
		lei_tunnel.schianto(oblo, -direzione(lunghezza()))
		lei_tunnel.schianto_contro.connect(func(): Audio.suona(&"cancello_fine", oblo, 2.0, 0.6), CONNECT_ONE_SHOT)
		get_tree().create_timer(2.6, false).timeout.connect(_nero)
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
	# la testa del tunnel e la presa: una lampada sul muro sinistro, prima della porta del bacino (da lì il
	# giocatore guarda la presa, dove riemerge lei: scelta 1A); luce debole come le altre
	_lampada(nodo, -2.2, -1.0, piano + 3.0, 3.0)
	var s := 3.0
	var lato := 1.0
	while s < lunghezza():
		# (nell'approdo no: a sinistra c'è la scala col ballatoio, a destra la lampada del portello)
		if s > lunghezza() - BALLATOIO - 6.0:
			break
		# nell'abisso le luci sono blu e poche, le fa SottomarinoArrediA1
		if SottomarinoArrediA1.senza_luci_normali(self, s):
			s += 9.0
			lato = -lato
			continue
		var p := punto(s)
		var r := destra(s)
		var muro_p := p + r * lato * (muro - 0.02)
		var l := (load("res://assets/enigma_acquari/lampada_gabbia.glb") as PackedScene).instantiate() as Node3D
		nodo.add_child(l)
		l.global_position = Vector3(muro_p.x, piano + 3.0, muro_p.z)
		l.look_at(l.global_position - r * lato * 2.0, Vector3.UP)
		l.rotate_object_local(Vector3.UP, PI)
		_a_filo_del_muro(l, -r * lato)
		# (nel giardino dei coralli la luce è verde-azzurra, come nel piano degli ambienti)
		var coralli := ambiente(s) == 1
		var g := l.find_child("globo", true, false) as MeshInstance3D
		if g:
			g.material_override = _mat_globo_coralli() if coralli else _mat_globo_luci()
		var o := OmniLight3D.new()
		o.light_color = Color(0.55, 0.95, 0.85) if coralli else Color(1.0, 0.76, 0.5)
		o.light_energy = 4.0
		o.omni_range = 12.0
		o.omni_attenuation = 1.3
		o.shadow_enabled = false
		nodo.add_child(o)
		o.global_position = l.global_position - r * lato * 0.4
		# fra una lampada e l'altra, sull'altro muro, un oblò col mare finto illuminato dietro
		if not SottomarinoArrediA1.senza_luci_normali(self, s + 4.5):
			_oblo(nodo, s + 4.5, -lato)
		s += 9.0
		lato = -lato


## Un oblò sul muro (dal lato [param lato]) a [param s]: anello d'ottone e vetro col mare finto illuminato dietro,
## come nel fiume B; fa luce da sé (niente luce in più).
func _oblo(nodo: Node3D, s: float, lato: float) -> void:
	if s > lunghezza() - 1.0:
		return
	# (non dietro gli ostacoli di quella banchina: lì c'è il carico, il cancello...)
	for o in ostacoli:
		if float(o["lato"]) == lato and s > float(o["s"]) - 2.5 and s < float(o["s"]) + float(o["lungo"]) + 2.5:
			return
	var p := punto(s)
	var r := destra(s)
	var n := Node3D.new()
	n.name = "Oblo"
	nodo.add_child(n)
	# (il centro a OBLO_MURO_SU: la cornice, raggio 0,46, sta tutta sopra i 2 m, fuori da davanti alla faccia di chi cammina)
	var pos := Vector3(p.x, piano + OBLO_MURO_SU, p.z) + r * lato * (muro - 0.005)
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


var _globo_luci: StandardMaterial3D
var _globo_coralli: StandardMaterial3D


func _mat_globo_luci() -> StandardMaterial3D:
	if _globo_luci == null:
		_globo_luci = StandardMaterial3D.new()
		_globo_luci.albedo_color = Color(1.0, 0.85, 0.55)
		_globo_luci.emission_enabled = true
		_globo_luci.emission = Color(1.0, 0.7, 0.35)
		_globo_luci.emission_energy_multiplier = 3.0
	return _globo_luci


func _mat_globo_coralli() -> StandardMaterial3D:
	if _globo_coralli == null:
		_globo_coralli = _mat_globo_luci().duplicate()
		_globo_coralli.albedo_color = Color(0.7, 1.0, 0.92)
		_globo_coralli.emission = Color(0.45, 0.95, 0.8)
	return _globo_coralli


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
## I passaggi obbligati lenti (regola dell'utente: "lei ti sta dietro fra 8 e 18 m"): mentre il giocatore li fa
## senza sbagliare (gli attraversamenti sui gommoni: sopra il canale, sui gommoni o in salto, fuori dall'acqua; le
## gallerie basse: accovacciato dietro il muro; l'approdo in fondo: il guado obbligato verso la scala, la scala e il
## pontile fino al portello) lei non scende sotto [member distanza_min], così all'uscita c'è il tempo di girarsi e
## spruzzare o di correre. Se cade in acqua o resta fermo (meno di [member fermo_passo] m in
## [member fermo_dopo] s) valgono le regole di sempre.
@export var fermo_dopo := 2.5
@export var fermo_passo := 0.6
## L'approdo, gli ultimi metri della strada (dal guado obbligato verso la scala della banchina sinistra al portello).
@export var approdo_tratto := 7.0
## Chi insegue (vuoto: il giocatore); i test lo cambiano.
var bersaglio: Node3D

## Lei del tunnel (LeiTunnel di mascotte) e il suo modello.
var lei_tunnel: LeiTunnel
var lei: MedusaAffacciata
var lei_stato := Lei.VIA
var lei_s := 0.0
var _lei_t := 0.0
var _morso_tra := 1.5
var _s_bersaglio := 0.0
var checkpoint: Array[Checkpoint] = []


## I file che la costruzione del tunnel carica (i modelli del fiume, le lampade, lo shader dell'oblò dell'abisso, lei):
## la sala li chiede al thread insieme al tunnel, così i passi li trovano pronti (caricati lì erano passi da 0,2-1,4 s).
## I modelli del tunnel (in [constant DIR_FIUME]).
const MODELLI := ["corallo", "forziere", "pesce_vetroresina", "salvagente", "tartaruga", "ancora", "palombaro"]


static func risorse() -> Array:
	var out: Array = []
	for nome in MODELLI:
		out.append(DIR_FIUME + nome + ".glb")
		out.append(DIR_FIUME + nome + FORME)
	out.append_array(["res://assets/enigma_acquari/lampada_gabbia.glb", DIR_FIUME + "mat_cemento.tres",
		DIR_FIUME + "mat_mosaico_blu.tres", DIR_FIUME + "mat_graniglia.tres", DIR_FIUME + "acqua_fiume.tres"])
	out.append_array(SalaInseguimento.RISORSE_LEI)
	return out.filter(func(p): return ResourceLoader.exists(p))


func _lei_crea() -> void:
	# lei del tunnel è di mascotte (LeiTunnel: animazioni, giro e inclinazione in curva, morsi, getto in faccia,
	# presa, schianto); qui si decide solo dove sta lungo la strada
	lei_tunnel = LeiTunnel.new()
	lei_tunnel.name = "LeiTunnel"
	add_child(lei_tunnel)
	lei = lei_tunnel.lei
	lei_tunnel.getto_litri = getto_in_faccia
	lei_tunnel.vicina = distanza_morsi
	lei_tunnel.getto_in_faccia.connect(respingi)


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
	_dai_forme_a_lei()
	lei_s = s
	lei_stato = Lei.INSEGUE
	_lei_t = 0.0
	if lei_tunnel.stato == LeiTunnel.Stato.VIA:
		# (dai checkpoint: risale dall'acqua del canale, poco profonda, già a metà salita)
		var p := punto(s)
		lei_tunnel.riemergi(Vector3(p.x, acqua, p.z), direzione(s), acqua - fondo_a(s))
	_metti_lei(0.0)


## Lei riemerge dalla presa in testa al tunnel (quando il giocatore la guarda dalla porta): sale dall'acqua e
## parte.
func riemergi() -> void:
	if lei_stato != Lei.VIA:
		return
	lei_stato = Lei.SALE
	_lei_t = 0.0
	lei_s = -1.0
	_dai_forme_a_lei()
	var p := punto(lei_s)
	lei_tunnel.riemergi(Vector3(p.x, acqua, p.z), direzione(lei_s), acqua - fondo_a(lei_s))
	lei_riemersa.emit()
	get_tree().create_timer(minf(lei_tunnel._durata(&"riemerge"), 2.5), false).timeout.connect(func():
		if lei_stato == Lei.SALE:
			insegui_da(lei_s))


## Il getto in faccia: si ritrae strizzando l'occhio, si ferma [member fermo_dopo_getto] secondi tornando indietro
## di [member indietro_dopo_getto] metri, poi riparte.
func respingi() -> void:
	if lei_stato != Lei.INSEGUE and lei_stato != Lei.SALE:
		return
	lei_stato = Lei.RESPINTA
	_lei_t = 0.0
	lei_tunnel.respinta()
	lei_respinta.emit()


func _prendi() -> void:
	if lei_stato == Lei.PRESA:
		return
	lei_stato = Lei.PRESA
	giocatore_preso.emit()
	if bersaglio == null:
		lei_tunnel.prendi()         # (la presa e la morte del giocatore)
	else:
		# (nei test chi insegue è finto: solo l'animazione)
		lei_tunnel.stato = LeiTunnel.Stato.PRESA
		lei_tunnel._anima("presa", 0.15)


## Dà ai tentacoli morbidi di lei le forme del tunnel (una volta sola, prima che compaia).
func _dai_forme_a_lei() -> void:
	if _forme_date or lei_tunnel == null or lei_tunnel.morbidezza == null:
		return
	_forme_date = true
	FormeTunnel.aggiungi(lei_tunnel.morbidezza, self)


var _forme_date := false


## Mette lei sull'asse del canale a [member lei_s], sul pelo dell'acqua: la quota, il giro e l'inclinazione in curva
## li fa LeiTunnel.
func _metti_lei(delta: float) -> void:
	var p := punto(lei_s)
	lei_tunnel.vai(Vector3(p.x, acqua, p.z), direzione(lei_s), delta)


func _process(delta: float) -> void:
	_process_oblo()
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
		Lei.INSEGUE when finito:
			pass      # (il portello si sta chiudendo: lei si ferma, poi la muove lo schianto)
		Lei.INSEGUE:
			var v := velocita_rincorsa if gap > distanza_max else velocita_lei
			if gap < distanza_min and _lei_t < vantaggio:
				v = 0.0
			var tetto := minf(_s_bersaglio - 0.5, lunghezza() - 2.5)
			if b and _passaggio_obbligato(b.global_position, delta):
				# (non oltre gli 8 m dietro di lui; se era già più vicina non la si tira indietro)
				tetto = minf(tetto, maxf(_s_bersaglio - distanza_min, lei_s))
			lei_s = minf(lei_s + v * delta, tetto)
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


## Vero mentre il giocatore (i piedi in [param piedi]) fa un passaggio obbligato lento senza sbagliare e senza
## fermarsi (vedi [member fermo_dopo]): un attraversamento sui gommoni ([method in_attraversamento]), una galleria
## bassa ([method in_tubo]) o l'approdo in fondo (gli ultimi [member approdo_tratto] m: lì il guado è obbligato).
func _passaggio_obbligato(piedi: Vector3, delta: float) -> bool:
	var dentro := in_attraversamento(piedi) or in_tubo(piedi) or _s_bersaglio > lunghezza() - approdo_tratto
	if not dentro:
		_fermo_t = 0.0
		_fermo_da = piedi
		return false
	if piedi.distance_to(_fermo_da) > fermo_passo:
		_fermo_da = piedi
		_fermo_t = 0.0
	else:
		_fermo_t += delta
	return _fermo_t < fermo_dopo


var _fermo_da := Vector3.ZERO
var _fermo_t := 0.0


## Vero se [param piedi] sono in un attraversamento sui gommoni: sopra il canale (o sul bordo delle banchine, dove si
## salta e si atterra), nel tratto dei gommoni di un attraversamento, fuori dall'acqua.
func in_attraversamento(piedi: Vector3) -> bool:
	var pr := proietta_vicino(piedi, _s_bersaglio)
	if absf(float(pr[1])) > canale + 0.6 or piedi.y < acqua - 0.05:
		return false
	var s := float(pr[0])
	for z in _zone_attraversamento:
		if s > float(z[0]) and s < float(z[1]):
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
		lei_tunnel.via()
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
	porta.material = _mat("acciaio_porta_bacino", Color(0.32, 0.36, 0.38), 0.45, 0.8)
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

## La fascia gialla e nera sopra una bocca della galleria: un pezzo solo, lungo la bocca più 20 cm per parte, alto
## 30 cm, spesso 1,2 cm, che segue il muro (anche in curva: ogni vertice sul muro nel suo punto della strada); le
## strisce di traverso sono fatte con la geometria (niente texture sgranata, niente pezzi sovrapposti o fessure).
func _fascia_bocca(nodo: Node3D, sb: float, lato: float, y_bocca: float) -> void:
	var lung := GALLERIA_BOCCA + 0.4
	var a0 := sb - lung * 0.5
	var ya := y_bocca + 0.02
	var yb := y_bocca + 0.32
	var obliquo := 0.15
	var n := 12
	var giallo := SurfaceTool.new()
	giallo.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nero := SurfaceTool.new()
	nero.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rett := PackedVector2Array([Vector2(a0, ya), Vector2(a0 + lung, ya), Vector2(a0 + lung, yb), Vector2(a0, yb)])
	# (un punto (s, y) della fascia nel mondo, staccato dal muro di [param su])
	var al_muro := func(q: Vector2, su: float) -> Vector3:
		return _muro_a(q.x, lato, q.y) - destra(q.x) * lato * su
	var passo := lung / float(n)
	for i in range(-2, n + 2):
		var s1 := a0 + passo * i
		var s2 := s1 + passo
		var striscia := PackedVector2Array([Vector2(s1, ya), Vector2(s2, ya), Vector2(s2 + obliquo, yb), Vector2(s1 + obliquo, yb)])
		for poly in Geometry2D.intersect_polygons(striscia, rett):
			var tri := Geometry2D.triangulate_polygon(poly)
			for k in range(0, tri.size(), 3):
				var tt := [al_muro.call(poly[tri[k]], 0.014), al_muro.call(poly[tri[k + 1]], 0.014), al_muro.call(poly[tri[k + 2]], 0.014)]
				_tri(giallo if posmod(i, 2) == 0 else nero, tt, -destra(poly[tri[k]].x) * lato)
	# i bordi (sopra, sotto, i due capi) dal muro alla faccia, in nero
	var bordo := PackedVector2Array()
	var m := 24
	for k in m + 1:
		bordo.append(Vector2(a0 + lung * float(k) / m, ya))
	for k in m + 1:
		bordo.append(Vector2(a0 + lung - lung * float(k) / m, yb))
	for k in bordo.size():
		var q0: Vector2 = bordo[k]
		var q1: Vector2 = bordo[(k + 1) % bordo.size()]
		var e := (q1 - q0)
		if e.length() < 1e-4:
			continue
		var normale := Vector3.UP if q0.y == yb and q1.y == yb else (Vector3.DOWN if q0.y == ya and q1.y == ya else direzione(q0.x) * signf(q0.x - sb))
		_quad(nero, [al_muro.call(q0, 0.002), al_muro.call(q1, 0.002), al_muro.call(q1, 0.014), al_muro.call(q0, 0.014)], normale)
	for coppia in [[giallo, _mat("fascia_gialla", Color(0.95, 0.74, 0.08), 0.6)], [nero, _mat("fascia_nera", Color(0.06, 0.06, 0.06), 0.7)]]:
		var mi := MeshInstance3D.new()
		mi.name = "Fascia"
		mi.mesh = (coppia[0] as SurfaceTool).commit()
		mi.material_override = coppia[1]
		nodo.add_child(mi)


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
	# (la banchina di questo lato è crollata davanti alla galleria: le lastre rotte vicino alle due teste)
	_crollo_lastre(nodo, float(o["s"]), float(o["lungo"]), lato, true)
	var u0 := muro                                  # il muro del tunnel (dentro)
	var u1 := muro + spessore                       # il retro del muro
	var u2 := u1 + GALLERIA_LARGA                   # il muro esterno della galleria
	var y0 := piano
	var y1 := piano + GALLERIA_ALTA
	# i pezzi ogni 0,5 m, spezzati anche dove le bocche finiscono e dove cominciano gli smussi: il muro fra le bocche
	# parte proprio dallo smusso, senza fessure (collaudo G1: nella curva a 425 lo spigolo e la fessura fra spalletta e
	# muro fermavano il giocatore)
	var bocca_a := float(o["s"])
	var bocca_b := float(o["s"]) + float(o["lungo"])
	var tagli: Array[float] = [bocca_a, bocca_a + GALLERIA_SMUSSO, bocca_b - GALLERIA_SMUSSO, bocca_b, s1]
	var passi: Array[float] = []
	var s_passo := s0
	while s_passo < s1 - 0.001:
		passi.append(s_passo)
		s_passo += 0.5
	for tg in tagli:
		passi.append(tg)
	passi.sort()
	var s := s0
	for t: float in passi:
		if t <= s + 0.001:
			continue
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
		if m > bocca_a + GALLERIA_SMUSSO and m < bocca_b - GALLERIA_SMUSSO:
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
	# gli stipiti delle bocche, con lo spigolo verso la galleria smussato a 45 gradi: si gira nella galleria scivolando
	for sc: float in [bocca_a, bocca_b]:
		var p := punto(sc)
		var r := destra(sc) * lato
		var segno := -1.0 if sc == bocca_a else 1.0
		var verso := direzione(sc) * segno
		var q := [_al(p, r, Vector2(u0, y0)), _al(p, r, Vector2(u1 - GALLERIA_SMUSSO, y0)), _al(p, r, Vector2(u1 - GALLERIA_SMUSSO, y1)), _al(p, r, Vector2(u0, y1))]
		_quad(st["mosaico"], q, verso)
		_facce_quad(facce, q)
		var sm := sc - segno * GALLERIA_SMUSSO
		var pm := punto(sm)
		var rm := destra(sm) * lato
		var qs := [_al(p, r, Vector2(u1 - GALLERIA_SMUSSO, y0)), _al(pm, rm, Vector2(u1, y0)), _al(pm, rm, Vector2(u1, y1)), _al(p, r, Vector2(u1 - GALLERIA_SMUSSO, y1))]
		_quad(st["mosaico"], qs, (verso + r).normalized())
		_facce_quad(facce, qs)
	for k in st:
		var mi := MeshInstance3D.new()
		mi.name = "struttura_" + k     # (architettura per il controllo di posizionamento: muri e pavimenti)
		mi.mesh = (st[k] as SurfaceTool).commit()
		mi.material_override = mat_mosaico if k == "mosaico" else mat_graniglia
		nodo.add_child(mi)
	_corpo(nodo, facce)
	# la fascia gialla e nera sopra le bocche (sul muro, dal lato del tunnel) e una lampada a gabbia sopra ognuna
	for sb: float in [float(o["s"]) - GALLERIA_BOCCA * 0.5, float(o["s"]) + float(o["lungo"]) + GALLERIA_BOCCA * 0.5]:
		var p := punto(sb)
		var r := destra(sb) * lato
		_fascia_bocca(nodo, sb, lato, y1)
		# (la lampada sopra la bocca, col fondo sopra i 2 m: sulla banchina si passa lì davanti)
		_lampada(nodo, sb, lato, piano + 2.45, 3.0)
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
## Le lastre di un crollo (le macerie, la banchina caduta nel canale): ognuna [s dal centro, u dall'asse, quota,
## misure (lunga, spessa, larga di traverso), giri in gradi (x, y, z: z alza la lunghezza verso +s), quale faccia ha il
## rivestimento (1: +y, -1: -y), "terra" (il punto più basso su [param pavimento]) / "muro" (il punto più lontano a filo
## del muro) / "sopra" (il punto più basso a pavimento + quota)]. Il rivestimento va in [param st_r], il calcestruzzo in
## [param st_c]. Restituisce per ogni lastra [centro, x, y, z, misure] (per i ferri dell'armatura).
func _lastre_crollate(st_r: SurfaceTool, st_c: SurfaceTool, facce: PackedVector3Array, sm: float, lato: float,
		lastre: Array, pavimento: float) -> Array:
	var ferri := []
	for l in lastre:
		# (ogni lastra nel suo punto della strada, anche in curva: s, la destra e la direzione lì)
		var sl := sm + float(l[0])
		var p := punto(sl)
		var r := destra(sl) * lato
		var d := direzione(sl)
		var m_loc := Basis(d, Vector3.UP, r)
		var rot: Vector3 = l[4]
		var b := m_loc * Basis.from_euler(rot * PI / 180.0)
		var ms: Vector3 = l[3]
		var x := b.x.normalized()
		var z := (b.z - x * b.z.dot(x)).normalized()
		var y := z.cross(x).normalized()
		var c := _al(p, r, Vector2(float(l[1]), pavimento + float(l[2])))
		var basso := INF
		var fuori := -INF
		for i in [-1, 1]:
			for j in [-1, 1]:
				for k in [-1, 1]:
					var q: Vector3 = c + x * ms.x * 0.5 * i + y * ms.y * 0.5 * j + z * ms.z * 0.5 * k
					basso = minf(basso, q.y)
					fuori = maxf(fuori, (q - p).dot(r))
		if String(l[6]).contains("terra"):
			c.y += pavimento - basso
		elif String(l[6]).contains("sopra"):
			c.y += pavimento + float(l[2]) - basso
		if String(l[6]).contains("muro"):
			c += r * (muro - fuori)
		var X := x * ms.x * 0.5
		var Y := y * ms.y * 0.5
		var Z := z * ms.z * 0.5
		var v := func(i: int, j: int, k: int) -> Vector3: return c + X * i + Y * j + Z * k
		var facce_l := [
			[v.call(1, -1, -1), v.call(1, 1, -1), v.call(1, 1, 1), v.call(1, -1, 1), X, 0],
			[v.call(-1, -1, 1), v.call(-1, 1, 1), v.call(-1, 1, -1), v.call(-1, -1, -1), -X, 0],
			[v.call(-1, 1, -1), v.call(-1, 1, 1), v.call(1, 1, 1), v.call(1, 1, -1), Y, 1],
			[v.call(-1, -1, -1), v.call(1, -1, -1), v.call(1, -1, 1), v.call(-1, -1, 1), -Y, -1],
			[v.call(-1, -1, 1), v.call(1, -1, 1), v.call(1, 1, 1), v.call(-1, 1, 1), Z, 0],
			[v.call(1, -1, -1), v.call(-1, -1, -1), v.call(-1, 1, -1), v.call(1, 1, -1), -Z, 0],
		]
		for q in facce_l:
			var qq := [q[0], q[1], q[2], q[3]]
			_quad(st_r if int(q[5]) == int(l[5]) else st_c, qq, q[4])
			_facce_quad(facce, qq)
		ferri.append([c, x, y, z, ms])
	return ferri


## I ferri dell'armatura che escono dai bordi rotti: ognuno [lastra, quale bordo lungo la sua lunghezza (1 o -1),
## dove lungo il bordo (frazione della mezza larghezza), lunghezza, direzione nelle coordinate della lastra]; partono
## dalla faccia del bordo (4 mm dentro).
func _ferri_armatura(nodo: Node3D, ferri: Array, elenco: Array, sopra: float) -> void:
	var ferro := _mat("ferro_armatura", Color(0.32, 0.2, 0.13), 0.85, 0.4)
	for fe in elenco:
		if int(fe[0]) >= ferri.size():
			continue
		var l: Array = ferri[int(fe[0])]
		var c: Vector3 = l[0]
		var lx: Vector3 = l[1]
		var ly: Vector3 = l[2]
		var lz: Vector3 = l[3]
		var ms: Vector3 = l[4]
		var dir_loc: Vector3 = fe[4]
		var bordo := c + lx * ms.x * 0.5 * float(fe[1]) + lz * ms.z * 0.5 * float(fe[2])
		var verso := (lx * dir_loc.x + ly * dir_loc.y + lz * dir_loc.z).normalized()
		var inizio := bordo - verso * 0.004
		if inizio.y < sopra + 0.05:
			continue
		_palo(nodo, inizio, inizio + verso * float(fe[3]), 0.009, ferro)


## Le lastre di una banchina crollata nel canale (da [param s0], lunga [param lungo], dal lato [param lato]): per ogni
## testa rotta una lastra grande appoggiata in salita contro la testa, una più piccola storta e due pezzi; in mezzo
## (se non [param solo_capi]) altre lastre storte. Tutte poggiano sul fondo del canale (e al muro), il pesante sotto;
## la graniglia della banchina sopra, il calcestruzzo sotto; i ferri dalle lastre grandi.
func _crollo_lastre(nodo: Node3D, s0: float, lungo: float, lato: float, solo_capi: bool) -> void:
	var sm := s0 + lungo * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s0 * 10.0) + 7
	var lastre := []
	for sgn: float in [-1.0, 1.0]:
		var e := sgn * lungo * 0.5
		lastre.append([e - sgn * 0.95, 5.0, 0.0, Vector3(1.6, 0.26, 2.0), Vector3(rng.randf_range(-6, 6), sgn * rng.randf_range(4, 12), sgn * 22.0), 1, "terra"])
		lastre.append([e - sgn * 2.2, 4.45, 0.0, Vector3(1.2, 0.24, 1.35), Vector3(rng.randf_range(4, 10), sgn * 15.0, -sgn * 8.0), 1, "terra"])
		lastre.append([e - sgn * 1.7, 5.85, 0.0, Vector3(0.5, 0.3, 0.45), Vector3(10, rng.randf_range(10, 50), 5), 1, "terra muro"])
		lastre.append([e - sgn * 0.45, 4.05, 0.0, Vector3(0.4, 0.25, 0.5), Vector3(0, rng.randf_range(10, 60), 12), -1, "terra"])
	if not solo_capi:
		var so := -lungo * 0.5 + 3.2
		var k := 0
		while so < lungo * 0.5 - 3.0:
			lastre.append([so, 5.4 if k % 2 == 0 else 4.6, 0.0, Vector3(1.3, 0.24, 1.3),
					Vector3(rng.randf_range(-15, 15), rng.randf_range(-30, 30), rng.randf_range(-12, 12)), 1 if k % 2 == 0 else -1, "terra"])
			lastre.append([so + 1.1, 4.3 if k % 2 == 0 else 5.6, 0.0, Vector3(0.55, 0.3, 0.5),
					Vector3(rng.randf_range(-10, 10), rng.randf_range(0, 90), rng.randf_range(-10, 10)), 1, "terra"])
			so += 2.4
			k += 1
	var st_g := SurfaceTool.new()
	st_g.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_c := SurfaceTool.new()
	st_c.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facce := PackedVector3Array()
	var ferri := _lastre_crollate(st_g, st_c, facce, sm, lato, lastre, fondo)
	for coppia in [[st_g, mat_graniglia, "Lastre"], [st_c, _mat_cemento("calcestruzzo_volta", Color(0.58, 0.56, 0.52)), "Calcestruzzo"]]:
		var mi := MeshInstance3D.new()
		mi.name = coppia[2]
		mi.mesh = (coppia[0] as SurfaceTool).commit()
		mi.material_override = coppia[1]
		nodo.add_child(mi)
	_corpo(nodo, facce)
	_ferri_armatura(nodo, ferri, [[0, 1.0, 0.4, 0.4, Vector3(0.9, 0.3, 0.1)], [0, 1.0, -0.4, 0.35, Vector3(0.9, 0.2, -0.2)],
			[4, -1.0, 0.3, 0.4, Vector3(-0.9, 0.3, 0.2)], [4, -1.0, -0.3, 0.3, Vector3(-0.9, 0.2, -0.1)]], fondo)


## Una cassa da nave (centro [param c], larga lungo [param r], lunga lungo [param d], misure x alta x lunga): il corpo
## di assi un po' rientrato, i dodici spigoli rinforzati e una traversa in diagonale sui due fianchi lunghi (in
## [param scuro]), due reggette di ferro tutto attorno (in [param regge]).
func _cassa(st: SurfaceTool, scuro: SurfaceTool, regge: SurfaceTool, facce: PackedVector3Array, c: Vector3, r: Vector3,
		d: Vector3, misure: Vector3) -> void:
	var w := misure.x
	var h := misure.y
	var l := misure.z
	var b := 0.07                       # gli spigoli
	_scatola(st, facce, c, r, d, Vector3(w - 0.04, h - 0.04, l - 0.04))
	var y := Vector3.UP
	for i: float in [-1.0, 1.0]:
		for j: float in [-1.0, 1.0]:
			# i quattro montanti, i quattro correnti lungo d e i quattro lungo r
			_scatola(scuro, facce, c + r * (w - b) * 0.5 * i + d * (l - b) * 0.5 * j, r, d, Vector3(b, h, b))
			_scatola(scuro, facce, c + r * (w - b) * 0.5 * i + y * (h - b) * 0.5 * j, r, d, Vector3(b, b, l - 2.0 * b))
			_scatola(scuro, facce, c + d * (l - b) * 0.5 * i + y * (h - b) * 0.5 * j, r, d, Vector3(w - 2.0 * b, b, b))
	# la traversa in diagonale sui fianchi lunghi (verso il canale e verso il muro)
	for i: float in [-1.0, 1.0]:
		var diag := (d * (l - 2.0 * b) + y * (h - 2.0 * b) * i).normalized()
		_scatola_ruotata(scuro, facce, c + r * (w * 0.5 - 0.035) * i, diag, r, Vector3(Vector2(l - 2.0 * b, h - 2.0 * b).length(), 0.08, 0.05))
	# due reggette tutto attorno, a un terzo e due terzi dell'altezza, 5 mm fuori dagli spigoli
	for f: float in [-1.0 / 6.0, 1.0 / 6.0]:
		var cc := c + y * h * f
		for i: float in [-1.0, 1.0]:
			_scatola(regge, facce, cc + r * (w * 0.5 + 0.0025) * i, r, d, Vector3(0.005, 0.05, l + 0.01))
			_scatola(regge, facce, cc + d * (l * 0.5 + 0.0025) * i, r, d, Vector3(w + 0.01, 0.05, 0.005))


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
			# la banchina caduta nel canale: lastre spezzate di traverso, appoggiate al fondo, al muro e alle teste rotte
			# (davanti a una galleria solo vicino alle teste: il resto è il canale dove si passa a guado)
			_crollo_lastre(nodo, s0, lungo, lato, _sotto_galleria(o))
			mat = mat_graniglia
		"carico":
			# il carico del relitto caduto sulla banchina: due colonne di casse da nave (le grandi sotto), il davanti
			# dritto alto 1,6 m (non ci si sale) e il forziere sopra la colonna verso il canale. Le casse sono vere: assi, spigoli rinforzati, una traversa in diagonale
			# e due reggette di ferro; la colonna verso il canale resta 10 cm dentro il bordo della banchina
			mat = _mat("cassa_assi", Color(0.5, 0.37, 0.22), 0.85)
			var scuro := SurfaceTool.new()
			scuro.begin(Mesh.PRIMITIVE_TRIANGLES)
			var regge := SurfaceTool.new()
			regge.begin(Mesh.PRIMITIVE_TRIANGLES)
			var uw := muro - 0.62
			var uc := canale + 0.1 + 0.575
			var mezzo_s := lungo * 0.25
			# [u, larga di traverso, quota del fondo, alta]
			for col in [[uw, 1.2, 0.0, 0.9], [uw, 1.2, 0.9, 0.7], [uc, 1.15, 0.0, 0.8], [uc, 1.15, 0.8, 0.75]]:
				for so: float in [-mezzo_s, mezzo_s]:
					var sc := sm + so
					var pc := punto(sc)
					var rc := destra(sc) * lato
					var dc := direzione(sc)
					var c := _al(pc, rc, Vector2(float(col[0]), piano + float(col[2]) + float(col[3]) * 0.5))
					_cassa(st, scuro, regge, facce, c, rc, dc, Vector3(float(col[1]), float(col[3]), lungo * 0.5 - 0.01))
			for coppia in [[scuro, _mat("cassa_spigoli", Color(0.27, 0.18, 0.1), 0.85), "Spigoli"], [regge, _mat_ferro(), "Reggette"]]:
				var mi_c := MeshInstance3D.new()
				mi_c.name = coppia[2]
				mi_c.mesh = (coppia[0] as SurfaceTool).commit()
				mi_c.material_override = coppia[1]
				nodo.add_child(mi_c)
			SottomarinoArrediA2._doppia_faccia(_modello(nodo, "forziere", _al(p + d * 0.2, r, Vector2(uc, piano + 1.55)), -d, 1.0))
		"cancello":
			_cancello(nodo, st, facce, s0, lato)
			mat = _mat_ferro()
		"macerie":
			# un pezzo di volta crollato (sotto il buco nella volta di ambienti-1): un mucchio di lastre di mosaico spezzate
			# e storte, le grandi sotto, due lastre ritte di traverso davanti (non si scavalca: alte 1,6-1,9 m e ripide),
			# una appoggiata al muro, i ferri dell'armatura che escono dai bordi rotti e i calcinacci intorno
			mat = mat_mosaico
			# il calcestruzzo delle lastre (il mosaico sta solo sulla faccia che era dentro la volta)
			var cls_st := SurfaceTool.new()
			cls_st.begin(Mesh.PRIMITIVE_TRIANGLES)
			# [s dal centro, u dall'asse, quota, misure (lunga, spessa, larga di traverso), giri in gradi (x, y, z: z alza
			#  la lunghezza verso +s), dove va il mosaico (1: faccia +y, -1: faccia -y), "terra"/"muro"]
			var lastre := [
				[0.2, 5.0, 0.0, Vector3(2.0, 0.32, 2.4), Vector3(6, 5, -4), 1, "terra"],
				[-0.7, 4.4, 0.0, Vector3(1.4, 0.3, 1.3), Vector3(-10, 25, 14), -1, "terra"],
				[-0.5, 5.6, 0.0, Vector3(1.3, 0.3, 1.2), Vector3(12, -20, 10), 1, "terra muro"],
				[-0.9, 4.6, 0.0, Vector3(1.7, 0.28, 1.4), Vector3(15, 10, 48), -1, "terra"],
				[-0.8, 5.6, 0.0, Vector3(1.8, 0.28, 1.3), Vector3(-15, -12, 55), 1, "terra muro"],
				[0.5, 5.75, 0.6, Vector3(1.5, 0.25, 1.4), Vector3(60, -6, 8), 1, "terra muro"],
				[0.3, 4.6, 0.3, Vector3(1.3, 0.25, 1.1), Vector3(-30, 15, -40), -1, "terra"],
				[-0.1, 5.0, 0.95, Vector3(1.0, 0.24, 0.9), Vector3(20, 35, 25), 1, "sopra"],
				[0.9, 5.2, 0.0, Vector3(0.6, 0.5, 0.55), Vector3(8, 30, 12), 1, "terra"],
				[-1.4, 5.0, 0.0, Vector3(0.5, 0.35, 0.45), Vector3(0, 40, 18), -1, "terra"],
				[-1.3, 4.1, 0.0, Vector3(0.4, 0.3, 0.5), Vector3(10, 15, -10), 1, "terra"],
				[1.3, 4.3, 0.0, Vector3(0.9, 0.28, 0.8), Vector3(-20, -25, 30), -1, "terra"],
			]
			var ferri := _lastre_crollate(st, cls_st, facce, sm, lato, lastre, piano)
			var cls := MeshInstance3D.new()
			cls.name = "Calcestruzzo"
			cls.mesh = cls_st.commit()
			cls.material_override = _mat_cemento("calcestruzzo_volta", Color(0.58, 0.56, 0.52))
			nodo.add_child(cls)
			# i ferri dell'armatura che escono dai bordi rotti
			_ferri_armatura(nodo, ferri, [[3, 1.0, 0.3, 0.5, Vector3(0.9, 0.2, 0.2)], [3, 1.0, -0.3, 0.4, Vector3(0.9, 0.3, -0.2)],
					[4, 1.0, 0.25, 0.45, Vector3(0.9, -0.1, 0.3)], [5, 1.0, 0.0, 0.5, Vector3(0.9, 0.3, 0.1)],
					[0, -1.0, 0.6, 0.4, Vector3(-0.9, 0.3, 0.2)], [7, 1.0, 0.2, 0.35, Vector3(0.9, 0.2, -0.3)]], piano)
			# i calcinacci intorno: pezzi piccoli di malta e mosaico sul pavimento della banchina, davanti e attorno al mucchio
			var c_st := SurfaceTool.new()
			c_st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var c_facce := PackedVector3Array()
			var rng := RandomNumberGenerator.new()
			rng.seed = 348
			for k in 34:
				var so := rng.randf_range(-2.1, 1.8)
				var u := rng.randf_range(canale + 0.15, muro - 0.15)
				if so > -1.5 and so < 1.6 and u > canale + 0.5:
					continue           # (sotto il mucchio no: solo intorno)
				var grande := k % 4 == 0
				var dim := Vector3(rng.randf_range(0.18, 0.34), rng.randf_range(0.1, 0.2), rng.randf_range(0.15, 0.3)) if grande \
						else Vector3(rng.randf_range(0.06, 0.2), rng.randf_range(0.04, 0.1), rng.randf_range(0.06, 0.18))
				var giro := rng.randf_range(0.0, TAU)
				var cx := d.rotated(Vector3.UP, giro)
				var cc := _al(p + d * so, r, Vector2(u, piano + dim.y * 0.5 + 0.001))
				_scatola_ruotata(c_st, c_facce, cc, cx, cx.cross(Vector3.UP), dim)
			var calc := MeshInstance3D.new()
			calc.name = "Calcinacci"
			calc.mesh = c_st.commit()
			calc.material_override = _mat_cemento("calcinacci", Color(0.72, 0.7, 0.64))
			nodo.add_child(calc)
			# sul mucchio non si sale (le lastre storte si scalerebbero a salti): un muro invisibile sopra, fino a 3 m
			var barriera := StaticBody3D.new()
			barriera.name = "Barriera"
			barriera.collision_layer = Layers.BARRIERS
			nodo.add_child(barriera)
			var bcs := CollisionShape3D.new()
			var bbox := BoxShape3D.new()
			bbox.size = Vector3(lungo, 3.0, muro - canale)
			bcs.shape = bbox
			barriera.add_child(bcs)
			barriera.global_transform = Transform3D(Basis(d, Vector3.UP, r), _al(p, r, Vector2((canale + muro) * 0.5, piano + 1.5)))
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
	_zone_attraversamento = []
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
		# il tratto di canale dell'attraversamento (per la distanza di lei: in_attraversamento)
		_zone_attraversamento.append([s_ultimo - float(lungo[n - 1]) - rg - 2.5, s_ultimo + rg + 2.5])


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
		mm.inner_radius = 0.045
		mm.outer_radius = 0.07
		mm.rings = 12
		mm.ring_segments = 6
		man.mesh = mm
		man.material_override = nera
		corpo.add_child(man)
		# l'anello esce dal fianco del tubolare (lo tocca col bordo), dritto e girato lungo il fianco: la corda passa
		# nel suo foro, dalla parte di fuori (q sta 2,5 cm dentro la gomma)
		# (la gomma disegnata, a facce, sta fino a un centimetro dentro quella vera: l'anello entra di due)
		man.transform = Transform3D(Basis(m, Vector3.UP, m.cross(Vector3.UP)) * Basis(Vector3.RIGHT, PI * 0.5), q + m * 0.075)
		maniglie.append(q + m * 0.12)
	# le corde: dalle due maniglie più vicine agli anelli della parete più vicina, prima e dopo lungo il canale
	var lato := 1.0 if off >= 0.0 else -1.0
	var corde: Array = []
	var usate := {}
	for k: float in [-1.0, 1.0]:
		var sa := s + k * CORDA_LUNGO
		var pa := punto(sa)
		var ra := destra(sa)
		# la piastra sul muro, e l'anello che ne esce di piatto, girato lungo il canale: la corda passa nell'anello
		# (sotto il listello del bordo della banchina, che sporge 4 cm e scende di 6 cm: 20 cm sopra l'acqua)
		var muro_q := _al(pa, ra, Vector2(lato * canale, acqua + 0.2))
		var dentro := -ra * lato
		var piastra := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.14, 0.14, 0.02)
		piastra.mesh = pm
		piastra.material_override = _mat_ferro()
		nodo.add_child(piastra)
		# (staccata dal muro di un millimetro e mezzo: tocca la parete del canale senza entrare sotto la banchina)
		piastra.global_transform = Transform3D(Basis.looking_at(dentro, Vector3.UP), muro_q + dentro * 0.0115)
		var attacco := MeshInstance3D.new()
		var am := TorusMesh.new()
		am.inner_radius = 0.035
		am.outer_radius = 0.06
		attacco.mesh = am
		attacco.material_override = _mat_ferro()
		nodo.add_child(attacco)
		var da := direzione(sa)
		# (l'anello tocca la piastra col bordo; la corda passa nel suo foro, dalla parte del canale)
		attacco.global_transform = Transform3D(Basis(dentro, da, dentro.cross(da)), muro_q + dentro * 0.0815)
		var anello := muro_q + dentro * 0.1115
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
	# (quando il gommone si avvicina all'anello la corda pende di più, ma non tocca l'acqua: resta 5 cm sopra)
	freccia = minf(freccia, maxf(0.0, minf(a.y, b.y) - acqua - 0.05))
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
			# (Godot: le facce davanti girano in senso orario viste da fuori)
			for v in [prev + v0, q + v1, q + v0, prev + v0, prev + v1, q + v1]:
				im.surface_set_normal(((v - prev) - dir * (v - prev).dot(dir)).normalized())
				im.surface_add_vertex(v)
	im.surface_end()


## Un modello Meshy del fiume (assets/fiume_lento) a [param pos], girato verso [param verso], scalato.
func _modello(nodo: Node3D, nome: String, pos: Vector3, verso: Vector3, scala: float) -> Node3D:
	var n := (load(DIR_FIUME + nome + ".glb") as PackedScene).instantiate() as Node3D
	usa_forme_salvate(nome, n)
	nodo.add_child(n)
	n.global_transform = Transform3D(Basis.looking_at(verso, Vector3.UP).scaled(Vector3.ONE * scala), pos)
	return n


## Le forme convesse dei modelli del tunnel calcolate prima e salvate (tools/genera_forme_tunnel.gd): accanto al GLB,
## "<nome>_forme.res", caricate nel thread con le altre [method risorse]. Calcolarle durante la costruzione costava
## 40-180 ms per modello (il primo corallo, il forziere, il palombaro). Sono le stesse del motore (test_forme_tunnel.gd).
const FORME := "_forme.res"


## Mette nelle cache le forme salvate delle mesh di [param n] (il modello [param nome] appena istanziato): la forma
## della collisione e l'involucro per sporgenze e appoggi. Si usano solo se la mesh è ancora quella (stesso AABB e
## stesso numero di vertici): se il GLB cambia senza rigenerarle, si ricalcolano come prima.
static func usa_forme_salvate(nome: String, n: Node3D) -> void:
	var f := DIR_FIUME + nome + FORME
	if senza_scorciatoie or not ResourceLoader.exists(f):
		return
	var r := load(f)
	var d: Dictionary = r.get_meta(&"forme", {}) if r else {}
	for x in n.find_children("*", "MeshInstance3D", true, false):
		var mi := x as MeshInstance3D
		var k := String(n.get_path_to(mi))
		if mi.mesh == null or not d.has(k):
			continue
		var e: Array = d[k]
		if e[2] != mi.mesh.get_aabb() or int(e[3]) != impronta(mi.mesh):
			continue
		if not _forme_convesse.has(mi.mesh):
			_forme_convesse[mi.mesh] = e[0]
		if not SottomarinoArrediA2._involucri.has(mi.mesh):
			SottomarinoArrediA2._involucri[mi.mesh] = e[1]


## Solo per i test (test_posizioni_tunnel.gd): niente forme salvate e sporgenze e appoggi su tutte le facce, come
## prima delle scorciatoie dei blocchi al primo avvio, per provare che le posizioni restano le stesse.
static var senza_scorciatoie := false


## Il numero di vertici di [param m] (per riconoscere una mesh cambiata).
static func impronta(m: Mesh) -> int:
	var n := 0
	if m is ArrayMesh:
		for i in m.get_surface_count():
			n += (m as ArrayMesh).surface_get_array_len(i)
	return n


## La collisione di un modello: per ogni sua mesh la forma convessa (si sbatte contro la sua sagoma, non contro una
## scatola invisibile più grande).
## Mesh -> la sua forma convessa semplificata (per [method _collisione_modello]).
static var _forme_convesse := {}


func _collisione_modello(n: Node3D) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "Collisione"
	corpo.collision_layer = Layers.WORLD
	n.add_child(corpo)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var cs := CollisionShape3D.new()
		# (la stessa forma per la stessa mesh, calcolata una volta: ogni corallo la rifaceva, 100 ms l'uno)
		if not _forme_convesse.has(m.mesh):
			_forme_convesse[m.mesh] = m.mesh.create_convex_shape(true, true)
		cs.shape = _forme_convesse[m.mesh]
		corpo.add_child(cs)
		cs.global_transform = m.global_transform


## Abbassa o alza [param n] finché il suo punto più basso sta a [param quota] (poggia).
func _appoggia(n: Node3D, quota: float) -> void:
	var basso := INF
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := m.global_transform
		for v in SottomarinoArrediA2._involucro(m.mesh):
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
	_a_filo_del_muro(l, -r)
	var g := l.find_child("globo", true, false) as MeshInstance3D
	if g:
		g.material_override = _mat_globo()
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.76, 0.5)
	o.light_energy = energia
	o.omni_range = 10.0
	o.omni_attenuation = 1.3
	nodo.add_child(o)
	o.global_position = l.global_position - r * 0.4


## Mette [param n] col retro a contatto col muro dietro (con Posa): [param fuori] è la direzione fuori dal muro.
func _a_filo_del_muro(n: Node3D, fuori: Vector3) -> void:
	var dietro := 0.0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := m.global_transform
		for v in SottomarinoArrediA2._involucro(m.mesh):
			dietro = maxf(dietro, ((xf * v) - n.global_position).dot(-fuori))
	Posa.fissa_al_muro(n, fuori.normalized(), dietro)


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


## Il calcestruzzo rotto delle lastre crollate e dei calcinacci: il cemento del fiume (texture triplanare, bagnato),
## con la sua tinta (collaudo D1: i bordi spezzati lisci e beige sembravano cartone). Lo stesso shader del resto del
## tunnel: niente campioni nuovi.
func _mat_cemento(nome: String, tinta: Color) -> Material:
	if not _materiali.has(nome):
		var m := (load(DIR_FIUME + "mat_cemento.tres") as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter(&"albedo_tint", tinta)
		m.set_shader_parameter(&"uv_scale", 0.6)
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

## Il punto della faccia del muro dal lato [param lato] a [param s], alla quota [param y], come lo disegna la mesh:
## dritto fra una sezione e l'altra (ogni [constant PASSO_SEZIONE] metri dalla testa), non sulla curva esatta.
func _muro_a(s: float, lato: float, y: float) -> Vector3:
	var sa := -TESTA + floorf((s + TESTA) / PASSO_SEZIONE) * PASSO_SEZIONE
	var sb := sa + PASSO_SEZIONE
	var a := _al(punto(sa), destra(sa), Vector2(lato * muro, y))
	var b := _al(punto(sb), destra(sb), Vector2(lato * muro, y))
	return a.lerp(b, (s - sa) / PASSO_SEZIONE)


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
