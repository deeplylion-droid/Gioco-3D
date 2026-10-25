extends Node
## Test della voce Continua del titolo (GameState.continue_from_disk):
## - senza salvataggio la voce non c'è, e la prima voce è Nuova partita;
## - con un salvataggio valido Continua è la prima voce, con lo stile delle altre; con uno guasto (versione vecchia,
##   JSON rotto) non c'è;
## - per ogni partenza del menu di prova (res://assets/prova/<id>.json, un checkpoint per zona) usata come salvataggio
##   su disco: Continua apre la sala dalla schermata di caricamento, il giocatore sta al checkpoint, con le luci, lo zaino
##   pieno e le Polaroid del salvataggio; ogni checkpoint più avanti nella stessa zona riscrive il salvataggio su disco; dopo
##   una morte si riparte dallo stesso checkpoint;
## - dopo una chiusura (i progressi in memoria azzerati, di nuovo il titolo) Continua riparte dall'ultimo checkpoint
##   scritto su disco;
## - un crash vero (due processi): con "crash_prima" il processo continua, raggiunge un checkpoint e si uccide da solo
##   (con un file temporaneo rotto a metà scrittura); con "crash_dopo" un processo nuovo continua da lì.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_continua.gd [id,id]

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = true
	var solo := PackedStringArray()
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		if args[1] == "crash_prima":
			await _crash_prima()
			return
		if args[1] == "crash_dopo":
			await _crash_dopo()
			print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
			get_tree().quit(1 if _ko > 0 else 0)
			return
		solo = args[1].split(",")
	await _titolo_senza_e_con()
	var prima := true
	for p in MenuProva.disponibili():
		var id: String = p["id"]
		if id == "inizio" or (not solo.is_empty() and not id in solo):
			continue
		print("== ", id)
		await _continua_da(id, prima)
		prima = false
	_cancella()
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _cancella() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))


func _scrivi(testo: String) -> void:
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(testo)
	f.close()


func _apri_titolo() -> Node:
	get_tree().change_scene_to_file(TITOLO)
	for i in 20:
		await get_tree().process_frame
	return get_tree().current_scene


func _nomi(t: Node) -> Array:
	return (t.call(&"voci") as Array).map(func(b): return String((b as Button).name))


func _titolo_senza_e_con() -> void:
	print("== titolo")
	_cancella()
	var t := await _apri_titolo()
	_check(not "Continua" in _nomi(t) and _nomi(t)[0] == "NuovaPartita",
			"senza salvataggio Continua non c'è e la prima voce è Nuova partita (%s)" % [_nomi(t)])
	# un salvataggio guasto non conta
	_scrivi("{rotto")
	t = await _apri_titolo()
	_check(not "Continua" in _nomi(t), "con un salvataggio rotto Continua non c'è")
	var d := MenuProva.istantanea("risalita")
	d["version"] = GameState.SAVE_VERSION + 1
	_scrivi(JSON.stringify(d))
	t = await _apri_titolo()
	_check(not "Continua" in _nomi(t), "con un salvataggio di un'altra versione Continua non c'è")
	# uno valido
	_scrivi(JSON.stringify(MenuProva.istantanea("risalita")))
	t = await _apri_titolo()
	var voci: Array = t.call(&"voci")
	_check(_nomi(t) == ["Continua", "NuovaPartita", "Opzioni", "Comandi", "Esci"],
			"con un salvataggio valido Continua è la prima voce (%s)" % [_nomi(t)])
	if voci.size() > 1:
		var c := voci[0] as Button
		var n := voci[1] as Button
		_check(c.text == "CONTINUA" and c.get_theme_font(&"font") == n.get_theme_font(&"font")
				and c.get_theme_font_size(&"font_size") == n.get_theme_font_size(&"font_size")
				and c.size.x == n.size.x, "Continua ha lo stile delle altre voci (%s)" % c.text)
		for i in 5:
			await get_tree().process_frame
		_check(t.get_viewport().gui_get_focus_owner() == c, "Continua ha il focus")


