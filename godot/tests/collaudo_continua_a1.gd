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
	_check(String(GameState.salvataggio().get("checkpoint", "")) == d["checkpoint"], "prima del primo checkpoint il salvataggio vecchio c'è ancora (%s)" % GameState.salvataggio().get("checkpoint", "-"))
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
	var validi := cps.filter(func(c): return (c as Checkpoint).order >= -1)
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
