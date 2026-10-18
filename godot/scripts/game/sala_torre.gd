class_name SalaTorre
extends Node3D
## La sala della torre (dopo la tappa 8, scelta dell'utente del 18 ottobre: la versione A, "la struttura
## mastodontica"): quattro torri di traliccio e decine di scivoli colorati, che non si scalano ma si
## SCENDONO, dal portone (in cima, alla quota della sala grande) fino alla vasca del fondo, 20 m più giù.
##
## La geometria viene da tools/blender/torre_proposte.py A --gioco (assets/ambiente/torre/):
## - torre_struttura.glb, torre_scivoli.glb, torre_prop.glb: i nomi con "-col" hanno la collisione fatta
##   dall'importatore (trimesh), i prop una scatola convessa;
## - torre_gioco.json: checkpoint, tratti e salti della discesa, Polaroid, balconata, pozzo, vasca del fondo;
## - torre_luci.json: lampeggianti rossi, lampade da lavoro, fari sui tralicci, gocce.
## Le coordinate dei JSON sono di Blender: (x, y, z) diventa (x, z, -y).
##
## La discesa è fatta dei canali "discesa_<tratto>_<pezzo>": i loro corpi statici sono nel gruppo
## "scivolo" (accordo con grafica: chi ci sta sopra scivola seguendo la pendenza, il salto a fine pezzo
## viene dalla velocità, il getto verso il basso in aria dà la spinta). Qui ci sono:
## - un checkpoint su ogni pedana d'arrivo (e all'ingresso);
## - la caduta: se il giocatore finisce 3 m sotto la pedana del prossimo checkpoint, o sul fondo fuori
##   dalla vasca, muore e riparte dall'ultimo checkpoint;
## - la Polaroid 10 sul lettino della pedana NO a -12;
## - la balconata dei bambini: al primo salto, un lampo e per un attimo si vede la fila di bambini;
## - la luce di lei che sale dal pozzo, più forte man mano che scendi;
## - la vasca del fondo: entrandoci la discesa è finita ([signal discesa_finita]).

signal discesa_finita

const DIR := "res://assets/ambiente/torre/"
const ROSSO := Color(1.0, 0.035, 0.02)
const CALDO := Color(1.0, 0.66, 0.36)
const ROSA := Color(1.0, 0.32, 0.62)
const BAMBINI := ["res://scenes/creature/bambino_cubo.tscn", "res://scenes/creature/bambino_agnello.tscn"]

## Ordine del primo checkpoint della torre (dopo quelli della sala grande e del ritorno).
@export var ordine_base := 20
## Metri sotto la pedana del prossimo checkpoint oltre i quali si è caduti.
@export var margine_caduta := 3.0
## Secondi fermi su qualcosa nel vuoto (lontano dalle pedane) dopo i quali si è caduti.
@export var tempo_bloccato := 1.5
## Luce di lei: energia in cima e in fondo alla discesa.
@export var lei_in_cima := 1.5
@export var lei_in_fondo := 14.0
## Le luci accese (per i test e le macchine lente si possono spegnere).
@export var crea_luci := true
## Guida agli imbocchi: nei primi metri di ogni tratto, finché si va piano, la velocità si allinea al canale
## e riporta verso il centro (si entra anche arrivando spostati o storti).
@export var guida_metri := 1.2
@export var guida_forza := 7.0
@export var guida_fino_a := 4.0      ## m/s: più veloce di così la guida non serve più

var dati := {}
var checkpoint: Array[Checkpoint] = []
var _quote_cp: Array[float] = []          ## quota (y di Godot) di ogni checkpoint
var _lei: Array[Light3D] = []
var _lampo_fatto := false
var _bambini: Array[Node3D] = []
var _finita := false
var _fermo := 0.0
var _imbocchi: Array[PackedVector3Array] = []   ## i primi metri della linea di fondo di ogni tratto


static func b(v: Array) -> Vector3:
	return Vector3(v[0], v[2], -v[1])


