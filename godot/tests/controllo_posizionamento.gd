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
	# gli stati indicati dalle squadre (22 ottobre): quello che cambia più avanti nel gioco
	{"scena": "res://scenes/sala_principale.tscn", "zona": "interni", "stato": "interni_dopo", "parti": ["Interni"]},
	{"scena": "res://scenes/sala_principale.tscn", "zona": "sala", "stato": "lei_fossa", "parti": ["Gioco/LeiSbuca"]},
	# le stanze della Risalita si disegnano solo col giocatore vicino (risalita_gioco.gd): nei due stati si mostrano,
	# come quando ci arriva (enigmi non risolti) e dopo (risolti)
	{"scena": "res://scenes/sala_principale.tscn", "zona": "risalita", "stato": "risalita_arrivo", "parti": ["Risalita"]},
	{"scena": "res://scenes/sala_principale.tscn", "zona": "risalita", "stato": "risalita_dopo", "parti": ["Risalita"]},
	# la tappa 7 (il ritorno): le porte col maniglione (sala pompe, ponte) e il portello sul fondo della piscina aperti
	# (coordinatore, 22 ottobre; collaudo: la porta della sala pompe aperta sporgeva sulla strada del ritorno). Senza
	# "zona": ogni caso prende la zona del giro iniziale
	{"scena": "res://scenes/sala_principale.tscn", "stato": "tappa7", "parti": ["Interni/Ambienti/Corridoio/porta_sala_pompe",
			"Tecnici/Ambienti/SalaPompe/PORTA_ponte", "Sala/Interattivi/sala_portello_scarico"]},
	{"scena": "res://scenes/sala/torre/sala_torre.tscn", "zona": "torre", "stato": "inseguimento_dopo",
			"parti": ["SalaInseguimento"]},
	{"scena": "res://scenes/sala_principale.tscn", "zona": "acquari", "stato": "acquari_comparsi",
			"parti": ["Gioco/EnigmaAcquari", "Gioco/PortoneTorre", "Sala/Interattivi/sala_portone_torre"]},
	{"scena": "res://scenes/sala_principale.tscn", "zona": "acquari", "stato": "acquari_risolti",
			"parti": ["Gioco/EnigmaAcquari", "Gioco/PortoneTorre", "Sala/Interattivi/sala_portone_torre"]},
]
const ECCEZIONI := "res://tests/posizionamento_eccezioni.json"
## A che squadra va un caso: il primo prefisso del nodo (o parola nel percorso) che corrisponde, se no la zona.
const SQUADRE := [
	["Mascotte", "mascotte"], ["statua", "mascotte"], ["Jilly", "mascotte"], ["Medusa", "mascotte"],
	["SalaInseguimento", "ambienti-2"],   # sala_inseguimento.gd mette anche i dettagli sotto il suo nodo Luci
	["LuciSala", "grafica"], ["LuciInterni", "grafica"], ["LuciTecnici", "grafica"], ["Luci/", "grafica"],
	["Sala/Dettagli", "ambienti-2"],   # il kit dei dettagli (dettagli_sala.gd)
	["Gioco/EnigmaAcquari", "enigmi"], ["LampadePortone", "enigmi"], ["Tecnici/Ambienti/Raccordo", "enigmi"],
	["ArredoRisalita", "enigmi"],
]
const SQUADRE_ZONA := {"sala": "ambienti-1", "interni": "ambienti-1", "torre": "ambienti-2", "tecnici": "ambienti-2",
	"risalita": "enigmi", "mascotte": "mascotte", "acquari": "enigmi"}   # tecnici: tools/blender/ambienti2_*.py
## Effetti a tempo (schizzi, getti, vapore, particelle): durano pochi secondi e si sovrappongono per natura, non sono
## oggetti di scena (riscontro di ambienti-1 sul controllo severo). Si riconoscono dalle parole del nome di un nodo
## del percorso o della classe del suo script: una parola che comincia con una di queste (vedi _parole). Non basta
## "contiene": "oggetti" contiene "getti", e tutto Sala/Oggetti restava fuori come uno schizzo (collaudo, 23 ottobre).
const EFFETTI := ["schizz", "vapore", "getto", "getti", "spruzz", "nebbia", "particell", "gocce", "bolle",
	"drip"]   # drip: le gocce che cadono dalle dita della medusa (WaterDripEmitter), si vedono solo mentre cadono
## Solo nella classe dello script, non nei nomi (nei nomi può essere l'insegna o il logo del parco).
const EFFETTI_CLASSE := ["splash"]
const NOMI_TUBI := ["tubo", "tubi", "tubaz", "cavo", "cavi", "condott", "pipe", "cable", "filo", "catena", "catene", "chain",
	"asta", "aste", "corda", "corde", "fune", "funi", "rope", "gancio", "ganci"]
## Il capo di un tubo, un cavo, un'asta... deve stare a meno di questo da una superficie vera (o infilato in un pieno).
const CAPO := 0.005
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
## La CI rossa anche con un solo caso "da correggere" (non solo con i casi nuovi): si accende per ultimo, quando le
## squadre hanno i loro elenchi (accordo col coordinatore del 22 ottobre).
const BLOCCA_DA_CORREGGERE := true
const OGGETTO_MAX_SEVERO := 30.0
## Architettura (pavimenti, muri, soffitti, strutture dei modelli d'ambiente): non è un oggetto da appoggiare.
const ARCHITETTURA := ["architettura", "struttura", "pavimento", "pavimenti", "muro", "muri", "parete", "pareti",
	"soffitto", "cupola"]
## Staccato: ogni oggetto deve toccare entro tanto (m) qualcosa che lo regge.
const STACCO := 0.005
## Sotto questa misura (diagonale del box, m) un oggetto si misura anche con la distanza vera fra le mesh, non solo con
## la forma convessa (vedi _contatto_vero); oltre, solo se ha un appoggio solo.
const PICCOLO := 0.4
const VERTICI_VERI := 300
const VERTICI_TUTTI := 3000
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
## All'altezza della testa (da TESTA_LARGA_DA a TESTA_A) l'ingombro si cerca fino a TESTA_LARGA dall'asse, non 10 cm.
const TESTA_LARGA_DA := 1.2
const TESTA_LARGA := 0.2
## Dove si sta accovacciati per forza, lo spazio libero arriva fin qui (crouch_height del giocatore, player.gd).
const ACCOVACCIATO := 1.05
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
## La copertura, per il rapporto: per ogni giro (zona e stato) quanti oggetti si sono controllati in ogni parte; per
## ogni scena le parti nascoste nel giro iniziale e i percorsi visti in tutti i giri (vedi _segna_copertura).
var _copertura: Array = []
var _nascoste_ora := {}
var _tocca := {}
var _punto_dentro := Vector3.ZERO   # dove _spigoli_dentro ha trovato il tratto più lungo nel pieno
var _staccati_veri := {}   # oggetto -> le mesh che la forma convessa toccava ma la mesh vera no
var _sferetta: PhysicsShapeQueryParameters3D
var _box_nascoste: Array[AABB] = []   # le mesh nascoste in questo giro (vedi _gruppi_staccati)
var _multimesh_senza: Array[String] = []   # MultiMesh senza le trasformazioni: non controllati (vedi _espandi_multimesh)           # MeshInstance3D -> le mesh che tocca (vedi _segna_tocchi)
var _nascoste_base := {}   # scena -> {percorso del nodo nascosto: mesh}
var _visti := {}           # scena -> {percorso di una mesh controllata: true}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# ripetibile: le cose che oscillano o sfarfallano usano il caso e il tempo (con --fixed-fps 60)
	seed(20261022)
	# le stanze della Risalita sempre caricate (nascoste col giocatore lontano), come prima del 23 ottobre: nel giro
	# iniziale il corridoio della zona del personale poggia su di loro, e lì si guarda nel giro che le mostra
	Engine.set_meta(&"risalita_subito", true)
	var solo := OS.get_cmdline_user_args().slice(1)
	# una scena da sola (res://...tscn) come argomento: la si controlla come una zona sua (per le prove)
	for arg in solo:
		if String(arg).begins_with("res://"):
			await _controlla_scena({"scena": arg, "zona": String(arg).get_file().get_basename()})
			_confronta()
			print("")
			print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
			get_tree().quit(1 if _failed > 0 else 0)
			return
	for z in ZONE:
		var nome_scena := String(z["scena"]).get_file().get_basename()
		if not solo.is_empty() and not solo.has(nome_scena) and not solo.has(z.get("zona", "")) and not solo.has(z.get("stato", "")):
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
		# quello che lo stato fa comparire: nascosto prima, visibile dopo (per le varianti, vedi _alternative)
		var prima_nascosti := _radice.find_children("*", "Node3D", true, false).filter(func(n): return not (n as Node3D).visible and not n is Light3D)
		await _prepara(String(z["stato"]))
		for n in prima_nascosti:
			if is_instance_valid(n) and (n as Node3D).visible:
				_nascoste_radici[n] = true
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
	_espandi_multimesh()
	await _congela_scheletri()
	var mesh := _mesh_visibili()
	print("  %d mesh visibili" % mesh.size())
	_elenca_nascoste()
	_crea_corpi(mesh)
	for i in 3:
		await get_tree().physics_frame
	var oggetti := mesh.filter(func(mi): return _e_oggetto(mi))
	print("  %d oggetti di scena" % oggetti.size())
	_segna_copertura(z, mesh, oggetti)
	var prima := _trovati.size()
	for mi in oggetti:
		_sospeso(z, mi)
	print("  a) sospesi: %d" % (_trovati.size() - prima))
	if SEVERO:
		prima = _trovati.size()
		_tocca.clear()
		_staccati_veri.clear()
		for mi in oggetti:
			_staccato(z, mi)
		_gruppi_staccati(z, oggetti)
		print("  a2) staccati (niente entro %d mm): %d" % [roundi(STACCO * 1000.0), _trovati.size() - prima])
	prima = _trovati.size()
	_ingombri(z, mesh)
	print("  b) ingombri nello spazio di chi cammina: %d" % (_trovati.size() - prima))
	prima = _trovati.size()
	_interattivi(z)
	print("  c) interattivi coperti o compenetrati: %d" % (_trovati.size() - prima))
	prima = _trovati.size()
	_compenetrazioni(z, oggetti)
	_dentro_dettagli(z, mesh, oggetti)
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
	match stato:
		"interni_dopo":
			# ambienti-1: docce aperte, armadietto sbattuto (a fine corsa, col metodo del gioco: gira sul cardine vero),
			# tornello girato (120°), saracinesca aperta
			var interni := _radice.get_node_or_null(^"Interni")
			if interni:
				interni.call(&"apri_docce", true)
				var anta := interni.find_child("armadietto_sbatte_anta", true, false) as Node3D
				if anta:
					interni.call(&"_sbatti_anta", anta, false)
				var rotore := interni.find_child("tornello_rotore", true, false) as Node3D
				if rotore:
					rotore.rotation.y -= TAU / 3.0
				var saracinesca := interni.find_child("Saracinesca", true, false)
				if saracinesca and saracinesca.has_method(&"load_state"):
					saracinesca.call(&"load_state", {"latched": true, "open": 1.0})
			for i in 10:
				await get_tree().physics_frame
			return
		"lei_fossa":
			# mascotte: dopo il blackout lei affacciata alla fossa (fase GUARDA); le luci non si toccano (il blackout
			# di GameState resterebbe anche per le scene dopo), conta solo dove sta lei
			var lei := _radice.find_child("LeiSbuca", true, false)
			if lei and lei.has_method(&"_affaccia"):
				lei.call(&"_affaccia")
			for i in 30:
				await get_tree().physics_frame
			return
		"tappa7":
			for porta in _radice.find_children("*", "PortaManiglione", true, false):
				porta.call(&"load_state", {"aperta": true, "bloccata": false})
			for portello in _radice.find_children("*", "HingedHatch", true, false):
				portello.call(&"load_state", {"open": true})
			for i in 30:
				await get_tree().physics_frame
			return
		"risalita_arrivo":
			_mostra_risalita()
			for i in 10:
				await get_tree().physics_frame
			return
		"risalita_dopo":
			# enigmi: le paratie del fiume girate, la cassaforte aperta, il negatoscopio con la radiografia
			# (come li prepara enigmi, 22 ottobre): la luce dell'infermeria accesa, tutti i cassetti tirati (ognuno si apre
			# una volta e resta aperto: il 14 con la radiografia), la cassaforte aperta col codice
			_mostra_risalita()
			for par in _radice.find_children("*", "ParatiaFiume", true, false):
				par.call(&"gira")
			var inf := _radice.get_node_or_null(^"Risalita/Infermeria")
			var interruttore := inf.get_node_or_null(^"Interruttore") if inf else null
			if interruttore:
				interruttore.set(&"powered", true)
			for c in _radice.find_children("*", "CassettoSchedario", true, false):
				c.call(&"load_state", {"aperto": true})
			for c in _radice.find_children("*", "CassaforteRotelle", true, false):
				c.call(&"load_state", {"cifre": [4, 1, 7], "aperta": true})
			for n in _radice.find_children("*", "Negatoscopio", true, false):
				n.call(&"load_state", {"con_radiografia": true})
			for i in 240:
				await get_tree().physics_frame
			return
		"inseguimento_dopo":
			# ambienti-2: la grata calata e le paratie aperte
			var ins := _radice.find_child("SalaInseguimento", true, false)
			if ins:
				var grata = ins.get(&"grata")
				var dati = ins.get(&"dati")
				if grata is Node3D and dati is Dictionary and (dati as Dictionary).has("grata"):
					(grata as Node3D).global_position += Vector3.DOWN * float(dati["grata"]["corsa"])
					ins.set(&"grata_giu", true)
				var paratie = ins.get(&"paratie")
				if paratie is Array:
					for d in paratie:
						var pn = d.get("pannello_nodo")
						if pn is Node3D:
							(pn as Node3D).global_position = (d["chiuso"] as Vector3) + Vector3.UP * float(d["corsa"])
			for i in 10:
				await get_tree().physics_frame
			return
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


