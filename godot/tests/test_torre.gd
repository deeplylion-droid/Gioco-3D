extends Node
## Test automatico della sala della torre (scenes/sala/torre/sala_torre.tscn, versione A scelta dall'utente il
## 18 ottobre): la struttura di torri e scivoli che si SCENDE, dal portone alla vasca del fondo.
## 1. Da sola: i canali della discesa sono solidi e nel gruppo "scivolo" (l'accordo con grafica per il
##    movimento dello scivolare), lungo tutta la discesa c'è il canale sotto e 2 m liberi sopra, i
##    checkpoint sono sulle pedane d'arrivo, la Polaroid 10 è sul lettino, il fondo fuori dalla vasca uccide.
## 2. La discesa col movimento vero sugli scivoli (Player di grafica): ogni tratto si scende dalla sua pedana
##    alla pedana dopo; nei due tratti che finiscono col getto, senza getto si cade.
## 3. Nella sala grande: il portone (aperto qui senza la tappa 8) fa caricare la torre in un thread, il guscio
##    vecchio sparisce, sulla passerella si entra (il portone si richiude, interni e tecnici si scaricano);
##    cadendo dalla discesa si muore e si riparte dall'ultimo checkpoint, con la torre di nuovo lì; le pedane
##    d'arrivo sono checkpoint in ordine; nella vasca del fondo la demo finisce.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_torre.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("1. La sala da sola")
	var torre: SalaTorre = (load(TORRE) as PackedScene).instantiate()
	torre.crea_luci = false
	get_tree().root.add_child(torre)
	await _frames(3)
	var dati: Dictionary = torre.dati
	var n_pezzi := 0
	for t in dati["tratti"]:
		n_pezzi += (t["pezzi"] as Array).size()
	var scivoli := torre.corpi_scivolo()
	check(n_pezzi >= 8 and scivoli.size() == n_pezzi, "%d pezzi di discesa, %d corpi nel gruppo \"scivolo\"" % [n_pezzi, scivoli.size()])
	check(torre.checkpoint.size() == 7, "7 checkpoint: il portone, le 5 pedane d'arrivo, il fondo (%d)" % torre.checkpoint.size())
	var ordini_ok := true
	for i in range(1, torre.checkpoint.size()):
		ordini_ok = ordini_ok and torre.checkpoint[i].order > torre.checkpoint[i - 1].order \
			and torre.checkpoint[i].global_position.y < torre.checkpoint[i - 1].global_position.y + 0.1
	check(ordini_ok, "i checkpoint vanno in ordine e sempre più in basso")
	check(torre.get_node_or_null("Polaroid10") != null, "c'è la Polaroid 10")
	check(torre.find_children("CadutaFondo*", "KillZone", false, false).size() == 4, "il fondo fuori dalla vasca è una zona di caduta")
	var solidi := torre.find_children("*", "StaticBody3D", true, false).size()
	check(solidi > n_pezzi + 20, "la struttura, i tubi e i prop sono solidi (%d corpi statici)" % solidi)
	var spazio := torre.get_world_3d().direct_space_state

	# i checkpoint stanno sopra qualcosa di solido
	var appoggiati := 0
	for cp in torre.checkpoint:
		var hit := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(cp.global_position + Vector3(0, 1.0, 0), cp.global_position - Vector3(0, 1.5, 0), Layers.WORLD))
		if not hit.is_empty():
			appoggiati += 1
		else:
			print("    sotto il checkpoint %s non c'è niente" % cp.name)
	check(appoggiati == torre.checkpoint.size(), "ogni checkpoint ha il pavimento sotto (%d/%d)" % [appoggiati, torre.checkpoint.size()])

	# lungo la discesa: il canale sotto, e lo spazio sopra per chi scivola
	var punti: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ambiente/torre/torre_percorso.json"))
	var sotto_ok := 0
	var sopra_ok := 0
	var n := 0
	for q in punti:
		if q["cosa"] != "scivolo":
			continue
		n += 1
		var pos := SalaTorre.b([q["x"], q["y"], q["z"]])
		var hit := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.6, 0), pos - Vector3(0, 1.2, 0), Layers.WORLD))
		if hit.is_empty() or not (hit.collider as Node).is_in_group(&"scivolo"):
			print("    sotto %s: %s" % [pos, "niente" if hit.is_empty() else String((hit.collider as Node).get_parent().name)])
		if not hit.is_empty() and (hit.collider as Node).is_in_group(&"scivolo"):
			sotto_ok += 1
			var fondo := (hit.position as Vector3) + Vector3(0, 0.15, 0)
			var su := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(fondo, fondo + Vector3(0, 2.0, 0), Layers.WORLD))
			if su.is_empty():
				sopra_ok += 1
			elif sopra_ok + 3 > n:
				print("    poco spazio sopra il canale a ", pos, " (", (su.collider as Node).name, ")")
	check(sotto_ok == n, "sotto ogni punto della discesa c'è un canale del gruppo \"scivolo\" (%d/%d)" % [sotto_ok, n])
	check(sopra_ok >= n - 2, "sopra il canale ci sono 2 m liberi (%d/%d punti)" % [sopra_ok, n])

	print("2. La discesa col movimento vero sugli scivoli (Player, di grafica)")
	var salti: Array = dati["salti"]
	var n_getto := salti.filter(func(x): return x["tipo"] == "getto").size()
	check(n_getto == 2 and salti.size() - n_getto >= 4, "%d salti normali e %d col getto" % [salti.size() - n_getto, n_getto])
	var l_prec := 0.0
	var crescono := true
	for x in salti:
		if x["tipo"] == "salto":
			crescono = crescono and float(x["larghezza"]) >= l_prec
			l_prec = float(x["larghezza"])
	check(crescono and float(salti[0]["larghezza"]) <= 1.0, "i salti normali sono sempre più lunghi e il primo è corto")
	for z in torre.find_children("CadutaFondo*", "KillZone", false, false):
		z.queue_free()
	torre.margine_caduta = 1000.0
	var pl: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(pl)
	await _frames(5)
	pl.water_pack.set_equipped(true, false)
	for k in range(torre.checkpoint.size() - 1):
		var tr: Dictionary = dati["tratti"][k]
		var col_getto: bool = (tr["salti"] as Array).has("getto")
		var esito := await _scendi(torre, pl, k, true)
		check(esito == "arrivato", "tratto %d (%s -> %s, salti %s): %s" % [k, torre.checkpoint[k].name, torre.checkpoint[k + 1].name, tr["salti"], esito])
		if col_getto:
			var senza := await _scendi(torre, pl, k, false)
			check(senza.begins_with("caduto"), "   senza il getto non si arriva (%s)" % senza)
	pl.queue_free()
	torre.queue_free()
	await _frames(2)

	print("3. Nella sala grande")
	get_tree().change_scene_to_file(LEVEL)
	await _aspetta_livello()
	var level := get_tree().current_scene
	var p := GameState.player
	var portone := level.get(&"portone") as PortoneTorre
	check(level.get(&"sala_torre") == null, "prima che il portone si apra la torre non è caricata")
	portone.apri()
	var t0 := Time.get_ticks_msec()
	for i in 3000:
		await get_tree().process_frame
		if level.get(&"sala_torre") != null:
			break
	var sala: SalaTorre = level.get(&"sala_torre")
	check(sala != null, "il portone fa caricare la torre in un thread (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if sala == null:
		_fine()
		return
	await _frames(5)
	check(level.find_child("sala_torre_guscio", true, false) == null, "il guscio vecchio dietro il portone non c'è più")
	for i in 900:
		if portone.is_aperto():
			break
		await _frames(1)
	_metti(p, Vector3(21.3, 0.1, -15.0), Vector3(30.0, 0.1, -15.0))
	await _frames(60)
	check(portone.chiuso_dietro, "entrando sulla passerella il portone si richiude alle spalle")
	check(level.get_node_or_null(^"Tecnici") == null and level.get_node_or_null(^"Interni") == null,
		"interni e tecnici si scaricano")
	check(String(GameState.snapshot.get("checkpoint", "")).contains("SalaTorre/Checkpoint_portone"),
		"checkpoint all'ingresso (%s)" % GameState.snapshot.get("checkpoint", ""))

	# le pedane d'arrivo, in ordine (qui ci si arriva teletrasportati)
	for i in range(1, sala.checkpoint.size() - 1):
		var cp := sala.checkpoint[i]
		_metti(p, cp.global_position + Vector3(0, 0.1, 0), cp.global_position - cp.global_basis.z)
		await _frames(20)
		check(String(GameState.snapshot.get("checkpoint", "")).ends_with(cp.name) and not GameState.is_dying,
			"pedana %s: checkpoint" % cp.name)

	print("   Una caduta")
	var ultimo := sala.checkpoint[sala.checkpoint.size() - 2]
	_metti(p, Vector3(31.0, ultimo.global_position.y - 1.0, -15.0), Vector3(31.0, 0, -10.0))   # nel vuoto sopra il pozzo
	for i in 400:
		await _frames(1)
		if GameState.is_dying:
			break
	check(GameState.is_dying, "cadendo dalla discesa si muore")
	await _salta_morte()
	await _aspetta_livello()
	level = get_tree().current_scene
	p = GameState.player
	sala = level.get(&"sala_torre")
	check(sala != null and is_instance_valid(sala), "si riparte con la torre già lì")
	if sala:
		check(p.global_position.distance_to(ultimo.global_position) < 2.0, "dall'ultimo checkpoint (%s)" % ultimo.name)
		check((level.get(&"portone") as PortoneTorre).chiuso_dietro, "col portone chiuso alle spalle")
		print("   La vasca del fondo")
		var fondo := sala.get_node("VascaFondo") as Area3D
		_metti(p, fondo.global_position + Vector3(0, 0.6, 0), fondo.global_position + Vector3(0, 0.6, 1))
		await _frames(30)
		check(bool(level.get(&"demo_finished")), "nella vasca del fondo la discesa finisce (per ora la demo)")
	_fine()


## Scende il tratto k col movimento vero: dall'ingresso del tratto (un metro dietro l'inizio) si cammina
## avanti finché si scivola, poi si lascia fare; nei tratti che finiscono col getto, con [param getto], negli
## ultimi metri si tiene premuto lo spruzzo verso il basso (la carica si fa scivolando, in aria la spinta parte
## subito). "arrivato" se ci si ferma sulla pedana del checkpoint dopo, "caduto ..." se si va giù.
func _scendi(torre: SalaTorre, p: Player, k: int, getto: bool) -> String:
	var tr: Dictionary = torre.dati["tratti"][k]
	var dopo := torre.checkpoint[k + 1]
	var avanti := SalaTorre.b(tr["verso"])
	var decollo := SalaTorre.b(tr["a"])
	var fine_getto: bool = (tr["salti"] as Array).size() > 0 and tr["salti"][-1] == "getto"
	p.global_position = SalaTorre.b(tr["entrata"]) + Vector3(0, 0.2, 0)
	p.velocity = Vector3.ZERO
	p.set_look(atan2(-avanti.x, -avanti.z), 0.0)
	p.water_pack.set_tank_amount(20.0)
	await _frames(10)
	Input.action_press(&"move_forward")
	var premuto := false
	var esito := "tempo scaduto"
	for i in 60 * 20:
		await _frames(1)
		if p.is_sliding and Input.is_action_pressed(&"move_forward"):
			Input.action_release(&"move_forward")
		if getto and fine_getto and not premuto and p.is_sliding \
				and Vector2(p.global_position.x - decollo.x, p.global_position.z - decollo.z).length() < 3.0:
			premuto = true
			p.set_look(p.yaw, deg_to_rad(-80.0))
			Input.action_press(&"spray")
		var pos := p.global_position
		if pos.y < dopo.global_position.y - 3.0:
			esito = "caduto a %.1f m" % pos.y
			break
		if pos.distance_to(dopo.global_position) < 2.2 and not p.is_sliding and p.is_on_floor():
			esito = "arrivato"
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"spray")
	p.set_look(p.yaw, 0.0)
	return esito


func _metti(p: Player, pos: Vector3, guarda: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	var g := Vector3(guarda.x, pos.y, guarda.z)
	if g.distance_to(pos) > 0.01:
		p.look_at(g, Vector3.UP)


func _aspetta_livello() -> void:
	var vecchio := GameState.player
	for i in 900:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player != vecchio and not GameState.is_dying:
			break
	await _frames(5)
	var p := GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame


func _salta_morte() -> void:
	await _frames(10)
	var seq := GameState.get_children().filter(func(n): return n is DeathSequence)
	if seq.size() > 0:
		(seq[0] as DeathSequence).skip()


func _fine() -> void:
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


func _frames(k: int) -> void:
	for i in k:
		await get_tree().physics_frame
