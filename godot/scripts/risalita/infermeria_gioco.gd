extends Node3D
## L'infermeria nel gioco (aspetto B, "per bambini del parco", scelta dell'utente del 19 ottobre),
## dopo l'approdo del fiume lento (GDD, "Allungare il capitolo"; logica approvata il 18 ottobre in
## docs/proposte/fiume_infermeria/nota_logica.md). La stanza è quella della proposta approvata
## (proposte/infermeria_aspetto/infermeria_aspetto.gd), con la logica di enigma-logica:
## 1. il pulsante del parco sotto il negatoscopio, colpito col getto (WaterButton, il lampeggiante
##    giallo lampeggia finché non lo colpisci, poi verde fisso): il negatoscopio smette di sfarfallare;
## 2. la Polaroid del medico sulla scrivania mostra lo schedario col cassetto dall'adesivo rosa; quel
##    cassetto (CassettoSchedario) ha l'adesivo fosforescente e dentro la radiografia;
## 3. la radiografia sul negatoscopio (E): i puntini rosa nelle ossa dell'agnello, 4, 1 e 7;
## 4. la cassaforte nel muro est (CassaforteRotelle, rotelle testa, corpo, coda): dentro la keycard 1 e
##    la Polaroid della pecora.
## Un checkpoint dopo ogni passo (luce, radiografia presa, radiografia appoggiata).
## Coordinate: la stanza va da -L a L in X e Z, alta H; si entra dalla porta a sud (+Z, dalla zona del
## personale) e si esce dalla porta a nord (-Z) verso la scala di servizio.

const DIR := "res://assets/infermeria/"
const TEX := "res://assets/infermeria/texture/"
const L := 3.2
const H := 3.0
const FASCIA := 1.5
## Il vano della cassaforte nel muro est (centro sul filo del muro) e la sua misura.
const CASSA := Vector3(3.2, 1.3, -1.05)
const VANO := 0.5
## Le porte: [x del centro, larghezza del vano].
const PORTA_SUD := 1.6
const PORTA_NORD := -2.2
const LARGO_PORTA := 1.0
## Ordine dei checkpoint dei passi (tra l'approdo e il magazzino).
@export var ordine_checkpoint := 12

var mat_piastrelle: Material
var mat_muro: Material
var mat_pavimento: Material
var mat_soffitto: Material

var interruttore: WaterButton
var negatoscopio: Negatoscopio
var cassaforte: CassaforteRotelle
var cassetti: Array[CassettoSchedario] = []
var keycard: Pickup
## I listelli a metà muro (dimensione, centro, materiale): si mettono alla fine, interrotti dove sul muro c'è
## appeso qualcosa (prima passavano dentro la giraffa, il pulsante, la cassetta del pronto soccorso, il cartellone)
var _listelli := []
var radiografia: Pickup

var _collisioni: StaticBody3D
var _vetro_lampeggiante: StandardMaterial3D
var _luce_lampeggiante: OmniLight3D
var _t := 0.0


func _ready() -> void:
	seed(1019)
	mat_piastrelle = _mat("piastrelle_piccole", Color(0.7, 0.92, 0.85), 1.2)
	mat_muro = _mat("intonaco", Color(1.0, 0.8, 0.84), 0.5)
	mat_pavimento = _mat("graniglia_colorata", Color(1.0, 1.0, 1.0), 0.7)
	mat_soffitto = _mat("intonaco", Color(0.7, 0.7, 0.68), 0.4)
	_collisioni = StaticBody3D.new()
	_collisioni.name = "Collisioni"
	add_child(_collisioni)
	_stanza()
	_arredi()
	_negatoscopio()
	_schedari()
	_cassaforte()
	_luci()
	_bambini()
	_metti_listelli()
	_checkpoint()
	_marker()


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


func _box(size: Vector3, pos: Vector3, m: Material, padre: Node3D = self, collisione := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	padre.add_child(mi)
	if collisione:
		_forma(size, padre.transform * pos if padre != self else pos)
	return mi


func _forma(size: Vector3, pos: Vector3, rot_y := 0.0) -> void:
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	f.shape = b
	f.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)), pos)
	_collisioni.add_child(f)


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


