extends Node
## Controllo automatico del posizionamento (regola dell'utente del 21 ottobre: "cerca di prestare più
## attenzione alla concretezza e coerenza del posizionamento delle cose, non possiamo tornarci troppe volte").
## Apre ogni zona del gioco ([constant ZONE]) e cerca:
##  a) SOSPESO: oggetti di scena con niente a meno di 5 cm dal loro box (né pavimento, né parete o soffitto, né un
##     altro oggetto o un filo a cui siano attaccati);
##  b) INGOMBRO: mesh visibili, con o senza collisione, a meno di 10 cm dall'asse del giocatore, da 35 cm a 2 m
##     sopra i pavimenti dove passa (le gambe non toccano il mondo), raggiungibili a piedi dai checkpoint; per
##     esempio un tubo davanti alla faccia sulle scale;
##  c) COPRE / COPERTO: oggetti che compenetrano Polaroid, pulsanti, porte, cancelli e oggetti da raccogliere, e
##     quelli che li nascondono a ogni punto di vista vicino all'altezza degli occhi;
##  d) COMPENETRA: oggetti di scena che entrano l'uno nell'altro;
##  e) ESTREMITA_LIBERA: tubi, cavi e condotte (dal nome, mesh allungate) con un capo che non tocca niente (muro,
##     pavimento, soffitto, un altro tubo o un macchinario): la richiesta dell'utente è partita da un tubo davanti alla
##     faccia sulle scale che non si collegava a nulla.
## Ogni caso ha la squadra a cui va (vedi [constant SQUADRE]).
## Le mesh si misurano con la loro forma vera: ogni mesh visibile ha per il controllo una collisione temporanea
## (trimesh) su uno strato suo, anche quelle che nel gioco non ne hanno. I pavimenti e i muri sono quelli del
## gioco (strato WORLD).
## Scrive docs/tecnico/posizionamento/rapporto.md (e rapporto.json) e confronta con le eccezioni in
## tests/posizionamento_eccezioni.json (casi voluti, con il motivo, o già assegnati a una squadra):
## RISULTATO con 0 falliti se non ci sono casi nuovi.
## Le zone che cambiano più avanti nel gioco (gli acquari comparsi e risolti) si controllano anche in quello stato.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/controllo_posizionamento.gd [zona]

## Le zone: la scena e, per le scene grandi, i nodi di primo livello che fanno da sotto-zone.
const ZONE := [
	{"scena": "res://scenes/sala_principale.tscn", "sotto": {"Sala": "sala", "Interni": "interni",
			"Tecnici": "tecnici", "Piscina": "sala", "Vasche": "sala", "Vasca": "sala", "Gioco": "sala",
			"Polaroid": "sala", "LuciSala": "sala", "BambiniBalconata": "sala", "Atmosfera": "sala"}},
	{"scena": "res://scenes/sala/torre/sala_torre.tscn", "zona": "torre"},
	# Le zone che cambiano dopo l'inizio, come le vede il giocatore (riscontro dell'utente sulla v0.3.8: gli
	# acquari davanti al portone "tutto compenetrato o fluttuante"). Si prepara lo stato ([method _prepara]) e
	# si controllano solo le parti elencate; i casi già trovati nello stato iniziale non si ripetono.
	# tutto quello che compare più avanti (le parti nascoste all'inizio, rese visibili)
	{"scena": "res://scenes/sala_principale.tscn", "stato": "tutto_visibile", "sotto": {"Sala": "sala",
			"Interni": "interni", "Tecnici": "tecnici", "Piscina": "sala", "Vasche": "sala", "Vasca": "sala",
			"Gioco": "sala", "Polaroid": "sala", "LuciSala": "sala", "BambiniBalconata": "sala", "Atmosfera": "sala"}},
	{"scena": "res://scenes/sala/torre/sala_torre.tscn", "zona": "torre", "stato": "tutto_visibile"},
	{"scena": "res://scenes/sala_principale.tscn", "zona": "acquari", "stato": "acquari_comparsi",
			"parti": ["Gioco/EnigmaAcquari", "Gioco/PortoneTorre", "Sala/Interattivi/sala_portone_torre"]},
	{"scena": "res://scenes/sala_principale.tscn", "zona": "acquari", "stato": "acquari_risolti",
			"parti": ["Gioco/EnigmaAcquari", "Gioco/PortoneTorre", "Sala/Interattivi/sala_portone_torre"]},
]
const ECCEZIONI := "res://tests/posizionamento_eccezioni.json"
## A che squadra va un caso: il primo prefisso del nodo (o parola nel percorso) che corrisponde, se no la zona.
const SQUADRE := [
	["Mascotte", "mascotte"], ["statua", "mascotte"], ["Jilly", "mascotte"],
	["LuciSala", "grafica"], ["LuciInterni", "grafica"], ["LuciTecnici", "grafica"], ["Luci/", "grafica"],
	["Gioco/EnigmaAcquari", "enigmi"], ["LampadePortone", "enigmi"], ["Tecnici/Ambienti/Raccordo", "enigmi"],
	["ArredoRisalita", "enigmi"],
]
const SQUADRE_ZONA := {"sala": "ambienti-1", "interni": "ambienti-1", "torre": "ambienti-2", "tecnici": "ambienti-2"}   # tecnici: tools/blender/ambienti2_*.py
const NOMI_TUBI := ["tubo", "tubi", "tubaz", "cavo", "cavi", "condott", "pipe", "cable", "filo", "catena", "catene", "chain"]
const STRATO := 1 << 20        # le collisioni temporanee delle mesh
const STRATO_SOLO := 1 << 21   # una mesh alla volta (dentro/fuori)
## Un oggetto di scena: una mesh con la diagonale del box fra questi due valori (m). Più grande è architettura.
const OGGETTO_MIN := 0.04
const OGGETTO_MAX := 4.0
## Controllo severo (processo nuovo approvato dall'utente il 22 ottobre, "per evitare questi errori una volta per
## tutte"): niente esenzione per gli oggetti grandi (solo l'architettura, riconosciuta dal nome, e i pezzi enormi
## sopra OGGETTO_MAX_SEVERO), il controllo "staccato" a pochi millimetri, le compenetrazioni anche fra oggetti della
## stessa scena .tscn e con gli spigoli, le parti nascoste rese visibili, la CI rossa con un solo caso da correggere.
const SEVERO := true
const OGGETTO_MAX_SEVERO := 30.0
## Architettura (pavimenti, muri, soffitti, strutture dei modelli d'ambiente): non è un oggetto da appoggiare.
const ARCHITETTURA := ["architettura", "struttura", "pavimento", "pavimenti", "muro", "muri", "parete", "pareti",
	"soffitto", "cupola"]
