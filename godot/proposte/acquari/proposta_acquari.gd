extends Node3D
## Proposta per l'utente (18 ottobre): l'enigma degli acquari nella sala principale, montato al volo
## dentro la sala vera per gli scatti (godot/tests/scatti_acquari.gd). Non è nel gioco.
## Tre acquari in fila: giallo | miscuglio (vuoto, poi verde o torbido) | blu, la valvola rossa sotto
## quello del miscuglio, il disegno dei bambini attaccato col nastro al suo vetro, e le lampade del
## portone della torre (spente o accese).
## stile: "A" vasca col telaio di metallo verniciato su un basamento, "B" grande cilindro di vetro
## tra base e coperchio di acciaio. posizione: 1 davanti alla serranda del magazzino (sud-ovest),
## 2 a est verso il portone della torre. lampade: "lampadine" (fila di lampadine da luna park intorno
## al portone) o "gabbia" (due lampade a gabbia ai lati).

const DIR := "res://assets/enigma_acquari/"
const AcquarioAcquaScript := preload("res://assets/enigma_acquari/acquario_acqua.gd")

@export_enum("A", "B") var stile := "A"
@export_enum("1", "2") var posizione := "1"
@export_enum("lampadine", "gabbia") var lampade := "lampadine"
@export var lampade_accese := false
## Il contenuto dell'acquario del miscuglio: "vuoto", "verde" o "torbido".
@export var miscuglio := "vuoto"
@export var miscuglio_pieno := 0.85
## Opzione 3: anche il giallo e il blu bassi come quello del miscuglio.
@export var tutti_bassi := false

## Dove sta la fila e dove guarda (verso il giocatore): [centro, angolo in gradi attorno a Y].
const POSIZIONI := {
	"1": [Vector3(-11.6, 0.0, 9.7), 0.0],      # davanti alla serranda, a nord della scia rosa (z 12,5); guarda a sud
	"2": [Vector3(15.6, 0.0, -3.6), -90.0],    # a est, verso il portone; guarda a ovest (la sala)
}
## Il miscuglio è basso (bordo a 0,8 m: la lancia tenuta in basso non versa più su) e sta un poco più
## avanti, con almeno 1,2 m liberi ai lati, per avvicinarsi e versare senza essere chiusi dagli alti.
const AVANTI_BASSO := 0.35
const SPAZIO := 1.2

var acque: Array[AcquarioAcqua] = []


func _ready() -> void:
	var fila := Node3D.new()
	fila.name = "Acquari"
	add_child(fila)
	var p: Array = POSIZIONI[posizione]
	fila.position = p[0]
	fila.rotation_degrees.y = p[1]
	# larghezze: A alto 2,0 / basso 2,2; B alto 1,3 / basso 1,9 (con piedi e raccordi)
	var largo_alto := 2.0 if stile == "A" else 1.3
	var largo_basso := 2.2 if stile == "A" else 1.9
	var lato := largo_basso if tutti_bassi else largo_alto
	var passo := (lato + largo_basso) * 0.5 + SPAZIO
	var colori := ["giallo", miscuglio, "blu"]
	for i in 3:
		var t := Node3D.new()
		t.name = ["AcquarioGiallo", "AcquarioMiscuglio", "AcquarioBlu"][i]
		t.position.x = (i - 1) * passo
		var basso := i == 1 or tutti_bassi
		if i == 1:
			t.position.z = AVANTI_BASSO
		fila.add_child(t)
		if stile == "A":
			_vasca_a(t, colori[i], i == 1, basso)
		else:
			_cilindro_b(t, colori[i], i == 1, basso)
		if i == 0:
			_disegno(t, basso)
	_lampade_portone()


func _glb(nome: String) -> Node3D:
	return (load(DIR + nome + ".glb") as PackedScene).instantiate()


func _acqua(parent: Node3D, pos: Vector3, size: Vector3, colore: String, cil: bool) -> AcquarioAcqua:
	var a := AcquarioAcquaScript.new() as AcquarioAcqua
	a.name = "Acqua"
	a.position = pos
	a.forma = 1 if cil else 0
	a.inner_size = size
	if colore == "vuoto":
		a.style = load(DIR + "acqua_verde.tres")
		a.fill = 0.0
	else:
		a.style = load(DIR + "acqua_%s.tres" % colore)
		a.fill = miscuglio_pieno if parent.name == "AcquarioMiscuglio" else 0.86
	parent.add_child(a)
	acque.append(a)
	return a


