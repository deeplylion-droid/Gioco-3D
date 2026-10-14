extends Node
## Test automatico della demo della sala principale, simulando gli input:
## lampione all'ingresso, aspirare la pozza, far cadere il gonfiabile, far girare la turbina
## dello scarico, svuotare la pozza, aprire il portello (fine della demo).
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
	var hatch: PoweredDoor = level.get_node("Piscina/Portello")
	var lamp: FlickerLight = level.get_node("Statua/Sfarfallio")

	print("Stanzino dei bagnini: lo zaino sulla rastrelliera")
	check(not p.water_pack.equipped, "si parte senza zaino")
	await _hold(&"spray", 10)
	check(not p.water_pack.is_spraying, "senza zaino non si spruzza")
	var pack_node: Node3D = level.get_node("StanzinoBagnini/Zaino")
	p.teleport(Vector3(5.2, 0, 21.0), -PI * 0.5, 0.0)
	p.look_at_point(pack_node.global_position + Vector3(0, 0.3, 0))
	await _frames(3)
	check(p.interactor.current is PackPickup, "il raggio trova lo zaino")
	await _hold(&"interact", 2)
	await _frames(3)
	check(p.water_pack.equipped and p.has_item(&"zaino_pompa"), "preso lo zaino: la pistola è in mano")
	check(p.water_pack.lance_rig != null, "la pistola 3D con le mani è montata")
	check(not is_instance_valid(level.get_node_or_null("StanzinoBagnini/Zaino")), "lo zaino sparisce dalla rastrelliera")
	check(p.water_pack.tank_amount < 0.01, "il serbatoio è vuoto")
	var bath: WaterTank = level.get_node("StanzinoBagnini/VascaLavapiedi")
	p.teleport(Vector3(-0.4, 0, 20.3), 0.0, 0.0)
	p.look_at_point(bath.global_position + Vector3(0, 0.15, 0))
	await _hold(&"suck", 60)
	check(p.water_pack.tank_amount > 6.0, "aspira dalla vasca lava-piedi (%.1f l)" % p.water_pack.tank_amount)

	print("Ingresso e statua")
	check(not lamp.is_on, "il lampione è spento")
	p.teleport(Vector3(0, 0, 19.0), 0.0, 0.0)
	Input.action_press(&"move_forward")
	await _frames(80)
	Input.action_release(&"move_forward")
	check(lamp.is_on, "entrando nella sala il lampione si accende")

	print("Aspirare la pozza")
	p.water_pack.set_tank_amount(0.0)
	p.teleport(Vector3(-1.5, -2.1, 0.2), PI, 0.0)
	p.look_at_point(Vector3(-1.0, -2.1, 3.2))
	await _frames(3)
	var before := puddle.get_liters()
	await _hold(&"suck", 90)
	var gained := p.water_pack.tank_amount
	check(gained > 12.0, "il serbatoio si riempie dalla pozza (%.1f l)" % gained)
	check(absf((before - puddle.get_liters()) - gained) < 0.05, "il livello della pozza scende davvero")

	print("Gonfiabile, turbina e scarico")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(3.6, -2.38, 6.2), PI, 0.0)
	# Il getto scende per la gravità: si punta un po' sopra.
	p.look_at_point(turbine.global_position + Vector3(0, 0.3, 0))
	await _frames(3)
	check(turbine.jammed and inflatable.is_stuck(), "la turbina parte bloccata dal gonfiabile")
	await _hold(&"spray", 60)
	check(not inflatable.is_stuck() and not turbine.jammed, "il getto fa cadere il gonfiabile")
	await _frames(40)
	p.look_at_point(turbine.global_position + Vector3(0.0, 0.3, 0.0))
	await _hold(&"spray", 120)
	check(turbine.powered, "la turbina gira (energia %.2f)" % turbine.energy)
	check(puddle.is_draining(), "lo scarico è aperto: la pozza si svuota")
	# Si alterna: aspira dalla pozza, spruzza sulla turbina, finché la pozza è vuota.
	for round in 12:
		if puddle.fill <= 0.001:
			break
		p.look_at_point(Vector3(2.5, -2.3, 4.0))
		await _hold(&"suck", 60)
		p.look_at_point(turbine.global_position + Vector3(0.0, 0.3, 0.0))
		await _hold(&"spray", 150)
	for i in 600:
		if puddle.fill <= 0.001:
			break
		await get_tree().physics_frame
	check(puddle.fill <= 0.001, "la pozza è vuota (fill %.3f)" % puddle.fill)

	print("Portello e fine della demo")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(-2.0, -2.38, 2.0), PI, 0.0)
	p.look_at_point(hatch_button.global_position + Vector3(0, 0.12, 0))
	await _frames(3)
	await _hold(&"spray", 60)
	check(hatch_button.powered, "il pulsante del portello si accende")
	for i in 300:
		await get_tree().physics_frame
		if hatch.is_open:
			break
	check(hatch.is_open, "il portello si apre")
	check(bool(level.get(&"demo_finished")), "fine della demo")
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
