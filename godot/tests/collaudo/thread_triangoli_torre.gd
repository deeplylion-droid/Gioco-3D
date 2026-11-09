extends Node
## Collaudo dei passi lunghi della sala (#147, secondo giro, ambienti-1): il thread nuovo dei triangoli delle luci della
## torre (SalaTorre._prepara_triangoli_luci) interrotto. Strada del portone (acquari comparsi, enigma risolto): appena
## la torre nascosta arriva ai triangoli (i passi delle luci pronti, il nodo Luci non ancora), si fa una di queste:
## - "titolo": Game.return_to_title(), poi 5 s nel titolo;
## - "esci": Game.esci(0) subito;
## - "morte": si aspetta il portone che si apre, e appena si muove GameState.respawn(), poi la torre di nuovo costruita.
## Il log va letto da chi lancia: niente "Lambda capture", errori di script o crash; il codice d'uscita è 0.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/thread_triangoli_torre.gd titolo|esci|morte

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cosa: String = a[1] if a.size() > 1 else "titolo"
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
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
	if cosa == "morte":
		var t0 := Time.get_ticks_msec()
		while not portone.in_movimento and Time.get_ticks_msec() - t0 < 300000:
			await get_tree().process_frame
		print("THREAD: il portone si apre, muoio subito")
		GameState.respawn()
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 600000:
			await get_tree().process_frame
			var s := get_tree().current_scene
			if s and s.scene_file_path == "res://scenes/sala_principale.tscn" and GameState.player \
					and not GameState.is_restoring() and Time.get_ticks_msec() - t1 > 3000:
				break
		for i in 120:
			await get_tree().process_frame
		var s2 := get_tree().current_scene
		var torre: Node = s2.get(&"sala_torre") if s2 else null
		print("THREAD: dopo la morte torre ", torre != null, " costruita ", torre != null and bool(torre.get(&"costruita")))
		print("THREAD: FINE")
		Game.esci(0)
		return
	# aspetta che la torre nascosta arrivi ai triangoli delle luci
	var t0 := Time.get_ticks_msec()
	var torre: Node = null
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		torre = level.get(&"_torre_nascosta")
		if torre and (torre.get(&"_passo_luci") as Callable).is_valid() and torre.get_node_or_null(^"Luci") == null:
			break
	print("THREAD: la torre è ai triangoli delle luci: ", torre != null)
	await get_tree().process_frame
	await get_tree().process_frame
	if cosa == "esci":
		print("THREAD: esco")
		Game.esci(0)
		return
	print("THREAD: torno al titolo")
	Game.return_to_title()
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 60000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == Game.SCENE_TITLE:
			break
	for i in 300:
		await get_tree().process_frame
	print("THREAD: nel titolo ", get_tree().current_scene.scene_file_path if get_tree().current_scene else "?")
	print("THREAD: FINE")
	Game.esci(0)
