extends Node3D
## Proposta d'aspetto del fiume lento (enigma-ambiente, 19 ottobre), per gli scatti dal motore:
## un pezzo rappresentativo del percorso della nota di enigma-logica (docs/proposte/fiume_infermeria/
## nota_logica.md), non l'anello intero: l'imbarco, il primo bivio con la paratia, il disco a strisce
## e i cartelli d'uscita, l'inizio dei due rami e, in fondo al ramo giusto, l'approdo con la scaletta.
## Al bivio 1 la paratia chiude il ramo giusto (va girata col getto): il cartello verde è acceso
## sopra il ramo giusto, quello sul ramo sbagliato è spento.
## aspetto "A": giungla finta (rocce di vetroresina, palme di plastica, tiki);
## aspetto "B": viaggio sottomarino (tunnel di mosaico blu, oblò illuminati, pesci di vetroresina).
## Niente torcia: si legge con le luci della scena (lampade d'emergenza rosse, cartelli verdi, la
## lampada del bersaglio, la cabina dell'imbarco e, nel B, gli oblò).
## Coordinate: l'imbarco è all'origine, le banchine a quota 0, la corrente va verso -Z.

const DIR := "res://assets/fiume_lento/"
@export_enum("A", "B") var aspetto := "A"

## Canale: larghezza dell'acqua, fondo e pelo.
const W := 3.2
const FONDO := -0.9
const ACQUA := -0.22
const PUNTI_IMBARCO := [Vector3(0, 0, 9), Vector3(0, 0, -18)]
const PUNTI_GIUSTO := [Vector3(1.8, 0, -23), Vector3(3.4, 0, -27.5), Vector3(6.8, 0, -31.5), Vector3(12.5, 0, -34.2), Vector3(18.0, 0, -35.0)]
const PUNTI_SBAGLIATO := [Vector3(-1.8, 0, -23), Vector3(-3.4, 0, -27.5), Vector3(-5.6, 0, -33), Vector3(-6.8, 0, -41), Vector3(-7.0, 0, -50)]
## La conca del bivio, tra la fine dell'imbarco e l'inizio dei rami.
const CONCA := Rect2(-3.4, -23.0, 6.8, 5.0)
## L'approdo: la conca in fondo al ramo giusto e la banchina con la scaletta.
const APPRODO := Rect2(18.0, -37.4, 4.0, 4.8)

var mat_vasca: Material
var mat_banca: Material
var mat_acqua: Material
var mat_roccia: Material


func _ready() -> void:
	seed(1018)
	mat_vasca = load(DIR + "mat_mosaico_blu.tres")
	mat_banca = load(DIR + ("mat_cemento.tres" if aspetto == "A" else "mat_graniglia.tres"))
	mat_acqua = load(DIR + "acqua_fiume.tres")
	mat_roccia = load(DIR + "mat_roccia_ocra.tres")
	_ambiente()
	var bank_imbarco := 2.6
	_canale(PUNTI_IMBARCO, bank_imbarco, bank_imbarco)
	_canale(PUNTI_GIUSTO, 1.4, 1.4)
	_canale(PUNTI_SBAGLIATO, 1.4, 1.4)
	_conca(CONCA)
	_conca(APPRODO, true)
	_banchina_approdo()
	_paratia()
	_bersaglio()
	_cartelli()
	_imbarco()
	_arredo_comune()
	if aspetto == "A":
		_giungla()
	else:
		_sottomarino()


# --- ambiente -----------------------------------------------------------------------------------

func _ambiente() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.0, 0.0, 0.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.2, 0.18, 0.17) if aspetto == "A" else Color(0.11, 0.14, 0.18)
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.1
	e.ssr_enabled = OS.get_environment("NO_SSR") == ""
	e.ssao_enabled = true
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_bloom = 0.05
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.025
	e.volumetric_fog_albedo = Color(0.6, 0.6, 0.6)
	we.environment = e
	add_child(we)


func _glb(nome: String) -> Node3D:
	var p := DIR + nome + ".glb"
	if not ResourceLoader.exists(p):
		push_warning("manca " + p)
		return Node3D.new()
	return (load(p) as PackedScene).instantiate()


func _metti(nome: String, pos: Vector3, rot_y := 0.0, scala := 1.0) -> Node3D:
	var n := _glb(nome)
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * scala
	add_child(n)
	return n


func _luce(pos: Vector3, colore: Color, energia: float, raggio: float, ombre := false) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = colore
	o.light_energy = energia
	o.omni_range = raggio
	o.omni_attenuation = 1.3
	o.shadow_enabled = ombre
	o.light_volumetric_fog_energy = 1.5
	add_child(o)
	return o


## Lampada di servizio a gabbia (la stessa del portone della torre) con la lampadina calda accesa,
## appesa al muro a 3 m: dà la luce neutra che serve a leggere l'ambiente senza torcia.
func _lampada_calda(pos: Vector3, rot_y: float, energia := 3.0) -> void:
	var l := (load("res://assets/enigma_acquari/lampada_gabbia.glb") as PackedScene).instantiate() as Node3D
	l.position = pos
	l.rotation_degrees.y = rot_y
	add_child(l)
	var g := l.find_child("globo", true, false) as MeshInstance3D
	if energia <= 0.0:
		# rotta: il vetro spento e sporco, la gabbia storta
		l.rotation_degrees.z = 9.0
		if g:
			var mr := StandardMaterial3D.new()
			mr.albedo_color = Color(0.25, 0.24, 0.2)
			mr.roughness = 0.3
			g.material_override = mr
		return
	if g:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.85, 0.55)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.7, 0.35)
		m.emission_energy_multiplier = 3.0
		g.material_override = m
	var dir := Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, 0, 1)
	_luce(pos + dir * 0.35, Color(1.0, 0.76, 0.5), energia, 11.0, false)


## Lampada d'emergenza rossa sul muro (modello Meshy + luce), che guarda verso [param verso].
func _lampada_rossa(pos: Vector3, verso: Vector3) -> void:
	var l := _metti("lampada_emergenza", pos)
	l.look_at(pos + verso, Vector3.UP)
	_luce(pos + verso.normalized() * 0.4, Color(1.0, 0.18, 0.12), 2.6, 9.0, false)


