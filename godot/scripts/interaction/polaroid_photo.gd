@tool
class_name PolaroidPhoto
extends Collectible
## Una delle Polaroid del capitolo 1 (le 10 della scaletta, P11 la pecora che brilla dell'infermeria, P12-P16 le
## nuove della proposta del 25 ottobre notte, docs/proposte/polaroid_nuove/): il modello 3D con la sua foto. Raccolta,
## si guarda da vicino (PhotoViewer) e va nella collezione. Con [member snap_to_surface] all'avvio si appoggia sulla
## superficie sotto di sé; quelle messe da codice con [method metti] le appoggia Posa.

const TEX_DIR := "res://assets/models/polaroid/texture/"
const VIEWER := preload("res://scripts/ui/photo_viewer.gd")
const SCENA := "res://scenes/props/polaroid.tscn"
## I punti dell'impronta della foto (8,8 x 10,7 cm) per Posa.appoggia_su_impronta, negli strumenti e nei test (a gioco
## avviato, con le stanze che si costruiscono a pezzi, i raggi sotto tutta la foto fanno fotogrammi lunghi): il centro,
## gli angoli e i lati.
const IMPRONTA: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0.04, 0, 0.05), Vector3(-0.04, 0, 0.05), Vector3(0.04, 0, -0.05),
	Vector3(-0.04, 0, -0.05), Vector3(0.04, 0, 0), Vector3(-0.04, 0, 0), Vector3(0, 0, 0.05), Vector3(0, 0, -0.05)]

## Le 16 Polaroid del capitolo 1, in ordine (la foto n è NOMI_RACCOLTA[n - 1]): il nome di ognuna nella collezione "polaroid" del
## salvataggio. Sono quelli di sempre (p01-p09 e p12-p16 dati apposta, la 10 e la pecora col nome del nodo): l'album e il
## contatore li leggono, il salvataggio resta com'era.
const NOMI_RACCOLTA: Array[StringName] = [&"p01", &"p02", &"p03", &"p04", &"p05", &"p06", &"p07", &"p08", &"p09", &"Polaroid10",
	&"PolaroidPecora", &"p12", &"p13", &"p14", &"p15", &"p16"]

## Numero della foto (1-10, 11 la pecora che brilla dell'infermeria, 12-16 le nuove): texture Pxx.jpg.
@export_range(1, 16) var photo := 1:
	set(value):
		photo = value
		_apply()
@export var snap_to_surface := true

static var _materials := {}


func _init() -> void:
	super()
	display_name = "Polaroid"


func _ready() -> void:
	_apply()
	if Engine.is_editor_hint():
		return
	super()
	if snap_to_surface:
		_snap.call_deferred()
	elif not _da_appoggiare:
		# messa ferma (nella scena, o da codice al posto giusto): solo il fondo a filo, quando la sua zona c'è
		_adagia_dopo.call_deferred()


## Vero per quelle messe da [method metti] che Posa appoggia ([method _appoggia] le adagia alla fine).
var _da_appoggiare := false


## Il fondo a filo per una foto messa ferma: dopo che la sua zona è costruita (anche nascosta: le sue mesh si guardano lo
## stesso), qualche fotogramma di fisica dopo (lo sportello della P02 la mette lui) e una foto per fotogramma.
func _adagia_dopo() -> void:
	var radice := await _aspetta_zona()
	if not is_inside_tree():
		return
	if not await _aspetta(4, true) or not await _aspetta(photo):
		return
	adagia(radice)


## Aspetta [param quanti] fotogrammi (di fisica con [param fisica]); falso se intanto la foto è uscita dalla scena (la
## sua zona tolta a metà della preparazione).
func _aspetta(quanti: int, fisica := false) -> bool:
	for i in quanti:
		if not is_inside_tree():
			return false
		if fisica:
			await get_tree().physics_frame
		else:
			await get_tree().process_frame
	return is_inside_tree()


## Aspetta che le zone che la contengono siano costruite; torna la più vicina (null se nessuna).
func _aspetta_zona() -> Node:
	var radice: Node = null
	var n := get_parent()
	while n and is_inside_tree():
		if &"costruita" in n:
			while not bool(n.get(&"costruita")) and is_inside_tree():
				await get_tree().process_frame
			if radice == null:
				radice = n
		n = n.get_parent()
	return radice