func _ready() -> void:
	dati = JSON.parse_string(FileAccess.get_file_as_string(DIR + "torre_gioco.json"))
	var acqua: Material = load("res://assets/materials/sala/acqua_torbida.tres")
	# i tre GLB sono figli della scena (scenes/sala/torre/sala_torre.tscn), così si caricano col thread;
	# se la si crea da codice si caricano qui
	for nome in ["torre_struttura", "torre_scivoli", "torre_prop"]:
		var nodo: String = String(nome).capitalize().replace(" ", "")
		if get_node_or_null(nodo) == null:
			var glb: Node3D = (load(DIR + nome + ".glb") as PackedScene).instantiate()
			glb.name = nodo
			add_child(glb)
	for m in find_children("acqua*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = acqua
	_scivoli()
	_prepara_imbocchi()
	_checkpoint()
	_caduta_sul_fondo()
	_polaroid()
	_balconata()
	_vasca_fondo()
	if crea_luci:
		_luci(JSON.parse_string(FileAccess.get_file_as_string(DIR + "torre_luci.json")))
	_luce_lei()


## I corpi statici dei canali della discesa vanno nel gruppo "scivolo". Tutte le forme trimesh della sala
## collidono da tutte e due le facce (l'importatore le fa da una sola: dentro i canali e i tubi si passerebbe
## attraverso le sponde viste dall'altra parte).
func _scivoli() -> void:
	for f in find_children("*", "CollisionShape3D", true, false):
		var forma := (f as CollisionShape3D).shape as ConcavePolygonShape3D
		if forma:
			forma.backface_collision = true
	# i canali della discesa: un corpo per pezzo, costruito dalla linea del fondo come nella scena di prova
	# degli scivoli di grafica (scenes/test/scivoli_prova.gd: canale a U tondo, sponde a 84 gradi)
	var radice := Node3D.new()
	radice.name = "CollisioniDiscesa"
	add_child(radice)
	for t in dati["tratti"]:
		for j in (t["pezzi"] as Array).size():
			var linea := PackedVector3Array()
			for q in t["linee"][j]:
				linea.append(b(q))
			radice.add_child(_corpo_scivolo(String(t["pezzi"][j]), linea))
			if j == 0:
				radice.add_child(_rampa_imbocco(String(t["pezzi"][j]) + "_rampa", linea))


const RAGGIO_CANALE := 1.05
const SPONDA_CANALE := 84.0


## L'imbocco svasato: davanti all'inizio del canale un fondo curvo largo e quasi piano (raggio da 3 m fino a
## quello del canale) che parte a filo della grata della pedana e sale di pochi centimetri fino al fondo del
## canale. Chi entra spostato dal centro ci sale sopra invece di urtare il bordo del canale, e non c'è una
## cresta che lo faccia decollare.
func _rampa_imbocco(nome: String, linea: PackedVector3Array) -> StaticBody3D:
	var tg := Vector3(linea[1].x - linea[0].x, 0.0, linea[1].z - linea[0].z).normalized()
	var lato := tg.cross(Vector3.UP).normalized()
	var colonne := 12
	var anelli: Array[PackedVector3Array] = []
	for passo in [[-0.7, 3.0, -0.06], [-0.35, 2.0, -0.035], [0.0, 1.4, -0.01], [0.35, 1.15, -0.03]]:
		var s_: float = passo[0]
		var r: float = passo[1]
		var base: Vector3 = linea[0] + tg * s_ + Vector3.UP * float(passo[2])
		if s_ > 0.0:
			base = linea[0].lerp(linea[1], s_ / linea[0].distance_to(linea[1])) + Vector3.UP * float(passo[2])
		var largo := minf(1.25, r * 0.9)
		var anello := PackedVector3Array()
		for k in colonne + 1:
			var x := lerpf(-largo, largo, float(k) / colonne)
			anello.append(base + lato * x + Vector3.UP * (r - sqrt(r * r - x * x)))
		anelli.append(anello)
	var facce := PackedVector3Array()
	for i in anelli.size() - 1:
		for k in colonne:
			facce.append_array([anelli[i][k], anelli[i + 1][k], anelli[i][k + 1],
					anelli[i][k + 1], anelli[i + 1][k], anelli[i + 1][k + 1]])
	var corpo := StaticBody3D.new()
	corpo.name = nome
	corpo.add_to_group(&"scivolo")
	corpo.set_meta(&"superficie", &"scivolo")
	corpo.set_meta(&"bagnato", true)
	var cs := CollisionShape3D.new()
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(facce)
	forma.backface_collision = true
	cs.shape = forma
	corpo.add_child(cs)
	return corpo


func _corpo_scivolo(nome: String, punti: PackedVector3Array) -> StaticBody3D:
	var linea := _campiona(punti, 0.3)
	var colonne := 18
	var facce := PackedVector3Array()
	var anelli: Array[PackedVector3Array] = []
	for i in linea.size():
		var t := (linea[mini(i + 1, linea.size() - 1)] - linea[maxi(i - 1, 0)]).normalized()
		var lato := t.cross(Vector3.UP).normalized()
		var su := lato.cross(t).normalized()
		var anello := PackedVector3Array()
		for k in colonne + 1:
			var a := deg_to_rad(lerpf(-SPONDA_CANALE, SPONDA_CANALE, float(k) / colonne))
			anello.append(linea[i] + lato * sin(a) * RAGGIO_CANALE + su * (1.0 - cos(a)) * RAGGIO_CANALE)
		anelli.append(anello)
	for i in anelli.size() - 1:
		for k in colonne:
			facce.append_array([anelli[i][k], anelli[i + 1][k], anelli[i][k + 1],
					anelli[i][k + 1], anelli[i + 1][k], anelli[i + 1][k + 1]])
	var corpo := StaticBody3D.new()
	corpo.name = nome
	corpo.add_to_group(&"scivolo")
	corpo.set_meta(&"superficie", &"scivolo")
	corpo.set_meta(&"bagnato", true)
	var cs := CollisionShape3D.new()
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(facce)
	forma.backface_collision = true
	cs.shape = forma
	corpo.add_child(cs)
	return corpo


## La linea del fondo: Catmull-Rom tra i punti, un campione ogni [param passo] metri circa.
static func _campiona(punti: PackedVector3Array, passo: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in punti.size() - 1:
		var p0: Vector3 = punti[maxi(i - 1, 0)]
		var p1: Vector3 = punti[i]
		var p2: Vector3 = punti[i + 1]
		var p3: Vector3 = punti[mini(i + 2, punti.size() - 1)]
		var n := maxi(1, ceili(p1.distance_to(p2) / passo))
		for k in n:
			var t := float(k) / n
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(punti[punti.size() - 1])
	return out


func corpi_scivolo() -> Array[Node]:
	return get_tree().get_nodes_in_group(&"scivolo").filter(func(c): return is_ancestor_of(c))


func _checkpoint() -> void:
	var i := 0
	for cp in dati["checkpoint"]:
		var a := Checkpoint.new()
		a.name = "Checkpoint_%s" % String(cp["nome"]).replace(" ", "").replace("-", "m")
		a.order = ordine_base + i
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.0, 2.6, 3.0)
		forma.shape = box
		forma.position = Vector3(0, 1.3, 0)
		a.add_child(forma)
		add_child(a)
		var pos := b(cp["pos"])
		a.global_position = pos
		# si riparte un metro dietro l'inizio del tratto dopo, rivolti nella sua direzione
		var rip := Marker3D.new()
		rip.name = "Ripartenza"
		a.add_child(rip)
		var sp := b(cp.get("spawn", cp["pos"]))
		var guarda := b(cp["guarda"])
		guarda.y = sp.y
		rip.global_position = sp
		if guarda.distance_to(sp) > 0.1:
			rip.look_at(guarda, Vector3.UP)
		a.spawn_point = rip
		checkpoint.append(a)
		_quote_cp.append(pos.y)
		i += 1


## Il fondo della sala fuori dalla vasca d'arrivo è una zona di caduta (cadere da 5-20 m non perdona).
func _caduta_sul_fondo() -> void:
	var v: Array = dati["vasca_fondo"]["rett"]
	var y := float(dati["pozzo"][2])
	var x0 := 20.2
	var x1 := 40.0
	var y0 := 4.0
	var y1 := 26.0
	# quattro fasce attorno alla vasca (coordinate di Blender: x, y)
	var fasce := [[x0, y0, x1, v[1]], [x0, v[3], x1, y1], [x0, v[1], v[0], v[3]], [v[2], v[1], x1, v[3]]]
	for k in fasce.size():
		var f: Array = fasce[k]
		if f[2] - f[0] < 0.05 or f[3] - f[1] < 0.05:
			continue
		var z := KillZone.new()
		z.name = "CadutaFondo%d" % k
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(f[2] - f[0], 1.2, f[3] - f[1])
		forma.shape = box
		z.add_child(forma)
		add_child(z)
		z.global_position = b([(f[0] + f[2]) / 2.0, (f[1] + f[3]) / 2.0, y + 0.3])


func _physics_process(_delta: float) -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p) or GameState.is_dying:
		return
	var y := p.global_position.y
	# caduta: più giù della pedana del prossimo checkpoint, oltre il margine
	var i := checkpoint_raggiunto()
	if i >= 0 and i + 1 < _quote_cp.size() and _in_sala(p.global_position):
		if y < _quote_cp[i + 1] - margine_caduta:
			GameState.kill_player(&"caduta")
			return
		# fermi su qualcosa nel vuoto (un tubo, una trave), lontano dalle pedane e sotto l'ultimo checkpoint:
		# da lì non si riparte, quindi conta come caduta
		if p.is_on_floor() and not p.is_sliding and y < _quote_cp[i] - 1.0 \
				and p.global_position.distance_to(checkpoint[i + 1].global_position) > 4.0:
			_fermo += _delta
			if _fermo > tempo_bloccato:
				_fermo = 0.0
				GameState.kill_player(&"caduta")
				return
		else:
			_fermo = 0.0
	_guida_imbocchi(p, _delta)
	# la luce di lei sale dal pozzo: più forte man mano che scendi
	var k := clampf((_quote_cp[0] - y) / maxf(_quote_cp[0] - _quote_cp[-1], 1.0), 0.0, 1.0)
	for l in _lei:
		l.light_energy = float(l.get_meta(&"base")) * lerpf(lei_in_cima, lei_in_fondo, k) / lei_in_fondo