func _continua_da(id: String, chiusura: bool) -> void:
	var d := MenuProva.istantanea(id)
	_check(not d.is_empty(), "%s: l'istantanea si legge" % id)
	if d.is_empty():
		return
	_scrivi(JSON.stringify(d))
	var t := await _apri_titolo()
	_check(_nomi(t)[0] == "Continua", "%s: nel titolo c'è Continua" % id)
	(t.call(&"voci")[0] as Button).pressed.emit()
	await _aspetta_ripresa()
	var pl := GameState.player
	var level := get_tree().current_scene
	_check(level != null and level.scene_file_path == d["scene"] and pl != null, "%s: la sala è aperta, col giocatore" % id)
	if pl == null:
		return
	var pos: Array = d["player"]["position"]
	var spawn := Vector3(pos[0], pos[1], pos[2])
	_check(pl.global_position.distance_to(spawn) < 1.5, "%s: il giocatore al checkpoint (a %.2f m)" % [id, pl.global_position.distance_to(spawn)])
	_check(String(GameState.snapshot.get("checkpoint", "")) == d["checkpoint"], "%s: checkpoint %s" % [id, GameState.snapshot.get("checkpoint", "")])
	_check(int(GameState.luci) == int(d["luci"]), "%s: luci %d" % [id, GameState.luci])
	_check(pl.has_item(&"zaino_pompa") and pl.water_pack and pl.water_pack.tank_amount > 0.0, "%s: zaino con l'acqua" % id)
	var polaroid: Array = (d["collectibles"] as Dictionary).get("polaroid", [])
	_check(GameState.get_collected_count(&"polaroid") == polaroid.size(), "%s: %d Polaroid raccolte" % [id, polaroid.size()])
	for i in 30:
		await get_tree().physics_frame
	# i checkpoint più avanti: ognuno riscrive il salvataggio su disco
	var cps: Array = get_tree().root.find_children("*", "Checkpoint", true, false)
	# (quelli della stessa zona: il primo pezzo della chiave, per esempio Risalita, SalaTorre, SalaSottomarino)
	var zona := String(d["checkpoint"]).get_slice("/", 0)
	cps = cps.filter(func(c): return (c as Checkpoint).order > int(d["order"]) \
			and GameState.persist_key(c).get_slice("/", 0) == zona)
	cps.sort_custom(func(a, b): return (a as Checkpoint).order < (b as Checkpoint).order)
	var scritti := 0
	var non_scritti := []
	var ultimo: Checkpoint = null
	for cp: Checkpoint in cps:
		GameState.reach_checkpoint(cp)
		var su_disco := GameState.salvataggio()
		if String(su_disco.get("checkpoint", "")) == GameState.persist_key(cp) and int(su_disco.get("order", -9)) == cp.order:
			scritti += 1
			ultimo = cp
		else:
			non_scritti.append("%s (%d)" % [GameState.persist_key(cp), cp.order])
	_check(non_scritti.is_empty(), "%s: %d checkpoint più avanti, tutti scritti su disco (non scritti: %s)" % [id, cps.size(), non_scritti])
	# una morte: si riparte dall'ultimo checkpoint raggiunto
	var atteso := ultimo.get_spawn_transform().origin if ultimo else spawn
	# (la chiave subito: dopo la morte la sala si ricarica e il nodo non c'è più)
	var chiave := GameState.persist_key(ultimo) if ultimo else ""
	GameState.respawn()
	await _aspetta_ripresa()
	pl = GameState.player
	_check(pl != null and pl.global_position.distance_to(atteso) < 1.5, "%s: dopo una morte di nuovo all'ultimo checkpoint" % id)
	if not chiusura or chiave == "":
		return
	# una chiusura: i progressi in memoria si perdono, resta il disco; dal titolo Continua riparte da lì
	GameState.reset_progress()
	t = await _apri_titolo()
	_check(_nomi(t)[0] == "Continua", "%s, dopo la chiusura: nel titolo c'è Continua" % id)
	(t.call(&"voci")[0] as Button).pressed.emit()
	await _aspetta_ripresa()
	pl = GameState.player
	_check(pl != null and pl.global_position.distance_to(atteso) < 1.5 and String(GameState.snapshot.get("checkpoint", "")) == chiave,
			"%s, dopo la chiusura: Continua riparte dall'ultimo checkpoint scritto (%s)" % [id, chiave])


