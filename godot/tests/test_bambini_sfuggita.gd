extends Node
## Test automatico dei bambini visti di sfuggita (BambinoSfuggita; proposta approvata dall'utente il 25 ottobre). Per
## ogni punto, nella sua zona caricata da sola:
## 1. il bambino poggia a terra (un raggio verso il basso trova il pavimento entro [constant TERRA_MAX] m dai piedi) e
##    al suo posto non entra in niente (una capsula larga come lui, dal pavimento in su);
## 2. la strada della fuga è libera: la stessa capsula, spostata da un punto all'altro, non tocca muri né oggetti, e
##    sotto ogni punto c'è il pavimento;
## 3. dove sparisce (l'ultimo punto) dalla zona del giocatore non si vede (muri in mezzo da ogni punto della zona);
## 4. col giocatore nella zona girato dall'altra parte il bambino compare, e mai mentre il giocatore guarda il suo
##    posto; guardato, scappa, e sparisce solo quando il giocatore non lo vede più; finito, non ricompare.
## I punti: nella risalita (scena di prova, con le stanze caricate) e nel tunnel sottomarino (costruito da solo).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_bambini_sfuggita.gd

const SCENA := "res://tests/scene/risalita_prova.tscn"
const TERRA_MAX := 0.05
## Il bambino come capsula (l'agnellino è più piccolo: la misura del più grande, il bambino a cubo).
const RAGGIO := 0.22
const ALTO := 1.15

var _passed := 0
var _failed := 0
var _p: Player


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	print("La risalita (nella scena di prova, coi suoi stanzoni caricati)")
	get_tree().change_scene_to_file(SCENA)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _frames(10)
	_p = GameState.player
	_p.camera.make_current()
	var ris := get_tree().current_scene.get_node(^"Risalita")
	var tutti := ris.find_children("*", "BambinoSfuggita", true, false)
	check(not tutti.is_empty(), "nella risalita ci sono bambini visti di sfuggita (%d)" % tutti.size())
	_p.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for b: BambinoSfuggita in tutti:
		# il giocatore nella zona del bambino: lì le stanze vicine si caricano (il capannone del fiume)
		_p.global_position = (b.get_parent() as Node3D).to_global(b.zona.get_center())
		for i in 1200:
			await get_tree().process_frame
			if not bool(ris.call(&"lavori_in_corso")):
				break
		await _frames(10)
		await _prova(b)
	print("Il tunnel sottomarino (costruito da solo)")
	var sala := SalaSottomarino.new()
	get_tree().root.add_child(sala)
	sala.costruisci()
	await _frames(10)
	var nel_tunnel := sala.find_children("*", "BambinoSfuggita", true, false)
	check(not nel_tunnel.is_empty(), "nel tunnel c'è il bambino visto di sfuggita")
	for b: BambinoSfuggita in nel_tunnel:
		await _prova(b)
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)


func _globale(b: BambinoSfuggita, q: Vector3) -> Vector3:
	return (b.get_parent() as Node3D).to_global(q)


func _pavimento(da: Vector3) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(da + Vector3.UP * 1.0, da + Vector3.DOWN * 1.0)
	q.exclude = [_p.get_rid()]
	var hit := get_viewport().find_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else null


## La capsula del bambino da [param a] a [param b] (i piedi), sollevata di 5 cm: tocca qualcosa?
func _urta(a: Vector3, b: Vector3) -> Array:
	var forma := CapsuleShape3D.new()
	forma.radius = RAGGIO
	forma.height = ALTO
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis.IDENTITY, a + Vector3.UP * (0.05 + ALTO * 0.5))
	q.motion = b - a
	q.exclude = [_p.get_rid()]
	var spazio := get_viewport().find_world_3d().direct_space_state
	var r := spazio.cast_motion(q)
	if r.is_empty() or r[0] >= 1.0:
		return []
	q.transform.origin += (b - a) * r[1]
	q.motion = Vector3.ZERO
	var dove := spazio.get_rest_info(q)
	return [dove.get("point", Vector3.ZERO), r[1]]


