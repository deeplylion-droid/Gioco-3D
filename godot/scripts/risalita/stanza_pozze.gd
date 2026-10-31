extends Node3D
## La stanza delle pozze colorate (GDD, "La stanza delle pozze colorate", scelte dell'utente del 31 ottobre): subito dopo
## l'infermeria, dalla sua porta nord; si esce dalla porta stagna nel muro nord, sul piede della scala di servizio.
## Una stanza quadrata di servizio delle piscine, illuminata (le sue luci sono sulla linea delle pompe riaccese): 25 pozze
## quadrate in 5x5, contigue, profonde 75 cm a filo del pavimento con un bordino di piastrelle, e intorno una passerella
## di grigliato larga 1,2 m da cui si aspira. Qui ci sono la stanza, le vasche (fondo, pareti e bordini, tutto con la
## collisione), la porta stagna, le luci, la lampada dell'errore e i checkpoint; l'acqua, i colori e la logica sono di
## enigmi (EnigmaPozze, scripts/game/enigma_pozze.gd), che si attacca al nodo EnigmaPozze.
## Coordinate: l'origine è al centro della griglia delle pozze, sul pavimento (la passerella e il bordo delle pozze sono a
## 0); la stanza va da -MEZZA a MEZZA in X e in Z, alta ALTA. La porta nord dell'infermeria è a x 0 nel muro sud (z
## MEZZA), la porta stagna a x PORTA_X nel muro nord (z -MEZZA).

## Le pozze: lato interno, passo da centro a centro (fra due pozze un bordino di 10 cm), profondità interna, quante per lato.
const LATO := 1.0
const PASSO := 1.1
const PROFONDITA := 0.75
const N := 5
## Metà del lato interno della stanza (passerella di 1,2 m intorno alle pozze) e altezza.
const MEZZA := 4.0
const ALTA := 3.6
## Spessore dei muri; il muro nord è doppio (40 cm): dall'altra parte c'è il pianerottolo della scala, col suo muro.
const MURO := 0.2
## La porta stagna nel muro nord (x del centro del vano).
const PORTA_X := -1.7
## Dove comincia, verso ovest, il muro dell'infermeria (che fa da muro sud fra x INFERMERIA_X e MEZZA): la porta nord
## dell'infermeria è a x 0.
const INFERMERIA_X := -1.1
const SALA := "res://scripts/game/enigma_pozze.gd"
## L'ordine del checkpoint d'ingresso: lo stesso dell'ultimo dell'infermeria (14); quello a enigma risolto ha il 15, come
## il magazzino (la serranda è il 16).
const ORDINE := 14

## Costruzione un passo per fotogramma (vedi [method costruisci_a_pezzi]).
var costruzione_a_pezzi := false
var costruita := false

var mat_piastrelle: StandardMaterial3D
var mat_piastrelle_pozza: StandardMaterial3D
var mat_intonaco: StandardMaterial3D
var mat_soffitto: StandardMaterial3D
var mat_grata: StandardMaterial3D
var mat_cemento: StandardMaterial3D
var mat_acciaio: StandardMaterial3D
var _collisioni: StaticBody3D


func _ready() -> void:
	if not costruzione_a_pezzi:
		_costruisci()


## Costruisce la stanza un passo per fotogramma: il nodo va messo nella scena con [member costruzione_a_pezzi] vero, poi
## si aspetta questa.
func costruisci_a_pezzi() -> void:
	if not costruita:
		await _costruisci()


func _pausa() -> void:
	if costruzione_a_pezzi:
		await get_tree().process_frame