# --- canale ---------------------------------------------------------------------------------------

## Curva liscia per i punti (maniglie di Catmull-Rom), campionata ogni 0,5 m.
func _campiona(punti: Array) -> PackedVector3Array:
	var c := Curve3D.new()
	for i in punti.size():
		var p: Vector3 = punti[i]
		var a: Vector3 = punti[maxi(i - 1, 0)]
		var b: Vector3 = punti[mini(i + 1, punti.size() - 1)]
		var t := (b - a) * 0.22
		c.add_point(p, -t, t)
	c.bake_interval = 0.5
	return c.get_baked_points()


## Il canale lungo i punti: fondo e pareti di mosaico, banchine ai lati (larghe [param bs] e [param bd]),
## e il nastro dell'acqua che scorre.
func _canale(punti: Array, bs: float, bd: float) -> void:
	var pts := _campiona(punti)
	var prof := [[-W * 0.5 - bs, 0.0, 1], [-W * 0.5, 0.0, 1], [-W * 0.5, 0.0, 0], [-W * 0.5, FONDO, 0],
			[W * 0.5, FONDO, 0], [W * 0.5, 0.0, 0], [W * 0.5, 0.0, 1], [W * 0.5 + bd, 0.0, 1]]
	var st_v := SurfaceTool.new()
	var st_b := SurfaceTool.new()
	var st_a := SurfaceTool.new()
	var st_l := SurfaceTool.new()
	for s in [st_v, st_b, st_a, st_l]:
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var t0 := _tangente(pts, i)
		var t1 := _tangente(pts, i + 1)
		var r0 := t0.cross(Vector3.UP).normalized()
		var r1 := t1.cross(Vector3.UP).normalized()
		for k in prof.size() - 1:
			var a: Array = prof[k]
			var b: Array = prof[k + 1]
			var st: SurfaceTool = st_b if int(a[2]) == 1 and int(b[2]) == 1 else st_v
			var q := [p0 + r0 * a[0] + Vector3(0, a[1], 0), p0 + r0 * b[0] + Vector3(0, b[1], 0),
					p1 + r1 * b[0] + Vector3(0, b[1], 0), p1 + r1 * a[0] + Vector3(0, a[1], 0)]
			_quad(st, q)
		# acqua
		var d1 := dist + p0.distance_to(p1)
		# la riga di calcare e alghe sulle due pareti, a cavallo del pelo
		for lato in [-1.0, 1.0]:
			var o := W * 0.5 - 0.006
			var a0: Vector3 = p0 + r0 * o * lato
			var a1: Vector3 = p1 + r1 * o * lato
			var lq := [a0 + Vector3(0, ACQUA + 0.25, 0), a1 + Vector3(0, ACQUA + 0.25, 0), a1 + Vector3(0, ACQUA - 0.1, 0), a0 + Vector3(0, ACQUA - 0.1, 0)]
			var luv := [Vector2(dist / 2.0, 0), Vector2(d1 / 2.0, 0), Vector2(d1 / 2.0, 1), Vector2(dist / 2.0, 1)]
			var ordine := [0, 1, 2, 0, 2, 3] if lato > 0 else [0, 2, 1, 0, 3, 2]
			for idx in ordine:
				st_l.set_normal(-r0 * lato)
				st_l.set_uv(luv[idx])
				st_l.add_vertex(lq[idx])
		var w := W * 0.5 - 0.01
		var aq := [p0 - r0 * w + Vector3(0, ACQUA, 0), p0 + r0 * w + Vector3(0, ACQUA, 0),
				p1 + r1 * w + Vector3(0, ACQUA, 0), p1 - r1 * w + Vector3(0, ACQUA, 0)]
		var uv := [Vector2(dist / 5.0, 0), Vector2(dist / 5.0, 1), Vector2(d1 / 5.0, 1), Vector2(d1 / 5.0, 0)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st_a.set_normal(Vector3.UP)
			st_a.set_uv(uv[idx])
			st_a.add_vertex(aq[idx])
		dist = d1
	_mesh(st_v, mat_vasca, true)
	_mesh(st_b, mat_banca, true)
	_mesh(st_a, mat_acqua, false)
	var ml := StandardMaterial3D.new()
	ml.albedo_texture = load(DIR + "texture/linea_calcare.png")
	ml.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ml.cull_mode = BaseMaterial3D.CULL_DISABLED
	ml.roughness = 0.8
	_mesh(st_l, ml, false)


func _tangente(pts: PackedVector3Array, i: int) -> Vector3:
	var a := pts[maxi(i - 1, 0)]
	var b := pts[mini(i + 1, pts.size() - 1)]
	var t := b - a
	t.y = 0.0
	return t.normalized()


func _quad(st: SurfaceTool, q: Array) -> void:
	var n: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
	if n.length() < 0.5:
		n = Vector3.UP
	for idx in [0, 2, 1, 0, 3, 2]:
		st.set_normal(-n)
		st.add_vertex(q[idx])


func _mesh(st: SurfaceTool, m: Material, ombre: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	if not ombre:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Una conca rettangolare d'acqua (il bivio, l'approdo) con fondo e acqua; le pareti le fanno i canali
## e le banchine intorno.
func _conca(r: Rect2, chiusa := false) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	_quad(st, [Vector3(x0, FONDO, z0), Vector3(x1, FONDO, z0), Vector3(x1, FONDO, z1), Vector3(x0, FONDO, z1)])
	# pareti laterali (lungo X) della conca
	for x in [x0, x1]:
		_quad(st, [Vector3(x, 0, z0), Vector3(x, 0, z1), Vector3(x, FONDO, z1), Vector3(x, FONDO, z0)])
	if chiusa:
		_quad(st, [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, FONDO, z0), Vector3(x0, FONDO, z0)])
		_quad(st, [Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3(x0, FONDO, z1), Vector3(x1, FONDO, z1)])
	_mesh(st, mat_vasca, true)
	var sa := SurfaceTool.new()
	sa.begin(Mesh.PRIMITIVE_TRIANGLES)
	var q := [Vector3(x0, ACQUA, z1), Vector3(x1, ACQUA, z1), Vector3(x1, ACQUA, z0), Vector3(x0, ACQUA, z0)]
	var uv := [Vector2(0, 0), Vector2(0, 1), Vector2(r.size.y / 5.0, 1), Vector2(r.size.y / 5.0, 0)]
	for idx in [0, 2, 1, 0, 3, 2]:
		sa.set_normal(Vector3.UP)
		sa.set_uv(uv[idx])
		sa.add_vertex(q[idx])
	_mesh(sa, mat_acqua, false)
	# le banchine intorno alla conca (a quota 0), fino a 3 m
	var sb := SurfaceTool.new()
	sb.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fascia in [Rect2(x0 - 3.0, z0, 3.0, r.size.y), Rect2(x1, z0, 3.0, r.size.y)]:
		var a: Vector2 = fascia.position
		var b: Vector2 = fascia.end
		_quad(sb, [Vector3(a.x, 0, b.y), Vector3(b.x, 0, b.y), Vector3(b.x, 0, a.y), Vector3(a.x, 0, a.y)])
	_mesh(sb, mat_banca, true)


