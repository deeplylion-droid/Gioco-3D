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
	check(absf(wrapf(p.yaw + PI / 2.0, -PI, PI)) < 0.2, "e guarda verso est, verso la porta tagliafuoco (inizio con il mostro-squalo)")
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
	await _scena_squalo(start)
	p.teleport(start.global_position, PI / 2.0, 0.0)
	await _frames(3)
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


## L'inizio con il mostro-squalo (scripts/interni/risveglio_squalo.gd), fatto girare davvero: la bocca
## spalancata davanti alla faccia, lui che corre dentro il corridoio e passa la porta, la porta che si
## chiude e resta chiusa, il giocatore che riprende il controllo dov'era.
func _scena_squalo(start: Marker3D) -> void:
	print("L'inizio con il mostro-squalo")
	var s := level.get_node_or_null("Gioco/RisveglioSqualo") as RisveglioSqualo
	check(s != null and not s.tempi.is_empty(), "c'è la scena dello squalo, con i tempi dell'animazione")
	if s == null:
		return
	var pos0 := p.global_position
	var fatto := [false]
	s.finito.connect(func(): fatto[0] = true)
	# la torcia: spenta prima della scena, il tasto F durante la scena non deve toccarla
	var torcia: Torcia = null
	for n in p.find_children("*", "Node3D", true, false):
		if n is Torcia:
			torcia = n
	var torcia_prima := true
	if torcia:
		torcia_prima = torcia.accesa
		torcia.imposta_accesa(true)
	var torcia_toccata := false
	var premute := 0
	level.call(&"fai_risveglio", p, true)
	await _frames(2)
	if torcia:
		check(not torcia.accesa, "il gioco inizia a torcia spenta")
	check(not p.input_enabled and s.in_corso() and s.squalo != null, "il giocatore non si muove: la camera è guidata")
	var perno := level.find_child("PernoPortaTagliafuoco", true, false) as Node3D
	check(perno != null and absf(perno.rotation_degrees.y - s.apertura_porta) < 1.0, "la porta tagliafuoco è aperta (%.0f gradi)" % s.apertura_porta)
	var min_dist := 99.0
	var max_apertura := 0.0
	var max_angolo_in_minaccia := 0.0
	var dentro := true
	var alla_porta_y := 0.0
	var porta_t: float = s.tempi.get("porta", 10.0)
	var t := 0.0
	var corsa_x := -99.0
	var pelle_min := 99.0
	var scosse := 0
	var scossa_prima := 0.0
	var scossa_forte := 0.0
	var scossa_ultima := 0.0
	while not fatto[0] and t < 16.0:
		await get_tree().process_frame
		t += 1.0 / 60.0
		if torcia and premute < 2 and t > [3.0, 7.0][premute]:   # nella minaccia e nella fuga
			premute += 1
			await _tasto_torcia()
			t += 2.0 / 60.0
			torcia_toccata = torcia_toccata or torcia.accesa
		var sp: Vector3 = s.call(&"_scossa_passo")
		if sp.x > 0.008 and scossa_prima <= 0.008:
			scosse += 1
			scossa_forte = maxf(scossa_forte, float(s.get(&"_passo_forza")))
			scossa_ultima = float(s.get(&"_passo_forza"))
		scossa_prima = sp.x
		if s.squalo == null or not s.squalo.visible:
			continue
		var occhio := p.camera.global_position
		for q: Vector3 in s.call(&"_pelle_vicina", occhio):
			pelle_min = minf(pelle_min, q.distance_to(occhio))
		var bocca: Vector3 = s.call(&"_punto_bocca")
		var apertura: float = s.call(&"_bone_mondo", "bocca").distance_to(s.call(&"_bone_mondo", "mento_punta"))
		if t > 2.6 and t < 5.3:
			min_dist = minf(min_dist, occhio.distance_to(bocca))
			max_apertura = maxf(max_apertura, apertura)
			var avanti := -p.camera.global_basis.z
			max_angolo_in_minaccia = maxf(max_angolo_in_minaccia, rad_to_deg(avanti.angle_to(bocca - occhio)))
		for osso in ["spina", "testa", "radice"]:
			var b: Vector3 = s.call(&"_bone_mondo", osso)
			if b.x > 22.3:
				continue
			if b.z < -2.5 or b.z > -0.1 or b.y > 2.4:
				dentro = false
		var spina: Vector3 = s.call(&"_bone_mondo", "spina")
		if absf(spina.x - 21.97) < 0.3:
			alla_porta_y = maxf(alla_porta_y, spina.y)
		corsa_x = maxf(corsa_x, s.call(&"_bone_mondo", "radice").x)
	check(min_dist < 0.55, "la bocca arriva addosso alla camera (%.2f m)" % min_dist)
	check(max_apertura > 0.28, "ed è spalancata (%.2f m tra il labbro e il mento)" % max_apertura)
	check(max_angolo_in_minaccia < 22.0, "la camera la guarda in faccia (al massimo %.0f° di lato)" % max_angolo_in_minaccia)
	check(dentro, "lo squalo resta dentro il corridoio (niente muri attraversati)")
	check(pelle_min > 0.18, "la camera non entra mai nello squalo, anche con le scosse (al più vicino %.2f m dalla sua pelle)" % pelle_min)
	check(scosse >= 8 and scossa_forte > 0.8 and scossa_ultima < scossa_forte * 0.5,
		"la camera trema a ogni passo, forte vicino e sempre meno lontano (%d scosse, da %.2f a %.2f)" % [scosse, scossa_forte, scossa_ultima])
	check(corsa_x > 22.2, "corre fino oltre la porta tagliafuoco (x %.2f)" % corsa_x)
	check(alla_porta_y > 0.0 and alla_porta_y < 1.35, "alla porta si abbassa per passare (schiena a %.2f m)" % alla_porta_y)
	check(fatto[0] and t < porta_t + 4.5, "la scena finisce (%.1f s)" % t)
	var audio := get_node_or_null(^"/root/Audio")
	if audio:
		var c: Dictionary = audio.get(&"conteggio")
		check(int(c.get(&"squalo_minaccia", 0)) == 1 and int(c.get(&"jilly_richiamo", 0)) == 1
				and int(c.get(&"squalo_sbuffo", 0)) == 1 and int(c.get(&"porta_chiusa", 0)) >= 1,
			"si sentono il fiato, il richiamo di Jilly, lo sbuffo e la porta che sbatte")
		check(int(c.get(&"squalo_passo", 0)) >= 8, "e i passi pesanti (%d)" % int(c.get(&"squalo_passo", 0)))
		check(int(c.get(&"squalo_denti", 0)) == 3 and int(c.get(&"squalo_ringhio", 0)) == 1,
			"i denti ai tre morsi e il ringhio quando si gira")
	check(p.input_enabled and p.camera.position.is_zero_approx() and is_zero_approx(p.camera.rotation.z),
		"il giocatore riprende il controllo, la camera torna normale")
	check(p.global_position.distance_to(pos0) < 0.05, "ed è ancora dove si è svegliato")
	if torcia:
		check(premute == 2 and not torcia_toccata and not torcia.accesa, "il tasto F non accende la torcia durante la scena, e alla fine è com'era")
		await _tasto_torcia()
		check(torcia.accesa, "dopo la scena il tasto F la riaccende")
		torcia.imposta_accesa(torcia_prima)
	check(s.squalo == null, "lo squalo non c'è più")
	check(perno != null and is_zero_approx(perno.rotation.y), "la porta tagliafuoco è chiusa")
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(21.0, 1.0, -1.3), Vector3(23.5, 1.0, -1.3))
	q.exclude = [p.get_rid()]
	var muro := space.intersect_ray(q)
	check(not muro.is_empty() and absf(muro.position.x - 21.95) < 0.1, "e da lì non si passa")


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


func _tasto_torcia() -> void:
	var e := InputEventAction.new()
	e.action = &"torcia"
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await get_tree().process_frame
	e = InputEventAction.new()
	e.action = &"torcia"
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
