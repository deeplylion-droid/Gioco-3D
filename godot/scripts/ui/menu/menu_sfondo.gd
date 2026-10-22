class_name MenuSfondo
extends Node3D
## Le prove dello sfondo della schermata del titolo (richiesta dell'utente del 22 ottobre: il menu è "tutto
## nero", la statua sospesa nel buio). Tre strati, accendibili e spegnibili, fatti con asset che ci sono già
## nel gioco e senza caricare la sala principale:
## - A, la cupola nella tempesta: la cupola di vetro dell'acquapark (sala_cupola.glb, col vetro della
##   pioggia) sul tamburo di muro, il cielo della tempesta; a ogni lampo si vedono le
##   travi di ferro e, oltre il vetro, la sagoma della torre degli scivoli;
## - B, l'acqua ai suoi piedi: il piedistallo esce da una vasca allagata (WaterBody scura dell'addon
##   dell'acqua, che riflette lei e le luci rosse), gocce dall'alto che fanno cerchi, una paperella e un
##   pallone che galleggiano; in fondo, sulla parete, l'insegna di Jilly Jubilee che sfarfalla;
## - C, la sala del parco: sulla parete di fondo, sfocate nella nebbia, le ghirlande di lampadine mezze
##   spente (agganciate al muro), i neon sopra i manifesti e la cornice di lampadine del portone della torre.
## Sono solo prove: nel menu del gioco gli strati sono spenti finché l'utente non sceglie.
## Il menu la istanzia come figlio "Sfondo" (scenes/ui/menu_principale.tscn); la parte sinistra
## dell'inquadratura resta scura (lì vanno il logo e le voci).

## Gli strati.
@export var cupola := false
@export var acqua := false
@export var sala := false
## La tempesta del menu: i suoi lampi accendono il vetro della cupola e il cielo.
@export var tempesta: Tempesta
## Per le prove: "A,B" e simili nella variabile d'ambiente MENU_SFONDO accende quegli strati.
@export var leggi_ambiente := true

## La parete di fondo (z), larga da X_PARETE.x a X_PARETE.y, alta quanto la base della cupola.
const Z_PARETE := -18.0
const X_PARETE := Vector2(-40.0, 40.0)
const BASE_CUPOLA := 9.0
const R_CUPOLA := 13.0
## Il centro della cupola (come nella sala: 5 m dietro la statua, con il bordo sulla parete di fondo).
const CENTRO_CUPOLA := Vector3(0.0, 0.0, -5.0)
## Il portone della torre sulla parete di fondo: centro (x) e larghezza, alto 5,5 m.
const PORTONE_X := 6.5
const PORTONE_LARGO := 6.9
## Il livello dell'acqua della vasca allagata (il piedistallo poggia sul fondo, a 0): mezzo metro, così
## all'inizio della salita (la camera è a 0,7 m) lo specchio d'acqua entra nell'inquadratura.
const LIVELLO := 0.5

const CUPOLA_GLB := "res://assets/ambiente/sala/sala_cupola.glb"
const VETRO_CUPOLA := "res://assets/materials/sala/vetro_cupola.tres"
const CIELO := "res://addons/grafica/cielo_tempesta.gdshader"
const TORRE_GLB := "res://assets/ambiente/torre/torre_struttura.glb"
const ACQUA_SHADER := "res://shaders/water_murky.gdshader"
const PAPERELLA := "res://assets/fiume_lento/paperella.glb"
const PALLONE := "res://assets/fiume_lento/pallone.glb"
const INSEGNA := "res://assets/models/mascotte/jilly/insegna.glb"
const MANIFESTO := "res://assets/models/mascotte/jilly/manifesto.glb"
const MURO_COL := "res://assets/ambiente/sala/sala_architettura_parete_col.jpg"
const MURO_NRM := "res://assets/ambiente/sala/sala_architettura_intonaco_scrostato_nrm.jpg"
const MURO_ORM := "res://assets/ambiente/sala/sala_architettura_intonaco_scrostato_orm.jpg"
const MM_PORTALAMPADE := "res://assets/enigma_acquari/portalampade_portone.res"
const MM_ACCESE := "res://assets/enigma_acquari/lampadine_accese.res"
const MM_SPENTE := "res://assets/enigma_acquari/lampadine_spente.res"
const GIALLO := "res://assets/enigma_acquari/metallo_giallo.tres"
const TIRANTI := "res://assets/materials/sala/metallo_verniciato.tres"

