class_name VarianteLuci
extends Node
## Le luci bianche al 40% (provate come variante nella v0.3.9; scelta dell'utente del 23 ottobre: "le luci a 40%
## vanno bene quindi via la scelta e restano così"): tutte le luci bianche e
## bianco-calde più deboli di [member fattore]; le rosse e le altre colorate (verdi delle uscite e del lettore,
## rosa e viola di Jilly, blu) restano com'erano. Con le luci scendono l'emissione dei materiali bianchi delle
## lampade (lampadine, neon, plafoniere) e l'energia del VoxelGI cotto.
##
## Il fattore si applica solo per il disegno: appena prima di disegnare un fotogramma
## (RenderingServer.frame_pre_draw) l'energia diventa base × fattore, subito dopo (frame_post_draw) torna la
## base. Così gli script che scrivono o leggono light_energy ed emission_energy_multiplier (sfarfallio, flash,
## luci_risveglio, bava_rosa, neon, il menu...) lavorano sempre sui valori pieni e il fattore resta su tutto
## quello che si vede, anche sulle luci che cambiano da sole.
##
## Il fattore viene dall'impostazione di progetto gioco/luci_bianche (0,4) ed è fisso: niente tasto, niente scelta.
## Gli strumenti che vogliono le luci piene (confronti, misure) usano imposta(1.0). Con fattore 1 non fa niente.

signal fattore_cambiato(fattore: float)

## Il fattore di serie (gioco/luci_bianche).
const FATTORE_VARIANTE := 0.4
const IMPOSTAZIONE := "gioco/luci_bianche"
## Una luce è bianca se la sua saturazione è al più SAT_BIANCA; bianco-calda se la tinta è fra arancio e giallo
## (TINTA_CALDA, in giri di ruota) e la saturazione al più SAT_CALDA (le lampadine a incandescenza, le lampade da
## lavoro). Le altre (rosse, verdi, rosa, viola, blu) sono colorate.
const SAT_BIANCA := 0.30
const SAT_CALDA := 0.76
const TINTA_CALDA := Vector2(0.045, 0.17)
## Emissione: i materiali con l'emissione accesa (almeno questa energia) e di colore bianco o bianco-caldo, solo
## delle lampade vere (vedi _lampada).
const EMISSIONE_MINIMA := 0.3
## Jilly, le creature, le statue e gli oggetti di gioco (indizi, Polaroid, keycard, lettori, pulsanti, schermi)
## restano com'erano, luci comprese: un nodo con un antenato che ha questi pezzi nel nome (minuscolo), o che è un
## Interactable o una Polaroid.
const ESCLUSI := ["medusa", "jilly_", "bambin", "agnello", "squalo", "mostro", "statua", "polpo", "creatur",
	"polaroid", "keycard", "tessera", "lettore", "pulsante", "schermo", "monitor", "crt", "negatoscopio", "geyser"]
## Non sono lampade ma scendono anche loro (l'utente: "il disegno sull'acquario abbassalo pure").
const ANCHE := ["disegno_carta"]
## Una lampada: mesh o materiale con uno di questi pezzi nel nome, o una mesh piccola (al più LAMPADA_MAX m) vicina a una
## Light3D (la luce è sua figlia o sorella, o figlia di uno dei due antenati sopra).
const NOMI_LAMPADA := ["lamp", "neon", "plafon", "globo", "bulb", "applique", "faro", "fanale", "lantern", "luce",
	"light", "bulbo", "tubo_t8", "insegna_lumin", "cartello_lumin"]
const LAMPADA_MAX := 2.5
## Un nome con un colore vince sulla tinta: il neon giallo delle insegne è un'insegna colorata, non una lampada bianca.
const NOMI_COLORATI := ["giallo", "gialla", "rosa", "rosso", "rossa", "verde", "azzurr", "blu", "viola", "arancio"]

## Il fattore delle luci bianche adesso (1 = piene).
var fattore := 1.0