func _prepara_imbocchi() -> void:
	for tr in dati["tratti"]:
		var linea: Array = tr["linee"][0]
		var pts := PackedVector3Array()
		var lung := 0.0
		for i in linea.size():
			var q := b(linea[i])
			if i > 0:
				lung += q.distance_to(pts[i - 1])
			pts.append(q)
			if lung > guida_metri:
				break
		_imbocchi.append(pts)


func _guida_imbocchi(p: Player, delta: float) -> void:
	var hv := Vector3(p.velocity.x, 0.0, p.velocity.z)
	if hv.length() > guida_fino_a or p.slide_launched:
		return
	var pos := p.global_position
	for pts in _imbocchi:
		# il segmento più vicino (in pianta) dei primi metri del canale, o il prolungamento davanti all'imbocco
		var migliore := -1
		var dm := 1.5
		for i in pts.size() - 1:
			if pos.y - pts[i].y > 2.0 or pos.y - pts[i].y < -1.0:
				continue
			var a := Vector2(pts[i].x, pts[i].z)
			var c := Vector2(pts[i + 1].x, pts[i + 1].z)
			if i == 0:
				a -= (c - a).normalized() * 1.2      # davanti all'imbocco, dentro l'imbuto
			var d := Geometry2D.get_closest_point_to_segment(Vector2(pos.x, pos.z), a, c).distance_to(Vector2(pos.x, pos.z))
			if d < dm:
				dm = d
				migliore = i
		if migliore < 0:
			continue
		var t := Vector3(pts[migliore + 1].x - pts[migliore].x, 0.0, pts[migliore + 1].z - pts[migliore].z).normalized()
		# solo chi va verso il canale (o ci scivola già): l'acqua lo porta dentro e al centro
		if hv.dot(t) < 0.1 and not p.is_sliding:
			return
		var lat := Vector3(-t.z, 0.0, t.x)
		var e := (pos - pts[migliore]).dot(lat)
		var voluta := (t - lat * clampf(e, -1.0, 1.0) * 0.9).normalized() * maxf(hv.length(), 2.6)
		hv = hv.lerp(voluta, clampf(guida_forza * delta, 0.0, 1.0))
		p.velocity.x = hv.x
		p.velocity.z = hv.z
		return


