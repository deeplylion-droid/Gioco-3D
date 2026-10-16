extends Node
## Test automatico degli ambienti tecnici (scenes/tecnici/tecnici.tscn): la scena si carica con le
## collisioni, il giocatore parte in fondo alla scala del pozzo e cammina, dalla camera delle onde
## si passa per il tunnel nella sala pompe, i marker per la logica di gioco ci sono tutti, la vasca di
## raccolta è piena e, con le scene messe come nel livello, il raccordo porta ai piedi della scala degli interni.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tecnici.gd

const LEVEL := "res://scenes/tecnici/tecnici.tscn"
const MARKER := ["marker_portello", "marker_arrivo_scala", "marker_tunnel_sala_pompe", "marker_paratia_1", "marker_paratia_2",
	"marker_pompa_1", "marker_pompa_2", "marker_pompa_3", "marker_turbina_1", "marker_turbina_2", "marker_turbina_3",
	"marker_leva", "marker_grata_leva", "marker_schema", "marker_vasca_raccolta", "marker_monitor",
	"marker_porta_ponte", "marker_porta_ponte_perno", "marker_raccordo_sala", "marker_raccordo_interni", "marker_chiavistello", "marker_chiusura_stagna"]

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

	print("La scena e l'arrivo dalla scala")
	check(level != null and level.scene_file_path == LEVEL, "la scena degli ambienti tecnici è caricata")
	check(p != null, "il giocatore è stato creato")
	var start: Marker3D = level.get_node("Marker/marker_arrivo_scala")
	check(p.global_position.distance_to(start.global_position) < 0.3, "il giocatore parte in fondo alla scala")
	for m in MARKER:
		check(level.get_node_or_null("Marker/" + m) is Marker3D, "c'è il marker " + m)
	for n in ["Ambienti/CameraOnde/PARATIA_1", "Ambienti/CameraOnde/PARATIA_2", "Ambienti/SalaPompe/LEVA",
			"Ambienti/SalaPompe/GRATA_leva", "Ambienti/SalaPompe/PORTA_ponte", "Ambienti/SalaPompe/SCHERMO_CRT",
			"Ambienti/SalaPompe/TURBINA_1", "Ambienti/SalaPompe/TURBINA_2", "Ambienti/SalaPompe/TURBINA_3",
			"Ambienti/SalaPompe/CHIAVISTELLO", "Ambienti/SalaPompe/ATTUATORE_stagno", "Ambienti/SalaPompe/LEVA_base"]:
		check(level.get_node_or_null(n) != null, "c'è il nodo da animare " + n.get_file())

	print("Collisioni")
	var space := p.get_world_3d().direct_space_state
	for x in [3.0, 12.0, 22.0, 28.0, 34.0, 42.0]:
		var z := -3.0 if x == 34.0 else 0.0
		var hit := _ray(space, Vector3(x, 1, z), Vector3(x, -1, z))
		check(not hit.is_empty() and absf(hit.position.y) < 0.08, "c'è il pavimento in x = %.0f" % x)
	var muro := _ray(space, Vector3(8, 1, 0), Vector3(8, 1, 5))
	check(not muro.is_empty() and absf(muro.position.z - 2.2) < 0.2, "il muro sud della camera ferma")
	check(_ray(space, Vector3(14, 1, 0), Vector3(30, 1, 0)).is_empty(), "sotto le paratie alzate e nel tunnel si passa")
	check(not _ray(space, Vector3(28, 1, 0), Vector3(28, 1, 3)).is_empty(), "il tunnel ha le pareti")
	var porta := _ray(space, Vector3(44.5, 1, 1.4), Vector3(48, 1, 1.4))
	check(not porta.is_empty() and porta.position.x > 45.5, "la porta del ponte inferiore chiude la sala")
	check(level.find_children("*_neon", "", true, false).size() >= 1, "i neon che sfarfallano sono nodi Neon")
	var rosse := level.find_children("emergenza_*", "", true, false).filter(func(n): return n is LuceEmergenza)
	check(rosse.size() >= 6, "le luci rosse sono LuceEmergenza (%d)" % rosse.size())

	print("Si cammina")
	Input.action_press(&"move_forward")
	await _frames(60)
	Input.action_release(&"move_forward")
	check(p.global_position.x > start.global_position.x + 1.0, "il giocatore cammina lungo la camera delle onde")
	check(p.global_position.y > -0.2, "e non cade dal pavimento")
	p.teleport(Vector3(29, 0, 0), -PI / 2.0, 0.0)
	Input.action_press(&"move_forward")
	await _frames(90)
	Input.action_release(&"move_forward")
	check(p.global_position.x > 31.0 and p.global_position.y > -0.2, "dal tunnel si entra nella sala pompe (x = %.1f)" % p.global_position.x)

	print("Il pozzo del portello")
	var portello: Node3D = level.get_node("Marker/marker_portello")
	check(level.get_node_or_null("Gioco/ScalaPozzo") is Ladder, "il pozzo ha la scala a pioli (Ladder)")
	var su := _ray(p.get_world_3d().direct_space_state, portello.global_position + Vector3(0, -1.0, 0), portello.global_position + Vector3(0, 1.0, 0))
	check(su.is_empty(), "il buco del pozzo è libero sotto il portello")
	p.teleport(portello.global_position * Vector3(1, 0, 1) + Vector3(0.1, 0, 0), PI / 2.0, 0.0)   # guarda verso -X, la scala
	await _frames(5)
	Input.action_press(&"move_forward")
	var quota := 0.0
	for i in 600:
		await get_tree().physics_frame
		quota = maxf(quota, p.global_position.y)
		if quota > portello.global_position.y - 0.05:
			break
	Input.action_release(&"move_forward")
	check(quota > portello.global_position.y - 0.05, "dal fondo del pozzo si sale fino al fondo della piscina (%.2f di %.2f)" % [quota, portello.global_position.y])
	p.teleport(start.global_position, start.global_rotation.y, 0.0)
	await _frames(30)

	print("La vasca di raccolta")
	var tank: WaterTank = level.get_node("Acqua/VascaRaccolta")
	var pelo := tank.global_position.y + tank.inner_size.y * tank.fill
	check(absf(pelo - (-0.15)) < 0.03, "la vasca è piena d'acqua nera (pelo a %.2f)" % pelo)
	check(tank.get_liters() > 50.0, "e il serbatoio ha acqua da aspirare (%.0f l)" % tank.get_liters())

	print("Il raccordo fino agli interni (scene messe come nel livello)")
	var interni: Node3D = load("res://scenes/interni/interni.tscn").instantiate()
	interni.set(&"giocatore_proprio", false)
	interni.position = Vector3(-9.7, 0, 40.9)
	get_tree().root.add_child(interni)
	(level as Node3D).position = Vector3(0, -9.05, 1.36)
	(level as Node3D).rotation.y = -PI / 2.0
	level.get_node("Ambienti/SalaPompe/PORTA_ponte").queue_free()   # porta aperta
	check(portello.global_position.distance_to(Vector3(0, -2.25, 2.0)) < 0.02,
			"il centro del pozzo è sotto il centro del portello della piscina (%s)" % str(portello.global_position))
	await _frames(5)
	var da: Node3D = level.get_node("Marker/marker_raccordo_sala")
	p.teleport(da.global_position + Vector3(0, 0.05, 0), p.yaw, 0.0)
	await _frames(5)
	var tappe: Array[Vector3] = []
	for loc in [Vector3(51.6, 0, 1.4), Vector3(51.6, 0, 0.6), Vector3(51.6, 3.625, -6.2), Vector3(50.0, 3.625, -7.8),
			Vector3(44.2, 7.25, -7.8), Vector3(40.2, 9.05, -7.8)]:
		tappe.append((level as Node3D).global_transform * loc)
	var ok := true
	for t in tappe:
		ok = ok and await _cammina_verso(t, 600)
	check(ok, "si cammina dalla porta della sala pompe su per le due rampe e la scala degli interni")
	var fine := p.global_position
	check(absf(fine.y) < 0.1 and fine.distance_to(Vector3(7.8, 0, 41.6)) < 0.5,
			"e si arriva sul pianerottolo degli interni, davanti alla porta della sala pompe (%s)" % str(fine))
	var cima: Node3D = level.get_node("Marker/marker_raccordo_interni")
	check(cima.global_position.distance_to(Vector3(7.8, -1.8, 45.4)) < 0.05, "il marker in cima al raccordo è ai piedi della scala degli interni")
	interni.queue_free()

	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Cammina in avanti verso t finché non ci arriva (in pianta). Falso se si blocca.
func _cammina_verso(t: Vector3, max_frames: int) -> bool:
	Input.action_press(&"move_forward")
	var arrivato := false
	for i in max_frames:
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			arrivato = true
			break
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	if not arrivato:
		printerr("  bloccato in ", p.global_position, " andando verso ", t)
	return arrivato


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))


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