func _costruisci() -> void:
	const TI := "res://assets/infermeria/texture/"
	const TA := "res://assets/ambienti_interni/texture/"
	mat_piastrelle = _mat(TI + "piastrelle_piccole", Color(0.93, 0.95, 0.95), 1.2)
	mat_piastrelle_pozza = _mat(TI + "piastrelle_piccole", Color(0.97, 0.98, 0.98), 1.6)
	mat_intonaco = _mat(TI + "intonaco", Color(0.78, 0.8, 0.8), 0.5)
	mat_soffitto = _mat(TI + "intonaco", Color(0.62, 0.63, 0.62), 0.4)
	mat_grata = StandardMaterial3D.new()
	mat_grata.albedo_texture = load(TA + "lamiera_grata_col.jpg")
	mat_grata.normal_enabled = true
	mat_grata.normal_texture = load(TA + "lamiera_grata_nrm.jpg")
	mat_grata.roughness_texture = load(TA + "lamiera_grata_met-lamiera_grata_rgh.jpg")
	mat_grata.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat_grata.metallic_texture = mat_grata.roughness_texture
	mat_grata.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat_grata.metallic = 1.0
	mat_grata.uv1_triplanar = true
	mat_grata.uv1_world_triplanar = true
	mat_grata.uv1_scale = Vector3.ONE * 1.0
	mat_cemento = _mat(TI + "graniglia_grigia", Color(0.55, 0.55, 0.53), 0.6)
	mat_acciaio = StandardMaterial3D.new()
	mat_acciaio.albedo_color = Color(0.4, 0.43, 0.45)
	mat_acciaio.metallic = 0.7
	mat_acciaio.roughness = 0.45
	_collisioni = StaticBody3D.new()
	_collisioni.name = "Collisioni"
	add_child(_collisioni)
	_stanza()
	await _pausa()
	_pozze()
	await _pausa()
	_porta()
	_luci()
	await _pausa()
	_lampeggiante()
	# (prima i checkpoint: EnigmaPozze nel suo _ready cerca CheckpointRisolto)
	_checkpoint()
	_enigma()
	costruita = true