## Una Polaroid messa da codice sotto [param padre]: [param pos] (locale, appena sopra il sostegno) e girata di
## [param gradi]. Due fotogrammi di fisica dopo, Posa (lo strumento comune) la appoggia sulla superficie che si vede
## sotto, 4 mm sopra come lo snap di sempre. Con [param posata] [param pos] è già il posto giusto, calcolato una volta
## sola con uno strumento (la P12 sul grigliato della torre, tests/posa_polaroid12.gd): niente raggi a gioco avviato.
## L'id nella collezione è "pNN".
static func metti(padre: Node3D, foto: int, pos: Vector3, gradi: float, posata := false) -> PolaroidPhoto:
	var p := (load(SCENA) as PackedScene).instantiate() as PolaroidPhoto
	p.name = "Polaroid%02d" % foto
	p.photo = foto
	p.entry_id = StringName("p%02d" % foto)
	p.snap_to_surface = false
	p._da_appoggiare = not posata
	p.position = pos
	p.rotation_degrees.y = gradi
	padre.add_child(p)
	if not posata:
		p._appoggia.call_deferred()
	return p


func _appoggia() -> void:
	# (nelle stanze costruite a pezzi mentre si gioca, come il fiume, il pavimento può arrivare dopo: si aspetta la fine)
	var radice := await _aspetta_zona()
	if not await _aspetta(2, true):
		return
	# (il fiume caricato a gioco avviato entra nella scena prima del suo pavimento: si riprova finché c'è, al massimo
	# 20 secondi, poi Posa dice che non c'è niente sotto. I 20 secondi contano solo con la stanza accesa: costruita
	# nascosta e ferma, come il fiume, i suoi corpi sono fuori dalla fisica e le sue mesh nascoste, quindi si aspetta
	# senza limite che AccensioneAPezzi la riaccenda; prima, ferma più di 20 s, la foto non trovava niente sotto)
	var i := 0
	while i < 120:
		if not is_inside_tree():
			return
		if not can_process():
			await get_tree().create_timer(0.17, false, true).timeout
			continue
		i += 1
		var da := global_position + Vector3.UP * 0.05
		var q := PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * Posa.PORTATA, Posa.STRATI)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			break
		await get_tree().create_timer(0.17, false, true).timeout
	if is_inside_tree() and Posa.appoggia_a_terra(self, 0.004):
		if await _aspetta(photo):
			adagia(radice)


## Il fondo della foto a [constant AGIO] dalla superficie sotto, nel punto più vicino, e nessun punto dentro. Prima
## l'origine stava 4 mm sopra il pavimento, e il fondo della foto (quasi piatta, da 0,1 a 0,8 mm sotto l'origine)
## restava 3,2-3,9 mm sollevato: di lato, radente, si vedeva uno spicchio scuro sotto il bordo (collaudo di grafica del
## 9 novembre, docs/collaudo/polaroid_fiume). In ognuno dei punti di [constant SOTTO] il fondo vero della foto (dalla sua
## mesh) e la superficie che si vede sotto (Posa, raggio dall'alto in basso): la foto sale o scende di quanto serve
## perché il più vicino sia ad AGIO. Su un fondo curvo (la conca dello scarico) tocca coi bordi e resta staccata in mezzo.
## [param radice]: la zona in cui sta, se si costruisce nascosta (le sue mesh si guardano lo stesso: Posa.mesh_vicine).
## Se la superficie sotto è un piano un po' inclinato rispetto alla foto (il fondo della piscina, collaudo di grafica: la
## P05 e la P08 toccavano da un lato e restavano a 6-10 mm dall'altro), la foto prima si gira come lui; su stecche,
## grigliati e feritoie (non un piano) resta com'è e tocca coi punti più alti.
func adagia(radice: Node = null) -> void:
	if not is_inside_tree():
		return
	var mesh := find_children("*", "MeshInstance3D", true, false)
	if mesh.is_empty():
		return
	var zona := AABB(global_position, Vector3.ZERO).grow(0.08)
	zona = zona.expand(global_position - global_basis.y.normalized() * 0.35)
	var vicine := Posa.mesh_vicine(self, zona, radice)
	var misure := _distanze(mesh, vicine)
	if misure.size() >= 6:
		var n_l = _piano(misure)
		if n_l != null:
			var su := global_basis.y.normalized()
			var n_w := (global_basis * (n_l as Vector3)).normalized()
			global_basis = Basis(Quaternion(su, n_w)) * global_basis
			misure = _distanze(mesh, vicine)
	var minimo := INF
	for m in misure:
		minimo = minf(minimo, float(m[2]))
	if minimo < INF and absf(minimo - AGIO) < 0.05:
		global_position += global_basis.y.normalized() * (AGIO - minimo)