var acqua_vasca: Node3D
var _anello: TorusMesh
var _mat_anello: StandardMaterial3D
var _galleggianti: Array[Node3D] = []
## Le luci che sfarfallano: [luce, energia, mesh emissive, materiale acceso, materiale spento, attesa].
var _guaste: Array = []
var _t := 0.0


func _ready() -> void:
	if leggi_ambiente and OS.has_environment("MENU_SFONDO"):
		var s := OS.get_environment("MENU_SFONDO").to_upper()
		cupola = s.contains("A")
		acqua = s.contains("B")
		sala = s.contains("C")
	if cupola or acqua or sala:
		_parete()
	if cupola:
		_cupola()
	if acqua:
		_acqua()
	if sala:
		_sala()


func _process(delta: float) -> void:
	_t += delta
	for i in _galleggianti.size():
		var g := _galleggianti[i]
		g.position.y = LIVELLO - 0.02 + sin(_t * 1.1 + i * 2.3) * 0.015
		g.rotation.z = sin(_t * 0.8 + i) * 0.06
	for gu in _guaste:
		gu[5] -= delta
		if gu[5] > 0.0:
			continue
		var accesa: bool = randf() < 0.7
		gu[5] = randf_range(0.04, 0.18) if randf() < 0.75 else randf_range(0.8, 2.6)
		if gu[0]:
			(gu[0] as Light3D).light_energy = gu[1] if accesa else gu[1] * 0.05
		for m in gu[2]:
			(m as GeometryInstance3D).material_override = gu[3] if accesa else gu[4]


# --- la parete di fondo (serve a tutti gli strati: ci sono appesi insegna, neon, ghirlande, portone) ----

func _parete() -> void:
	var radice := Node3D.new()
	radice.name = "Parete"
	add_child(radice)
	# il muro della sala (le texture di sala_architettura), più scuro: è lontano e non deve rubare la scena
	var mat := ORMMaterial3D.new()
	mat.albedo_texture = load(MURO_COL)
	mat.albedo_color = Color(0.3, 0.3, 0.32)
	mat.normal_enabled = true
	mat.normal_texture = load(MURO_NRM)
	mat.orm_texture = load(MURO_ORM)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.25
	var spessore := 0.4
	if cupola:
		# con la cupola il muro gira tutto intorno sotto il suo anello (come il tamburo nella sala): il cielo
		# si vede solo dal vetro
		var lati := 32
		var largo := 2.0 * R_CUPOLA * tan(PI / lati) + 0.05
		for k in lati:
			var a := TAU * k / lati
			var mi := _scatola(radice, Vector3(-largo * 0.5, 0.0, -spessore * 0.5), Vector3(largo * 0.5, BASE_CUPOLA, spessore * 0.5), mat)
			var c := CENTRO_CUPOLA + Vector3(cos(a), 0.0, sin(a)) * (R_CUPOLA + spessore * 0.5)
			mi.transform = Transform3D(Basis.looking_at(CENTRO_CUPOLA - Vector3(c.x, 0.0, c.z), Vector3.UP), c + Vector3.UP * BASE_CUPOLA * 0.5)
		return
	# senza la cupola la parete di fondo sale nel buio, oltre l'inquadratura
	var alto := 30.0
	var x0 := X_PARETE.x
	var x1 := X_PARETE.y
	var p0 := PORTONE_X - PORTONE_LARGO * 0.5 - 0.35
	var p1 := PORTONE_X + PORTONE_LARGO * 0.5 + 0.35
	var h_porta := 5.9
	# a pezzi attorno al vano del portone (dentro il vano è buio: la porta è aperta sulla torre)
	for r in [[x0, p0, 0.0, alto], [p1, x1, 0.0, alto], [p0, p1, h_porta, alto]]:
		_scatola(radice, Vector3(r[0], r[2], Z_PARETE - spessore), Vector3(r[1], r[3], Z_PARETE), mat)
	# lo sguincio del vano e il fondo nero
	var buio := StandardMaterial3D.new()
	buio.albedo_color = Color(0.01, 0.01, 0.012)
	_scatola(radice, Vector3(p0, 0.0, Z_PARETE - 3.0), Vector3(p1, h_porta, Z_PARETE - 2.9), buio)


