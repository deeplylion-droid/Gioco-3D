extends Node
## Collaudo dei passi lunghi della sala (#147, ambienti-1): le posizioni di tutto quello che c'è nella sala dopo che la
## torre si è costruita nel gioco vero (acquari comparsi, enigma risolto, portone aperto), per confrontare due versioni
## del codice di Posa (Posa.mesh_vicine contro tutte le mesh). Scrive in un file, per ogni Node3D fuori dal giocatore,
## il percorso e la trasformazione nel mondo (al decimo di millimetro), e stampa l'md5 e le 7 lampade d'emergenza.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/posa_prima_dopo.gd <file>

const LEVEL := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var uscita: String = a[1] if a.size() > 1 else "/tmp/posizioni.txt"
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene
	for i in 30:
		await get_tree().process_frame
	var portone := level.get(&"portone") as PortoneTorre
	var enigma := level.get_node_or_null(^"Gioco/EnigmaAcquari")
	if enigma:
		enigma.emit_signal(&"comparso")
	await get_tree().process_frame
	portone.apri_quando_pronta()
	var t0 := Time.get_ticks_msec()
	while not portone.in_movimento and Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
	for i in 60:
		await get_tree().process_frame
	var torre: Node3D = level.get(&"sala_torre")
	print("POSA: torre costruita ", torre != null and bool(torre.get(&"costruita")))
	var giocatore := GameState.player as Node
	var righe: PackedStringArray = []
	for n in level.find_children("*", "Node3D", true, false):
		if giocatore and (n == giocatore or giocatore.is_ancestor_of(n)):
			continue
		var t := (n as Node3D).global_transform
		var v: Array = [t.origin.x, t.origin.y, t.origin.z, t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y,
				t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z]
		var s := PackedStringArray()
		for x in v:
			s.append("%.4f" % x)
		righe.append("%s %s" % [level.get_path_to(n), " ".join(s)])
	var testo := "\n".join(righe)
	var f := FileAccess.open(uscita, FileAccess.WRITE)
	f.store_string(testo)
	f.close()
	print("POSA: %d nodi, md5 %s" % [righe.size(), testo.md5_text()])
	var luci := torre.get_node_or_null(^"Luci") if torre else null
	for c in (luci.get_children() if luci else []):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			var p := (c as Node3D).global_position
			print("POSA: emergenza %s %.4f %.4f %.4f" % [c.name, p.x, p.y, p.z])
	Game.esci(0)
