extends Node
## Collaudo di ambienti-1 (25 ottobre sera) di Continua e Nuova partita (lavoro/continua di mascotte), indipendente da
## test_continua.gd: gli input veri (tastiera, joypad, mouse) sul titolo, la ripresa con lo zaino, le Polaroid, le luci e
## l'inventario di quel momento, un checkpoint raggiunto giocando e poi la chiusura; Nuova partita col suo pulsante e lo
## spot saltato tenendo premuto, fino al primo checkpoint; i salvataggi guasti di molti tipi.
## Un caso per processo:
##   <metodo>:<partenza>  metodo = tastiera | joypad | mouse, partenza = un file di res://assets/prova (risalita, torre...)
##   nuova                Nuova partita, uscita prima del primo checkpoint, poi primo checkpoint della partita nuova
##   rotti                salvataggi mancanti, vuoti, rotti, troncati, di un'altra versione, senza scena o giocatore
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo_continua_a1.gd <caso>

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
	var caso: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "rotti"
	print("== ", caso)
	if caso == "rotti":
		await _rotti()
	elif caso == "joypad2":
		await _joypad2()
	elif caso == "tmp":
		await _tmp()
	elif caso == "interni":
		await _interni()
	elif caso == "risveglio":
		await _risveglio_interrotto()
	elif caso == "nuova":
		await _nuova()
	else:
		await _continua(caso.get_slice(":", 0), caso.get_slice(":", 1))
	_cancella()
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


# --- Continua con un input vero -----------------------------------------------------------------

func _continua(metodo: String, id: String) -> void:
	var d := MenuProva.istantanea(id)
	_check(not d.is_empty(), "la partenza %s c'è" % id)
	_scrivi(JSON.stringify(d))
	var t := await _apri_titolo()
	var voci: Array = t.call(&"voci")
	_check(_nomi(t) == ["Continua", "NuovaPartita", "Opzioni", "Comandi", "Esci"], "voci del titolo %s" % [_nomi(t)])
	var vp := t.get_viewport()
	_check(vp.gui_get_focus_owner() == voci[0], "il focus parte su Continua")
	# su e giù col metodo scelto: il focus passa a Nuova partita e torna su Continua
	if metodo != "mouse":
		await _premi(metodo, "giu")
		_check(vp.gui_get_focus_owner() == voci[1], "%s: giù porta il focus su Nuova partita" % metodo)
		await _premi(metodo, "su")
		_check(vp.gui_get_focus_owner() == voci[0], "%s: su lo riporta su Continua" % metodo)
		await _premi(metodo, "conferma")
		if metodo == "joypad" and not bool(t.get(&"_avviato")):
			_check(false, "joypad: A conferma Continua (ui_accept non ha pulsanti del joypad: si conferma con Invio)")
			await _premi("tastiera", "conferma")
	else:
		var c := (voci[0] as Button).get_global_rect().get_center()
		var mm := InputEventMouseMotion.new()
		mm.position = c
		mm.global_position = c
		vp.push_input(mm, true)
		await _frame(3)
		for su in [true, false]:
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = su
			mb.position = c
			mb.global_position = c
			vp.push_input(mb, true)
			await _frame(2)
	_check(bool(t.get(&"_avviato")), "%s: Continua scelto (il titolo parte)" % metodo)
	await _aspetta_ripresa()
	var pl := GameState.player
	_check(pl != null and get_tree().current_scene.scene_file_path == d["scene"], "%s: la sala è aperta col giocatore" % id)
	if pl == null:
		return
	_confronta(pl, d, id)
	# un checkpoint più avanti, raggiunto col corpo del giocatore (non chiamato a mano): la sua area
	var zona := String(d["checkpoint"]).get_slice("/", 0)
	var cps: Array = get_tree().root.find_children("*", "Checkpoint", true, false).filter(func(c):
		return (c as Checkpoint).order > int(d["order"]) and GameState.persist_key(c).get_slice("/", 0) == zona)
	cps.sort_custom(func(a, b): return (a as Checkpoint).order < (b as Checkpoint).order)
	if cps.is_empty():
		_check(false, "%s: un checkpoint più avanti nella zona" % id)
		return
	var cp := cps[0] as Checkpoint
	var chiave := GameState.persist_key(cp)
	pl.call(&"teleport", cp.global_position + Vector3(0, 0.1, 0), pl.rotation.y, 0.0)
	for i in 30:
		await get_tree().physics_frame
	var su_disco := GameState.salvataggio()
	_check(String(su_disco.get("checkpoint", "")) == chiave, "%s: entrando nel checkpoint %s il salvataggio è suo (%s)" % [id, chiave, su_disco.get("checkpoint", "-")])
	var atteso := cp.get_spawn_transform().origin
	var acqua := float((su_disco.get("player", {}) as Dictionary).get("water", -1.0))
	# chiusura: progressi in memoria azzerati, il titolo, Continua (con lo stesso metodo)
	GameState.reset_progress()
	t = await _apri_titolo()
	voci = t.call(&"voci")
	if metodo == "mouse":
		(voci[0] as Button).pressed.emit()
	else:
		await _premi("tastiera", "conferma")
	await _aspetta_ripresa()
	pl = GameState.player
	_check(pl != null and pl.global_position.distance_to(atteso) < 1.5 and String(GameState.snapshot.get("checkpoint", "")) == chiave,
			"%s, dopo la chiusura: riparte da %s (a %.2f m)" % [id, chiave, pl.global_position.distance_to(atteso) if pl else -1.0])
	if pl and pl.water_pack:
		_check(absf(pl.water_pack.tank_amount - acqua) < 0.01, "%s, dopo la chiusura: l'acqua del checkpoint (%.2f / %.2f)" % [id, pl.water_pack.tank_amount, acqua])


