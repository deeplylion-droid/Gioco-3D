extends Node
## Test della voce Continua del titolo (GameState.continue_from_disk):
## - senza salvataggio la voce non c'è, e la prima voce è Nuova partita;
## - con un salvataggio valido Continua è la prima voce, con lo stile delle altre; con uno guasto (versione vecchia,
##   JSON rotto) non c'è; se il salvataggio manca o è guasto ma c'è il file temporaneo completo (su Windows un crash fra
##   la cancellazione e il rename), vale quello e diventa il salvataggio; la prima partenza qui sotto parte così;
## - per ogni partenza del menu di prova (res://assets/prova/<id>.json, un checkpoint per zona) usata come salvataggio
##   su disco: Continua apre la sala dalla schermata di caricamento, il giocatore sta al checkpoint, con le luci, lo zaino
##   pieno e le Polaroid del salvataggio; ogni checkpoint più avanti nella stessa zona riscrive il salvataggio su disco; dopo
##   una morte si riparte dallo stesso checkpoint;
## - dopo una chiusura (i progressi in memoria azzerati, di nuovo il titolo) Continua riparte dall'ultimo checkpoint
##   scritto su disco;
## - Nuova partita e uscita prima del primo checkpoint: il salvataggio di prima resta (si scrive su disco solo dal primo
##   checkpoint vero);
## - gli interni ("interni"): durante la scena del risveglio nessun checkpoint (su disco resta quello di prima: chi esce lì
##   la rivede da capo); a scena finita il checkpoint del risveglio, poi gli altri 5 entrandoci: ognuno si scrive su disco
##   (prima, con l'ordine da -10 a -5 sotto l'istantanea "inizio", si scartavano tutti); Continua da ognuno riparte lì, con
##   le luci e lo zaino (preso nello stanzino), senza rifare la scena del risveglio; poi una morte riparte dall'ultimo;
## - un crash vero (due processi): con "crash_prima" il processo continua, raggiunge un checkpoint e si uccide da solo
##   (con un file temporaneo rotto a metà scrittura); con "crash_dopo" un processo nuovo continua da lì.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_continua.gd [id,id]

const TITOLO := "res://scenes/ui/menu_principale.tscn"
const TEMPORANEO := GameState.SAVE_PATH + ".tmp"

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
	if solo.is_empty() or "interni" in solo:
		await _interni()
	if solo.is_empty() or "nuova" in solo:
		await _nuova_partita_non_cancella()
	_cancella()
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


## Nuova partita, poi si esce prima del primo checkpoint (collaudo di Continua): il salvataggio di prima resta, e nel
## titolo c'è ancora Continua. (Come la voce Nuova partita dopo lo spot: progressi azzerati, sala dal caricamento.)
func _nuova_partita_non_cancella() -> void:
	print("== nuova partita")
	var d := MenuProva.istantanea("torre")
	_scrivi(JSON.stringify(d))
	GameState.reset_progress()
	get_tree().change_scene_to_file(GameState.SCENA_CARICAMENTO)
	await _aspetta_ripresa()
	_check(GameState.player != null and String(GameState.snapshot.get("checkpoint", "")) == "inizio",
			"nuova partita: la sala è aperta, dall'inizio")
	_check(String(GameState.salvataggio().get("checkpoint", "")) == d["checkpoint"],
			"nuova partita: prima del primo checkpoint il salvataggio di prima c'è ancora (%s)" % GameState.salvataggio().get("checkpoint", "-"))
	var t := await _apri_titolo()
	_check(_nomi(t)[0] == "Continua", "uscendo prima del primo checkpoint, nel titolo c'è ancora Continua")