## La luce dentro l'acquario, sotto il bordo di sopra: fa leggere il colore dell'acqua nel buio.
func _luce_interna(parent: Node3D, y: float) -> void:
	var l := SpotLight3D.new()
	l.name = "LuceAcquario"
	l.position = Vector3(0.0, y, 0.0)
	l.rotation_degrees.x = -90.0
	l.light_color = Color(1.0, 0.95, 0.86)
	l.light_energy = 4.0
	l.spot_range = 2.8
	l.spot_angle = 75.0
	l.spot_attenuation = 0.8
	l.light_volumetric_fog_energy = 0.4
	parent.add_child(l)


# --- stile A ---------------------------------------------------------------------------------------
# alto: basamento 2,0 x 0,5 x 0,93 m e sopra il telaio (2,0 x 1,63 x 0,93), interno dei vetri
# 1,76 x 1,43 x 0,64 dal fondo della vaschetta della base del telaio (0,10 m) in su.
# basso: basamento abbassato e allargato (2,2 x 0,4 x 1,16) e sopra la stessa vasca tagliata
# (vasca_bassa_telaio, alta 0,40): bordo a 0,80 m, vetro da 0,50 a 0,72 (misure in assets_src/enigma_acquari).
const A_BASE := 0.5
const A_BASSO_SCALA := Vector3(1.1, 1.0, 1.25)
const A_BASSO_BASE := 0.4

func _vasca_a(t: Node3D, colore: String, miscuglio_: bool, basso: bool) -> void:
	var base := _glb("basamento_vasca")
	t.add_child(base)
	if not basso:
		var telaio := _glb("vasca_telaio")
		telaio.position.y = A_BASE
		t.add_child(telaio)
		_acqua(t, Vector3(0.0, A_BASE + 0.10, 0.0), Vector3(1.76, 1.43, 0.64), colore, false)
		_luce_interna(t, A_BASE + 1.50)
		return
	base.scale = Vector3(A_BASSO_SCALA.x, A_BASSO_BASE / A_BASE, A_BASSO_SCALA.z)
	var telaio := _glb("vasca_bassa_telaio")
	telaio.position.y = A_BASSO_BASE
	telaio.scale = A_BASSO_SCALA
	t.add_child(telaio)
	_acqua(t, Vector3(0.0, A_BASSO_BASE + 0.10, 0.0), Vector3(1.76 * 1.1, 0.215, 0.64 * 1.25), colore, false)
	_luce_alta(t, A_BASSO_BASE + 1.6)
	if miscuglio_:
		# la bocca flangiata del basamento: x 0,5, alta 0,27, davanti a z 0,465 (prima della scala)
		_valvola(t, 0.5 * A_BASSO_SCALA.x, 0.465 * A_BASSO_SCALA.z, 0.27 * A_BASSO_BASE / A_BASE, 0.72)


# --- stile B ---------------------------------------------------------------------------------------
# alto: base 0,85 m, vetro di 1,1 m di diametro alto 1,3 m, coperchio sopra.
# basso: base tagliata a 0,40 m e allargata x1,45 (vetro di 1,6 m), vetro alto 0,38, anello sul bordo a 0,8 m.
const B_BASE := 0.849
const B_VETRO := 1.3
const B_BASSO_SCALA := 1.45
const B_BASSO_BASE := 0.40
const B_BASSO_VETRO := 0.38

func _mat_rosso() -> StandardMaterial3D:
	var m := load("res://assets/materials/sala/metallo_verniciato.tres").duplicate() as StandardMaterial3D
	m.albedo_color = Color(0.95, 0.32, 0.26)
	return m