## I listelli lungo i muri, interrotti (2 cm di margine) dove li attraversa qualcosa appeso o appoggiato al muro.
func _metti_listelli() -> void:
	var altri: Array[AABB] = []
	for c in get_children():
		if c is CollisionObject3D or c is Light3D:
			continue
		var b := _box_di(c)
		if b.size != Vector3.ZERO:
			altri.append(b)
	for li in _listelli:
		var size: Vector3 = li[0]
		var centro: Vector3 = li[1]
		var asse := 0 if size.x > size.z else 2   # lungo x (muri nord e sud) o lungo z (ovest ed est)
		var box := AABB(centro - size * 0.5, size)
		var tagli := []
		for b in altri:
			var i := box.grow(-0.002).intersection(b)
			if i.size.x > 0.0 and i.size.y > 0.0 and i.size.z > 0.0:
				tagli.append([b.position[asse] - 0.02, b.end[asse] + 0.02])
		tagli.sort_custom(func(p, q): return p[0] < q[0])
		var da := box.position[asse]
		for t in tagli + [[box.end[asse], box.end[asse]]]:
			var a: float = da
			var fine: float = minf(t[0], box.end[asse])
			if fine - a > 0.03:
				var s := size
				var c := centro
				s[asse] = fine - a
				c[asse] = (a + fine) * 0.5
				_box(s, c, li[2]).name = "Listello"
			da = maxf(da, t[1])


## La collisione (una scatola) di un modello messo con _metti: il box delle sue mesh, nelle coordinate della stanza.
func _forma_di(n: Node3D) -> void:
	var b := _box_di(n)
	_forma(b.size, b.get_center())


## Il box delle mesh di [param n] nelle coordinate della stanza.
func _box_di(n: Node) -> AABB:
	var b := AABB()
	var primo := true
	for mi in ([n] if n is MeshInstance3D else []) + n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var k: Node = mi
		while k != self and k != null:
			xf = (k as Node3D).transform * xf
			k = k.get_parent()
		var bb: AABB = xf * (mi as MeshInstance3D).get_aabb()
		b = bb if primo else b.merge(bb)
		primo = false
	return b