## L'acqua, dai pezzi del percorso (minuscolo): quelli che cominciano con "acqua" (Acqua, acqua_pozze,
## AcquaFossaBimbi) ma non con "acquari", o finiscono con "_acqua". Non basta "contiene acqua": prendeva anche gli
## acquari (AcquarioGiallo...), e basi, coperchi, tiranti e vetri degli acquari non si controllavano mai (collaudo,
## 22 ottobre).
static func _e_acqua(percorso: String) -> bool:
	return Array(percorso.split("/")).any(func(x): return (x.begins_with("acqua") and not x.begins_with("acquari")) or x.ends_with("_acqua"))


## Perché una parte nascosta può non essere controllata: una creatura (si muove: la guarda il collaudo), un effetto o
## l'acqua (esclusi sempre), o la variante di una cosa controllata nello stesso posto (la lampada accesa e quella
## spenta, il cassetto chiuso e tirato). Vuoto: nessun motivo, va controllata con uno stato.
func _tipo_nascosta(n: Node) -> String:
	var percorso := _nodo(n).to_lower()
	for pezzo in percorso.split("/"):
		if pezzo == "lei" or pezzo.contains("medusa") or pezzo.contains("medusin") or pezzo.contains("bambino"):
			return "creatura, si muove (la guarda il collaudo)"
	if Array(percorso.split("/")).any(func(x): return _e_effetto(x)) or _e_acqua(percorso):
		return "effetto o acqua, esclusi"
	if percorso.split("/").has("graybox"):
		# il segnaposto di un meccanismo col modello vero (per esempio il pannello della PoweredDoor): resta solo come
		# collisione, non si vede mai
		return "segnaposto graybox, al suo posto si vede il modello vero"
	# la variante: il suo box sta dentro quello delle mesh visibili accanto (stesso genitore)
	var mio := AABB()
	var primo := true
	for m in ([n] if n is MeshInstance3D else []) + n.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh:
			mio = _box(m) if primo else mio.merge(_box(m))
			primo = false
	var padre := n.get_parent()
	if primo or padre == null:
		return ""
	var vicini := AABB()
	var trovato := false
	for m in padre.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh and _visibile(m) and not n.is_ancestor_of(m) and m != n:
			vicini = _box(m) if not trovato else vicini.merge(_box(m))
			trovato = true
	if trovato and vicini.grow(0.05).encloses(mio):
		return "variante nello stesso posto di una parte controllata"
	return ""


## I MultiMesh (i dettagli della sala con 6 o più copie, le lamelle della serranda, la struttura della cupola)
## diventano una mesh per istanza, così si controllano come le altre. Senza schermo il MultiMesh non conserva le
## trasformazioni: chi lo crea le lascia nel meta "trasformazioni". Quelli senza finiscono nel rapporto, fra i non
## controllati.
func _espandi_multimesh() -> void:
	var n_istanze := 0
	for n in _radice.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm == null or mm.mesh == null or not _visibile(mmi):
			continue
		# il meta sul nodo (MultiMesh fatti da codice) o sulla risorsa (MultiMesh salvati in un .res, come le lampadine
		# del portone: il meta si salva con la risorsa)
		var fonte: Object = mmi if mmi.has_meta(&"trasformazioni") else mm
		if not fonte.has_meta(&"trasformazioni"):
			if not _tipo_nascosta(mmi).is_empty():
				continue   # una creatura (le medusine) o un effetto: esclusi come le loro mesh
			_multimesh_senza.append("%s · %s" % [String(_radice.scene_file_path).get_file().get_basename(), _nodo(mmi)])
			continue
		var tr: Array = fonte.get_meta(&"trasformazioni")
		var quante := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		for i in mini(quante, tr.size()):
			var copia := MeshInstance3D.new()
			copia.name = "%s_%d" % [mmi.name, i]
			copia.mesh = mm.mesh
			copia.material_override = mmi.material_override
			copia.cast_shadow = mmi.cast_shadow
			copia.transform = mmi.transform * (tr[i] as Transform3D)
			mmi.get_parent().add_child(copia)
			n_istanze += 1
		mmi.visible = false
	if n_istanze > 0:
		print("  MultiMesh: %d istanze controllate come mesh" % n_istanze)


## Le mesh con lo scheletro si misurano nella posa del momento, non in quella di riposo (collaudo, 22 ottobre): la mesh
## diventa quella messa in posa e lo scheletro si stacca (il controllo non anima niente). Senza schermo
## bake_mesh_from_current_skeleton_pose non funziona (la skin si registra col renderer): lo skinning si fa qui.
func _congela_scheletri() -> void:
	# la posa con i modificatori dello scheletro (i tentacoli spinti fuori dai muri, lo sguardo: mascotte, 22 ottobre)
	# c'è solo subito dopo un aggiornamento dello scheletro: lo si fa girare un momento, si aspetta skeleton_updated e
	# lì si mettono in posa le sue mesh
	var per_scheletro := {}
	for n in _radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skeleton.is_empty() or mi.skin == null or not _visibile(mi):
			continue
		var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if sk:
			per_scheletro.get_or_add(sk, []).append(mi)
	var n_cotte := 0
	for sk in per_scheletro:
		var cotte := {}
		var fatto := [false]
		var cuoci := func():
			if fatto[0]:
				return
			fatto[0] = true
			for mi in per_scheletro[sk]:
				cotte[mi] = _in_posa(mi, sk)
		(sk as Skeleton3D).skeleton_updated.connect(cuoci)
		(sk as Node).process_mode = Node.PROCESS_MODE_ALWAYS
		for i in 10:
			await get_tree().process_frame
			if fatto[0]:
				break
		(sk as Node).process_mode = Node.PROCESS_MODE_INHERIT
		(sk as Skeleton3D).skeleton_updated.disconnect(cuoci)
		if not fatto[0]:
			push_warning("controllo: lo scheletro %s non si è aggiornato, posa senza modificatori" % _nodo(sk))
			cuoci.call()
		for mi in cotte:
			if cotte[mi] == null:
				continue
			(mi as MeshInstance3D).skin = null
			(mi as MeshInstance3D).skeleton = NodePath()
			(mi as MeshInstance3D).mesh = cotte[mi]
			n_cotte += 1
	if n_cotte > 0:
		print("  mesh con scheletro nella posa del momento (modificatori compresi): %d" % n_cotte)