## Staccato: ogni oggetto deve toccare entro tanto (m) qualcosa che lo regge.
const STACCO := 0.005
## Quanti vertici per oggetto si provano per lo staccato.
const STACCO_VERTICI := 48
## Nelle zone con stato (poche parti, guardate da vicino) anche le cose grandi sono oggetti: le pedane, le ringhiere,
## gli acquari (riscontro dell'utente: lì sotto i 4 m il controllo non vedeva niente).
const OGGETTO_MAX_PARTI := 15.0
## Nelle zone con stato: uno spigolo che passa dentro un altro oggetto per più di tanto (m) è una compenetrazione.
const ATTRAVERSA_MIN := 0.03
const CONTATTO := 0.05
const PASSO_GRIGLIA := 0.25
const TESTA_DA := 0.35
const TESTA_A := 2.0
const GRADINO := 0.4
const OCCHI := 1.6

var _passed := 0
var _failed := 0
var _trovati: Array = []        # {zona, nodo, problema, pos, dettaglio}
var _corpi := {}                # RID del corpo temporaneo -> MeshInstance3D
var _corpo_di := {}             # MeshInstance3D -> StaticBody3D
var _acqua := {}                # MeshInstance3D delle superfici dell'acqua
var _semi: Array[Vector3] = []   # da dove parte il riempimento (vedi _controlla_scena)
var _q_corpo: PhysicsShapeQueryParameters3D   # il cilindro del giocatore (vedi _libero)
var _spazio: PhysicsDirectSpaceState3D
var _radice: Node
var _oggetto_max := OGGETTO_MAX
## Nelle zone con stato il controllo delle compenetrazioni è più fino (vedi _compenetrazioni).
var _fino := false
## Le parti nascoste all'inizio rese visibili dallo stato "tutto_visibile" (per non contare come compenetrate fra loro
## le due versioni della stessa cosa, per esempio le lampade Spente e Accese).
var _nascoste_radici := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# ripetibile: le cose che oscillano o sfarfallano usano il caso e il tempo (con --fixed-fps 60)
	seed(20261022)
	var solo := OS.get_cmdline_user_args().slice(1)
	for z in ZONE:
		var nome_scena := String(z["scena"]).get_file().get_basename()
		if not solo.is_empty() and not solo.has(nome_scena) and not solo.has(z.get("zona", "")):
			continue
		await _controlla_scena(z)
	_confronta()
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- una scena ------------------------------------------------------------------------------------------