## I checkpoint degli interni (collaudo di Continua di ambienti-1, difetto del 15 ottobre): vedi in cima.
func _interni() -> void:
	print("== interni")
	var prima := MenuProva.istantanea("torre")
	_cancella()
	_scrivi(JSON.stringify(prima))
	GameState.reset_progress()
	get_tree().change_scene_to_file(GameState.SCENA_CARICAMENTO)
	await _aspetta_ripresa(false)
	var interni := get_tree().current_scene.get_node_or_null(^"Interni") if get_tree().current_scene else null
	var p := GameState.player
	_check(interni != null and p != null, "interni: nuova partita, la sala è aperta")
	if interni == null or p == null:
		return
	var cps: Array = interni.find_children("*", "Checkpoint", true, false)
	cps.sort_custom(func(a, b): return (a as Checkpoint).order < (b as Checkpoint).order)
	_check(cps.size() == 6 and (cps[0] as Node).name == "CheckpointRisveglio", "interni: 6 checkpoint, il primo è quello del risveglio (%s)" % [cps.map(func(c): return c.name)])
	if cps.size() != 6:
		return
	_check(not p.input_enabled and String(GameState.snapshot.get("checkpoint", "")) == "inizio"
			and String(GameState.salvataggio().get("checkpoint", "")) == prima["checkpoint"],
			"interni: durante la scena del risveglio nessun checkpoint, su disco resta quello di prima (%s)" % GameState.salvataggio().get("checkpoint", "-"))
	var t0 := Time.get_ticks_msec()
	while not p.input_enabled and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().physics_frame
	for i in 10:
		await get_tree().physics_frame
	# i checkpoint uno dopo l'altro, entrandoci: si salva quello che c'è su disco dopo ognuno
	var salvati := []
	for cp: Checkpoint in cps:
		var chiave := GameState.persist_key(cp)
		if cp.name == "CheckpointLavapiedi":
			(interni.get_node(^"Zaino/Prendi") as Interactable).interact(p)
		if cp.name != "CheckpointRisveglio":
			var sp := cp.get_spawn_transform()
			p.teleport(sp.origin, p.yaw, 0.0)
			for i in 20:
				await get_tree().physics_frame
		var su_disco := GameState.salvataggio()
		_check(String(GameState.snapshot.get("checkpoint", "")) == chiave and String(su_disco.get("checkpoint", "")) == chiave
				and int(su_disco.get("order", 0)) == cp.order, "interni: %s (%d) raggiunto e scritto su disco (%s)" % [cp.name, cp.order, su_disco.get("checkpoint", "-")])
		salvati.append([cp.name, chiave, cp.get_spawn_transform().origin, FileAccess.get_file_as_string(GameState.SAVE_PATH)])
	# Continua da ognuno, dopo una chiusura
	for s in salvati:
		var nome: String = s[0]
		var d = JSON.parse_string(s[3])
		_scrivi(s[3])
		GameState.reset_progress()
		var t := await _apri_titolo()
		_check(_nomi(t)[0] == "Continua", "interni, %s: nel titolo c'è Continua" % nome)
		(t.call(&"voci")[0] as Button).pressed.emit()
		await _aspetta_ripresa()
		await _ripresa_interni(nome, s[1], s[2], d)
	# una morte nell'ultimo (negli interni non c'è niente che uccide: la ripartenza dopo una morte si prova lo stesso)
	var ultimo: Array = salvati[-1]
	GameState.respawn()
	await _aspetta_ripresa()
	await _ripresa_interni(String(ultimo[0]) + " dopo una morte", ultimo[1], ultimo[2], JSON.parse_string(ultimo[3]))


func _ripresa_interni(nome: String, chiave: String, posto: Vector3, d: Dictionary) -> void:
	var p := GameState.player
	var interni := get_tree().current_scene.get_node_or_null(^"Interni") if get_tree().current_scene else null
	_check(p != null and interni != null and String(GameState.snapshot.get("checkpoint", "")) == chiave
			and p.global_position.distance_to(posto) < 0.5, "interni, %s: riparte dal checkpoint (a %.2f m)" % [nome, p.global_position.distance_to(posto) if p else -1.0])
	if p == null or interni == null:
		return
	_check(int(GameState.luci) == int(d["luci"]), "interni, %s: luci %d (salvate %d)" % [nome, GameState.luci, int(d["luci"])])
	var zaino := (d["player"]["inventory"] as Dictionary).has("zaino_pompa")
	var acqua := float(d["player"]["water"])
	_check(p.has_item(&"zaino_pompa") == zaino and (p.water_pack == null or p.water_pack.equipped == zaino)
			and (not zaino or absf(p.water_pack.tank_amount - acqua) < 0.01)
			and (interni.get_node_or_null(^"Zaino") == null) == zaino,
			"interni, %s: zaino %s, come nel salvataggio (oggetto %s, addosso %s, acqua %.1f, sulla rastrelliera %s)" % [nome,
			"preso" if zaino else "ancora nello stanzino", p.has_item(&"zaino_pompa"), p.water_pack.equipped if p.water_pack else null,
			p.water_pack.tank_amount if p.water_pack else -1.0, interni.get_node_or_null(^"Zaino") != null])
	var squalo := interni.get_node_or_null(^"Gioco/RisveglioSqualo") as RisveglioSqualo
	_check(p.input_enabled and absf(p.camera.rotation.z) < 0.01 and absf(p.camera.position.y) < 0.01 and squalo and not squalo.in_corso(),
			"interni, %s: la scena del risveglio non riparte" % nome)


