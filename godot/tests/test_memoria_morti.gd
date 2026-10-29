extends Node
## Test: morire e ripartire dal checkpoint più volte di fila non fa crescere la memoria (richiesta del coordinatore, 28
## ottobre: +4-5 MB di memoria statica e +100-140 oggetti a ogni ritorno al checkpoint). Si muore [constant MORTI] volte
## nella sala principale; la prima ripartenza scalda le cache e fa da base, poi la crescita media per morte deve restare
## sotto [constant SOGLIA_MB] MB e [constant SOGLIA_OGGETTI] oggetti. Stampa a ogni morte memoria, oggetti, nodi, nodi
## orfani, risorse e le connessioni dei segnali degli autoload (per trovare cosa resta appeso).
## A tempo vero (la ripartenza aspetta i caricamenti nel thread).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_memoria_morti.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const MORTI := 6
const SOGLIA_MB := 0.5
const SOGLIA_OGGETTI := 10.0

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


func _aspetta_giocatore(vecchio: Node) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p != vecchio and p.is_inside_tree() and not GameState.is_dying:
			break
	# la sala nuova si sistema: caricamenti nel thread finiti e qualche secondo di gioco
	await Game.aspetta_caricamenti(get_tree().current_scene, 60.0)
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 3000:
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


## Le dimensioni di array e dizionari degli autoload e delle cache statiche (per trovare cosa cresce).
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
	for c in [Posa, FormeTunnel, SalaSottomarino, SottomarinoArrediA2, ObloLei, RiscaldamentoShader, AttesaZone]:
		var scr := c as Script
		for pr in scr.get_script_property_list():
			if pr["type"] == TYPE_ARRAY or pr["type"] == TYPE_DICTIONARY:
				var v = scr.get(pr["name"])
				if v != null:
					out["%s.%s" % [scr.resource_path.get_file(), pr["name"]]] = (v as Variant).size()
	return out


func _misura() -> Dictionary:
	return {
		"mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"oggetti": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodi": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orfani": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"risorse": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"connessioni": _connessioni(),
		"contenitori": _contenitori(),
	}


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	await _aspetta_giocatore(null)
	var p := GameState.player
	GameState.capture_snapshot("prova_memoria", 0, p.global_transform)
	var misure: Array = []
	for i in MORTI:
		var vecchio := GameState.player
		GameState.kill_player()
		await _aspetta_giocatore(vecchio)
		var m := _misura()
		misure.append(m)
		var diff := ""
		if i > 0:
			var a: Dictionary = misure[i - 1]
			diff = " (%+.2f MB, %+d oggetti, %+d nodi, %+d orfani, %+d risorse)" % [m["mb"] - a["mb"], m["oggetti"] - a["oggetti"],
				m["nodi"] - a["nodi"], m["orfani"] - a["orfani"], m["risorse"] - a["risorse"]]
			var cambiate: Array[String] = []
			for k in m["connessioni"]:
				if int(m["connessioni"][k]) != int(a["connessioni"].get(k, 0)):
					cambiate.append("%s %+d" % [k, int(m["connessioni"][k]) - int(a["connessioni"].get(k, 0))])
			for k in m["contenitori"]:
				if int(m["contenitori"][k]) != int(a["contenitori"].get(k, 0)):
					cambiate.append("%s %+d" % [k, int(m["contenitori"][k]) - int(a["contenitori"].get(k, 0))])
			if not cambiate.is_empty():
				diff += " cambiati: " + ", ".join(cambiate)
		print("MORTE %d: %.2f MB, %d oggetti, %d nodi, %d orfani, %d risorse%s" % [i + 1, m["mb"], m["oggetti"], m["nodi"], m["orfani"], m["risorse"], diff])
	var primo: Dictionary = misure[0]
	var ultimo: Dictionary = misure[-1]
	var n := float(misure.size() - 1)
	var mb := (float(ultimo["mb"]) - float(primo["mb"])) / n
	var ogg := (float(ultimo["oggetti"]) - float(primo["oggetti"])) / n
	check(mb < SOGLIA_MB, "memoria statica per morte, dalla seconda alla %d: %+.2f MB (soglia %.1f)" % [MORTI, mb, SOGLIA_MB])
	check(ogg < SOGLIA_OGGETTI, "oggetti per morte: %+.1f (soglia %.0f)" % [ogg, SOGLIA_OGGETTI])
	if int(ultimo["orfani"]) > 0:
		print_orphan_nodes()
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
