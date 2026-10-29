class_name Medusine
extends Node3D
## Tappa 5, scelta dell'utente del 16 ottobre: nell'acqua torbida della parte profonda della piscina
## a onde nuotano una quindicina di micro medusine luminose di vari colori, per attirare lo sguardo.
## Si muovono come meduse vere: la campana si contrae e le spinge, poi si rilassa e scivolano, si
## girano piano e sotto il pelo si voltano di lato; i tentacoli ondeggiano e restano indietro.
## Mentre si aspira l'acqua con lo zaino si aspirano anche loro: la corrente le tira verso il punto
## da cui si aspira e salgono col filo d'acqua fino all'ugello. Restano nello zaino con l'acqua ed
## escono col getto: volano via e finiscono a terra, dove restano accese ancora un po' e poi si
## spengono; se cadono in un'altra vasca spariscono, se ricadono nell'acqua della piscina ci
## nuotano di nuovo. Più l'acqua scende, meno ne restano: quando la piscina è vuota non ce n'è più
## nessuna. Le crea PiscinaOnde ([member PiscinaOnde.medusine]).

## Una medusina è entrata nell'ugello dello zaino (per il suono di vetro).
signal aspirata(posizione: Vector3)
## Una medusina è uscita col getto.
signal sparata(posizione: Vector3)

enum Stato { NUOTA, TIRATA, RISUCCHIATA, NELLO_ZAINO, IN_VOLO, A_TERRA, SPENTA }

## Passo della griglia con l'altezza del fondo sotto l'acqua (m).
const PASSO := 0.25
## Contro cosa sbattono in volo: mondo, nemici, oggetti (Layers.WORLD | ENEMIES | PROPS).
const MASCHERA := 13

## L'acqua in cui nuotano (una WaterTank dritta, senza rotazioni).
@export var vasca: WaterTank
## Quante sono a piscina piena.
@export var numero := 15
## I colori, uno dopo l'altro.
@export var colori := PackedColorArray([Color(1.0, 0.38, 0.78), Color(0.32, 0.86, 1.0), Color(0.66, 0.48, 1.0),
		Color(0.38, 1.0, 0.72), Color(1.0, 0.78, 0.32), Color(0.36, 0.56, 1.0)])
## Diametro della campana (m) e quanto cambia da una all'altra (frazione).
@export var diametro := 0.09
@export_range(0.0, 0.8) var variazione := 0.3
## Seme del caso: con lo stesso seme partono sempre dagli stessi posti.
@export var seme := 1610

@export_group("Luce")
@export var luminosita := 2.0
@export var luminosita_alone := 1.0
## Diametro dell'alone appena sotto il pelo, da vicino (m): più sono in fondo, più è largo e fioco.
@export var alone := 0.16
## Quanto le attenua l'acqua torbida rispetto al fondo della vasca (1 = uguale, meno = si vedono di più).
@export_range(0.0, 1.0) var attenuazione := 0.4
## Quanto crescono gli aloni visti da lontano (0 = niente): dalla spiaggia restano luci colorate.
@export_range(0.0, 2.0) var lontananza := 1.0

@export_group("Nuoto")
@export var periodo_min := 1.1
@export var periodo_max := 1.8
## Velocità che dà una contrazione (m/s).
@export var spinta := 0.12
@export var resistenza := 1.8
## Quanto affondano tra una spinta e l'altra (m/s²).
@export var affondamento := 0.03
## Quanto in fretta girano la campana (rad/s).
@export var virata := 0.7

@export_group("Aspirazione e getto")
## Entro questa distanza (in pianta) dal punto da cui si aspira la corrente le prende.
@export var raggio_presa := 1.1
## Velocità con cui la corrente le tira (m/s); da lontano un po' di più.
@export var velocita_tirata := 3.0
## Quando resta questa frazione d'acqua sono già state aspirate tutte.
@export_range(0.0, 0.5) var margine_fine := 0.12
## Quanto restano accese a terra (s), poi si spengono.
@export var durata_a_terra := 10.0
## Dopo quanto spariscono se in volo non toccano niente (s).
@export var durata_volo := 5.0


class Medusina:
	var stato := 6
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	## Orientamento: Y è l'asse della campana (verso la cima).
	var base := Basis.IDENTITY
	## Verso dove sta girando la campana.
	var meta := Vector3.UP
	var cambia := false
	var fase := 0.0
	var periodo := 1.4
	var contrazione := 0.0
	var colore := Color.WHITE
	var raggio := 0.045
	var seme := 0.0
	var t := 0.0
	## Nello zaino: esce col getto quando nel serbatoio restano meno litri di così.
	var soglia := 0.0
	var inizio := Vector3.ZERO
	var durata := 0.3
	var spin := Vector3.ZERO
	var rimbalzi := 0
	var luce := 1.0
	var affonda := false
	## Tentacoli trascinati (coordinate locali della campana, raggio = 1).
	var piega := Vector2.ZERO
	var scala := 1.0
	## Disegno: gli ultimi due passi della fisica, interpolati a ogni fotogramma.
	var xf := Transform3D(Basis() * 0.0, Vector3.ZERO)
	var xf_prima := Transform3D(Basis() * 0.0, Vector3.ZERO)
	var alone_xf := Transform3D(Basis() * 0.0, Vector3.ZERO)
	var alone_prima := Transform3D(Basis() * 0.0, Vector3.ZERO)
	var salto := true
	var col := Color(0, 0, 0, 0)
	var col_alone := Color(0, 0, 0, 0)
	var dati := Color(0, 0, 0, 0)


