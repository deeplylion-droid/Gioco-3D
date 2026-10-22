extends Node
## Collaudo: quanta memoria prende la sala principale, passo per passo (per capire cosa la fa uscire dai 15 GB).
## Uso: come giro.gd, argomenti: <scena> [nodi da togliere] [classi da togliere]

func _rss() -> String:
	var out := ""
	for r in FileAccess.get_file_as_string("/proc/self/status").split("\n"):
		if r.begins_with("VmRSS") or r.begins_with("VmHWM"):
			out += r.replace("\t", " ") + "  "
	print("   ", out)
	return out

func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	_run.call_deferred()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("basso")
	print("inizio "); _rss(); print("")
	var livello := (load(a[1]) as PackedScene).instantiate()
	print("istanziata "); _rss(); print("")
	if a.size() > 2:
		for p in a[2].split(",", false):
			var n := livello.get_node_or_null(NodePath(p))
			if n:
				n.get_parent().remove_child(n)
				n.free()
	if a.size() > 3:
		for classe in a[3].split(",", false):
			for n in livello.find_children("*", classe, true, false):
				n.get_parent().remove_child(n)
				n.free()
	print("tolti "); _rss(); print("")
	get_tree().root.add_child(livello)
	print("nell'albero "); _rss(); print("")
	for i in 400:
		await get_tree().process_frame
		if i in [0, 1, 5, 20, 60, 120, 200, 300, 399]:
			print("frame %d " % i); _rss(); print("")
	get_tree().quit()