## [x, z, distanza, altezza della superficie sopra l'origine della foto] in ogni punto di [constant SOTTO]: dal fondo vero della foto alla superficie sotto, lungo il -y della
## foto (giù per quelle appoggiate, il muro per quelle appese).
func _distanze(mesh: Array, vicine: Array) -> Array:
	var out: Array = []
	var su := global_basis.y.normalized()
	for pl: Vector3 in SOTTO:
		var fondo = _fondo_in(pl, mesh)
		if fondo == null:
			continue
		var w: Vector3 = fondo
		var h := Posa._raggio(self, w + su * 0.03, w - su * 0.3, [], vicine)
		if not h.is_empty():
			out.append([pl.x, pl.z, (w - (h.position as Vector3)).dot(su), ((h.position as Vector3) - global_position).dot(su)])
	return out


## La normale (in coordinate della foto) del piano della superficie sotto, se le altezze della superficie in [param misure]
## stanno su un piano (scarto al più 2 mm) inclinato di più di mezzo grado e meno di 25 gradi rispetto alla foto; se no
## null. (Dalla superficie sola: con le distanze contava anche la curva del fondo della foto, e sui pavimenti piani la
## girava di un grado.)
static func _piano(misure: Array) -> Variant:
	# minimi quadrati di d = a x + b z + c, con d = -altezza della superficie
	var sxx := 0.0
	var szz := 0.0
	var sxz := 0.0
	var sx := 0.0
	var sz := 0.0
	var sd := 0.0
	var sxd := 0.0
	var szd := 0.0
	var n := float(misure.size())
	for m in misure:
		var x: float = m[0]
		var z: float = m[1]
		var d: float = -float(m[3])
		sxx += x * x
		szz += z * z
		sxz += x * z
		sx += x
		sz += z
		sd += d
		sxd += x * d
		szd += z * d
	var mat := Basis(Vector3(sxx, sxz, sx), Vector3(sxz, szz, sz), Vector3(sx, sz, n))
	if absf(mat.determinant()) < 1e-12:
		return null
	var abc := mat.inverse() * Vector3(sxd, szd, sd)
	var scarto := 0.0
	for m in misure:
		scarto = maxf(scarto, absf(-float(m[3]) - (abc.x * float(m[0]) + abc.y * float(m[1]) + abc.z)))
	# (la superficie, rispetto al fondo della foto, sta a -d: il piano y = -a x - b z, normale (a, 1, b))
	var normale := Vector3(abc.x, 1.0, abc.y).normalized()
	var angolo := rad_to_deg(normale.angle_to(Vector3.UP))
	if scarto > 0.002 or angolo < 0.5 or angolo > 25.0:
		return null
	return normale


## Quanto resta fra il fondo della foto e la superficie sotto, nel punto più vicino (m).
const AGIO := 0.0002
## I punti sotto la foto (8,8 x 10,7 cm) dove si guarda il fondo: una griglia di 5 x 5, dagli angoli appena dentro il
## bordo al centro.
static var SOTTO: Array[Vector3] = _griglia()


static func _griglia() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in 5:
		for j in 5:
			out.append(Vector3(-0.042 + 0.021 * i, 0.0, -0.051 + 0.0255 * j))
	return out