var _luci: Array[Light3D] = []
var _materiali: Array[BaseMaterial3D] = []
var _gi: Array[VoxelGIData] = []
var _visti := {}                    # oggetti già raccolti (instance id -> true)
var _base_luci: Array = []          # [Light3D, energia] applicate in questo fotogramma
var _base_materiali: Array = []     # [BaseMaterial3D, emissione]
var _base_gi: Array = []            # [VoxelGIData, energia]
var _collegato := false
var _geometrie: Array[GeometryInstance3D] = []   # per rileggere i materiali (cambiano anche senza nodi nuovi)
var _prossima := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	imposta(float(ProjectSettings.get_setting(IMPOSTAZIONE, FATTORE_VARIANTE)))


## Cambia il fattore. Con 1 smette di toccare le luci (e rimette le basi).
func imposta(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	if is_equal_approx(f, fattore) and (_collegato == (f < 1.0)):
		return
	fattore = f
	var attivo := fattore < 1.0
	if attivo and not _collegato:
		_collegato = true
		RenderingServer.frame_pre_draw.connect(applica)
		RenderingServer.frame_post_draw.connect(ripristina)
		get_tree().node_added.connect(_su_nodo)
		_raccogli(get_tree().root)
	elif not attivo and _collegato:
		_collegato = false
		ripristina()
		RenderingServer.frame_pre_draw.disconnect(applica)
		RenderingServer.frame_post_draw.disconnect(ripristina)
		get_tree().node_added.disconnect(_su_nodo)
	fattore_cambiato.emit(fattore)


func _process(_delta: float) -> void:
	if not _collegato:
		return
	# i materiali cambiano anche senza nodi nuovi (una lampada spenta e riaccesa, un material_override, una
	# lampada accesa dopo): si rileggono 300 geometrie per fotogramma, a giro
	var n := mini(300, _geometrie.size())
	for k in n:
		_prossima = (_prossima + 1) % _geometrie.size()
		var g := _geometrie[_prossima]
		if is_instance_valid(g):
			_materiali_di(g)


## Prima del disegno: le bianche a base × fattore.
func applica() -> void:
	if not _base_luci.is_empty() or not _base_materiali.is_empty() or not _base_gi.is_empty():
		ripristina()
	for i in range(_luci.size() - 1, -1, -1):
		var l := _luci[i]
		if not is_instance_valid(l):
			_luci.remove_at(i)
			continue
		if not is_bianca(l.light_color) or _esclusa(l) or _nome_colorato(l.name):
			continue
		_base_luci.append([l, l.light_energy])
		l.light_energy *= fattore
	for i in range(_materiali.size() - 1, -1, -1):
		var m := _materiali[i]
		if m == null:
			_materiali.remove_at(i)
			continue
		if not m.emission_enabled or not is_bianca(m.emission):
			continue
		_base_materiali.append([m, m.emission_energy_multiplier])
		m.emission_energy_multiplier *= fattore
	for d in _gi:
		if d:
			_base_gi.append([d, d.energy])
			d.energy *= fattore


## Dopo il disegno: le basi (gli script trovano sempre i loro valori).
func ripristina() -> void:
	for b in _base_luci:
		if is_instance_valid(b[0]):
			(b[0] as Light3D).light_energy = b[1]
	for b in _base_materiali:
		if b[0]:
			(b[0] as BaseMaterial3D).emission_energy_multiplier = b[1]
	for b in _base_gi:
		if b[0]:
			(b[0] as VoxelGIData).energy = b[1]
	_base_luci.clear()
	_base_materiali.clear()
	_base_gi.clear()


## Bianca o bianco-calda (vedi SAT_BIANCA, SAT_CALDA, TINTA_CALDA).
static func is_bianca(c: Color) -> bool:
	if c.s <= SAT_BIANCA:
		return true
	return c.h >= TINTA_CALDA.x and c.h <= TINTA_CALDA.y and c.s <= SAT_CALDA


func _su_nodo(n: Node) -> void:
	# dopo il _ready del nodo: molti creano i loro materiali lì. Passa l'id e non il nodo: un nodo liberato prima
	# della chiamata darebbe un errore nella coda dei messaggi ("Cannot convert argument 1 from Object to Object")
	_raccogli_id.call_deferred(n.get_instance_id())


func _raccogli_id(id: int) -> void:
	_raccogli(instance_from_id(id) as Node)


func _raccogli(radice: Node) -> void:
	if radice == null or not is_instance_valid(radice):
		return
	var nodi: Array[Node] = [radice]
	nodi.append_array(radice.find_children("*", "", true, false))
	for n in nodi:
		if n is Light3D:
			_aggiungi(_luci, n)
		elif n is GeometryInstance3D:
			if not _visti.has(n.get_instance_id()):
				_visti[n.get_instance_id()] = true
				_geometrie.append(n)
			_materiali_di(n)
		elif n is VoxelGI:
			var d := (n as VoxelGI).data
			if d and not _visti.has(d.get_instance_id()):
				_visti[d.get_instance_id()] = true
				_gi.append(d)


func _materiali_di(g: GeometryInstance3D) -> void:
	if _esclusa(g):
		return
	var mats: Array = [g.material_override, g.material_overlay]
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				mats.append(mi.get_surface_override_material(s))
				mats.append(mi.mesh.surface_get_material(s))
	var di_lampada := -1          # -1: non ancora guardato (si guarda solo se c'è un materiale che si accende)
	for m in mats:
		var b := m as BaseMaterial3D
		if b == null or _visti.has(b.get_instance_id()):
			continue
		if not b.emission_enabled or b.emission_energy_multiplier < EMISSIONE_MINIMA:
			continue
		if di_lampada < 0:
			di_lampada = 1 if _lampada(g) else 0
		if _nome_colorato(b.resource_name):
			continue
		if di_lampada == 1 or _nome_da_lampada(b.resource_name) or _anche(b.resource_name) or _anche(g.name):
			_visti[b.get_instance_id()] = true
			_materiali.append(b)


var _esclusi_cache := {}


## Jilly, una creatura, una statua o un oggetto di gioco (vedi ESCLUSI)?
func _esclusa(n: Node) -> bool:
	var id := n.get_instance_id()
	if _esclusi_cache.has(id):
		return _esclusi_cache[id]
	var r := false
	var p: Node = n
	while p and p != get_tree().root:
		if p is Interactable or p is PolaroidPhoto:
			r = true
			break
		var nome := String(p.name).to_lower()
		if nome == "lei" or nome.begins_with("lei_") or nome == "leisbuca":
			r = true
			break
		for parola in ESCLUSI:
			if nome.contains(parola):
				r = true
				break
		if r:
			break
		p = p.get_parent()
	_esclusi_cache[id] = r
	return r


static func _anche(nome: String) -> bool:
	nome = nome.to_lower()
	for parola in ANCHE:
		if nome.contains(parola):
			return true
	return false


static func _nome_colorato(nome: String) -> bool:
	nome = nome.to_lower()
	for parola in NOMI_COLORATI:
		if nome.contains(parola):
			return true
	return false


static func _nome_da_lampada(nome: String) -> bool:
	nome = nome.to_lower()
	for parola in NOMI_LAMPADA:
		if nome.contains(parola):
			return true
	return false


## Una lampada vera: il nome della mesh (o dei due antenati sopra) da lampada, o una mesh piccola vicino a una Light3D.
func _lampada(g: GeometryInstance3D) -> bool:
	var p: Node = g
	for k in 3:
		if p == null:
			break
		if _nome_da_lampada(String(p.name)):
			return true
		p = p.get_parent()
	if g.get_aabb().size.length() * g.global_basis.get_scale().length() / sqrt(3.0) > LAMPADA_MAX:
		return false
	p = g
	for k in 3:
		if p == null:
			break
		if p is Light3D:
			return true
		for c in p.get_children():
			if c is Light3D:
				return true
		p = p.get_parent()
	return false


func _aggiungi(lista: Array, o: Object) -> void:
	if not _visti.has(o.get_instance_id()):
		_visti[o.get_instance_id()] = true
		lista.append(o)


## Per i test e per l'elenco: le luci raccolte, divise in bianche e colorate.
func luci_raccolte() -> Array:
	return _luci.filter(func(l): return is_instance_valid(l))


func materiali_raccolti() -> Array:
	return _materiali.duplicate()


func gi_raccolti() -> Array:
	return _gi.duplicate()