## La mesh di mi messa nella posa corrente di sk (nello spazio di mi), solo i triangoli (per le misure).
static func _in_posa(mi: MeshInstance3D, sk: Skeleton3D) -> ArrayMesh:
	var skin := mi.skin
	var a_mi := mi.global_transform.affine_inverse() * sk.global_transform
	var ossa: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var osso := skin.get_bind_bone(b)
		if osso < 0:
			osso = sk.find_bone(skin.get_bind_name(b))
		ossa.append(a_mi * (sk.get_bone_global_pose(osso) if osso >= 0 else Transform3D()) * skin.get_bind_pose(b))
	var out := ArrayMesh.new()
	for si in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix = arr[Mesh.ARRAY_BONES]
		var w = arr[Mesh.ARRAY_WEIGHTS]
		if ix == null or w == null or (ix as PackedInt32Array).is_empty():
			return null
		var per := (ix as PackedInt32Array).size() / v.size()   # 4 o 8 ossa per vertice
		var nv := PackedVector3Array()
		nv.resize(v.size())
		for k in v.size():
			var p := Vector3.ZERO
			for q in per:
				var peso: float = w[k * per + q]
				if peso > 0.0:
					var b: int = ix[k * per + q]
					if b < ossa.size():
						p += (ossa[b] * v[k]) * peso
			nv[k] = p
		var nuovi := []
		nuovi.resize(Mesh.ARRAY_MAX)
		nuovi[Mesh.ARRAY_VERTEX] = nv
		nuovi[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, nuovi)
	return out


## Le stanze della Risalita (fiume e infermeria) come col giocatore dentro: visibili, e il loro script fermo (se no
## le rinasconde, col giocatore lontano).
func _mostra_risalita() -> void:
	var r := _radice.get_node_or_null(^"Risalita")
	if r == null:
		push_warning("controllo: Risalita non trovata")
		return
	# le stanze si caricano solo col giocatore vicino o lungo la strada nuova: qui servono comunque
	r.call(&"carica_subito")
	r.process_mode = Node.PROCESS_MODE_DISABLED
	for nome in ["fiume", "infermeria"]:
		var n = r.get(nome)
		if n is Node3D:
			(n as Node3D).visible = true


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
	for classe in ["GPUParticles3D", "CPUParticles3D"]:
		for n in _radice.find_children("*", classe, true, false):
			esclusi.append(n)
	for n in _radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not _visibile(mi) or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if esclusi.any(func(e): return (e as Node).is_ancestor_of(mi)):
			continue
		if _effetto(mi):
			continue
		var percorso := String(_radice.get_path_to(mi)).to_lower()
		if _e_acqua(percorso) or String(mi.name).to_lower() in ["superficie", "surface"]:
			_acqua[mi] = true   # le superfici dell'acqua reggono quello che galleggia, ma non sono oggetti
		out.append(mi)
	return out


## Le parti nascoste all'inizio (che compaiono più avanti nel gioco): il controllo non le guarda, a meno di una zona
## con stato che le mostri. Le stampa raggruppate per il primo nodo nascosto, con quante mesh hanno sotto.
func _elenca_nascoste() -> void:
	var gruppi := {}
	_box_nascoste.clear()
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
			_box_nascoste.append(_box(mi))
	_nascoste_ora = {}
	for nome in gruppi:
		_nascoste_ora[nome] = [gruppi[nome], _tipo_nascosta(_radice.get_node(NodePath(nome)))]
	if gruppi.is_empty():
		return
	var nomi := gruppi.keys()
	nomi.sort()
	print("  nascoste all'inizio (non controllate): %d parti, %d mesh" % [nomi.size(), gruppi.values().reduce(func(x, y): return x + y, 0)])
	for nome in nomi:
		print("    NASCOSTA %s · %d mesh" % [nome, gruppi[nome]])


## Un effetto a tempo (vedi EFFETTI): il nome di un nodo del percorso o la classe del suo script.
func _effetto(mi: Node) -> bool:
	var k := mi
	while k and k != _radice:
		if _e_effetto(String(k.name), classe_di(k)):
			return true
		k = k.get_parent()
	return false


static func _e_effetto(nome: String, classe := "") -> bool:
	var parole := _parole(nome) + _parole(classe)
	var di_classe := _parole(classe)
	return parole.any(func(w): return EFFETTI.any(func(e): return w.begins_with(e))) \
			or di_classe.any(func(w): return EFFETTI_CLASSE.any(func(e): return w.begins_with(e)))


## Le parole di un nome, minuscole: si divide a ogni carattere che non è una lettera e dove una minuscola è seguita da
## una maiuscola (SchizzoCoda -> schizzo, coda; det_getto_2 -> det, getto; WaterDripEmitter -> water, drip, emitter).
static func _parole(nome: String) -> Array:
	var out := []
	var w := ""
	for i in nome.length():
		var ch := nome[i]
		var lettera := ch.to_lower() != ch.to_upper()
		if not lettera:
			if not w.is_empty():
				out.append(w.to_lower())
			w = ""
			continue
		if not w.is_empty() and ch == ch.to_upper() and w[w.length() - 1] == w[w.length() - 1].to_lower():
			out.append(w.to_lower())
			w = ""
		w += ch
	if not w.is_empty():
		out.append(w.to_lower())
	return out


static func classe_di(n: Node) -> String:
	var sc: Script = n.get_script()
	while sc:
		var g := String(sc.get_global_name())
		if g != "":
			return g
		sc = sc.get_base_script()
	return ""


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
	var p := _radice.get_path_to(n)
	if (z.has("parti") and not (z["parti"] as Array).any(func(x): return String(p).begins_with(x))) \
			or (not z.has("zona") and not z.has("sotto")):
		# negli stati, un caso fuori dalle parti (un ingombro di quello che si è aperto): la zona del giro iniziale
		for b in ZONE:
			if b["scena"] == z["scena"] and not b.has("stato"):
				z = b
				break
	if z.has("zona"):
		return z["zona"]
	return String((z["sotto"] as Dictionary).get(String(p.get_name(0)), String(p.get_name(0)).to_lower()))


static func _squadra(zona: String, nodo: String) -> String:
	for r in SQUADRE:
		if nodo.begins_with(r[0]) or nodo.contains("/" + r[0]):
			return r[1]
	return SQUADRE_ZONA.get(zona, "da assegnare")


