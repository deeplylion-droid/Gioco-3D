extends Node
## Test del finale del tunnel (build 0.5.0 «La storia», GDD del 15 novembre, finale A), col giocatore vero nella scena
## di prova sottomarino_prova.tscn. Senza schermo, a --fixed-fps 60:
## 1. i sei bambini al loro posto, nascosti e fermi prima della fine: nella stanza dopo il primo tratto della camera
##    stagna, coi piedi sul pavimento, girati verso il giocatore; i due davanti a circa 3 m, le quattro sagome dietro;
## 2. la sequenza: schianto, lei si stacca (il canto tace), silenzio, la camera si gira di 180 gradi, i bambini fermi,
##    quello col cubo fa due passi e porge il foglio, la camera si abbassa sul foglio (più di metà dello schermo per
##    5 s), nero e fine_demo; coi tempi di SalaSottomarino;
## 3. mai i bambini insieme a lei: quando compaiono lei è sparita e il canto è spento;
## 4. una seconda volta nella stessa sessione (la scena ricaricata) va uguale; col finale spento, il nero subito dopo
##    lo schianto, come nella 0.4.0.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_finale_tunnel.gd

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
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	print("1-3. Il finale")
	await _prova(true, true)
	print("4. Una seconda volta nella stessa sessione")
	await _prova(true, false)
	print("4. Col finale spento")
	await _prova(false, false)
	_fine()


func _carica() -> SalaSottomarino:
	get_tree().change_scene_to_file(LEVEL)
	await get_tree().process_frame
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	for i in 10:
		await get_tree().physics_frame
	var sott := get_tree().current_scene.get_node("SalaSottomarino") as SalaSottomarino
	sott.costruisci()
	for i in 400:
		if GameState.player.input_enabled:
			break
		await get_tree().process_frame
	return sott


