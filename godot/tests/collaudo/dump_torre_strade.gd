extends Node
## Collaudo dei passi lunghi della sala (#147, secondo giro, ambienti-1): la posizione nel mondo di tutto quello che c'è
## nella sala della torre (ogni Node3D, e ogni istanza dei MultiMesh), arrivandoci per le strade del gioco:
## - "portone": acquari comparsi, enigma risolto, la torre si prepara nascosta e il portone si apre;
## - "f9": F9 torre, poi una morte (cache dei varchi piena), un'altra con la cache vuotata, poi Continua dalla torre.
## Un file per strada (<prefisso>_<strada>.txt): percorso dalla torre (i nomi automatici @Classe@N tolti) e
## trasformazione al decimo di millimetro. Poi si confrontano come multinsiemi.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- \
##   res://tests/collaudo/dump_torre_strade.gd <prefisso> portone|f9

var _pref := "/tmp/torre"


func _ready() -> void:
	_run.call_deferred()


func _riga(t: Transform3D) -> String:
	var v: Array = [t.origin.x, t.origin.y, t.origin.z, t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y,
			t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z]
	var s := PackedStringArray()
	for x in v:
		s.append("%.4f" % x)
	return " ".join(s)


func _dump(nome: String) -> void:
	var sala := get_tree().current_scene
	var torre: Node3D = sala.get(&"sala_torre") if sala else null
	if torre == null or not bool(torre.get(&"costruita")):
		print("DUMP %s: torre non costruita" % nome)
		return
	var re := RegEx.create_from_string("@[A-Za-z0-9]+@[0-9]+")
	var righe: PackedStringArray = []
	var istanze := 0
	for n in torre.find_children("*", "Node3D", true, false):
		var p := re.sub(str(torre.get_path_to(n)), "@", true)
		righe.append("%s %s" % [p, _riga((n as Node3D).global_transform)])
		var mmi := n as MultiMeshInstance3D
		if mmi and mmi.multimesh:
			for i in mmi.multimesh.instance_count:
				righe.append("%s#%d %s" % [p, i, _riga(mmi.global_transform * mmi.multimesh.get_instance_transform(i))])
				istanze += 1
	righe.sort()
	var testo := "\n".join(righe)
	var f := FileAccess.open("%s_%s.txt" % [_pref, nome], FileAccess.WRITE)
	f.store_string(testo)
	f.close()
	print("DUMP %s: %d righe (%d istanze di MultiMesh), md5 %s" % [nome, righe.size(), istanze, testo.md5_text()])
	for c in torre.get_node(^"Luci").get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			print("DUMP %s: emergenza %s" % [nome, (c as Node3D).global_position])


func _aspetta_torre() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and GameState.player \
				and is_instance_valid(GameState.player) and not GameState.is_restoring():
			var torre: Node = s.get(&"sala_torre") if &"sala_torre" in s else null
			if torre and bool(torre.get(&"costruita")):
				break
	for i in 60:
		await get_tree().process_frame


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	_pref = a[1] if a.size() > 1 else _pref
	var strada: String = a[2] if a.size() > 2 else "portone"
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	if strada == "portone":
		GameState.reset_progress()
		get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
		for i in 600:
			await get_tree().process_frame
			if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
				break
		var level := get_tree().current_scene
		for i in 30:
			await get_tree().process_frame
		var enigma := level.get_node_or_null(^"Gioco/EnigmaAcquari")
		if enigma:
			enigma.emit_signal(&"comparso")
		await get_tree().process_frame
		var portone := level.get(&"portone") as PortoneTorre
		portone.apri_quando_pronta()
		var t0 := Time.get_ticks_msec()
		while not portone.in_movimento and Time.get_ticks_msec() - t0 < 300000:
			await get_tree().process_frame
		await _aspetta_torre()
		_dump("portone")
	else:
		MenuProva.parti(get_tree(), "torre")
		await _aspetta_torre()
		_dump("f9")
		GameState.respawn()
		await _aspetta_torre()
		_dump("morte")
		SalaInseguimento._varco_cache.clear()
		GameState.respawn()
		await _aspetta_torre()
		_dump("morte_cache_vuota")
		var d := MenuProva.istantanea("torre")
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		GameState.continue_from_disk()
		await _aspetta_torre()
		_dump("continua")
		DirAccess.remove_absolute(GameState.SAVE_PATH)
	Game.esci(0)