## Il punto del fondo della foto sotto [param pl] (in coordinate della foto, y ignorata), in coordinate del mondo: la
## faccia più bassa della sua mesh lungo la verticale della foto. null se lì la mesh non c'è.
func _fondo_in(pl: Vector3, mesh: Array) -> Variant:
	var meglio: Variant = null
	for n in mesh:
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var tm := Posa._triangoli_di(mi.mesh)
		if tm == null:
			continue
		var inv := mi.global_transform.affine_inverse()
		var da := inv * (global_transform * Vector3(pl.x, -0.02, pl.z))
		var a := inv * (global_transform * Vector3(pl.x, 0.02, pl.z))
		# (intersect_ray: con intersect_segment, su questi 4 cm, la mesh della foto non dava niente)
		var r := tm.intersect_ray(da, (a - da).normalized())
		if r.is_empty() or (r.position as Vector3).distance_to(da) > da.distance_to(a):
			continue
		var w: Vector3 = mi.global_transform * (r.position as Vector3)
		if meglio == null or w.y < (meglio as Vector3).y:
			meglio = w
	return meglio


func get_texture() -> Texture2D:
	return texture_di(photo)


## La foto [param n] (1-16).
static func texture_di(n: int) -> Texture2D:
	return load(TEX_DIR + "P%02d.jpg" % n) as Texture2D


## Vero se la foto [param n] (1-16) è già stata raccolta.
static func trovata(n: int) -> bool:
	return n >= 1 and n <= NOMI_RACCOLTA.size() and GameState.has_collectible(&"polaroid", NOMI_RACCOLTA[n - 1])


## Quante delle 16 sono state raccolte.
static func quante_trovate() -> int:
	var k := 0
	for n in range(1, NOMI_RACCOLTA.size() + 1):
		if trovata(n):
			k += 1
	return k


func _apply() -> void:
	if not is_inside_tree():
		return
	var meshes := find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var mesh_inst := meshes[0] as MeshInstance3D
	if mesh_inst.mesh == null:
		return
	mesh_inst.set_surface_override_material(0, _front_material(photo))
	if mesh_inst.mesh.get_surface_count() > 1:
		mesh_inst.set_surface_override_material(1, _back_material())


static func _front_material(i: int) -> StandardMaterial3D:
	var key := "P%02d" % i
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX_DIR + key + ".jpg")
	m.roughness_texture = load(TEX_DIR + key + "_rugosita.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.normal_enabled = true
	m.normal_texture = load(TEX_DIR + "normale.png")
	m.normal_scale = 0.6
	# Un filo di luce propria, così si nota anche nel buio (senza sembrare una lampada).
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.06
	_materials[key] = m
	return m


static func _back_material() -> StandardMaterial3D:
	if _materials.has("retro"):
		return _materials["retro"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX_DIR + "retro.jpg")
	m.roughness_texture = load(TEX_DIR + "retro_rugosita.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	_materials["retro"] = m
	return m


func _snap() -> void:
	if not await _aspetta(2, true):
		return
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -4.0, 0), Layers.WORLD | Layers.PROPS)
	# (senza passare dalle crepe fra due triangoli, dove un raggio solo trova il pavimento sotto: RaggioSicuro)
	var hit := RaggioSicuro.interseca(space, q)
	if hit.is_empty():
		push_warning("Polaroid %d: niente sotto su cui appoggiarsi (%s)" % [photo, global_position])
		return
	# Su una superficie in pendenza (il fondo della piscina) si inclina con lei, se no un angolo affonda.
	var n: Vector3 = hit.normal
	if n.dot(Vector3.UP) > cos(deg_to_rad(25.0)):
		global_basis = Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, global_rotation.y)
	else:
		n = Vector3.UP
	global_position = hit.position + n * 0.004
	# Poi il fondo vero a filo della superficie, guardando sotto tutta la foto: su un fondo curvo (la conca dello scarico,
	# Polaroid05, controllo di posizionamento del 22 ottobre) la pendenza del centro non basta e tocca coi bordi. Prima si
	# guardavano 4 punti a 7 cm dal centro, fuori dalla foto, e la P05 e la P08 restavano a 7-8 mm. (Una foto per
	# fotogramma: Posa.mesh_vicine guarda tutto l'albero, qualche ms.)
	if await _aspetta(photo):
		adagia()


func _on_interact(by: Node) -> void:
	var viewer: CanvasLayer = VIEWER.new()
	viewer.set(&"texture", get_texture())
	get_tree().root.add_child(viewer)
	super(by)
