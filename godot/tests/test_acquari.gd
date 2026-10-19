extends Node
## Test automatico dell'enigma degli acquari nella sala principale (GDD, "L'enigma degli acquari"),
## simulando gli input dello zaino (aspira col tasto destro, versa col getto).
## 1. Al primo passaggio gli acquari non ci sono e le lampade del portone sono spente.
## 2. Rientrando dal magazzino (tappa 7, si apre la serranda) compaiono e le lampade si accendono,
##    ma prima della tappa 8 non funzionano: non si aspira e non si versa.
## 3. Dopo la tappa 8 il portone non si apre da solo.
## 4. Il colore: aspirando il serbatoio prende il colore dell'acquario, la finestrella e il getto
##    lo mostrano; aspirando un colore lo zaino butta via l'acqua chiara che aveva (scelta B
##    dell'utente); versando l'acquario del miscuglio cambia colore mentre si riempie.
## 5. Un miscuglio sbagliato (1 giallo + 2 blu) diventa torbido e il portone resta chiuso; la valvola
##    colpita col getto lo svuota col gorgo e i colorati tornano pieni.
## 6. Il giro dopo, 2 giallo + 1 blu, partendo con acqua chiara nello zaino: verde e il portone si apre.
## 7. I colorati non si esauriscono; la tolleranza del rapporto.
## 8. I checkpoint: prima della tappa 7, torbido, risolto.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_acquari.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var level: Node
var p: Player
var enigma: EnigmaAcquari
var portone: PortoneTorre
var giallo: WaterTank
var blu: WaterTank
var misto: WaterTank
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	await _aspetta_livello()
	check(enigma != null, "c'è l'enigma degli acquari nella sala")
	if enigma == null:
		_fine()
		return
	check(portone != null and portone.apertura == PortoneTorre.Apertura.SOLO_ENIGMA,
		"il portone della torre lo apre solo l'enigma")
	for n in ["AcquarioGiallo", "AcquarioBlu", "AcquarioMisto", "Valvola", "Disegno", "LampadePortone"]:
		check(enigma.get_node_or_null(n) != null, "c'è il nodo %s" % n)

	print("1. Primo passaggio: gli acquari non ci sono, le lampade sono spente")
	await _frames(5)
	check(not enigma.comparsi and not giallo.visible and not misto.visible, "gli acquari non ci sono")
	check(not _lampade_accese(), "le lampade del portone sono spente")
	check(not giallo.is_in_group(&"water_sources") and not misto.is_in_group(&"water_catchers"),
		"nascosti non si aspirano e non prendono il getto")
	check(_collisioni_spente(), "e non hanno collisioni")
	var cp_prima := _salva("TestPrimaTappa7")

	print("2. Tappa 7: rientri dal magazzino, compaiono; prima della tappa 8 non funzionano")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	_serranda().call(&"apri")
	await _frames(5)
	check(enigma.comparsi and giallo.visible and blu.visible and misto.visible, "gli acquari ci sono")
	# Con gli acquari comincia il caricamento della sala della torre in un thread: all'apertura del
	# portone è già pronta anche su un PC lento. Il guscio dietro il portone resta finché non si apre.
	var sala_p := get_tree().current_scene
	await _frames(2)
	check(bool(sala_p.get(&"_torre_in_caricamento")) or sala_p.get(&"_torre_pronta") != null,
		"compaiono gli acquari: la torre comincia a caricarsi in un thread")
	check(sala_p.get(&"sala_torre") == null and sala_p.find_child("sala_torre_guscio", true, false) != null,
		"ma non entra nella sala (il guscio dietro il portone resta)")
	check(_lampade_accese(), "le lampade del portone sono accese")
	check(not _collisioni_spente(), "e hanno le collisioni")
	# L'acqua vera dell'addon sui tre acquari (la mette enigma-ambiente): con le 7 masse d'acqua che
	# ci sono già fanno 10, e l'addon ne regge 12.
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		for t in [giallo, blu, misto]:
			# Se l'acqua dell'addon c'è già nella scena (la mette enigma-ambiente) non se ne aggiunge un'altra.
			var ha_link := false
			for c in t.find_children("*", "", true, false):
				ha_link = ha_link or c is WaterTankLink
			if ha_link:
				continue
			var link := (load("res://addons/acqua/scenes/acqua_per_vasca.tscn") as PackedScene).instantiate()
			link.set(&"tank", t)
			t.add_child(link)
		await _frames(5)
		var masse: int = (wm.call(&"get_bodies") as Array).size()
		var massimo: int = (wm.get_script() as Script).get_script_constant_map().get("MAX_BODIES", 0)
		check(masse >= 10 and masse <= massimo, "le masse d'acqua dell'addon ci stanno tutte (%d su %d)" % [masse, massimo])
	check(not enigma.attivi, "prima della tappa 8 non funzionano")
	p.water_pack.set_tank_amount(0.0)
	await _aspira(giallo)
	check(p.water_pack.tank_amount < 0.5 and giallo.fill > 0.93, "dal giallo non si aspira (%.1f L)" % p.water_pack.tank_amount)
	p.water_pack.set_tank_amount(20.0)
	await _versa()
	check(misto.fill < 0.001, "nel miscuglio non si versa (%.2f)" % misto.fill)

	print("3. Tappa 8: lei se ne va, il portone non si apre da solo")
	var lei: Node = level.get(&"lei_sbuca")
	lei.call(&"load_state", {"finita": true})
	if lei.has_signal(&"andata_via"):
		lei.emit_signal(&"andata_via")
	await _frames(30)
	check(enigma.attivi, "ora gli acquari funzionano")
	check(not portone.in_movimento and not portone.is_aperto(), "il portone resta chiuso")
	check(not portone.si_puo_aprire(), "e la fine della demo non lo apre")

	print("4. Il colore dell'acqua")
	p.water_pack.set_tank_amount(0.0)
	var prima := giallo.get_liters()
	await _aspira(giallo)
	var preso := prima - giallo.get_liters()
	check(p.water_pack.tank_amount > 19.5, "dal giallo si riempie il serbatoio (%.1f L)" % p.water_pack.tank_amount)
	check(absf(preso - p.water_pack.tank_amount) < 0.5, "i litri si conservano (%.1f, %.1f)" % [preso, p.water_pack.tank_amount])
	check(WaterMix.frazione(p.water_pack.water_mix, WaterMix.GIALLO) > 0.99, "il serbatoio è giallo")
	var gauge := p.find_children("*", "ReservoirGauge", true, false)
	if not gauge.is_empty():
		var c: Color = (gauge[0] as ReservoirGauge).get(&"_water_mat").get_shader_parameter(&"color")
		check(c.r > 0.8 and c.b < 0.3, "la finestrella della lancia è gialla (%s)" % str(c))
	var getto: GettoPotente = null
	for n in p.find_children("*", "GettoPotente", true, false):
		getto = n
	if getto:
		var cg: Color = (p.water_pack.stream.material_override as ShaderMaterial).get_shader_parameter(&"colore")
		check(cg.r > 0.8 and cg.b < 0.3, "il getto è giallo (%s)" % str(cg))
		var ok_tinte := true
		for t in getto.get(&"_tinte"):
			var ct: Color = (t[0] as ShaderMaterial).get_shader_parameter(&"tint")
			ok_tinte = ok_tinte and ct.r > 0.8 and ct.b < 0.3
		check(ok_tinte and not (getto.get(&"_tinte") as Array).is_empty(), "e anche schizzi, gocce e nebbia")
	# Mezza zainata di blu sopra il giallo: il serbatoio si mescola per litri.
	p.water_pack.set_tank_amount(10.0)
	await _aspira(blu)
	var g := WaterMix.frazione(p.water_pack.water_mix, WaterMix.GIALLO)
	check(absf(g - 0.5) < 0.05, "mezzo giallo e mezzo blu nel serbatoio: metà e metà (%.2f)" % g)
	p.water_pack.set_tank_amount(0.0)
	check(p.water_pack.water_mix.is_empty(), "vuoto, il serbatoio non ha più colore")
	# Scelta B dell'utente: aspirando un colore lo zaino butta via l'acqua chiara che aveva.
	p.water_pack.set_tank_amount(10.0)
	check(p.water_pack.water_mix.is_empty(), "10 litri d'acqua chiara nello zaino")
	await _aspira(giallo)
	check(WaterMix.frazione(p.water_pack.water_mix, WaterMix.GIALLO) > 0.99 and p.water_pack.tank_amount > 19.5,
		"aspirando il giallo l'acqua chiara se ne va: dentro c'è solo giallo (%.2f, %.1f L)" % [WaterMix.frazione(p.water_pack.water_mix, WaterMix.GIALLO), p.water_pack.tank_amount])
	p.water_pack.set_tank_amount(10.0)
	await _aspira(blu)
	g = WaterMix.frazione(p.water_pack.water_mix, WaterMix.GIALLO)
	check(absf(g - 0.5) < 0.05 and WaterMix.intensita(p.water_pack.water_mix) > 0.99, "i colori che c'erano restano (giallo %.2f)" % g)
	p.water_pack.set_tank_amount(0.0)

	print("5. Miscuglio sbagliato: 1 giallo + 2 blu")
	var colori := []
	for t in [giallo, blu, blu]:
		await _aspira(t)
		await _versa()
		colori.append(WaterMix.tinta(misto.mix))
	await _frames(10)
	check(enigma.stato == EnigmaAcquari.Stato.TORBIDO, "pieno di colore sbagliato: torbido (giallo %.2f, pieno %.2f)" % [enigma.parte_di_giallo(), misto.fill])
	check(WaterMix.frazione(misto.mix, WaterMix.TORBIDA) > 0.99, "l'acqua è torbida")
	var c0 := colori[0] as Color
	# Colori tolleranti: i valori esatti li sceglie enigma-ambiente con l'utente.
	check(c0.r > 0.6 and c0.g > 0.5 and c0.b < 0.4 and not (colori[1] as Color).is_equal_approx(c0),
		"il colore cambia mentre si riempie (%s)" % str(colori))
	check(not portone.in_movimento and not portone.is_aperto(), "il portone resta chiuso")
	check(giallo.can_give_water() and blu.can_give_water(), "i colorati non sono vuoti")
	var cp_torbido := _salva("TestTorbido")

	print("   la valvola rossa: il gorgo svuota e i colorati tornano pieni")
	await _spruzza_valvola()
	check(enigma.stato == EnigmaAcquari.Stato.GORGO, "la valvola fa partire il gorgo")
	await _frames(int((enigma.durata_gorgo + 1.0) * 60.0))
	check(enigma.stato == EnigmaAcquari.Stato.APERTO and misto.fill < 0.001 and misto.mix.is_empty(), "l'acquario del miscuglio è vuoto")
	check(giallo.fill >= giallo.max_fill - 0.001 and blu.fill >= blu.max_fill - 0.001, "i colorati sono di nuovo pieni")

	print("6. Il giro dopo: 2 giallo + 1 blu, partendo con l'acqua chiara nello zaino")
	p.water_pack.set_tank_amount(0.0)
	p.water_pack.set_tank_amount(12.0)
	for t in [giallo, blu, giallo]:
		await _aspira(t)
		await _versa()
	await _frames(10)
	check(enigma.stato == EnigmaAcquari.Stato.RISOLTO, "verde: risolto (giallo %.2f)" % enigma.parte_di_giallo())
	check(WaterMix.frazione(misto.mix, WaterMix.VERDE) > 0.99, "l'acqua è verde")
	check(portone.in_movimento or portone.is_aperto(), "il portone si apre")
	await _frames(int((portone.partenza + portone.durata + 0.5) * 60.0))
	check(portone.is_aperto(), "il portone è aperto")
	check(portone.si_puo_aprire(), "e la fine della demo ora vale")
	var cp_risolto := _salva("TestRisolto")

	print("7. I colorati non si esauriscono; la tolleranza")
	var presi := 0.0
	for i in 40:
		presi += giallo.take_water(10.0)
	check(presi >= 399.0 and giallo.can_give_water() and giallo.fill >= giallo.min_fill - 0.001,
		"dal giallo escono %.0f litri e non finisce (pieno %.2f)" % [presi, giallo.fill])
	for prova in [[2.0, 1.0, true], [2.0, 0.85, true], [1.7, 1.0, true], [1.0, 1.0, false], [3.0, 1.0, false], [1.0, 2.0, false], [2.0, 1.0, false, 0.4]]:
		check(_valuta(prova) == bool(prova[2]), "giallo %.2f e blu %.2f%s: %s" % [prova[0], prova[1],
			(" con il %d%% d'acqua chiara" % int(prova[3] * 100.0)) if prova.size() > 3 else "",
			"verde" if prova[2] else "torbido"])

	print("8. Checkpoint")
	await _riparti(cp_prima)
	check(not enigma.comparsi and not _lampade_accese() and enigma.stato == EnigmaAcquari.Stato.APERTO,
		"prima della tappa 7: niente acquari, lampade spente")
	check(not portone.is_aperto() and not portone.in_movimento, "e il portone chiuso")
	await _riparti(cp_torbido)
	check(enigma.comparsi and enigma.attivi and enigma.stato == EnigmaAcquari.Stato.TORBIDO, "torbido: gli acquari ci sono, funzionano e sono torbidi")
	check(WaterMix.frazione(misto.mix, WaterMix.TORBIDA) > 0.99 and misto.fill > 0.9, "con l'acqua torbida dentro")
	check(not portone.is_aperto(), "e il portone chiuso")
	await _spruzza_valvola()
	await _frames(int((enigma.durata_gorgo + 1.0) * 60.0))
	check(enigma.stato == EnigmaAcquari.Stato.APERTO and misto.fill < 0.001, "anche dopo il checkpoint la valvola svuota")
	await _riparti(cp_risolto)
	check(enigma.comparsi and enigma.stato == EnigmaAcquari.Stato.RISOLTO and portone.is_aperto(), "risolto: il portone resta aperto")
	check(WaterMix.frazione(misto.mix, WaterMix.VERDE) > 0.99, "e l'acqua verde")
	_fine()