func _prova(bambini: bool, tutto: bool) -> void:
	var sott: SalaSottomarino = await _carica()
	var p := GameState.player
	sott.finale_bambini = bambini
	sott.lei_stato = SalaSottomarino.Lei.VIA
	var L := sott.lunghezza()
	var d := sott.direzione(L)
	var r := sott.destra(L)
	var sg := sott.piano + SalaSottomarino.SOGLIA
	var pos := sott.punto(L) + d * 1.0
	pos.y = sg + 0.02
	p.teleport(pos)
	for i in 5:
		await get_tree().physics_frame
	var bb: Array = sott._bambini_finale
	if tutto:
		check(bb.size() == 6 and bb.all(func(b): return not b.visible and b.process_mode == Node.PROCESS_MODE_DISABLED),
				"sei bambini, nascosti e fermi prima della fine (%d)" % bb.size())
		var occhi := sott.punto(L) + d * SalaSottomarino.CAMERA_DOVE_GUARDA
		var spazio := p.get_world_3d().direct_space_state
		var fuori: Array = []
		for i in bb.size():
			var b := bb[i] as Bambino
			var q := b.global_position
			var dist := Vector2(q.x - occhi.x, q.z - occhi.z).length()
			var verso := Vector3(occhi.x - q.x, 0.0, occhi.z - q.z).normalized()
			var ray := PhysicsRayQueryParameters3D.create(q + Vector3.UP * 0.3, q - Vector3.UP * 0.3, Layers.WORLD)
			var h := spazio.intersect_ray(ray)
			var a_terra := not h.is_empty() and absf((h.position as Vector3).y - q.y) < 0.01
			var dentro := (q - sott.punto(L)).dot(d) > SalaSottomarino.CAMERA_TRATTO + 0.3 and sott._in_camera(q)
			var giusto := (2.7 <= dist and dist <= 3.3) if i < 2 else (dist > 3.3 and dist < 5.5)
			if not (a_terra and dentro and giusto and b.global_basis.z.normalized().dot(verso) > 0.97 and b.get_meta(&"sagoma") == (i >= 2)):
				fuori.append("%d: a %.2f m, a terra %s, nella stanza %s, girato %.2f" % [i, dist, a_terra, dentro, b.global_basis.z.normalized().dot(verso)])
		check(fuori.is_empty(), "al loro posto: nella stanza, coi piedi a terra, girati verso il giocatore; i due davanti a circa 3 m, le sagome dietro %s" % [fuori])
	var fasi := {}
	var t := [0.0]
	var fine := [false]
	sott.fase_finale_cambiata.connect(func(f: String): fasi[f] = t[0])
	sott.fine_demo.connect(func(): fine[0] = true)
	sott.chiudi_portello()
	var insieme := 0
	var canto := 0
	var girato := -2.0
	var foglio_min := 2.0
	var foglio_t := 0.0
	var visti := false
	var alto := float(get_viewport().get_visible_rect().size.y)
	while not fine[0] and t[0] < 40.0:
		await get_tree().process_frame
		t[0] += get_process_delta_time()
		var lei := sott.lei_tunnel.lei
		var bambini_visti := bb.any(func(b): return b.is_visible_in_tree())
		if bambini_visti:
			visti = true
			if lei.is_visible_in_tree():
				insieme += 1
			if not lei.has_meta(LeiTunnel.CANTO_ZITTO) and lei.is_visible_in_tree():
				canto += 1
		var cam := get_viewport().get_camera_3d()
		if sott.fase_finale == "fermi" and girato < -1.5:
			girato = (-cam.global_basis.z).dot(d)
		if sott.fase_finale == "foglio" and t[0] - float(fasi["foglio"]) > sott.finale_abbassa + 0.05 and sott._foglio:
			var f := sott._foglio
			var su := f.global_transform * Vector3(0.0, SalaSottomarino.FOGLIO.y * 0.5, 0.0)
			var giu := f.global_transform * Vector3(0.0, -SalaSottomarino.FOGLIO.y * 0.5, 0.0)
			var h := absf(cam.unproject_position(su).y - cam.unproject_position(giu).y) / alto
			foglio_min = minf(foglio_min, h)
			foglio_t += get_process_delta_time()
	if not bambini:
		check(fine[0] and not visti and not fasi.has("girata"), "col finale spento: niente bambini, il nero subito dopo lo schianto (%.1f s)" % t[0])
		check(fine[0] and t[0] < 7.0, "e la fine arriva come nella 0.4.0 (%.1f s)" % t[0])
		return
	var ordine := ["schianto", "stacca", "silenzio", "girata", "fermi", "porge", "foglio", "nero"]
	var in_ordine := ordine.all(func(f): return fasi.has(f))
	for k in range(1, ordine.size()):
		if in_ordine and float(fasi[ordine[k]]) < float(fasi[ordine[k - 1]]):
			in_ordine = false
	check(in_ordine and fine[0], "le fasi in ordine fino alla fine %s" % [fasi])
	if not in_ordine:
		return
	var dura := func(a: String, b: String) -> float: return float(fasi[b]) - float(fasi[a])
	check(absf(dura.call("schianto", "stacca") - 2.6) < 0.1, "lei resta premuta 2,6 s (%.2f)" % dura.call("schianto", "stacca"))
	check(absf(dura.call("stacca", "silenzio") - sott.finale_stacca) < 0.1, "si stacca in %.1f s (%.2f)" % [sott.finale_stacca, dura.call("stacca", "silenzio")])
	check(absf(dura.call("silenzio", "girata") - sott.finale_silenzio) < 0.1, "poi %.1f s di silenzio (%.2f)" % [sott.finale_silenzio, dura.call("silenzio", "girata")])
	check(absf(dura.call("girata", "fermi") - sott.finale_girata) < 0.1 and girato > 0.95,
			"la camera si gira di 180 gradi in %.1f s (%.2f s, guarda nella stanza %.2f)" % [sott.finale_girata, dura.call("girata", "fermi"), girato])
	check(absf(dura.call("fermi", "porge") - sott.finale_fermi) < 0.1, "i bambini fermi %.1f s (%.2f)" % [sott.finale_fermi, dura.call("fermi", "porge")])
	check(dura.call("porge", "foglio") > 0.8 and dura.call("porge", "foglio") < 4.5, "due passi e porge il foglio (%.2f s)" % dura.call("porge", "foglio"))
	var sul_foglio: float = dura.call("foglio", "nero") - sott.finale_abbassa
	check(absf(sul_foglio - sott.finale_foglio) < 0.15 and foglio_min > 0.5 and foglio_t > sott.finale_foglio - 0.2,
			"il foglio riempie più di metà dello schermo per %.0f s (%.1f s, almeno %.0f%% dell'altezza)" % [sott.finale_foglio, foglio_t, foglio_min * 100.0])
	check(fine[0] and absf(t[0] - float(fasi["nero"]) - 1.2) < 0.1, "nero in 1,2 s e la fine (%.2f s)" % (t[0] - float(fasi["nero"])))
	check(visti and insieme == 0 and canto == 0, "mai i bambini insieme a lei, e col canto spento (%d fotogrammi con lei, %d col canto)" % [insieme, canto])
	var porge := bb[0] as Bambino
	var occhi_p := p.global_position
	check(Vector2(porge.global_position.x - occhi_p.x, porge.global_position.z - occhi_p.z).length() < 3.0 - sott.porge_passi + 0.4,
			"il bambino col cubo è venuto avanti di due passi (a %.2f m)" % Vector2(porge.global_position.x - occhi_p.x, porge.global_position.z - occhi_p.z).length())