func _cilindro_b(t: Node3D, colore: String, miscuglio_: bool, basso: bool) -> void:
	if basso:
		var base := _glb("cilindro_base_bassa")
		base.scale = Vector3(B_BASSO_SCALA, 1.0, B_BASSO_SCALA)
		t.add_child(base)
		var r := 0.55 * B_BASSO_SCALA
		_acqua(t, Vector3(0.0, B_BASSO_BASE, 0.0), Vector3(r * 2.0, B_BASSO_VETRO, r * 2.0), colore, true)
		# l'anello di acciaio sul bordo del vetro
		var anello := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.025
		tm.outer_radius = r + 0.045
		tm.rings = 64
		anello.mesh = tm
		anello.scale.y = 0.6
		anello.material_override = _mat_rosso()
		anello.position.y = B_BASSO_BASE + B_BASSO_VETRO + 0.006
		t.add_child(anello)
		_luce_alta(t, B_BASSO_BASE + 1.6)
		if miscuglio_:
			_valvola(t, 0.0, r - 0.02, 0.21, 0.7)
		return
	t.add_child(_glb("cilindro_base"))
	var cop := _glb("cilindro_coperchio")
	cop.position.y = B_BASE + B_VETRO
	t.add_child(cop)
	_acqua(t, Vector3(0.0, B_BASE, 0.0), Vector3(1.1, B_VETRO, 1.1), colore, true)
	_luce_interna(t, B_BASE + B_VETRO - 0.05)
	# quattro tiranti tra base e coperchio
	var mat := load("res://assets/materials/sala/metallo_verniciato.tres") as Material
	for k in 4:
		var a := deg_to_rad(45.0 + 90.0 * k)
		var r := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.022
		cm.bottom_radius = 0.022
		cm.height = B_VETRO + 0.2
		r.mesh = cm
		r.material_override = mat
		r.position = Vector3(cos(a) * 0.6, B_BASE + B_VETRO * 0.5, sin(a) * 0.6)
		t.add_child(r)


## Il disegno dei bambini sul vetro del giallo, dal lato del miscuglio, all'altezza degli occhi; se il
## giallo è basso, sul davanti del suo basamento.
func _disegno(t: Node3D, basso: bool) -> void:
	if stile == "A":
		if basso:
			_disegno_piano(t, Vector3(-0.45, 0.2, 0.58 + 0.012), 0.75)
		else:
			_disegno_piano(t, Vector3(0.5, A_BASE + 0.85, 0.332 + 0.012), 1.0)
	else:
		if basso:
			_disegno_curvo(t, 0.55 * B_BASSO_SCALA + 0.03, 0.2, -25.0, 0.75)
		else:
			_disegno_curvo(t, 0.562 + 0.014, B_BASE + 0.6, 28.0, 1.0)


## Luce di servizio sopra un acquario basso aperto (una plafoniera del soffitto non c'è: la luce è
## quella del buio rosso più questa, debole, per leggere il colore da sopra).
func _luce_alta(parent: Node3D, y: float) -> void:
	var l := SpotLight3D.new()
	l.name = "LuceAcquario"
	l.position = Vector3(0.0, y, 0.0)
	l.rotation_degrees.x = -90.0
	l.light_color = Color(1.0, 0.95, 0.86)
	l.light_energy = 3.0
	l.spot_range = 1.45   # arriva all'acqua ma non al pavimento (senza ombre passerebbe la base)
	l.spot_angle = 50.0
	l.spot_attenuation = 0.8
	l.light_volumetric_fog_energy = 0.0
	parent.add_child(l)


## La valvola rossa: tubo in avanti (verso il giocatore), la flangia di dietro contro la base,
## il volantino in alto; sotto la bocca davanti, la griglia dello scarico a pavimento.
func _valvola(t: Node3D, x: float, z_base: float, y: float, s := 0.85) -> void:
	var v := _glb("valvola_rossa")
	v.name = "ValvolaRossa"
	v.scale = Vector3.ONE * s
	# nel modello il tubo è lungo X (1,1 m) e il volantino sta in alto: si gira il tubo su Z
	v.rotation_degrees.y = 90.0
	v.position = Vector3(x, y, z_base + 0.55 * s)
	t.add_child(v)
	var g := MeshInstance3D.new()
	g.name = "Scarico"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.26
	cm.bottom_radius = 0.26
	cm.height = 0.01
	g.mesh = cm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/ambiente/dettagli/gltf/texture/Fence008A_Color-Fence008A_Opacity.png")
	gm.albedo_color = Color(0.25, 0.24, 0.22)
	gm.metallic = 0.8
	gm.roughness = 0.5
	gm.uv1_scale = Vector3(1.4, 1.4, 1.4)
	g.material_override = gm
	g.position = Vector3(x, 0.004, z_base + 1.1 * s + 0.12)
	t.add_child(g)
	var buco := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.24
	bm.bottom_radius = 0.24
	bm.height = 0.004
	buco.mesh = bm
	var nero := StandardMaterial3D.new()
	nero.albedo_color = Color(0.01, 0.01, 0.01)
	buco.material_override = nero
	buco.position = g.position + Vector3(0, -0.002, 0)
	t.add_child(buco)


