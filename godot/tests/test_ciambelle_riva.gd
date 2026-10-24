extends Node
## Nel gioco vero (la sala principale con la Risalita) le ciambelle tolte dal fiume stanno sulla riva: tre in piedi
## appoggiate alla roccia lungo la strada giusta e una stesa sulla banchina dell'approdo (riscontro dell'utente sulla
## v0.3.12). Ognuna poggia a terra (il punto più basso a pochi millimetri dalla banchina) e quelle in piedi toccano la
## roccia con la cima. Collaudo della v0.3.13: nella scena di prova c'erano, nel gioco no; un test vale solo se gira
## sulla scena vera del gioco.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_ciambelle_riva.gd

const SALA := "res://scenes/sala_principale.tscn"

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file(SALA)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene
	var ris := level.get_node_or_null(^"Risalita")
	var fiume: Node3D = ris.get(&"fiume") if ris else null
	for i in 60 * 60:
		if fiume and bool(fiume.get(&"costruita")):
			break
		await get_tree().physics_frame
		fiume = ris.get(&"fiume") if ris else null
	check(fiume != null and bool(fiume.get(&"costruita")), "il fiume della Risalita è costruito nel gioco vero")
	if fiume == null:
		_fine()
		return
	await _secondi(0.5)
	var riva := fiume.find_children("CiambellaRiva*", "Node3D", false, false)
	check(riva.size() == 3, "tre ciambelle in piedi sulla riva (%d)" % riva.size())
	for c in riva:
		var ci := c as Node3D
		var basso := INF
		for mi in ci.find_children("*", "MeshInstance3D", true, false):
			var xf := (mi as MeshInstance3D).global_transform
			for v in (mi as MeshInstance3D).mesh.get_faces():
				basso = minf(basso, (xf * v).y)
		var terra := fiume.global_position.y
		check(basso - terra > -0.003 and basso - terra < 0.004, "%s poggia a terra (%.1f mm)" % [ci.name, (basso - terra) * 1000.0])
		# la cima del retro contro la faccia vera della roccia (nelle coordinate del fiume, coi triangoli dei modelli: col
		# giocatore lontano le stanze della Risalita sono nascoste, e i raggi sulle mesh visibili non le vedono)
		var n := ci.basis.y.normalized()
		var su := (Vector3.UP - n * Vector3.UP.dot(n)).normalized()
		var cima := ci.position + su * 0.57
		var h: Dictionary = fiume.call(&"_raggio_roccia", cima + n * 0.06, cima - n * 0.5)
		var gap := ((cima + n * 0.06).distance_to(h["position"]) - 0.06) if not h.is_empty() else INF
		check(gap < 0.012 and gap > -0.03, "%s tocca la roccia con la cima (%.1f mm)" % [ci.name, gap * 1000.0])
		check(n.y < 0.4, "%s è in piedi, inclinata di %.0f gradi" % [ci.name, rad_to_deg(asin(clampf(n.y, -1.0, 1.0)))])
	# nessuna ciambella più nel canale lungo la strada giusta (solo le due della vasca dell'imbarco)
	var in_acqua := 0
	for c in fiume.get_children():
		if c is Node3D and String(c.name).begins_with("ciambella") and (c as Node3D).position.y < -0.1:
			in_acqua += 1
	check(in_acqua == 2, "a galla restano solo le due della vasca dell'imbarco (%d)" % in_acqua)
	_fine()


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)