## La banchina dell'approdo con la scaletta che sale dall'acqua e la porta di servizio.
func _banchina_approdo() -> void:
	var sb := SurfaceTool.new()
	sb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x1 := APPRODO.end.x
	var z0 := APPRODO.position.y
	var z1 := APPRODO.end.y
	_quad(sb, [Vector3(x1, 0, z1 + 2.0), Vector3(x1 + 5.0, 0, z1 + 2.0), Vector3(x1 + 5.0, 0, z0 - 2.0), Vector3(x1, 0, z0 - 2.0)])
	_mesh(sb, mat_banca, true)
	# la scaletta sulla parete di fondo della conca
	var sc := _metti("scaletta_banchina", Vector3(x1 - 0.05, FONDO + 0.05, (z0 + z1) * 0.5), -90.0)
	sc.name = "Scaletta"
	# la porta di servizio verso la zona del personale, con la lampada rossa sopra
	# il muro di fondo dell'approdo, di cemento
	var muro := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 4.6, z1 - z0 + 4.0)
	muro.mesh = bm
	muro.material_override = mat_banca
	muro.position = Vector3(x1 + 5.1, 2.3, (z0 + z1) * 0.5)
	add_child(muro)
	if aspetto == "A":
		_porta(Vector3(x1 + 4.9, 0, (z0 + z1) * 0.5), -90.0)
	else:
		_metti("portello", Vector3(x1 + 5.0, 0, (z0 + z1) * 0.5), -90.0)
	_lampada_rossa(Vector3(x1 + 4.85, 2.9, (z0 + z1) * 0.5 + 1.4), Vector3(-1, -0.6, 0))


func _porta(pos: Vector3, rot: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot
	add_child(n)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.38, 0.36)
	m.metallic = 0.6
	m.roughness = 0.55
	var telaio := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 2.2, 0.08)
	telaio.mesh = bm
	telaio.material_override = m
	telaio.position = Vector3(0, 1.1, 0)
	n.add_child(telaio)


# --- bivio -----------------------------------------------------------------------------------------

## La paratia: una chiusa a saracinesca nel suo telaio, attraverso l'imbocco del ramo giusto, chiusa
## (al bivio 1 va girata col getto); il pilastro del naso tra i due rami porta le travi dei cartelli.
func _paratia() -> void:
	var naso := Vector3(0, 0, CONCA.position.y)
	var p := _metti("paratia", Vector3(1.8, FONDO, naso.z + 0.1), 0.0)
	p.name = "Paratia"
	var pil := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.5, 4.6, 0.5)
	pil.mesh = cm
	pil.material_override = mat_banca
	pil.position = naso + Vector3(0, 1.4, -0.3)
	add_child(pil)
	# il lato aperto illuminato: il ramo sbagliato, dove adesso va la corrente
	var luce := SpotLight3D.new()
	luce.position = naso + Vector3(-1.8, 3.4, 1.0)
	luce.look_at_from_position(luce.position, naso + Vector3(-2.2, ACQUA, -2.0))
	luce.light_color = Color(1.0, 0.85, 0.55)
	luce.light_energy = 2.5
	luce.spot_range = 6.0
	luce.spot_angle = 35.0
	add_child(luce)


## Il disco a strisce di 80 cm sul palo, sulla banchina destra, 12-15 m prima del bivio, con la
## lampada d'emergenza che lo illumina.
func _bersaglio() -> void:
	var base := Vector3(W * 0.5 + 0.7, 0, CONCA.end.y + 13.0)
	var palo := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.045
	pm.bottom_radius = 0.05
	pm.height = 2.2
	palo.mesh = pm
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.85, 0.7, 0.1)
	mp.metallic = 0.4
	mp.roughness = 0.5
	palo.material_override = mp
	palo.position = base + Vector3(0, 1.1, 0)
	add_child(palo)
	var disco := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.4
	dm.bottom_radius = 0.4
	dm.height = 0.04
	disco.mesh = dm
	var md := ShaderMaterial.new()
	md.shader = load(DIR + "disco_strisce.gdshader")
	disco.material_override = md
	# il disco guarda chi arriva (+Z) e un po' verso il canale
	disco.position = base + Vector3(-0.1, 2.0, 0.06)
	disco.rotation_degrees = Vector3(90, -20, 0)
	add_child(disco)
	var l := _metti("lampada_emergenza", base + Vector3(0.0, 2.45, -0.15))
	l.look_at(disco.position + Vector3(0, 0, 0.6), Vector3.UP)
	var s := SpotLight3D.new()
	s.position = base + Vector3(0.0, 2.6, 0.5)
	s.look_at_from_position(s.position, disco.position)
	s.light_color = Color(1.0, 0.9, 0.7)
	s.light_energy = 1.2
	s.spot_range = 3.0
	s.spot_angle = 30.0
	add_child(s)