## Un modello dell'infermeria nell'aspetto B (o quello uguale nei due aspetti).
func _metti(nome: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var p := DIR + nome + "_B.glb"
	if not ResourceLoader.exists(p):
		p = DIR + nome + "_N.glb"
	if not ResourceLoader.exists(p):
		p = DIR + nome + ".glb"
	var n: Node3D = (load(p) as PackedScene).instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	return n


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
	o.set_meta(&"risveglio_ignora", true)
	add_child(o)
	return o


# --- la stanza -------------------------------------------------------------------------------------

func _stanza() -> void:
	_box(Vector3(2 * L + 0.2, 0.1, 2 * L + 0.2), Vector3(0, -0.05, 0), mat_pavimento, self, true)
	_box(Vector3(2 * L + 0.2, 0.1, 2 * L + 0.2), Vector3(0, H + 0.05, 0), mat_soffitto, self, true)
	var listello := _colore(Color(0.55, 0.75, 0.9), 0.0, 0.4)
	# nord e sud, con il vano della porta; ovest pieno; est col vano della cassaforte
	for lato in [-1.0, 1.0]:
		var z: float = lato * (L + 0.05)
		var xp: float = PORTA_SUD if lato > 0.0 else PORTA_NORD
		var a := xp - LARGO_PORTA * 0.5
		var b := xp + LARGO_PORTA * 0.5
		for seg in [[-L - 0.1, a], [b, L + 0.1]]:
			var w: float = seg[1] - seg[0]
			var cx: float = (seg[0] + seg[1]) * 0.5
			_box(Vector3(w, FASCIA, 0.1), Vector3(cx, FASCIA * 0.5, z), mat_piastrelle)
			_box(Vector3(w, H - FASCIA, 0.1), Vector3(cx, FASCIA + (H - FASCIA) * 0.5, z), mat_muro)
			_listelli.append([Vector3(w, 0.05, 0.04), Vector3(cx, FASCIA, z - lato * 0.07), listello])
			_forma(Vector3(w, H, 0.1), Vector3(cx, H * 0.5, z))
		# sopra la porta
		_box(Vector3(LARGO_PORTA, H - 2.15, 0.1), Vector3(xp, 2.15 + (H - 2.15) * 0.5, z), mat_muro, self, true)
		_telaio(Vector3(xp, 0, z - lato * 0.05), 0.0 if lato < 0.0 else 180.0)
	_box(Vector3(0.1, FASCIA, 2 * L), Vector3(-L - 0.05, FASCIA * 0.5, 0), mat_piastrelle)
	_box(Vector3(0.1, H - FASCIA, 2 * L), Vector3(-L - 0.05, FASCIA + (H - FASCIA) * 0.5, 0), mat_muro)
	_listelli.append([Vector3(0.04, 0.05, 2 * L), Vector3(-L + 0.02, FASCIA, 0), listello])
	_forma(Vector3(0.1, H, 2 * L), Vector3(-L - 0.05, H * 0.5, 0))
	_muro_col_vano(L + 0.05, 0.0, FASCIA, mat_piastrelle)
	_muro_col_vano(L + 0.05, FASCIA, H, mat_muro)
	_muro_col_vano(L + 0.03, FASCIA - 0.025, FASCIA + 0.025, listello, 0.04, true)
	_forma(Vector3(0.1, H, 2 * L), Vector3(L + 0.05 + 0.31, H * 0.5, 0))   # dietro al vano: il fondo è a 30 cm
	for z in [[-L, CASSA.z - VANO * 0.5], [CASSA.z + VANO * 0.5, L]]:
		_forma(Vector3(0.1, H, z[1] - z[0]), Vector3(L + 0.05, H * 0.5, (z[0] + z[1]) * 0.5))
	# la plafoniera a neon spenta (manca la corrente)
	var pf := _box(Vector3(1.25, 0.08, 0.32), Vector3(0.0, H - 0.04, -0.4), _colore(Color(0.8, 0.8, 0.78), 0.2, 0.5))
	pf.name = "Plafoniera"
	_box(Vector3(1.18, 0.01, 0.26), Vector3(0.0, H - 0.085, -0.4), _colore(Color(0.6, 0.62, 0.6), 0.0, 0.3))


func _muro_col_vano(x: float, y0: float, y1: float, m: Material, spessore := 0.1, listello := false) -> void:
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
			if listello:
				_listelli.append([Vector3(spessore, hi - lo, b - a), Vector3(x, (lo + hi) * 0.5, (a + b) * 0.5), m])
			else:
				_box(Vector3(spessore, hi - lo, b - a), Vector3(x, (lo + hi) * 0.5, (a + b) * 0.5), m)


## Il telaio della porta di servizio e l'anta aperta, appoggiata al muro dentro la stanza.
func _telaio(pos: Vector3, rot: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot
	add_child(n)
	var telaio := _colore(Color(0.3, 0.32, 0.31), 0.6, 0.5)
	var anta := _colore(Color(0.98, 0.95, 0.82), 0.3, 0.55)
	for lato in [-1.0, 1.0]:
		_box(Vector3(0.06, 2.15, 0.14), Vector3(lato * (LARGO_PORTA * 0.5 - 0.03), 1.075, 0.0), telaio, n)
	_box(Vector3(LARGO_PORTA, 0.06, 0.14), Vector3(0, 2.12, 0.0), telaio, n)
	# l'anta spalancata fino al muro (180 gradi) verso dentro, sui cardini a destra: parallela al muro, 7 cm dentro la
	# stanza, con la maniglia fra l'anta e il muro, e la sua collisione (prima ci si passava attraverso). A 100 gradi lo
	# spessore sporgeva 4,9 cm nel vano dal lato dei cardini e il giocatore passava con 4 cm (controllo dei varchi di
	# grafica, 23 ottobre); così il passaggio è il vano intero, 0,5 m per lato dall'asse
	var cardine := Node3D.new()
	cardine.position = Vector3(LARGO_PORTA * 0.5 - 0.06, 0, 0.07)
	cardine.rotation_degrees.y = 180.0
	n.add_child(cardine)
	_box(Vector3(0.88, 2.04, 0.05), Vector3(-0.44, 1.03, -0.025), anta, cardine)
	_box(Vector3(0.14, 0.03, 0.05), Vector3(-0.78, 1.05, 0.02), _colore(Color(0.7, 0.7, 0.7), 0.9, 0.3), cardine)
	var xf := n.transform * cardine.transform
	_forma(Vector3(0.88, 2.04, 0.05), xf * Vector3(-0.44, 1.03, -0.025), rot + cardine.rotation_degrees.y)
	# i cardini: due perni sull'asse, nello spigolo dell'anta, davanti allo stipite (non dentro)
	for y in [0.35, 1.75]:
		_box(Vector3(0.025, 0.1, 0.025), Vector3(-0.0126, y, -0.0063), telaio, cardine)


# --- arredi --------------------------------------------------------------------------------------

func _arredi() -> void:
	_metti("scrivania", Vector3(0.3, 0, -L + 0.36), 0.0)
	_forma(Vector3(1.4, 0.81, 0.67), Vector3(0.3, 0.405, -L + 0.36))
	_metti("sedia", Vector3(0.15, 0, -2.05), 200.0)
	_forma(Vector3(0.5, 0.9, 0.5), Vector3(0.15, 0.45, -2.05))
	# la Polaroid del medico davanti allo schedario (l'indizio del cassetto)
	var foto := StandardMaterial3D.new()
	foto.albedo_color = Color(0.82, 0.82, 0.82)
	foto.albedo_texture = load(TEX + "polaroid_medico_B.jpg")
	foto.roughness = 0.6
	var pq := _quad(Vector2(0.088, 0.104), Vector3(0.5, 0.812, -2.62), Vector3(-90, -14, 0), foto)
	pq.name = "PolaroidMedico"
	var piano := 0.81
	_metti("lampada_tavolo", Vector3(-0.25, piano, -2.98), 30.0)
	var fg := _metti("fogli", Vector3(-0.05, piano, -2.72), 12.0)
	fg.scale = Vector3(1.0, 0.45, 1.0)
	_metti("fonendoscopio", Vector3(0.22, piano, -2.66), 40.0)
	_metti("timbri", Vector3(0.82, piano, -3.0), -10.0)
	_metti("bicchiere", Vector3(0.88, piano, -2.7), 0.0)
	_metti("cerotti", Vector3(0.66, piano, -3.02), 15.0)
	_metti("cestino", Vector3(1.15, 0, -2.9), 0.0)
	_metti("lettino", Vector3(L - 0.45, 0, 1.95), 0.0)
	_forma(Vector3(0.8, 0.65, 1.9), Vector3(L - 0.45, 0.325, 1.95))
	_metti("tenda_binario", Vector3(2.3, H, 1.55), 90.0)
	# il materasso è piano a 0,686 (da z -0,3 a 0,7 del lettino, dietro sale lo schienale): il lenzuolo ci appoggia
	# verso i piedi e l'orsetto davanti allo schienale (prima stavano 5 cm dentro il materasso)
	var lz := _metti("lenzuolo", Vector3(2.75, 0.686, 1.95 + 0.405), 0.0)
	lz.scale = Vector3(0.8, 0.35, 0.6)
	_metti("asciugamani", Vector3(2.7, 0.64, 2.75), 5.0)
	_metti("asta_flebo", Vector3(2.2, 0, 1.05), 0.0)
	_metti("sedia_rotelle", Vector3(0.35, 0, 2.55), 160.0)
	_forma(Vector3(0.7, 0.9, 0.9), Vector3(0.35, 0.45, 2.55), 160.0)
	_metti("bilancia", Vector3(-L + 0.35, 0, 2.55), 90.0)
	_forma(Vector3(0.5, 1.2, 0.5), Vector3(-L + 0.35, 0.6, 2.55))
	_forma_di(_metti("pronto_soccorso", Vector3(-L, 1.45, 0.35), 90.0))
	var ct := _metti("cartelle_terra", Vector3(-2.1, 0, -0.55), 30.0)
	ct.scale = Vector3(1.0, 0.3, 1.0)
	_metti("vetri_rotti", Vector3(2.75, 0.002, 0.15), 0.0)
	_metti("vetri_rotti", Vector3(0.5, 0.002, -1.6), 70.0)
	# il carrello accanto alla testa del lettino (la porta sud resta libera)
	_metti("carrello", Vector3(1.85, 0, 0.45), -90.0)
	_forma(Vector3(0.5, 0.9, 0.7), Vector3(1.85, 0.45, 0.45))
	# l'armadietto a muro e il lavandino sporgono all'altezza della testa e del busto: con la loro collisione
	var arm := _metti("armadietto", Vector3(L, 1.2, 0.35), -90.0)
	var ba := _box_di(arm)
	_forma(Vector3(ba.size.x, ba.end.y, ba.size.z), Vector3(ba.get_center().x, ba.end.y * 0.5, ba.get_center().z))   # fino a terra
	_forma_di(_metti("lavandino", Vector3(-0.6, 0.32, L), 180.0))


## Il negatoscopio sul muro nord sopra la scrivania (modello Meshy, pannello e lastra della logica) e
## accanto il pulsante del parco che lo accende.
func _negatoscopio() -> void:
	var c := Vector3(0.3, 1.72, -L)
	_metti("negatoscopio", c + Vector3(0, 0.1, 0), 0.0)
	interruttore = WaterButton.new()
	interruttore.name = "Interruttore"
	interruttore.mode = WaterButton.Mode.LATCH
	interruttore.show_model = false
	interruttore.radius = 0.16
	negatoscopio = Negatoscopio.new()
	negatoscopio.name = "Negatoscopio"
	negatoscopio.alimentazione = interruttore
	negatoscopio.mostra_segnaposto = false
	negatoscopio.lastra_tex = load(TEX + "radiografia.jpg")
	negatoscopio.puntini_tex = load(TEX + "radiografia_emi.jpg")
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.9, 0.5, 0.1)
	f.shape = b
	negatoscopio.add_child(f)
	negatoscopio.position = c + Vector3(0, 0.07, 0.104)
	add_child(negatoscopio)
	# la luce del pannello sulla scrivania: la accende il negatoscopio (segue la sua energia)
	var s := SpotLight3D.new()
	s.name = "LuceNegatoscopio"
	s.position = c + Vector3(0, 0, 0.25)
	add_child(s)
	s.look_at(global_transform * (c + Vector3(0, -0.9, 1.6)), Vector3.UP)
	s.light_color = Color(0.82, 0.9, 1.0)
	s.spot_range = 6.0
	s.spot_angle = 75.0
	s.shadow_enabled = true
	s.set_meta(&"risveglio_ignora", true)
	_luce_negatoscopio = s
	_pulsante_parco(Vector3(1.35, 1.25, -L))


var _luce_negatoscopio: SpotLight3D


## Il pulsante della botola preso dal GLB della sala (cassetta, fungo e vetro del lampeggiante), girato
## verso +Z con il retro sul muro; il bersaglio del getto è il WaterButton sul fungo.
func _pulsante_parco(muro: Vector3) -> void:
	var glb := (load("res://assets/ambiente/sala/sala_interattivi.glb") as PackedScene).instantiate()
	var rif := Vector3(2.25, -1.12, 4.72)   # il perno del fungo nel GLB (guarda verso -Z)
	var tieni := Node3D.new()
	tieni.name = "PulsanteParco"
	tieni.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -rif)
	var box := AABB()
	var primo := true
	_vetro_lampeggiante = StandardMaterial3D.new()
	_vetro_lampeggiante.albedo_color = Color(1.0, 0.85, 0.2, 0.8)
	_vetro_lampeggiante.emission_enabled = true
	_vetro_lampeggiante.emission = Color(1.0, 0.75, 0.1)
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
			if mi is MeshInstance3D and nome == "sala_lampeggiante_portello":
				(mi as MeshInstance3D).material_override = _vetro_lampeggiante
	glb.free()
	var base := Node3D.new()
	base.name = "Pulsante"
	add_child(base)
	base.add_child(tieni)
	base.position = Vector3(muro.x, muro.y, muro.z - box.position.z)
	interruttore.position = Vector3(muro.x, muro.y, muro.z + box.end.z - box.position.z + 0.02)
	add_child(interruttore)
	_luce_lampeggiante = _luce(base.position + Vector3(0, 0.55, box.end.z + 0.2), Color(1.0, 0.75, 0.1), 0.0, 2.5, false)