func _vista_libera(da: Vector3, a: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(da, a)
	q.exclude = [_p.get_rid()]
	return get_viewport().find_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _prova(b: BambinoSfuggita) -> void:
	print("- ", b.name)
	# 1. a terra e libero
	var piedi := b.global_position
	var terra = _pavimento(piedi)
	check(terra != null and absf((terra as Vector3).y - piedi.y) < TERRA_MAX,
			"poggia a terra (pavimento a %s m dai piedi)" % (("%+.3f" % ((terra as Vector3).y - piedi.y)) if terra != null else "-"))
	var u := _urta(piedi, piedi + Vector3(0.001, 0, 0))
	check(u.is_empty(), "al suo posto non entra in niente%s" % ((" (tocca a %s)" % str(u[0])) if not u.is_empty() else ""))
	# 2. la strada della fuga
	var prima := piedi
	var i := 0
	for q in b.via:
		var g := _globale(b, q)
		var t2 = _pavimento(g)
		check(t2 != null and absf((t2 as Vector3).y - g.y) < TERRA_MAX, "fuga, punto %d: c'è il pavimento" % i)
		var urto := _urta(prima, g)
		check(urto.is_empty(), "fuga, tratto %d: la strada è libera%s" % [i, ((" (tocca a %s)" % str(urto[0])) if not urto.is_empty() else "")])
		prima = g
		i += 1
	# 3. dove sparisce non si vede dalla zona
	var fine := _globale(b, b.via[b.via.size() - 1]) + Vector3.UP * 0.6
	var visti := 0
	var campioni := 0
	var z := b.zona
	for ix in 5:
		for iz in 9:
			var dove := _globale(b, z.position + Vector3(z.size.x * (ix + 0.5) / 5.0, 0.2, z.size.z * (iz + 0.5) / 9.0))
			var t3 = _pavimento(dove)
			if t3 == null:
				continue
			campioni += 1
			if _vista_libera((t3 as Vector3) + Vector3.UP * 1.6, fine):
				visti += 1
	check(campioni > 5 and visti == 0, "dove sparisce, dalla zona non si vede (%d punti su %d)" % [visti, campioni])
	# 4. comparsa, fuga, sparizione
	# (dal punto da cui lo si vede di solito, nella zona)
	var dentro := _globale(b, b.da_dove) - Vector3.UP * 1.6
	var t4 = _pavimento(dentro)
	if t4 != null:
		dentro = t4
	_metti(dentro, b.global_position, true)
	var t := 0.0
	while t < 3.0 and b.stato == BambinoSfuggita.Stato.ATTESA:
		await _frames(1)
		t += 1.0 / 60.0
	check(b.stato == BambinoSfuggita.Stato.GUARDA, "col giocatore nella zona girato dall'altra parte, compare")
	# lo si guarda
	_metti(dentro, b.global_position, false)
	t = 0.0
	while t < 8.0 and b.stato == BambinoSfuggita.Stato.GUARDA:
		await _frames(1)
		t += 1.0 / 60.0
	check(b.stato == BambinoSfuggita.Stato.SCAPPA, "guardato, scappa (dopo %.1f s)" % t)
	t = 0.0
	while t < 15.0 and b.stato == BambinoSfuggita.Stato.SCAPPA:
		await _frames(1)
		t += 1.0 / 60.0
		_guarda(b.bambino.punto_testa())   # lo segue con lo sguardo
		if OS.has_environment("DEBUG_FUGA"):
			print("    fuga %.2f %s vis %s cam %s" % [t, str(b.bambino.global_position.snapped(Vector3.ONE * 0.01)), b.bambino.visibile_da(_p), get_viewport().get_camera_3d() == _p.camera])
	check(b.stato == BambinoSfuggita.Stato.FINITO, "sparisce alla fine della fuga (%.1f s)" % t)
	var corsa := b.bambino.global_position.distance_to(b.global_position)
	check(corsa > 1.0, "è sparito dopo essere scappato (%.1f m), quando non si vedeva più" % corsa)
	# finito: non ricompare
	_metti(dentro, b.global_position, true)
	await _frames(60)
	check(b.stato == BambinoSfuggita.Stato.FINITO and not b.bambino.visible, "finito, non ricompare")
	var s := b.save_state()
	check(bool(s.get("finito", false)), "lo stato si salva (finito)")


## Il giocatore in [param dove], che guarda verso [param punto] o (con [param via]) dalla parte opposta.
func _metti(dove: Vector3, punto: Vector3, via: bool) -> void:
	_p.global_position = dove
	var occhio := _p.get_eye_position()
	var mira := punto + Vector3.UP * 0.8
	if via:
		mira = occhio - (mira - occhio)
	_guarda(mira)


## Lo sguardo e la camera insieme (il giocatore è fermo: la camera non la gira lui).
func _guarda(punto: Vector3) -> void:
	_p.look_at_point(punto)
	_p.camera.global_transform = _p.get_aim_transform()
