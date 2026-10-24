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
const PRESA_FINO := 6.0
## I gradini per risalire dal canale: ogni quanti metri, alternati sui due lati.
const GRADINI_OGNI := 12.0

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
	out.append(_gradini)
	out.append(_luci)
	return out


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

## La sezione del tunnel a [param s] in coordinate (di lato dall'asse, quota): i pezzi della sezione col loro
## materiale e il verso in cui guardano. Il fondo del canale, le sue pareti, il bordo e il piano delle banchine, i
## muri e la volta a mezza ellisse.
func _profilo(s: float) -> Array:
	var f := fondo if s >= PRESA_FINO else lerpf(PRESA_FONDO, fondo, clampf((s + 0.5) / (PRESA_FINO + 0.5), 0.0, 1.0))
	var c := canale
	var m := muro
	var out: Array = []
	# (punti da sinistra a destra; ogni pezzo: [a, b, materiale, verso della faccia in coordinate (lato, su)])
	out.append([Vector2(-c, f), Vector2(c, f), "mosaico", Vector2(0, 1)])               # fondo del canale
	out.append([Vector2(-c, piano), Vector2(-c, f), "mosaico", Vector2(1, 0)])          # parete sinistra
	out.append([Vector2(c, f), Vector2(c, piano), "mosaico", Vector2(-1, 0)])           # parete destra
	out.append([Vector2(-m, piano), Vector2(-c, piano), "graniglia", Vector2(0, 1)])    # banchina sinistra
	out.append([Vector2(c, piano), Vector2(m, piano), "graniglia", Vector2(0, 1)])      # banchina destra
	out.append([Vector2(-m, imposta), Vector2(-m, piano), "mosaico", Vector2(1, 0)])    # muro sinistro
	out.append([Vector2(m, piano), Vector2(m, imposta), "mosaico", Vector2(-1, 0)])     # muro destro
	var seg := 12
	for k in seg:
		var a0 := PI * float(k) / seg
		var a1 := PI * float(k + 1) / seg
		var p0 := Vector2(-cos(a0) * m, imposta + sin(a0) * (chiave - imposta))
		var p1 := Vector2(-cos(a1) * m, imposta + sin(a1) * (chiave - imposta))
		var mid := (p0 + p1) * 0.5
		out.append([p0, p1, "mosaico", (Vector2(0, imposta) - mid).normalized()])
	return out


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
		var porta := s >= PORTA_S - PORTA_LARGA * 0.5 - 0.001 and t <= PORTA_S + PORTA_LARGA * 0.5 + 0.001
		var pa := punto(s)
		var pb := punto(t)
		var ra := destra(s)
		var rb := destra(t)
		var prof_a := _profilo(s)
		var prof_b := _profilo(t)
		for k in prof_a.size():
			var a: Array = prof_a[k]
			var b: Array = prof_b[k]
			var q := [_al(pa, ra, a[0]), _al(pa, ra, a[1]), _al(pb, rb, b[1]), _al(pb, rb, b[0])]
			var v: Vector2 = a[3]
			var verso := ra * v.x + Vector3.UP * v.y
			if porta and k == 5:
				# il muro est (a sinistra) sopra la porta del bacino
				q = [_al(pa, ra, Vector2(-muro, imposta)), _al(pa, ra, Vector2(-muro, piano + PORTA_ALTA)),
						_al(pb, rb, Vector2(-muro, piano + PORTA_ALTA)), _al(pb, rb, Vector2(-muro, imposta))]
			_quad(st[a[2]], q, verso)
			_facce_quad(facce, q)
			# il retro, spesso [member spessore]: muri e volta pieni (con una faccia sola l'illuminazione globale
			# passava attraverso e faceva macchie scure sulla volta)
			if k >= 5:
				var vn := verso.normalized()
				_quad(st[a[2]], [q[0] - vn * spessore, q[1] - vn * spessore, q[2] - vn * spessore, q[3] - vn * spessore], -vn)
		# il bordo delle banchine verso il canale: la graniglia sporge di 4 cm sul canale, spessa 6 cm (sopra, davanti e
		# sotto, così da sopra non si vede il retro)
		for lato: float in [-1.0, 1.0]:
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


