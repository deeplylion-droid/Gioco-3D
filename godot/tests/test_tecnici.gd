extends Node
## Test automatico degli ambienti tecnici (scenes/tecnici/tecnici.tscn): la scena si carica con le
## collisioni, il giocatore parte in fondo alla scala del pozzo e cammina, dalla camera delle onde
## si passa per il tunnel nella sala pompe, i marker per la logica di gioco ci sono tutti.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tecnici.gd

const LEVEL := "res://scenes/tecnici/tecnici.tscn"
const MARKER := ["marker_portello", "marker_arrivo_scala", "marker_tunnel_sala_pompe", "marker_paratia_1", "marker_paratia_2",
	"marker_pompa_1", "marker_pompa_2", "marker_pompa_3", "marker_turbina_1", "marker_turbina_2", "marker_turbina_3",
	"marker_leva", "marker_grata_leva", "marker_schema", "marker_vasca_raccolta", "marker_monitor",
	"marker_porta_ponte", "marker_porta_ponte_perno"]

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
			"Ambienti/SalaPompe/TURBINA_1", "Ambienti/SalaPompe/TURBINA_2", "Ambienti/SalaPompe/TURBINA_3"]:
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

	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


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