## Dove si appende qualcosa al muro di fondo, all'ascissa [param x] e all'altezza [param y]: sulla parete
## dritta o, con la cupola, sul tamburo. La base guarda nella sala (+Z verso la sala, come le insegne).
func sul_muro(x: float, y: float) -> Transform3D:
	if cupola:
		var dz := sqrt(maxf(R_CUPOLA * R_CUPOLA - x * x, 0.0))
		var p := Vector3(x, y, CENTRO_CUPOLA.z - dz)
		var verso := Vector3(CENTRO_CUPOLA.x - p.x, 0.0, CENTRO_CUPOLA.z - p.z).normalized()
		return Transform3D(Basis.looking_at(-verso, Vector3.UP), p)
	return Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), Vector3(x, y, Z_PARETE))


func _scatola(radice: Node3D, lo: Vector3, hi: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = hi - lo
	mi.mesh = b
	mi.material_override = mat
	radice.add_child(mi)
	mi.position = (lo + hi) * 0.5
	return mi


func _cilindro(radice: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	radice.add_child(mi)
	mi.position = (a + b) * 0.5
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return mi


# --- A: la cupola nella tempesta --------------------------------------------------------------------

func _cupola() -> void:
	var radice := Node3D.new()
	radice.name = "Cupola"
	add_child(radice)
	# la cupola della sala (raggio 13, centro in z -5, base a 12,5) sopra la statua, sul tamburo di muro
	var glb: Node3D = (load(CUPOLA_GLB) as PackedScene).instantiate()
	radice.add_child(glb)
	glb.position = Vector3(0.0, BASE_CUPOLA - 12.5, 0.0)
	var vetro: ShaderMaterial = (load(VETRO_CUPOLA) as ShaderMaterial).duplicate()
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if String(m.name).contains("vetro"):
			for i in m.mesh.get_surface_count():
				m.set_surface_override_material(i, vetro)
	# il cielo della tempesta, dietro il vetro
	var cielo := ShaderMaterial.new()
	cielo.shader = load(CIELO)
	var env := _ambiente()
	if env:
		var sky := Sky.new()
		sky.sky_material = cielo
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	if tempesta:
		tempesta.cielo = cielo
		tempesta.materiali.append(vetro)
	# la sagoma della torre degli scivoli oltre il vetro, nera: si vede solo contro il cielo del lampo
	var torre: Node3D = (load(TORRE_GLB) as PackedScene).instantiate()
	var nero := StandardMaterial3D.new()
	nero.albedo_color = Color(0.0, 0.0, 0.0)
	nero.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi in torre.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var nome := String(m.name)
		if nome.begins_with("acqua"):
			m.visible = false
		m.material_override = nero
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (le mesh "-col" sono figlie dei loro corpi: si spengono le collisioni, non si tolgono)
	for n in torre.find_children("*", "CollisionObject3D", true, false):
		(n as CollisionObject3D).collision_layer = 0
		(n as CollisionObject3D).collision_mask = 0
	radice.add_child(torre)
	# (nel GLB la torre sta fra x 20 e 40, z -26 e -4, con la cima a 14)
	torre.position = Vector3(-2.0, 13.0, -16.0)


func _ambiente() -> Environment:
	var we := get_parent().find_child("WorldEnvironment", false, false) as WorldEnvironment if get_parent() else null
	return we.environment if we else get_viewport().world_3d.environment if get_viewport() and get_viewport().world_3d else null


# --- B: l'acqua ai suoi piedi -------------------------------------------------------------------------

func _acqua() -> void:
	var radice := Node3D.new()
	radice.name = "Acqua"
	add_child(radice)
	# la vasca allagata, da parete a parete: acqua nera, ferma e lucidissima (water_murky, come la pozza in
	# fondo alla piscina), che prende i riflessi dello spazio schermo di lei, delle luci rosse e della sala
	var piano := MeshInstance3D.new()
	piano.name = "Specchio"
	var pm := PlaneMesh.new()
	pm.size = Vector2(X_PARETE.y - X_PARETE.x, 26.0)
	piano.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load(ACQUA_SHADER)
	mat.set_shader_parameter(&"shallow_color", Color(0.035, 0.045, 0.055))
	mat.set_shader_parameter(&"deep_color", Color(0.004, 0.006, 0.009))
	mat.set_shader_parameter(&"wave_strength", 0.035)
	mat.set_shader_parameter(&"wave_scale", 0.9)
	piano.material_override = mat
	piano.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	radice.add_child(piano)
	piano.position = Vector3((X_PARETE.x + X_PARETE.y) * 0.5, LIVELLO, Z_PARETE + 13.0)
	pm.size.y = 2.0 * 13.0 + 6.0
	acqua_vasca = piano
	# le gocce che cadono dall'alto (dalla cupola o dal buio) e fanno i cerchi
	for p in [Vector3(1.6, 0, -2.4), Vector3(-1.9, 0, 1.4), Vector3(3.4, 0, 1.2), Vector3(0.6, 0, 3.6), Vector3(5.0, 0, -4.0),
			Vector3(-0.8, 0, -3.0), Vector3(2.2, 0, 4.4)]:
		var g := Gocce.new()
		g.altezza = 7.0
		g.intervallo_min = 0.7
		g.intervallo_max = 2.4
		radice.add_child(g)
		g.position = Vector3(p.x, LIVELLO + 7.0, p.z)
		g.goccia_caduta.connect(func(pos: Vector3): _cerchio(radice, Vector3(pos.x, LIVELLO + 0.004, pos.z)))
	# la paperella e il pallone che galleggiano
	for d in [[PAPERELLA, Vector3(2.3, 0, 2.6), 0.9, 40.0], [PALLONE, Vector3(4.6, 0, 0.6), 1.0, 0.0]]:
		var o: Node3D = (load(d[0]) as PackedScene).instantiate()
		radice.add_child(o)
		o.position = Vector3((d[1] as Vector3).x, LIVELLO, (d[1] as Vector3).z)
		o.scale = Vector3.ONE * float(d[2])
		o.rotation.y = deg_to_rad(float(d[3]))
		_galleggianti.append(o)
	# in fondo, sulla parete, l'insegna di Jilly Jubilee con le sue due lampade, guasta
	var ins: Node3D = (load(INSEGNA) as PackedScene).instantiate()
	radice.add_child(ins)
	ins.global_transform = sul_muro(10.0 if cupola else 13.2, 3.4)
	var lampadine: Array = ins.find_children("*lampadina*", "MeshInstance3D", true, false)
	var spenta := StandardMaterial3D.new()
	spenta.albedo_color = Color(0.3, 0.26, 0.2)
	spenta.roughness = 0.3
	var accesa := StandardMaterial3D.new()
	accesa.albedo_color = Color(1.0, 0.7, 0.4)
	accesa.emission_enabled = true
	accesa.emission = Color(1.0, 0.7, 0.4)
	accesa.emission_energy_multiplier = 6.0
	for e in ins.find_children("luce_*", "Node3D", true, false):
		var l := SpotLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.42)
		l.light_energy = 2.2
		l.spot_range = 2.4
		l.spot_angle = 40.0
		l.spot_attenuation = 1.2
		l.light_volumetric_fog_energy = 0.6
		(e as Node3D).add_child(l)
		var loc := ins.to_local((e as Node3D).global_position)
		l.look_at(ins.to_global(Vector3(loc.x * 0.4, -0.05, 0.15)), ins.global_basis.y)
		var mie: Array = lampadine.filter(func(m): return String(m.name).contains("_sx") == String(e.name).contains("_sx"))
		_guaste.append([l, l.light_energy, mie, accesa, spenta, randf_range(0.2, 1.0)])


## Il cerchio di una goccia sull'acqua: un anello sottile che si allarga e svanisce in un secondo.
func _cerchio(radice: Node3D, p: Vector3) -> void:
	if _anello == null:
		_anello = TorusMesh.new()
		_anello.inner_radius = 0.96
		_anello.outer_radius = 1.0
		_anello.rings = 32
		_anello.ring_segments = 3
		_mat_anello = StandardMaterial3D.new()
		_mat_anello.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_anello.albedo_color = Color(0.75, 0.82, 0.9, 0.5)
		_mat_anello.roughness = 0.05
		_mat_anello.metallic_specular = 1.0
	for k in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = _anello
		var m := _mat_anello.duplicate() as StandardMaterial3D
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		radice.add_child(mi)
		mi.position = p
		mi.scale = Vector3(0.02, 0.15, 0.02)
		var tw := mi.create_tween().set_parallel()
		var r := 0.35 if k == 0 else 0.22
		tw.tween_property(mi, "scale", Vector3(r, 0.15, r), 1.1 + k * 0.2).set_delay(k * 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "albedo_color:a", 0.0, 1.1 + k * 0.2).set_delay(k * 0.18)
		tw.chain().tween_callback(mi.queue_free)


# --- C: la sala del parco -----------------------------------------------------------------------------

func _sala() -> void:
	var radice := Node3D.new()
	radice.name = "Sala"
	add_child(radice)
	_cornice_portone(radice)
	# le ghirlande di lampadine lungo la parete, da gancio a gancio, mezze spente
	# (da dietro la statua verso destra: la parte sinistra, dove ci sono il logo e il menu, resta scura)
	var ganci := [Vector3(0.5, 7.6, Z_PARETE), Vector3(5.0, 7.6, Z_PARETE),
			Vector3(9.5, 7.6, Z_PARETE), Vector3(14.0, 7.6, Z_PARETE), Vector3(18.5, 7.6, Z_PARETE)]
	_ghirlanda(radice, ganci, 0.9, [2, 3, 7, 11, 12, 13, 19, 24, 25, 31, 36, 37], [5, 16, 28])
	var bassi := [Vector3(10.6, 5.2, Z_PARETE), Vector3(14.0, 5.2, Z_PARETE), Vector3(17.4, 5.2, Z_PARETE)]
	_ghirlanda(radice, bassi, 0.55, [1, 4, 5, 9, 14], [7])
	# i manifesti di Jilly con il neon sopra (uno guasto)
	for d in [[Vector3(15.6, 2.6, Z_PARETE), Neon.Modalita.SFARFALLA], [Vector3(20.6, 2.6, Z_PARETE), Neon.Modalita.GUASTO]]:
		var man: Node3D = (load(MANIFESTO) as PackedScene).instantiate()
		radice.add_child(man)
		man.global_transform = sul_muro((d[0] as Vector3).x, (d[0] as Vector3).y)
		var ne := Neon.new()
		ne.modalita = d[1]
		ne.colore = Color(1.0, 0.45, 0.75)
		ne.lunghezza = 1.6
		ne.energia_luce = 3.0
		ne.portata = 6.0
		radice.add_child(ne)
		# la plafoniera è appoggiata al muro (profonda 16 cm), sopra il manifesto
		var t := sul_muro((d[0] as Vector3).x, (d[0] as Vector3).y + 1.55)
		ne.global_transform = Transform3D(t.basis, t.origin + t.basis.z * 0.08)


## La cornice di lampadine del portone della torre (la stessa della sala: guide gialle a terra, staffe al
## muro, portalampade e lampadine), girata dalla parete est della sala alla parete di fondo.
func _cornice_portone(radice: Node3D) -> void:
	var c := Node3D.new()
	c.name = "CornicePortone"
	radice.add_child(c)
	# nella sala la parete è in x 20,2 e il centro del portone in z -15; qui la parete guarda +z
	var giro := Basis(Vector3.UP, PI * 0.5)
	c.transform = Transform3D(giro, Vector3(PORTONE_X, 0, Z_PARETE) - giro * Vector3(20.2, 0, -15.0))
	var giallo: Material = load(GIALLO)
	var tiranti: Material = load(TIRANTI)
	for z in [-18.45, -11.55]:
		_scatola(c, Vector3(19.62, 0.0, z - 0.045), Vector3(19.67, 5.56, z + 0.045), giallo)
	_scatola(c, Vector3(19.62, 5.455, -18.5), Vector3(19.67, 5.545, -11.5), giallo)
	for z in [-18.2, -16.3, -13.7, -11.8]:
		_scatola(c, Vector3(19.665, 5.475, z - 0.025), Vector3(20.2, 5.525, z + 0.025), tiranti)
	for d in [[MM_PORTALAMPADE, false], [MM_SPENTE, false], [MM_ACCESE, true]]:
		var mm := MultiMeshInstance3D.new()
		mm.multimesh = load(d[0])
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.add_child(mm)
	for p in [Vector3(19.095, 3.0, -18.45), Vector3(19.095, 3.0, -11.55), Vector3(19.095, 5.3, -15.0)]:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.75, 0.45)
		o.light_energy = 2.2
		o.light_volumetric_fog_energy = 1.0
		o.omni_range = 7.0
		o.omni_attenuation = 1.2
		c.add_child(o)
		o.position = p