func _in_sala(pos: Vector3) -> bool:
	return pos.x > 20.2 and pos.x < 40.0 and pos.z > -26.0 and pos.z < -4.0


## Indice dell'ultimo checkpoint della torre raggiunto (-1 se nessuno).
func checkpoint_raggiunto() -> int:
	var key := String(GameState.snapshot.get("checkpoint", ""))
	for i in range(checkpoint.size() - 1, -1, -1):
		if is_instance_valid(checkpoint[i]) and GameState.persist_key(checkpoint[i]) == key:
			return i
	var ordine := int(GameState.snapshot.get("order", -1))
	return clampi(ordine - ordine_base, -1, checkpoint.size() - 1) if ordine >= ordine_base else -1


func _polaroid() -> void:
	var foto: Node3D = (load("res://scenes/props/polaroid.tscn") as PackedScene).instantiate()
	foto.name = "Polaroid10"
	if &"photo" in foto:
		foto.set(&"photo", 10)
	add_child(foto)
	foto.global_position = b(dati["polaroid_10"]) + Vector3(0, 0.05, 0)


## La fila di bambini sulla balconata: invisibili; al primo salto un lampo li mostra per un attimo.
func _balconata() -> void:
	var c := b(dati["balconata"]["centro"])
	var salto := b(dati["balconata"]["primo_salto"])
	for i in 4:
		var bimbo: Node3D = (load(BAMBINI[i % 2]) as PackedScene).instantiate()
		bimbo.name = "BambinoBalconata%d" % i
		add_child(bimbo)
		bimbo.global_position = c + Vector3(-1.8 + 1.2 * i, 0.0, -0.3)
		var verso := Vector3(salto.x, bimbo.global_position.y, salto.z)
		if verso.distance_to(bimbo.global_position) > 0.1:
			bimbo.look_at(verso, Vector3.UP, true)
		bimbo.visible = false
		bimbo.process_mode = Node.PROCESS_MODE_DISABLED
		_bambini.append(bimbo)
	var area := Area3D.new()
	area.name = "LampoBalconata"
	area.collision_layer = 0
	area.collision_mask = Layers.PLAYER
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var sfera := SphereShape3D.new()
	sfera.radius = 2.2
	forma.shape = sfera
	area.add_child(forma)
	add_child(area)
	area.global_position = salto
	area.body_entered.connect(func(corpo):
		if corpo is Player and not _lampo_fatto:
			lampo())
	var luce := OmniLight3D.new()
	luce.name = "LuceLampo"
	luce.light_color = Color(0.85, 0.9, 1.0)
	luce.light_energy = 0.0
	luce.omni_range = 9.0
	luce.shadow_enabled = true
	add_child(luce)
	luce.global_position = c + Vector3(0, 2.6, 1.2)