func _controlla_scena(z: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	print("Scena %s" % z["scena"])
	_radice = (load(z["scena"]) as PackedScene).instantiate()
	get_tree().root.add_child(_radice)
	# i punti da cui parte il riempimento delle celle, subito, prima che qualcosa si muova: solo punti fissi
	# (checkpoint, i loro punti di ripartenza, il giocatore dove comincia), niente bambini o altri corpi che
	# camminano (con loro i casi cambiavano da un giro all'altro)
	_semi.clear()
	for cp in _radice.find_children("*", "Checkpoint", true, false):
		_semi.append((cp as Node3D).global_position)
		var sp = cp.get(&"spawn_point")
		if sp is Node3D:
			_semi.append((sp as Node3D).global_position)
	for g in _radice.find_children("*", "Player", true, false):
		_semi.append((g as Node3D).global_position)
	_oggetto_max = OGGETTO_MAX_SEVERO if SEVERO else (OGGETTO_MAX_PARTI if z.has("parti") else OGGETTO_MAX)
	_fino = SEVERO or z.has("parti")
	_nascoste_radici.clear()
	if z.has("stato"):
		await _prepara(String(z["stato"]))
	for i in 20:
		await get_tree().physics_frame
	# poi ferma, come la lasciano gli script dopo l'ingresso (niente animazioni durante il controllo); i corpi
	# fisici restano attivi (un corpo fermo si toglie dallo spazio fisico)
	_radice.process_mode = Node.PROCESS_MODE_DISABLED
	for c in _radice.find_children("*", "CollisionObject3D", true, false):
		(c as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 3:
		await get_tree().physics_frame
	_spazio = (_radice as Node3D).get_world_3d().direct_space_state if _radice is Node3D else get_viewport().get_world_3d().direct_space_state
	var mesh := _mesh_visibili()
	print("  %d mesh visibili" % mesh.size())
	_elenca_nascoste()
	_crea_corpi(mesh)
	for i in 3:
		await get_tree().physics_frame
	var oggetti := mesh.filter(func(mi): return _e_oggetto(mi))
	print("  %d oggetti di scena" % oggetti.size())
	var prima := _trovati.size()
	for mi in oggetti:
		_sospeso(z, mi)
	print("  a) sospesi: %d" % (_trovati.size() - prima))
	if SEVERO:
		prima = _trovati.size()
		for mi in oggetti:
			_staccato(z, mi)
		print("  a2) staccati (niente entro %d mm): %d" % [roundi(STACCO * 1000.0), _trovati.size() - prima])
	prima = _trovati.size()
	_ingombri(z, mesh)
	print("  b) ingombri nello spazio di chi cammina: %d" % (_trovati.size() - prima))
	prima = _trovati.size()
	_interattivi(z)
	print("  c) interattivi coperti o compenetrati: %d" % (_trovati.size() - prima))
	prima = _trovati.size()
	_compenetrazioni(z, oggetti)
	print("  d) compenetrazioni fra oggetti: %d" % (_trovati.size() - prima))
	prima = _trovati.size()
	for mi in mesh:
		_estremita(z, mi)
	print("  e) tubi e cavi con un capo libero: %d" % (_trovati.size() - prima))
	print("  (%.0f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_radice.queue_free()
	_corpi.clear()
	_corpo_di.clear()
	_acqua.clear()
	for i in 5:
		await get_tree().process_frame


## Mette la zona nello stato in cui la vede il giocatore più avanti nel gioco.
##  acquari_comparsi: rientrato dal magazzino (tappa 7), gli acquari pieni e le lampade del portone accese;
##  acquari_risolti: il verde giusto, il portone della torre aperto fino in fondo.
func _prepara(stato: String) -> void:
	print("  stato: %s" % stato)
	if stato == "tutto_visibile":
		# tutto quello che compare più avanti (nascosto all'inizio), luci a parte
		for n in _radice.find_children("*", "Node3D", true, false):
			if not (n as Node3D).visible and not n is Light3D:
				_nascoste_radici[n] = true
				(n as Node3D).visible = true
		print("  parti nascoste rese visibili: %d" % _nascoste_radici.size())
		return
	var enigma := _radice.find_child("EnigmaAcquari", true, false)
	if enigma == null:
		push_warning("controllo: EnigmaAcquari non trovato per lo stato %s" % stato)
		return
	match stato:
		"acquari_comparsi":
			var serranda = enigma.get(&"serranda")
			if serranda:
				serranda.set(&"aperta", true)
		"acquari_risolti":
			enigma.set(&"stato", EnigmaAcquari.Stato.RISOLTO)
			var portone = enigma.get(&"portone")
			if portone and portone.has_method(&"apri"):
				portone.call(&"apri")
				for i in 900:
					if bool(portone.call(&"is_aperto")) and not bool(portone.get(&"in_movimento")):
						break
					await get_tree().physics_frame
	for i in 10:
		await get_tree().physics_frame
	print("  acquari comparsi: %s, stato %s" % [enigma.get(&"comparsi"), enigma.get(&"stato")])


## Le mesh visibili della scena, senza il giocatore, le creature e le gocce che cadono (si muovono); le superfici
## dell'acqua a parte.
func _mesh_visibili() -> Array:
	var out := []
	var esclusi := []
	for n in _radice.find_children("*", "CharacterBody3D", true, false) + _radice.find_children("*", "RigidBody3D", true, false):
		esclusi.append(n)
	for n in get_tree().get_nodes_in_group(&"bambini"):
		esclusi.append(n)
	for n in _radice.find_children("*", "Gocce", true, false):
		esclusi.append(n)   # le gocce che cadono dal soffitto: in volo, non sono messe male
	for n in _radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not _visibile(mi) or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if esclusi.any(func(e): return (e as Node).is_ancestor_of(mi)):
			continue
		var percorso := String(_radice.get_path_to(mi)).to_lower()
		if percorso.begins_with("acqua") or percorso.contains("/acqua") or String(mi.name).to_lower() in ["superficie", "surface"]:
			_acqua[mi] = true   # le superfici dell'acqua reggono quello che galleggia, ma non sono oggetti
		out.append(mi)
	return out


## Le parti nascoste all'inizio (che compaiono più avanti nel gioco): il controllo non le guarda, a meno di una zona
## con stato che le mostri. Le stampa raggruppate per il primo nodo nascosto, con quante mesh hanno sotto.
func _elenca_nascoste() -> void:
	var gruppi := {}
	for n in _radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or _visibile(mi):
			continue
		# il nodo nascosto più in alto
		var k: Node = mi
		var nascosto: Node = null
		while k and k != _radice:
			if k is Node3D and not (k as Node3D).visible and not k is Light3D:
				nascosto = k
			k = k.get_parent()
		if nascosto:
			var nome := String(_radice.get_path_to(nascosto))
			gruppi[nome] = int(gruppi.get(nome, 0)) + 1
	if gruppi.is_empty():
		return
	var nomi := gruppi.keys()
	nomi.sort()
	print("  nascoste all'inizio (non controllate): %d parti, %d mesh" % [nomi.size(), gruppi.values().reduce(func(x, y): return x + y, 0)])
	for nome in nomi:
		print("    NASCOSTA %s · %d mesh" % [nome, gruppi[nome]])


## Visibile, senza contare le luci sopra la mesh: quelle che sfarfallano si accendono e spengono a caso (LookSala),
## e il controllo deve dare lo stesso risultato a ogni giro.
func _visibile(n: Node) -> bool:
	while n and n != _radice.get_parent():
		if n is Node3D and not (n as Node3D).visible and not n is Light3D:
			return false
		n = n.get_parent()
	return true


func _crea_corpi(mesh: Array) -> void:
	var cont := Node3D.new()
	cont.name = "ControlloCorpi"
	cont.process_mode = Node.PROCESS_MODE_ALWAYS
	_radice.add_child(cont)
	for mi in mesh:
		# i triangoli già nel mondo: un corpo fisico non si scala (con la scala della mesh il corpo verrebbe
		# della grandezza sbagliata)
		var facce: PackedVector3Array = (mi as MeshInstance3D).mesh.get_faces()
		if facce.is_empty():
			continue
		var forma := ConcavePolygonShape3D.new()
		forma.set_faces((mi as MeshInstance3D).global_transform * facce)
		forma.backface_collision = true
		var c := StaticBody3D.new()
		c.collision_layer = STRATO
		c.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = forma
		c.add_child(cs)
		cont.add_child(c)
		_corpi[c.get_rid()] = mi
		_corpo_di[mi] = c


func _box(mi: MeshInstance3D) -> AABB:
	return mi.global_transform * mi.get_aabb()


func _e_oggetto(mi: MeshInstance3D) -> bool:
	if _acqua.has(mi):
		return false
	var d := _box(mi).size.length()
	if d <= OGGETTO_MIN or d >= _oggetto_max:
		return false
	if SEVERO:
		var percorso := String(_radice.get_path_to(mi)).to_lower()
		if ARCHITETTURA.any(func(a): return percorso.contains(a)):
			return false
	return true


func _zona(z: Dictionary, n: Node) -> String:
	if z.has("zona"):
		return z["zona"]
	var p := _radice.get_path_to(n)
	return String((z["sotto"] as Dictionary).get(String(p.get_name(0)), String(p.get_name(0)).to_lower()))


static func _squadra(zona: String, nodo: String) -> String:
	for r in SQUADRE:
		if nodo.begins_with(r[0]) or nodo.contains("/" + r[0]):
			return r[1]
	return SQUADRE_ZONA.get(zona, "da assegnare")


func _nodo(n: Node) -> String:
	return String(_radice.get_path_to(n))


func _trova(z: Dictionary, n: Node, problema: String, pos: Vector3, dettaglio: String) -> void:
	if z.has("stato"):
		var nodo := _nodo(n)
		if z.has("parti") and not (z["parti"] as Array).any(func(p): return nodo.begins_with(p)):
			return
		# già trovato nello stato iniziale (stesso nodo, stesso problema): non si ripete
		if _trovati.any(func(t): return t["nodo"] == nodo and t["problema"] == problema):
			return
		dettaglio += " (stato: %s)" % z["stato"]
	var k := {"zona": _zona(z, n), "nodo": _nodo(n), "squadra": _squadra(_zona(z, n), _nodo(n)), "problema": problema,
			"pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)], "dettaglio": dettaglio}
	_trovati.append(k)


func _raggio(da: Vector3, a: Vector3, maschera: int, esclusi: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(da, a, maschera, esclusi)
	q.hit_back_faces = true
	q.hit_from_inside = false
	return _spazio.intersect_ray(q)


# --- a) sospesi ----------------------------------------------------------------------------------------

func _sospeso(z: Dictionary, mi: MeshInstance3D) -> void:
	var b := _box(mi)
	var me: Array[RID] = []
	if _corpo_di.has(mi):
		me.append((_corpo_di[mi] as StaticBody3D).get_rid())
	# qualunque cosa a meno di 5 cm dal suo box (pavimento, parete, soffitto, un altro oggetto, un filo)
	var forma := BoxShape3D.new()
	forma.size = b.size + Vector3.ONE * CONTATTO * 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis(), b.get_center())
	q.collision_mask = STRATO | Layers.WORLD
	q.exclude = me
	if not _spazio.intersect_shape(q, 1).is_empty():
		return
	var c := b.get_center()
	var giu := _raggio(Vector3(c.x, b.position.y, c.z), Vector3(c.x, b.position.y - 5.0, c.z), STRATO | Layers.WORLD, me)
	var vuoto := "più di 5 m" if giu.is_empty() else "%.2f m" % (b.position.y - (giu.position as Vector3).y)
	_trova(z, mi, "sospeso", c, "niente a meno di 5 cm (sotto, il primo appoggio è a %s)" % vuoto)


## Staccato: l'oggetto deve toccare, entro STACCO, qualcosa che lo regge (pavimento, muro, soffitto, l'oggetto a cui è
## attaccato). Per un campione di vertici, raggi corti nelle sei direzioni: basta che uno colpisca un altro corpo.
## Gli oggetti già "sospesi" (niente entro 5 cm) non si ripetono.
func _staccato(z: Dictionary, mi: MeshInstance3D) -> void:
	if _trovati.any(func(t): return t["nodo"] == _nodo(mi) and t["problema"] == "sospeso"):
		return
	var facce := mi.mesh.get_faces()
	if facce.is_empty():
		return
	var me: Array[RID] = []
	if _corpo_di.has(mi):
		me.append((_corpo_di[mi] as StaticBody3D).get_rid())
	var passo := maxi(1, facce.size() / STACCO_VERTICI)
	var dirs := [Vector3.DOWN, Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var i := 0
	while i < facce.size():
		var p := mi.global_transform * facce[i]
		for d in dirs:
			if not _raggio(p - d * 0.001, p + d * STACCO, STRATO | Layers.WORLD, me).is_empty():
				return
		i += passo
	var b := _box(mi)
	var c := b.get_center()
	var giu := _raggio(Vector3(c.x, b.position.y, c.z), Vector3(c.x, b.position.y - 5.0, c.z), STRATO | Layers.WORLD, me)
	var vuoto := "più di 5 m" if giu.is_empty() else "%.1f cm" % ((b.position.y - (giu.position as Vector3).y) * 100.0)
	_trova(z, mi, "staccato", c, "non tocca niente entro %d mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a %s)" % [
			roundi(STACCO * 1000.0), vuoto])


# --- b) ingombri nello spazio di chi cammina -----------------------------------------------------------

func _ingombri(z: Dictionary, mesh: Array) -> void:
	var limiti := AABB()
	var primo := true
	for mi in mesh:
		var b := _box(mi)
		if b.size.length() > 300.0:
			continue
		limiti = b if primo else limiti.merge(b)
		primo = false
	# la griglia ancorata al mondo (multipli di PASSO_GRIGLIA), non all'angolo della scena: se la scena si allarga
	# le celle restano dove sono, e i casi vicino agli oggetti non cambiano da un branch all'altro
	var angolo := Vector3(floorf(limiti.position.x / PASSO_GRIGLIA), limiti.position.y, floorf(limiti.position.z / PASSO_GRIGLIA))
	angolo.x *= PASSO_GRIGLIA
	angolo.z *= PASSO_GRIGLIA
	limiti = AABB(angolo, limiti.end - angolo)
	var cil := CylinderShape3D.new()
	cil.radius = 0.3
	cil.height = 0.7
	_q_corpo = PhysicsShapeQueryParameters3D.new()
	_q_corpo.shape = cil
	_q_corpo.collision_mask = Layers.WORLD | Layers.BARRIERS   # anche i muri invisibili fermano il giocatore
	# i pavimenti: per ogni colonna della griglia tutti i piani calpestabili, dall'alto in basso
	var celle := {}   # Vector3i(ix, piano, iz) -> y
	var nx := int(limiti.size.x / PASSO_GRIGLIA) + 1
	var nz := int(limiti.size.z / PASSO_GRIGLIA) + 1
	var colonne := {}  # Vector2i -> Array di y
	for ix in nx:
		for iz in nz:
			var x := limiti.position.x + ix * PASSO_GRIGLIA
			var zz := limiti.position.z + iz * PASSO_GRIGLIA
			var y := limiti.end.y + 1.0
			var piani := []
			for k in 8:
				var h := _raggio(Vector3(x, y, zz), Vector3(x, limiti.position.y - 1.0, zz), Layers.WORLD)
				if h.is_empty():
					break
				var hp: Vector3 = h.position
				if (h.normal as Vector3).y >= 0.7:
					piani.append(hp.y)
				y = hp.y - 0.05
			if not piani.is_empty():
				colonne[Vector2i(ix, iz)] = piani
	# raggiungibili a piedi dai punti fissi (_semi), con gradini fino a GRADINO
	var semi := _semi
	var coda: Array[Vector3i] = []
	var raggiunte := {}
	for s in semi:
		var c := Vector2i(roundi((s.x - limiti.position.x) / PASSO_GRIGLIA), roundi((s.z - limiti.position.z) / PASSO_GRIGLIA))
		if not colonne.has(c):
			continue
		var piani: Array = colonne[c]
		var migliore := -1
		for i in piani.size():
			if absf(float(piani[i]) - s.y) < 0.6 and (migliore < 0 or absf(float(piani[i]) - s.y) < absf(float(piani[migliore]) - s.y)):
				migliore = i
		if migliore >= 0 and _libero(c, float(piani[migliore]), limiti):
			var k := Vector3i(c.x, migliore, c.y)
			if not raggiunte.has(k):
				raggiunte[k] = true
				coda.append(k)
	while not coda.is_empty():
		var k: Vector3i = coda.pop_back()
		var y: float = colonne[Vector2i(k.x, k.z)][k.y]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c := Vector2i(k.x + d.x, k.z + d.y)
			if not colonne.has(c):
				continue
			var piani: Array = colonne[c]
			for i in piani.size():
				var y2 := float(piani[i])
				if absf(y2 - y) > GRADINO:
					continue
				var k2 := Vector3i(c.x, i, c.y)
				if raggiunte.has(k2) or not _libero(c, y2, limiti):
					continue
				raggiunte[k2] = true
				coda.append(k2)
	print("  %d celle raggiungibili a piedi" % raggiunte.size())
	# nello spazio sopra ogni cella, a meno di 10 cm dall'asse del giocatore: tutto quello che si vede (anche con la collisione)
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.2, TESTA_A - TESTA_DA, 0.2)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.collide_with_areas = false
	var visti := {}
	for k in raggiunte:
		var y: float = colonne[Vector2i(k.x, k.z)][k.y]
		var centro := Vector3(limiti.position.x + k.x * PASSO_GRIGLIA, y + (TESTA_DA + TESTA_A) * 0.5, limiti.position.z + k.z * PASSO_GRIGLIA)
		q.transform = Transform3D(Basis(), centro)
		q.collision_mask = STRATO
		var r := _spazio.intersect_shape(q, 16)
		var solido := false
		if not r.is_empty():
			q.collision_mask = Layers.WORLD | Layers.BARRIERS
			solido = not _spazio.intersect_shape(q, 1).is_empty()
		for h in r:
			var mi: MeshInstance3D = _corpi.get((h.collider as CollisionObject3D).get_rid())
			if mi == null or _acqua.has(mi):
				continue
			if not visti.has(mi):
				visti[mi] = [centro - Vector3(0, (TESTA_DA + TESTA_A) * 0.5, 0), 0, 9.0, 0.0, false]
			visti[mi][1] += 1
			visti[mi][4] = visti[mi][4] or solido
			# fin dove arriva sopra il pavimento (le gambe o la testa)
			var bb := _box(mi)
			var pav: float = centro.y - (TESTA_DA + TESTA_A) * 0.5
			visti[mi][2] = minf(visti[mi][2], maxf(bb.position.y - pav, TESTA_DA))
			visti[mi][3] = maxf(visti[mi][3], minf(bb.end.y - pav, TESTA_A))
	for mi in visti:
		var p: Vector3 = visti[mi][0]
		var alto: float = visti[mi][3]
		var dove := "all'altezza della testa" if alto > 1.4 else ("all'altezza del busto" if alto > 0.9 else "all'altezza delle gambe")
		_trova(z, mi, "ingombro", p, "nello spazio di chi cammina, %s: a meno di 10 cm dal giocatore, fra %.2f e %.2f m sopra il pavimento (%d celle da 25 cm), %s" % [
				dove, visti[mi][2], alto, visti[mi][1],
				"con la collisione (ci si sbatte contro)" if visti[mi][4] else "senza collisione (si attraversa)"])


## Una cella dove passa il giocatore: ci entrano le sue gambe (un cilindro di raggio 30 cm fra 0,3 e 1 m sopra il
## pavimento) senza toccare niente del mondo. Più in alto conta tutto quello che si vede, anche con la collisione
## (un tubo a 1,7 m sopra una scala è un difetto anche se ci si sbatte contro).
func _libero(c: Vector2i, y: float, limiti: AABB) -> bool:
	var x := limiti.position.x + c.x * PASSO_GRIGLIA
	var zz := limiti.position.z + c.y * PASSO_GRIGLIA
	_q_corpo.transform = Transform3D(Basis(), Vector3(x, y + 0.3 + 0.35, zz))
	return _spazio.intersect_shape(_q_corpo, 1).is_empty()


# --- c) interattivi ------------------------------------------------------------------------------------

func _e_interattivo(n: Node) -> bool:
	return n is PolaroidPhoto or n is Pickup or n is PackPickup or n is Collectible or n is WaterButton \
			or n is PoweredDoor or n is HingedHatch or n is PortoneTorre or n is Interactable


func _interattivi(z: Dictionary) -> void:
	for n in _radice.find_children("*", "Node3D", true, false):
		if not _e_interattivo(n):
			continue
		# un interattivo dentro un altro (l'Interactable di una porta) conta una volta sola
		var dentro := false
		var p := n.get_parent()
		while p and p != _radice:
			if _e_interattivo(p):
				dentro = true
				break
			p = p.get_parent()
		if dentro:
			continue
		var proprie := n.find_children("*", "MeshInstance3D", true, false).filter(func(m): return _corpo_di.has(m))
		if proprie.is_empty():
			continue
		var box := _box(proprie[0])
		for m in proprie:
			box = box.merge(_box(m))
		var esclusi: Array[RID] = []
		for m in proprie:
			esclusi.append((_corpo_di[m] as StaticBody3D).get_rid())
		for c in (n as Node).find_children("*", "CollisionObject3D", true, false):
			esclusi.append((c as CollisionObject3D).get_rid())
		var esclusi_vista := esclusi.duplicate()   # l'acqua si vede attraverso
		for a in _acqua:
			if _corpo_di.has(a):
				esclusi_vista.append((_corpo_di[a] as StaticBody3D).get_rid())
		# compenetrato da un oggetto di scena (non l'architettura, non i suoi pezzi)
		var forma := BoxShape3D.new()
		forma.size = box.size * 0.7
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma
		q.transform = Transform3D(Basis(), box.get_center())
		q.collision_mask = STRATO
		q.exclude = esclusi
		var gia := {}
		for h in _spazio.intersect_shape(q, 8):
			var altro: MeshInstance3D = _corpi.get((h.collider as CollisionObject3D).get_rid())
			if altro and _e_oggetto(altro) and not gia.has(altro):
				gia[altro] = true
				_trova(z, n, "compenetrato", box.get_center(), "entra dentro %s" % _nodo(altro))
		# coperto: da nessun punto di vista vicino, all'altezza degli occhi, si vede il suo centro
		var punti := 0
		var visti := 0
		var ostacoli := {}
		var distanza := 99.0
		var bersaglio := box.get_center()
		for dist in [1.0, 1.8]:
			for i in 8:
				var v: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0) * dist
				var sopra: Vector3 = bersaglio + v + Vector3(0, 0.5, 0)   # (non sopra il soffitto)
				var pav := _raggio(sopra, sopra - Vector3(0, 6.0, 0), Layers.WORLD)
				if pav.is_empty() or (pav.normal as Vector3).y < 0.7:
					continue
				var occhio: Vector3 = pav.position + Vector3(0, OCCHI, 0)
				if not _raggio(pav.position + Vector3(0, 0.3, 0), occhio, Layers.WORLD).is_empty():
					continue
				punti += 1
				# contano solo le mesh visibili (le collisioni del mondo non si vedono); il centro o la cima
				# visibile se il raggio arriva al centro o appena sopra la cima senza toccare niente (anche un foglio
				# appoggiato sopra lo copre)
				var h := _raggio(occhio, bersaglio, STRATO, esclusi_vista)
				if not h.is_empty():
					var h2 := _raggio(occhio, Vector3(bersaglio.x, box.end.y + 0.002, bersaglio.z), STRATO, esclusi_vista)
					if h2.is_empty():
						h = h2
				if h.is_empty():
					visti += 1
				else:
					var chi: Node = _corpi.get((h.collider as CollisionObject3D).get_rid(), h.collider)
					ostacoli[_nodo(chi)] = int(ostacoli.get(_nodo(chi), 0)) + 1
					distanza = minf(distanza, (h.position as Vector3).distance_to(bersaglio))
		if punti > 0 and visti == 0:
			var nomi := ostacoli.keys()
			nomi.sort_custom(func(a, b): return ostacoli[a] > ostacoli[b])
			_trova(z, n, "coperto", bersaglio, "non si vede da nessuno dei %d punti di vista vicini (1-1,8 m, altezza degli occhi); lo coprono: %s (la superficie più vicina è a %.0f cm dal suo centro)" % [
					punti, ", ".join(nomi.slice(0, 3)), distanza * 100.0])


# --- e) tubi e cavi con un capo libero ---------------------------------------------------------------

func _estremita(z: Dictionary, mi: MeshInstance3D) -> void:
	if _acqua.has(mi):
		return
	var nome := String(mi.name).to_lower()
	if not NOMI_TUBI.any(func(t): return nome.contains(t)):
		return
	var b := _box(mi)
	var lati := [b.size.x, b.size.y, b.size.z]
	var asse := lati.find(lati.max())
	var ordinati := lati.duplicate()
	ordinati.sort()
	# un pezzo solo e allungato (le mesh con tanti tubi insieme non si controllano così)
	if float(ordinati[2]) < 0.4 or float(ordinati[2]) < 3.0 * float(ordinati[1]):
		return
	var v := mi.global_transform * mi.mesh.get_faces()
	var lo := INF
	var hi := -INF
	for p in v:
		lo = minf(lo, p[asse])
		hi = maxf(hi, p[asse])
	var me: Array[RID] = []
	if _corpo_di.has(mi):
		me.append((_corpo_di[mi] as StaticBody3D).get_rid())
	for capo in [lo, hi]:
		var box := AABB()
		var primo := true
		for p in v:
			if absf(p[asse] - capo) <= 0.08:
				box = AABB(p, Vector3.ZERO) if primo else box.expand(p)
				primo = false
		var forma := BoxShape3D.new()
		# severo: il capo deve essere collegato (1 cm), non solo vicino a qualcosa
		forma.size = box.size + Vector3.ONE * (0.01 if SEVERO else CONTATTO) * 2.0
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma
		q.transform = Transform3D(Basis(), box.get_center())
		q.collision_mask = STRATO | Layers.WORLD
		q.exclude = me
		if _spazio.intersect_shape(q, 1).is_empty():
			_trova(z, mi, "estremita_libera", box.get_center(), "un capo del %s non è collegato a niente entro %s (né muro, pavimento, soffitto, né un altro tubo o un macchinario)" % [
					"catena" if nome.contains("caten") or nome.contains("chain") else ("tubo" if not nome.contains("cav")
					and not nome.contains("filo") and not nome.contains("cable") else "cavo"), "1 cm" if SEVERO else "5 cm"])


# --- d) compenetrazioni fra oggetti di scena -----------------------------------------------------------

func _compenetrazioni(z: Dictionary, oggetti: Array) -> void:
	var boxes := {}
	for mi in oggetti:
		boxes[mi] = _box(mi)
	# a celle di 2 m per non confrontare tutte le coppie
	var celle := {}
	for mi in oggetti:
		var bx: AABB = boxes[mi]
		if _fino:
			# in tutte le celle che il box tocca: un corrimano lungo 6 m ha il centro lontano dalla valvola che
			# attraversa
			var da := Vector3i((bx.position / 2.0).floor())
			var a_ := Vector3i((bx.end / 2.0).floor())
			for x in range(da.x, a_.x + 1):
				for y in range(da.y, a_.y + 1):
					for zz in range(da.z, a_.z + 1):
						celle.get_or_add(Vector3i(x, y, zz), []).append(mi)
		else:
			celle.get_or_add(Vector3i(bx.get_center() / 2.0), []).append(mi)
	var fatte := {}
	for c in celle:
		var vicini := []
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					vicini.append_array(celle.get(c + Vector3i(dx, dy, dz), []))
		for a in celle[c]:
			for b in vicini:
				if a == b or fatte.has([b, a]) or fatte.has([a, b]):
					continue
				fatte[[a, b]] = true
				if _stesso_modello(a, b) or (a as Node).get_parent() == (b as Node).get_parent():
					continue   # pezzi dello stesso modello, o dello stesso oggetto fatto da codice (lampade, fari)
				if _alternative(a, b):
					continue   # due versioni della stessa cosa (una nascosta all'inizio): non si vedono insieme
				var ba: AABB = boxes[a]
				var bb: AABB = boxes[b]
				var i := ba.intersection(bb)
				if i.size == Vector3.ZERO:
					continue
				if _fino:
					# una sbarra che passa dentro un oggetto senza avere vertici dentro: gli spigoli che lo attraversano
					var p := _attraversa(a, b)
					if p > ATTRAVERSA_MIN:
						var chi: MeshInstance3D = a if ba.get_volume() <= bb.get_volume() else b
						var altro: MeshInstance3D = b if chi == a else a
						_trova(z, chi, "compenetra", i.get_center(), "passa dentro %s per %d cm" % [_nodo(altro), roundi(p * 100.0)])
						continue
				var piccolo := minf(ba.get_volume(), bb.get_volume())
				if piccolo <= 0.0 or i.get_volume() < 0.3 * piccolo:
					continue
				var dentro := _frazione_dentro(a, b)
				if dentro >= 0.2:
					var chi: MeshInstance3D = a if ba.get_volume() <= bb.get_volume() else b
					var altro: MeshInstance3D = b if chi == a else a
					_trova(z, chi, "compenetra", i.get_center(), "il %d%% dei suoi vertici è dentro %s" % [roundi(dentro * 100.0), _nodo(altro)])


## Vero se una delle due sta sotto una parte nascosta all'inizio che è sorella di un antenato dell'altra (o dell'altra
## parte nascosta): le lampade Spente e Accese, i vetri puliti e impolverati.
func _alternative(a: Node, b: Node) -> bool:
	if _nascoste_radici.is_empty():
		return false
	var ra := _radice_nascosta(a)
	var rb := _radice_nascosta(b)
	if ra == rb:
		return false
	for coppia in [[ra, b], [rb, a]]:
		var r: Node = coppia[0]
		if r == null:
			continue
		var k: Node = coppia[1]
		while k and k != _radice:
			if k.get_parent() == r.get_parent() and k != r:
				return true
			k = k.get_parent()
	return false


func _radice_nascosta(n: Node) -> Node:
	var trovata: Node = null
	var k := n
	while k and k != _radice:
		if _nascoste_radici.has(k):
			trovata = k
		k = k.get_parent()
	return trovata


## Due mesh dello stesso modello importato (.glb, .gltf): i suoi pezzi si toccano per costruzione. Nelle zone con
## stato solo questo: gli oggetti di una scena .tscn hanno tutti lo stesso owner (la radice della scena), ma sono
## oggetti diversi messi a mano (gli acquari: la valvola nella ringhiera della pedana non si vedeva).
func _stesso_modello(a: Node, b: Node) -> bool:
	if a.owner == null or a.owner != b.owner:
		return false
	if not _fino:
		return true
	var f := a.owner.scene_file_path.get_extension().to_lower()
	return f == "glb" or f == "gltf"


## Quanto (m) gli spigoli di una mesh passano dentro l'altra, il massimo fra le due direzioni: per ogni spigolo
## (un campione) un raggio dall'inizio alla fine e uno dalla fine all'inizio contro l'altra; se colpiscono tutti e
## due, il tratto fra i due punti colpiti è dentro (gli spigoli che toccano solo la superficie non contano).
func _attraversa(a: MeshInstance3D, b: MeshInstance3D) -> float:
	return maxf(_spigoli_dentro(a, b), _spigoli_dentro(b, a))


func _spigoli_dentro(a: MeshInstance3D, b: MeshInstance3D) -> float:
	if not _corpo_di.has(b):
		return 0.0
	var facce := a.mesh.get_faces()
	if facce.is_empty():
		return 0.0
	var corpo := _corpo_di[b] as StaticBody3D
	corpo.collision_layer = STRATO_SOLO
	var tri := facce.size() / 3
	var passo := maxi(1, tri / 80)
	var massimo := 0.0
	var centro := _box(a).get_center()
	var t := 0
	while t < tri:
		for e in 3:
			var p0 := a.global_transform * facce[t * 3 + e]
			var p1 := a.global_transform * facce[t * 3 + (e + 1) % 3]
			# 5 mm verso il centro dell'oggetto: uno spigolo appoggiato su una superficie (una scatola su uno
			# scaffale) non la deve sfiorare
			p0 += (centro - p0).normalized() * 0.005
			p1 += (centro - p1).normalized() * 0.005
			var l := p0.distance_to(p1)
			if l < 0.03:
				continue
			var d := (p1 - p0) / l
			var h0 := _raggio(p0 + d * 0.005, p1 - d * 0.005, STRATO_SOLO)
			if h0.is_empty():
				continue
			var h1 := _raggio(p1 - d * 0.005, p0 + d * 0.005, STRATO_SOLO)
			if h1.is_empty():
				continue
			massimo = maxf(massimo, (h0.position as Vector3).distance_to(h1.position))
		t += passo
	corpo.collision_layer = STRATO
	return massimo


## Quanti vertici della mesh più piccola fra a e b stanno dentro l'altra (raggi verso l'alto: dispari = dentro).
func _frazione_dentro(a: MeshInstance3D, b: MeshInstance3D) -> float:
	var piccola := a if _box(a).get_volume() <= _box(b).get_volume() else b
	var grande := b if piccola == a else a
	if not _corpo_di.has(grande):
		return 0.0
	var corpo := _corpo_di[grande] as StaticBody3D
	var vertici := piccola.mesh.get_faces()
	if vertici.is_empty():
		return 0.0
	var passo := maxi(1, vertici.size() / 30)
	corpo.collision_layer = STRATO_SOLO
	var dentro := 0
	var tot := 0
	var i := 0
	while i < vertici.size():
		var p := piccola.global_transform * vertici[i]
		var n := 0
		var da := p
		for k in 16:
			var h := _raggio(da, da + Vector3(0, 50, 0), STRATO_SOLO)
			if h.is_empty():
				break
			n += 1
			da = (h.position as Vector3) + Vector3(0, 0.001, 0)
		tot += 1
		if n % 2 == 1:
			dentro += 1
		i += passo
	corpo.collision_layer = STRATO
	return float(dentro) / maxf(tot, 1)


# --- rapporto e eccezioni ------------------------------------------------------------------------------

## La chiave di un caso: zona, nodo e problema; i nodi fatti da codice hanno nomi automatici (@MeshInstance3D@217)
## che cambiano: per loro conta il tipo e la posizione arrotondata a mezzo metro.
static func chiave_caso(e: Dictionary) -> String:
	var nodo := String(e["nodo"])
	var re := RegEx.create_from_string("@([A-Za-z0-9]+)@[0-9]+")
	var k := "%s|%s|%s" % [e["zona"], re.sub(nodo, "@$1", true), e["problema"]]
	if nodo.contains("@"):
		var p: Array = e["pos"]
		k += "|%s,%s,%s" % [snappedf(float(p[0]), 0.5), snappedf(float(p[1]), 0.5), snappedf(float(p[2]), 0.5)]
	return k


func _confronta() -> void:
	var eccezioni: Array = []
	if FileAccess.file_exists(ECCEZIONI):
		eccezioni = JSON.parse_string(FileAccess.get_file_as_string(ECCEZIONI))
	var note := {}
	for e in eccezioni:
		note[chiave_caso(e)] = e
	var nuovi := []
	var noti := []
	var trovate := {}
	for t in _trovati:
		var k: String = chiave_caso(t)
		trovate[k] = true
		if note.has(k):
			t["stato"] = note[k].get("stato", "")
			t["motivo"] = note[k].get("motivo", "")
			noti.append(t)
		else:
			nuovi.append(t)
	var spariti := eccezioni.filter(func(e): return not trovate.has(chiave_caso(e)))
	_scrivi_rapporto(nuovi, noti, spariti)
	check(nuovi.is_empty(), "nessun caso nuovo di posizionamento (%d nuovi, %d già noti, %d eccezioni non più trovate)" % [
			nuovi.size(), noti.size(), spariti.size()])
	if SEVERO:
		var da_fare := noti.filter(func(t): return t.get("stato", "") != "voluto")
		check(da_fare.is_empty(), "nessun caso da correggere (%d da correggere; passano solo i casi \"voluto\", decisi dall'utente)" % da_fare.size())
	for t in nuovi.slice(0, 40):
		print("    NUOVO %s · %s · %s · %s · %s" % [t["zona"], t["problema"], t["nodo"], str(t["pos"]), t["dettaglio"]])


func _scrivi_rapporto(nuovi: Array, noti: Array, spariti: Array) -> void:
	var cartella := ProjectSettings.globalize_path("res://").path_join("../docs/tecnico/posizionamento").simplify_path()
	DirAccess.make_dir_recursive_absolute(cartella)
	var testo := "# Controllo di posizionamento\n\n"
	testo += "Scritto da `godot/tests/controllo_posizionamento.gd` il %s. Problemi: **sospeso** (niente a meno di 5 cm: né sotto, né una parete, un soffitto o un altro oggetto a cui sia attaccato), **ingombro** (qualcosa di visibile, con o senza collisione, a meno di 10 cm dall'asse del giocatore, fra %.2f e %.2f m sopra il pavimento), **compenetrato** e **coperto** (Polaroid, pulsanti, porte, cancelli, oggetti da raccogliere), **compenetra** (due oggetti di scena l'uno dentro l'altro), **estremita_libera** (un tubo o un cavo con un capo che non tocca niente). Come si usa: `LEGGIMI.md` qui accanto.\n\n" % [
			Time.get_datetime_string_from_system(false, true), TESTA_DA, TESTA_A]
	testo += "Nuovi: %d. Già noti (in `godot/tests/posizionamento_eccezioni.json`): %d. Eccezioni non più trovate: %d.\n\n" % [nuovi.size(), noti.size(), spariti.size()]
	for sezione in [["Nuovi", nuovi], ["Già noti", noti]]:
		var righe: Array = sezione[1]
		if righe.is_empty():
			continue
		testo += "## %s\n\n" % sezione[0]
		var zone := {}
		for t in righe:
			zone.get_or_add(t["zona"], []).append(t)
		var nomi := zone.keys()
		nomi.sort()
		for zn in nomi:
			testo += "### %s\n\n| Squadra | Problema | Nodo | Posizione | Dettaglio |%s\n|---|---|---|---|---|%s\n" % [zn,
					" Stato |" if sezione[0] != "Nuovi" else "", "---|" if sezione[0] != "Nuovi" else ""]
			var lista: Array = zone[zn]
			lista.sort_custom(func(a, b): return String(a["problema"]) + String(a["nodo"]) < String(b["problema"]) + String(b["nodo"]))
			for t in lista:
				testo += "| %s | %s | `%s` | %s | %s |%s\n" % [t["squadra"], t["problema"], t["nodo"], "%.2f, %.2f, %.2f" % t["pos"], t["dettaglio"],
						(" %s: %s |" % [t.get("stato", ""), t.get("motivo", "")]) if sezione[0] != "Nuovi" else ""]
			testo += "\n"
	if not spariti.is_empty():
		testo += "## Eccezioni non più trovate (si possono togliere dal file)\n\n"
		for e in spariti:
			testo += "- %s · %s · `%s`\n" % [e["zona"], e["problema"], e["nodo"]]
	var f := FileAccess.open(cartella.path_join("rapporto.md"), FileAccess.WRITE)
	f.store_string(testo)
	f.close()
	f = FileAccess.open(cartella.path_join("rapporto.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(nuovi + noti, "\t"))
	f.close()
	print("rapporto: %s" % cartella.path_join("rapporto.md"))


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)