## Il crash, prima parte (un processo a sé): Continua dalla partenza del fiume, il checkpoint più avanti nella zona,
## poi il processo si uccide da solo senza uscire (kill -9), con anche un file temporaneo rotto, come se la scrittura
## successiva si fosse interrotta. Scrive in user://crash_atteso.json il checkpoint e il posto dove si deve ripartire.
func _crash_prima() -> void:
	_scrivi(JSON.stringify(MenuProva.istantanea("fiume")))
	var t := await _apri_titolo()
	(t.call(&"voci")[0] as Button).pressed.emit()
	await _aspetta_ripresa()
	var d := GameState.snapshot
	var zona := String(d["checkpoint"]).get_slice("/", 0)
	var cps: Array = get_tree().root.find_children("*", "Checkpoint", true, false).filter(func(c):
		return (c as Checkpoint).order > int(d["order"]) and GameState.persist_key(c).get_slice("/", 0) == zona)
	cps.sort_custom(func(a, b): return (a as Checkpoint).order < (b as Checkpoint).order)
	var cp := cps[0] as Checkpoint
	GameState.reach_checkpoint(cp)
	var o := cp.get_spawn_transform().origin
	var f := FileAccess.open("user://crash_atteso.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checkpoint": GameState.persist_key(cp), "position": [o.x, o.y, o.z]}))
	f.close()
	f = FileAccess.open(GameState.SAVE_PATH + ".tmp", FileAccess.WRITE)
	f.store_string("{\"version\": 1, \"scene\": ")
	f.close()
	print("CRASH: checkpoint %s scritto, il processo si uccide" % GameState.persist_key(cp))
	OS.kill(OS.get_process_id())


## Il crash, seconda parte (un processo nuovo): nel titolo c'è Continua, e riparte dal checkpoint scritto prima del
## crash.
func _crash_dopo() -> void:
	print("== dopo il crash")
	var atteso = JSON.parse_string(FileAccess.get_file_as_string("user://crash_atteso.json"))
	_check(typeof(atteso) == TYPE_DICTIONARY, "il processo di prima ha scritto cosa aspettarsi")
	if typeof(atteso) != TYPE_DICTIONARY:
		return
	var t := await _apri_titolo()
	_check(_nomi(t)[0] == "Continua", "dopo il crash nel titolo c'è Continua (%s)" % [_nomi(t)])
	if _nomi(t)[0] != "Continua":
		return
	(t.call(&"voci")[0] as Button).pressed.emit()
	await _aspetta_ripresa()
	var pl := GameState.player
	var p: Array = atteso["position"]
	var o := Vector3(p[0], p[1], p[2])
	_check(pl != null and pl.global_position.distance_to(o) < 1.5 and String(GameState.snapshot.get("checkpoint", "")) == atteso["checkpoint"],
			"dopo il crash Continua riparte dall'ultimo checkpoint (%s)" % atteso["checkpoint"])
	_cancella()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://crash_atteso.json"))


func _aspetta_ripresa() -> void:
	# (in tempo vero: la sala si carica in un thread, e nel sandbox la prima volta ci mette minuti)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and s.scene_file_path != TITOLO \
				and GameState.player and is_instance_valid(GameState.player) and not GameState.is_restoring():
			break
	for i in 30:
		await get_tree().process_frame