## Il lampo: la luce bianca sopra la balconata scatta, i bambini si vedono per un istante e spariscono.
func lampo() -> void:
	if _lampo_fatto:
		return
	_lampo_fatto = true
	var luce := get_node_or_null("LuceLampo") as OmniLight3D
	for bimbo in _bambini:
		bimbo.visible = true
	if luce:
		luce.light_energy = 14.0
	await get_tree().create_timer(0.12, false).timeout
	if luce:
		luce.light_energy = 2.0
	await get_tree().create_timer(0.08, false).timeout
	if luce:
		luce.light_energy = 16.0
	await get_tree().create_timer(0.22, false).timeout
	if luce:
		luce.light_energy = 0.0
	for bimbo in _bambini:
		if is_instance_valid(bimbo):
			bimbo.queue_free()
	_bambini.clear()


func _vasca_fondo() -> void:
	var v: Array = dati["vasca_fondo"]["rett"]
	var area := Area3D.new()
	area.name = "VascaFondo"
	area.collision_layer = 0
	area.collision_mask = Layers.PLAYER
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(v[2] - v[0] - 0.4, 1.4, v[3] - v[1] - 0.4)
	forma.shape = box
	area.add_child(forma)
	add_child(area)
	area.global_position = b([(v[0] + v[2]) / 2.0, (v[1] + v[3]) / 2.0, float(dati["vasca_fondo"]["acqua"]) - 0.2])
	area.body_entered.connect(func(corpo):
		if corpo is Player and not _finita:
			_finita = true
			discesa_finita.emit())