## I cartelli d'uscita sopra l'imbocco dei due rami, sulla trave tra il pilastro e il muro: acceso
## sul ramo giusto, spento (rotto) sullo sbagliato.
func _cartelli() -> void:
	var naso := Vector3(0, 0, CONCA.position.y)
	for lato in [1, -1]:
		var acceso: bool = lato == 1
		var c := Vector3(lato * 1.75, 3.25, naso.z - 0.35)
		# la trave d'acciaio dal pilastro al muro
		var trave := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(3.6, 0.22, 0.18)
		trave.mesh = tb
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.2, 0.2, 0.21)
		mt.metallic = 0.7
		mt.roughness = 0.6
		trave.material_override = mt
		trave.position = Vector3(lato * 1.95, 3.6, naso.z - 0.35)
		add_child(trave)
		_cartello(c + Vector3(0, 0, 0.12), acceso)


func _cartello(pos: Vector3, acceso: bool) -> void:
	var cassa := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.82, 0.42, 0.1)
	cassa.mesh = b
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.75, 0.74, 0.7)
	mc.roughness = 0.6
	cassa.material_override = mc
	cassa.position = pos
	add_child(cassa)
	var faccia := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.76, 0.38)
	faccia.mesh = q
	var mf := StandardMaterial3D.new()
	mf.albedo_texture = load(DIR + "texture/uscita_faccia.jpg")
	if acceso:
		mf.emission_enabled = true
		mf.emission_texture = mf.albedo_texture
		mf.emission_energy_multiplier = 3.0
	else:
		mf.albedo_color = Color(0.22, 0.26, 0.23)
	faccia.material_override = mf
	faccia.position = pos + Vector3(0, 0, 0.052)
	add_child(faccia)
	if acceso:
		_luce(pos + Vector3(0, -0.2, 0.5), Color(0.15, 1.0, 0.4), 2.2, 7.0)


# --- imbarco --------------------------------------------------------------------------------------

func _imbarco() -> void:
	# la ciambella incagliata contro la banchina, pronta
	var c := _metti("ciambella", Vector3(-0.85, ACQUA - 0.12, 4.0), 25.0)
	c.name = "Ciambella"
	_metti("ciambella", Vector3(1.0, ACQUA - 0.12, 7.4), -40.0)
	# la cabina dell'imbarco con la luce ambra, le transenne della fila
	_metti("tornello_imbarco", Vector3(-W * 0.5 - 1.3, 0, 5.2), 90.0)
	_luce(Vector3(-W * 0.5 - 1.3, 1.9, 5.2), Color(1.0, 0.6, 0.25), 2.5, 7.0, true)
	for i in 3:
		_metti("transenna", Vector3(-W * 0.5 - 2.2, 0, 7.5 - i * 2.05), 90.0)
	# lampade d'emergenza lungo il canale (sulle pareti, a 3 m)
	# sulle pareti: nel A davanti alle rocce (sporgono fino a 0,7 m dal muro), nel B sul muro dritto
	# del tunnel, sotto la volta
	var sp := 0.7 if aspetto == "A" else 0.1
	var hl := 3.0 if aspetto == "A" else 2.0
	var mx := W * 0.5 + 2.6 - sp
	for z in [6.0, -8.0]:
		_lampada_rossa(Vector3(-mx, hl, z), Vector3(1, -0.5, 0))
	for z in [-1.0, -14.0]:
		_lampada_rossa(Vector3(mx, hl, z), Vector3(-1, -0.5, 0))
	# le lampade di servizio calde, alternate alle rosse
	_lampada_calda(Vector3(mx, hl, 5.5), -90.0)
	_lampada_calda(Vector3(-mx, hl, 0.5), 90.0)
	_lampada_calda(Vector3(mx, hl, -7.0), -90.0)
	_lampada_calda(Vector3(-mx, hl, -14.5), 90.0)
	_lampada_calda(Vector3(mx, hl, -18.5), -90.0, 3.0)
	# sul pilastro del naso, verso la conca e la paratia
	_lampada_calda(Vector3(0, 2.7, CONCA.position.y - 0.05), 0.0, 3.0)
	# lungo i rami, alternate sui due lati
	var k := 0
	for v in _lungo(PUNTI_GIUSTO, W * 0.5 + 1.4 - sp, 5.0, 2.0):
		_lampada_calda(Vector3(v[0].x, hl, v[0].z), v[1], 3.5)
	for v in _lungo(PUNTI_SBAGLIATO, W * 0.5 + 1.4 - sp, 7.0, 3.0):
		k += 1
		if k % 2 == 0:
			_lampada_calda(Vector3(v[0].x, hl, v[0].z), v[1], 2.5)
	# le luci subacquee nelle pareti del canale
	for pts in [PUNTI_IMBARCO, PUNTI_GIUSTO, PUNTI_SBAGLIATO]:
		for v in _lungo(pts, W * 0.5, 7.0, 1.5):
			_faro_subacqueo(Vector3(v[0].x, FONDO + 0.25, v[0].z), v[1])
	_lampada_calda(Vector3(APPRODO.end.x + 4.75, 3.0, APPRODO.position.y + 0.6), -90.0)


# --- arredo comune: un fiume lento anni '90 abbandonato -----------------------------------------------