static var _mesh_cache: ArrayMesh

var _medusine: Array[Medusina] = []
var _rng := RandomNumberGenerator.new()
var _griglia := PackedFloat32Array()
var _g_min := Vector2.ZERO
var _g_n := Vector2i.ZERO
var _profondo := Vector2.ZERO
var _corpi: MultiMeshInstance3D
var _aloni: MultiMeshInstance3D
var _da_rifare := false
var _sigma := Vector3(7.1, 6.55, 7.05)
var _sigma_t := 0.0
var _pack: WaterPack
var _attesa := 3


func _ready() -> void:
	add_to_group(&"persist")
	_rng.seed = seme
	_prepara_grafica()


# --- Per i test e gli scatti -------------------------------------------------------------------

## Quante sono nello stato [param s] (Stato).
func quante(s: int) -> int:
	var n := 0
	for m in _medusine:
		if m.stato == s:
			n += 1
	return n


## Quante sono ancora nell'acqua della piscina (che nuotano o tirate dalla corrente).
func in_acqua() -> int:
	return quante(Stato.NUOTA) + quante(Stato.TIRATA)


## Lo stato di ciascuna, in ordine.
func stati() -> PackedInt32Array:
	var a := PackedInt32Array()
	for m in _medusine:
		a.append(m.stato)
	return a


## Dove sono, in ordine.
func posizioni() -> PackedVector3Array:
	var a := PackedVector3Array()
	for m in _medusine:
		a.append(m.pos)
	return a


## Il raggio della campana di ciascuna (m), in ordine.
func raggi() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for m in _medusine:
		a.append(m.raggio)
	return a


## Quanto è contratta la campana di ciascuna (0..1), in ordine.
func contrazioni() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for m in _medusine:
		a.append(m.contrazione)
	return a


## Quota del fondo sotto (x, z), dalla griglia (dopo il primo passo della fisica).
func fondo(x: float, z: float) -> float:
	return _fondo(x, z)


## Quante ne devono restare nell'acqua con il livello di adesso.
func quota() -> int:
	if vasca == null:
		return 0
	var f := clampf((vasca.fill - margine_fine) / maxf(1.0 - margine_fine, 0.001), 0.0, 1.0)
	return int(ceil(float(numero) * f - 0.0001))


## Le rimette nell'acqua com'è adesso (quante ne vuole il livello), dai posti di partenza.
func ricomincia() -> void:
	_da_rifare = true


## (Per gli scatti) Sposta la medusina [param i], se nuota, in [param punto] (in pianta), appena sotto il pelo.
func sposta(i: int, punto: Vector3) -> void:
	if i < 0 or i >= _medusine.size() or _medusine[i].stato != Stato.NUOTA or vasca == null:
		return
	var m := _medusine[i]
	m.pos = Vector3(punto.x, vasca.get_surface_global_y() - m.raggio * 1.6, punto.z)
	m.vel = Vector3.ZERO
	m.salto = true


# --- Checkpoint: dipendono solo dal livello dell'acqua -----------------------------------------

func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	_da_rifare = true


# --- Simulazione -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if vasca == null or not is_inside_tree():
		return
	if _griglia.is_empty():
		# Qualche passo della fisica prima di guardare dov'è il fondo (i corpi della sala devono
		# essere già nello spazio fisico).
		_attesa -= 1
		if _attesa > 0 or not _costruisci_griglia():
			return
		_semina(quota())
	elif _da_rifare:
		_semina(quota())
	_da_rifare = false
	var zaino := _zaino()
	var livello := vasca.get_surface_global_y()
	var vuota := vasca.fill <= 0.001
	var aspira: bool = zaino != null and zaino.is_sucking and zaino.suck_source == vasca and not vuota
	_sigma_t -= delta
	if _sigma_t <= 0.0:
		_sigma_t = 1.0
		_aggiorna_sigma()
	if aspira:
		_prendi(zaino.suck_point)
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	var occhio: Vector3 = cam.global_position if cam else global_position + Vector3(0.0, 2.0, 0.0)
	for m in _medusine:
		m.xf_prima = m.xf
		m.alone_prima = m.alone_xf
		if vuota and m.stato == Stato.NUOTA:
			# La piscina si è svuotata senza aspirarle (non succede giocando): restano all'asciutto.
			_arenata(m)
		match m.stato:
			Stato.NUOTA:
				_nuota(m, delta, livello)
			Stato.TIRATA:
				_tirata(m, delta, livello, zaino, aspira)
			Stato.RISUCCHIATA:
				_risucchiata(m, delta, zaino)
			Stato.NELLO_ZAINO:
				_nello_zaino(m, zaino)
			Stato.IN_VOLO:
				_in_volo(m, delta, zaino)
			Stato.A_TERRA:
				_a_terra(m, delta)
		_prepara_disegno(m, livello, occhio)


func _zaino() -> WaterPack:
	if _pack == null or not is_instance_valid(_pack):
		_pack = null
		var pl := get_tree().get_first_node_in_group(&"player")
		if pl and &"water_pack" in pl:
			_pack = pl.get(&"water_pack") as WaterPack
	return _pack