# --- luci ------------------------------------------------------------------------------------------

func _luce_lei() -> void:
	var p := b(dati["pozzo"])
	var fondo := MeshInstance3D.new()
	fondo.name = "FondoPozzo"
	var cil := CylinderMesh.new()
	cil.top_radius = 1.7
	cil.bottom_radius = 1.7
	cil.height = 0.05
	fondo.mesh = cil
	var m := StandardMaterial3D.new()
	m.albedo_color = ROSA
	m.emission_enabled = true
	m.emission = ROSA
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fondo.material_override = m
	add_child(fondo)
	fondo.global_position = p + Vector3(0, -5.0, 0)
	for d in [[Vector3(0, -0.8, 0), 14.0, 10.0, false], [Vector3(0, -3.5, 0), 10.0, 4.0, false]]:
		var o := OmniLight3D.new()
		o.light_color = ROSA
		o.omni_range = d[2]
		o.light_volumetric_fog_energy = 3.0
		o.set_meta(&"base", d[1])
		o.set_meta(&"risveglio_ignora", true)
		add_child(o)
		o.global_position = p + d[0]
		_lei.append(o)
	var s := SpotLight3D.new()
	s.light_color = ROSA
	s.spot_range = 30.0
	s.spot_angle = 16.0
	s.shadow_enabled = true
	s.light_volumetric_fog_energy = 4.0
	s.set_meta(&"base", 22.0)
	s.set_meta(&"risveglio_ignora", true)
	add_child(s)
	s.global_position = p + Vector3(0, -2.5, 0)
	s.rotation_degrees = Vector3(90, 0, 0)
	_lei.append(s)


func _luci(d: Dictionary) -> void:
	var versi := {"e": Vector3.RIGHT, "o": Vector3.LEFT, "n": Vector3.FORWARD, "s": Vector3.BACK}
	var radice := Node3D.new()
	radice.name = "Luci"
	add_child(radice)
	for e in d["emergenza"]:
		_emergenza(radice, b(e[0]), versi[e[1]])
	for p in d["lavoro"]:
		_lampada(radice, b(p), str(p[3]) if (p as Array).size() > 3 else "")
	for f in d["fari"]:
		_faro(radice, b(f[0]), b(f[1]), b(f[2]) if (f as Array).size() > 2 else null)
	for g in d["gocce"]:
		_gocce(radice, b(g))
	_catena(radice, b(d["lei"]))


static func _emissivo(colore: Color, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.emission_enabled = true
	m.emission = colore
	m.emission_energy_multiplier = energia
	return m


func _emergenza(radice: Node3D, p: Vector3, verso: Vector3) -> void:
	var corpo := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.16, 0.3, 0.3) if absf(verso.x) > 0.5 else Vector3(0.3, 0.3, 0.16)
	corpo.mesh = bx
	corpo.material_override = _emissivo(ROSSO, 6.0)
	radice.add_child(corpo)
	corpo.global_position = p
	var l := OmniLight3D.new()
	l.light_color = ROSSO
	l.light_energy = 3.5
	l.omni_range = 7.5
	l.light_volumetric_fog_energy = 1.5
	radice.add_child(l)
	l.global_position = p + verso * 0.4