## Cosa ha guardato questo giro: gli oggetti per parte (i primi due livelli del percorso), e quali mesh erano visibili
## (dentro le parti, nei giri con stato). Così il rapporto dice di ogni zona se è stata controllata e con quanti oggetti,
## e quali parti nascoste all'inizio non le ha guardate nessun giro.
func _segna_copertura(z: Dictionary, mesh: Array, oggetti: Array) -> void:
	var scena: String = z["scena"]
	var parti: Array = z.get("parti", [])
	var dentro := func(percorso: String) -> bool:
		return parti.is_empty() or parti.any(func(p): return percorso == p or percorso.begins_with(p + "/"))
	var visti: Dictionary = _visti.get_or_add(scena, {})
	for mi in mesh:
		var percorso := _nodo(mi)
		if dentro.call(percorso):
			visti[percorso] = true
	var per_parte := {}
	for mi in oggetti:
		var percorso := _nodo(mi)
		if not dentro.call(percorso):
			continue
		var pezzi := percorso.split("/")
		var parte := "/".join(pezzi.slice(0, mini(2, pezzi.size() - 1))) if pezzi.size() > 1 else percorso
		if parte.contains("@"):
			parte = pezzi[0]   # i nodi con nomi automatici con la loro parte, non una riga ciascuno
		per_parte[parte] = int(per_parte.get(parte, 0)) + 1
	# le parti nascoste: quelle del giro iniziale, più quelle nascoste anche dentro le parti di uno stato (per esempio i
	# cassetti tirati dell'infermeria, che nel giro iniziale non si vedevano perché era nascosta tutta la stanza)
	var nascoste: Dictionary = _nascoste_base.get_or_add(scena, {})
	for g in _nascoste_ora:
		if dentro.call(String(g)) and not nascoste.has(g):
			nascoste[g] = _nascoste_ora[g]
	# negli stati: ogni parte deve essere visibile almeno per metà delle sue mesh. Se no lo stato non l'ha mostrata
	# (fiume e infermeria, rinascosti dal _process della Risalita, non si controllavano): il controllo fallisce
	for p in parti:
		var nodo_p := _radice.get_node_or_null(NodePath(p))
		if nodo_p == null:
			check(false, "stato %s: la parte %s non esiste" % [z.get("stato", ""), p])
			continue
		# le stesse esclusioni di _mesh_visibili (effetti, solo ombra), tranne la visibilità
		var tutte := nodo_p.find_children("*", "MeshInstance3D", true, false).filter(func(m): return (m as MeshInstance3D).mesh != null \
				and (m as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and not _effetto(m))
		var viste := mesh.filter(func(m): return _nodo(m) == p or _nodo(m).begins_with(p + "/"))
		if tutte.size() >= 4 and viste.size() * 2 < tutte.size():
			check(false, "stato %s: della parte %s si vedono solo %d mesh su %d (lo stato non la mostra?)" % [
					z.get("stato", ""), p, viste.size(), tutte.size()])
	for p in parti:
		if not per_parte.keys().any(func(k): return k == p or String(k).begins_with(p + "/") or String(p).begins_with(k + "/")):
			# una parte dello stato senza nessun oggetto visibile: si vede subito nel rapporto (-1: non ha mesh, è solo
			# logica, come PortoneTorre, i cui pezzi stanno in un'altra parte)
			var nodo := _radice.get_node_or_null(NodePath(p))
			per_parte[p] = -1 if nodo and nodo.find_children("*", "MeshInstance3D", true, false).is_empty() else 0
	_copertura.append({"giro": "%s · %s" % [scena.get_file().get_basename(), z.get("stato", "inizio")], "parti": per_parte})


func _nodo(n: Node) -> String:
	return String(_radice.get_path_to(n))


func _trova(z: Dictionary, n: Node, problema: String, pos: Vector3, dettaglio: String) -> void:
	if z.has("stato"):
		var nodo := _nodo(n)
		# negli stati si guardano le parti dello stato; l'ingombro in tutta la scena (la serranda, il portello o il
		# portone aperti finiscono nel passaggio: collaudo, 22 ottobre). I casi già trovati nel giro iniziale non si
		# ripetono (sotto).
		if problema != "ingombro" and z.has("parti") and not (z["parti"] as Array).any(func(p): return nodo.begins_with(p)):
			return
		dettaglio += " (stato: %s)" % z["stato"]
	var firma := ""
	if _nodo(n).contains("@"):
		# i nodi fatti da codice hanno nomi automatici, che cambiano col numero di nodi creati prima: il caso si
		# riconosce anche dal modello da cui vengono e dalla mesh (la "firma"), oltre che dalla posizione
		var a := n
		while a and a != _radice and a.scene_file_path.is_empty():
			a = a.get_parent()
		var modello := a.scene_file_path.get_file() if a and a != _radice else ""
		if not modello.is_empty():
			dettaglio += " [modello: %s]" % modello
		firma = "%s|%s" % [modello, _firma_mesh(n)]
	var k := {"zona": _zona(z, n), "nodo": _nodo(n), "squadra": _squadra(_zona(z, n), _nodo(n)), "problema": problema,
			"pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)], "dettaglio": dettaglio}
	if not firma.is_empty():
		k["firma"] = firma
	if z.has("stato"):
		# già trovato nello stato iniziale (stesso nodo, stesso problema; i nodi fatti da codice, @Classe@N, cambiano
		# numero da un'istanza all'altra: si confrontano con la posizione, come le eccezioni): non si ripete
		var mia := _chiave_senza_zona(k)
		if _trovati.any(func(t): return _chiave_senza_zona(t) == mia):
			return
	_trovati.append(k)


## La mesh di un nodo, in un modo che non cambia da un avvio all'altro: il file della risorsa, o la classe e la
## misura (per le mesh fatte da codice: SphereMesh, BoxMesh...).
static func _firma_mesh(n: Node) -> String:
	var mi := n as MeshInstance3D
	if mi == null or mi.mesh == null:
		return classe_di(n) if not classe_di(n).is_empty() else n.get_class()
	if not mi.mesh.resource_path.is_empty():
		return mi.mesh.resource_path.get_file()
	var a := mi.mesh.get_aabb().size
	return "%s %.2fx%.2fx%.2f" % [mi.mesh.get_class(), a.x, a.y, a.z]


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
## attaccato): la sua forma convessa allargata di STACCO deve toccare o entrare in un altro corpo.
## Gli oggetti già "sospesi" (niente entro 5 cm) non si ripetono.
func _staccato(z: Dictionary, mi: MeshInstance3D) -> void:
	if _trovati.any(func(t): return t["nodo"] == _nodo(mi) and t["problema"] == "sospeso"):
		return
	var me: Array[RID] = []
	if _corpo_di.has(mi):
		me.append((_corpo_di[mi] as StaticBody3D).get_rid())
	# la forma convessa della mesh, allargata di STACCO: se tocca o entra in un altro corpo, è retto (anche un pezzo
	# infilato in un altro, come un bulbo sul portalampada)
	# solo le mesh vere (STRATO), non le collisioni del gioco: una collisione è spesso più grande della mesh (un muro
	# a 2 cm sembrava toccato) o è dell'oggetto stesso (l'anta toccava la sua collisione)
	var qp := PhysicsShapeQueryParameters3D.new()
	qp.collision_mask = STRATO
	qp.exclude = me
	var conv := mi.mesh.create_convex_shape(true, false) as ConvexPolygonShape3D
	if conv == null or conv.points.size() < 8 or _piatta(mi):
		# una mesh piatta (un foglio, una scritta): il suo box allargato di STACCO
		var bx := _box(mi)
		var bf := BoxShape3D.new()
		bf.size = bx.size + Vector3.ONE * STACCO * 2.0
		qp.shape = bf
		qp.transform = Transform3D(Basis(), bx.get_center())
		if _segna_tocchi(mi, qp):
			return
		_trova_staccato(z, mi, me)
		return
	# i punti nel mondo (la scala del nodo, nella query, non si applica alla forma), allargati di STACCO in tutte le
	# direzioni (ogni punto spostato di ±STACCO sui tre assi: anche un foglio sottile si allarga sotto e sopra)
	var gt := mi.global_transform
	var punti := PackedVector3Array()
	var spinte := [Vector3(STACCO, 0, 0), Vector3(-STACCO, 0, 0), Vector3(0, STACCO, 0), Vector3(0, -STACCO, 0),
		Vector3(0, 0, STACCO), Vector3(0, 0, -STACCO)]
	for q in conv.points:
		var w := gt * q
		for sp in spinte:
			punti.append(w + sp)
	# i punti puliti dal ConvexHullComputer di Godot prima di darli a Jolt: con troppi punti quasi allineati Jolt
	# non costruiva la forma ("Hull building failed"), la query non trovava niente e l'oggetto risultava staccato
	# anche se poggiava (enigmi, transenna16 del fiume). Senza semplificare: semplificata la forma si rimpicciolisce.
	var nuvola := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = punti
	nuvola.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr)
	var forma := nuvola.create_convex_shape(true, false) as ConvexPolygonShape3D
	if forma == null or forma.points.size() < 4:
		forma = ConvexPolygonShape3D.new()
		forma.points = punti
	qp.shape = forma
	qp.transform = Transform3D.IDENTITY
	if not _forma_buona(mi, qp):
		# Jolt non l'ha costruita lo stesso: il box allargato, come per le mesh piatte
		var bx := _box(mi)
		var bf := BoxShape3D.new()
		bf.size = bx.size + Vector3.ONE * STACCO * 2.0
		qp.shape = bf
		qp.transform = Transform3D(Basis(), bx.get_center())
	if _segna_tocchi(mi, qp):
		return
	_trova_staccato(z, mi, me)


## Vero se la forma della query è stata costruita: deve almeno toccare il corpo della mesh stessa (che contiene), messo
## per un attimo sullo strato STRATO_SOLO. Una forma che Jolt non riesce a costruire ("Hull building failed") non
## tocca niente, e l'oggetto risultava staccato.
func _forma_buona(mi: MeshInstance3D, qp: PhysicsShapeQueryParameters3D) -> bool:
	var corpo := _corpo_di.get(mi) as StaticBody3D
	if corpo == null:
		return true
	var maschera := qp.collision_mask
	var esclusi := qp.exclude
	corpo.collision_layer = STRATO | STRATO_SOLO
	qp.collision_mask = STRATO_SOLO
	qp.exclude = []
	var ok := not _spazio.intersect_shape(qp, 1).is_empty()
	corpo.collision_layer = STRATO
	qp.collision_mask = maschera
	qp.exclude = esclusi
	return ok


## Le mesh che la forma allargata di mi tocca (per i gruppi, vedi _gruppi_staccati): vero se ne tocca almeno una.
func _segna_tocchi(mi: MeshInstance3D, qp: PhysicsShapeQueryParameters3D) -> bool:
	var altri := []
	for h in _tutti_i_corpi(qp):
		var m: MeshInstance3D = _corpi.get((h.collider as CollisionObject3D).get_rid())
		if m:
			altri.append(m)
	# gli oggetti piccoli (sotto PICCOLO) o con un solo appoggio: la distanza vera fra le mesh, vertice contro faccia
	# come il collaudo. La forma convessa riempie i vuoti (fra il braccio di una lampada e il muro) e "toccava" anche
	# a 1-5 cm (collaudo, 22 ottobre: lampade della torre e dell'inseguimento, Polaroid10 sul lettino)
	# e, per tutti, i sostegni fissi (muri, strutture, pezzi oltre i 4 m): il braccio di una lampada "toccava" la
	# struttura della torre con la forma, a 5 cm con la mesh vera
	if not altri.is_empty():
		var tutti := _box(mi).size.length() < PICCOLO or altri.size() == 1
		var veri := altri.filter(func(m): return not (tutti or _box(m).size.length() >= OGGETTO_MAX) or _contatto_vero(mi, m, qp))
		if veri.is_empty():
			_staccati_veri[mi] = altri
		altri = veri
	_tocca[mi] = altri
	# diagnosi: POSIZ_TOCCA=pezzo_del_nome stampa cosa tocca ogni oggetto che lo contiene
	var cerca := OS.get_environment("POSIZ_TOCCA")
	if not cerca.is_empty() and _nodo(mi).contains(cerca):
		print("    TOCCA %s %s -> %s" % [_nodo(mi), _box(mi).get_center().snappedf(0.01), ", ".join(altri.map(func(m): return "%s (%.1f m)" % [_nodo(m), _box(m).size.length()]))])
	return not altri.is_empty()


## Vero se le mesh vere di a e b sono a meno di STACCO: una sferetta di STACCO su un vertice di a (fino a VERTICI_VERI,
## quelli nel box di b allargato) tocca il corpo di b; e, se b è piccolo, il contrario.
## Si provano per primi i vertici vicini ai punti dove la forma convessa allargata (qp) tocca b.
func _contatto_vero(a: MeshInstance3D, b: MeshInstance3D, qp: PhysicsShapeQueryParameters3D) -> bool:
	var corpo := _corpo_di.get(b) as StaticBody3D
	if corpo == null:
		return true
	corpo.collision_layer = STRATO_SOLO
	var maschera := qp.collision_mask
	qp.collision_mask = STRATO_SOLO
	var contatti := _spazio.collide_shape(qp, 16)
	qp.collision_mask = maschera
	corpo.collision_layer = STRATO
	var su_b := PackedVector3Array()
	for i in range(1, contatti.size(), 2):
		su_b.append(contatti[i])
	return _vertici_su(a, b, su_b) or (_box(b).size.length() < PICCOLO * 4.0 and _vertici_su(b, a, su_b))


func _vertici_su(a: MeshInstance3D, b: MeshInstance3D, vicino_a: PackedVector3Array) -> bool:
	var corpo := _corpo_di.get(b) as StaticBody3D
	if corpo == null:
		return true
	var vicino := _box(b).grow(STACCO * 2.0)
	var gt := a.global_transform
	var punti := []
	var visti := {}
	for v in a.mesh.get_faces():
		var w := gt * v
		if not vicino.has_point(w) or visti.has(w):
			continue
		visti[w] = true
		# la distanza dal punto di contatto più vicino (per provare prima quelli)
		var d := 0.0
		if not vicino_a.is_empty():
			d = INF
			for c in vicino_a:
				d = minf(d, w.distance_squared_to(c))
		punti.append([d, w])
	if punti.is_empty():
		return false
	punti.sort_custom(func(x, y): return x[0] < y[0])
	if _sferetta == null:
		_sferetta = PhysicsShapeQueryParameters3D.new()
		var sf := SphereShape3D.new()
		sf.radius = STACCO
		_sferetta.shape = sf
		_sferetta.collision_mask = STRATO_SOLO
	corpo.collision_layer = STRATO_SOLO
	var tocca := false
	for i in mini(punti.size(), VERTICI_VERI):
		_sferetta.transform = Transform3D(Basis(), punti[i][1])
		if not _spazio.intersect_shape(_sferetta, 1).is_empty():
			tocca = true
			break
	if not tocca and punti.size() > VERTICI_VERI:
		# i punti di contatto della forma possono stare tutti altrove (la mandata di una pompa, mentre il fondo poggia
		# sul basamento: ambienti-2, 23 ottobre): anche gli altri vertici nel box di b, fino a VERTICI_TUTTI
		var passo := maxi(1, (punti.size() - VERTICI_VERI) / VERTICI_TUTTI)
		var i := VERTICI_VERI
		while i < punti.size():
			_sferetta.transform = Transform3D(Basis(), punti[i][1])
			if not _spazio.intersect_shape(_sferetta, 1).is_empty():
				tocca = true
				break
			i += passo
	if not tocca:
		# infilato più di 5 mm (lo stelo di un manometro nella pompa, un capo nel muro): i vertici vicini al contatto
		# stanno dentro b, lontani dalla sua superficie
		for i in mini(punti.size(), 40):
			if _nel_pieno(punti[i][1]):
				tocca = true
				break
	if not tocca:
		# o uno spigolo che passa una faccia di b (un braccio infilato in un muro fatto di una faccia sola: i vertici
		# del cilindro sono solo sulle due basi, lontani dalla faccia)
		var facce := a.mesh.get_faces()
		var provati := 0
		var t := 0
		while t < facce.size() and provati < 400:
			var p0 := gt * facce[t]
			var p1 := gt * facce[t + 1]
			var p2 := gt * facce[t + 2]
			if vicino.has_point(p0) or vicino.has_point(p1) or vicino.has_point(p2):
				for coppia in [[p0, p1], [p1, p2], [p2, p0]]:
					provati += 1
					if not _raggio(coppia[0], coppia[1], STRATO_SOLO).is_empty():
						tocca = true
						break
				if tocca:
					break
			t += 3
	corpo.collision_layer = STRATO
	return tocca


## Gli oggetti che si toccano solo fra loro: la lampada e il suo vetro, a 2 cm dal muro, si reggevano a vicenda.
## Ogni gruppo di oggetti che si toccano deve toccare almeno una cosa fissa: l'architettura (pavimenti, muri,
## soffitti), un pezzo grande oltre i 4 m, o l'acqua (ciò che galleggia).
func _gruppi_staccati(z: Dictionary, oggetti: Array) -> void:
	var sono := {}
	for mi in oggetti:
		sono[mi] = true
	var fisso := func(m: MeshInstance3D) -> bool:
		# un pezzo grande (oltre OGGETTO_MAX, 4 m: le strutture, le stanze fatte in un pezzo) regge come un muro; se è
		# staccato lui, lo dice il suo controllo
		var d := _box(m).size.length()
		return _acqua.has(m) or d >= OGGETTO_MAX or (not sono.has(m) and d > OGGETTO_MIN)
	# retto: tocca un sostegno fisso, o un oggetto retto; si ripete finché non cambia niente. Si guarda solo ciò che
	# ogni oggetto tocca (ciò che lo regge): la forma convessa di una stanza fatta in un pezzo (corridoio_statico,
	# 27 m) contiene tutto quello che c'è dentro, e prendendo i contatti nei due sensi le lampade staccate dal muro
	# risultavano rette
	var retti := {}
	var cambiato := true
	while cambiato:
		cambiato = false
		for mi in _tocca:
			if retti.has(mi) or fisso.call(mi):
				continue
			for m in _tocca[mi]:
				if fisso.call(m) or retti.has(m):
					retti[mi] = true
					cambiato = true
					break
	# i gruppi non retti, per il dettaglio: gli oggetti non retti che si toccano fra loro
	var visto := {}
	for mi in _tocca:
		if visto.has(mi) or retti.has(mi) or fisso.call(mi):
			continue
		var gruppo := [mi]
		visto[mi] = true
		var i := 0
		while i < gruppo.size():
			for m in _tocca.get(gruppo[i], []):
				if sono.has(m) and not visto.has(m) and not retti.has(m) and not fisso.call(m):
					visto[m] = true
					gruppo.append(m)
			i += 1
		# un caso per gruppo, sull'oggetto più in basso (di solito è lui che non appoggia: lo scatolone in fondo alla pila,
		# 1 cm sopra il pavimento), con gli altri nel dettaglio
		gruppo = gruppo.filter(func(m): return not _trovati.any(func(t): return t["nodo"] == _nodo(m) and t["problema"] in ["sospeso", "staccato"]))
		if gruppo.is_empty():
			continue
		# un gruppo appoggiato a una parte nascosta in questo giro (il corridoio della Risalita sulle stanze, che il gioco
		# nasconde col giocatore lontano) si guarda nel giro che la mostra, non qui (enigmi, 22 ottobre)
		if gruppo.any(func(g): return _box_nascoste.any(func(bn): return bn.intersects(_box(g).grow(CONTATTO)))):
			continue
		gruppo.sort_custom(func(a, b): return _box(a).position.y < _box(b).position.y)
		var m: MeshInstance3D = gruppo[0]
		var b := _box(m)
		var c := b.get_center()
		var me: Array[RID] = []
		for g in gruppo:
			if _corpo_di.has(g):
				me.append((_corpo_di[g] as StaticBody3D).get_rid())
		var giu := _raggio(Vector3(c.x, b.position.y, c.z), Vector3(c.x, b.position.y - 5.0, c.z), STRATO, me)
		var vuoto := "più di 5 m" if giu.is_empty() else "%.1f cm" % ((b.position.y - (giu.position as Vector3).y) * 100.0)
		var altri := gruppo.slice(1).map(func(x): return String(x.name))
		var con := "" if altri.is_empty() else " Con lui, staccati insieme, %d oggetti che si reggono solo fra loro: %s%s." % [
				altri.size(), ", ".join(altri.slice(0, 8)), "..." if altri.size() > 8 else ""]
		_trova(z, m, "staccato", c, "tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a %s.%s" % [vuoto, con])


## Una mesh con un lato del box quasi nullo (meno di 1 mm): la forma convessa non si costruisce.
func _piatta(mi: MeshInstance3D) -> bool:
	var a := mi.get_aabb().size * mi.global_transform.basis.get_scale().abs()
	return minf(a.x, minf(a.y, a.z)) < 0.001


func _trova_staccato(z: Dictionary, mi: MeshInstance3D, me: Array[RID]) -> void:
	var b := _box(mi)
	var c := b.get_center()
	var giu := _raggio(Vector3(c.x, b.position.y, c.z), Vector3(c.x, b.position.y - 5.0, c.z), STRATO | Layers.WORLD, me)
	var vuoto := "più di 5 m" if giu.is_empty() else "%.1f cm" % ((b.position.y - (giu.position as Vector3).y) * 100.0)
	if _staccati_veri.has(mi):
		var vicini: Array = _staccati_veri[mi]
		_trova(z, mi, "staccato", c, "la sua forma sfiora %s, ma la mesh vera non lo tocca: fra i due più di %d mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a %s)" % [
				", ".join(vicini.slice(0, 3).map(func(m): return _nodo(m))), roundi(STACCO * 1000.0), vuoto])
		return
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
				if (h.normal as Vector3).y >= 0.7 and not _mobile(h.collider as Node):
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
	# le zone dove si sta accovacciati per forza (i tubi dell'inseguimento: SalaInseguimento.in_tubo, la stessa
	# funzione che usa il gioco): lì lo spazio da tenere libero arriva solo all'altezza da accovacciati
	var accovacciati: Array[Node] = []
	for n in _radice.find_children("*", "", true, false):
		if n.has_method(&"in_tubo"):
			accovacciati.append(n)
	var n_accov := 0
	print("  %d celle raggiungibili a piedi" % raggiunte.size())
	# nello spazio sopra ogni cella, a meno di 10 cm dall'asse del giocatore: tutto quello che si vede (anche con la collisione)
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.2, TESTA_A - TESTA_DA, 0.2)
	var forma_accov := BoxShape3D.new()
	forma_accov.size = Vector3(0.2, ACCOVACCIATO - TESTA_DA, 0.2)
	var forma_testa := CylinderShape3D.new()
	forma_testa.radius = TESTA_LARGA
	forma_testa.height = TESTA_A - TESTA_LARGA_DA
	var q := PhysicsShapeQueryParameters3D.new()
	q.collide_with_areas = false
	var visti := {}
	for k in raggiunte:
		var y: float = colonne[Vector2i(k.x, k.z)][k.y]
		var piedi := Vector3(limiti.position.x + k.x * PASSO_GRIGLIA, y, limiti.position.z + k.z * PASSO_GRIGLIA)
		var testa := TESTA_A
		for n in accovacciati:
			if n.call(&"in_tubo", piedi):
				testa = ACCOVACCIATO
				n_accov += 1
				break
		q.shape = forma if testa == TESTA_A else forma_accov
		var centro := piedi + Vector3(0, (TESTA_DA + testa) * 0.5, 0)
		q.transform = Transform3D(Basis(), centro)
		q.collision_mask = STRATO
		var r := _tutti_i_corpi(q)
		var solido := false
		if not r.is_empty():
			q.collision_mask = Layers.WORLD | Layers.BARRIERS
			solido = not _spazio.intersect_shape(q, 1).is_empty()
		# all'altezza della testa (da TESTA_LARGA_DA) lo spazio è più largo: una lampada che sporge dal muro a 10-30 cm
		# da dove si cammina finisce in faccia (collaudo, 22 ottobre: i fari della torre, le lampade del raccordo)
		if testa == TESTA_A:
			q.shape = forma_testa
			q.transform = Transform3D(Basis(), piedi + Vector3(0, (TESTA_LARGA_DA + TESTA_A) * 0.5, 0))
			q.collision_mask = STRATO
			var gia := r.map(func(h): return (h.collider as CollisionObject3D).get_rid())
			for h in _tutti_i_corpi(q):
				if not gia.has((h.collider as CollisionObject3D).get_rid()):
					r.append(h)
		for h in r:
			var mi: MeshInstance3D = _corpi.get((h.collider as CollisionObject3D).get_rid())
			if mi == null or _acqua.has(mi) or _aperta_dal_giocatore(mi):
				continue
			if not visti.has(mi):
				visti[mi] = [piedi, 0, 9.0, 0.0, false, y, y]
			visti[mi][1] += 1
			visti[mi][4] = visti[mi][4] or solido
			# fin dove arriva sopra il pavimento (le gambe o la testa)
			var bb := _box(mi)
			visti[mi][2] = minf(visti[mi][2], maxf(bb.position.y - y, TESTA_DA))
			visti[mi][3] = maxf(visti[mi][3], minf(bb.end.y - y, testa))
			visti[mi][5] = minf(visti[mi][5], y)
			visti[mi][6] = maxf(visti[mi][6], y)
	if not accovacciati.is_empty():
		print("  %d celle dove si sta accovacciati per forza (spazio libero fino a %.2f m)" % [n_accov, ACCOVACCIATO])
	for mi in visti:
		var p: Vector3 = visti[mi][0]
		var alto: float = visti[mi][3]
		var dove := "all'altezza della testa" if alto > 1.4 else ("all'altezza del busto" if alto > 0.9 else "all'altezza delle gambe")
		var quote := " (pavimento a y %.2f)" % visti[mi][5] if visti[mi][6] - visti[mi][5] < 0.05 else " (pavimenti fra y %.2f e %.2f)" % [visti[mi][5], visti[mi][6]]
		_trova(z, mi, "ingombro", p, "nello spazio di chi cammina, %s: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra %.2f e %.2f m sopra il pavimento (%d celle da 25 cm)%s, %s" % [
				dove, visti[mi][2], alto, visti[mi][1], quote,
				"con la collisione (ci si sbatte contro)" if visti[mi][4] else "senza collisione (si attraversa)"])