func _aggiorna_sigma() -> void:
	var piscina := get_parent()
	if piscina and piscina.has_method(&"superficie"):
		var acqua: Node = piscina.call(&"superficie")
		var st: WaterStyle = acqua.get(&"style") as WaterStyle if acqua else null
		if st:
			_sigma = st.absorption + Vector3.ONE * st.turbidity


## La corrente dell'aspirazione: prende quelle vicine al punto da cui si aspira e, se nell'acqua
## ne restano più di quante ne vuole il livello, anche le più vicine fra le altre.
func _prendi(punto: Vector3) -> void:
	var in_acqua_ora := 0
	var tirate := 0
	var libere: Array[Medusina] = []
	for m in _medusine:
		if m.stato == Stato.NUOTA:
			in_acqua_ora += 1
			libere.append(m)
		elif m.stato == Stato.TIRATA:
			in_acqua_ora += 1
			tirate += 1
	if libere.is_empty():
		return
	var da_forzare := in_acqua_ora - quota() - tirate
	var p2 := Vector2(punto.x, punto.z)
	libere.sort_custom(func(a: Medusina, b: Medusina) -> bool:
		return Vector2(a.pos.x, a.pos.z).distance_squared_to(p2) < Vector2(b.pos.x, b.pos.z).distance_squared_to(p2))
	for m in libere:
		if Vector2(m.pos.x, m.pos.z).distance_to(p2) >= raggio_presa and da_forzare <= 0:
			break
		da_forzare -= 1
		m.stato = Stato.TIRATA
		m.t = 0.0


func _nuota(m: Medusina, delta: float, livello: float) -> void:
	m.t += delta
	_pulsa(m, delta, 1.0)
	var r := m.raggio
	var fondo_qui := _fondo(m.pos.x, m.pos.z)
	var prof := livello - fondo_qui
	var alta := livello - m.pos.y < r * 1.2 + 0.03
	var bassa := m.pos.y - fondo_qui < r * 2.5 + 0.03
	if m.cambia:
		m.cambia = false
		m.meta = _nuova_meta(alta, bassa)
	# Dove l'acqua è troppo bassa vanno verso il profondo, lontano dalle pareti della vasca; sotto
	# il pelo si voltano di lato, vicino al fondo tornano su.
	var poca := prof < r * 3.0 + 0.06
	var dentro := _verso_dentro(m.pos)
	if poca:
		var g := _verso_profondo(m.pos)
		m.vel += Vector3(g.x, 0.0, g.y) * 0.4 * delta
		if Vector2(m.meta.x, m.meta.z).dot(g) < 0.3:
			m.meta = Vector3(g.x, 0.25, g.y).normalized()
	elif dentro != Vector2.ZERO:
		m.vel += Vector3(dentro.x, 0.0, dentro.y) * 0.1 * delta
		if Vector2(m.meta.x, m.meta.z).dot(dentro) < 0.2:
			m.meta = Vector3(dentro.x, 0.4, dentro.y).normalized()
	elif alta and bassa:
		if absf(m.meta.y) > 0.35:
			m.meta = _nuova_meta(true, true)
	elif alta and m.meta.y > 0.3:
		m.meta = _nuova_meta(true, false)
	elif bassa and m.meta.y < 0.2:
		m.meta = _nuova_meta(false, true)
	# La spinta della contrazione, lungo l'asse della campana; poi scivola e affonda piano.
	if m.fase < 0.3:
		m.vel += m.base.y.normalized() * spinta * PI / (0.6 * m.periodo) * sin(m.fase / 0.3 * PI) * delta
	m.vel *= exp(-resistenza * delta)
	m.vel.y -= affondamento * delta
	m.pos += m.vel * delta
	var cima := livello - r * 0.9
	var giu := fondo_qui + r * 1.8
	if giu > cima:
		# Acqua bassa: sta dove può, al massimo appoggiata al fondo.
		m.pos.y = clampf(m.pos.y, fondo_qui + r * 0.6, maxf(cima, fondo_qui + r * 0.6))
	elif m.pos.y > cima:
		m.pos.y = cima
		m.vel.y = minf(m.vel.y, 0.0)
	elif m.pos.y < giu:
		m.pos.y = giu
		m.vel.y = maxf(m.vel.y, 0.0)
	_dentro_vasca(m)
	_gira(m, delta, virata)
	_trascina(m, delta, 3.0)