## Il giocatore ripreso contro il salvataggio [param d]: posto, checkpoint, luci, inventario, acqua, Polaroid.
func _confronta(pl: Node, d: Dictionary, id: String) -> void:
	var pd: Dictionary = d["player"]
	var pos: Array = pd["position"]
	var spawn := Vector3(pos[0], pos[1], pos[2])
	_check(pl.global_position.distance_to(spawn) < 1.5, "%s: al checkpoint (a %.2f m)" % [id, pl.global_position.distance_to(spawn)])
	_check(String(GameState.snapshot.get("checkpoint", "")) == d["checkpoint"], "%s: checkpoint %s" % [id, d["checkpoint"]])
	_check(int(GameState.luci) == int(d["luci"]), "%s: luci %d (salvate %d)" % [id, GameState.luci, d["luci"]])
	var inv: Dictionary = pd.get("inventory", {})
	var mancano := []
	for k in inv:
		if not pl.has_item(StringName(k)):
			mancano.append(k)
	_check(mancano.is_empty(), "%s: l'inventario %s (mancano %s)" % [id, inv.keys(), mancano])
	var wp = pl.get(&"water_pack")
	var acqua := float(pd.get("water", -1.0))
	_check(wp != null and absf(wp.tank_amount - acqua) < 0.01,
			"%s: lo zaino con %.2f di acqua (salvata %.2f)" % [id, wp.tank_amount if wp else -1.0, acqua])
	var polaroid: Array = (d.get("collectibles", {}) as Dictionary).get("polaroid", [])
	_check(GameState.get_collected_count(&"polaroid") == polaroid.size(), "%s: %d Polaroid, come nel salvataggio %s" % [id, GameState.get_collected_count(&"polaroid"), polaroid])


func _premi(metodo: String, cosa: String) -> void:
	var ev: InputEvent
	if metodo == "tastiera":
		var k := InputEventKey.new()
		k.keycode = {"giu": KEY_DOWN, "su": KEY_UP, "conferma": KEY_ENTER}[cosa]
		k.physical_keycode = k.keycode
		ev = k
	else:
		var j := InputEventJoypadButton.new()
		j.button_index = {"giu": JOY_BUTTON_DPAD_DOWN, "su": JOY_BUTTON_DPAD_UP, "conferma": JOY_BUTTON_A}[cosa]
		ev = j
	for su in [true, false]:
		var e := ev.duplicate() as InputEvent
		e.set(&"pressed", su)
		Input.parse_input_event(e)
		await _frame(3)


