class_name RitornoAlBuio
extends Node
## Tappa 7 di docs/livello/capitolo1.md, il ritorno al buio: dopo il risveglio nella sala pompe
## (GameState.luci = BLACKOUT) si torna su dal raccordo, si ripassa dagli spogliatoi e si esce
## dalla stessa porta di prima nella sala.
## - la porta "sala pompe" del corridoio degli interni si apre (prima era chiusa);
## - le docce scorrono senza fermarsi e il vapore copre tutto;
## - nella sala la vasca è vuota: la medusa non c'è più, l'acqua si muove ancora, dal bordo
##   gocciola e una scia di bava rosa fosforescente (prima erano gocce) si allontana nel buio verso
##   l'area bimbi;
## - niente musica (senza corrente il pulsante della sigla non suona), solo gocce e tempesta;
##   il lampione resta spento (lo spegne il blackout).
## Tutto dipende da GameState.luci, che si salva con i checkpoint: ripartendo dal blackout la
## sala torna così com'era; ripartendo da prima del risveglio torna com'era prima.

## La medusa affacciata alla vasca (sparisce).
@export var medusa: Node3D
## L'acqua dell'addon sulla vasca della medusa (WaterTankLink): si muove ancora.
@export var acqua_vasca: Node3D
## Dove stava la medusa: da lì partono le increspature.
@export var centro_increspature := Vector3(0.0, 0.88, 11.0)
## Gli interni (docce) e la porta della sala pompe nel loro corridoio.
@export var interni: Node
@export var porta_interni: Node
## Il pulsante della sigla: senza corrente non fa niente.
@export var pulsante_sigla: Node
## La scia (bava rosa o gocce), dal bordo della vasca verso l'area bimbi (punti a terra, in ordine).
@export var scia := PackedVector3Array()
## Da dove gocciola ancora (sul bordo della vasca, dalla parte della scia).
@export var gocciolatoi := PackedVector3Array()
## Materiale delle macchie bagnate a terra (quello delle pozzanghere della sala).
@export var materiale_bagnato: Material
## Passo delle macchie lungo la scia (m).
@export var passo_scia := 0.55
## Vero: al posto delle gocce una scia continua di bava rosa fosforescente (BavaRosa dell'addon
## grafica), del colore dei tentacoli: le gocce al buio non si vedevano (riscontro F5).
@export var scia_bava := true
## Bava rosa intorno alla fossa della VascaBimbi1 (tappa 8, riscontro F6): sul bordo e a terra
## tutto intorno. In coordinate globali, come [member scia].
@export var bordo_fossa := PackedVector3Array([Vector3(-12.15, 0.455, -7.7), Vector3(-12.15, 0.455, -5.85), Vector3(-13.8, 0.455, -5.85), Vector3(-14.95, 0.455, -7.0)])
@export var intorno_fossa := PackedVector3Array([Vector3(-11.7, 0.0, -7.8), Vector3(-11.7, 0.0, -5.4), Vector3(-13.95, 0.0, -5.4), Vector3(-15.4, 0.0, -6.9), Vector3(-15.4, 0.0, -8.4)])

var attivo := false
var increspature := 0   # quante ne ha fatte (per i test)

var _nodi: Array[Node] = []
var _prossima := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	GameState.luci_cambiate.connect(_on_luci)
	# Dopo che la sala e gli interni hanno preparato i loro nodi (docce, porte).
	_on_luci.call_deferred(GameState.luci)


func _on_luci(fase: GameState.Luci) -> void:
	if fase == GameState.Luci.BLACKOUT and not attivo:
		_attiva()
	elif fase == GameState.Luci.PRIMA_DEL_RISVEGLIO and attivo:
		_disattiva()


func _attiva() -> void:
	attivo = true
	if medusa:
		medusa.visible = false
		medusa.process_mode = Node.PROCESS_MODE_DISABLED
	if pulsante_sigla:
		pulsante_sigla.process_mode = Node.PROCESS_MODE_DISABLED
	if porta_interni:
		porta_interni.set(&"bloccata", false)
	if interni and interni.has_method(&"apri_docce"):
		interni.call(&"apri_docce", true)
		_vapore_negli_spogliatoi()
	_scia()


func _disattiva() -> void:
	attivo = false
	if medusa:
		medusa.visible = true
		medusa.process_mode = Node.PROCESS_MODE_INHERIT
	if pulsante_sigla:
		pulsante_sigla.process_mode = Node.PROCESS_MODE_INHERIT
	if porta_interni:
		porta_interni.set(&"bloccata", true)
	if interni and interni.has_method(&"apri_docce"):
		interni.call(&"apri_docce", false)
	for n in _nodi:
		if is_instance_valid(n):
			n.queue_free()
	_nodi.clear()