func _lampada(radice: Node3D, p: Vector3, appoggio := "") -> void:
	# lampada da cantiere: bulbo caldo in una gabbia, su un palo dalla pedana o su una staffa al muro
	var bulbo := MeshInstance3D.new()
	var sf := SphereMesh.new()
	sf.radius = 0.07
	sf.height = 0.14
	bulbo.mesh = sf
	bulbo.material_override = _emissivo(Color(1.0, 0.55, 0.25), 1.2)
	radice.add_child(bulbo)
	bulbo.global_position = p
	var metallo := _metallo_scuro()
	var gabbia := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.1
	gm.bottom_radius = 0.1
	gm.height = 0.24
	gm.radial_segments = 8
	gm.rings = 2
	gabbia.mesh = gm
	var mg := _metallo_scuro()
	mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mg.albedo_texture = _griglia()
	mg.cull_mode = BaseMaterial3D.CULL_DISABLED
	gabbia.material_override = mg
	radice.add_child(gabbia)
	gabbia.global_position = p
	var cappello := MeshInstance3D.new()
	var cp := CylinderMesh.new()
	cp.top_radius = 0.06
	cp.bottom_radius = 0.13
	cp.height = 0.07
	cappello.mesh = cp
	cappello.material_override = metallo
	radice.add_child(cappello)
	cappello.global_position = p + Vector3(0, 0.15, 0)
	if appoggio == "palo":
		_asta(radice, p + Vector3(0, 0.18, 0), p + Vector3(0, -1.25, 0), 0.03, metallo)
	elif appoggio.begins_with("muro_"):
		var verso: Vector3 = {"muro_n": Vector3.FORWARD, "muro_s": Vector3.BACK, "muro_e": Vector3.RIGHT, "muro_o": Vector3.LEFT}[appoggio]
		_asta(radice, p + Vector3(0, 0.18, 0), p + Vector3(0, 0.18, 0) + verso * 0.4, 0.025, metallo)
	var l := OmniLight3D.new()
	l.light_color = CALDO
	l.light_energy = 4.0
	l.omni_range = 8.0
	radice.add_child(l)
	l.global_position = p + Vector3(0, -0.15, 0)


## Faro da cantiere su un braccio dalla colonna del traliccio: corpo tondo di metallo, cornice e lente
## tonda calda (non abbagliante), staffa a U. La luce è quella di prima.
func _faro(radice: Node3D, p: Vector3, mira: Vector3, attacco = null) -> void:
	var metallo := _metallo_scuro()
	var corpo := Node3D.new()
	radice.add_child(corpo)
	corpo.global_position = p
	corpo.look_at(mira)
	var guscio := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.2
	cm.height = 0.3
	guscio.mesh = cm
	guscio.material_override = metallo
	corpo.add_child(guscio)
	guscio.rotation_degrees = Vector3(-90, 0, 0)
	var cornice := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.17
	tm.outer_radius = 0.22
	cornice.mesh = tm
	cornice.material_override = metallo
	corpo.add_child(cornice)
	cornice.rotation_degrees = Vector3(90, 0, 0)
	cornice.position = Vector3(0, 0, -0.15)
	var lente := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.175
	lm.bottom_radius = 0.175
	lm.height = 0.02
	lente.mesh = lm
	lente.material_override = _emissivo(Color(1.0, 0.6, 0.28), 0.9)
	corpo.add_child(lente)
	lente.rotation_degrees = Vector3(90, 0, 0)
	lente.position = Vector3(0, 0, -0.145)
	# staffa a U attorno al corpo e braccio fino alla colonna
	for sg in [-1.0, 1.0]:
		_asta(corpo, Vector3(sg * 0.24, 0, 0), Vector3(sg * 0.24, -0.26, 0), 0.02, metallo, false)
	_asta(corpo, Vector3(-0.24, -0.26, 0), Vector3(0.24, -0.26, 0), 0.02, metallo, false)
	if attacco != null:
		var a: Vector3 = attacco
		_asta(radice, corpo.to_global(Vector3(0, -0.26, 0)), a, 0.04, metallo)
	var l := SpotLight3D.new()
	l.light_color = Color(1.0, 0.88, 0.72)
	l.light_energy = 16.0
	l.spot_range = 30.0
	l.spot_angle = 24.0
	l.spot_attenuation = 0.6
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 0.8
	radice.add_child(l)
	l.global_position = p
	l.look_at(mira)