# --- Nuova partita ------------------------------------------------------------------------------

func _nuova() -> void:
	var d := MenuProva.istantanea("torre")
	_scrivi(JSON.stringify(d))
	var t := await _apri_titolo()
	await _premi("tastiera", "giu")
	_check(t.get_viewport().gui_get_focus_owner() == t.call(&"voci")[1], "il focus su Nuova partita")
	await _premi("tastiera", "conferma")
	# lo spot: si salta tenendo premuto un tasto
	await _secondi(1.5)
	var k := InputEventKey.new()
	k.keycode = KEY_SPACE
	k.physical_keycode = KEY_SPACE
	k.pressed = true
	Input.parse_input_event(k)
	await _secondi(1.6)
	k = k.duplicate()
	k.pressed = false
	Input.parse_input_event(k)
	await _aspetta_ripresa()
	_check(GameState.player != null and String(GameState.snapshot.get("checkpoint", "")) == "inizio", "nuova partita: la sala dall'inizio")
	_check(String(GameState.salvataggio().get("checkpoint", "")) == d["checkpoint"], "prima del primo checkpoint il salvataggio vecchio c'è ancora (%s; risveglio in corso: %s)" % [GameState.salvataggio().get("checkpoint", "-"), not GameState.player.input_enabled])
	# (una Polaroid raccolta prima del primo checkpoint non deve riscrivere il disco: si prova con collect)
	GameState.collect(&"polaroid", &"prova_collaudo")
	_check(String(GameState.salvataggio().get("checkpoint", "")) == d["checkpoint"], "anche raccogliendo qualcosa prima del primo checkpoint")
	# uscita: il titolo ha ancora Continua, del vecchio salvataggio
	GameState.reset_progress()
	t = await _apri_titolo()
	_check(_nomi(t)[0] == "Continua", "uscendo prima del primo checkpoint, nel titolo c'è ancora Continua")
	# di nuovo Nuova partita, fino al primo checkpoint della sala (il più basso), raggiunto col corpo del giocatore
	(t.call(&"voci")[1] as Button).pressed.emit()
	await _secondi(1.5)
	k = InputEventKey.new()
	k.keycode = KEY_SPACE
	k.physical_keycode = KEY_SPACE
	k.pressed = true
	Input.parse_input_event(k)
	await _secondi(1.6)
	k = k.duplicate()
	k.pressed = false
	Input.parse_input_event(k)
	await _aspetta_ripresa()
	var pl := GameState.player
	var cps: Array = get_tree().root.find_children("*", "Checkpoint", true, false)
	cps.sort_custom(func(a, b): return (a as Checkpoint).order < (b as Checkpoint).order)
	for c in cps.slice(0, 4):
		print("  checkpoint %s ordine %d a %.1f m dal giocatore" % [GameState.persist_key(c), (c as Checkpoint).order, pl.global_position.distance_to((c as Node3D).global_position)])
	# il primo checkpoint che si raggiunge davvero: dentro, poi fuori e di nuovo dentro se non conta (il giocatore può
	# partire già dentro la sua area)
	var cp: Checkpoint = null
	var validi := cps.filter(func(c): return (c as Checkpoint).order > GameState.ORDINE_INIZIO) if "ORDINE_INIZIO" in GameState else cps.filter(func(c): return (c as Checkpoint).order >= -1)
	print("  checkpoint con ordine sotto -1 (scartati da reach_checkpoint dopo l'istantanea \"inizio\" a -1): %d" % (cps.size() - validi.size()))
	for c in [cps[0]] + validi.slice(0, 2):
		for giro in 2:
			if giro == 1:
				pl.call(&"teleport", (c as Node3D).global_position + Vector3(6, 0.1, 0), pl.rotation.y, 0.0)
				for i in 20:
					await get_tree().physics_frame
			pl.call(&"teleport", (c as Node3D).global_position + Vector3(0, 0.1, 0), pl.rotation.y, 0.0)
			for i in 30:
				await get_tree().physics_frame
			if String(GameState.snapshot.get("checkpoint", "")) == GameState.persist_key(c):
				cp = c
				break
		print("  %s: in memoria %s, su disco %s" % [GameState.persist_key(c), GameState.snapshot.get("checkpoint", "-"), GameState.salvataggio().get("checkpoint", "-")])
		if cp:
			break
	if cp == null:
		_check(false, "un checkpoint della partita nuova si raggiunge")
		return
	var chiave := GameState.persist_key(cp)
	_check(String(GameState.salvataggio().get("checkpoint", "")) == chiave, "dopo il primo checkpoint (%s) il salvataggio è della partita nuova (%s)" % [chiave, GameState.salvataggio().get("checkpoint", "-")])
	_check(not (GameState.salvataggio().get("collectibles", {}) as Dictionary).get("polaroid", []).has("prova_collaudo"),
			"la Polaroid finta della prima partita non è nel salvataggio nuovo")
	GameState.reset_progress()
	t = await _apri_titolo()
	_check(_nomi(t)[0] == "Continua", "nel titolo c'è Continua")
	(t.call(&"voci")[0] as Button).pressed.emit()
	await _aspetta_ripresa()
	pl = GameState.player
	_check(pl != null and String(GameState.snapshot.get("checkpoint", "")) == chiave and pl.global_position.distance_to(cp.get_spawn_transform().origin) < 1.5 if is_instance_valid(cp) else pl != null and String(GameState.snapshot.get("checkpoint", "")) == chiave,
			"Continua riparte dalla partita nuova (%s)" % GameState.snapshot.get("checkpoint", "-"))


