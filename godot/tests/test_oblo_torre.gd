extends Node
## Test dell'oblò con lei nel muro est della torre (ObloLei, accanto alla bocca del tubo), col giocatore vero:
## 1. l'oblò sta nel foro del muro (torre_gioco.json, oblo_lei), lontano dalla bocca del tubo, e dal pavimento si vede;
## 2. al buio, col giocatore al fondo che guarda altrove, lei compare (una volta); guardandola, la vede;
## 3. entrando nella bocca del tubo (parte l'inseguimento) lei se ne va col suo distacco lento e non torna più, anche
##    tornando al fondo e girandosi.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_oblo_torre.gd

const PLAYER := "res://scenes/player/player.tscn"

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(600.0, true, false, true).timeout.connect(func():
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.PRIMA_DEL_RISVEGLIO
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	torre.crea_luci = false
	add_child(torre)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(20)
	var o := torre.oblo

	print("1. Il posto")
	var d: Dictionary = torre.dati["oblo_lei"]
	var centro := SalaTorre.b(d["centro"])
	check(o != null and o.global_position.distance_to(centro) < 0.001 and o.normale().distance_to(Vector3.LEFT) < 0.001,
			"l'oblò sta nel foro del muro est, col vetro verso la sala")
	var bocca := SalaTorre.b([40.0, 17.4, SalaTorre.FONDO_Z + 1.6])
	var mezzo := float(d["lato"]) * 0.5
	# il collare della bocca ha raggio 1,48: fra il bordo della piastra e il collare resta muro
	check(Vector2(bocca.z - centro.z, bocca.y - centro.y).length() - 1.48 - mezzo * sqrt(2.0) > 0.0 or absf(bocca.z - centro.z) - 1.48 - mezzo > 0.5,
			"la piastra non copre la bocca del tubo (%.2f m di muro fra i due)" % (absf(bocca.z - centro.z) - 1.48 - mezzo))
	var lontano := Vector3(35.9, SalaTorre.FONDO_Z, -13.4)
	p.teleport(lontano)
	await _frames(10)
	var spazio := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p.camera.global_position, o.global_transform * Vector3(0, 0, 0.05), Layers.WORLD, [p.get_rid()])
	check(spazio.intersect_ray(q).is_empty(), "dal pavimento, a 4 m, il vetro si vede (niente davanti)")

	print("2. Lei compare")
	await _frames(30)
	check(o.stato == ObloLei.Stato.ATTESA, "prima del buio lei non c'è")
	GameState.luci = GameState.Luci.BLACKOUT
	# guardando via (verso il pozzo) lei compare dietro il vetro
	p.look_at_point(SalaTorre.b(torre.dati["pozzo"]) + Vector3.UP * 1.5)
	await _frames(10)
	check(o.stato == ObloLei.Stato.PRONTA and o.lei != null, "al buio, al fondo, guardando altrove: lei compare dietro il vetro")
	p.look_at_point(centro)
	await _frames(100)
	check(o.stato == ObloLei.Stato.VISTA, "guardandola, il giocatore la vede (lei resta)")

	print("3. L'inseguimento")
	var finita := [false]
	o.finita.connect(func(): finita[0] = true)
	p.teleport(SalaTorre.b([38.8, 17.4, SalaTorre.FONDO_Z + 1.0]))
	await _frames(5)
	check(o.stato == ObloLei.Stato.VIA and not o.attivo, "entrando nella bocca del tubo lei se ne va (distacco lento)")
	for i in 600:
		if finita[0]:
			break
		await get_tree().process_frame
	check(finita[0] and o.lei == null, "dopo il distacco l'oblò resta vuoto")
	p.teleport(lontano)
	await _frames(5)
	p.look_at_point(SalaTorre.b(torre.dati["pozzo"]) + Vector3.UP * 1.5)
	await _frames(30)
	p.look_at_point(centro)
	await _frames(30)
	check(o.stato == ObloLei.Stato.FINITA and o.lei == null, "tornando al fondo lei non ricompare")
	check(bool(o.save_state().get("finito", false)), "lo stato si salva coi checkpoint (finito)")
	_fine()
