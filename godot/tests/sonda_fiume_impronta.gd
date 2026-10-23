extends Node
## Sonda: scrive le posizioni di tutti i nodi del fiume e dell'infermeria costruiti (scena di prova della Risalita),
## per confrontare due versioni del codice che li costruisce.
## Con "pezzi" le stanze si rifanno come a gioco avviato (il capannone a pezzi), usando intanto il generatore comune
## a ogni fotogramma come fanno le luci che sfarfallano.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_fiume_impronta.gd <file> [pezzi]

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	for i in 20:
		await get_tree().process_frame
	var ris := get_tree().current_scene.get_node(^"Risalita")
	if OS.get_cmdline_user_args().has("pezzi"):
		# (ferma: il suo _process le rifarebbe subito, tutte insieme)
		ris.process_mode = Node.PROCESS_MODE_DISABLED
		# i file tenuti in memoria, come quando li carica il thread
		var tenuti := []
		for percorso in JSON.parse_string(FileAccess.get_file_as_string(ris.get(&"ELENCO_RISORSE"))):
			tenuti.append(load(percorso))
		ris.call(&"_togli_stanze")
		await get_tree().process_frame
		ris.call(&"_costruisci_stanze", load(ris.get(&"SCENA_FIUME")), load(ris.get(&"SCENA_INFERMERIA")))
		var f := 0
		while ris.get(&"fiume") == null:
			randf()
			await get_tree().process_frame
			f += 1
		print("SONDA a pezzi in %d fotogrammi" % f)
		await get_tree().process_frame
	var righe := PackedStringArray()
	for nome in ["Fiume", "Infermeria"]:
		var r := ris.get_node(NodePath(nome))
		for n in r.find_children("*", "Node3D", true, false):
			var t := (n as Node3D).global_transform
			var parti := PackedStringArray()
			for x in String(ris.get_path_to(n)).split("/"):
				parti.append("@" if x.contains("@") else x)
			righe.append("%s %s %s" % ["/".join(parti), t.origin.snapped(Vector3.ONE * 0.001), t.basis.get_euler().snapped(Vector3.ONE * 0.001)])
	var f := FileAccess.open(OS.get_cmdline_user_args()[1], FileAccess.WRITE)
	f.store_string("\n".join(righe))
	f.close()
	print("SONDA %d nodi" % righe.size())
	Game.esci(0)