# --- Ritocchi di enigmi (lavoro/continua-ritocchi) ----------------------------------------------

## A del joypad conferma le voci del titolo (Continua e Nuova partita), B chiude Comandi e Opzioni; in gioco A e B non
## aprono né chiudono niente.
func _joypad2() -> void:
	var d := MenuProva.istantanea("risalita")
	_scrivi(JSON.stringify(d))
	var t := await _apri_titolo()
	var voci: Array = t.call(&"voci")
	# Comandi e Opzioni: giù fino alla voce, A, poi B
	for nome in ["Comandi", "Opzioni"]:
		t = await _apri_titolo()
		voci = t.call(&"voci")
		var i := _nomi(t).find(nome)
		for k in i:
			await _premi("joypad", "giu")
		_check(t.get_viewport().gui_get_focus_owner() == voci[i], "col D-pad il focus su %s" % nome)
		await _premi("joypad", "conferma")
		await _frame(10)
		_check(is_instance_valid(t.get(&"_sottomenu")), "A apre %s" % nome)
		await _premi_joy(JOY_BUTTON_B)
		await _frame(10)
		_check(not is_instance_valid(t.get(&"_sottomenu")) and _nomi(t).size() > 0, "B chiude %s" % nome)
		_check(get_tree().current_scene == t, "B nel titolo non cambia scena")
	# Continua con A, fino alla sala
	GameState.reset_progress()
	_scrivi(JSON.stringify(d))
	t = await _apri_titolo()
	_check(t.get_viewport().gui_get_focus_owner() == t.call(&"voci")[0], "il focus su Continua")
	await _premi("joypad", "conferma")
	_check(bool(t.get(&"_avviato")), "A conferma Continua")
	await _aspetta_ripresa()
	var pl := GameState.player
	_check(pl != null and String(GameState.snapshot.get("checkpoint", "")) == d["checkpoint"], "Continua col joypad riparte da %s" % d["checkpoint"])
	if pl == null:
		return
	# in gioco: A e B non aprono menu, non mettono in pausa, non cambiano scena
	var scena := get_tree().current_scene
	var pos := pl.global_position
	for b in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_A, JOY_BUTTON_B]:
		await _premi_joy(b)
		await _frame(10)
	var menu_aperti := get_tree().root.find_children("*", "CanvasLayer", true, false).filter(func(c):
		return (c as CanvasLayer).visible and (String(c.name).to_lower().contains("menu") or String(c.name).to_lower().contains("pausa") or String(c.name).to_lower().contains("opzion")))
	_check(not get_tree().paused and not Game.is_paused() and get_tree().current_scene == scena,
			"in gioco A e B non mettono in pausa e non cambiano scena")
	_check(menu_aperti.is_empty(), "in gioco A e B non aprono menu %s" % [menu_aperti.map(func(c): return String(c.name))])
	_check(pl.global_position.distance_to(pos) < 0.05, "in gioco A e B non muovono il giocatore (%.3f m)" % pl.global_position.distance_to(pos))
	# per ultima, Nuova partita con A: il titolo parte (lo spot comincia)
	GameState.reset_progress()
	t = await _apri_titolo()
	await _premi("joypad", "giu")
	await _premi("joypad", "conferma")
	_check(bool(t.get(&"_avviato")), "A conferma Nuova partita")