## Il giudizio su un miscuglio di [giallo, blu, atteso, chiara] (litri in proporzione).
func _valuta(prova: Array) -> bool:
	var chiara: float = prova[3] if prova.size() > 3 else 0.0
	var tot := float(prova[0]) + float(prova[1])
	var m := {WaterMix.GIALLO: float(prova[0]) / tot * (1.0 - chiara), WaterMix.BLU: float(prova[1]) / tot * (1.0 - chiara)}
	var stato := enigma.stato
	enigma.stato = EnigmaAcquari.Stato.APERTO
	misto.set_mix(m)
	var pf := portone.apertura
	var vecchio := enigma.portone
	enigma.portone = null
	enigma.call(&"_valuta")
	var ok := enigma.stato == EnigmaAcquari.Stato.RISOLTO
	enigma.portone = vecchio
	enigma.stato = stato
	portone.apertura = pf
	return ok


# --- Azioni ---------------------------------------------------------------------------------

## Davanti all'acquario dal lato ovest, guardando dentro, col tasto destro finché il serbatoio è
## pieno (o per 3 s).
func _aspira(t: WaterTank) -> void:
	_zaino()
	var c := t.global_position
	p.teleport(Vector3(c.x - 1.6, 0.0, c.z), PI * 0.5, 0.0)
	await _frames(3)
	p.look_at_point(c + Vector3(0.0, t.get_level() * 0.5, 0.0))
	Input.action_press(&"suck")
	for i in 180:
		await get_tree().physics_frame
		if p.water_pack.tank_amount >= p.water_pack.tank_capacity - 0.01:
			break
	Input.action_release(&"suck")
	await _frames(3)