## Due schedari da cinque cassetti contro il muro ovest; nel secondo dall'alto di quello a destra
## (guardandoli; il primo, a nord) l'adesivo rosa che brilla al buio, come nella Polaroid, e dentro la
## radiografia.
const CASSETTI_Y := [[0.05, 0.33], [0.33, 0.56], [0.56, 0.78], [0.78, 1.04], [1.04, 1.31]]


func _schedari() -> void:
	var tinta := Color(1.0, 0.8, 0.86)
	radiografia = Pickup.new()
	radiografia.name = "Radiografia"
	radiografia.item_id = &"radiografia"
	radiografia.item_name = "Radiografia"
	var fr := CollisionShape3D.new()
	var br := BoxShape3D.new()
	br.size = Vector3(0.3, 0.12, 0.3)
	fr.shape = br
	radiografia.add_child(fr)
	# la cartella color manila con la lastra
	var mc := _colore(Color(0.85, 0.75, 0.5), 0.0, 0.8)
	_box(Vector3(0.25, 0.01, 0.32), Vector3.ZERO, mc, radiografia)
	for i in 2:
		var x := -L + 0.2
		var z := -1.3 + i * 0.46
		var s := _metti("schedario_vero", Vector3(x, 0, z), 90.0)
		_tingi(s, tinta)
		_forma(Vector3(0.35, 1.35, 0.42), Vector3(x, 0.675, z))
		for k in CASSETTI_Y.size():
			var y0: float = CASSETTI_Y[k][0]
			var y1: float = CASSETTI_Y[k][1]
			var cas := CassettoSchedario.new()
			cas.name = "Cassetto%d%d" % [i + 1, k + 1]
			cas.mostra_segnaposto = false
			cas.misura = Vector3(0.36, y1 - y0 - 0.02, 0.38)   # tirato, il fondo arriva alla faccia dello schedario
			cas.tinta = tinta
			cas.corsa = 0.38
			cas.fino_a_terra = (y0 + y1) * 0.5
			var giusto := i == 0 and k == 3
			cas.adesivo = giusto
			var f := CollisionShape3D.new()
			var b := BoxShape3D.new()
			b.size = Vector3(0.38, y1 - y0, 0.06)
			f.shape = b
			cas.add_child(f)
			# il frontale guarda verso +X (dentro la stanza): +Z del cassetto verso +X
			# l'origine sulla faccia vera dei cassetti del modello (15,1-15,3 cm dal centro, misurata coi raggi;
			# prima a 17,7, sul bordo delle maniglie: l'adesivo restava 2,6 cm davanti al cassetto chiuso, e quello tirato,
			# fuori di 38 cm, non entrava più nello schedario)
			cas.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x + 0.1535, (y0 + y1) * 0.5, z))
			add_child(cas)
			if giusto:
				cas.contenuto = radiografia
				var ad := _adesivo()
				cas.get_node("Frontale").add_child(ad)
				ad.position = Vector3(-0.08, (y1 - y0) * 0.5 - 0.075, 0.0015)   # sul frontale, 0,5 mm davanti (spesso 2 mm)
				# dentro il cassetto: esce con lui
				cas.get_node("Frontale").add_child(radiografia)
				radiografia.position = Vector3(0, -(y1 - y0) * 0.5 + 0.051, -0.2)   # sul fondo del cassetto, 1 mm sopra (a filo le facce coincidevano)
				cas.call(&"_metti")
			cassetti.append(cas)