func _premi_joy(b: int) -> void:
	for su in [true, false]:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		j.pressed = su
		Input.parse_input_event(j)
		await _frame(3)


## Il file temporaneo: solo lui completo, oppure il salvataggio rotto e lui buono (Continua c'è e riparte giusto); tutti e
## due rotti (Continua non c'è, niente crash).
func _tmp() -> void:
	var tmp := GameState.SAVE_PATH + ".tmp"
	for caso in ["solo il .tmp completo", "salvataggio rotto e .tmp buono", "tutti e due rotti"]:
		print("-- ", caso)
		GameState.reset_progress()
		_cancella()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		var id: String = {"solo il .tmp completo": "torre", "salvataggio rotto e .tmp buono": "tunnel", "tutti e due rotti": "risalita"}[caso]
		var d := MenuProva.istantanea(id)
		var buono := JSON.stringify(d)
		var f: FileAccess
		if caso != "solo il .tmp completo":
			_scrivi(buono.substr(0, buono.length() / 3))
		f = FileAccess.open(tmp, FileAccess.WRITE)
		f.store_string(buono if caso != "tutti e due rotti" else buono.substr(0, 200))
		f.close()
		var t := await _apri_titolo()
		if caso == "tutti e due rotti":
			_check(t != null and t.scene_file_path == TITOLO and not "Continua" in _nomi(t), "%s: il titolo si apre senza Continua (%s)" % [caso, _nomi(t)])
			continue
		_check(_nomi(t)[0] == "Continua", "%s: Continua c'è (%s)" % [caso, _nomi(t)])
		_check(FileAccess.file_exists(GameState.SAVE_PATH) and not GameState._leggi_salvataggio(GameState.SAVE_PATH).is_empty(),
				"%s: il .tmp è diventato il salvataggio" % caso)
		(t.call(&"voci")[0] as Button).pressed.emit()
		await _aspetta_ripresa()
		var pl := GameState.player
		if pl == null:
			_check(false, "%s: la sala con il giocatore" % caso)
			continue
		_confronta(pl, d, "%s (%s)" % [caso, id])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))


