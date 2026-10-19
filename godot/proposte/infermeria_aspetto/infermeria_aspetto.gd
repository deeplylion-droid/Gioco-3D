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
## La cassaforte aperta, con dentro la keycard (variante 1 o 2 della proposta della tessera) e la
## Polaroid della pecora (qui girata: la fa chi fa le Polaroid).
@export var cassaforte_aperta := false
@export_enum("1", "2") var tessera := "1"
## Il vano della cassaforte nel muro est (centro sul filo del muro) e la sua misura.
const CASSA := Vector3(3.2, 1.3, -1.05)
const VANO := 0.5

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


func _quad(size: Vector2, pos: Vector3, rot: Vector3, m: Material, padre: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


## Un modello dell'infermeria nell'aspetto giusto (o il nome esatto se c'è un solo aspetto).
func _metti(nome: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var p := DIR + nome + "_" + aspetto + ".glb"
	if not ResourceLoader.exists(p):
		p = DIR + nome + "_N.glb"   # uguale nei due aspetti
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
		var dentro := -c.normalized() * 0.02
		if c.x > 0.0:
			# il muro est ha il vano della cassaforte
			_muro_col_vano(c.x, 0.0, FASCIA, mat_piastrelle)
			_muro_col_vano(c.x, FASCIA, H, mat_muro)
			_muro_col_vano(c.x + dentro.x, FASCIA - 0.025, FASCIA + 0.025, listello, 0.04)
			continue
		_box(Vector3(s.x, FASCIA, s.z), c + Vector3(0, FASCIA * 0.5, 0), mat_piastrelle)
		_box(Vector3(s.x, H - FASCIA, s.z), c + Vector3(0, FASCIA + (H - FASCIA) * 0.5, 0), mat_muro)
		_box(Vector3(maxf(s.x, 0.04), 0.05, maxf(s.z, 0.04)), c + dentro + Vector3(0, FASCIA, 0), listello)
	# la porta d'ingresso (dalla zona del personale) e quella della scala di servizio per il magazzino
	_porta(Vector3(1.6, 0, L - 0.01), 180.0)
	_porta(Vector3(-2.2, 0, -L + 0.01), 0.0)
	# la plafoniera a neon spenta (manca la corrente)
	var pf := _box(Vector3(1.25, 0.08, 0.32), Vector3(0.0, H - 0.04, -0.4), _colore(Color(0.8, 0.8, 0.78), 0.2, 0.5))
	pf.name = "Plafoniera"
	_box(Vector3(1.18, 0.01, 0.26), Vector3(0.0, H - 0.085, -0.4), _colore(Color(0.6, 0.62, 0.6), 0.0, 0.3))


## Una fascia del muro est (da [param y0] a [param y1]) col buco del vano della cassaforte.
func _muro_col_vano(x: float, y0: float, y1: float, m: Material, spessore := 0.1) -> void:
	var z0 := CASSA.z - VANO * 0.5
	var z1 := CASSA.z + VANO * 0.5
	var v0 := CASSA.y - VANO * 0.5
	var v1 := CASSA.y + VANO * 0.5
	var pezzi := [[-L, z0, y0, y1], [z1, L, y0, y1]]
	if v0 > y0:
		pezzi.append([z0, z1, y0, minf(v0, y1)])
	if v1 < y1:
		pezzi.append([z0, z1, maxf(v1, y0), y1])
	for p in pezzi:
		var a: float = p[0]
		var b: float = p[1]
		var lo: float = p[2]
		var hi: float = p[3]
		if b - a > 0.001 and hi - lo > 0.001:
			_box(Vector3(spessore, hi - lo, b - a), Vector3(x, (lo + hi) * 0.5, (a + b) * 0.5), m)


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
	# sulla scrivania la Polaroid del medico davanti allo schedario
	var foto := StandardMaterial3D.new()
	foto.albedo_color = Color(0.82, 0.82, 0.82)
	foto.albedo_texture = load(TEX + ("polaroid_medico.jpg" if aspetto == "A" else "polaroid_medico_B.jpg"))
	foto.roughness = 0.6
	_quad(Vector2(0.088, 0.104), Vector3(0.5, 0.812, -2.62), Vector3(-90, -14, 0), foto)
	# gli oggetti della scrivania: la lampada, i fogli e le cartelle, il fonendoscopio, i timbri, il bicchiere
	var piano := 0.81
	_metti("lampada_tavolo", Vector3(-0.25, piano, -2.98), 30.0)
	var fg := _metti("fogli", Vector3(-0.05, piano, -2.72), 12.0)
	fg.scale = Vector3(1.0, 0.45, 1.0)
	_metti("fonendoscopio", Vector3(0.22, piano, -2.66), 40.0)
	_metti("timbri", Vector3(0.82, piano, -3.0), -10.0)
	_metti("bicchiere", Vector3(0.88, piano, -2.7), 0.0)
	_metti("guanti" if aspetto == "A" else "cerotti", Vector3(0.66, piano, -3.02), 15.0)
	_metti("cestino", Vector3(1.15, 0, -2.9), 0.0)
	# il lettino lungo il muro est con la tenda e il carrello, l'armadietto dei medicinali sopra
	_metti("lettino", Vector3(L - 0.45, 0, 1.95), 0.0)
	# la tenda sul binario a soffitto lungo il lettino, tirata a metà
	_metti("tenda_binario", Vector3(2.3, H, 1.55), 90.0)
	var lz := _metti("lenzuolo", Vector3(2.75, 0.64, 2.25), 20.0)
	lz.scale = Vector3(0.8, 0.35, 0.8)
	_metti("asciugamani", Vector3(2.7, 0.64, 2.75), 5.0)
	_metti("asta_flebo", Vector3(2.2, 0, 1.05), 0.0)
	_metti("sedia_rotelle", Vector3(0.35, 0, 2.55), 160.0)
	_metti("bilancia", Vector3(-L + 0.35, 0, 2.55), 90.0)
	_metti("pronto_soccorso", Vector3(-L, 1.45, 0.35), 90.0)
	var ct := _metti("cartelle_terra", Vector3(-2.1, 0, -0.55), 30.0)
	ct.scale = Vector3(1.0, 0.3, 1.0)
	_metti("vetri_rotti", Vector3(2.75, 0.002, 0.15), 0.0)
	_metti("vetri_rotti", Vector3(0.5, 0.002, -1.6), 70.0)
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
	# il negatoscopio vero (Meshy): cornice di metallo, mollette, interruttore e cavo; il pannello
	# acceso e la lastra sono nostri, davanti al diffusore del modello
	_metti("negatoscopio", c + Vector3(0, 0.1, 0), 0.0)
	var pan := StandardMaterial3D.new()
	pan.albedo_color = Color(0.9, 0.95, 1.0)
	pan.emission_enabled = true
	pan.emission = Color(0.85, 0.92, 1.0)
	pan.emission_energy_multiplier = 0.9
	_quad(Vector2(0.84, 0.44), c + Vector3(0, 0.07, 0.104), Vector3.ZERO, pan)
	if radiografia_appesa:
		var r := StandardMaterial3D.new()
		r.albedo_texture = load(TEX + "radiografia.jpg")
		r.emission_enabled = true
		r.emission_texture = r.albedo_texture
		r.albedo_color = Color(0.5, 0.5, 0.5)
		r.emission_energy_multiplier = 0.85
		r.roughness = 0.95
		r.metallic_specular = 0.0
		_quad(Vector2(0.32, 0.42), c + Vector3(-0.15, 0.07, 0.108), Vector3.ZERO, r)
		var p := StandardMaterial3D.new()
		p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p.albedo_texture = load(TEX + "radiografia_emi.jpg")
		p.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		p.albedo_color = Color(1.6, 1.6, 1.6)
		_quad(Vector2(0.32, 0.42), c + Vector3(-0.15, 0.07, 0.11), Vector3.ZERO, p)
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
	# l'interruttore: il pulsante del parco approvato (versione A, il fungo rosso sulla cassetta gialla
	# col lampeggiante, quello della botola della piscina a onde), già colpito: lampeggiante verde
	_pulsante_parco(Vector3(1.35, 1.25, -L))


## Il pulsante della botola preso dal GLB della sala (sala_interattivi.glb: cassetta, fungo e vetro del
## lampeggiante), girato verso +Z con il retro della cassetta sul muro in [param muro] (il centro del
## fungo all'altezza di [param muro].y).
func _pulsante_parco(muro: Vector3) -> void:
	var glb := (load("res://assets/ambiente/sala/sala_interattivi.glb") as PackedScene).instantiate()
	var rif := Vector3(2.25, -1.12, 4.72)   # il perno del fungo nel GLB (guarda verso -Z)
	var tieni := Node3D.new()
	tieni.name = "PulsanteParco"
	tieni.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -rif)
	var box := AABB()
	var primo := true
	for nome in ["sala_pulsante_portello_cassetta", "sala_pulsante_portello", "sala_lampeggiante_portello"]:
		var n := glb.find_child(nome, true, false) as Node3D
		if n == null:
			push_warning("manca " + nome)
			continue
		n.get_parent().remove_child(n)
		tieni.add_child(n)
		n.owner = null
		for mi in [n] + n.find_children("*", "MeshInstance3D", true, false):
			if mi is MeshInstance3D and nome == "sala_pulsante_portello_cassetta":
				var bb: AABB = tieni.transform * (mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()
				box = bb if primo else box.merge(bb)
				primo = false
		if nome == "sala_lampeggiante_portello":
			for mi in [n] + n.find_children("*", "MeshInstance3D", true, false):
				if mi is MeshInstance3D:
					var v := StandardMaterial3D.new()
					v.albedo_color = Color(0.3, 1.0, 0.45, 0.8)
					v.emission_enabled = true
					v.emission = Color(0.15, 1.0, 0.3)
					v.emission_energy_multiplier = 3.0
					(mi as MeshInstance3D).material_override = v
	glb.free()
	var base := Node3D.new()
	add_child(base)
	base.add_child(tieni)
	# il retro della cassetta (il lato -Z dopo la rotazione) sul muro
	base.position = Vector3(muro.x, muro.y, muro.z - box.position.z)
	_luce(base.position + Vector3(0, 0.55, box.end.z + 0.2), Color(0.15, 1.0, 0.3), 0.6, 2.5, false)


## Due schedari da quattro cassetti contro il muro ovest; nel secondo cassetto dall'alto di quello di
## destra l'adesivo rosa che brilla al buio (come nella Polaroid).
func _schedari() -> void:
	for i in 2:
		var s := _metti("schedario_vero", Vector3(-L + 0.2, 0, -1.3 + i * 0.46), 90.0)
		_tingi(s, Color(0.82, 0.85, 0.83) if aspetto == "A" else Color(1.0, 0.8, 0.86))
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
	d.position = Vector3(-L + 0.2 + 0.177, 0.98, -1.3 + 0.08)
	d.rotation_degrees = Vector3(0, 0, 90)
	add_child(d)
	var g := _luce(d.position + Vector3(0.12, 0, 0), Color(1.0, 0.3, 0.75), 0.25, 1.2, false)
	g.name = "AloneAdesivo"


## La cassaforte nel muro est: il vano d'acciaio nel muro con la cornice, lo sportello sui cardini a
## sinistra con la maniglia, tre rotelle sullo stesso asse con le cifre 0-9 e sopra ognuna il simbolo
## (testa, corpo, coda dell'agnello). Aperta, dentro ci sono la keycard e la Polaroid.
func _cassaforte() -> void:
	var c := CASSA
	var h := VANO * 0.5
	var scuro := _colore(Color(0.2, 0.21, 0.21), 0.7, 0.5)
	var acciaio := _colore(Color(0.32, 0.36, 0.35) if aspetto == "A" else Color(0.42, 0.46, 0.5), 0.75, 0.45)
	# il vano: fondo, cielo, pavimento e fianchi, profondo 30 cm nel muro
	var p := 0.3
	_box(Vector3(0.02, VANO, VANO), Vector3(c.x + p, c.y, c.z), scuro)
	for dy in [-h, h]:
		_box(Vector3(p, 0.02, VANO), Vector3(c.x + p * 0.5, c.y + dy, c.z), scuro)
	for dz in [-h, h]:
		_box(Vector3(p, VANO, 0.02), Vector3(c.x + p * 0.5, c.y, c.z + dz), scuro)
	# la cornice sul filo del muro
	for dy in [-h - 0.03, h + 0.03]:
		_box(Vector3(0.03, 0.06, VANO + 0.12), Vector3(c.x - 0.015, c.y + dy, c.z), scuro)
	for dz in [-h - 0.03, h + 0.03]:
		_box(Vector3(0.03, VANO, 0.06), Vector3(c.x - 0.015, c.y, c.z + dz), scuro)
	# lo sportello, sui cardini dal lato -Z
	var sp := Node3D.new()
	sp.name = "Sportello"
	sp.position = Vector3(c.x - 0.03, c.y, c.z - h)
	add_child(sp)
	if cassaforte_aperta:
		sp.rotation_degrees.y = -105.0
	# lo sportello vero (Meshy): cerniere a sinistra, maniglia a destra, bordo imbullonato
	var porta := (load(DIR + "sportello_cassaforte_N.glb") as PackedScene).instantiate() as Node3D
	porta.position = Vector3(0.0, 0.0, h)
	porta.rotation_degrees.y = -90.0
	sp.add_child(porta)
	var cifre := StandardMaterial3D.new()
	cifre.albedo_texture = load(TEX + "rotella_cifre.jpg")
	cifre.uv1_scale = Vector3(1, 2, 1)   # il lato del CylinderMesh usa solo metà della V
	cifre.roughness = 0.5
	var nomi := ["testa", "corpo", "coda"]
	for i in 3:
		var z := h + (i - 1) * 0.09
		var r := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = 0.086
		r.mesh = cm
		r.material_override = cifre
		r.position = Vector3(-0.135, 0.03, z)
		# l'asse lungo Z, cifre a caso davanti (aperta: il codice giusto 4-1-7)
		r.rotation = Vector3(PI * 0.5, 0, 0)
		var cifra: int = [4, 1, 7][i] if cassaforte_aperta else randi() % 10
		r.rotate_object_local(Vector3.UP, deg_to_rad(36.0 * cifra))
		sp.add_child(r)
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = load(TEX + "simbolo_%s.png" % nomi[i])
		sm.roughness = 0.4
		_quad(Vector2(0.09, 0.09), Vector3(-0.072, 0.16, z), Vector3(0, -90, 0), sm, sp)
	# il supporto delle rotelle
	_box(Vector3(0.06, 0.1, 0.34), Vector3(-0.1, 0.03, h), _colore(Color(0.15, 0.15, 0.15), 0.8, 0.4), sp)
	if cassaforte_aperta:
		_dentro_cassaforte()


## La keycard e la Polaroid sul fondo del vano, e una lucina: il vano altrimenti è nero.
func _dentro_cassaforte() -> void:
	var fondo := CASSA.y - VANO * 0.5 + 0.011
	# la luce rossa della lampada d'emergenza che entra nel vano dallo sportello aperto
	_luce(Vector3(CASSA.x + 0.05, CASSA.y + 0.18, CASSA.z), Color(1.0, 0.6, 0.5), 0.7, 1.0, false)
	_tessera_a(Vector3(CASSA.x + 0.12, fondo, CASSA.z + 0.06), 18.0)
	var retro := StandardMaterial3D.new()
	retro.albedo_texture = load("res://assets/models/polaroid/texture/retro.jpg")
	retro.roughness = 0.7
	_quad(Vector2(0.088, 0.107), Vector3(CASSA.x + 0.2, fondo + 0.001, CASSA.z - 0.09), Vector3(-90, 75, 0), retro)


## La keycard della variante [member tessera]: 85,6 x 54 mm, spessa 0,8, stesa con la faccia in su.
func _tessera_a(pos: Vector3, rot_y: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	var bordo := _colore(Color(0.9, 0.9, 0.88) if tessera == "1" else Color(0.9, 0.35, 0.08), 0.0, 0.4)
	_box(Vector3(0.084, 0.0008, 0.052), Vector3.ZERO, bordo, n)
	var f := StandardMaterial3D.new()
	f.albedo_texture = load("res://assets/tessera/texture/tessera_%s.png" % tessera)
	f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	f.roughness = 0.3
	_quad(Vector2(0.0856, 0.054), Vector3(0, 0.0005, 0), Vector3(-90, 0, 0), f, n)


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
	# il poster della mascotte (lo stesso cartellone della sala) sul muro ovest, in vista dalla porta
	var mp := StandardMaterial3D.new()
	mp.albedo_texture = load("res://assets/ambienti_interni/texture/cartellone_medusa_vecchio.jpg")
	mp.roughness = 0.7
	_box(Vector3(0.02, 1.04, 0.79), Vector3(-L + 0.01, 1.85, 1.45), _colore(Color(0.95, 0.75, 0.85)))
	_quad(Vector2(0.75, 1.0), Vector3(-L + 0.022, 1.85, 1.45), Vector3(0, 90, 0), mp)
	# gli adesivi da cartone, grandi, sui muri e sull'intonaco rosa
	var posti := [[Vector3(-L + 0.012, 2.35, -0.3), 90.0, 0.62], [Vector3(-0.9, 2.25, L - 0.012), 180.0, 0.6],
			[Vector3(L - 0.012, 2.3, 1.75), -90.0, 0.7], [Vector3(1.0, 2.45, -L + 0.012), 0.0, 0.55],
			[Vector3(-1.2, 2.35, -L + 0.012), 0.0, 0.6], [Vector3(L - 0.012, 0.9, -0.15), -90.0, 0.5],
			[Vector3(-L + 0.012, 0.75, 0.6), 90.0, 0.45]]
	for i in posti.size():
		var t := load(TEX + "adesivo_%d.png" % (i % 5)) as Texture2D
		var m := StandardMaterial3D.new()
		m.albedo_texture = t
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.roughness = 0.5
		var h: float = posti[i][2]
		var w := h * float(t.get_width()) / float(t.get_height())
		_quad(Vector2(w, h), posti[i][0], Vector3(0, posti[i][1], 0), m)
	# i giocattoli: l'orsetto sul lettino, il trenino per terra, il cavallo a dondolo nell'angolo
	_metti("orsetto", Vector3(2.8, 0.64, 1.55), -120.0)
	_metti("trenino", Vector3(-0.9, 0, 1.3), 35.0)
	_metti("cavallo_dondolo", Vector3(-2.45, 0, 0.95), 60.0)
	# la lucina notturna a forma di luna nella presa vicino al lettino, a batteria: rosa e calda
	var luna := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	luna.mesh = sm
	var ml := StandardMaterial3D.new()
	ml.albedo_color = Color(1.0, 0.9, 0.7)
	ml.emission_enabled = true
	ml.emission = Color(1.0, 0.8, 0.6)
	ml.emission_energy_multiplier = 3.0
	luna.material_override = ml
	luna.position = Vector3(L - 0.02, 0.45, 0.95)
	luna.scale = Vector3(0.5, 1.0, 1.0)
	add_child(luna)
	_luce(Vector3(L - 0.3, 0.6, 0.95), Color(1.0, 0.75, 0.7), 1.2, 4.5, false)