## Le parti che si muovono (paratie, grate, portoni, saracinesche...) non fanno mai da pavimento: il bordo alto di
## una paratia alzata non è un posto dove si arriva.
const MOBILI := ["inseguimentomobili", "paratia", "ins_grata", "portone", "saracinesca", "serranda", "cancello"]


func _mobile(n: Node) -> bool:
	while n != null and n != _radice:
		var nome := String(n.name).to_lower()
		for m in MOBILI:
			if nome.contains(m):
				return true
		n = n.get_parent()
	return false


## Una parte che il giocatore apre da sé (un cassetto, lo sportello della cassaforte, un'anta o una porta che apre
## lui): sporge come in una stanza vera e non conta come ingombro (coordinatore, 22 ottobre). Compenetrazioni, distacchi
## e sospesi si controllano lo stesso. Si riconosce dall'Interactable sopra di lei con uno stato di apertura.
func _aperta_dal_giocatore(mi: Node) -> bool:
	var a := mi.get_parent()
	while a and a != _radice:
		if (a is Interactable and (&"aperto" in a or &"open" in a or &"is_open" in a)) or &"aperta_ora" in a:
			return true
		a = a.get_parent()
	return false


## Tutti i corpi diversi che la forma tocca, uno per corpo. Jolt dà un risultato per ogni triangolo di una forma
## concava toccato: con un limite fisso, una mesh fitta riempiva la lista (e le celle si contavano più volte) e gli
## altri oggetti nello stesso punto sparivano. Si richiede escludendo quelli già trovati, finché la lista non è piena.
func _tutti_i_corpi(q: PhysicsShapeQueryParameters3D) -> Array:
	var esclusi_prima := q.exclude
	var out := []
	var trovati: Array[RID] = esclusi_prima.duplicate()
	for giro in 64:
		q.exclude = trovati
		var r := _spazio.intersect_shape(q, 32)
		for h in r:
			var rid: RID = (h.collider as CollisionObject3D).get_rid()
			if not trovati.has(rid):
				trovati.append(rid)
				out.append(h)
		if r.size() < 32:
			break
	q.exclude = esclusi_prima
	return out