## L'adesivo rosa fosforescente (un disco di 7 cm) col suo alone.
func _adesivo() -> Node3D:
	var n := Node3D.new()
	n.name = "Adesivo"
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
	d.rotation_degrees = Vector3(90, 0, 0)
	n.add_child(d)
	var g := OmniLight3D.new()
	g.name = "AloneAdesivo"
	g.light_color = Color(1.0, 0.3, 0.75)
	g.light_energy = 0.25
	g.omni_range = 1.2
	g.position = Vector3(0, 0, 0.12)
	g.set_meta(&"risveglio_ignora", true)
	n.add_child(g)
	return n


## La cassaforte nel muro est: il vano d'acciaio con la cornice, e la CassaforteRotelle col suo
## sportello vero sui cardini. Dentro la keycard 1 e la Polaroid della pecora.
func _cassaforte() -> void:
	var c := CASSA
	var h := VANO * 0.5
	var scuro := _colore(Color(0.2, 0.21, 0.21), 0.7, 0.5)
	var p := 0.3
	_box(Vector3(0.02, VANO, VANO), Vector3(c.x + p, c.y, c.z), scuro)
	for dy in [-h, h]:
		_box(Vector3(p, 0.02, VANO), Vector3(c.x + p * 0.5, c.y + dy, c.z), scuro)
	for dz in [-h, h]:
		_box(Vector3(p, VANO, 0.02), Vector3(c.x + p * 0.5, c.y, c.z + dz), scuro)
	for dy in [-h - 0.03, h + 0.03]:
		_box(Vector3(0.03, 0.06, VANO + 0.12), Vector3(c.x - 0.015, c.y + dy, c.z), scuro)
	for dz in [-h - 0.03, h + 0.03]:
		_box(Vector3(0.03, VANO, 0.06), Vector3(c.x - 0.015, c.y, c.z + dz), scuro)
	var fondo := c.y - h + 0.011
	keycard = Pickup.new()
	keycard.name = "Keycard"
	keycard.item_id = &"keycard"
	keycard.item_name = "Keycard"
	var fk := CollisionShape3D.new()
	var bk := BoxShape3D.new()
	bk.size = Vector3(0.14, 0.06, 0.12)
	fk.shape = bk
	keycard.add_child(fk)
	_tessera(keycard)
	add_child(keycard)
	keycard.position = Vector3(c.x + 0.12, fondo, c.z + 0.08)
	keycard.rotation_degrees.y = 18.0
	# la Polaroid della pecora che brilla (P11, scelta dell'utente del 21 ottobre): la stessa delle altre,
	# appoggiata sul fondo accanto alla keycard; si raccoglie e va nella collezione
	var polaroid := (load("res://scenes/props/polaroid.tscn") as PackedScene).instantiate() as PolaroidPhoto
	polaroid.name = "PolaroidPecora"
	polaroid.photo = 11
	polaroid.snap_to_surface = false
	add_child(polaroid)
	polaroid.position = Vector3(c.x + 0.2, fondo, c.z - 0.1)
	polaroid.rotation_degrees.y = 75.0
	cassaforte = CassaforteRotelle.new()
	cassaforte.name = "Cassaforte"
	cassaforte.mostra_segnaposto = false
	cassaforte.modello_sportello = load(DIR + "sportello_cassaforte_N.glb")
	cassaforte.cifre_tex = load(TEX + "rotella_cifre.jpg")
	cassaforte.simboli = [load(TEX + "simbolo_testa.png"), load(TEX + "simbolo_corpo.png"), load(TEX + "simbolo_coda.png")]
	cassaforte.passo = 0.13   # (rotelle di 9 cm, 4 cm fra l'una e l'altra: con lo sportello aperto non si toccano)
	cassaforte.contenuto = [keycard, polaroid]
	# lo sportello guarda verso -X (la stanza), i cardini dal lato -Z del vano
	# lo sportello gira sullo spigolo davanti, coi cardini; dietro appoggia sulla cornice (prima il nodo era sullo
	# spigolo davanti ma lo sportello gli stava davanti: chiuso restava 7,5 cm staccato dalla cornice)
	cassaforte.spessore_sportello = 0.075
	cassaforte.faccia_sportello = -0.075 + 0.037   # la faccia del modello è a 3,7 cm dal retro (il bordo a 7,5): misurata coi raggi
	cassaforte.barriera_fino_a_terra = c.y   # (prima la metteva _process, che nel controllo è fermo)
	cassaforte.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(c.x - 0.03 - 0.075, c.y, c.z - h - 0.03))
	add_child(cassaforte)
	# i cardini: la piastra sulla cornice fino all'asse, e il perno
	for dy in [-0.2, 0.2]:
		_box(Vector3(0.075, 0.08, 0.03), Vector3(c.x - 0.03 - 0.0375, c.y + dy, c.z - h - 0.045), scuro)
		var cd := MeshInstance3D.new()
		cd.name = "Cardine"
		var cm := CylinderMesh.new()
		# (il perno arriva allo spigolo smussato dello sportello, a 2,5 cm dall'asse: prima, sottile, lo sportello aperto
		# non toccava niente)
		cm.top_radius = 0.0235
		cm.bottom_radius = 0.0235
		cm.height = 0.1
		cd.mesh = cm
		cd.material_override = scuro
		cd.position = Vector3(c.x - 0.03 - 0.075, c.y + dy, c.z - h - 0.03)
		add_child(cd)
	# la luce che entra nel vano (si accende con lo sportello aperto)
	var lv := _luce(Vector3(c.x + 0.05, c.y + 0.18, c.z), Color(1.0, 0.6, 0.5), 0.7, 1.0, false)
	lv.name = "LuceVano"
	lv.visible = false
	cassaforte.aperta.connect(func(): lv.visible = true)