## I 6 checkpoint degli interni: una partita nuova, il risveglio (quello semplice: nelle prove automatiche la scena dello
## squalo non parte da sola), poi ognuno raggiunto col corpo del giocatore e scritto su disco; Continua da 3 di loro con
## posto, luci e zaino del salvataggio e senza rifare il risveglio.
func _interni() -> void:
	GameState.reset_progress()
	_cancella()
	var t := await _apri_titolo()
	(t.call(&"voci")[0] as Button).pressed.emit()
	await _salta_spot()
	await _aspetta_ripresa()
	var pl := GameState.player
	# la fine del risveglio (semplice: 2,6 s)
	await _secondi(4.0)
	_check(String(GameState.salvataggio().get("checkpoint", "")).ends_with("CheckpointRisveglio"),
			"a risveglio finito si salva il checkpoint del risveglio (%s)" % GameState.salvataggio().get("checkpoint", "-"))
	var cps: Array = get_tree().root.find_children("*", "Checkpoint", true, false).filter(func(c): return GameState.persist_key(c).begins_with("Interni/"))
	cps.sort_custom(func(a, b): return (a as Checkpoint).order < (b as Checkpoint).order)
	_check(cps.size() == 6, "6 checkpoint negli interni (%d)" % cps.size())
	var salvati := {}
	for c: Checkpoint in cps:
		var chiave := GameState.persist_key(c)
		if not chiave.ends_with("CheckpointRisveglio"):
			pl.call(&"teleport", c.global_position + Vector3(0, 0.1, 0), pl.rotation.y, 0.0)
			for i in 30:
				await get_tree().physics_frame
		var sd := GameState.salvataggio()
		_check(String(sd.get("checkpoint", "")) == chiave, "%s (ordine %d) scritto su disco (%s)" % [chiave, c.order, sd.get("checkpoint", "-")])
		salvati[chiave] = sd.duplicate(true)
	# Continua da 3 di loro: il primo, uno a metà, l'ultimo
	var chiavi := salvati.keys()
	for chiave in [chiavi[0], chiavi[chiavi.size() / 2], chiavi[-1]]:
		var d: Dictionary = salvati[chiave]
		if d.is_empty():
			continue
		GameState.reset_progress()
		_scrivi(JSON.stringify(d))
		t = await _apri_titolo()
		(t.call(&"voci")[0] as Button).pressed.emit()
		await _aspetta_ripresa()
		pl = GameState.player
		if pl == null:
			_check(false, "%s: la sala col giocatore" % chiave)
			continue
		var cp_risveglio := get_tree().root.find_child("CheckpointRisveglio", true, false) as Checkpoint
		_check(pl.input_enabled and absf(pl.camera.rotation.z) < 0.01 and (cp_risveglio == null or cp_risveglio.monitoring),
				"%s: niente risveglio rifatto (comandi attivi, camera dritta, checkpoint del risveglio attivo)" % chiave)
		_confronta(pl, d, chiave)
		var zaino_salvato := (d["player"]["inventory"] as Dictionary).has("zaino_pompa")
		_check(pl.has_item(&"zaino_pompa") == zaino_salvato and (pl.water_pack == null or pl.water_pack.equipped == zaino_salvato),
				"%s: zaino %s come nel salvataggio" % [chiave, "addosso" if zaino_salvato else "non addosso"])


## La scena dello squalo del risveglio (fatta partire a mano: nelle prove automatiche non parte da sola), e l'uscita a
## metà: il checkpoint del risveglio non si salva, quindi alla partita dopo la scena si rivede.
func _risveglio_interrotto() -> void:
	var vecchio := MenuProva.istantanea("torre")
	_scrivi(JSON.stringify(vecchio))
	GameState.reset_progress()
	get_tree().change_scene_to_file(GameState.SCENA_CARICAMENTO)
	await _aspetta_ripresa()
	# il risveglio semplice (prove automatiche) finisce e salva il suo checkpoint: si rimette tutto come al primo avvio
	await _secondi(4.0)
	var interni := get_tree().root.find_child("Interni", true, false)
	var pl := GameState.player
	_scrivi(JSON.stringify(vecchio))
	GameState.snapshot["checkpoint"] = "inizio"
	GameState.snapshot["order"] = GameState.ORDINE_INIZIO
	# la scena dello squalo, come al primo avvio vero
	interni.call(&"fai_risveglio", pl, true)
	await _frame(300)   # 5 s di gioco (--fixed-fps 60)
	var cp := get_tree().root.find_child("CheckpointRisveglio", true, false) as Checkpoint
	_check(cp != null and not cp.monitoring, "durante la scena dello squalo il checkpoint del risveglio è spento")
	_check(String(GameState.salvataggio().get("checkpoint", "")) == vecchio["checkpoint"],
			"durante la scena il salvataggio è ancora quello vecchio (%s)" % GameState.salvataggio().get("checkpoint", "-"))
	# a scena finita si salva
	var fotogrammi := 0
	while fotogrammi < 3600 and not String(GameState.salvataggio().get("checkpoint", "")).ends_with("CheckpointRisveglio"):
		await get_tree().process_frame
		fotogrammi += 1
	_check(String(GameState.salvataggio().get("checkpoint", "")).ends_with("CheckpointRisveglio") and cp.monitoring,
			"a scena finita (dopo %.1f s di gioco) il checkpoint del risveglio si salva" % ((fotogrammi + 300) / 60.0))
	# di nuovo, e uscita a metà scena
	_scrivi(JSON.stringify(vecchio))
	GameState.snapshot["checkpoint"] = "inizio"
	GameState.snapshot["order"] = GameState.ORDINE_INIZIO
	interni.call(&"fai_risveglio", pl, true)
	await _frame(300)   # 5 s di gioco (--fixed-fps 60)
	GameState.reset_progress()
	var t := await _apri_titolo()
	_check(_nomi(t)[0] == "Continua" and String(GameState.salvataggio().get("checkpoint", "")) == vecchio["checkpoint"],
			"uscendo a metà scena il salvataggio resta quello vecchio: il risveglio non conta, la scena si rivede")