## Una cella dove passa il giocatore: ci entrano le sue gambe (un cilindro di raggio 30 cm fra 0,3 e 1 m sopra il
## pavimento) senza toccare niente del mondo. Più in alto conta tutto quello che si vede, anche con la collisione
## (un tubo a 1,7 m sopra una scala è un difetto anche se ci si sbatte contro).
func _libero(c: Vector2i, y: float, limiti: AABB) -> bool:
	var x := limiti.position.x + c.x * PASSO_GRIGLIA
	var zz := limiti.position.z + c.y * PASSO_GRIGLIA
	_q_corpo.transform = Transform3D(Basis(), Vector3(x, y + 0.3 + 0.35, zz))
	if not _spazio.intersect_shape(_q_corpo, 1).is_empty():
		return false
	# dentro un muro spesso fatto a trimesh il cilindro non tocca nessuna superficie: un raggio verso l'alto che
	# colpisce per prima una faccia rivolta in su (vista da sotto, da dentro) vuol dire che la cella è nel pieno
	var su := _raggio(Vector3(x, y + 0.1, zz), Vector3(x, y + 3.0, zz), Layers.WORLD)
	return su.is_empty() or (su.normal as Vector3).y < 0.5


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
		for h in _tutti_i_corpi(q):
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
	# per nome, o un pezzo fatto da codice (nome automatico) lungo e sottile: le aste e i cavi delle lampade
	var da_codice := String(mi.name).begins_with("@") and (mi.mesh is CylinderMesh or mi.mesh is BoxMesh)
	if not da_codice and not NOMI_TUBI.any(func(t): return nome.contains(t)):
		return
	var b := _box(mi)
	var lati := [b.size.x, b.size.y, b.size.z]
	var asse := lati.find(lati.max())
	var ordinati := lati.duplicate()
	ordinati.sort()
	# un pezzo solo e allungato (le mesh con tanti tubi insieme non si controllano così)
	if float(ordinati[2]) < (0.3 if da_codice else 0.4) or float(ordinati[2]) < (6.0 if da_codice else 3.0) * float(ordinati[1]):
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
	if _sferetta == null:
		_sferetta = PhysicsShapeQueryParameters3D.new()
		var sf := SphereShape3D.new()
		sf.radius = STACCO
		_sferetta.shape = sf
	var centro := b.get_center()
	var attaccati := {}
	for capo in [lo, hi]:
		# i vertici del capo (entro 1 cm dall'estremità lungo l'asse)
		var punti := {}
		for p in v:
			if absf(p[asse] - capo) <= 0.01:
				punti[p] = true
		attaccati[capo] = _capo_attaccato(punti.keys(), me, centro)
	for capo in [lo, hi]:
		if attaccati[capo]:
			continue
		# un pezzo verticale che poggia col capo di sotto (un palo) può avere libero quello di sopra; il capo di sotto
		# (un cavo appeso) no
		if asse == 1 and capo == hi and attaccati[lo]:
			continue
		var punti := {}
		for p in v:
			if absf(p[asse] - capo) <= 0.01:
				punti[p] = true
		var c := Vector3.ZERO
		for p in punti:
			c += p
		c /= maxf(punti.size(), 1)
		var cosa := "catena" if nome.contains("caten") or nome.contains("chain") else ("asta" if da_codice or nome.contains("asta") or nome.contains("aste") \
				else ("cavo" if nome.contains("cav") or nome.contains("filo") or nome.contains("cable") or nome.contains("cord") or nome.contains("fun") \
				else ("gancio" if nome.contains("ganci") else "tubo")))
		_trova(z, mi, "estremita_libera", c, "un capo del pezzo (%s) finisce nel vuoto: nessuna superficie vera a meno di %d mm, e non è infilato in niente (né muro, pavimento, soffitto, né un altro pezzo o un macchinario)" % [
				cosa, roundi(CAPO * 1000.0)])


