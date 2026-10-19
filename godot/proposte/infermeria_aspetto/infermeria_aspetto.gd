extends Node3D
## Proposta d'aspetto dell'infermeria (enigma-ambiente, 19 ottobre), per gli scatti dal motore: la
## stanza del medico del parco della nota di enigma-logica (docs/proposte/fiume_infermeria/
## nota_logica.md), arredata, al buio, con la luce d'emergenza rossa, il negatoscopio acceso (dopo
## l'interruttore colpito col getto) e la radiografia dell'agnello sopra, lo schedario con l'adesivo
## rosa fosforescente, la cassaforte nel muro con le tre rotelle (testa, corpo, coda).
## aspetto "A": ambulatorio di bordo anni '90 (piastrelle bianche, muri grigioverdi, acciaio smaltato);
## aspetto "B": infermeria per bambini (muri pastello, adesivi da cartone, metro a giraffa).
## Gli stessi modelli Meshy con due texture (<nome>_A.glb, <nome>_B.glb).
## Coordinate: la stanza va da -3,2 a 3,2 in X e Z, alta 3 m; si entra dalla porta a sud (+Z).

const DIR := "res://assets/infermeria/"
const TEX := "res://assets/infermeria/texture/"
@export_enum("A", "B") var aspetto := "A"
## La radiografia è già sul negatoscopio (l'ultimo passo prima della cassaforte).
@export var radiografia_appesa := true

const L := 3.2
const H := 3.0
## Altezza della fascia di piastrelle sui muri.
const FASCIA := 1.5

var mat_piastrelle: Material
var mat_muro: Material
var mat_pavimento: Material
var mat_soffitto: Material


func _ready() -> void:
	seed(1019)
	if aspetto == "A":
		mat_piastrelle = _mat("piastrelle_grandi", Color(0.92, 0.93, 0.9), 1.0)
		mat_muro = _mat("intonaco", Color(0.56, 0.66, 0.6), 0.5)
		mat_pavimento = _mat("graniglia_grigia", Color(0.8, 0.8, 0.78), 0.6)
	else:
		mat_piastrelle = _mat("piastrelle_piccole", Color(0.7, 0.92, 0.85), 1.2)
		mat_muro = _mat("intonaco", Color(1.0, 0.8, 0.84), 0.5)
		mat_pavimento = _mat("graniglia_colorata", Color(1.0, 1.0, 1.0), 0.7)
	mat_soffitto = _mat("intonaco", Color(0.7, 0.7, 0.68), 0.4)
	_ambiente()
	_stanza()
	_arredi()
	_negatoscopio()
	_schedari()
	_cassaforte()
	_luci()
	if aspetto == "B":
		_bambini()


# --- materiali e aiuti -----------------------------------------------------------------------------