func _arredo_comune() -> void:
	# ciambelle alla deriva e incagliate (oltre alle due dell'imbarco)
	for c in [[Vector3(2.3, ACQUA - 0.12, -19.0), 60.0], [Vector3(-2.6, ACQUA - 0.12, -22.0), 10.0],
			[Vector3(5.6, ACQUA - 0.12, -30.4), 130.0], [Vector3(11.2, ACQUA - 0.12, -33.4), 80.0],
			[Vector3(-4.0, ACQUA - 0.12, -30.0), 30.0], [Vector3(20.9, ACQUA - 0.12, -36.3), 15.0]]:
		_metti("ciambella", c[0], c[1])
	# la pila di ciambelle di ricambio accanto alla cabina
	for i in 3:
		_metti("ciambella", Vector3(-W * 0.5 - 1.9, 0.05 + i * 0.27, 1.6), i * 37.0)
	# scalette d'emergenza lungo le pareti
	_metti("scaletta_banchina", Vector3(-W * 0.5 + 0.05, FONDO + 0.05, -6.0), 90.0)
	_metti("scaletta_banchina", Vector3(W * 0.5 - 0.05, FONDO + 0.05, -13.5), -90.0)
	var k := 0
	for v in _lungo(PUNTI_GIUSTO, W * 0.5 - 0.05, 9.0, 6.0):
		k += 1
		if k == 2:
			_metti("scaletta_banchina", Vector3(v[0].x, FONDO + 0.05, v[0].z), v[1])
	# le bocchette della corrente nelle pareti, appena sotto il pelo, alternate sui due lati
	for pts in [PUNTI_IMBARCO, PUNTI_GIUSTO, PUNTI_SBAGLIATO]:
		k = 0
		for v in _lungo(pts, W * 0.5, 6.0, 4.5):
			k += 1
			if k % 3 == 0:
				_metti("bocchetta", Vector3(v[0].x, ACQUA - 0.32, v[0].z), v[1])
	# griglie di scolo sulle banchine, lungo il bordo
	for pts in [PUNTI_IMBARCO, PUNTI_GIUSTO]:
		k = 0
		for v in _lungo(pts, W * 0.5 + 0.45, 8.0, 3.0):
			k += 1
			if k % 2 == 1:
				var g := _metti("griglia_scolo", Vector3(v[0].x, -0.02, v[0].z), v[1])
				g.scale = Vector3(0.45, 0.08, 0.7)   # incassata nella banchina: si vede solo la griglia
				_tingi(g, Color(0.45, 0.45, 0.42))
	# cartelli a pittogrammi sui pali, all'imbarco e all'approdo
	_cartello_palo(Vector3(W * 0.5 + 0.7, 0, 6.2), -40.0, "cartello_tuffi")
	_cartello_palo(Vector3(-W * 0.5 - 0.6, 0, -2.0), 90.0, "cartello_bimbi")
	_cartello_palo(Vector3(APPRODO.end.x + 0.7, 0, APPRODO.end.y + 0.4), -90.0, "cartello_tuffi")
	# il salvagente sul suo palo
	_metti("salvagente", Vector3(W * 0.5 + 0.5, 0, 0.8), -90.0)
	_metti("salvagente", Vector3(APPRODO.end.x + 1.2, 0, APPRODO.position.y - 0.4), 0.0)
	# altoparlanti in alto sulle pareti, col cavo
	var mx := W * 0.5 + 2.6 - (0.7 if aspetto == "A" else 0.05)
	var ha := 3.9 if aspetto == "A" else 2.05
	_metti("altoparlante", Vector3(mx, ha, 1.5), -90.0)
	_metti("altoparlante", Vector3(-mx, ha, -11.0), 90.0)
	# lampade rotte accanto a quelle accese
	_lampada_calda(Vector3(mx, 3.0 if aspetto == "A" else 2.0, -11.5), -90.0, 0.0)
	_lampada_calda(Vector3(-mx, 3.0 if aspetto == "A" else 2.0, 4.0), 90.0, 0.0)
	# le cose perse dai bambini e i detriti, nei posti dove si fermano
	_metti("ciabatta", Vector3(W * 0.5 + 0.9, 0, -3.4), 35.0)
	_metti("ciabatta", Vector3(APPRODO.end.x + 0.6, 0, APPRODO.get_center().y + 0.9), 200.0)
	_metti("paperella", Vector3(-1.1, ACQUA - 0.02, -20.6), 70.0)
	_metti("paperella", Vector3(W * 0.5 + 0.35, 0.0, 3.4), 160.0)
	_metti("secchiello", Vector3(-W * 0.5 - 0.9, 0, -9.6), 20.0)
	_metti("pallone", Vector3(3.0, ACQUA - 0.15, -22.5), 0.0)
	_metti("detriti", Vector3(-W * 0.5 - 1.4, 0, 3.6), 30.0)
	_metti("detriti", Vector3(W * 0.5 + 1.5, 0, -16.8), 110.0)
	_metti("detriti", Vector3(APPRODO.end.x + 3.8, 0, APPRODO.position.y + 0.7), 0.0)
	_metti("detriti", Vector3(9.6, 0, -35.9), 200.0)
	# il ramo giusto: un salvagente, un cartello, detriti e una lampada rotta anche qui
	_metti("salvagente", Vector3(8.6, 0, -35.3), 10.0)
	_cartello_palo(Vector3(9.6, 0, -30.9), -150.0, "cartello_bimbi")
	_metti("detriti", Vector3(6.6, 0, -29.3), 70.0)
	_metti("ciabatta", Vector3(11.0, 0, -31.8), 120.0)
	_metti("transenna", Vector3(13.6, 0, -32.2), -8.0)


## Moltiplica il colore dei materiali del modello.
func _tingi(n: Node3D, c: Color) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var s := m.mesh.surface_get_material(i) as StandardMaterial3D
			if s:
				s = s.duplicate()
				s.albedo_color = c
				m.set_surface_override_material(i, s)


## Palo zincato con un cartello quadrato a pittogrammi (50 cm) in cima, verso [param rot_y].
func _cartello_palo(pos: Vector3, rot_y: float, tex: String) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	var palo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.035
	cm.height = 2.2
	palo.mesh = cm
	var mz := StandardMaterial3D.new()
	mz.albedo_color = Color(0.55, 0.56, 0.55)
	mz.metallic = 0.8
	mz.roughness = 0.5
	palo.material_override = mz
	palo.position = Vector3(0, 1.1, 0)
	n.add_child(palo)
	var lastra := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.52, 0.52, 0.015)
	lastra.mesh = b
	lastra.material_override = mz
	lastra.position = Vector3(0, 1.85, 0.045)
	n.add_child(lastra)
	var f := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	f.mesh = q
	var mf := StandardMaterial3D.new()
	mf.albedo_texture = load(DIR + "texture/" + tex + ".jpg")
	mf.roughness = 0.6
	f.material_override = mf
	f.position = Vector3(0, 1.85, 0.054)
	n.add_child(f)


