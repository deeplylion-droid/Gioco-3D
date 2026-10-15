class_name RitornoAlBuio
extends Node
## Tappa 7 di docs/livello/capitolo1.md, il ritorno al buio: dopo il risveglio nella sala pompe
## (GameState.luci = BLACKOUT) si torna su dal raccordo, si ripassa dagli spogliatoi e si esce
## dalla stessa porta di prima nella sala.
## - la porta "sala pompe" del corridoio degli interni si apre (prima era chiusa);
## - le docce scorrono senza fermarsi e il vapore copre tutto;
## - nella sala la vasca è vuota: la medusa non c'è più, l'acqua si muove ancora, dal bordo
##   gocciola e una scia di gocce si allontana nel buio verso l'area bimbi;
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
## La scia di gocce, dal bordo della vasca verso l'area bimbi (punti a terra, in ordine).
@export var scia := PackedVector3Array()
## Da dove gocciola ancora (sul bordo della vasca, dalla parte della scia).
@export var gocciolatoi := PackedVector3Array()
## Materiale delle macchie bagnate a terra (quello delle pozzanghere della sala).
@export var materiale_bagnato: Material
## Passo delle macchie lungo la scia (m).
@export var passo_scia := 0.55

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
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
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
			m.material_override = materiale_bagnato
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var grande := lerpf(0.42, 0.14, k) * _rng.randf_range(0.7, 1.2)
			radice.add_child(m)
			m.global_position = p + Vector3(0.0, 0.006, 0.0)
			m.rotation = Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0)
			m.scale = Vector3(grande, 1.0, grande * _rng.randf_range(0.6, 1.0))
			d += passo_scia * lerpf(1.0, 1.8, k) * _rng.randf_range(0.8, 1.25)
		fatta += tratto
	for g in gocciolatoi:
		var e := WaterDripEmitter.new()
		e.name = "Gocciolatoio"
		e.interval_min = 1.2
		e.interval_max = 3.8
		radice.add_child(e)
		e.global_position = g


## Quante macchie ha la scia (per i test).
func macchie_scia() -> int:
	var radice := get_node_or_null(^"Scia")
	return radice.find_children("*", "MeshInstance3D", false, false).size() if radice else 0


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
