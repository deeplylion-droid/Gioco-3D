extends Node
## Sonda del canto sulla strada vera (0.4.0): la sala intera con la Risalita caricata, dopo il blackout. Il giocatore va
## in ogni checkpoint, nei punti della Risalita, nell'infermeria e nelle pozze (sulla passerella girandosi in 8
## direzioni). Per ogni posto stampa quale acqua segue il canto (CantoPrima) e la fase_canto di ogni specchio.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sonda_canto_strada.gd
const LEVEL := "res://scenes/sala_principale.tscn"
var p: Player
func _ready() -> void:
	_run.call_deferred()
func _sta(pos: Vector3, n := 40) -> void:
	for i in n:
		p.teleport(pos)
		await get_tree().physics_frame
func _dove() -> String:
	var c = Audio.canto_prima
	var l: Node = c.lei
	return "%s %s" % [String(get_tree().current_scene.get_path_to(l)) if l and is_instance_valid(l) else "-", c.fase]
func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == LEVEL and GameState.player:
			break
	await get_tree().create_timer(0.5).timeout
	var level := get_tree().current_scene
	p = GameState.player as Player
	var ris := level.get_node(^"Risalita")
	ris.call(&"carica_subito")
	for i in 30:
		await get_tree().physics_frame
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var posti := []
	var poz0 := ris.get_node(^"StanzaPozze") as Node3D
	for k in 8:
		posti.append(["Pozze giro %d" % k, poz0.to_global(Vector3(0, 0, 3.4))])
	for c in level.find_children("Checkpoint*", "Area3D", true, false):
		var sp: Node3D = c.get(&"spawn_point") if c.get(&"spawn_point") else c
		posti.append([String(c.name), sp.global_position])
	for m in ris.get_node(^"Marker").get_children():
		posti.append(["Marker/" + String(m.name), (m as Node3D).global_position])
	posti.append(["Infermeria", (ris.get_node(^"Infermeria") as Node3D).global_position])
	var poz := ris.get_node(^"StanzaPozze") as Node3D
	posti.append(["Pozze passerella", poz.to_global(Vector3(0, 0, 3.4))])
	posti.append(["Pozze centro", poz.to_global(Vector3(0, 0, 0))])
	for a in get_tree().get_nodes_in_group(AcquaDiLei.GRUPPO):
		var ad := a as AcquaDiLei
		print("SPECCHIO %s punti %d primo %s" % [level.get_path_to(ad), ad.punti_uscita.size(), ad.punti_uscita[0].global_position.snapped(Vector3.ONE * 0.1) if ad.punti_uscita.size() > 0 else "-"])
	for pp in posti:
		await _sta(pp[1] + Vector3(0, 0.05, 0))
		if String(pp[0]).begins_with("Pozze giro"):
			p.set_look(TAU * int(String(pp[0]).right(1)) / 8.0, 0.0)
			await get_tree().create_timer(0.3).timeout
		var fasi := []
		for a in get_tree().get_nodes_in_group(AcquaDiLei.GRUPPO):
			fasi.append("%s=%s" % [a.name, (a as AcquaDiLei).fase_canto])
		print("CANTO %-28s %s -> segue %s | %s" % [pp[0], (pp[1] as Vector3).snapped(Vector3.ONE * 0.1), _dove(), ", ".join(fasi)])
	get_tree().quit()
