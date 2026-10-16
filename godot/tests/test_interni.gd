extends Node
## Test automatico dell'inizio del capitolo 1 (scenes/interni/interni.tscn), simulando gli input:
## la scena si carica con le collisioni, il giocatore parte dal marker del risveglio, lo zaino
## si raccoglie dalla rastrelliera, la vasca lava-piedi riempie il serbatoio, il getto sblocca il
## tornello e la turbina alza la saracinesca.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_interni.gd

const LEVEL := "res://scenes/interni/interni.tscn"

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

	print("La scena e il risveglio")
	check(level != null and level.scene_file_path == LEVEL, "la scena degli interni è caricata")
	check(p != null, "il giocatore è stato creato")
	var start: Marker3D = level.get_node("Gioco/Risveglio")
	check(p.global_position.distance_to(start.global_position) < 0.3, "il giocatore parte dal marker del risveglio")
	check(absf(wrapf(p.yaw - PI / 2.0, -PI, PI)) < 0.2, "e guarda verso ovest, lungo il corridoio")
	var space := p.get_world_3d().direct_space_state
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(15, 1, -1.3), Vector3(15, -1, -1.3)))
	check(not floor_hit.is_empty() and absf(floor_hit.position.y) < 0.05, "il pavimento del corridoio ha la collisione")
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(15, 1, -1.3), Vector3(15, 1, 2.0)))
	check(not wall.is_empty() and absf(wall.position.z) < 0.05, "il muro sud del corridoio ha la collisione")
	var passage := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(6.8, 1, -1.3), Vector3(6.8, 1, -5.0)))
	check(passage.is_empty(), "il passaggio verso gli spogliatoi è libero")
	check(level.find_children("*_neon", "", true, false).size() >= 3, "i neon che sfarfallano sono nodi Neon")
	var rosse := level.find_children("luce_emergenza_*", "", true, false).filter(func(n): return n is LuceEmergenza)
	check(rosse.size() >= 10, "le luci rosse sono LuceEmergenza (%d)" % rosse.size())

	print("Si cammina")
	Input.action_press(&"move_forward")
	await _frames(40)
	Input.action_release(&"move_forward")
	check(p.global_position.x < start.global_position.x - 0.5, "il giocatore cammina lungo il corridoio")

	print("Lo zaino sulla rastrelliera dello stanzino")
	check(not p.water_pack.equipped, "si parte senza zaino")
	var pack_node: Node3D = level.get_node("Zaino")
	p.teleport(Vector3(13.6, 0, -8.43), PI / 2.0 * -1.0, 0.0)
	p.look_at_point(pack_node.global_position + Vector3(0, 0.35, 0))
	await _frames(3)
	check(p.interactor.current is PackPickup, "il raggio trova lo zaino")
	await _hold(&"interact", 2)
	await _frames(3)
	check(p.water_pack.equipped and p.has_item(&"zaino_pompa"), "preso lo zaino: la pistola è in mano")
	check(not is_instance_valid(level.get_node_or_null("Zaino")), "lo zaino sparisce dalla rastrelliera")

	print("La vasca lava-piedi riempie il serbatoio")
	var tank: WaterTank = level.get_node("Acqua/VascaLavapiedi")
	p.water_pack.set_tank_amount(0.0)
	p.teleport(Vector3(9.7, 0, -11.6), 0.0, 0.0)
	await _frames(5)
	p.look_at_point(Vector3(9.7, -0.1, -13.2))
	await _frames(3)
	var before := tank.get_liters()
	await _hold(&"suck", 90)
	var gained := p.water_pack.tank_amount
	check(gained > 6.0, "il serbatoio si riempie dalla vasca (%.1f l)" % gained)
	check(tank.get_liters() < before - 5.0, "il livello della vasca lava-piedi scende")
	# Riscontro sulla v0.3.1: la vaschetta si riempie di nuovo quando smetti di aspirare.
	var ricarica := tank.get_node_or_null(^"Ricarica") as RicaricaVasca
	check(ricarica != null and absf(ricarica.get_livello() * tank.capacity_liters - before) < 0.05,
		"la vasca lava-piedi si riempie di nuovo fino al livello di partenza (%.1f l)" % before)
	var svuotata := tank.get_liters()
	await _frames(60)
	check(tank.get_liters() <= svuotata + 0.01, "appena smetti di aspirare l'acqua non risale subito")
	await _frames(240)
	var risale := tank.get_liters()
	check(risale > svuotata + 1.0, "poi risale piano (da %.1f a %.1f l in 4 s)" % [svuotata, risale])
	await _frames(60 * 26)
	check(absf(tank.get_liters() - before) < 0.05, "e torna com'era (%.1f l)" % tank.get_liters())

	print("Il pulsante del tornello dietro il vetro rotto")
	var button: WaterButton = level.get_node("Meccanismi/PulsanteTornello")
	var blocker: StaticBody3D = level.get_node("Meccanismi/BloccoTornello")
	var block := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(9.5, 1, -15.5), Vector3(9.5, 1, -17.5)))
	check(not block.is_empty(), "il tornello chiuso blocca il passaggio")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(10.2, 0, -16.0), 0.0, 0.0)
	await _frames(5)
	p.look_at_point(button.global_position + Vector3(0, 0.15, 0))
	await _frames(3)
	await _hold(&"spray", 90)
	if not button.powered:
		print("  (il getto colpisce: ", p.water_pack.hit_collider, " in ", p.water_pack.hit_point, ")")
	check(button.powered, "il getto passa dal vetro rotto e preme il pulsante")
	check(blocker.process_mode == Node.PROCESS_MODE_DISABLED, "il tornello si sblocca")
	await _frames(3)
	block = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(9.5, 1, -15.5), Vector3(9.5, 1, -17.5)))
	check(block.is_empty(), "si passa dal tornello")

	print("La turbina alza la saracinesca")
	var turbine: Turbine = level.get_node("Meccanismi/TurbinaSaracinesca")
	var door: Saracinesca = level.get_node("Meccanismi/Saracinesca")
	check(not door.is_open, "la saracinesca è chiusa")
	p.teleport(Vector3(10.3, 0, -17.6), 0.0, 0.0)
	await _frames(5)
	for round in 8:
		if door.is_open:
			break
		p.water_pack.set_tank_amount(20.0)
		p.look_at_point(turbine.global_position + Vector3(0, 0.15, 0))
		await _hold(&"spray", 150)
		for i in 60:
			if door.is_open:
				break
			await get_tree().physics_frame
	for i in 900:
		if door.is_open:
			break
		await get_tree().physics_frame
	check(door.is_open, "la saracinesca è su (turbina %.2f)" % turbine.energy)
	var exit_ray := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(9.7, 1, -19.5), Vector3(9.7, 1, -21.5)))
	check(exit_ray.is_empty(), "l'uscita verso la sala principale è libera")

	print("La Polaroid nell'armadietto")
	var pol: Node3D = level.get_node("Polaroid/Polaroid02")
	p.teleport(Vector3(4.4, 0, -7.9), PI / 2.0, 0.0)
	await _frames(5)
	p.look_at_point(pol.global_position + Vector3(0, 0.05, 0))
	await _frames(3)
	check(p.interactor.current is PolaroidPhoto, "il raggio trova la Polaroid P2 nell'armadietto")
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