func _tirata(m: Medusina, delta: float, livello: float, zaino: WaterPack, aspira: bool) -> void:
	m.t += delta
	_pulsa(m, delta, 2.2)
	if not aspira:
		if vasca.fill > 0.001:
			m.stato = Stato.NUOTA
			m.meta = Vector3.UP
		elif zaino:
			# L'ultima acqua se n'è andata con loro: finiscono nello zaino.
			_verso_zaino(m, zaino)
		else:
			_arenata(m)
		return
	var punto := zaino.suck_point
	var verso := Vector2(punto.x - m.pos.x, punto.z - m.pos.z)
	var d := verso.length()
	var v := clampf(0.5 + m.t * 1.6, 0.5, velocita_tirata) * (1.0 + clampf(d - 2.0, 0.0, 6.0) * 0.25)
	var dir := verso / maxf(d, 0.001)
	var fondo_qui := _fondo(m.pos.x, m.pos.z)
	var cima := livello - m.raggio * 0.8
	var voluta := Vector3(dir.x * v, (cima - m.pos.y) * 3.0, dir.y * v)
	m.vel = m.vel.lerp(voluta, 1.0 - exp(-4.0 * delta))
	m.pos += m.vel * delta
	m.pos.y = clampf(m.pos.y, fondo_qui + m.raggio * 0.6, maxf(cima, fondo_qui + m.raggio * 0.6))
	_dentro_vasca(m)
	if m.vel.length() > 0.05:
		m.meta = m.vel.normalized()
	_gira(m, delta, 3.0)
	_trascina(m, delta, 3.0)
	var prof := livello - _fondo(m.pos.x, m.pos.z)
	if d < 0.3 or prof < m.raggio * 1.2 or m.t > 7.0:
		_verso_zaino(m, zaino)


func _verso_zaino(m: Medusina, zaino: WaterPack) -> void:
	if zaino == null or zaino.muzzle == null:
		_arenata(m)
		return
	m.stato = Stato.RISUCCHIATA
	m.inizio = m.pos
	m.t = 0.0
	m.durata = clampf(m.pos.distance_to(zaino.muzzle.global_position) / 6.0, 0.25, 1.0)


## Su per il filo d'acqua dell'aspirazione (la stessa curva di SuctionStream), fino all'ugello.
func _risucchiata(m: Medusina, delta: float, zaino: WaterPack) -> void:
	if zaino == null or zaino.muzzle == null:
		_spegni(m)
		return
	m.t += delta
	_pulsa(m, delta, 2.5)
	var b := zaino.muzzle.global_position
	var a := m.inizio
	var mid := a.lerp(b, 0.45) + Vector3(0.0, 0.12 + 0.08 * a.distance_to(b), 0.0)
	var u := clampf(m.t / m.durata, 0.0, 1.0)
	var k := u * u
	var p := (1.0 - k) * (1.0 - k) * a + 2.0 * (1.0 - k) * k * mid + k * k * b
	m.vel = (p - m.pos) / maxf(delta, 0.001)
	m.pos = p
	if m.vel.length() > 0.05:
		m.meta = m.vel.normalized()
	_gira(m, delta, 8.0)
	_trascina(m, delta, 0.3)
	m.scala = 1.0 - 0.6 * smoothstep(0.6, 1.0, u)
	if u >= 1.0:
		m.stato = Stato.NELLO_ZAINO
		m.soglia = _rng.randf_range(0.15, 0.85) * maxf(zaino.tank_amount, 1.0)
		m.scala = 1.0
		aspirata.emit(b)


func _nello_zaino(m: Medusina, zaino: WaterPack) -> void:
	if zaino == null:
		_spegni(m)
	elif zaino.is_spraying and zaino.flow > 0.25 and zaino.tank_amount <= m.soglia:
		_spara(m, zaino)
	elif zaino.tank_amount <= 0.001 and not zaino.is_spraying:
		# Il serbatoio si è vuotato senza sparare (non succede giocando).
		_spegni(m)


## Fuori col getto: parte dall'ugello con l'acqua, un po' più piano e un po' storta.
func _spara(m: Medusina, zaino: WaterPack) -> void:
	var dir := -zaino.get_muzzle_transform().basis.z.normalized()
	var eredita := zaino.player.velocity * zaino.inherit_player_velocity if zaino.player else Vector3.ZERO
	m.stato = Stato.IN_VOLO
	m.t = 0.0
	m.rimbalzi = 0
	m.pos = zaino.muzzle.global_position + dir * 0.05
	m.vel = dir * zaino.jet_speed * maxf(zaino.flow, 0.6) * _rng.randf_range(0.8, 1.0) + eredita
	m.vel += Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * 0.5
	m.base = Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))
	m.spin = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized() \
			* _rng.randf_range(5.0, 11.0)
	m.scala = 1.0
	m.luce = 1.0
	m.affonda = false
	m.salto = true
	sparata.emit(m.pos)