func _mat_disegno() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(DIR + "disegno_bambini.jpg")
	m.albedo_color = Color(0.86, 0.84, 0.78)
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # il foglio piegato sul cilindro
	return m


func _nastro(parent: Node3D, pos: Vector3, rot: float, n: Vector3) -> void:
	var q := MeshInstance3D.new()
	var pm := QuadMesh.new()
	pm.size = Vector2(0.075, 0.028)
	q.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.72, 0.55, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	q.material_override = m
	parent.add_child(q)
	q.position = pos
	q.look_at(q.global_position + parent.global_basis * n, Vector3.UP)
	q.rotate_object_local(Vector3.FORWARD, rot)
	q.rotate_object_local(Vector3.UP, PI)


## Il disegno (30 x 40 cm) attaccato col nastro di carta al vetro davanti della vasca A.
func _disegno_piano(t: Node3D, pos: Vector3, sc: float) -> void:
	var d := Node3D.new()
	d.name = "Disegno"
	d.position = pos
	d.rotation_degrees.z = 2.5
	d.scale = Vector3.ONE * sc
	t.add_child(d)
	var f := MeshInstance3D.new()
	var pm := QuadMesh.new()
	pm.size = Vector2(0.3, 0.4)
	f.mesh = pm
	f.material_override = _mat_disegno()
	d.add_child(f)
	for c in [Vector2(-0.14, 0.19), Vector2(0.14, 0.19), Vector2(-0.14, -0.19), Vector2(0.14, -0.19)]:
		_nastro(d, Vector3(c.x, c.y, 0.002), deg_to_rad(40.0 if c.x * c.y > 0 else -40.0), Vector3(0, 0, 1))


## Il disegno piegato sul vetro del cilindro B, centrato all'angolo [param ang] (gradi, 0 = davanti).
func _disegno_curvo(t: Node3D, r: float, y: float, ang: float, sc: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.3 * sc
	var h := 0.4 * sc
	var nx := 12
	var a0 := deg_to_rad(ang) - w / r * 0.5
	for i in nx:
		var u0 := float(i) / nx
		var u1 := float(i + 1) / nx
		var aa := a0 + u0 * w / r
		var ab := a0 + u1 * w / r
		var p00 := Vector3(sin(aa) * r, -h * 0.5, cos(aa) * r)
		var p10 := Vector3(sin(ab) * r, -h * 0.5, cos(ab) * r)
		var p01 := p00 + Vector3(0, h, 0)
		var p11 := p10 + Vector3(0, h, 0)
		var n0 := Vector3(sin(aa), 0, cos(aa))
		var n1 := Vector3(sin(ab), 0, cos(ab))
		for v in [[p00, n0, Vector2(u0, 1)], [p10, n1, Vector2(u1, 1)], [p11, n1, Vector2(u1, 0)],
				[p00, n0, Vector2(u0, 1)], [p11, n1, Vector2(u1, 0)], [p01, n0, Vector2(u0, 0)]]:
			st.set_normal(v[1])
			st.set_uv(v[2])
			st.add_vertex(v[0])
	st.generate_tangents()
	var f := MeshInstance3D.new()
	f.name = "Disegno"
	f.mesh = st.commit()
	f.material_override = _mat_disegno()
	f.position.y = y
	t.add_child(f)
	for c in [Vector2(0.0, 0.19), Vector2(1.0, 0.19), Vector2(0.0, -0.19), Vector2(1.0, -0.19)]:
		var a: float = a0 + c.x * w / r
		var n := Vector3(sin(a), 0, cos(a))
		_nastro(t, n * (r + 0.002) + Vector3(0, y + c.y * sc, 0), deg_to_rad(40.0 if (c.x - 0.5) * c.y > 0 else -40.0), n)


# --- le lampade del portone della torre ---------------------------------------------------------------
# Il portone (sala_portone_torre) sta sul muro est, x = 19,64-19,88, z = -18,15..-11,85, alto 5,25 m;
# il telaio con la guida arriva a z = -18,75..-9,85 e x = 19,67-20,0.

func _lampade_portone() -> void:
	var n := Node3D.new()
	n.name = "LampadePortone"
	add_child(n)
	if lampade == "lampadine":
		_lampadine(n)
	else:
		_gabbie(n)


func _mat_bulbo() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if lampade_accese:
		m.albedo_color = Color(1.0, 0.85, 0.55)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.72, 0.35)
		m.emission_energy_multiplier = 7.0
		m.roughness = 0.3
	else:
		m.albedo_color = Color(0.42, 0.40, 0.36)
		m.roughness = 0.25
		m.metallic_specular = 0.8
	return m