## Le quote lungo la strada delle sezioni di un pezzo: ogni [constant PASSO_SEZIONE] metri, più i bordi della porta.
func _sezioni(s0: float, s1: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var s := s0
	while s < s1 - 0.001:
		out.append(s)
		for b in [PORTA_S - PORTA_LARGA * 0.5, PORTA_S + PORTA_LARGA * 0.5]:
			if s < b - 0.001 and b < minf(s + PASSO_SEZIONE, s1) - 0.001:
				out.append(b)
		s += PASSO_SEZIONE
	out.append(s1)
	var o := Array(out)
	o.sort()
	return PackedFloat32Array(o)


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
	var w := canale - 0.01
	var s := maxf(s0, -TESTA + 0.01)
	while s < s1 - 0.001:
		var t := minf(s + PASSO_SEZIONE, s1)
		var pa := punto(s)
		var pb := punto(t)
		var ra := destra(s)
		var rb := destra(t)
		var q := [pa - ra * w, pa + ra * w, pb + rb * w, pb - rb * w]
		for j in 4:
			q[j].y = acqua
		var uv := [Vector2(0, s / 5.0), Vector2(1, s / 5.0), Vector2(1, t / 5.0), Vector2(0, t / 5.0)]
		var n: Vector3 = ((q[1] as Vector3) - q[0]).cross((q[3] as Vector3) - q[0])
		var ordine := [0, 2, 1, 0, 3, 2] if n.y > 0.0 else [0, 1, 2, 0, 2, 3]
		for idx in ordine:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[idx])
			st.add_vertex(q[idx])
		s = t
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
		var fondo_qui := fondo if m >= PRESA_FINO else PRESA_FONDO
		var vol := WaterVolume.new()
		vol.name = "Canale_%d" % int(m)
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(canale * 2.0, acqua - fondo_qui, t2 - s2 + 0.3)
		cs.shape = b
		vol.add_child(cs)
		nodo.add_child(vol)
		vol.global_transform = Transform3D(Basis.looking_at(direzione(m), Vector3.UP), Vector3(c.x, (acqua + fondo_qui) * 0.5, c.z))
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


## La fine del tunnel, dopo l'approdo: per ora un muro (il portello viene col finale).
func _fine() -> void:
	var nodo := Node3D.new()
	nodo.name = "Fine"
	add_child(nodo)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facce := PackedVector3Array()
	var s := lunghezza()
	var p := punto(s)
	var r := destra(s)
	var d := direzione(s)
	var pts := [Vector2(-muro, fondo), Vector2(muro, fondo), Vector2(muro, imposta)]
	var seg := 12
	for k in range(1, seg):
		var a := PI * float(k) / seg
		pts.append(Vector2(cos(a) * muro, imposta + sin(a) * (chiave - imposta)))
	pts.append(Vector2(-muro, imposta))
	var tri := Geometry2D.triangulate_polygon(PackedVector2Array(pts))
	for k in range(0, tri.size(), 3):
		var t := [_al(p, r, pts[tri[k]]), _al(p, r, pts[tri[k + 1]]), _al(p, r, pts[tri[k + 2]])]
		_tri(st, t, -d)
		facce.append_array(PackedVector3Array(t))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat_mosaico
	nodo.add_child(mi)
	_corpo(nodo, facce)


## I gradini per risalire dal canale sulle banchine: quattro gradini da 23 cm contro la parete del canale, ogni
## [constant GRADINI_OGNI] metri, alternati sui due lati (dall'acqua si esce sempre).
func _gradini() -> void:
	var nodo := Node3D.new()
	nodo.name = "Gradini"
	add_child(nodo)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facce := PackedVector3Array()
	var s := PRESA_FINO + 4.0
	var lato := 1.0
	var alzata := (piano - fondo) / 4.0
	while s < lunghezza() - 3.0:
		var p := punto(s)
		var r := destra(s)
		var d := direzione(s)
		for k in 4:
			# gradino k (dal basso): largo 1,2 m lungo il canale, contro la parete, sporge 30 cm per ogni gradino sopra
			var alto := fondo + alzata * (k + 1)
			var box_c := p + r * lato * (canale - 0.15 * (4 - k)) + Vector3(0, (fondo + alto) * 0.5 - p.y, 0)
			_scatola(st, facce, box_c, r * lato, d, Vector3(0.3 * (4 - k), alto - fondo, 1.2))
		s += GRADINI_OGNI
		lato = -lato
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat_graniglia
	nodo.add_child(mi)
	_corpo(nodo, facce)


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