func _in_volo(m: Medusina, delta: float, zaino: WaterPack) -> void:
	m.t += delta
	_pulsa(m, delta, 2.0)
	var prima := m.pos
	m.vel.y -= (zaino.jet_gravity if zaino else 9.8) * delta
	var dopo := prima + m.vel * delta
	var giri := m.spin.length()
	if giri > 0.001:
		m.base = (Basis(m.spin / giri, giri * delta) * m.base).orthonormalized()
	_trascina(m, delta, 0.3)
	# Prima l'acqua, come il getto: la piscina o un'altra vasca.
	var best := 2.0
	var presa: Node = null
	for c in get_tree().get_nodes_in_group(&"water_catchers"):
		if c.has_method(&"surface_hit_fraction"):
			var f: float = c.surface_hit_fraction(prima, dopo)
			if f >= 0.0 and f < best:
				best = f
				presa = c
	var q := PhysicsRayQueryParameters3D.create(prima, dopo, MASCHERA)
	if zaino and zaino.player:
		q.exclude = [zaino.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var f_hit := 2.0
	if not hit.is_empty():
		f_hit = prima.distance_to(hit.position) / maxf(prima.distance_to(dopo), 0.0001)
	if presa and best <= f_hit:
		var punto := prima.lerp(dopo, best)
		m.t = 0.0
		if presa == vasca and vasca.fill > 0.01:
			# Di nuovo nella piscina: ci nuota.
			m.stato = Stato.NUOTA
			m.pos = punto + Vector3(0.0, -m.raggio * 1.5, 0.0)
			m.vel = Vector3(m.vel.x, 0.0, m.vel.z) * 0.05
			m.meta = Vector3.UP
		else:
			m.stato = Stato.A_TERRA
			m.affonda = true
			m.pos = punto
			m.vel = Vector3.ZERO
		return
	if not hit.is_empty():
		var n: Vector3 = hit.normal
		if n.y > 0.5:
			# A terra: appoggiata con la campana in su, girata a caso.
			m.stato = Stato.A_TERRA
			m.affonda = false
			m.t = 0.0
			m.pos = hit.position + n * m.raggio * 0.12
			m.vel = Vector3.ZERO
			m.base = Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, _rng.randf() * TAU)
			return
		# Contro un muro: rimbalza piano e cade.
		m.rimbalzi += 1
		m.pos = hit.position + n * 0.03
		m.vel = m.vel.bounce(n) * 0.25
		if m.rimbalzi > 3:
			_spegni(m)
		return
	m.pos = dopo
	if m.t > durata_volo:
		_spegni(m)


func _a_terra(m: Medusina, delta: float) -> void:
	m.t += delta
	if m.affonda:
		# In un'altra vasca: va giù e sparisce.
		m.pos.y -= 0.08 * delta
		m.luce = 1.0 - clampf(m.t / 1.5, 0.0, 1.0)
		if m.t >= 1.5:
			_spegni(m)
		return
	# Qualche ultima pulsazione, sempre più debole, poi la luce si spegne piano.
	_pulsa(m, delta, 0.5)
	m.contrazione *= maxf(0.0, 1.0 - m.t / (durata_a_terra * 0.5))
	m.luce = 1.0 - smoothstep(durata_a_terra * 0.35, durata_a_terra, m.t)
	m.piega = m.piega.lerp(Vector2.ZERO, 1.0 - exp(-4.0 * delta))
	if m.t >= durata_a_terra:
		_spegni(m)


## Rimasta all'asciutto dove si trova: si spegne come quelle a terra, ma prima.
func _arenata(m: Medusina) -> void:
	m.stato = Stato.A_TERRA
	m.affonda = false
	m.t = durata_a_terra * 0.5
	m.vel = Vector3.ZERO
	m.pos.y = _fondo(m.pos.x, m.pos.z) + m.raggio * 0.12
	m.base = Basis(Vector3.UP, _rng.randf() * TAU)


func _spegni(m: Medusina) -> void:
	m.stato = Stato.SPENTA
	m.luce = 0.0
	m.salto = true


func _pulsa(m: Medusina, delta: float, veloce: float) -> void:
	m.fase += delta * veloce / m.periodo
	if m.fase >= 1.0:
		m.fase -= floorf(m.fase)
		m.periodo = _rng.randf_range(periodo_min, periodo_max)
		m.cambia = _rng.randf() < 0.3
	m.contrazione = contrazione(m.fase)


## La campana durante una pulsazione (0 rilassata, 1 contratta): si chiude in fretta e si
## riapre piano.
static func contrazione(f: float) -> float:
	if f < 0.3:
		return smoothstep(0.0, 0.3, f)
	return 1.0 - smoothstep(0.3, 1.0, f)


func _nuova_meta(alta: bool, bassa: bool) -> Vector3:
	var incl := _rng.randf_range(0.2, 1.0)
	if alta and bassa:
		incl = _rng.randf_range(1.35, 1.75)
	elif alta:
		incl = _rng.randf_range(1.25, 1.9)
	elif bassa:
		incl = _rng.randf_range(0.05, 0.5)
	var az := _rng.randf() * TAU
	return Vector3(sin(incl) * cos(az), cos(incl), sin(incl) * sin(az)).normalized()


## Gira la campana verso [member Medusina.meta], al massimo di [param rate] rad/s, e piano su se stessa.
func _gira(m: Medusina, delta: float, rate: float) -> void:
	var y := m.base.y.normalized()
	var meta := m.meta.normalized()
	var ang := y.angle_to(meta)
	if ang > 0.0001:
		var asse := y.cross(meta)
		if asse.length_squared() < 1e-8:
			asse = m.base.x
		m.base = Basis(asse.normalized(), minf(ang, rate * delta)) * m.base
	m.base = (Basis(m.base.y.normalized(), 0.15 * delta) * m.base).orthonormalized()


## I tentacoli restano indietro rispetto a come si muove di lato.
func _trascina(m: Medusina, delta: float, k: float) -> void:
	var lv := m.base.transposed() * m.vel
	var voluta := (-Vector2(lv.x, lv.z) * k).limit_length(1.6)
	m.piega = m.piega.lerp(voluta, 1.0 - exp(-5.0 * delta))


# --- Dove c'è acqua: la griglia del fondo -------------------------------------------------------