## La keycard 1: 85,6 x 54 mm, spessa 0,8, stesa con la faccia in su.
func _tessera(padre: Node3D) -> void:
	_box(Vector3(0.084, 0.0008, 0.052), Vector3.ZERO, _colore(Color(0.9, 0.9, 0.88), 0.0, 0.4), padre)
	var f := StandardMaterial3D.new()
	f.albedo_texture = load("res://assets/tessera/texture/tessera_1.png")
	f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	f.roughness = 0.3
	_quad(Vector2(0.0856, 0.054), Vector3(0, 0.0005, 0), Vector3(-90, 0, 0), f, padre)


func _luci() -> void:
	# la lampada d'emergenza rossa sopra la porta d'ingresso e una sul muro est, sopra la cassaforte
	# (i punti sono sulla faccia dei muri: la staffa si appoggia al muro)
	for p in [[Vector3(PORTA_SUD, 2.55, L), Vector3(0, -0.5, -1)], [Vector3(L, 2.5, -1.05), Vector3(-1, -0.7, 0)]]:
		var l := LampadaMuro.monta(self, p[0], p[1])
		_luce(l.position + (p[1] as Vector3).normalized() * 0.3, Color(1.0, 0.16, 0.1), 1.6, 6.0, true)
	# il cartello d'uscita verde sopra la porta della scala, acceso (luce d'emergenza a batteria)
	var mf := StandardMaterial3D.new()
	mf.albedo_texture = load("res://assets/fiume_lento/texture/uscita_faccia.jpg")
	mf.emission_enabled = true
	mf.emission_texture = mf.albedo_texture
	mf.emission_energy_multiplier = 2.5
	_box(Vector3(0.5, 0.26, 0.08), Vector3(PORTA_NORD, 2.38, -L + 0.04), _colore(Color(0.8, 0.8, 0.76)))
	_quad(Vector2(0.46, 0.23), Vector3(PORTA_NORD, 2.38, -L + 0.082), Vector3.ZERO, mf)
	_luce(Vector3(PORTA_NORD, 2.2, -L + 0.4), Color(0.2, 1.0, 0.4), 0.35, 3.0, false)


