extends Node
## Test automatico degli ambienti tecnici (scenes/tecnici/tecnici.tscn): la scena si carica con le
## collisioni, il giocatore parte in fondo alla scala del pozzo e cammina, dalla camera delle onde
## si passa per il tunnel nella sala pompe, i marker per la logica di gioco ci sono tutti, la vasca di
## raccolta è piena e, con le scene messe come nel livello, il raccordo porta al pianerottolo davanti alla grata
## chiusa della scala degli interni e di lì, per il corridoio della tappa 7, al magazzino dei gonfiabili e alla serranda.
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

	print("La vasca di raccolta non si esaurisce (riscontro v0.3.1, punto 7)")
	var inesauribile := level.get_node_or_null("Acqua/VascaInesauribile") as VascaInesauribile
	check(inesauribile != null and inesauribile.vasca == tank, "la vasca ha il rabbocco che la tiene piena")
	var pieno := tank.fill
	var minimo_visto := 1.0
	var dati := 0.0
	for i in 40:
		dati += tank.take_water(20.0)   # 40 pieni di zaino, uno a fotogramma: molto più di quanto ci sta
		await get_tree().physics_frame
		minimo_visto = minf(minimo_visto, tank.fill)
	check(dati >= 40.0 * 20.0 - 0.1, "dà acqua a ogni zainata, anche dopo 40 di fila (%.0f l)" % dati)
	check(minimo_visto < pieno - 0.05, "il livello scende davvero mentre si aspira (%.2f -> %.2f)" % [pieno, minimo_visto])
	if inesauribile:
		check(minimo_visto >= inesauribile.fill_minimo() - 0.001, "ma non va mai sotto il minimo (%.2f, minimo %.2f)" % [minimo_visto, inesauribile.fill_minimo()])
	await _frames(60 * 8)
	check(tank.fill > minimo_visto + 0.1, "smesso di aspirare, la vasca si rabbocca (%.2f)" % tank.fill)

	print("Si cade nella vasca di raccolta e si risale con la scaletta (riscontro v0.3.1, punto 9)")
	var scaletta := level.get_node_or_null("Gioco/ScalettaVasca") as Ladder
	check(scaletta != null, "c'è la scaletta della vasca di raccolta")
	p.teleport(Vector3(36.0, 0.6, 0.6), 0.0, 0.0)
	await _frames(90)
	check(p.global_position.y < -1.0, "si cade dentro la vasca (y %.2f)" % p.global_position.y)
	if scaletta:
		# Verso la scaletta, contro il muro sud della vasca, e su con W.
		# Basta camminare verso la scaletta: ci si aggrappa già andandoci incontro.
		var presa := [false]
		var su_scala := func(si: bool) -> void: presa[0] = presa[0] or si
		p.ladder_changed.connect(su_scala)
		var base := scaletta.global_position + scaletta.get_climb_normal() * 0.6
		await _cammina_verso(Vector3(base.x, p.global_position.y, base.z), 300, false)
		var verso := -scaletta.get_climb_normal()
		p.set_look(atan2(-verso.x, -verso.z), 0.0)
		Input.action_press(&"move_forward")
		var fuori := false
		for i in 60 * 10:
			await get_tree().physics_frame
			if presa[0] and not p.is_on_ladder() and p.is_on_floor() and p.global_position.y > -0.1:
				fuori = true
				break
		await _frames(30)   # il giocatore tiene W ancora un attimo, come farebbe davvero
		Input.action_release(&"move_forward")
		p.ladder_changed.disconnect(su_scala)
		check(presa[0], "camminando verso la scaletta ci si aggrappa")
		check(fuori, "e salendo si esce dalla vasca (y %.2f)" % p.global_position.y)
		var dentro_vasca := Rect2(34.1, -0.6, 4.8, 3.0).has_point(Vector2(p.global_position.x, p.global_position.z))
		check(not dentro_vasca, "fuori dalla vasca, oltre il bordo (%s)" % str(p.global_position))

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
	var lv := (level as Node3D).global_transform
	var ok := true
	for loc in [Vector3(51.6, 0, 1.4), Vector3(51.6, 0, 0.6), Vector3(51.6, 3.625, -6.2), Vector3(50.0, 3.625, -7.8),
			Vector3(44.55, 7.25, -7.8)]:
		ok = ok and await _cammina_verso(lv * loc, 600)
	check(ok, "si cammina dalla porta della sala pompe su per le due rampe fino al pianerottolo T")
	var cima: Node3D = level.get_node("Marker/marker_raccordo_interni")
	check(cima.global_position.distance_to(Vector3(7.8, -1.8, 45.4)) < 0.05, "il marker in cima al raccordo è ai piedi della scala degli interni")
	var grata := _ray(p.get_world_3d().direct_space_state, lv * Vector3(44.2, 8.0, -7.8), lv * Vector3(42.5, 8.0, -7.8))
	check(not grata.is_empty(), "la grata chiusa blocca la scala degli interni")
	var bloccato := not await _cammina_verso(lv * Vector3(41.0, 9.05, -7.8), 240, false)
	check(bloccato and p.global_position.y < -1.0, "e di lì non si sale agli interni (%s)" % str(p.global_position))

	print("Tappa 7: il corridoio, il magazzino dei gonfiabili e la serranda (con gli interni al loro posto)")
	for m in ["marker_t7_inizio", "marker_t7_cima_scala", "marker_t7_magazzino", "marker_t7_serranda", "marker_t7_inizio_scia"]:
		check(level.get_node_or_null("Marker/" + m) is Marker3D, "c'è il marker " + m)
	p.teleport(lv * Vector3(44.55, 7.30, -7.8), p.yaw, 0.0)
	await _frames(5)
	ok = true
	var salita := 0.0
	# scelta β (21 ottobre): nel tratto basso di C2 la porta di servizio verso il fiume (aperta), e subito
	# dopo il buco dell'agnellino una grata chiusa; di là C2 continua fino al magazzino
	var sp := p.get_world_3d().direct_space_state
	check(_ray(sp, lv * Vector3(44.9, 8.25, -5.1), lv * Vector3(46.5, 8.25, -5.1)).is_empty(), "nel tratto basso di C2 la porta di servizio è aperta")
	check(not _ray(sp, lv * Vector3(44.9, 8.25, -4.0), lv * Vector3(46.5, 8.25, -4.0)).is_empty(), "accanto alla porta c'è il muro")
	for loc in [Vector3(44.55, 7.25, -4.0), Vector3(44.55, 9.05, 2.0), Vector3(44.55, 9.05, 4.4)]:
		ok = ok and await _cammina_verso(lv * loc, 900)
		salita = maxf(salita, p.global_position.y)
	check(ok, "dal pianerottolo T su per la scala di C2 fino al buco dell'agnellino")
	check(not await _cammina_verso(lv * Vector3(44.55, 9.05, 9.0), 240, false), "subito dopo il buco la grata non si passa")
	p.teleport(lv * Vector3(44.55, 9.10, 7.0), p.yaw, 0.0)
	await _frames(5)
	for loc in [Vector3(44.55, 9.05, 15.0), Vector3(30.0, 9.05, 15.0), Vector3(24.0, 9.05, 15.0), Vector3(19.3, 9.05, 15.0)]:
		ok = ok and await _cammina_verso(lv * loc, 900)
	check(ok, "di là dalla grata il corridoio va nel magazzino fino alla serranda")
	check(absf(p.global_position.y) < 0.1, "il magazzino è al livello della sala grande (y = %.2f)" % p.global_position.y)
	var serr: Node3D = level.get_node("Marker/marker_t7_serranda")
	check(serr.global_position.distance_to(Vector3(-15.0, 0, 19.3)) < 0.1, "il marker della serranda è appena dentro la sala, angolo sud-ovest (%s)" % str(serr.global_position))
	var space2 := p.get_world_3d().direct_space_state
	check(_ray(space2, Vector3(-15.0, 1.0, 21.0), Vector3(-15.0, 1.0, 19.0)).is_empty(), "sotto la serranda alzata si passa in piedi")
	check(not _ray(space2, Vector3(-15.0, 2.2, 21.0), Vector3(-15.0, 2.2, 19.0)).is_empty(), "e la serranda chiude sopra 1,95 m")
	check(not _ray(space2, Vector3(-17.0, 1.0, 21.0), Vector3(-17.0, 1.0, 19.0)).is_empty(), "accanto alla serranda c'è il muro")
	interni.queue_free()

	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Cammina in avanti verso t finché non ci arriva (in pianta). Falso se si blocca.
func _cammina_verso(t: Vector3, max_frames: int, avvisa := true) -> bool:
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
	if not arrivato and avvisa:
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