## Una ghirlanda di lampadine fra i [param ganci] sulla parete (filo nero, lampadine pastello, una luce
## vera ogni tre accese), come quella dell'area bimbi della sala (LookSala).
func _ghirlanda(radice: Node3D, ganci: Array, cala: float, rotte: Array, sfarfallano: Array) -> void:
	var colori := [Color(1.0, 0.25, 0.3), Color(1.0, 0.8, 0.2), Color(0.25, 0.6, 1.0),
			Color(0.35, 1.0, 0.45), Color(1.0, 0.45, 0.85), Color(1.0, 0.55, 0.15)]
	var filo := StandardMaterial3D.new()
	filo.albedo_color = Color(0.03, 0.03, 0.03)
	var spento := StandardMaterial3D.new()
	spento.albedo_color = Color(0.25, 0.25, 0.25)
	spento.roughness = 0.2
	var sfera := SphereMesh.new()
	sfera.radius = 0.045
	sfera.height = 0.11
	sfera.radial_segments = 12
	sfera.rings = 6
	var materiali := {}
	var n := 0
	# il filo corre 6 cm davanti alla parete (i ganci sono piastrine sul muro)
	var avanti := Vector3(0, 0, 0.06)
	for g in ganci:
		var gancio := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.06, 0.06, 0.06)
		gancio.mesh = b
		gancio.material_override = filo
		radice.add_child(gancio)
		gancio.position = (g as Vector3) + Vector3(0, 0, 0.03)
	for k in ganci.size() - 1:
		var a: Vector3 = ganci[k] + avanti
		var bb: Vector3 = ganci[k + 1] + avanti
		var passi := maxi(int(a.distance_to(bb) / 0.42), 2)
		var prec := a
		for i in passi + 1:
			var t := float(i) / passi
			var p := a.lerp(bb, t) - Vector3.UP * cala * 4.0 * t * (1.0 - t)
			if i > 0:
				_cilindro(radice, prec, p, 0.006, filo).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			prec = p
			if i == 0 and k > 0:
				continue
			var colore: Color = colori[n % colori.size()]
			var rotta: bool = n in rotte
			var lamp := MeshInstance3D.new()
			lamp.mesh = sfera
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var m: StandardMaterial3D = materiali.get(colore)
			if m == null:
				m = StandardMaterial3D.new()
				m.albedo_color = colore
				m.emission_enabled = true
				m.emission = colore
				m.emission_energy_multiplier = 4.0
				materiali[colore] = m
			lamp.material_override = spento if rotta else m
			radice.add_child(lamp)
			lamp.position = p + Vector3.DOWN * 0.06
			if not rotta and n % 3 == 1:
				var o := OmniLight3D.new()
				o.light_color = colore
				o.light_energy = 1.1
				o.omni_range = 3.2
				o.omni_attenuation = 1.4
				o.light_volumetric_fog_energy = 1.2
				radice.add_child(o)
				o.position = p + Vector3(0, -0.15, 0.1)
				if n in sfarfallano:
					_guaste.append([o, o.light_energy, [lamp], m, spento, randf_range(0.2, 2.0)])
			n += 1