func _bambini() -> void:
	_metti("giraffa_metro", Vector3(2.45, 0.05, -L), 0.0)
	var mp := StandardMaterial3D.new()
	mp.albedo_texture = load("res://assets/ambienti_interni/texture/cartellone_medusa_vecchio.jpg")
	mp.roughness = 0.7
	_box(Vector3(0.02, 1.04, 0.79), Vector3(-L + 0.01, 1.85, 1.45), _colore(Color(0.95, 0.75, 0.85)))
	_quad(Vector2(0.75, 1.0), Vector3(-L + 0.022, 1.85, 1.45), Vector3(0, 90, 0), mp)
	# (a 3 mm dal muro: a 12 mm sembravano staccati)
	var posti := [[Vector3(-L + 0.003, 2.35, -0.3), 90.0, 0.62], [Vector3(-0.9, 2.25, L - 0.003), 180.0, 0.6],
			[Vector3(L - 0.003, 2.3, 1.75), -90.0, 0.7], [Vector3(1.0, 2.45, -L + 0.003), 0.0, 0.55],
			[Vector3(-1.2, 2.35, -L + 0.003), 0.0, 0.6], [Vector3(L - 0.003, 0.9, 0.55), -90.0, 0.5],
			[Vector3(-L + 0.003, 0.75, 0.6), 90.0, 0.45]]
	for i in posti.size():
		var t := load(TEX + "adesivo_%d.png" % (i % 5)) as Texture2D
		var m := StandardMaterial3D.new()
		m.albedo_texture = t
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.roughness = 0.5
		var h: float = posti[i][2]
		var w := h * float(t.get_width()) / float(t.get_height())
		_quad(Vector2(w, h), posti[i][0], Vector3(0, posti[i][1], 0), m)
	_metti("orsetto", Vector3(2.75, 0.686, 1.95 - 0.08), 180.0)
	_metti("trenino", Vector3(-0.9, 0, 1.3), 35.0)
	_metti("cavallo_dondolo", Vector3(-2.45, 0, 0.95), 60.0)
	_forma(Vector3(0.4, 0.8, 1.0), Vector3(-2.45, 0.4, 0.95), 60.0)
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