func _mat(base: String, tinta: Color, scala: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(base + "_col.jpg")
	m.albedo_color = tinta
	m.normal_enabled = true
	m.normal_texture = load(base + "_nrm.jpg")
	m.roughness_texture = load(base + "_rgh.jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scala
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Un box che si vede e, con [param collisione], la sua forma nel corpo della stanza.
func _box(size: Vector3, pos: Vector3, m: Material, collisione := true, padre: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	padre.add_child(mi)
	if collisione:
		var f := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		f.shape = s
		f.position = pos
		_collisioni.add_child(f)
	return mi


## Un muro in [param x0]-[param x1] (o z) con lo zoccolo di piastrelle alto 1,5 m e sopra l'intonaco; [param buco]: [centro
## lungo il muro, mezza larghezza, altezza] di un vano dal pavimento, o vuoto.
func _muro(asse_x: bool, a0: float, a1: float, piano: float, spessore: float, buco := []) -> void:
	var tratti := [[a0, a1, 0.0, ALTA]]
	if not buco.is_empty():
		var c: float = buco[0]
		var r: float = buco[1]
		var h: float = buco[2]
		tratti = [[a0, c - r, 0.0, ALTA], [c + r, a1, 0.0, ALTA], [c - r, c + r, h, ALTA]]
	for t in tratti:
		var b0: float = t[0]
		var b1: float = t[1]
		if b1 - b0 < 0.005:
			continue
		for fascia in [[t[2], maxf(t[2], minf(1.5, t[3])), mat_piastrelle], [maxf(t[2], 1.5), t[3], mat_intonaco]]:
			var y0: float = fascia[0]
			var y1: float = fascia[1]
			if y1 - y0 < 0.005:
				continue
			var size := Vector3(b1 - b0, y1 - y0, spessore) if asse_x else Vector3(spessore, y1 - y0, b1 - b0)
			var c := (b0 + b1) * 0.5
			var pos := Vector3(c, (y0 + y1) * 0.5, piano) if asse_x else Vector3(piano, (y0 + y1) * 0.5, c)
			_box(size, pos, fascia[2])


func _stanza() -> void:
	var m := MEZZA
	# i muri: ovest ed est interi, nord col vano della porta stagna (doppio: dietro c'è il pianerottolo), sud solo a ovest
	# dell'infermeria (il resto è il suo muro, con la sua porta nord)
	_muro(false, -m - MURO, m + MURO, -m - MURO * 0.5, MURO)
	# (l'est finisce al muro dell'infermeria, che va da z MEZZA a MEZZA + 0,1 fino a x MEZZA + 1,5)
	_muro(false, -m - MURO, m, m + MURO * 0.5, MURO)
	_muro(true, -m - MURO, m + MURO, -m - MURO * 0.5, MURO, [PORTA_X, PortaStagna.LARGO * 0.5, PortaStagna.ALTO])
	_muro(true, -m - MURO, INFERMERIA_X, m + MURO * 0.5, MURO)
	# sopra il muro dell'infermeria (alto 3 m, col soffitto fino a 3,1) la fascia fino al soffitto della stanza
	_box(Vector3(m + MURO - INFERMERIA_X, ALTA - 3.1, MURO), Vector3((INFERMERIA_X + m + MURO) * 0.5, (3.1 + ALTA) * 0.5, m + MURO * 0.5), mat_intonaco)
	# il soffitto e la soletta sotto la passerella (dove non ci sono le pozze)
	_box(Vector3(2.0 * (m + MURO), 0.2, 2.0 * (m + MURO)), Vector3(0, ALTA + 0.1, 0), mat_soffitto)
	var g := N * PASSO * 0.5 + 0.05      # metà del quadrato delle pozze, col bordino esterno (2,8)
	for d in [[Vector3(2.0 * m, 0.2, m - g), Vector3(0, 0, -(m + g) * 0.5)], [Vector3(2.0 * m, 0.2, m - g), Vector3(0, 0, (m + g) * 0.5)],
			[Vector3(m - g, 0.2, 2.0 * g), Vector3(-(m + g) * 0.5, 0, 0)], [Vector3(m - g, 0.2, 2.0 * g), Vector3((m + g) * 0.5, 0, 0)]]:
		# la soletta di cemento 3 cm sotto (sotto il grigliato, il canale di scolo) e il grigliato della passerella a filo
		# del bordo delle pozze: la collisione del pavimento è il grigliato, a 0
		_box(d[0], d[1] + Vector3(0, -0.13, 0), mat_cemento, false)
		var gr := _box(Vector3(d[0].x, 0.03, d[0].z), d[1] + Vector3(0, -0.015, 0), mat_grata)
		gr.name = "Grigliato"


## Le 25 vasche: il fondo, i bordini fra le pozze (10 cm) e quelli esterni, tutto in piastrelle bianche, a filo del
## pavimento. L'acqua la mette EnigmaPozze.
func _pozze() -> void:
	var g := N * PASSO * 0.5          # 2,75: il bordo esterno delle pozze di fuori più mezzo bordino
	var fondo := -PROFONDITA
	# il fondo, spesso 20 cm, sotto tutto il quadrato
	_box(Vector3(2.0 * g + 0.1, 0.2, 2.0 * g + 0.1), Vector3(0, fondo - 0.1, 0), mat_piastrelle_pozza)
	# i bordini: N + 1 per verso, larghi 10 cm, dal fondo al pavimento
	for k in N + 1:
		var c := -g + k * PASSO
		var lungo := 2.0 * g + 0.1
		_box(Vector3(0.1, PROFONDITA, lungo), Vector3(c, fondo * 0.5, 0), mat_piastrelle_pozza)
		_box(Vector3(lungo, PROFONDITA, 0.1), Vector3(0, fondo * 0.5, c), mat_piastrelle_pozza)


func _porta() -> void:
	# il pavimento nel vano, sotto lo spessore del muro (fra la passerella e il pianerottolo della scala)
	_box(Vector3(PortaStagna.LARGO + 0.04, 0.2, MURO), Vector3(PORTA_X, -0.1, -MEZZA - MURO * 0.5), mat_cemento)
	var p := PortaStagna.new()
	p.name = "PortaStagna"
	p.position = Vector3(PORTA_X, 0, -MEZZA)
	add_child(p)


## Le luci: due file di plafoniere al soffitto, bianche, sulla linea delle pompe riaccese. Una sola fa le ombre.
func _luci() -> void:
	var mat_tubo := StandardMaterial3D.new()
	mat_tubo.albedo_color = Color(0.95, 0.97, 1.0)
	mat_tubo.emission_enabled = true
	mat_tubo.emission = Color(0.95, 0.97, 1.0)
	mat_tubo.emission_energy_multiplier = 4.0
	var i := 0
	for x in [-2.0, 2.0]:
		for z in [-1.8, 1.8]:
			var pl := Node3D.new()
			pl.name = "Plafoniera%d" % (i + 1)
			pl.position = Vector3(x, ALTA, z)
			add_child(pl)
			_box(Vector3(0.22, 0.08, 1.3), Vector3(0, -0.04, 0), mat_acciaio, false, pl)
			_box(Vector3(0.12, 0.03, 1.2), Vector3(0, -0.095, 0), mat_tubo, false, pl)
			var o := OmniLight3D.new()
			o.name = "Luce"
			o.light_color = Color(0.97, 0.98, 1.0)
			o.light_energy = 1.6
			o.omni_range = 7.0
			o.omni_attenuation = 1.1
			o.shadow_enabled = i == 0
			o.position = Vector3(0, -0.4, 0)
			o.set_meta(&"risveglio_ignora", true)
			pl.add_child(o)
			i += 1


## La lampada dell'errore (di enigmi la accende e la fa lampeggiare): un lampeggiante rosso girevole sul muro nord, a
## destra della porta stagna, ben in vista entrando dall'infermeria; la luce figlia è spenta.
func _lampeggiante() -> void:
	var l := Node3D.new()
	l.name = "LampeggianteErrore"
	l.position = Vector3(PORTA_X + 1.6, 2.6, -MEZZA)
	add_child(l)
	# la staffa al muro e la base, poi la cupola rossa
	_box(Vector3(0.14, 0.04, 0.2), Vector3(0, -0.02, 0.1), mat_acciaio, false, l)
	var base := MeshInstance3D.new()
	var cb := CylinderMesh.new()
	cb.top_radius = 0.07
	cb.bottom_radius = 0.075
	cb.height = 0.05
	base.mesh = cb
	base.material_override = mat_acciaio
	base.position = Vector3(0, 0.025, 0.14)
	l.add_child(base)
	var cupola := MeshInstance3D.new()
	cupola.name = "Cupola"
	var cs := CylinderMesh.new()
	cs.top_radius = 0.045
	cs.bottom_radius = 0.065
	cs.height = 0.12
	cupola.mesh = cs
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.6, 0.05, 0.04)
	mc.roughness = 0.2
	cupola.material_override = mc
	cupola.position = Vector3(0, 0.11, 0.14)
	l.add_child(cupola)
	# la cupola accesa: EnigmaPozze la mostra mentre lampeggia
	var acceso := MeshInstance3D.new()
	acceso.name = "Acceso"
	acceso.mesh = cs
	var ma := StandardMaterial3D.new()
	ma.albedo_color = Color(1.0, 0.2, 0.12)
	ma.emission_enabled = true
	ma.emission = Color(1.0, 0.12, 0.06)
	ma.emission_energy_multiplier = 6.0
	acceso.material_override = ma
	acceso.position = cupola.position
	acceso.scale = Vector3.ONE * 1.01
	acceso.visible = false
	l.add_child(acceso)
	var o := OmniLight3D.new()
	o.name = "Luce"
	o.light_color = Color(1.0, 0.1, 0.06)
	o.light_energy = 2.5
	o.omni_range = 6.0
	o.visible = false
	o.position = Vector3(0, 0.11, 0.3)
	o.set_meta(&"risveglio_ignora", true)
	l.add_child(o)


## Il nodo della logica di enigmi: al centro della griglia, alla quota del pavimento, con le misure delle pozze.
func _enigma() -> void:
	var e: Node3D
	if ResourceLoader.exists(SALA):
		e = (load(SALA) as Script).new() as Node3D
	else:
		e = Node3D.new()
	e.name = "EnigmaPozze"
	e.set(&"lato", LATO)
	e.set(&"passo", PASSO)
	e.set(&"profondita", PROFONDITA)
	add_child(e)


## I checkpoint: all'ingresso (appena passata la porta dell'infermeria) e a enigma risolto, davanti alla porta stagna
## (quello lo fa scattare EnigmaPozze: l'area è spenta).
func _checkpoint() -> void:
	var n := Node3D.new()
	n.name = "Checkpoint"
	add_child(n)
	var ingresso := Checkpoint.new()
	ingresso.name = "CheckpointIngresso"
	ingresso.order = ORDINE
	ingresso.position = Vector3(0, 1.0, MEZZA - 0.8)
	var f := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(2.0, 2.0, 1.2)
	f.shape = s
	ingresso.add_child(f)
	var spawn := Marker3D.new()
	spawn.name = "Ripartenza"
	spawn.position = Vector3(0, -1.0, 0.2)
	ingresso.add_child(spawn)
	ingresso.spawn_point = spawn
	n.add_child(ingresso)
	var risolto := Checkpoint.new()
	risolto.name = "CheckpointRisolto"
	risolto.order = ORDINE + 1
	risolto.monitoring = false
	risolto.position = Vector3(PORTA_X, 0, -MEZZA + 0.7)
	var spawn2 := Marker3D.new()
	spawn2.name = "Ripartenza"
	risolto.add_child(spawn2)
	risolto.spawn_point = spawn2
	n.add_child(risolto)
