extends Node
## Collaudo della voce Continua come un giocatore, un processo per volta (si chiude e si riapre il gioco davvero).
## Modi (primo argomento dopo lo script), con <cartella> per gli scatti e i file di stato:
##  - "titolo <cartella> <nome>": il titolo, le voci, chi ha il focus, F9 nascosto; uno scatto se c'è un renderer;
##  - "gioca <cartella> <id> [kill]": dal titolo, F9, la partenza <id>; arrivati, il giocatore entra nel checkpoint
##    successivo della zona (il primo più avanti, per ordine) e si aspetta che il salvataggio su disco cambi; si scrive
##    lo stato (checkpoint, posto, zaino, acqua, Polaroid, luci) in <cartella>/stato_<id>.json. Con "kill" il processo
##    si uccide da solo (SIGKILL) subito dopo, come un crash; altrimenti esce normalmente;
##  - "continua <cartella> <id>": dal titolo, Continua (col tasto vero, ui_accept sulla voce che ha il focus), la
##    schermata di caricamento, l'arrivo; si confronta lo stato con <cartella>/stato_<id>.json;
##  - "nuova <cartella>": dal titolo con un salvataggio, giù fino a Nuova partita e invio; si salta lo spot; al
##    risveglio il giocatore entra nel primo checkpoint e si guarda il salvataggio su disco.
## Uso: [xvfb-run ...] godot [--headless] --path godot --fixed-fps 60 --script res://tests/run.gd -- \
##        res://tests/collaudo/sonda_continua.gd <modo> <cartella> [argomenti]

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var cart := ""
var modo := ""
var _f := 0


func _ready() -> void:
	_run.call_deferred()


func _passa(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _tasto(k: Key) -> void:
	for premuto in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = premuto
		Input.parse_input_event(e)
		await _passa(3)


func _foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.88)
	print("CONTINUA: scatto ", nome)


