extends Node
## Test del menu di prova nascosto (MenuProva, F9 nel titolo): per ogni partenza che c'è (res://assets/prova/<id>.json,
## scritte da tests/genera_partenze_prova.gd):
## - si parte come dal menu (MenuProva.parti: l'istantanea in GameState, poi la schermata di caricamento) e la sala si
##   apre senza errori di script;
## - il giocatore sta nel posto del checkpoint, con lo zaino pieno, le luci, le Polaroid e gli oggetti persist
##   dell'istantanea; la torre e il tunnel ci sono quando la partenza è lì dentro;
## - la memoria resta sotto [constant MEMORIA_MAX] (statica, quella che si misura senza scheda video);
## - morendo si riparte dallo stesso checkpoint.
## E il titolo: F9 apre il menu di prova con le partenze, Esc lo chiude, fra le voci del titolo non c'è.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_partenze_prova.gd [id,id]

const MEMORIA_MAX := 6.0 * 1024 * 1024 * 1024
const TITOLO := "res://scenes/ui/menu_principale.tscn"

var _ok := 0
var _ko := 0
var _errori_prima := 0


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
	GameState.save_to_disk = false
	var solo := PackedStringArray()
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		solo = args[1].split(",")
	await _titolo()
	for p in MenuProva.disponibili():
		var id: String = p["id"]
		if id == "inizio" or (not solo.is_empty() and not id in solo):
			continue
		print("== ", id)
		await _partenza(id)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _titolo() -> void:
	print("== titolo")
	get_tree().change_scene_to_file(TITOLO)
	for i in 30:
		await get_tree().process_frame
	var t := get_tree().current_scene
	var testi: Array = (t.call(&"voci") as Array).map(func(b): return (b as Button).text.to_lower())
	_check(not testi.any(func(x): return "prova" in x or "partenz" in x), "fra le voci del titolo il menu di prova non c'è (%s)" % [testi])
	var ev := InputEventKey.new()
	ev.keycode = MenuProva.TASTO
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 5:
		await get_tree().process_frame
	var m := t.get_node_or_null(^"MenuProva") as MenuProva
	_check(m != null, "F9 apre il menu di prova")
	if m:
		var n := m.find_children("*", "Button", true, false).size()
		_check(n == MenuProva.disponibili().size() + 1, "con %d partenze e Indietro (%d bottoni)" % [MenuProva.disponibili().size(), n])
		var esc := InputEventAction.new()
		esc.action = &"ui_cancel"
		esc.pressed = true
		Input.parse_input_event(esc)
		for i in 5:
			await get_tree().process_frame
		_check(t.get_node_or_null(^"MenuProva") == null, "Esc lo chiude")
	await _clic_mouse(t)


## Il clic vero col mouse su una partenza (#143, collaudo finale della 0.3.22: la Radice del titolo, su layer 100 e con
## MOUSE_FILTER_STOP, si prendeva i clic prima del menu di prova): F9, poi un clic sinistro (premuto e rilasciato) sul
## centro della prima partenza dopo "Inizio", passato al viewport. La partenza scelta arriva al segnale del menu (staccato
## dal titolo, così non parte davvero).
func _clic_mouse(t: Node) -> void:
	var ev := InputEventKey.new()
	ev.keycode = MenuProva.TASTO
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 5:
		await get_tree().process_frame
	var m := t.get_node_or_null(^"MenuProva") as MenuProva
	_check(m != null, "F9 riapre il menu di prova")
	if m == null:
		return
	var partenze := MenuProva.disponibili()
	if partenze.size() < 2:
		print("  (nessuna partenza oltre Inizio: il clic non si prova)")
		m.chiudi()
		return
	for c in m.scelta.get_connections():
		m.scelta.disconnect(c["callable"])
	var scelte: Array[String] = []
	m.scelta.connect(func(id: String): scelte.append(id))
	var voce := m.find_children("*", "Button", true, false)[1] as Button
	var centro := voce.get_global_rect().get_center()
	var mossa := InputEventMouseMotion.new()
	mossa.position = centro
	mossa.global_position = centro
	get_viewport().push_input(mossa, true)
	await get_tree().process_frame
	var sotto := get_viewport().gui_get_hovered_control()
	for premuto in [true, false]:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = premuto
		clic.position = centro
		clic.global_position = centro
		get_viewport().push_input(clic, true)
		await get_tree().process_frame
	await get_tree().process_frame
	var atteso: String = partenze[1]["id"]
	_check(scelte == [atteso], "un clic col mouse sulla partenza «%s» la sceglie (sotto il mouse %s, scelte: %s)" % [voce.text,
			sotto.name if sotto else "niente", scelte])
	if is_instance_valid(m):
		m.chiudi()
	for i in 3:
		await get_tree().process_frame