## Vero se il capo tocca una mesh vera: un suo vertice a meno di CAPO da una faccia (sferetta sullo strato delle
## mesh, se stesso escluso), o il suo centro nel pieno di una mesh vicina (un capo infilato in un muro o in un attacco).
func _capo_attaccato(punti: Array, me: Array[RID], centro_pezzo: Vector3) -> bool:
	if punti.is_empty():
		return true
	_sferetta.collision_mask = STRATO
	_sferetta.exclude = me
	var passo := maxi(1, punti.size() / 64)
	var i := 0
	while i < punti.size():
		_sferetta.transform = Transform3D(Basis(), punti[i])
		if not _spazio.intersect_shape(_sferetta, 1).is_empty():
			_sferetta.collision_mask = STRATO_SOLO
			_sferetta.exclude = []
			return true
		i += passo
	_sferetta.collision_mask = STRATO_SOLO
	_sferetta.exclude = []
	var c := Vector3.ZERO
	for p in punti:
		c += p
	c /= punti.size()
	# passato di poco attraverso una faccia (un braccio infilato 1 cm in un muro fatto di una faccia sola): un raggio dal
	# capo verso il pezzo, per 5 cm, colpisce la faccia
	if not _raggio(c, c + (centro_pezzo - c).normalized() * 0.05, STRATO, me).is_empty():
		return true
	# infilato: le mesh vicine (5 cm), una per volta sullo strato STRATO_SOLO
	var vicine := BoxShape3D.new()
	vicine.size = Vector3.ONE * 0.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = vicine
	q.transform = Transform3D(Basis(), c)
	q.collision_mask = STRATO
	q.exclude = me
	var diagnosi := not OS.get_environment("POSIZ_CAPO").is_empty() and c.distance_to(str_to_var(OS.get_environment("POSIZ_CAPO"))) < 0.1
	for h in _tutti_i_corpi(q):
		var corpo := h.collider as StaticBody3D
		corpo.collision_layer = STRATO_SOLO
		var dentro := _nel_pieno(c)
		if diagnosi:
			print("    CAPO %s vicino a %s: nel pieno %s" % [c, _nodo(_corpi.get(corpo.get_rid())), dentro])
		corpo.collision_layer = STRATO
		if dentro:
			return true
	if diagnosi:
		print("    CAPO %s: %d punti, nessuno a meno di 5 mm" % [c, punti.size()])
	return false


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
					# pezzi dello stesso modello, o dello stesso oggetto fatto da codice (lampade, fari): non si
					# confrontano, tranne un corrimano o un tubo con le altre cose di un glTF d'arredo, cioè fatto di
					# tanti oggetti diversi (l'arredo della risalita: il carrello nel corrimano di C2, riscontro dell'utente
					# sulla v0.3.11). Solo gli spigoli che lo attraversano: le staffe entrano apposta 1 mm nel tubo. Nei
					# modelli normali i pezzi si incastrano apposta (bielle, montanti, cornici)
					if _fino and _stesso_modello(a, b) and _arredo(a) and (_lungo_sottile(a) or _lungo_sottile(b)) \
							and boxes[a].intersects(boxes[b]):
						var pp := _attraversa(a, b)
						if pp > ATTRAVERSA_MIN:
							var chi2: MeshInstance3D = b if _lungo_sottile(a) else a
							var altro2: MeshInstance3D = a if chi2 == b else b
							_trova(z, chi2, "compenetra", boxes[a].intersection(boxes[b]).get_center(), "passa dentro %s per %d cm (nel pieno, per esempio, in %s)" % [_nodo(altro2), roundi(pp * 100.0), _punto_dentro.snappedf(0.01)])
					continue
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
						_trova(z, chi, "compenetra", i.get_center(), "passa dentro %s per %d cm (nel pieno, per esempio, in %s)" % [_nodo(altro), roundi(p * 100.0), _punto_dentro.snappedf(0.01)])
						continue
				var piccolo := minf(ba.get_volume(), bb.get_volume())
				if piccolo <= 0.0 or i.get_volume() < 0.3 * piccolo:
					continue
				var dentro := _frazione_dentro(a, b)
				if dentro >= 0.2:
					var chi: MeshInstance3D = a if ba.get_volume() <= bb.get_volume() else b
					var altro: MeshInstance3D = b if chi == a else a
					_trova(z, chi, "compenetra", i.get_center(), "il %d%% dei suoi vertici è dentro %s" % [roundi(dentro * 100.0), _nodo(altro)])


## Un glTF d'arredo: tanti oggetti diversi messi in un modello solo (più di [constant ARREDO_MESH] mesh), come l'arredo
## della risalita (480).
const ARREDO_MESH := 100
var _arredi := {}


func _arredo(mi: Node) -> bool:
	var o := mi.owner
	if o == null:
		return false
	if not _arredi.has(o):
		_arredi[o] = o.find_children("*", "MeshInstance3D", true, false).size() > ARREDO_MESH
	return _arredi[o]


## Una mesh lunga e sottile (un corrimano, un tubo, una sbarra): il lato più corto del box sotto 12 cm, il più lungo
## sopra 80 cm.
func _lungo_sottile(mi: MeshInstance3D) -> bool:
	var s := _box(mi).size
	return minf(s.x, minf(s.y, s.z)) < 0.12 and maxf(s.x, maxf(s.y, s.z)) > 0.8


## Le mesh grandi di dettagli (RACCORDO_dettagli, 44 m: i corrimano, i tubi e le staffe di tutto il raccordo fusi
## insieme) non sono oggetti di scena (troppo grandi) e prima non si confrontavano con niente: l'estintore, il rullo col
## tubo e lo scatolone dell'arredo della risalita passavano dentro i corrimano senza che il controllo li vedesse
## (riscontro dell'utente sulla v0.3.11). Per ogni oggetto vicino si prendono solo i triangoli della mesh grande attorno
## al suo box, e si guarda quanto i loro spigoli passano nel pieno dell'oggetto. L'architettura (pavimenti, muri, scale)
## resta fuori: lì le cose si appoggiano.
const NON_DETTAGLI := ["scale", "scala", "gradin", "rampa", "terreno", "tetto"]
## Una mesh di dettagli che passa dentro un oggetto più di tanto sotto la sua superficie (m) è una compenetrazione.
const PROFONDO_MIN := 0.012


func _dentro_dettagli(z: Dictionary, mesh: Array, oggetti: Array) -> void:
	var ogg := {}
	for o in oggetti:
		ogg[o] = true
	for g in mesh:
		var mg := g as MeshInstance3D
		if ogg.has(mg) or _acqua.has(mg) or _box(mg).size.length() < _oggetto_max:
			continue
		var percorso := String(_radice.get_path_to(mg)).to_lower()
		if ARCHITETTURA.any(func(a): return percorso.contains(a)) or NON_DETTAGLI.any(func(a): return percorso.contains(a)):
			continue
		var facce: PackedVector3Array = mg.global_transform * mg.mesh.get_faces()
		# i triangoli in celle da 1 m
		var celle := {}
		for t in facce.size() / 3:
			# i triangoli orizzontali (pavimenti, soffitti, la cima delle costole) no: lì le cose si appoggiano, e i loro
			# spigoli corrono sulla faccia di sotto di quello che ci sta sopra (le pile del fiume, i telai delle chiuse)
			var nt := (facce[t * 3 + 1] - facce[t * 3]).cross(facce[t * 3 + 2] - facce[t * 3])
			if nt.length() < 1e-9 or absf(nt.normalized().y) > 0.9:
				continue
			var bt := AABB(facce[t * 3], Vector3.ZERO).expand(facce[t * 3 + 1]).expand(facce[t * 3 + 2])
			var da := Vector3i(bt.position.floor())
			var a_ := Vector3i(bt.end.floor())
			for x in range(da.x, a_.x + 1):
				for y in range(da.y, a_.y + 1):
					for zz in range(da.z, a_.z + 1):
						celle.get_or_add(Vector3i(x, y, zz), []).append(t)
		var bg := _box(mg)
		for o in oggetti:
			var mo := o as MeshInstance3D
			var bo := _box(mo).grow(0.02)
			if not bo.intersects(bg) or not _corpo_di.has(mo) or _stesso_modello(mo, mg):
				continue
			var vicini := {}
			var da := Vector3i(bo.position.floor())
			var a_ := Vector3i(bo.end.floor())
			for x in range(da.x, a_.x + 1):
				for y in range(da.y, a_.y + 1):
					for zz in range(da.z, a_.z + 1):
						for t in celle.get(Vector3i(x, y, zz), []):
							vicini[t] = true
			if vicini.is_empty():
				continue
			var corpo := _corpo_di[mo] as StaticBody3D
			corpo.collision_layer = STRATO_SOLO
			var massimo := 0.0
			var punto := Vector3.ZERO
			var spigolo := ""
			for t in vicini:
				for e in 3:
					var p0 := facce[t * 3 + e]
					var p1 := facce[t * 3 + (e + 1) % 3]
					if not bo.has_point(p0) and not bo.has_point(p1) and not bo.intersects_segment(p0, p1):
						continue
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
					var medio := ((h0.position as Vector3) + (h1.position as Vector3)) * 0.5
					if not _nel_pieno(medio):
						continue
					# quanto è dentro, non quanto è lungo il tratto: una piastra di 1 cm sul pavimento sotto uno
					# scatolone ha spigoli lunghi tutti dentro la sua base, ma solo di 1 cm
					var prof := _profondita(medio)
					if prof > massimo:
						massimo = prof
						punto = medio
						spigolo = "da %s a %s" % [p0.snappedf(0.01), p1.snappedf(0.01)]
			corpo.collision_layer = STRATO
			if massimo > PROFONDO_MIN:
				_trova(z, mo, "compenetra", punto, "dentro ci passa %s, %d cm sotto la sua superficie (per esempio in %s, lo spigolo %s)" % [_nodo(mg), roundi(massimo * 100.0), punto.snappedf(0.01), spigolo])


## Quanto p sta sotto la superficie della mesh sullo strato STRATO_SOLO: la distanza più corta in 14 direzioni.
func _profondita(p: Vector3) -> float:
	var minimo := 1.0
	for d in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK,
			Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, 1, 1),
			Vector3(-1, 1, -1), Vector3(-1, -1, 1), Vector3(-1, -1, -1)]:
		var h := _raggio(p, p + (d as Vector3).normalized() * minimo, STRATO_SOLO)
		if not h.is_empty():
			minimo = minf(minimo, p.distance_to(h.position))
	return minimo


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
				# la versione accesa e quella spenta occupano lo stesso spazio; una stanza che compare accanto a un
				# corridoio no (il fiume della Risalita)
				return _stesso_spazio(r, k)
			k = k.get_parent()
	return false