## Punti a passo [param passo] lungo il canale, dal tratto [param inizio] (m), a distanza [param d] dal
## centro sui due lati: [posizione a quota 0, rotazione Y (gradi) che guarda il canale].
func _lungo(punti: Array, d: float, passo: float, inizio: float) -> Array:
	var pts := _campiona(punti)
	var out := []
	var dist := 0.0
	var prossimo := inizio
	for i in pts.size() - 1:
		dist += pts[i].distance_to(pts[i + 1])
		if dist < prossimo:
			continue
		prossimo += passo
		var dx := _tangente(pts, i).cross(Vector3.UP).normalized()
		for lato in [1.0, -1.0]:
			var verso: Vector3 = -dx * lato
			out.append([pts[i] + dx * lato * d, rad_to_deg(atan2(verso.x, verso.z))])
	return out


## Faro subacqueo nella parete del canale: oblò bianco sotto il pelo e luce nell'acqua.
func _faro_subacqueo(pos: Vector3, rot_y: float) -> void:
	var dir := Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, 0, 1)
	var f := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.1
	cm.height = 0.03
	f.mesh = cm
	var m := StandardMaterial3D.new()
	var col := Color(0.75, 0.95, 1.0) if aspetto == "A" else Color(0.4, 0.8, 1.0)
	# senza ombreggiatura e scuro: la sua stessa luce lo bruciava in una macchia bianca sotto il pelo
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col * 0.45
	f.material_override = m
	f.position = pos + dir * 0.01
	f.rotation_degrees = Vector3(90, rot_y, 0)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(f)
	var o := _luce(pos + dir * 0.4, col, 1.6, 4.5)
	o.light_specular = 0.0   # da sotto il pelo farebbe una macchia bianca sull'acqua


# --- aspetto A: giungla finta -----------------------------------------------------------------------

func _giungla() -> void:
	# pareti di roccia finta lungo il canale dell'imbarco e dei rami, dietro le banchine
	for z in [8.0, 4.0, 0.0, -4.0, -8.0, -12.0, -16.0]:
		_roccia(Vector3(-W * 0.5 - 2.6, 0, z), 90.0)
		_roccia(Vector3(W * 0.5 + 2.6, 0, z), -90.0)
	for p in [[Vector3(-4.0, 0, -21.5), 90.0], [Vector3(4.0, 0, -21.5), -90.0], [Vector3(0.0, 0, -25.6), 180.0]]:
		_roccia(p[0], p[1])
	for pts in [PUNTI_GIUSTO, PUNTI_SBAGLIATO]:
		for v in _lungo(pts, W * 0.5 + 1.4, 3.6, 2.5):
			_roccia(v[0], v[1])
	# palme di plastica nelle fioriere sulle banchine, il totem e la capanna all'imbarco
	for p in [Vector3(-W * 0.5 - 1.6, 0, -1.0), Vector3(W * 0.5 + 1.5, 0, 3.0), Vector3(W * 0.5 + 1.6, 0, -10.0),
			Vector3(-W * 0.5 - 1.7, 0, -14.5), Vector3(3.2, 0, -21.4)]:
		_metti("palma_finta", p, randf() * 360.0)
	_metti("totem_tiki", Vector3(W * 0.5 + 2.0, 0, 4.6), -100.0)
	_metti("capanna_tiki", Vector3(-W * 0.5 - 1.2, 0, 9.4), 90.0)
	_soffitto()
	# la tettoia di paglia sopra la cabina dell'imbarco
	var t := _metti("tettoia_paglia", Vector3(-W * 0.5 - 1.3, 0, 5.2), 90.0)
	t.scale = Vector3.ONE * 0.8
	# liane che pendono dalle rocce, fiori di plastica nelle fioriere
	for p in [Vector3(-3.55, 4.6, 6.5), Vector3(3.55, 4.6, -2.5), Vector3(-3.55, 4.6, -6.5), Vector3(3.55, 4.6, -9.0),
			Vector3(-3.55, 4.6, -16.0), Vector3(3.5, 4.6, -20.5)]:
		_metti("liane", p, -90.0 if p.x > 0 else 90.0)
	for v in _lungo(PUNTI_GIUSTO, W * 0.5 + 0.75, 7.0, 3.0):
		if v[0].distance_to(Vector3(12.5, 0, -34.2)) > 2.0:
			_metti("liane", Vector3(v[0].x, 4.4, v[0].z) + Basis(Vector3.UP, deg_to_rad(v[1])) * Vector3(0, 0, -0.2), v[1])
	for p in [Vector3(-3.4, 0, -4.4), Vector3(3.4, 0, -6.4), Vector3(-3.4, 0, -13.0), Vector3(4.6, 0, -19.2), Vector3(-4.6, 0, -20.0)]:
		_metti("fiori", p, randf() * 360.0)
	# maschere tiki sui pali, il pappagallo e la scimmia di vetroresina
	_maschera_palo(Vector3(W * 0.5 + 1.0, 0, -17.3), -90.0)
	_maschera_palo(Vector3(-W * 0.5 - 1.1, 0, 2.6), 90.0)
	_maschera_palo(Vector3(APPRODO.end.x + 0.8, 0, APPRODO.position.y + 0.3), -90.0)
	_metti("pappagallo", Vector3(W * 0.5 + 1.3, 0, -4.6), -110.0)
	_metti("scimmia", Vector3(-W * 0.5 - 1.5, 0, -11.2), 100.0)
	_metti("pappagallo", Vector3(10.6, 0, -31.6), -160.0)
	_metti("fiori", Vector3(7.6, 0, -29.6), 0.0)
	_metti("fiori", Vector3(15.5, 0, -36.6), 90.0)
	# corrimano di bambù lungo le banchine della conca e dell'approdo
	for p in [[Vector3(3.6, 0, -19.6), 90.0], [Vector3(-3.6, 0, -19.6), 90.0], [Vector3(APPRODO.end.x + 0.25, 0, APPRODO.position.y - 0.9), 90.0]]:
		_metti("corrimano_bambu", p[0], p[1])
	# luci tiki calde, deboli, come fiaccole rimaste accese
	_luce(Vector3(W * 0.5 + 1.9, 2.7, 4.6), Color(1.0, 0.55, 0.2), 1.2, 5.0)