func _costruisci_griglia() -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	var space := world.direct_space_state
	if space == null:
		return false
	var c := vasca.global_position
	var size := Vector2(vasca.inner_size.x, vasca.inner_size.z)
	_g_min = Vector2(c.x, c.z) - size * 0.5
	_g_n = Vector2i(int(ceil(size.x / PASSO)) + 1, int(ceil(size.y / PASSO)) + 1)
	_griglia.resize(_g_n.x * _g_n.y)
	var fondo_vasca := vasca.get_floor_global_y()
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = Layers.WORLD
	var piu_basso := INF
	var punto := func(i: int, j: int) -> Vector2:
		return Vector2(minf(_g_min.x + i * PASSO, _g_min.x + size.x), minf(_g_min.y + j * PASSO, _g_min.y + size.y))
	for j in _g_n.y:
		for i in _g_n.x:
			var xz: Vector2 = punto.call(i, j)
			q.from = Vector3(xz.x, fondo_vasca + vasca.inner_size.y + 0.5, xz.y)
			q.to = Vector3(xz.x, fondo_vasca - 1.0, xz.y)
			var hit := space.intersect_ray(q)
			_griglia[j * _g_n.x + i] = hit.position.y if not hit.is_empty() else -INF
	# la griglia ha passi tondi, come le giunzioni fra i triangoli del fondo: un raggio proprio su una giunzione passa
	# dalla crepa e trova quello che c'è sotto, o niente. Dove un punto non trova niente o sta più di 2 cm sotto i due
	# vicini da parti opposte, lo si rifà col raggio robusto (RaggioSicuro). Tutti col raggio robusto costavano 48 ms
	# in un fotogramma, contro 8
	var alto := _griglia.duplicate()
	for j in _g_n.y:
		for i in _g_n.x:
			var y: float = alto[j * _g_n.x + i]
			var giu := y == -INF
			if i > 0 and i < _g_n.x - 1:
				giu = giu or y < minf(alto[j * _g_n.x + i - 1], alto[j * _g_n.x + i + 1]) - 0.02
			if j > 0 and j < _g_n.y - 1:
				giu = giu or y < minf(alto[(j - 1) * _g_n.x + i], alto[(j + 1) * _g_n.x + i]) - 0.02
			if giu:
				var xz: Vector2 = punto.call(i, j)
				q.from = Vector3(xz.x, fondo_vasca + vasca.inner_size.y + 0.5, xz.y)
				q.to = Vector3(xz.x, fondo_vasca - 1.0, xz.y)
				var hit := RaggioSicuro.interseca(space, q)
				_griglia[j * _g_n.x + i] = hit.position.y if not hit.is_empty() else -INF
	for j in _g_n.y:
		for i in _g_n.x:
			var y := maxf(_griglia[j * _g_n.x + i], fondo_vasca)
			_griglia[j * _g_n.x + i] = y
			if y < piu_basso - 0.001:
				piu_basso = y
				_profondo = punto.call(i, j)
	return true


