extends Node
## Test automatico della demo della sala principale (architettura vera), simulando gli input:
## zaino sulla rastrelliera, aspirare dalla vasca d'arrivo, lampada della statua, sigla, la
## piscina a onde da svuotare con lo zaino (tappa 5 decisa dall'utente il 15 ottobre: l'acqua
## sparata dentro la vasca ci ritorna, la taratura da circa 1 minuto proposta prima, le micro
## medusine che se ne vanno con l'acqua, il pulsante della botola che si attiva a piscina vuota),
## il portello e il recinto aperto. Il pozzo e la sala pompe sono in test_tappe56.gd (con la
## taratura di serie, circa 30 secondi, e le medusine seguite da vicino).
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
	# Con gli interni si parte dal risveglio nel corridoio: si aspetta che finisca.
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var puddle: WaterTank = level.get_node("Piscina/Pozza")
	var svuota: PiscinaOnde = level.get_node("Piscina/SvuotaPiscina")
	var hatch_button: WaterButton = level.get_node("Piscina/PulsantePortello")
	var hatch: HingedHatch = level.get_node("Piscina/Portello")
	var lamp: FlickerLight = level.get_node("Vasca/Sfarfallio")

	print("La sala: architettura, collisioni e medusa")
	check(level.get_node_or_null("Sala/Architettura") != null, "l'architettura della sala è caricata")
	var polaroid := level.find_children("*", "PolaroidPhoto", true, false)
	var p10 := polaroid.filter(func(n): return int(n.get(&"photo")) == 10)
	check(polaroid.size() == 9 and p10.is_empty() and GameState.get_total(&"polaroid") == 9,
		"nella demo ci sono 9 Polaroid: P10 torna con la sala della torre (%d)" % polaroid.size())
	var medusa := level.get_node("Vasca/Medusa") as MedusaAffacciata
	check(medusa != null and medusa.get_model_instance() != null, "la medusa è affacciata alla vasca")
	var strappo := medusa.get_model_instance().find_child("Medusa_Strappo", true, false) as MeshInstance3D
	var sm := strappo.get_surface_override_material(0) as BaseMaterial3D if strappo else null
	check(strappo != null and not strappo.visible and sm != null and sm.vertex_color_use_as_albedo
			and sm.albedo_color.is_equal_approx(Color(0.7, 0.76, 0.96)), "lo strappo della fauce è nascosto, con la tinta della pelle bagnata")
	var ap := medusa.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(ap != null and ap.is_playing() and ap.current_animation == "affacciata", "con l'animazione affacciata in ciclo")
	var eye := medusa.get_eye_position()
	check(absf(eye.y - 1.63) < 0.1 and absf(eye.x) < 0.15 and eye.z > 11.5 and eye.z < 12.1, "l'occhio è sopra il bordo, all'altezza dei tuoi occhi (%s)" % eye)
	var pool: WaterTank = level.get_node("Vasca/VascaCentrale")
	check(absf(pool.get_surface_global_y() - 0.88) < 0.03 and not pool.suckable, "l'acqua della vasca è quasi al bordo e non si aspira")
	var det := level.get_node_or_null("Sala/Dettagli")
	if det:
		check(det.get_child_count() >= 100, "i dettagli della sala sono montati (%d nodi)" % det.get_child_count())
	var space := p.get_world_3d().direct_space_state
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-3, 1, 18), Vector3(-3, 1, 22)))
	check(not wall.is_empty() and absf(wall.position.z - 20.0) < 0.3, "il muro sud ha la collisione")
	var door_q := PhysicsRayQueryParameters3D.create(Vector3(0, 1, 18.5), Vector3(0, 1, 21.5))
	door_q.exclude = [p.get_rid()]
	var door := space.intersect_ray(door_q)
	if not door.is_empty():
		print("  (il raggio nel vano tocca ", door.collider, " in ", door.position, ")")
	check(door.is_empty() or door.position.z > 20.15, "il vano verso gli spogliatoi è libero")
	var ghost := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-1, 1, -1), Vector3(3, 1, -1)))
	check(ghost.is_empty(), "niente muri invisibili in mezzo alla piscina")
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1, 2), Vector3(0, -4, 2)))
	check(not floor_hit.is_empty() and floor_hit.position.y < -2.0, "il fondo della piscina ha la collisione")
	var pool_q := PhysicsRayQueryParameters3D.create(Vector3(0, 0.5, 14.0), Vector3(0, 0.5, 10.0))
	pool_q.exclude = [p.get_rid()]
	var pool_hit := space.intersect_ray(pool_q)
	check(not pool_hit.is_empty() and pool_hit.position.z > 12.1 and pool_hit.position.z < 12.5, "la vasca è solida: il muro davanti ferma (z %.2f)" % (pool_hit.position.z if not pool_hit.is_empty() else 0.0))

	print("Lo zaino sulla rastrelliera dei bagnini")
	check(not p.water_pack.equipped, "si parte senza zaino")
	await _hold(&"spray", 10)
	check(not p.water_pack.is_spraying, "senza zaino non si spruzza")
	var interni := level.get_node_or_null("Interni")
	if interni:
		# Con gli interni lo zaino è nello stanzino dei bagnini: si prende da lì.
		check(level.get_node_or_null("PostazioneBagnini") == null, "con gli interni la rastrelliera della sala non c'è")
		var picks := interni.find_children("*", "PackPickup", true, false)
		check(picks.size() == 1, "lo zaino è nello stanzino degli interni")
		var pack_holder: Node = (picks[0] as Node).get(&"remove_node") if picks.size() > 0 else null
		if picks.size() > 0:
			(picks[0] as PackPickup).interact(p)
		await _frames(3)
		check(p.water_pack.equipped and p.has_item(&"zaino_pompa"), "preso lo zaino: la pistola è in mano")
		check(p.water_pack.lance_rig != null, "la pistola 3D con le mani è montata")
		check(pack_holder == null or not is_instance_valid(pack_holder), "lo zaino sparisce dalla rastrelliera")
	else:
		var pack_node: Node3D = level.get_node("PostazioneBagnini/Zaino")
		var station: Node3D = level.get_node("PostazioneBagnini")
		var stand := station.global_position + station.global_basis.z * 1.2
		p.teleport(Vector3(stand.x, 0.0, stand.z), 0.0, 0.0)
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
	p.teleport(Vector3(2.5, 0, 18.0), 0.0, 0.0)
	Input.action_press(&"move_forward")
	await _frames(50)
	Input.action_release(&"move_forward")
	check(lamp.is_on, "avvicinandosi la lampada si accende")
	# Ripartendo da un checkpoint oltre il lampione, o con "Continua" da un salvataggio (anche
	# della v0.2.0), la lampada è già accesa: lo stesso percorso di GameState al caricamento.
	lamp.turn_off()
	GameState.capture_snapshot("Gioco/CheckpointStatua", 1, Transform3D(Basis(), Vector3(0, 0, 14.4)))
	GameState._restore_pending = true
	GameState._on_level_ready()
	await _frames(2)
	check(lamp.is_on and lamp.light.light_energy > 1.0, "ripartendo oltre il lampione la lampada è già accesa")
	lamp.turn_off()
	# (Prima del trigger, che LuciSala mette appena dopo la porta: z 18,1-19,1 per x -4..4.)
	GameState.capture_snapshot("inizio", -1, Transform3D(Basis(), Vector3(5.0, 0, 19.2)))
	GameState._restore_pending = true
	GameState._on_level_ready()
	await _frames(2)
	check(not lamp.is_on, "ripartendo dall'ingresso la lampada è spenta (si accende entrando)")
	lamp.turn_on(true)

	print("Aspirare dalla vasca d'arrivo")
	var arrival: WaterTank = level.get_node("Vasche/VascaArrivo")
	p.teleport(Vector3(-8.3, 0, 2.0), 0.0, 0.0)
	p.look_at_point(Vector3(-10.6, -0.22, 2.0))
	await _frames(3)
	var arrival_before := arrival.get_liters()
	await _hold(&"suck", 60)
	check(p.water_pack.tank_amount > 6.0, "aspira dalla vasca d'arrivo (%.1f l)" % p.water_pack.tank_amount)
	check(arrival.get_liters() < arrival_before - 5.0, "il livello della vasca d'arrivo scende")

	var jingle: WaterButton = level.get_node("Vasca/PulsanteSigla")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(0.0, 0, 14.6), 0.0, 0.0)
	p.look_at_point(jingle.global_position + Vector3(0, 0.12, 0))
	await _hold(&"spray", 40)
	check(jingle.powered, "il getto fa partire la sigla dal pulsante del piedistallo")

	print("Aspirare l'acqua della piscina a onde")
	p.water_pack.set_tank_amount(0.0)
	p.teleport(Vector3(-2.6, -1.95, -0.6), PI, 0.0)
	await _frames(10)
	p.look_at_point(Vector3(-0.9, -2.07, 1.6))
	await _frames(3)
	var before := puddle.get_liters()
	await _hold(&"suck", 90)
	var gained := p.water_pack.tank_amount
	check(gained > 12.0, "il serbatoio si riempie dalla piscina (%.1f l)" % gained)
	check(absf((before - puddle.get_liters()) - gained) < 0.05, "il livello della piscina scende davvero")

	print("La piscina a onde: si svuota con lo zaino")
	check(level.get_node_or_null("Piscina/TurbinaScarico") == null and level.get_node_or_null("Piscina/GonfiabileIncastrato") == null,
		"niente più turbina dello scarico né gonfiabile")
	var rotore := level.get_node_or_null("Sala/Interattivi/sala_turbina_scarico") as Node3D
	check(rotore == null or not rotore.visible, "la turbina dello scarico non si vede più")
	check(puddle.get_surface_global_y() > -1.8 and puddle.inner_size.x >= 13.0,
		"c'è l'acqua nella parte profonda (pelo a %.2f)" % puddle.get_surface_global_y())
	check(not hatch_button.enabled and not svuota.attivo, "con l'acqua il pulsante della botola è spento")
	# Le varianti dell'aspetto dell'acqua (proposte per l'utente): di serie resta com'è.
	var acqua := svuota.superficie()
	var stile_serie: Resource = acqua.get(&"style") if acqua else null
	check(svuota.aspetto == PiscinaOnde.Aspetto.OGGI and acqua != null and stile_serie != null, "l'acqua della piscina è com'era (aspetto di serie)")
	svuota.aspetto = PiscinaOnde.Aspetto.LEGGIBILE
	var stile_b := acqua.get(&"style") as WaterStyle
	check(stile_b != stile_serie and stile_b.reflection_strength > (stile_serie as WaterStyle).reflection_strength
			and stile_b.foam_shore_amount > (stile_serie as WaterStyle).foam_shore_amount
			and svuota.get_node_or_null("LampadaServizio") == null, "aspetto B: acqua più riflettente con la schiuma sul pelo, senza luci in più")
	svuota.aspetto = PiscinaOnde.Aspetto.LEGGIBILE_CON_LAMPADA
	var lampada := svuota.get_node_or_null("LampadaServizio") as SpotLight3D
	check(lampada != null and lampada.visible and lampada.global_position.y > 5.0 and (-lampada.global_basis.z).y < -0.99,
		"aspetto C: in più la lampada di servizio in alto, puntata in giù sulla parte profonda")
	svuota.aspetto = PiscinaOnde.Aspetto.OGGI
	check(acqua.get(&"style") == stile_serie and not lampada.visible, "si torna all'aspetto di serie")
	var segnale := svuota.get_node_or_null("SegnalePulsante") as Light3D
	check(segnale != null and not segnale.visible, "e la sua luce è spenta")
	# Il getto sul pulsante con l'acqua ancora dentro non fa niente.
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(0.6, -1.95, 1.0), PI, 0.0)
	await _frames(10)
	p.look_at_point(hatch_button.global_position + Vector3(0, 0.4, 0))
	await _hold(&"spray", 50)
	check(not hatch_button.powered, "il getto sul pulsante spento non apre niente")
	# Dal bordo est della vasca: l'acqua sparata dentro la vasca (sulla spiaggia) ci ritorna.
	p.teleport(Vector3(7.35, 0.0, 2.0), -PI * 0.5, 0.0)
	await _frames(10)
	check(p.is_on_floor() and absf(p.global_position.y) < 0.1, "si sta sul bordo est della piscina (%s)" % p.global_position)
	p.water_pack.set_tank_amount(20.0)
	var prima_spiaggia := puddle.get_liters()
	p.look_at_point(Vector3(2.0, 1.0, -9.0))
	await _hold(&"spray", 60)
	var dove_spiaggia := p.water_pack.hit_point
	await _frames(40)
	check(puddle.get_liters() > prima_spiaggia + 4.0, "l'acqua sparata dentro la vasca (in %s) ci ricola (+%.1f l)" % [dove_spiaggia, puddle.get_liters() - prima_spiaggia])
	var prima_fuori := puddle.get_liters()
	p.look_at_point(Vector3(13.0, 0.5, 2.0))
	await _hold(&"spray", 60)
	var dove_fuori := p.water_pack.hit_point
	await _frames(40)
	check(absf(puddle.get_liters() - prima_fuori) < 0.05, "l'acqua sparata fuori dalla vasca (in %s) non torna" % dove_fuori)
	# La taratura da circa 1 minuto (proposta prima delle scelte del 16 ottobre, resta come
	# opzione): si riempie e si svuota tutta, come un giocatore.
	svuota.taratura = PiscinaOnde.Taratura.UN_MINUTO
	puddle.fill = 1.0
	p.water_pack.set_tank_amount(0.0)
	await _frames(2)
	check(is_equal_approx(puddle.get_liters(), svuota.litri_da_togliere()), "taratura da 1 minuto: %.0f litri" % puddle.get_liters())
	var med := svuota.get_node_or_null("Medusine") as Medusine
	check(med != null and med.in_acqua() > 0, "nell'acqua nuotano le micro medusine (%d)" % (med.in_acqua() if med else 0))
	var esito: Array = await _svuota_piscina(puddle, Vector3(7.35, 0.0, 2.0), Vector3(6.5, -1.5, 2.0), Vector3(13.0, 0.5, 2.0))
	print("  (taratura da 1 minuto: %d pieni di zaino, %.0f secondi)" % [esito[0], esito[1]])
	check(puddle.fill <= 0.001, "la piscina si svuota tutta (fill %.3f)" % puddle.fill)
	check(int(esito[0]) == svuota.pieni_un_minuto, "servono %d pieni di zaino (%d)" % [svuota.pieni_un_minuto, int(esito[0])])
	check(float(esito[1]) > 45.0 and float(esito[1]) < 75.0, "circa 1 minuto di lavoro (%.0f s)" % float(esito[1]))
	await _frames(3)
	check(med == null or med.in_acqua() == 0, "a piscina vuota non resta nessuna medusina nell'acqua")
	check(hatch_button.enabled and svuota.attivo and segnale.visible and segnale.light_color.b < 0.3,
		"a piscina vuota il pulsante si attiva e il suo lampeggiante giallo si accende")
	check(String(GameState.snapshot.get("checkpoint", "")).ends_with("CheckpointPozzaVuota"), "checkpoint: piscina vuota")

	print("Portello")
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
	# Sotto c'è il pozzo della camera delle onde (tappe 5-6, test_tappe56.gd): la demo va avanti.
	check(not bool(level.get(&"demo_finished")), "la demo non finisce al portello: sotto c'è il pozzo")

	print("Area bimbi e recinto (tappa 5 rifatta)")
	check(level.get_node_or_null("RuotaESecchio") == null, "il secchio gigante è solo scenografia: niente ruota a pale da far girare")
	var cancello := level.get_node_or_null("Sala/Interattivi/sala_cancello_spiaggia") as Node3D
	if cancello:
		var space2 := p.get_world_3d().direct_space_state
		var varco := PhysicsRayQueryParameters3D.create(Vector3(-0.6, 1.0, -15.0), Vector3(-0.6, 1.0, -12.0))
		varco.exclude = [p.get_rid()]
		var colpo := space2.intersect_ray(varco)
		check(colpo.is_empty(), "il cancello del recinto è aperto: si passa (%s)" % (str(colpo.get("collider")) if not colpo.is_empty() else "libero"))

	if interni:
		print("Dagli spogliatoi alla sala")
		var shutters := interni.find_children("*", "Saracinesca", true, false)
		check(shutters.size() == 1, "c'è la saracinesca tra gli spogliatoi e la sala")
		if shutters.size() == 1:
			var d := shutters[0] as Node3D
			check(absf(d.global_position.x) < 0.1 and absf(d.global_position.z - 20.3) < 0.3,
				"la saracinesca combacia con il vano sud (%s)" % d.global_position)
			d.set(&"_latched", true)
			await _frames(60 * 10)
			check(bool(d.get(&"is_open")), "la saracinesca si alza")
			p.teleport(Vector3(0.0, 0.0, 21.4), 0.0, 0.0)
			await _frames(3)
			Input.action_press(&"move_forward")
			await _frames(150)
			Input.action_release(&"move_forward")
			check(p.global_position.z < 19.4, "dagli spogliatoi si entra nella sala (z %.2f)" % p.global_position.z)

	print("La medusa ti segue con l'occhio")
	p.teleport(Vector3(0.0, 0.0, 16.0), 0.0, 0.0)
	p.look_at_point(medusa.get_eye_position())
	await _frames(90)
	var to_cam := (p.camera.global_position - medusa.get_eye_position()).normalized()
	var dir_front := medusa.get_eye_direction()
	check(rad_to_deg(dir_front.angle_to(to_cam)) < 20.0, "di fronte, l'occhio ti guarda (%.1f gradi)" % rad_to_deg(dir_front.angle_to(to_cam)))
	p.teleport(Vector3(5.5, 0.0, 13.0), 0.0, 0.0)
	await _frames(90)
	var dir_side := medusa.get_eye_direction()
	var turn := rad_to_deg(dir_side.angle_to(dir_front))
	check(turn > 3.0 and turn < 17.0, "di lato, l'occhio si gira ma al massimo di 15 gradi (%.1f)" % turn)

	print("Easter egg: il getto in faccia le chiude l'occhio")
	check(not medusa.occhio_chiuso(), "l'occhio è aperto")
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(0.0, 0.0, 15.2), 0.0, 0.0)
	await _frames(5)
	p.look_at_point(medusa.get_eye_position())
	await _frames(3)
	# Primo colpo (1 s di getto): si chiude; poi, mentre è chiuso, un altro colpo di mezzo secondo.
	Input.action_press(&"spray")
	var chiuso_a := -1
	for i in 60:
		await get_tree().physics_frame
		if chiuso_a < 0 and medusa.occhio_chiuso():
			chiuso_a = i
	Input.action_release(&"spray")
	check(chiuso_a >= 0, "col getto in faccia l'occhio si chiude (dopo %.2f s)" % (chiuso_a / 60.0))
	await _frames(90)
	check(medusa.occhio_chiuso(), "e resta chiuso")
	Input.action_press(&"spray")
	await _frames(30)
	Input.action_release(&"spray")
	# Si riapre circa 5,75 s dopo il primo colpo (0,25 + 5 + 0,5): i colpi mentre è chiuso non lo
	# fanno ripartire (altrimenti sarebbe chiuso fino a circa 8,4 s).
	await _frames(216)
	check(not medusa.occhio_chiuso(), "e si riapre da solo dopo circa 5 s, anche se intanto lo colpisci ancora")

	print("B5: i bambini sulla balconata (spenti dal 16 ottobre), in un lampo")
	var kids: KidSighting = level.get_node("BambiniBalconata")
	var storm: Tempesta = level.find_children("*", "Tempesta", true, false)[0]
	var flashes := [0]
	storm.lampo.connect(func(_i): flashes[0] += 1)
	check(not kids.attivo, "nella sala i bambini sulla balconata sono spenti")
	p.teleport(Vector3(13.5, 4.5, -16.5), PI, 0.0)
	await _frames(5)
	check(kids.get_child_count() == 0, "sulla torre non compare nessuno")
	# Il meccanismo resta (si ripropone con la sala della torre): lo si riaccende solo qui.
	p.teleport(Vector3(0.0, 0.0, 16.0), 0.0, 0.0)
	await _frames(5)
	kids.attivo = true
	p.teleport(Vector3(13.5, 4.5, -16.5), PI, 0.0)
	await _frames(5)
	check(kids.get_child_count() >= 5, "riacceso, sulla torre compaiono i bambini sulla balconata")
	check(kids.get_child_count() > 0 and kids.get_child(0) is Bambino, "sono i bambini animati (ti seguono con la testa)")
	check(flashes[0] >= 1, "e un lampo li illumina")
	await _frames(150)
	storm.lampo_ora(1.0, 1.0)
	await _frames(5)
	var left := 0
	for c in kids.get_children():
		if not c.is_queued_for_deletion():
			left += 1
	check(left == 0, "al lampo dopo non c'è più nessuno")
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