func _partenza(id: String) -> void:
	var d := MenuProva.istantanea(id)
	_check(not d.is_empty(), "%s: l'istantanea si legge" % id)
	if d.is_empty():
		return
	_check(MenuProva.parti(get_tree(), id), "%s: parte" % id)
	await _aspetta_ripresa()
	var level := get_tree().current_scene
	var pl := GameState.player
	_check(level != null and level.scene_file_path == d["scene"] and pl != null, "%s: la sala è aperta, col giocatore" % id)
	if pl == null:
		return
	_check(not GameState.is_restoring(), "%s: l'istantanea è applicata" % id)
	var pos: Array = d["player"]["position"]
	var spawn := Vector3(pos[0], pos[1], pos[2])
	_check(pl.global_position.distance_to(spawn) < 1.5, "%s: il giocatore al checkpoint (a %.2f m)" % [id, pl.global_position.distance_to(spawn)])
	_check(String(GameState.snapshot.get("checkpoint", "")) == d["checkpoint"], "%s: checkpoint %s" % [id, GameState.snapshot.get("checkpoint", "")])
	_check(int(GameState.luci) == int(d["luci"]), "%s: luci %d" % [id, GameState.luci])
	_check(pl.has_item(&"zaino_pompa") and pl.water_pack and pl.water_pack.tank_amount > 0.0, "%s: zaino con l'acqua" % id)
	var polaroid: Array = (d["collectibles"] as Dictionary).get("polaroid", [])
	_check(GameState.get_collected_count(&"polaroid") == polaroid.size(), "%s: %d Polaroid raccolte" % [id, polaroid.size()])
	# gli oggetti persist come nell'istantanea
	var diversi := []
	var objects: Dictionary = d["objects"]
	for n in get_tree().get_nodes_in_group(&"persist"):
		var key := GameState.persist_key(n)
		# (non le vasche d'acqua, che si muovono da sole, e il portone della torre, che si chiude alle spalle di chi entra)
		if n is WaterTank or n is PortoneTorre:
			continue
		if objects.has(key) and n.has_method(&"save_state") and not _uguali(n.call(&"save_state"), objects[key]):
			diversi.append(key)
	_check(diversi.is_empty(), "%s: gli oggetti persist come nell'istantanea (diversi: %s)" % [id, diversi])
	if String(d["checkpoint"]).begins_with("SalaTorre"):
		_check(level.get(&"sala_torre") is Node, "%s: la torre c'è" % id)
	if String(d["checkpoint"]).begins_with("SalaSottomarino"):
		_check(level.get(&"sala_sottomarino") is Node, "%s: il tunnel c'è" % id)
	for i in 60:
		await get_tree().physics_frame
	_check(not GameState.is_dying and pl.global_position.y > spawn.y - 3.0, "%s: dopo un secondo è ancora lì, vivo (y %.1f)" % [id, pl.global_position.y])
	var mem := OS.get_static_memory_usage()
	_check(mem < MEMORIA_MAX, "%s: memoria %.2f GB (al più %.1f)" % [id, mem / 1073741824.0, MEMORIA_MAX / 1073741824.0])
	# una morte: si riparte dallo stesso checkpoint
	GameState.respawn()
	await _aspetta_ripresa()
	pl = GameState.player
	_check(pl != null and pl.global_position.distance_to(spawn) < 1.5, "%s: dopo una morte di nuovo al checkpoint" % id)


func _aspetta_ripresa() -> void:
	# (in tempo vero: la sala si carica in un thread, e nel sandbox la prima volta ci mette minuti)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and GameState.player \
				and is_instance_valid(GameState.player) and not GameState.is_restoring():
			break
	for i in 30:
		await get_tree().process_frame


static func _uguali(a, b) -> bool:
	# (i numeri dal JSON tornano float)
	return JSON.stringify(a) == JSON.stringify(JSON.parse_string(JSON.stringify(b))) \
		or JSON.parse_string(JSON.stringify(a)) == b