func _cancella() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMPORANEO))


func _scrivi(testo: String, percorso := GameState.SAVE_PATH) -> void:
	var f := FileAccess.open(percorso, FileAccess.WRITE)
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
	# solo il file temporaneo, completo (su Windows il rename cancella prima il salvataggio: un crash lì lascia solo lui)
	var r := MenuProva.istantanea("risalita")
	_cancella()
	_scrivi(JSON.stringify(r), TEMPORANEO)
	t = await _apri_titolo()
	_check("Continua" in _nomi(t) and FileAccess.file_exists(GameState.SAVE_PATH) and not FileAccess.file_exists(TEMPORANEO)
			and String(GameState.salvataggio().get("checkpoint", "")) == r["checkpoint"],
			"senza salvataggio ma col file temporaneo completo c'è Continua, e il temporaneo diventa il salvataggio")
	# guasto, col temporaneo completo
	_scrivi("{rotto")
	_scrivi(JSON.stringify(r), TEMPORANEO)
	t = await _apri_titolo()
	_check("Continua" in _nomi(t) and not FileAccess.file_exists(TEMPORANEO) and String(GameState.salvataggio().get("checkpoint", "")) == r["checkpoint"],
			"con un salvataggio rotto ma il file temporaneo completo c'è Continua, dal temporaneo")
	# guasto, col temporaneo rotto a metà scrittura
	_scrivi("{rotto")
	_scrivi("{\"version\": %d, \"scene\": " % GameState.SAVE_VERSION, TEMPORANEO)
	t = await _apri_titolo()
	_check(not "Continua" in _nomi(t), "con il salvataggio e il file temporaneo rotti Continua non c'è")
	_cancella()
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
	await _joypad_conferma()


## A del joypad conferma la voce col focus (collaudo di ambienti-1: ui_accept aveva solo Invio, Invio del tastierino e
## Spazio), e nel gioco non fa nient'altro: non è in nessuna azione del giocatore.
func _joypad_conferma() -> void:
	var altre := InputMap.get_actions().filter(func(a): return not String(a).begins_with("ui_") \
			and InputMap.action_get_events(a).any(func(e): return e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_A))
	_check(altre.is_empty(), "A del joypad non è in nessuna azione del gioco (%s)" % [altre])
	var b := Button.new()
	b.text = "prova"
	add_child(b)
	b.grab_focus()
	var premuto := [false]
	b.pressed.connect(func(): premuto[0] = true)
	for giu in [true, false]:
		var a := InputEventJoypadButton.new()
		a.button_index = JOY_BUTTON_A
		a.pressed = giu
		Input.parse_input_event(a)
		for i in 3:
			await get_tree().process_frame
	_check(premuto[0], "A del joypad conferma la voce col focus")
	b.queue_free()


func _continua_da(id: String, chiusura: bool) -> void:
	var d := MenuProva.istantanea(id)
	_check(not d.is_empty(), "%s: l'istantanea si legge" % id)
	if d.is_empty():
		return
	_cancella()
	# la prima partenza parte dal solo file temporaneo (il crash nel rename su Windows)
	_scrivi(JSON.stringify(d), TEMPORANEO if chiusura else GameState.SAVE_PATH)
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


func _aspetta_ripresa(attesa := true) -> void:
	# (in tempo vero: la sala si carica in un thread, e nel sandbox la prima volta ci mette minuti)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and s.scene_file_path != TITOLO \
				and GameState.player and is_instance_valid(GameState.player) and not GameState.is_restoring():
			break
	if attesa:
		for i in 30:
			await get_tree().process_frame