## Svuota la piscina come farebbe un giocatore dal bordo: si gira verso l'acqua (mezzo secondo),
## aspira finché lo zaino è pieno, si gira (mezzo secondo) e spara fuori dalla vasca finché lo zaino
## è vuoto. Ritorna [pieni di zaino, secondi].
func _svuota_piscina(vasca: WaterTank, dove: Vector3, acqua: Vector3, fuori: Vector3, max_pieni := 40) -> Array:
	p.teleport(dove, 0.0, 0.0)
	await _frames(10)
	var fotogrammi := 0
	var pieni := 0
	while vasca.fill > 0.001 and pieni < max_pieni:
		p.look_at_point(acqua)
		await _frames(30)
		fotogrammi += 30
		Input.action_press(&"suck")
		var k := 0
		while p.water_pack.tank_amount < p.water_pack.tank_capacity - 0.01 and vasca.fill > 0.001 and k < 600:
			await get_tree().physics_frame
			k += 1
		Input.action_release(&"suck")
		fotogrammi += k
		pieni += 1
		p.look_at_point(fuori)
		await _frames(30)
		fotogrammi += 30
		Input.action_press(&"spray")
		k = 0
		while p.water_pack.tank_amount > 0.01 and k < 900:
			await get_tree().physics_frame
			k += 1
		Input.action_release(&"spray")
		fotogrammi += k
	return [pieni, fotogrammi / 60.0]
