extends Node
## Test automatico della demo della sala principale (architettura vera), simulando gli input:
## zaino sulla rastrelliera, aspirare dalla vasca d'arrivo, lampada della statua, sigla,
## pozza, gonfiabile, turbina dello scarico, pozza vuota, portello (fine della demo), e il
## gioco dell'area bimbi (ruota a pale, secchio, cancello).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_sala.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var level: Node
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
	await _frames(5)
	level = get_tree().current_scene
	p = GameState.player
	var puddle: WaterTank = level.get_node("Piscina/Pozza")
	var turbine: Turbine = level.get_node("Piscina/TurbinaScarico")
	var inflatable: StuckInflatable = level.get_node("Piscina/GonfiabileIncastrato")
	var hatch_button: WaterButton = level.get_node("Piscina/PulsantePortello")
	var hatch: HingedHatch = level.get_node("Piscina/Portello")
	var lamp: FlickerLight = level.get_node("Statua/Sfarfallio")

	print("La sala: architettura, collisioni e medusa")
	check(level.get_node_or_null("Sala/Architettura") != null, "l'architettura della sala è caricata")
	check((level.get_node("Statua/Medusa") as MedusaStatue).get_model_instance() != null, "la medusa è sul piedistallo")
	var space := p.get_world_3d().direct_space_state
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-3, 1, 10), Vector3(-3, 1, 14)))
	check(not wall.is_empty() and absf(wall.position.z - 12.0) < 0.3, "il muro sud ha la collisione")
	var ghost := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-1, 1, -1), Vector3(3, 1, -1)))
	check(ghost.is_empty(), "niente muri invisibili in mezzo alla piscina")
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1, 2), Vector3(0, -4, 2)))
	check(not floor_hit.is_empty() and floor_hit.position.y < -2.0, "il fondo della piscina ha la collisione")

	print("Lo zaino sulla rastrelliera dei bagnini")
	check(not p.water_pack.equipped, "si parte senza zaino")
	await _hold(&"spray", 10)
	check(not p.water_pack.is_spraying, "senza zaino non si spruzza")
	var pack_node: Node3D = level.get_node("PostazioneBagnini/Zaino")
	p.teleport(Vector3(4.5, 0, 10.3), 0.0, 0.0)
	p.look_at_point(pack_node.global_position + Vector3(0, 0.3, 0))
	await _frames(3)
	check(p.interactor.current is PackPickup, "il raggio trova lo zaino")
	await _hold(&"interact", 2)
	await _frames(3)
	check(p.water_pack.equipped and p.has_item(&"zaino_pompa"), "preso lo zaino: la pistola è in mano")
	check(p.water_pack.lance_rig != null, "la pistola 3D con le mani è montata")
	check(not is_instance_valid(level.get_node_or_null("PostazioneBagnini/Zaino")), "lo zaino sparisce dalla rastrelliera")
	check(p.water_pack.tank_amount < 0.01, "il serbatoio è vuoto")

	print("Lampada della statua e sigla")
	check(not lamp.is_on, "la lampada è spenta")
	p.teleport(Vector3(-2.5, 0, 11.0), 0.0, 0.0)
	Input.action_press(&"move_forward")
	await _frames(50)
	Input.action_release(&"move_forward")
	check(lamp.is_on, "avvicinandosi la lampada si accende")

	print("Aspirare dalla vasca d'arrivo")
	var arrival: WaterTank = level.get_node("Vasche/VascaArrivo")
	p.teleport(Vector3(-8.3, 0, 2.0), 0.0, 0.0)
	p.look_at_point(Vector3(-10.6, -0.22, 2.0))
	await _frames(3)
	var arrival_before := arrival.get_liters()
	await _hold(&"suck", 60)
	check(p.water_pack.tank_amount > 6.0, "aspira dalla vasca d'arrivo (%.1f l)" % p.water_pack.tank_amount)
	check(arrival.get_liters() < arrival_before - 5.0, "il livello della vasca d'arrivo scende")

	var jingle: WaterButton = level.get_node("Statua/PulsanteSigla")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(0.0, 0, 10.6), 0.0, 0.0)
	p.look_at_point(jingle.global_position + Vector3(0, 0.12, 0))
	await _hold(&"spray", 40)
	check(jingle.powered, "il getto fa partire la sigla dal pulsante del piedistallo")

	print("Aspirare la pozza")
	p.water_pack.set_tank_amount(0.0)
	p.teleport(Vector3(-2.6, -1.95, -0.6), PI, 0.0)
	await _frames(10)
	p.look_at_point(Vector3(-0.9, -2.07, 1.6))
	await _frames(3)
	var before := puddle.get_liters()
	await _hold(&"suck", 90)
	var gained := p.water_pack.tank_amount
	check(gained > 12.0, "il serbatoio si riempie dalla pozza (%.1f l)" % gained)
	check(absf((before - puddle.get_liters()) - gained) < 0.05, "il livello della pozza scende davvero")

	print("Gonfiabile, turbina e scarico")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(3.4, -1.95, 1.2), PI, 0.0)
	await _frames(10)
	# Il getto scende per la gravità: si punta un po' sopra.
	p.look_at_point(turbine.global_position + Vector3(0, 0.3, 0))
	await _frames(3)
	check(turbine.jammed and inflatable.is_stuck(), "la turbina parte bloccata dal gonfiabile")
	await _hold(&"spray", 60)
	check(not inflatable.is_stuck() and not turbine.jammed, "il getto fa cadere il gonfiabile")
	await _frames(40)
	p.water_pack.set_tank_amount(20.0)
	p.look_at_point(turbine.global_position + Vector3(0.0, 0.3, 0.0))
	await _hold(&"spray", 120)
	check(turbine.powered, "la turbina gira (energia %.2f)" % turbine.energy)
	check(puddle.is_draining(), "lo scarico è aperto: la pozza si svuota")
	# Si alterna: aspira dalla pozza, spruzza sulla turbina, finché la pozza è vuota.
	for round in 12:
		if puddle.fill <= 0.001:
			break
		p.look_at_point(Vector3(1.2, -2.07, 2.4))
		await _hold(&"suck", 60)
		p.look_at_point(turbine.global_position + Vector3(0.0, 0.3, 0.0))
		await _hold(&"spray", 150)
	for i in 900:
		if puddle.fill <= 0.001:
			break
		await get_tree().physics_frame
	check(puddle.fill <= 0.001, "la pozza è vuota (fill %.3f)" % puddle.fill)

	print("Portello e fine della demo")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(0.6, -1.95, 1.0), PI, 0.0)
	await _frames(10)
	p.look_at_point(hatch_button.global_position + Vector3(0, 0.4, 0))
	await _frames(3)
	await _hold(&"spray", 60)
	if not hatch_button.powered:
		print("  (il getto colpisce: ", p.water_pack.hit_collider, " in ", p.water_pack.hit_point, ")")
	check(hatch_button.powered, "il pulsante del portello si accende")
	for i in 300:
		await get_tree().physics_frame
		if hatch.is_open:
			break
	check(hatch.is_open, "il portello si apre")
	check(bool(level.get(&"demo_finished")), "fine della demo")

	print("Area bimbi: ruota a pale, secchio e cancello")
	var toy: BucketWheel = level.get_node("RuotaESecchio")
	var wheel: Node3D = level.get_node("Sala/AreaBimbi/sala_ruota_pale")
	p.teleport(Vector3(-17.4, 0, -10.8), PI, 0.0)
	await _frames(10)
	var tipped := [false]
	toy.bucket_tipped.connect(func(): tipped[0] = true)
	for round in 10:
		if tipped[0]:
			break
		p.water_pack.set_tank_amount(20.0)
		p.look_at_point(wheel.global_position + Vector3(0, 0.45, 0))
		await _hold(&"spray", 150)
	check(toy.angular_speed > 0.5 or tipped[0], "il getto fa girare la ruota a pale")
	check(tipped[0], "il secchio si riempie e si ribalta")
	for i in 600:
		if toy.gate_open:
			break
		await get_tree().physics_frame
	check(toy.gate_open, "l'ondata apre il cancello della piscina")
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


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


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