## Fila di lampadine da luna park su una guida di metallo verniciato, sopra e ai lati del portone.
func _lampadine(n: Node3D) -> void:
	var x := 19.6
	var z0 := -18.45
	var z1 := -11.55
	var y_top := 5.5
	var y_bot := 0.9
	var pti: Array[Vector3] = []   # punti della guida, in ordine
	var punti_lamp: Array[Vector3] = []
	var passo := 0.34
	var lato := y_top - y_bot
	for k in int(lato / passo) + 1:
		punti_lamp.append(Vector3(x, y_bot + k * passo, z0))
		punti_lamp.append(Vector3(x, y_bot + k * passo, z1))
	for k in range(1, int((z1 - z0) / passo)):
		punti_lamp.append(Vector3(x, y_top, z0 + k * passo))
	# la guida: tre listelli (due verticali e uno in alto)
	var mat_g := load("res://assets/materials/sala/metallo_verniciato.tres").duplicate() as StandardMaterial3D
	mat_g.albedo_color = Color(0.95, 0.75, 0.25)
	for seg in [[Vector3(x + 0.03, (y_top + y_bot) * 0.5, z0), Vector3(0.05, lato + 0.12, 0.09)],
			[Vector3(x + 0.03, (y_top + y_bot) * 0.5, z1), Vector3(0.05, lato + 0.12, 0.09)],
			[Vector3(x + 0.03, y_top, (z0 + z1) * 0.5), Vector3(0.05, 0.09, z1 - z0 + 0.09)]]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = seg[1]
		b.mesh = bm
		b.material_override = mat_g
		b.position = seg[0]
		n.add_child(b)
	# portalampada (cilindro scuro) e bulbo, con due MultiMesh
	var porta := CylinderMesh.new()
	porta.top_radius = 0.028
	porta.bottom_radius = 0.032
	porta.height = 0.06
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.12, 0.11, 0.1)
	mp.metallic = 0.7
	mp.roughness = 0.45
	porta.material = mp
	var bulbo := SphereMesh.new()
	bulbo.radius = 0.042
	bulbo.height = 0.095
	bulbo.material = _mat_bulbo()
	for parte in [[porta, -0.01], [bulbo, -0.075]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = parte[0]
		mm.instance_count = punti_lamp.size()
		for i in punti_lamp.size():
			# asse del cilindro lungo -X (fuori dal muro)
			var b := Basis(Vector3(0, 0, 1), PI * 0.5)
			mm.set_instance_transform(i, Transform3D(b, punti_lamp[i] + Vector3(parte[1], 0, 0)))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	if lampade_accese:
		for p in [Vector3(x - 0.5, y_top - 0.2, (z0 + z1) * 0.5), Vector3(x - 0.5, 3.0, z0), Vector3(x - 0.5, 3.0, z1)]:
			var o := OmniLight3D.new()
			o.position = p
			o.light_color = Color(1.0, 0.75, 0.45)
			o.light_energy = 2.2
			o.omni_range = 7.0
			o.omni_attenuation = 1.2
			o.light_volumetric_fog_energy = 1.0
			n.add_child(o)


## Due lampade a gabbia sul muro, ai lati del telaio del portone, a 3,4 m.
func _gabbie(n: Node3D) -> void:
	for z in [-19.25, -9.35]:
		var l := _glb("lampada_gabbia")
		l.position = Vector3(20.0, 3.4, z)
		l.rotation_degrees.y = -90.0
		n.add_child(l)
		var globo := l.find_child("globo", true, false) as MeshInstance3D
		if globo:
			globo.material_override = _mat_bulbo()
		if lampade_accese:
			var o := OmniLight3D.new()
			o.position = Vector3(20.0 - 0.34, 3.4, z)
			o.light_color = Color(1.0, 0.75, 0.45)
			o.light_energy = 3.0
			o.omni_range = 8.0
			o.omni_attenuation = 1.2
			o.shadow_enabled = true
			o.light_volumetric_fog_energy = 1.2
			n.add_child(o)