## I box delle mesh sotto a e sotto b si sovrappongono per più del 70% del più piccolo.
func _stesso_spazio(a: Node, b: Node) -> bool:
	var ba := _box_di(a)
	var bb := _box_di(b)
	var i := ba.intersection(bb)
	var minore := minf(ba.get_volume(), bb.get_volume())
	return minore > 0.0 and i.get_volume() > 0.7 * minore


func _box_di(n: Node) -> AABB:
	var out := AABB()
	var primo := true
	for m in ([n] if n is MeshInstance3D else []) + n.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh:
			out = _box(m) if primo else out.merge(_box(m))
			primo = false
	return out


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
	var m1 := _spigoli_dentro(a, b)
	var p1 := _punto_dentro
	var m2 := _spigoli_dentro(b, a)
	if m1 >= m2:
		_punto_dentro = p1
	return maxf(m1, m2)


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
			# conta solo se fra le due facce c'è il pieno (un muro, un bordo, il fondo), non il vuoto di una fossa o di
			# una vasca aperte (coordinatore, 22 ottobre: un tentacolo che scende nella fossa non è una compenetrazione)
			var medio := ((h0.position as Vector3) + (h1.position as Vector3)) * 0.5
			if not _nel_pieno(medio):
				continue
			var l_dentro := (h0.position as Vector3).distance_to(h1.position)
			if l_dentro > massimo:
				massimo = l_dentro
				_punto_dentro = medio
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
		tot += 1
		if _nel_pieno(p):
			dentro += 1
		i += passo
	corpo.collision_layer = STRATO
	return float(dentro) / maxf(tot, 1)


## Vero se p sta nel pieno della mesh sullo strato STRATO_SOLO: dispari verso l'alto, e dispari anche verso il basso
## o in almeno 3 delle 4 direzioni orizzontali. Una fossa o una vasca aperte sopra danno pari verso l'alto (il vuoto
## dove scende un tentacolo non è "dentro"); un oggetto appoggiato a terra di solito non ha la faccia di sotto, ma i
## lati sì (un foglio nascosto dentro una base aperta in basso resta "dentro"). Un raggio solo verso l'alto dava
## dentro anche il vuoto sotto un foglio o una cupola.
func _nel_pieno(p: Vector3) -> bool:
	# dal verso delle facce, non dalla parità: in 6 direzioni, se la prima faccia colpita è vista dal retro (lo stesso
	# raggio senza le facce dal retro non la colpisce, o colpisce più lontano) vuol dire "dentro". Con pareti a faccia
	# singola e bordi senza fondo (la fossa dell'area bimbi) la parità dava pieno anche il vuoto fra il fondo e un
	# bordo che sporge (mascotte, 23 ottobre)
	var dentro := 0
	for d in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var h := _raggio(p, p + d * 50.0, STRATO_SOLO)
		if h.is_empty():
			continue
		var q := PhysicsRayQueryParameters3D.create(p, p + d * 50.0, STRATO_SOLO)
		q.hit_back_faces = false
		var davanti := _spazio.intersect_ray(q)
		var retro: bool = davanti.is_empty() or p.distance_to(davanti.position) > p.distance_to(h.position) + 0.0005
		if retro:
			dentro += 1
		if _diagnosi_pieno(p):
			print("    PIENO %s %s: colpita a %.3f m, %s" % [p.snappedf(0.01), d, p.distance_to(h.position), "dal retro" if retro else "davanti"])
	return dentro >= 4


## Diagnosi: POSIZ_PIENO=Vector3(x, y, z) stampa i raggi di _nel_pieno per i punti a meno di 30 cm.
func _diagnosi_pieno(p: Vector3) -> bool:
	var e := OS.get_environment("POSIZ_PIENO")
	return not e.is_empty() and p.distance_to(str_to_var(e)) < 1.5


## Quante volte il raggio da p verso dir passa le facce del corpo sullo strato STRATO_SOLO.
func _attraversamenti(p: Vector3, dir: Vector3) -> int:
	var n := 0
	var da := p
	for k in 16:
		var h := _raggio(da, da + dir * 50.0, STRATO_SOLO)
		if h.is_empty():
			break
		n += 1
		da = (h.position as Vector3) + dir * 0.001
	return n


# --- rapporto e eccezioni ------------------------------------------------------------------------------

## La chiave di un caso: zona, nodo e problema; i nodi fatti da codice hanno nomi automatici (@MeshInstance3D@217)
## che cambiano: per loro conta il tipo e la posizione arrotondata a mezzo metro.
static func _chiave_senza_zona(e: Dictionary) -> String:
	var c := e.duplicate()
	c["zona"] = ""
	return chiave_caso(c)


## Un caso si riconosce da zona, nodo e problema. Per i nodi con nomi automatici (@Classe@N) il numero non conta: al
## suo posto la posizione arrotondata a mezzo metro e la firma (modello e mesh, vedi _trova). Con firma := false la
## chiave vecchia, senza firma (per le eccezioni scritte prima del 22 ottobre sera).
static func chiave_caso(e: Dictionary, con_firma := true) -> String:
	var nodo := String(e["nodo"])
	var re := RegEx.create_from_string("@([A-Za-z0-9]+)@[0-9]+")
	var k := "%s|%s|%s" % [e["zona"], re.sub(nodo, "@$1", true), e["problema"]]
	if nodo.contains("@"):
		var p: Array = e["pos"]
		k += "|%s,%s,%s" % [snappedf(float(p[0]), 0.5), snappedf(float(p[1]), 0.5), snappedf(float(p[2]), 0.5)]
		if con_firma and e.has("firma"):
			k += "|" + String(e["firma"])
	return k


func _confronta() -> void:
	var eccezioni: Array = []
	if FileAccess.file_exists(ECCEZIONI):
		eccezioni = JSON.parse_string(FileAccess.get_file_as_string(ECCEZIONI))
	var note := {}
	for e in eccezioni:
		note[chiave_caso(e)] = e   # con la firma, se l'eccezione ce l'ha
	var nuovi := []
	var noti := []
	var trovate := {}
	for t in _trovati:
		var k: String = chiave_caso(t)
		var k_vecchia: String = chiave_caso(t, false)
		trovate[k] = true
		trovate[k_vecchia] = true
		var e = note.get(k, note.get(k_vecchia))
		if e != null:
			t["stato"] = e.get("stato", "")
			t["motivo"] = e.get("motivo", "")
			noti.append(t)
		else:
			nuovi.append(t)
	var spariti := eccezioni.filter(func(e): return not trovate.has(chiave_caso(e)))
	_scrivi_rapporto(nuovi, noti, spariti)
	check(nuovi.is_empty(), "nessun caso nuovo di posizionamento (%d nuovi, %d già noti, %d eccezioni non più trovate)" % [
			nuovi.size(), noti.size(), spariti.size()])
	var da_fare := noti.filter(func(t): return t.get("stato", "") != "voluto")
	print("  casi da correggere (non \"voluto\"): %d" % da_fare.size())
	# POSIZ_BLOCCA=1 prova il blocco senza accenderlo nella CI (per il giro sul commit candidato)
	if BLOCCA_DA_CORREGGERE or OS.get_environment("POSIZ_BLOCCA") == "1":
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
	testo += _testo_copertura()
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


## La sezione "Copertura" del rapporto: per ogni giro gli oggetti controllati per parte, poi le parti nascoste nel giro
## iniziale e se un altro giro (uno stato) le ha guardate.
func _testo_copertura() -> String:
	var t := "## Copertura\n\nPer ogni giro, quanti oggetti di scena si sono controllati in ogni parte. Una parte con 0 è una zona che il controllo non ha guardato.\n\n| Giro | Parte | Oggetti controllati |\n|---|---|---|\n"
	for c in _copertura:
		var pp: Dictionary = c["parti"]
		var nomi := pp.keys()
		nomi.sort()
		for n in nomi:
			t += "| %s | `%s` | %s |\n" % [c["giro"], n, ("**0: non controllata**" if int(pp[n]) == 0 else ("nessuna mesh (solo logica)" if int(pp[n]) < 0 else str(pp[n])))]
	t += "\n### Parti nascoste all'inizio\n\nLe parti nascoste nel giro iniziale (compaiono più avanti, o sono le versioni spente o accese di una luce, o effetti). \"Controllata nello stato\" vuol dire che un giro con stato le ha viste visibili; \"mai controllata\" va guardato.\n\n| Scena | Parte nascosta | Mesh | Controllata |\n|---|---|---|---|\n"
	var mai := 0
	for scena in _nascoste_base:
		var visti: Dictionary = _visti.get(scena, {})
		var gruppi: Dictionary = _nascoste_base[scena]
		var nomi := gruppi.keys()
		nomi.sort()
		for g in nomi:
			var vista := visti.has(g) or visti.keys().any(func(k): return String(k).begins_with(g + "/"))
			var tipo: String = gruppi[g][1]
			var come := "sì, in uno stato" if vista else ("no: " + tipo if not tipo.is_empty() else "**mai controllata**")
			if not vista and tipo.is_empty():
				mai += 1
			t += "| %s | `%s` | %d | %s |\n" % [String(scena).get_file().get_basename(), g, gruppi[g][0], come]
	print("  parti nascoste all'inizio mai controllate: %d (vedi il rapporto, \"Copertura\")" % mai)
	if not _multimesh_senza.is_empty():
		t += "\n### MultiMesh non controllati\n\nSenza le trasformazioni nel meta \"trasformazioni\" del nodo o della risorsa MultiMesh (vedi `_espandi_multimesh`):\n\n"
		for m in _multimesh_senza:
			t += "- `%s`\n" % m
		print("  MultiMesh non controllati: %d" % _multimesh_senza.size())
	return t + "\n"


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)