## Il soffitto del capannone sopra la giungla finta: lamiera grecata, capriate reticolari d'acciaio
## ogni 5 m, arcarecci, il condotto dell'aria sopra il canale e le lampade a campana appese (due
## accese deboli, le altre spente o rotte).
const TETTO := 7.6
const AREA_TETTO := Rect2(-10.0, -52.0, 38.0, 64.0)


func _soffitto() -> void:
	var ferro := StandardMaterial3D.new()
	ferro.albedo_color = Color(0.2, 0.21, 0.2)
	ferro.metallic = 0.7
	ferro.roughness = 0.65
	var lamiera := StandardMaterial3D.new()
	lamiera.albedo_color = Color(0.17, 0.18, 0.18)
	lamiera.metallic = 0.5
	lamiera.roughness = 0.7
	var a := AREA_TETTO
	_scatola(Vector3(a.size.x, 0.06, a.size.y), Vector3(a.get_center().x, TETTO + 0.03, a.get_center().y), lamiera)
	# capriate lungo X ogni 5 m: correnti sopra e sotto, montanti e diagonali
	var z := a.position.y + 2.0
	while z < a.end.y:
		_scatola(Vector3(a.size.x, 0.18, 0.14), Vector3(a.get_center().x, TETTO - 0.12, z), ferro)
		_scatola(Vector3(a.size.x, 0.14, 0.12), Vector3(a.get_center().x, TETTO - 1.1, z), ferro)
		var x := a.position.x
		while x < a.end.x:
			_scatola(Vector3(0.08, 0.9, 0.08), Vector3(x, TETTO - 0.6, z), ferro)
			var d := _scatola(Vector3(0.06, 1.35, 0.06), Vector3(x + 1.0, TETTO - 0.6, z), ferro)
			d.rotation_degrees.z = 48.0 if int(x) % 4 == 0 else -48.0
			x += 2.0
		z += 5.0
	# arcarecci lungo Z
	var xa := a.position.x + 1.0
	while xa < a.end.x:
		_scatola(Vector3(0.1, 0.16, a.size.y), Vector3(xa, TETTO - 0.3, a.get_center().y), ferro)
		xa += 3.0
	# il condotto dell'aria sopra il canale dell'imbarco, con le staffe appese alle capriate
	var zinco := StandardMaterial3D.new()
	zinco.albedo_color = Color(0.45, 0.46, 0.45)
	zinco.metallic = 0.85
	zinco.roughness = 0.75
	var cond := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.4
	cm.height = 30.0
	cond.mesh = cm
	cond.material_override = zinco
	cond.position = Vector3(-2.6, TETTO - 1.75, -6.0)
	cond.rotation_degrees.x = 90.0
	add_child(cond)
	z = -20.0
	while z < 9.0:
		_scatola(Vector3(0.04, 0.6, 0.04), Vector3(-2.6, TETTO - 1.2, z), ferro)
		z += 5.0
	# lampade a campana: appese alle capriate, su canale e approdo
	var punti := [[Vector3(0.6, 0, 3.0), true], [Vector3(-0.4, 0, -8.0), false], [Vector3(0.8, 0, -18.0), false],
			[Vector3(7.0, 0, -32.0), true], [Vector3(14.0, 0, -35.0), false], [Vector3(21.0, 0, -35.0), false]]
	for pt in punti:
		var p: Vector3 = pt[0]
		var zc: float = a.position.y + 2.0 + roundf((p.z - a.position.y - 2.0) / 5.0) * 5.0
		var catena := _scatola(Vector3(0.02, 1.9, 0.02), Vector3(p.x, TETTO - 2.05, zc), ferro)
		catena.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := _metti("lampada_capannone", Vector3(p.x, TETTO - 3.0, zc))
		if pt[1]:
			_luce(Vector3(p.x, TETTO - 3.3, zc), Color(1.0, 0.8, 0.55), 2.5, 9.0, false)
		else:
			l.rotation_degrees.z = randf_range(-6.0, 6.0)


func _scatola(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _maschera_palo(pos: Vector3, rot_y: float) -> void:
	var palo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.11
	cm.height = 2.3
	palo.mesh = cm
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.38, 0.27, 0.17)
	mp.roughness = 0.85
	palo.material_override = mp
	palo.position = pos + Vector3(0, 1.15, 0)
	add_child(palo)
	var dir := Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, 0, 1)
	_metti("maschera_tiki", pos + Vector3(0, 1.45, 0) + dir * 0.1, rot_y)


## Un pannello di roccia finta (4,2 x 3,2 m, alzato a 4,9) col retro sul muro; ruotato e specchiato a
## caso perché non si veda che è sempre lo stesso.
func _roccia(pos: Vector3, rot: float) -> void:
	var r := _metti("roccia_parete", pos, rot)
	# il dettaglio della roccia lo dà la texture (il modello ha facce grandi)
	for mi in r.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat_roccia
	var sx := 1.0 if randf() < 0.5 else -1.0
	r.scale = Vector3(sx * randf_range(0.95, 1.1), randf_range(1.4, 1.6), 1.0)


# --- aspetto B: viaggio sottomarino -------------------------------------------------------------------

## Le tinte dei coralli di vetroresina (il modello è color sabbia).
const CORALLI := [Color(1.0, 0.55, 0.6), Color(1.0, 0.62, 0.35), Color(0.8, 0.55, 1.0)]


