extends RefCounted
## Collaudo del posizionamento: porta una scena negli stati principali del capitolo, per controllare anche
## gli oggetti che compaiono o cambiano dopo (regola dell'utente del 22 ottobre).
## Stati:
##  - "inizio": come la scena si apre;
##  - "aperto": tutte le porte, i portelli, le paratie e le serrande aperte, le luci di prima;
##  - "ritorno": il ritorno al buio (tappa 7): blackout, porte aperte, serranda del magazzino aperta (acquari
##    pieni e lampadine del portone accese), tappa 8 finita;
##  - "risolto": come "ritorno", con l'enigma degli acquari risolto e il portone della torre aperto.
## Le chiavi di save_state() dei nodi "persist" che vogliono dire "fatto" o "aperto" diventano vere; i
## Pickup restano dove sono (sono oggetti da controllare anche loro).

const VERE := ["latched", "aperto", "aperta", "finita", "finito", "fatto", "tornello", "docce", "armadietto", "avviate", "open"]
const FALSE := ["chiusa", "bloccata", "chiuso_dietro"]


static func applica(livello: Node, stato: String) -> void:
	if stato == "inizio":
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
	if stato in ["ritorno", "risolto"]:
		GameState.luci_cambiate.emit(GameState.luci)