func _fondo(x: float, z: float) -> float:
	if _griglia.is_empty():
		return vasca.get_floor_global_y() if vasca else 0.0
	var fx := clampf((x - _g_min.x) / PASSO, 0.0, float(_g_n.x - 1) - 0.001)
	var fz := clampf((z - _g_min.y) / PASSO, 0.0, float(_g_n.y - 1) - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := _griglia[j * _g_n.x + i]
	var b := _griglia[j * _g_n.x + i + 1]
	var c := _griglia[(j + 1) * _g_n.x + i]
	var d := _griglia[(j + 1) * _g_n.x + i + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


## In pianta, la direzione in cui il fondo scende (o verso il punto più profondo).
func _verso_profondo(p: Vector3) -> Vector2:
	var e := 0.4
	var g := Vector2(_fondo(p.x - e, p.z) - _fondo(p.x + e, p.z), _fondo(p.x, p.z - e) - _fondo(p.x, p.z + e))
	if g.length() < 0.01:
		g = _profondo - Vector2(p.x, p.z)
	return g.normalized() if g.length() > 0.0001 else Vector2.ZERO


## Se è vicina alle pareti della vasca, la direzione verso il centro (altrimenti zero).
func _verso_dentro(p: Vector3) -> Vector2:
	var v := Vector2.ZERO
	var lo := _g_min + Vector2(0.6, 0.6)
	var hi := _g_min + Vector2(vasca.inner_size.x, vasca.inner_size.z) - Vector2(0.6, 0.6)
	if p.x < lo.x:
		v.x = 1.0
	elif p.x > hi.x:
		v.x = -1.0
	if p.z < lo.y:
		v.y = 1.0
	elif p.z > hi.y:
		v.y = -1.0
	return v.normalized()


func _dentro_vasca(m: Medusina) -> void:
	m.pos.x = clampf(m.pos.x, _g_min.x + 0.15, _g_min.x + vasca.inner_size.x - 0.15)
	m.pos.z = clampf(m.pos.z, _g_min.y + 0.15, _g_min.y + vasca.inner_size.z - 0.15)


func _nella_vasca(p: Vector3) -> bool:
	return p.x >= _g_min.x and p.z >= _g_min.y and p.x <= _g_min.x + vasca.inner_size.x \
		and p.z <= _g_min.y + vasca.inner_size.z


## Mette [param n] medusine nell'acqua, lontane una dall'altra, dove è profonda; le altre spente.
func _semina(n: int) -> void:
	_rng.seed = seme
	while _medusine.size() < numero:
		_medusine.append(Medusina.new())
	var livello := vasca.get_surface_global_y()
	var size := Vector2(vasca.inner_size.x, vasca.inner_size.z)
	var prof_max := livello - _fondo(_profondo.x, _profondo.y)
	var messe: Array[Vector3] = []
	for k in _medusine.size():
		var m := _medusine[k]
		m.colore = colori[k % colori.size()] if colori.size() > 0 else Color.WHITE
		m.raggio = diametro * 0.5 * _rng.randf_range(1.0 - variazione, 1.0 + variazione)
		m.seme = _rng.randf()
		m.periodo = _rng.randf_range(periodo_min, periodo_max)
		m.fase = _rng.randf()
		m.t = 0.0
		m.vel = Vector3.ZERO
		m.piega = Vector2.ZERO
		m.scala = 1.0
		m.luce = 1.0
		m.affonda = false
		m.salto = true
		if k >= n or prof_max <= 0.0:
			m.stato = Stato.SPENTA
			m.luce = 0.0
			continue
		var p := Vector3(_profondo.x, livello - m.raggio * 1.5, _profondo.y)
		for tentativo in 80:
			var x := _rng.randf_range(_g_min.x + 0.5, _g_min.x + size.x - 0.5)
			var z := _rng.randf_range(_g_min.y + 0.5, _g_min.y + size.y - 0.5)
			var prof := livello - _fondo(x, z)
			if prof < minf(0.38, prof_max * 0.6):
				continue
			var lontana := true
			for altra in messe:
				if Vector2(altra.x - x, altra.z - z).length() < 1.1 - tentativo * 0.012:
					lontana = false
					break
			if not lontana:
				continue
			p = Vector3(x, livello - _rng.randf_range(m.raggio * 1.2, minf(0.24, prof * 0.6)), z)
			break
		messe.append(p)
		m.stato = Stato.NUOTA
		m.pos = p
		m.base = Basis.from_euler(Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf() * TAU, _rng.randf_range(-0.5, 0.5)))
		m.meta = m.base.y


# --- Disegno -----------------------------------------------------------------------------------

func _prepara_disegno(m: Medusina, livello: float, occhio: Vector3) -> void:
	if m.stato == Stato.SPENTA or m.stato == Stato.NELLO_ZAINO or m.luce <= 0.001:
		m.xf = Transform3D(Basis() * 0.0, m.pos)
		m.alone_xf = m.xf
		m.col = Color(0, 0, 0, 0)
		m.col_alone = Color(0, 0, 0, 0)
		m.salto = true
	else:
		m.xf = Transform3D(m.base * (m.raggio * m.scala), m.pos)
		# L'acqua torbida le attenua: la campana lungo il cammino della vista fino al pelo,
		# l'alone (luce sparsa intorno) meno.
		var sotto := livello - m.pos.y if _nella_vasca(m.pos) and vasca.fill > 0.001 else 0.0
		var tr := Vector3.ONE
		var tr_alone := Vector3.ONE
		if sotto > 0.0:
			var vd := (m.pos - occhio).normalized()
			var sin_t := Vector2(vd.x, vd.z).length() / 1.333
			var cammino := sotto / sqrt(maxf(1.0 - sin_t * sin_t, 0.05)) * attenuazione
			tr = Vector3(exp(-_sigma.x * cammino), exp(-_sigma.y * cammino), exp(-_sigma.z * cammino))
			var c2 := sotto * attenuazione * 0.45
			tr_alone = Vector3(exp(-_sigma.x * c2), exp(-_sigma.y * c2), exp(-_sigma.z * c2))
		m.col = Color(m.colore.r * tr.x, m.colore.g * tr.y, m.colore.b * tr.z, m.luce)
		# Vicino agli occhi (mentre entra nell'ugello) l'alone si spegne.
		var distanza := m.pos.distance_to(occhio)
		var vicino := smoothstep(0.25, 1.0, distanza)
		# Da lontano (dalla spiaggia) l'alone cresce, così sullo schermo resta una piccola luce colorata
		# anche quando la medusina è troppo piccola per vedersi; da vicino resta piccolo.
		var lontano := smoothstep(1.5, 12.0, distanza) * lontananza
		m.col_alone = Color(m.colore.r * tr_alone.x, m.colore.g * tr_alone.y, m.colore.b * tr_alone.z,
				m.luce * (0.85 + 0.3 * m.contrazione) * vicino * (1.0 + 0.4 * lontano))
		var grande := alone * (1.0 + maxf(sotto, 0.0) * 2.0) * (m.raggio / (diametro * 0.5)) * m.scala * (1.0 + 3.0 * lontano)
		if sotto <= 0.0 and m.stato != Stato.A_TERRA:
			grande *= 0.6
		m.alone_xf = Transform3D(Basis() * grande, m.pos + m.base.y.normalized() * m.raggio * m.scala * 0.25)
	var a_terra := m.stato == Stato.A_TERRA and not m.affonda
	m.dati = Color(m.contrazione, m.piega.x, m.piega.y, m.seme * 0.999 + (2.0 if a_terra else 0.0))
	if m.salto:
		m.xf_prima = m.xf
		m.alone_prima = m.alone_xf
		m.salto = false


func _process(_delta: float) -> void:
	if _corpi == null or _medusine.is_empty():
		return
	var f := Engine.get_physics_interpolation_fraction()
	var mm := _corpi.multimesh
	var ma := _aloni.multimesh
	for i in mini(_medusine.size(), mm.instance_count):
		var m := _medusine[i]
		if m.col.a <= 0.0:
			mm.set_instance_transform(i, m.xf)
			ma.set_instance_transform(i, m.alone_xf)
		else:
			mm.set_instance_transform(i, m.xf_prima.interpolate_with(m.xf, f))
			ma.set_instance_transform(i, m.alone_prima.interpolate_with(m.alone_xf, f))
		mm.set_instance_color(i, m.col)
		mm.set_instance_custom_data(i, m.dati)
		ma.set_instance_color(i, m.col_alone)


func _prepara_grafica() -> void:
	var n := maxi(numero, 1)
	_corpi = _multimesh("Corpi", mesh_medusina(), load("res://shaders/medusine.gdshader"), n, 2)
	(_corpi.material_override as ShaderMaterial).set_shader_parameter(&"luminosita", luminosita)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_aloni = _multimesh("Aloni", quad, load("res://shaders/medusine_alone.gdshader"), n, 1)
	(_aloni.material_override as ShaderMaterial).set_shader_parameter(&"luminosita", luminosita_alone)


func _multimesh(nome: String, mesh: Mesh, shader: Shader, n: int, priorita: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = n
	# Volano in giro per la sala: niente calcolo del riquadro a ogni fotogramma.
	mm.custom_aabb = AABB(Vector3(-40.0, -20.0, -40.0), Vector3(80.0, 45.0, 80.0))
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis() * 0.0, Vector3.ZERO))
		mm.set_instance_color(i, Color(0, 0, 0, 0))
		mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	var mi := MultiMeshInstance3D.new()
	mi.name = nome
	mi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = shader
	# Dopo l'acqua (che scrive la profondità): si vedono attraverso la superficie.
	mat.render_priority = priorita
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.top_level = true
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	return mi