static func _metallo_scuro() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.31, 0.29)
	m.metallic = 0.7
	m.roughness = 0.45
	return m


static var _tex_griglia: ImageTexture


static func _griglia() -> ImageTexture:
	if _tex_griglia == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for i in 32:
			for j in 32:
				if i % 8 < 2 or j % 16 < 2:
					img.set_pixel(i, j, Color(1, 1, 1, 1))
		_tex_griglia = ImageTexture.create_from_image(img)
	return _tex_griglia


## Un'asta tonda da a a b (in coordinate del padre se globale = false).
func _asta(padre: Node3D, a: Vector3, b_: Vector3, r: float, m: Material, globale := true) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b_)
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	padre.add_child(mi)
	var centro := (a + b_) * 0.5
	var asse := (b_ - a).normalized()
	var t := Transform3D()
	var su := asse
	var lato := su.cross(Vector3.FORWARD if absf(su.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	t.basis = Basis(lato, su, lato.cross(su))
	t.origin = centro
	if globale:
		mi.global_transform = t
	else:
		mi.transform = t


func _gocce(radice: Node3D, p: Vector3) -> void:
	var g := CPUParticles3D.new()
	var sf := SphereMesh.new()
	sf.radius = 0.012
	sf.height = 0.05
	g.mesh = sf
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.8, 0.85, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	g.material_override = m
	g.amount = 40
	g.lifetime = 2.0
	g.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	g.emission_box_extents = Vector3(0.3, 0.02, 0.3)
	g.direction = Vector3.DOWN
	g.initial_velocity_min = 0.2
	g.initial_velocity_max = 0.6
	g.gravity = Vector3(0, -9.8, 0)
	radice.add_child(g)
	g.global_position = p


## Una catena appesa al centro del soffitto con tre grappoli di lampade da cantiere.
func _catena(radice: Node3D, fondo: Vector3) -> void:
	var cavo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	var basso := fondo.y + 6.0
	cm.height = 14.0 - basso
	cavo.mesh = cm
	var nero := StandardMaterial3D.new()
	nero.albedo_color = Color(0.06, 0.06, 0.06)
	nero.metallic = 0.8
	cavo.material_override = nero
	radice.add_child(cavo)
	cavo.global_position = Vector3(fondo.x + 1.2, (14.0 + basso) / 2.0, fondo.z)
	for y in [9.0, -3.0, basso]:
		for k in 3:
			var a := TAU * k / 3.0
			var bulbo := MeshInstance3D.new()
			var sf := SphereMesh.new()
			sf.radius = 0.08
			sf.height = 0.16
			bulbo.mesh = sf
			bulbo.material_override = _emissivo(CALDO, 9.0)
			radice.add_child(bulbo)
			bulbo.global_position = Vector3(fondo.x + 1.2 + cos(a) * 0.35, y - 0.1 * k, fondo.z + sin(a) * 0.35)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.62)
		l.light_energy = 6.0
		l.omni_range = 15.0
		l.omni_attenuation = 0.8
		l.shadow_enabled = true
		l.light_volumetric_fog_energy = 0.6
		radice.add_child(l)
		l.global_position = Vector3(fondo.x + 1.2, y - 0.2, fondo.z)