func _salvataggio() -> Dictionary:
	if not FileAccess.file_exists(GameState.SAVE_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	return d if d is Dictionary else {}


func _voci() -> Array:
	var t := get_tree().current_scene
	if t == null or not t.has_method(&"voci"):
		return []
	return (t.call(&"voci") as Array).map(func(b): return String((b as Button).name))


func _apri_titolo() -> void:
	get_tree().change_scene_to_file(TITOLO)
	await _passa(240)


func _stato() -> Dictionary:
	var p := GameState.player
	var out := {"scena": String(get_tree().current_scene.scene_file_path) if get_tree().current_scene else ""}
	out["checkpoint"] = String(GameState.snapshot.get("checkpoint", "")) if GameState.snapshot is Dictionary else ""
	out["luci"] = int(GameState.luci)
	if p and is_instance_valid(p):
		out["posizione"] = [p.global_position.x, p.global_position.y, p.global_position.z]
		out["zaino"] = p.has_item(&"zaino_pompa")
		out["acqua"] = p.water_pack.tank_amount if p.water_pack else -1.0
		var inv := []
		for k in p.inventory:
			inv.append(String(k))
		inv.sort()
		out["inventario"] = inv
		out["comandi"] = p.input_enabled
	var coll = GameState.snapshot.get("collectibles", {}) if GameState.snapshot is Dictionary else {}
	out["polaroid"] = coll
	return out


## Aspetta il gioco dopo la schermata di caricamento: il giocatore coi comandi.
func _aspetta_arrivo() -> bool:
	var t0 := Time.get_ticks_msec()
	var caricamento := false
	while Time.get_ticks_msec() - t0 < 900000:
		await _passa(1)
		var sc := get_tree().current_scene
		if sc and String(sc.scene_file_path).contains("caricamento"):
			if not caricamento:
				caricamento = true
				print("CONTINUA: schermata di caricamento dopo %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
				await _passa(30)
				await _foto("%s_caricamento" % modo)
		var p := GameState.player
		if p and is_instance_valid(p) and p.input_enabled and sc and not String(sc.scene_file_path).contains("caricamento") \
				and not String(sc.scene_file_path).contains("menu"):
			print("CONTINUA: arrivo in %s dopo %.1f s" % [sc.scene_file_path, (Time.get_ticks_msec() - t0) / 1000.0])
			return true
	return false


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	modo = a[1]
	cart = a[2]
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = true
	print("CONTINUA: cartella dei dati %s" % OS.get_user_data_dir())
	match modo:
		"titolo":
			await _titolo(a[3] if a.size() > 3 else "titolo")
		"gioca":
			await _gioca(a[3], a.size() > 4 and a[4] == "kill")
		"continua":
			await _continua(a[3])
		"nuova":
			await _nuova()
	get_tree().quit()


func _titolo(nome: String) -> void:
	await _apri_titolo()
	var d := _salvataggio()
	print("CONTINUA: titolo %s, salvataggio su disco %s (checkpoint %s), voci %s" % [nome, not d.is_empty(), d.get("checkpoint", "-"), _voci()])
	var f := get_viewport().gui_get_focus_owner()
	print("CONTINUA: focus su %s" % (String(f.name) if f else "niente"))
	print("CONTINUA: menu di prova aperto %s" % (get_tree().root.find_child("MenuProva", true, false) != null))
	await _foto(nome)


func _gioca(id: String, kill: bool) -> void:
	await _apri_titolo()
	await _tasto(KEY_F9)
	await _passa(30)
	var menu := get_tree().root.find_child("MenuProva", true, false)
	var nome := ""
	for p in MenuProva.PARTENZE:
		if p["id"] == id:
			nome = p["nome"]
	var bottone: Button = null
	for b in menu.find_children("*", "Button", true, false) if menu else []:
		if nome != "" and (b as Button).text.begins_with(nome):
			bottone = b
	if bottone == null:
		print("CONTINUA: ERRORE niente partenza ", id)
		return
	bottone.pressed.emit()
	if not await _aspetta_arrivo():
		print("CONTINUA: ERRORE non arriva")
		return
	await _passa(120)
	var p := GameState.player
	var cp0 := String(GameState.snapshot.get("checkpoint", ""))
	var ord0 := int(GameState.snapshot.get("order", -1))
	# il checkpoint dopo: nella stessa scena, l'ordine più basso fra quelli più avanti
	var dopo: Checkpoint = null
	for c in get_tree().current_scene.find_children("*", "Checkpoint", true, false):
		var cp := c as Checkpoint
		if cp.order > ord0 and (dopo == null or cp.order < dopo.order):
			dopo = cp
	print("CONTINUA: partenza %s al checkpoint %s (ordine %d), il prossimo è %s" % [id, cp0, ord0, (str(dopo.get_path()) + " ordine " + str(dopo.order)) if dopo else "nessuno"])
	var t_prima := FileAccess.get_modified_time(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else 0
	var cp_disco_prima := String(_salvataggio().get("checkpoint", "-"))
	if dopo:
		# un po' di gioco: si raccoglie l'acqua che serve e si entra nel checkpoint dopo
		p.teleport(dopo.global_position + Vector3.UP * 0.1)
		for i in 120:
			await get_tree().physics_frame
			if String(GameState.snapshot.get("checkpoint", "")) != cp0:
				break
	await _passa(10)
	var d := _salvataggio()
	print("CONTINUA: salvataggio su disco prima %s, dopo %s (riscritto %s)" % [cp_disco_prima, d.get("checkpoint", "-"),
			FileAccess.file_exists(GameState.SAVE_PATH) and FileAccess.get_modified_time(GameState.SAVE_PATH) >= t_prima and d.get("checkpoint", "") != cp_disco_prima])
	var st := _stato()
	st["salvataggio"] = d.get("checkpoint", "")
	st["posto_salvato"] = d.get("player", {}).get("position", [])
	var f := FileAccess.open(cart.path_join("stato_%s.json" % id), FileAccess.WRITE)
	f.store_string(JSON.stringify(st, "\t"))
	f.close()
	print("CONTINUA: stato scritto ", JSON.stringify(st))
	if kill:
		print("CONTINUA: CRASH, SIGKILL al processo %d" % OS.get_process_id())
		OS.kill(OS.get_process_id())
		await _passa(600)


func _continua(id: String) -> void:
	var atteso = JSON.parse_string(FileAccess.get_file_as_string(cart.path_join("stato_%s.json" % id)))
	await _apri_titolo()
	var v := _voci()
	var f := get_viewport().gui_get_focus_owner()
	print("CONTINUA: voci %s, focus su %s" % [v, String(f.name) if f else "niente"])
	await _foto("continua_%s_titolo" % id)
	# il tasto vero sulla voce col focus
	await _tasto(KEY_ENTER)
	if not await _aspetta_arrivo():
		print("CONTINUA: ERRORE non arriva")
		return
	await _passa(60)
	var st := _stato()
	print("CONTINUA: arrivato ", JSON.stringify(st))
	var pos: Array = st.get("posizione", [0, 0, 0])
	var sp: Array = atteso.get("posto_salvato", [0, 0, 0]) if atteso is Dictionary else [0, 0, 0]
	var dist := Vector3(pos[0], pos[1], pos[2]).distance_to(Vector3(sp[0], sp[1], sp[2])) if sp.size() == 3 else -1.0
	print("CONTINUA: CONFRONTO %s: checkpoint %s / atteso %s; distanza dal posto salvato %.2f m; luci %s / %s; zaino %s / %s; acqua %.1f / %.1f; inventario %s / %s; Polaroid uguali %s" % [
			id, st.get("checkpoint"), atteso.get("salvataggio"), dist, st.get("luci"), atteso.get("luci"),
			st.get("zaino"), atteso.get("zaino"), float(st.get("acqua", -1)), float(atteso.get("acqua", -1)),
			st.get("inventario"), atteso.get("inventario"), JSON.stringify(st.get("polaroid")) == JSON.stringify(atteso.get("polaroid"))])


func _nuova() -> void:
	var prima := _salvataggio()
	await _apri_titolo()
	print("CONTINUA: nuova partita, salvataggio prima: %s, voci %s" % [prima.get("checkpoint", "-"), _voci()])
	# dalla voce col focus (Continua) giù fino a Nuova partita
	var f := get_viewport().gui_get_focus_owner()
	if f and String(f.name) == "Continua":
		await _tasto(KEY_DOWN)
	f = get_viewport().gui_get_focus_owner()
	print("CONTINUA: focus su %s, invio" % (String(f.name) if f else "niente"))
	await _tasto(KEY_ENTER)
	# lo spot VHS: si salta tenendo premuto
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await _passa(1)
		var sc := get_tree().current_scene
		if sc and String(sc.scene_file_path).contains("spot"):
			Input.action_press(&"ui_accept")
			Input.action_press(&"jump")
		var p := GameState.player
		if p and is_instance_valid(p) and sc and String(sc.scene_file_path).contains("sala_principale"):
			break
	Input.action_release(&"ui_accept")
	Input.action_release(&"jump")
	print("CONTINUA: nella sala dopo %.1f s; checkpoint in memoria %s; su disco %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
			GameState.snapshot.get("checkpoint", "-") if GameState.snapshot is Dictionary else "-", _salvataggio().get("checkpoint", "-")])
	# si aspetta che il giocatore abbia i comandi (il risveglio)
	var p := GameState.player
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000 and not (p and is_instance_valid(p) and p.input_enabled):
		await _passa(1)
		p = GameState.player
	print("CONTINUA: comandi dopo il risveglio %s; su disco ancora %s" % [p.input_enabled if p else false, _salvataggio().get("checkpoint", "-")])
	# il primo checkpoint della scena (ordine più basso più avanti di quello in memoria)
	var ord0 := int(GameState.snapshot.get("order", -1)) if GameState.snapshot is Dictionary else -1
	var primo: Checkpoint = null
	for c in get_tree().current_scene.find_children("*", "Checkpoint", true, false):
		var cp := c as Checkpoint
		if cp.order > ord0 and (primo == null or cp.order < primo.order):
			primo = cp
	if primo and p:
		p.teleport(primo.global_position + Vector3.UP * 0.1)
		for i in 120:
			await get_tree().physics_frame
	var d := _salvataggio()
	print("CONTINUA: NUOVA dopo il primo checkpoint (%s, ordine %d): su disco %s, ordine %s, scena %s; sovrascritto %s" % [
			primo.get_path() if primo else "-", primo.order if primo else -1, d.get("checkpoint", "-"), d.get("order", "-"),
			d.get("scene", "-"), d.get("checkpoint", "") != prima.get("checkpoint", "")])
