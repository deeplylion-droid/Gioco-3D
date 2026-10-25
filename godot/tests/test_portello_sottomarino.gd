extends Node
## Test del finale del tunnel sottomarino (collaudo P1: il battente chiudendosi spingeva il giocatore e lo schianto non
## si vedeva), col giocatore vero nella scena di prova sottomarino_prova.tscn. Dalla camera stagna, guardando la porta,
## a 0,3, 0,6, 1,0, 1,5 e 2,2 m dal piano della porta, sull'asse e 0,6 m di lato:
## - E chiude il portello (anche da vicinissimo);
## - mentre il battente si chiude il giocatore non viene spinto né attraversato: è già fermo sull'asse a 2,2 m;
## - durante lo schianto l'oblò con la faccia di lei sta al centro della vista (entro 10 gradi) e niente lo copre.
## Ogni prova ricarica la scena (il finale si fa una volta sola).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_portello_sottomarino.gd

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(1500.0, true, false, true).timeout.connect(func():
		printerr("  FALLITO tempo scaduto")
		_failed += 1
		_fine())


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _fine() -> void:
	Input.action_release(&"interact")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	for dentro in [0.3, 0.6, 1.0, 1.5, 2.2]:
		for lato in [0.0, 0.6]:
			await _prova(dentro, lato)
	_fine()


func _prova(dentro: float, lato: float) -> void:
	get_tree().change_scene_to_file(LEVEL)
	await get_tree().process_frame
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	await _frames(10)
	var level := get_tree().current_scene
	var p := GameState.player
	var sott := level.get_node("SalaSottomarino") as SalaSottomarino
	sott.costruisci()
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	sott.lei_stato = SalaSottomarino.Lei.VIA
	var L := sott.lunghezza()
	var d := sott.direzione(L)
	var r := sott.destra(L)
	var sg := sott.piano + SalaSottomarino.SOGLIA
	var pos := sott.punto(L) + d * dentro + r * lato
	pos.y = sg + 0.02
	p.teleport(pos)
	await _frames(5)
	# guardando la porta (il vano, all'altezza dell'oblò)
	var porta := sott.punto(L) + Vector3.UP * (sg - sott.punto(L).y + SalaSottomarino.OBLO_Y)
	p.look_at_point(porta)
	await _frames(5)
	var nome := "%.1f m%s" % [dentro, "" if lato == 0.0 else " (di lato %.1f m)" % lato]
	Input.action_press(&"interact")
	await _frames(2)
	Input.action_release(&"interact")
	await _frames(5)
	check(sott.finito, "%s: con E si chiude il portello" % nome)
	if not sott.finito:
		return
	# il passo indietro (0,6 s), poi il battente si chiude (0,7 s) e il volantino gira (1,3 s): da qui il giocatore è
	# fermo dove deve stare
	await _frames(40)
	var fermo := p.global_position
	var mosso := 0.0
	var contro := [false]
	var fine := [false]
	sott.lei_tunnel.schianto_contro.connect(func(): contro[0] = true)
	sott.fine_demo.connect(func(): fine[0] = true)
	var visti := 0
	var fotogrammi := 0
	var peggio := 0.0
	var schianto := false
	for i in 60 * 8:
		await get_tree().physics_frame
		mosso = maxf(mosso, p.global_position.distance_to(fermo))
		if sott.lei_stato == SalaSottomarino.Lei.PRESA:
			schianto = true
		if schianto and not fine[0]:
			fotogrammi += 1
			var oblo := sott._oblo_chiuso()
			var cam := p.camera.global_position
			var ang := rad_to_deg((-p.camera.global_basis.z).angle_to(oblo - cam))
			var q := PhysicsRayQueryParameters3D.create(cam, oblo + (cam - oblo).normalized() * 0.03, Layers.WORLD, [p.get_rid()])
			var libero := p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
			peggio = maxf(peggio, ang)
			if ang < 10.0 and libero:
				visti += 1
		if fine[0]:
			break
	var asse := (fermo - sott.punto(L))
	check(mosso < 0.02 and absf(asse.dot(d) - SalaSottomarino.CAMERA_DOVE_GUARDA) < 0.05 and absf(asse.dot(r)) < 0.05,
			"%s: il giocatore va sull'asse a %.1f m e il battente non lo sposta (mosso %.3f m, a %.2f m, di lato %.2f m)" % [
			nome, SalaSottomarino.CAMERA_DOVE_GUARDA, mosso, asse.dot(d), asse.dot(r)])
	check(contro[0] and fotogrammi > 30 and visti == fotogrammi, "%s: lo schianto si vede, l'oblò al centro della vista (%d fotogrammi su %d, peggio %.1f gradi)" % [
			nome, visti, fotogrammi, peggio])
