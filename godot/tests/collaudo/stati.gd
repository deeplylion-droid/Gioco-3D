extends RefCounted
## Collaudo del posizionamento: porta una scena negli stati principali del capitolo, per controllare anche
## gli oggetti che compaiono o cambiano dopo (regola dell'utente del 22 ottobre).
## Stati:
##  - "inizio": come la scena si apre;
##  - "aperto": tutte le porte, i portelli, le paratie e le serrande aperte, le luci di prima;
##  - "ritorno": il ritorno al buio (tappa 7): blackout, porte aperte, serranda del magazzino aperta (acquari
##    pieni e lampadine del portone accese), tappa 8 finita;
##  - "risolto": come "ritorno", con l'enigma degli acquari risolto e il portone della torre aperto;
##  - "lei_fossa": lei affacciata alla fossa dell'area bimbi, come lo stato omonimo del controllo della CI.
## Le chiavi di save_state() dei nodi "persist" che vogliono dire "fatto" o "aperto" diventano vere; i
## Pickup restano dove sono (sono oggetti da controllare anche loro).

const VERE := ["latched", "aperto", "aperta", "finita", "finito", "fatto", "tornello", "docce", "armadietto", "avviate", "open", "con_radiografia"]
const FALSE := ["chiusa", "bloccata", "chiuso_dietro"]


static func applica(livello: Node, stato: String) -> void:
	mostra_nascosti(livello)
	if stato == "inizio":
		return
	if stato.begins_with("infermeria_"):
		_infermeria(livello, stato)
		return
	if stato.begins_with("acquari_"):
		# la base è il ritorno (blackout, acquari comparsi, tappa 8 finita), poi il momento dell'enigma
		applica(livello, "ritorno")
		_acquari(livello, stato)
		return
	if stato == "lei_fossa":
		# lei affacciata alla fossa dopo il blackout (fase GUARDA), come nel controllo della CI
		var lei := livello.find_child("LeiSbuca", true, false)
		if lei and lei.has_method(&"_affaccia"):
			lei.call(&"_affaccia")
		return
	if stato in ["ritorno", "risolto"]:
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for n in livello.get_tree().get_nodes_in_group(&"persist"):
		if not livello.is_ancestor_of(n) or n is Pickup or n is PackPickup or n is WaterTank:
			continue
		if not n.has_method(&"save_state") or not n.has_method(&"load_state"):
			continue
		var nome := String(n.name)
		if stato == "aperto" and (nome == "LeiSbuca" or nome.begins_with("EnigmaAcquari")):
			continue
		if n is PortoneTorre and stato != "risolto":
			continue
		var d: Dictionary = n.call(&"save_state")
		if n.get_script() and String((n.get_script() as Script).resource_path).ends_with("enigma_acquari.gd"):
			if stato == "risolto":
				d["stato"] = 3
			n.call(&"load_state", d)
			continue
		var cambiato := false
		for k in d.keys():
			if k == "open" and (d[k] is float or d[k] is int):
				d[k] = 1.0
				cambiato = true
			elif k in VERE:
				d[k] = true
				cambiato = true
			elif k in FALSE:
				d[k] = false
				cambiato = true
		if cambiato:
			n.call(&"load_state", d)
	# l'inseguimento: la grata calata davanti a lei
	for n in livello.find_children("*", "Node", true, false):
		if n.has_method(&"cala_grata"):
			n.call(&"cala_grata")
	if stato in ["ritorno", "risolto"]:
		GameState.luci_cambiate.emit(GameState.luci)


## Le zone che il gioco tiene nascoste finché il giocatore non ci arriva (per la memoria): la risalita mostra
## fiume e infermeria solo col giocatore vicino. Per il collaudo si mostrano sempre.
static func mostra_nascosti(livello: Node) -> void:
	for n in livello.find_children("*", "Node", true, false):
		if n.get(&"fiume") is Node3D and n.get(&"infermeria") is Node3D:
			n.set_process(false)
			(n.get(&"fiume") as Node3D).visible = true
			(n.get(&"infermeria") as Node3D).visible = true