## La mesh di una medusina con la campana di raggio 1: campana a cupola, 12 tentacoli sottili
## dall'orlo e 4 braccia orali in mezzo (nastri incrociati). Vedi shaders/medusine.gdshader.
static func mesh_medusina() -> ArrayMesh:
	if _mesh_cache:
		return _mesh_cache
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ns := 24
	var nr := 8
	for j in nr:
		for i in ns:
			var s0 := float(j) / nr
			var s1 := float(j + 1) / nr
			var a0 := TAU * i / ns
			var a1 := TAU * (i + 1) / ns
			_vertice_campana(st, s0, a0)
			_vertice_campana(st, s0, a1)
			_vertice_campana(st, s1, a1)
			_vertice_campana(st, s0, a0)
			_vertice_campana(st, s1, a1)
			_vertice_campana(st, s1, a0)
	for k in 12:
		var a := TAU * (k + 0.5) / 12.0
		var h := fposmod(sin(k * 12.9898) * 43758.5453, 1.0)
		_filamento(st, Vector3(0.95 * cos(a), -0.1, 0.95 * sin(a)), a, 2.0 * (0.75 + 0.5 * h), 0.045, 0.6, 8, 1.0, float(k) / 12.0)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0 + 0.4
		_filamento(st, Vector3(0.12 * cos(a), 0.05, 0.12 * sin(a)), a, 1.05 + 0.15 * (k % 2), 0.16, 0.65, 6, 2.0, 0.5 + k / 8.0)
	_mesh_cache = st.commit()
	return _mesh_cache


static func _vertice_campana(st: SurfaceTool, s: float, a: float) -> void:
	var fi := s * 1.76
	var n := Vector2(0.62 * sin(fi), cos(fi)).normalized()
	st.set_normal(Vector3(n.x * cos(a), n.y, n.x * sin(a)))
	st.set_uv(Vector2(minf(s, 0.999), 0.0))
	st.set_uv2(Vector2(a / TAU, 0.0))
	st.add_vertex(Vector3(sin(fi) * cos(a), 0.62 * cos(fi), sin(fi) * sin(a)))


## Un tentacolo o un braccio: due nastri incrociati che scendono dall'attacco.
static func _filamento(st: SurfaceTool, radice: Vector3, a: float, lungo: float, largo: float, restringe: float,
		segmenti: int, parte: float, seme_f: float) -> void:
	var radiale := Vector3(cos(a), 0.0, sin(a))
	var tangente := Vector3(-sin(a), 0.0, cos(a))
	var uv2 := Vector2(a / TAU, seme_f)
	for lato: Vector3 in [tangente, radiale]:
		for i in segmenti:
			var t0 := float(i) / segmenti
			var t1 := float(i + 1) / segmenti
			var c0 := radice + Vector3(0.0, -lungo * t0, 0.0)
			var c1 := radice + Vector3(0.0, -lungo * t1, 0.0)
			var w0 := largo * (1.0 - restringe * t0) * 0.5
			var w1 := largo * (1.0 - restringe * t1) * 0.5
			var quad := [[c0 - lato * w0, Vector2(parte, t0)], [c0 + lato * w0, Vector2(parte + 0.98, t0)],
					[c1 + lato * w1, Vector2(parte + 0.98, t1)], [c1 - lato * w1, Vector2(parte, t1)]]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(radiale)
				st.set_uv(quad[idx][1])
				st.set_uv2(uv2)
				st.add_vertex(quad[idx][0])