## Davanti all'acquario del miscuglio, col getto dentro finché il serbatoio è vuoto.
func _versa() -> void:
	_zaino()
	var c := misto.global_position
	p.teleport(Vector3(c.x - 2.0, 0.0, c.z), PI * 0.5, 0.0)
	await _frames(3)
	var bersaglio := c + Vector3(0.3, 0.45, 0.0)
	var d := p.camera.global_position.distance_to(bersaglio)
	p.look_at_point(bersaglio + Vector3.UP * 0.0067 * d * d)
	Input.action_press(&"spray")
	for i in 600:
		await get_tree().physics_frame
		if p.water_pack.tank_amount <= 0.001:
			break
	await _frames(40)
	Input.action_release(&"spray")
	await _frames(10)


func _spruzza_valvola() -> void:
	_zaino()
	p.water_pack.set_tank_amount(20.0)
	var v := (enigma.get_node(^"Valvola") as Node3D).global_position
	p.teleport(Vector3(v.x - 2.5, 0.0, v.z), PI * 0.5, 0.0)
	await _frames(3)
	var d := p.camera.global_position.distance_to(v)
	p.look_at_point(v + Vector3.UP * 0.0067 * d * d)
	Input.action_press(&"spray")
	for i in 120:
		await get_tree().physics_frame
		if enigma.stato == EnigmaAcquari.Stato.GORGO:
			break
	Input.action_release(&"spray")
	await _frames(5)


