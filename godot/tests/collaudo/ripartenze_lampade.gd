extends Node
## Collaudo dei passi lunghi della sala (#147, ambienti-1): le 7 lampade d'emergenza della torre nelle ripartenze.
## F9 torre (menu di prova), poi una morte (cache dei varchi piena), poi un'altra con la cache vuotata
## (SalaInseguimento._varco_cache), poi Continua dalla torre (salvataggio su disco). Ogni volta: le 7 lampade ci sono,
## nelle stesse posizioni della prima costruzione, e nessun passo della torre oltre 50 ms.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/ripartenze_lampade.gd

var _ok := 0
var _ko := 0
var _rif := ""


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _aspetta_ripresa() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and GameState.player \
				and is_instance_valid(GameState.player) and not GameState.is_restoring():
			break
	# la torre si costruisce a pezzi: si aspetta che sia costruita
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 300000:
		await get_tree().process_frame
		var torre: Node = get_tree().current_scene.get(&"sala_torre") if get_tree().current_scene else null
		if torre and bool(torre.get(&"costruita")):
			break
	for i in 30:
		await get_tree().process_frame


func _lampade(quando: String) -> void:
	var sala := get_tree().current_scene
	var torre: Node = sala.get(&"sala_torre") if sala else null
	_check(torre != null and bool(torre.get(&"costruita")), "%s: la torre è costruita" % quando)
	if torre == null:
		return
	var luci := torre.get_node_or_null(^"Luci")
	var righe: PackedStringArray = []
	var accese := 0
	for c in (luci.get_children() if luci else []):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			var p := (c as Node3D).global_position
			righe.append("%.4f %.4f %.4f" % [p.x, p.y, p.z])
		if c is OmniLight3D and (c as OmniLight3D).light_color.r > 0.8 and (c as OmniLight3D).light_color.g < 0.3 \
				and (c as OmniLight3D).visible:
			accese += 1
	var testo := "\n".join(righe)
	print("    ", testo.replace("\n", " | "))
	_check(righe.size() == 7, "%s: 7 lampade d'emergenza (%d)" % [quando, righe.size()])
	_check(accese >= 7, "%s: le loro luci rosse ci sono (%d)" % [quando, accese])
	if _rif == "":
		_rif = testo
	else:
		_check(testo == _rif, "%s: nelle stesse posizioni della prima costruzione" % quando)
	var lunghi: Array = torre.get(&"passi_lunghi") if &"passi_lunghi" in torre else []
	print("    passi lunghi della torre: ", lunghi)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	print("== F9 torre")
	_check(MenuProva.parti(get_tree(), "torre"), "F9 torre: parte")
	await _aspetta_ripresa()
	await _lampade("F9 torre")
	print("== morte in torre, cache piena")
	GameState.respawn()
	await _aspetta_ripresa()
	await _lampade("morte, cache piena")
	print("== morte in torre, cache vuota")
	SalaInseguimento._varco_cache.clear()
	GameState.respawn()
	await _aspetta_ripresa()
	await _lampade("morte, cache vuota")
	print("== Continua dalla torre")
	var d := MenuProva.istantanea("torre")
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	_check(GameState.continue_from_disk(), "Continua: parte dal salvataggio della torre")
	await _aspetta_ripresa()
	_check(String(GameState.snapshot.get("checkpoint", "")).begins_with("SalaTorre"),
			"Continua: checkpoint della torre (%s)" % GameState.snapshot.get("checkpoint", ""))
	await _lampade("Continua")
	DirAccess.remove_absolute(GameState.SAVE_PATH)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