# --- checkpoint dopo ogni passo -----------------------------------------------------------------------

var _cp: Array[Checkpoint] = []


func _checkpoint() -> void:
	var n := Node3D.new()
	n.name = "Checkpoint"
	add_child(n)
	# si riparte in mezzo alla stanza, verso la scrivania
	var spawn := Marker3D.new()
	spawn.name = "Ripartenza"
	spawn.position = Vector3(0.6, 0, 0.6)
	spawn.rotation_degrees.y = 20.0
	n.add_child(spawn)
	for i in 3:
		var cp := Checkpoint.new()
		cp.name = ["DopoLuce", "DopoRadiografia", "DopoNegatoscopio"][i]
		cp.order = ordine_checkpoint + i
		cp.spawn_point = spawn
		cp.monitoring = false
		n.add_child(cp)
		_cp.append(cp)
	interruttore.powered_changed.connect(func(on: bool): if on: _raggiunto(0))
	radiografia.interacted.connect(func(_by): _raggiunto(1))
	negatoscopio.radiografia_appoggiata.connect(func(): _raggiunto(2))


func _raggiunto(i: int) -> void:
	GameState.reach_checkpoint.call_deferred(_cp[i])


func _marker() -> void:
	var m := Node3D.new()
	m.name = "Marker"
	add_child(m)
	for d in [["PortaSud", Vector3(PORTA_SUD, 0, L + 0.1)], ["PortaNord", Vector3(PORTA_NORD, 0, -L - 0.1)]]:
		var k := Marker3D.new()
		k.name = d[0]
		k.position = d[1]
		m.add_child(k)


func _process(delta: float) -> void:
	_t += delta
	# il lampeggiante: lampi gialli finché non lo colpisci, poi verde fisso
	var on := interruttore.powered
	var k := 1.0 if on else (1.0 if fmod(_t, 1.6) < 0.25 else 0.0)
	_vetro_lampeggiante.albedo_color = (Color(0.3, 1.0, 0.45, 0.8) if on else Color(1.0, 0.85, 0.2, 0.8))
	_vetro_lampeggiante.emission = Color(0.15, 1.0, 0.3) if on else Color(1.0, 0.75, 0.1)
	_vetro_lampeggiante.emission_energy_multiplier = 3.0 * k
	_luce_lampeggiante.light_color = _vetro_lampeggiante.emission
	_luce_lampeggiante.light_energy = 0.6 * k
	# la luce del negatoscopio segue il pannello (sfarfalla senza corrente)
	_luce_negatoscopio.light_energy = 3.0 if negatoscopio.e_acceso() else (0.9 if fmod(_t * 7.3, 5.0) < 0.6 else 0.05)