func _zaino() -> void:
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)


func _salva(nome: String) -> Dictionary:
	GameState.capture_snapshot(nome, 900, p.global_transform)
	return GameState.snapshot.duplicate(true)


func _riparti(s: Dictionary) -> void:
	GameState.snapshot = s.duplicate(true)
	GameState.respawn()
	await _aspetta_livello()
	await _frames(10)


# --- Aiuti ----------------------------------------------------------------------------------

func _serranda() -> Node:
	return level.get_node(^"Tecnici/Logica/SerrandaMagazzino")


## Con i figli Spente e Accese conta solo Accese (le spente si vedono sempre).
func _lampade_accese() -> bool:
	var lampade := enigma.get_node(^"LampadePortone") as Node3D
	var accese := lampade.get_node_or_null(^"Accese") as Node3D
	if accese:
		var spente := lampade.get_node_or_null(^"Spente") as Node3D
		if spente and not spente.is_visible_in_tree():
			printerr("  le lampade spente non si vedono")
			return false
		lampade = accese
	if not lampade.is_visible_in_tree():
		return false
	for l in lampade.find_children("*", "Light3D", true, false):
		if (l as Light3D).is_visible_in_tree():
			return true
	return false


func _collisioni_spente() -> bool:
	for n in enigma.find_children("*", "CollisionObject3D", true, false):
		if (n as Node).can_process():
			return false
	for t in [giallo, blu, misto]:
		if (t as Node).can_process():
			return false
	return true


func _aspetta_livello() -> void:
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _frames(5)
	level = get_tree().current_scene
	p = GameState.player
	enigma = level.get_node_or_null(^"Gioco/EnigmaAcquari") as EnigmaAcquari
	portone = level.get(&"portone") as PortoneTorre
	if enigma:
		giallo = enigma.get_node(^"AcquarioGiallo") as WaterTank
		blu = enigma.get_node(^"AcquarioBlu") as WaterTank
		misto = enigma.get_node(^"AcquarioMisto") as WaterTank
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