func _sottomarino() -> void:
	var mat_tunnel: Material = load(DIR + "mat_mosaico_blu.tres")
	# volta del tunnel sopra canale e banchine dell'imbarco
	_volta(PUNTI_IMBARCO, W * 0.5 + 2.6, mat_tunnel)
	_volta(PUNTI_GIUSTO, W * 0.5 + 1.4, mat_tunnel)
	_volta(PUNTI_SBAGLIATO, W * 0.5 + 1.4, mat_tunnel)
	# la volta continua sopra la conca del bivio, e una sopra l'approdo
	_volta([Vector3(0, 0, -17.6), Vector3(0, 0, CONCA.position.y - 0.2)], W * 0.5 + 2.6, mat_tunnel)
	var za := APPRODO.get_center().y
	_volta([Vector3(APPRODO.position.x - 0.4, 0, za), Vector3(APPRODO.end.x + 5.2, 0, za)], 3.6, mat_tunnel)
	# oblò illuminati sulle pareti (il mare finto dietro), pesci e tartaruga di vetroresina
	for z in [7.0, 2.0, -3.0, -8.0, -13.0]:
		_oblo(Vector3(-W * 0.5 - 2.55, 1.6, z), Vector3(1, 0, 0))
		_oblo(Vector3(W * 0.5 + 2.55, 1.6, z + 2.5), Vector3(-1, 0, 0))
	# i pesci sul loro piedistallo sulle banchine, la tartaruga appesa alla volta con i cavi
	_metti("pesce_vetroresina", Vector3(-3.3, 0, -6.0), 90.0)
	_metti("pesce_vetroresina", Vector3(3.3, 0, -1.0), -90.0, 0.8)
	_appeso("tartaruga", Vector3(2.6, 2.6, -14.0), -100.0)
	_metti("palombaro", Vector3(-W * 0.5 - 1.6, 0, 8.2), 60.0)
	# coralli lungo le pareti, l'ancora, il forziere, le reti con le stelle marine
	for p in [Vector3(-3.6, 0, 4.5), Vector3(3.6, 0, -4.0), Vector3(-3.6, 0, -13.5), Vector3(3.6, 0, -17.0), Vector3(4.8, 0, -20.0)]:
		_tingi(_metti("corallo", p, randf() * 360.0), CORALLI[randi() % 3])
	for v in _lungo(PUNTI_GIUSTO, W * 0.5 + 1.0, 8.0, 4.0):
		_tingi(_metti("corallo", v[0], randf() * 360.0), CORALLI[randi() % 3])
	_metti("forziere", Vector3(10.5, 0, -31.5), -150.0)
	_metti("ancora", Vector3(8.0, 0, -35.6), 10.0)
	_metti("ancora", Vector3(-3.75, 0, -2.6), 90.0)
	_metti("forziere", Vector3(3.4, 0, -8.3), -100.0)


## Un pesce di vetroresina appeso con due cavi d'acciaio alla volta del tunnel dell'imbarco.
func _appeso(nome: String, pos: Vector3, rot: float, scala := 1.0) -> void:
	_metti(nome, pos, rot, scala)
	var r := W * 0.5 + 2.6
	var tetto := 2.2 + sqrt(maxf(1.0 - pow(pos.x / r, 2.0), 0.0)) * r * 0.55
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.5, 0.5, 0.52)
	mc.metallic = 0.8
	mc.roughness = 0.4
	for dz in [-0.45, 0.45]:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.008
		cm.bottom_radius = 0.008
		var alto := tetto - pos.y
		cm.height = alto
		c.mesh = cm
		c.material_override = mc
		c.position = pos + Vector3(0, alto * 0.5 + 0.1, dz * scala)
		add_child(c)


## Volta a botte di raggio [param r] sopra i punti, dalle banchine in su.
func _volta(punti: Array, r: float, m: Material) -> void:
	var pts := _campiona(punti)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 16
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var r0 := _tangente(pts, i).cross(Vector3.UP).normalized()
		var r1 := _tangente(pts, i + 1).cross(Vector3.UP).normalized()
		for lato in [1.0, -1.0]:
			var w0: Vector3 = p0 + r0 * r * lato
			var w1: Vector3 = p1 + r1 * r * lato
			var q := [w0, w1, w1 + Vector3(0, 2.2, 0), w0 + Vector3(0, 2.2, 0)]
			_quad(st, [q[1], q[0], q[3], q[2]] if lato > 0 else q)
		for k in seg:
			var a0 := PI * float(k) / seg
			var a1 := PI * float(k + 1) / seg
			# pareti dritte fino a 2,2 m, poi l'arco
			var q := [_arco(p0, r0, r, a0), _arco(p0, r0, r, a1), _arco(p1, r1, r, a1), _arco(p1, r1, r, a0)]
			_quad(st, q)
	_mesh(st, m, true)


func _arco(p: Vector3, destra: Vector3, r: float, a: float) -> Vector3:
	return p + destra * cos(a) * r + Vector3(0, 2.2 + sin(a) * r * 0.55, 0)


## Oblò: anello d'ottone e vetro con il mare finto illuminato dietro (luce azzurra).
func _oblo(pos: Vector3, verso: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	n.look_at(pos + verso, Vector3.UP)
	var anello := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.34
	tm.outer_radius = 0.44
	anello.mesh = tm
	anello.rotation_degrees.x = 90
	var mo := StandardMaterial3D.new()
	mo.albedo_color = Color(0.55, 0.42, 0.2)
	mo.metallic = 0.85
	mo.roughness = 0.35
	anello.material_override = mo
	n.add_child(anello)
	var vetro := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.35
	cm.height = 0.02
	vetro.mesh = cm
	vetro.rotation_degrees.x = 90
	var mv := StandardMaterial3D.new()
	mv.albedo_color = Color(0.05, 0.25, 0.35)
	mv.emission_enabled = true
	mv.emission = Color(0.1, 0.45, 0.6)
	mv.emission_energy_multiplier = 1.4
	mv.roughness = 0.1
	vetro.material_override = mv
	vetro.position.z = -0.02
	n.add_child(vetro)
	_luce(pos + verso * 0.5, Color(0.2, 0.6, 0.9), 0.8, 4.0)
