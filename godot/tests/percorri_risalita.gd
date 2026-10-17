extends Node
## Controlla che la strada di risalita arredata (tappa 7 B) si percorra tutta senza incastrarsi: dalla porta
## col maniglione della sala pompe, su per il raccordo, giù per il corridoio C2, lungo C3 fino al magazzino
## dei gonfiabili, camminando e correndo, al centro e spostati di lato (col giocatore vero e le collisioni
## dell'arredo). Se spostato di lato urta qualcosa, sterza verso il centro come farebbe chi gioca; fallisce
## solo se si incastra anche così. Stampa dove si blocca.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/percorri_risalita.gd

const LEVEL := "res://scenes/sala_principale.tscn"
## Le tappe della strada, nelle coordinate della scena dei tecnici (come test_tappa7.gd).
const TAPPE := [Vector3(51.6, 0, 1.4), Vector3(51.6, 0, 0.6), Vector3(51.6, 3.625, -6.2), Vector3(50.0, 3.625, -7.8),
		Vector3(44.55, 7.25, -7.8), Vector3(44.55, 7.25, -4.0), Vector3(44.55, 9.05, 2.0), Vector3(44.55, 9.05, 15.0),
		Vector3(30.0, 9.05, 15.0), Vector3(26.5, 9.05, 15.0), Vector3(22.5, 9.05, 15.0)]
## Spostamento di lato rispetto al centro della strada (m).
const LATI := [0.0, -0.2, 0.2]

var p: Player
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	var level := get_tree().current_scene
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var tec: Node3D = level.get_node("Tecnici")
	var arredo := tec.get_node_or_null("Ambienti/Raccordo/ArredoRisalita")
	check(arredo != null, "c'è l'arredo della strada di risalita")
	var corpi := arredo.find_children("*", "StaticBody3D", true, false).size() if arredo else 0
	check(corpi > 100, "l'arredo ha le collisioni (%d corpi)" % corpi)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for corsa in [false, true]:
		for lato in LATI:
			p.teleport(tec.to_global(_m(tec, "marker_t7_inizio")) + Vector3(0, 0.05, 0), 0.0, 0.0)
			await _frames(10)
			var ok := true
			var prima: Vector3 = tec.to_global(_m(tec, "marker_t7_inizio"))
			for t in TAPPE:
				var g := tec.to_global(t)
				var d := Vector3(g.x - prima.x, 0, g.z - prima.z).normalized()
				var lat: Vector3 = Vector3(-d.z, 0, d.x) * float(lato)
				var arrivato := await _vai(g + lat, corsa, 1500)
				if not arrivato and lato != 0.0:
					# come farebbe chi gioca: sterza verso il centro della strada (per esempio intorno al
					# mucchio di gonfiabili in C3, che occupa metà corsia); incastrato è solo chi non riparte
					print("  aggiro verso il centro")
					var pos := p.global_position
					var centro: Vector3 = prima + d * d.dot(pos - prima)
					# un passo di lato oltre il centro, dalla parte opposta a dove si è urtato
					await _vai(Vector3(centro.x, pos.y, centro.z) - lat.normalized() * 0.3, corsa, 300, 0.08)
					arrivato = await _vai(g, corsa, 1500)
				ok = ok and arrivato
				prima = g
				if not ok:
					break
			check(ok, "%s, %s: tutta la strada senza incastrarsi" % ["correndo" if corsa else "camminando",
					"al centro" if lato == 0.0 else "spostato di %.2f m" % lato])
	print("risultato: %d ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _m(tec: Node3D, nome: String) -> Vector3:
	return (tec.get_node("Marker/" + nome) as Node3D).position


func _vai(t: Vector3, corsa: bool, max_frames: int, soglia := 0.3) -> bool:
	Input.action_press(&"move_forward")
	if corsa:
		Input.action_press(&"sprint")
	var arrivato := false
	var fermo := 0
	var ultimo := p.global_position
	for i in max_frames:
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < soglia:
			arrivato = true
			break
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
		fermo = fermo + 1 if p.global_position.distance_to(ultimo) < 0.002 else 0
		ultimo = p.global_position
		if fermo > 90:
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	if not arrivato:
		printerr("  bloccato in ", p.global_position, " andando verso ", t)
	return arrivato


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		print("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