func _salta_spot() -> void:
	await _secondi(1.5)
	var k := InputEventKey.new()
	k.keycode = KEY_SPACE
	k.physical_keycode = KEY_SPACE
	k.pressed = true
	Input.parse_input_event(k)
	await _secondi(1.6)
	k = k.duplicate()
	k.pressed = false
	Input.parse_input_event(k)


# --- Salvataggi guasti --------------------------------------------------------------------------

func _rotti() -> void:
	var buono := JSON.stringify(MenuProva.istantanea("risalita"))
	var senza_scena := MenuProva.istantanea("risalita")
	senza_scena["scene"] = "res://scenes/non_esiste.tscn"
	var senza_giocatore := MenuProva.istantanea("risalita")
	senza_giocatore.erase("player")
	var vecchia := MenuProva.istantanea("risalita")
	vecchia["version"] = 0
	var casi := {
		"mancante": null,
		"vuoto": "",
		"json rotto": "{rotto",
		"troncato a metà": buono.substr(0, buono.length() / 2),
		"una lista invece di un dizionario": "[1, 2, 3]",
		"versione vecchia": JSON.stringify(vecchia),
		"scena che non esiste": JSON.stringify(senza_scena),
		"senza giocatore": JSON.stringify(senza_giocatore),
		"byte a caso": "\u0000\u0001ÿþ garbage",
	}
	for nome in casi:
		_cancella()
		if casi[nome] != null:
			_scrivi(casi[nome])
		var t := await _apri_titolo()
		_check(t != null and t.scene_file_path == TITOLO and not "Continua" in _nomi(t) and _nomi(t)[0] == "NuovaPartita",
				"%s: il titolo si apre, senza Continua (%s)" % [nome, _nomi(t) if t else []])
		_check(not GameState.continue_from_disk(), "%s: continue_from_disk rifiuta" % nome)
	# un file temporaneo rotto lasciato da un crash, accanto a un salvataggio buono: Continua c'è e va
	_cancella()
	_scrivi(buono)
	var f := FileAccess.open(GameState.SAVE_PATH + ".tmp", FileAccess.WRITE)
	f.store_string("{\"version\": 1, \"sce")
	f.close()
	var t := await _apri_titolo()
	_check(_nomi(t)[0] == "Continua", "un .tmp rotto accanto a un salvataggio buono: Continua c'è")
	_check(not GameState.salvataggio().is_empty(), "e il salvataggio è quello buono")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH + ".tmp"))
	# solo il .tmp (il crash dopo aver scritto il temporaneo e prima di rinominarlo, senza salvataggio di prima)
	_cancella()
	f = FileAccess.open(GameState.SAVE_PATH + ".tmp", FileAccess.WRITE)
	f.store_string(buono)
	f.close()
	t = await _apri_titolo()
	print("  (solo il .tmp completo, senza salvataggio: voci %s)" % [_nomi(t)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH + ".tmp"))


# --- attrezzi -----------------------------------------------------------------------------------

func _cancella() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))


func _scrivi(testo: String) -> void:
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(testo)
	f.close()


func _apri_titolo() -> Node:
	get_tree().change_scene_to_file(TITOLO)
	for i in 30:
		await get_tree().process_frame
	return get_tree().current_scene


func _nomi(t: Node) -> Array:
	return (t.call(&"voci") as Array).map(func(b): return String((b as Button).name))


func _frame(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secondi(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await get_tree().process_frame


func _aspetta_ripresa() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and s.scene_file_path != TITOLO \
				and GameState.player and is_instance_valid(GameState.player) and not GameState.is_restoring():
			break
	for i in 30:
		await get_tree().process_frame