## I passi dell'infermeria, uno dopo l'altro come nel gioco (al buio della tappa 7): infermeria_arrivo (com'è
## entrando), infermeria_negatoscopio (il pulsante colpito: il negatoscopio acceso), infermeria_cassetto (il cassetto
## con l'adesivo aperto), infermeria_cassaforte (la radiografia sul negatoscopio e la cassaforte aperta con 4-1-7).
static func _infermeria(livello: Node, stato: String) -> void:
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	GameState.luci_cambiate.emit(GameState.luci)
	var inf := livello.find_child("Infermeria", true, false)
	if inf == null:
		push_warning("stati: niente infermeria (COLLAUDO_RISALITA=1?)")
		return
	var k := ["infermeria_arrivo", "infermeria_negatoscopio", "infermeria_cassetto", "infermeria_cassaforte"].find(stato)
	if k >= 1:
		(inf.get(&"interruttore") as Node).call(&"load_state", {"powered": true})
	if k >= 2:
		for c in inf.get(&"cassetti"):
			if bool((c as Node).get(&"adesivo")):
				(c as Node).call(&"load_state", {"aperto": true})
	if k >= 3:
		var radiografia = inf.get(&"radiografia")
		if radiografia is Node3D:
			(radiografia as Node3D).visible = false   # presa dal cassetto e appoggiata sul negatoscopio
		(inf.get(&"negatoscopio") as Node).call(&"load_state", {"con_radiografia": true})
		(inf.get(&"cassaforte") as Node).call(&"load_state", {"cifre": [4, 1, 7], "aperta": true})


## I momenti dell'enigma degli acquari (sopra il ritorno): acquari_limpidi (i colorati pieni, il miscuglio vuoto),
## acquari_torbidi (il miscuglio pieno e torbido: la valvola gocciola), acquari_gorgo (a metà dello svuotamento),
## acquari_svuotati (finito il gorgo, i colorati di nuovo pieni), acquari_risolti (verde, portone aperto).
static func _acquari(livello: Node, stato: String) -> void:
	var e := livello.find_child("EnigmaAcquari", true, false)
	if e == null:
		return
	var misto = e.get(&"_misto")
	var giallo = e.get(&"_giallo")
	var blu = e.get(&"_blu")
	match stato:
		"acquari_limpidi", "acquari_svuotati":
			e.set(&"stato", EnigmaAcquari.Stato.APERTO)
			misto.fill = 0.0
			misto.set_mix({})
		"acquari_torbidi":
			for t in [giallo, blu]:
				t.fill = t.max_fill * 0.55
			misto.fill = misto.max_fill
			misto.set_mix(WaterMix.pura(WaterMix.TORBIDA))
			e.set(&"stato", EnigmaAcquari.Stato.TORBIDO)
		"acquari_gorgo":
			for t in [giallo, blu]:
				t.fill = t.max_fill * 0.75
			misto.fill = misto.max_fill * 0.5
			misto.set_mix(WaterMix.pura(WaterMix.TORBIDA))
			e.set(&"stato", EnigmaAcquari.Stato.GORGO)
			# fermo a metà: il gorgo non va avanti durante gli scatti
			e.set_physics_process(false)
		"acquari_risolti":
			misto.fill = misto.max_fill
			misto.set_mix(WaterMix.pura(WaterMix.VERDE))
			e.set(&"stato", EnigmaAcquari.Stato.RISOLTO)
			# COLLAUDO_SENZA_TORRE=1: il portone si apre ma la sala della torre non si carica (la sala intera
			# con la torre non entra nella memoria del renderer software; la torre ha il suo collaudo)
			if OS.get_environment("COLLAUDO_SENZA_TORRE") == "1" and &"sala_torre_scena" in livello:
				livello.set(&"sala_torre_scena", "")
			var portone = e.get(&"portone")
			if portone and portone.has_method(&"apri"):
				portone.call(&"apri")