func _mat(nome: String, tinta: Color, scala: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + nome + "_col.jpg")
	m.albedo_color = tinta
	m.normal_enabled = true
	m.normal_texture = load(TEX + nome + "_nrm.jpg")
	m.roughness_texture = load(TEX + nome + "_rgh.jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scala
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _colore(c: Color, metallo := 0.0, ruvido := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallo
	m.roughness = ruvido
	return m


func _box(size: Vector3, pos: Vector3, m: Material, padre: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	padre.add_child(mi)
	return mi


func _quad(size: Vector2, pos: Vector3, rot: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Un modello dell'infermeria nell'aspetto giusto (o il nome esatto se c'è un solo aspetto).
func _metti(nome: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var p := DIR + nome + "_" + aspetto + ".glb"
	if not ResourceLoader.exists(p):
		p = DIR + nome + ".glb"
	var n: Node3D = (load(p) as PackedScene).instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	return n


## Moltiplica il colore dei materiali del modello (per esempio lo schedario grigio del A).
func _tingi(n: Node3D, c: Color) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var s := m.mesh.surface_get_material(i) as StandardMaterial3D
			if s:
				s = s.duplicate()
				s.albedo_color = c
				m.set_surface_override_material(i, s)


func _luce(pos: Vector3, colore: Color, energia: float, raggio: float, ombre := true) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = colore
	o.light_energy = energia
	o.omni_range = raggio
	o.omni_attenuation = 1.2
	o.shadow_enabled = ombre
	add_child(o)
	return o


# --- ambiente e stanza -------------------------------------------------------------------------------

func _ambiente() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.1, 0.09, 0.1)
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.15
	e.ssao_enabled = true
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.04
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.015
	we.environment = e
	add_child(we)


func _stanza() -> void:
	_box(Vector3(2 * L, 0.1, 2 * L), Vector3(0, -0.05, 0), mat_pavimento)
	_box(Vector3(2 * L, 0.1, 2 * L), Vector3(0, H + 0.05, 0), mat_soffitto)
	# i quattro muri: piastrelle in basso, intonaco dipinto sopra, il listello tra i due
	var listello := _colore(Color(0.45, 0.5, 0.47) if aspetto == "A" else Color(0.55, 0.75, 0.9), 0.0, 0.4)
	for m in [[Vector3(0, 0, -L - 0.05), Vector3(2 * L, 0, 0.1)], [Vector3(0, 0, L + 0.05), Vector3(2 * L, 0, 0.1)],
			[Vector3(-L - 0.05, 0, 0), Vector3(0.1, 0, 2 * L)], [Vector3(L + 0.05, 0, 0), Vector3(0.1, 0, 2 * L)]]:
		var c: Vector3 = m[0]
		var s: Vector3 = m[1]
		_box(Vector3(s.x, FASCIA, s.z), c + Vector3(0, FASCIA * 0.5, 0), mat_piastrelle)
		_box(Vector3(s.x, H - FASCIA, s.z), c + Vector3(0, FASCIA + (H - FASCIA) * 0.5, 0), mat_muro)
		var dentro := -c.normalized() * 0.02
		_box(Vector3(maxf(s.x, 0.04), 0.05, maxf(s.z, 0.04)), c + dentro + Vector3(0, FASCIA, 0), listello)
	# la porta d'ingresso (dalla zona del personale) e quella della scala di servizio per il magazzino
	_porta(Vector3(1.6, 0, L - 0.01), 180.0)
	_porta(Vector3(-2.2, 0, -L + 0.01), 0.0)
	# la plafoniera a neon spenta (manca la corrente)
	var pf := _box(Vector3(1.25, 0.08, 0.32), Vector3(0.0, H - 0.04, -0.4), _colore(Color(0.8, 0.8, 0.78), 0.2, 0.5))
	pf.name = "Plafoniera"
	_box(Vector3(1.18, 0.01, 0.26), Vector3(0.0, H - 0.085, -0.4), _colore(Color(0.6, 0.62, 0.6), 0.0, 0.3))


## Porta di servizio chiusa (anta e telaio) appoggiata al muro, che guarda verso +Z ruotata di [param rot].
func _porta(pos: Vector3, rot: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot
	add_child(n)
	var telaio := _colore(Color(0.3, 0.32, 0.31), 0.6, 0.5)
	var anta := _colore(Color(0.62, 0.64, 0.6) if aspetto == "A" else Color(0.98, 0.95, 0.82), 0.3, 0.55)
	_box(Vector3(1.04, 2.14, 0.04), Vector3(0, 1.07, 0.02), telaio, n)
	_box(Vector3(0.92, 2.06, 0.05), Vector3(0, 1.03, 0.045), anta, n)
	_box(Vector3(0.14, 0.03, 0.05), Vector3(0.34, 1.05, 0.09), _colore(Color(0.7, 0.7, 0.7), 0.9, 0.3), n)


# --- arredi --------------------------------------------------------------------------------------

func _arredi() -> void:
	# la scrivania contro il muro nord, sotto il negatoscopio, con la sedia girata
	_metti("scrivania", Vector3(0.3, 0, -L + 0.36), 0.0)
	_metti("sedia", Vector3(0.15, 0, -2.05), 200.0)
	# sulla scrivania la Polaroid del medico davanti allo schedario, una cartella, un portapenne
	var foto := StandardMaterial3D.new()
	foto.albedo_color = Color(0.82, 0.82, 0.82)
	foto.albedo_texture = load(TEX + ("polaroid_medico.jpg" if aspetto == "A" else "polaroid_medico_B.jpg"))
	foto.roughness = 0.6
	_quad(Vector2(0.088, 0.104), Vector3(0.5, 0.812, -2.62), Vector3(-90, -14, 0), foto)
	var cartella := _box(Vector3(0.24, 0.012, 0.32), Vector3(-0.12, 0.817, -2.82), _colore(Color(0.75, 0.62, 0.38) if aspetto == "A" else Color(0.55, 0.78, 0.95), 0.0, 0.8))
	cartella.rotation_degrees.y = 8.0
	var pp := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 0.1
	pp.mesh = cm
	pp.material_override = _colore(Color(0.2, 0.22, 0.25), 0.5, 0.4)
	pp.position = Vector3(0.85, 0.86, -3.0)
	add_child(pp)
	# il lettino lungo il muro est con il paravento e il carrello, l'armadietto dei medicinali sopra
	_metti("lettino", Vector3(L - 0.45, 0, 1.95), 0.0)
	var pv := _metti("paravento", Vector3(2.35, 0, 0.62), 0.0)
	pv.name = "Paravento"
	_metti("carrello", Vector3(1.9, 0, 2.35), -90.0)
	_metti("armadietto", Vector3(L, 1.2, 0.35), -90.0)
	# il lavandino sul muro sud, vicino alla porta
	_metti("lavandino", Vector3(-0.6, 0.32, L), 180.0)
	if aspetto == "A":
		_metti("bombola", Vector3(-2.65, 0, 1.0), 90.0)


## Il negatoscopio sul muro nord, sopra la scrivania: telaio d'acciaio, pannello luminoso acceso fisso,
## la radiografia dell'agnello agganciata con le mollette; l'interruttore d'acqua accanto.
func _negatoscopio() -> void:
	var c := Vector3(0.3, 1.72, -L)
	_box(Vector3(1.0, 0.68, 0.09), c + Vector3(0, 0, 0.045), _colore(Color(0.78, 0.79, 0.76) if aspetto == "A" else Color(0.95, 0.95, 0.92), 0.4, 0.45))
	var pan := StandardMaterial3D.new()
	pan.albedo_color = Color(0.9, 0.95, 1.0)
	pan.emission_enabled = true
	pan.emission = Color(0.85, 0.92, 1.0)
	pan.emission_energy_multiplier = 0.9
	_quad(Vector2(0.9, 0.56), c + Vector3(0, 0.0, 0.092), Vector3.ZERO, pan)
	# la barra delle mollette in alto
	_box(Vector3(0.92, 0.03, 0.02), c + Vector3(0, 0.3, 0.1), _colore(Color(0.6, 0.6, 0.6), 0.8, 0.35))
	if radiografia_appesa:
		var r := StandardMaterial3D.new()
		r.albedo_texture = load(TEX + "radiografia.jpg")
		r.emission_enabled = true
		r.emission_texture = r.albedo_texture
		r.albedo_color = Color(0.5, 0.5, 0.5)
		r.emission_energy_multiplier = 0.85
		r.roughness = 0.95
		r.metallic_specular = 0.0
		_quad(Vector2(0.39, 0.52), c + Vector3(-0.15, 0.0, 0.096), Vector3.ZERO, r)
		var p := StandardMaterial3D.new()
		p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p.albedo_texture = load(TEX + "radiografia_emi.jpg")
		p.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		p.albedo_color = Color(1.6, 1.6, 1.6)
		_quad(Vector2(0.39, 0.52), c + Vector3(-0.15, 0.0, 0.098), Vector3.ZERO, p)
	# la luce del pannello sulla scrivania e sulla stanza
	var s := SpotLight3D.new()
	s.position = c + Vector3(0, 0, 0.25)
	s.look_at_from_position(s.position, c + Vector3(0, -0.9, 1.6))
	s.light_color = Color(0.82, 0.9, 1.0)
	s.light_energy = 3.0
	s.spot_range = 6.0
	s.spot_angle = 75.0
	s.shadow_enabled = true
	add_child(s)
	_luce(c + Vector3(0, 0, 0.4), Color(0.82, 0.9, 1.0), 0.8, 5.0, false)
	# l'interruttore del parco, da colpire col getto, a destra del negatoscopio
	var b := (load("res://scenes/props/water_button.tscn") as PackedScene).instantiate() as Node3D
	b.position = Vector3(1.2, 1.35, -L + 0.02)
	add_child(b)


## Due schedari da quattro cassetti contro il muro ovest; nel secondo cassetto dall'alto di quello di
## destra l'adesivo rosa che brilla al buio (come nella Polaroid).
func _schedari() -> void:
	for i in 2:
		var s := _metti("schedario", Vector3(-L + 0.25, 0, -1.3 + i * 0.5), 90.0)
		if aspetto == "A":
			_tingi(s, Color(0.66, 0.7, 0.68))
	var ad := StandardMaterial3D.new()
	ad.albedo_color = Color(1.0, 0.35, 0.78)
	ad.emission_enabled = true
	ad.emission = Color(1.0, 0.3, 0.75)
	ad.emission_energy_multiplier = 2.2
	var d := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 0.002
	d.mesh = cm
	d.material_override = ad
	d.position = Vector3(-L + 0.25 + 0.245, 0.98, -1.3 + 0.1)
	d.rotation_degrees = Vector3(0, 0, 90)
	add_child(d)
	var g := _luce(d.position + Vector3(0.12, 0, 0), Color(1.0, 0.3, 0.75), 0.25, 1.2, false)
	g.name = "AloneAdesivo"


## La cassaforte nel muro est: sportello d'acciaio incassato, maniglia, tre rotelle sullo stesso asse
## con le cifre 0-9 e sopra ognuna il simbolo (testa, corpo, coda dell'agnello).
func _cassaforte() -> void:
	var c := Vector3(L, 1.3, -1.05)
	var acciaio := _colore(Color(0.32, 0.36, 0.35) if aspetto == "A" else Color(0.42, 0.46, 0.5), 0.75, 0.45)
	_box(Vector3(0.06, 0.6, 0.6), c + Vector3(-0.03, 0, 0), _colore(Color(0.2, 0.21, 0.21), 0.7, 0.5))   # telaio
	_box(Vector3(0.05, 0.5, 0.5), c + Vector3(-0.07, 0, 0), acciaio)                                   # sportello
	_box(Vector3(0.08, 0.04, 0.16), c + Vector3(-0.12, -0.12, 0.13), _colore(Color(0.75, 0.74, 0.7), 0.9, 0.25))
	var cifre := StandardMaterial3D.new()
	cifre.albedo_texture = load(TEX + "rotella_cifre.jpg")
	cifre.uv1_scale = Vector3(1, 2, 1)   # il lato del CylinderMesh usa solo metà della V
	cifre.roughness = 0.5
	var nomi := ["testa", "corpo", "coda"]
	for i in 3:
		var z := c.z + (i - 1) * 0.09
		var r := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = 0.086
		r.mesh = cm
		r.material_override = cifre
		r.position = Vector3(c.x - 0.13, c.y + 0.03, z)
		# l'asse lungo Z, cifre a caso davanti
		r.rotation = Vector3(PI * 0.5, 0, 0)
		r.rotate_object_local(Vector3.UP, deg_to_rad(36.0 * (randi() % 10)))
		add_child(r)
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = load(TEX + "simbolo_%s.png" % nomi[i])
		sm.roughness = 0.4
		_quad(Vector2(0.09, 0.09), Vector3(c.x - 0.096, c.y + 0.16, z), Vector3(0, -90, 0), sm)
	# il supporto delle rotelle
	_box(Vector3(0.04, 0.1, 0.34), c + Vector3(-0.1, 0.03, 0), _colore(Color(0.15, 0.15, 0.15), 0.8, 0.4))


func _luci() -> void:
	# la lampada d'emergenza rossa sopra la porta d'ingresso e una sul muro est, sopra la cassaforte
	for p in [[Vector3(1.6, 2.55, L - 0.12), Vector3(0, -0.5, -1)], [Vector3(L - 0.12, 2.5, -1.05), Vector3(-1, -0.7, 0)]]:
		var l := (load("res://assets/fiume_lento/lampada_emergenza.glb") as PackedScene).instantiate() as Node3D
		l.position = p[0]
		add_child(l)
		l.look_at(p[0] + p[1], Vector3.UP)
		_luce(p[0] + (p[1] as Vector3).normalized() * 0.3, Color(1.0, 0.16, 0.1), 1.6, 6.0, true)
	# il cartello d'uscita verde sopra la porta della scala, acceso (luce d'emergenza a batteria)
	var mf := StandardMaterial3D.new()
	mf.albedo_texture = load("res://assets/fiume_lento/texture/uscita_faccia.jpg")
	mf.emission_enabled = true
	mf.emission_texture = mf.albedo_texture
	mf.emission_energy_multiplier = 2.5
	_box(Vector3(0.5, 0.26, 0.08), Vector3(-2.2, 2.38, -L + 0.04), _colore(Color(0.8, 0.8, 0.76)))
	_quad(Vector2(0.46, 0.23), Vector3(-2.2, 2.38, -L + 0.082), Vector3.ZERO, mf)
	_luce(Vector3(-2.2, 2.2, -L + 0.4), Color(0.2, 1.0, 0.4), 0.35, 3.0, false)


# --- aspetto B: infermeria per bambini -----------------------------------------------------------

func _bambini() -> void:
	_metti("giraffa_metro", Vector3(2.45, 0.05, -L), 0.0)
	# gli adesivi da cartone sull'intonaco rosa
	var posti := [[Vector3(-L + 0.012, 2.15, 0.2), 90.0, 0.42], [Vector3(-L + 0.012, 2.3, 2.4), 90.0, 0.3],
			[Vector3(-0.9, 2.2, L - 0.012), 180.0, 0.32], [Vector3(-2.3, 2.05, L - 0.012), 180.0, 0.36],
			[Vector3(L - 0.012, 2.3, 1.6), -90.0, 0.4], [Vector3(1.4, 2.3, -L + 0.012), 0.0, 0.34]]
	for i in posti.size():
		var t := load(TEX + "adesivo_%d.png" % (i % 5)) as Texture2D
		var m := StandardMaterial3D.new()
		m.albedo_texture = t
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.roughness = 0.5
		var h: float = posti[i][2]
		var w := h * float(t.get_width()) / float(t.get_height())
		_quad(Vector2(w, h), posti[i][0], Vector3(0, posti[i][1], 0), m)