## Vapore che copre tutto: oltre a quello delle docce, uno sopra ogni coppia di docce.
func _vapore_negli_spogliatoi() -> void:
	var docce := interni.find_children("getto_doccia_*", "", true, false)
	for i in range(0, docce.size(), 2):
		var v := Vapore.new()
		v.name = "VaporeBuio%d" % i
		v.portata = 1.6
		v.raggio = 1.2
		v.altezza = 2.4
		add_child(v)
		v.global_position = (docce[i] as Node3D).global_position - Vector3(0.0, 1.9, 0.0)
		_nodi.append(v)


## La scia: macchie bagnate a terra sempre più rade e piccole, e qualche goccia che cade ancora
## dal bordo della vasca.
func _scia() -> void:
	var radice := Node3D.new()
	radice.name = "Scia"
	add_child(radice)
	_nodi.append(radice)
	if scia_bava:
		_bava(radice, "BavaScia", scia, 0.34, 3)
		_bava(radice, "BavaBordoFossa", bordo_fossa, 0.2, 5)
		_bava(radice, "BavaIntornoFossa", intorno_fossa, 0.42, 7)
		_gocciolatoi(radice)
		return
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	var mat := materiale_bagnato if materiale_bagnato else _materiale_goccia()
	var fatta := 0.0
	var lunghezza := 0.0
	for i in range(1, scia.size()):
		lunghezza += scia[i - 1].distance_to(scia[i])
	for i in range(1, scia.size()):
		var a := scia[i - 1]
		var b := scia[i]
		var tratto := a.distance_to(b)
		var d := 0.0
		while d < tratto:
			var k := (fatta + d) / maxf(lunghezza, 0.01)
			var p := a.lerp(b, d / tratto)
			var lato := (b - a).normalized().cross(Vector3.UP)
			p += lato * _rng.randf_range(-0.18, 0.18)
			var m := MeshInstance3D.new()
			m.mesh = quad
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var grande := lerpf(0.36, 0.12, k) * _rng.randf_range(0.7, 1.25)
			radice.add_child(m)
			m.global_position = p + Vector3(0.0, 0.006, 0.0)
			# Allungate nel verso in cui si è trascinata.
			m.rotation = Vector3(0.0, atan2((b - a).x, (b - a).z) + _rng.randf_range(-0.4, 0.4), 0.0)
			m.scale = Vector3(grande * _rng.randf_range(0.55, 0.9), 1.0, grande * _rng.randf_range(1.0, 1.7))
			d += passo_scia * lerpf(1.0, 1.8, k) * _rng.randf_range(0.8, 1.25)
		fatta += tratto
	_gocciolatoi(radice)


func _bava(radice: Node3D, nome: String, percorso: PackedVector3Array, larga: float, seme: int) -> void:
	if percorso.size() < 2:
		return
	var b := BavaRosa.new()
	b.name = nome
	b.punti = percorso
	b.larghezza = larga
	b.seme = seme
	radice.add_child(b)


func _gocciolatoi(radice: Node3D) -> void:
	for g in gocciolatoi:
		var e := WaterDripEmitter.new()
		e.name = "Gocciolatoio"
		e.interval_min = 1.2
		e.interval_max = 3.8
		radice.add_child(e)
		e.global_position = g


## Macchia bagnata tonda: scura, lucida, che sfuma ai bordi (una goccia schiacciata a terra).
static func _materiale_goccia() -> StandardMaterial3D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.03, 0.035, 0.04, 0.8)
	m.albedo_texture = t
	m.roughness = 0.04
	m.metallic_specular = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Quante macchie ha la scia (per i test).
func macchie_scia() -> int:
	var radice := get_node_or_null(^"Scia")
	return radice.find_children("*", "MeshInstance3D", false, false).size() if radice else 0


## Quanti metri di scia ci sono a terra: la bava rosa lungo [member scia] o, con le gocce, una
## macchia ogni [member passo_scia] (0 se non c'è).
func metri_scia() -> float:
	var radice := get_node_or_null(^"Scia")
	if radice == null:
		return 0.0
	var bava := radice.get_node_or_null(^"BavaScia") as BavaRosa
	if bava == null:
		return macchie_scia() * passo_scia
	var metri := 0.0
	for i in range(1, bava.punti.size()):
		metri += bava.punti[i - 1].distance_to(bava.punti[i])
	return metri if bava.get_child_count() > 0 else 0.0


func _process(delta: float) -> void:
	if not attivo or acqua_vasca == null or not acqua_vasca.has_method(&"add_impulse"):
		return
	# L'acqua della vasca si muove ancora, come se fosse appena uscita.
	_prossima -= delta
	if _prossima <= 0.0:
		_prossima = _rng.randf_range(0.5, 1.6)
		var p := centro_increspature + Vector3(_rng.randf_range(-1.6, 1.6), 0.0, _rng.randf_range(-0.9, 0.9))
		acqua_vasca.call(&"add_impulse", p, _rng.randf_range(0.25, 0.6), -_rng.randf_range(0.004, 0.011), 0.0)
		increspature += 1
