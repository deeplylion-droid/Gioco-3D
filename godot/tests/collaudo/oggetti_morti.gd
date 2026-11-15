extends Node
## Test: morire e ripartire più volte di fila nella torre e nell'inseguimento non lascia oggetti in più (richiesta del
## coordinatore del 10 novembre: +1 oggetto a ogni ripartenza, già su main: il perno della porta tagliafuoco del
## risveglio, rimasto orfano). Partenze F9 Torre e F9 Inseguimento; per ognuna [constant MORTI] morti di fila. Le prime
## due ripartenze scaldano le cache (la torre, alla seconda, +44 oggetti e +40 risorse) e la seconda fa da base: fino
## all'ultima gli oggetti, i nodi, gli orfani e le risorse non devono crescere. A ogni morte stampa le misure e cosa cambia (array e
## dizionari degli autoload e delle cache statiche, connessioni dei segnali degli autoload).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_oggetti_morti.gd

const PARTENZE := ["torre", "inseguimento"]
const MORTI := 6

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


## Il giocatore nuovo in gioco (non quello di instance id [param vecchio]), poi la sala si sistema.
func _aspetta_giocatore(vecchio: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		var p := GameState.player
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and p and is_instance_valid(p) \
				and p.get_instance_id() != vecchio and p.is_inside_tree() and not GameState.is_dying \
				and not GameState.is_restoring():
			break
	await Game.aspetta_caricamenti(get_tree().current_scene, 60.0)
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 4000:
		await get_tree().process_frame


func _connessioni() -> Dictionary:
	var out := {}
	for n in get_tree().root.get_children():
		if n == get_tree().current_scene or n == self:
			continue
		var tot := 0
		for s in n.get_signal_list():
			tot += n.get_signal_connection_list(s["name"]).size()
		out[String(n.name)] = tot
	return out


## Le dimensioni di array e dizionari degli autoload e delle cache statiche degli script con class_name.
func _contenitori() -> Dictionary:
	var out := {}
	for n in get_tree().root.get_children():
		if n == get_tree().current_scene or n == self:
			continue
		for pr in n.get_property_list():
			if pr["type"] == TYPE_ARRAY or pr["type"] == TYPE_DICTIONARY:
				var v = n.get(pr["name"])
				if v != null:
					out["%s.%s" % [n.name, pr["name"]]] = (v as Variant).size()
	for c in ProjectSettings.get_global_class_list():
		var scr := load(String(c["path"])) as Script
		if scr == null:
			continue
		for pr in scr.get_script_property_list():
			if pr["type"] == TYPE_ARRAY or pr["type"] == TYPE_DICTIONARY:
				var v = scr.get(pr["name"])
				if v != null:
					out["%s.%s" % [c["class"], pr["name"]]] = (v as Variant).size()
	return out


## Quanti orfani in tutto, quanti in cima e quanti nodi sotto quelli in cima (se i conti non tornano, uno ha un
## genitore che non è un orfano: è dentro un oggetto che lo tiene); e gli orfani che non stanno sotto nessuno in cima.
func _conti_orfani() -> String:
	var ids := Node.get_orphan_node_ids()
	var sotto := 0
	var cima := 0
	var dentro := {}
	for id in ids:
		var n := instance_from_id(id) as Node
		if n and n.get_parent() == null:
			cima += 1
			sotto += 1 + n.find_children("*", "", true, false).size()
			dentro[id] = true
			for c in n.find_children("*", "", true, false):
				dentro[c.get_instance_id()] = true
	var strani: Array[String] = []
	for id in ids:
		if not dentro.has(id):
			var n := instance_from_id(id) as Node
			if n:
				var r: Node = n
				while r.get_parent():
					r = r.get_parent()
				strani.append("%s %s sotto %s %s (nell'albero: %s)" % [n.get_class(), n.name, r.get_class(), r.name, r.is_inside_tree()])
	var nomi := {}
	for id in dentro:
		var n := instance_from_id(id) as Node
		if n and n.get_parent() == null:
			var k := "%s %s" % [n.get_class(), n.name]
			nomi[k] = int(nomi.get(k, 0)) + 1
	return "orfani %d, in cima %d con %d nodi (%s); fuori conto: %s" % [ids.size(), cima, sotto, nomi, strani]


func _misura() -> Dictionary:
	return {
		"oggetti": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodi": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orfani": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"risorse": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"connessioni": _connessioni(),
		"contenitori": _contenitori(),
	}


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	for id in PARTENZE:
		GameState.reset_progress()
		MenuProva.parti(get_tree(), id)
		await _aspetta_giocatore(0)
		var misure: Array = []
		for i in MORTI:
			var vecchio := GameState.player.get_instance_id()
			GameState.kill_player()
			await _aspetta_giocatore(vecchio)
			var m := _misura()
			misure.append(m)
			var diff := ""
			if i > 0:
				var a: Dictionary = misure[i - 1]
				diff = " (%+d oggetti, %+d nodi, %+d orfani, %+d risorse)" % [m["oggetti"] - a["oggetti"], m["nodi"] - a["nodi"],
						m["orfani"] - a["orfani"], m["risorse"] - a["risorse"]]
				var cambiate: Array[String] = []
				for k in m["connessioni"]:
					if int(m["connessioni"][k]) != int(a["connessioni"].get(k, 0)):
						cambiate.append("connessioni %s %+d" % [k, int(m["connessioni"][k]) - int(a["connessioni"].get(k, 0))])
				for k in m["contenitori"]:
					if int(m["contenitori"][k]) != int(a["contenitori"].get(k, 0)):
						cambiate.append("%s %+d" % [k, int(m["contenitori"][k]) - int(a["contenitori"].get(k, 0))])
				if not cambiate.is_empty():
					diff += " cambiati: " + ", ".join(cambiate)
			print("   ", _conti_orfani())
			print("%s, MORTE %d: %d oggetti, %d nodi, %d orfani, %d risorse%s" % [id, i + 1, m["oggetti"], m["nodi"], m["orfani"], m["risorse"], diff])
		var base: Dictionary = misure[1]
		var ultimo: Dictionary = misure[MORTI - 1]
		for k in ["oggetti", "nodi", "orfani", "risorse"]:
			check(int(ultimo[k]) - int(base[k]) <= 0, "%s: %s dalla seconda alla %d ripartenza %+d (0 in più)" % [id, k, MORTI, int(ultimo[k]) - int(base[k])])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
