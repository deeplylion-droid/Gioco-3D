extends Node
## Test automatico del movimento sugli scivoli (sala della torre, versione A), nella scena di prova
## scenes/test/scivoli_prova.tscn, simulando gli input:
## 1. La scena: tre pezzi di scivolo nel gruppo "scivolo", i checkpoint, il vuoto sotto.
## 2. Si scende senza toccare niente: dalla piattaforma si entra nel giallo e si scivola, sempre più
##    veloci; la camera si inclina in curva, si sente lo scivolare, ai piedi schizzi. A fine pezzo il
##    salto viene da sé e si atterra sul rosso (tonfo, corona di schizzi).
## 3. Senza il getto il salto dal rosso al blu non basta: si cade nel vuoto e si riparte dal
##    checkpoint in alto.
## 4. Con il getto tenuto verso il basso in aria il salto si allunga (e beve molta acqua): si arriva
##    sul blu e giù fino alla piattaforma del fondo (checkpoint).
## 5. Il controllo: di lato si sterza; tirando indietro si rallenta, ma non ci si ferma.
## 6. La spinta del getto vale solo in aria: in piedi e mentre si scivola non solleva.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_scivoli.gd

const LEVEL := "res://scenes/test/scivoli_prova.tscn"
const PARTENZA := Vector3(0.0, 20.0, 3.5)

var level: Node
var p: Player
var _passed := 0
var _failed := 0
var _atterraggi: Array = []


func _ready() -> void:
	_run.call_deferred()


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


func _aspetta_livello() -> void:
	# (a tempo: la ripartenza aspetta i caricamenti nel thread, anche qualche secondo)
	var t_attesa := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_attesa < 90000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _frames(5)
	level = get_tree().current_scene
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	_atterraggi.clear()
	p.landed.connect(func(s: StringName, _w: bool, v: float): _atterraggi.append([s, v]))


func _fine() -> void:
	_lascia()
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)  # aspetta i caricamenti nel thread


func _lascia() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"spray"]:
		Input.action_release(a)


## Una discesa dalla piattaforma in alto. [param comandi]: azione tenuta mentre si scivola sul
## giallo; [param getto]: al secondo salto si punta in basso e si spruzza fino all'atterraggio.
## Torna quello che è successo.
func _scendi(comandi: StringName = &"", getto := false, secondi := 14.0) -> Dictionary:
	p.teleport(PARTENZA, 0.0, 0.0)
	p.water_pack.set_tank_amount(20.0)
	_atterraggi.clear()
	await _frames(3)
	var r := {"lanci": [], "pezzi": [], "roll": 0.0, "min_v": INF, "v_giallo": 0.0, "suono": 0.0,
			"schizzi": false, "morto": false, "fondo": false, "acqua": 0.0, "boost_scivolando": false,
			"x_giallo": [], "uscita_giallo": Vector3.ZERO}
	Input.action_press(&"move_forward")
	for i in 240:
		await get_tree().physics_frame
		if p.is_sliding:
			break
	Input.action_release(&"move_forward")
	r.partito = p.is_sliding
	var t := 0.0
	var era := p.is_sliding
	var spruzzo := false
	var acqua_prima := 0.0
	if comandi != &"":
		Input.action_press(comandi)
	while t < secondi:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if GameState.is_dying:
			r.morto = true
			break
		if p.is_sliding:
			var pezzo := _pezzo_sotto()
			if pezzo != "" and (r.pezzi.is_empty() or r.pezzi[-1] != pezzo):
				r.pezzi.append(pezzo)
			if t > 0.5:
				r.min_v = minf(r.min_v, p.velocity.length())
			r.roll = maxf(r.roll, absf(rad_to_deg(p._roll)))
			r.suono = maxf(r.suono, _volume_scivolo())
			var fx := p.get_node_or_null(^"SlideFx") as SlideFx
			r.schizzi = r.schizzi or (fx != null and fx._lati[0].emitting)
			if pezzo == "ScivoloGiallo":
				r.x_giallo.append(p.global_position.x)
			if spruzzo and p.water_pack.boosting:
				r.boost_scivolando = true
		if p.is_sliding != era:
			era = p.is_sliding
			if not era:
				r.lanci.append({"pos": p.global_position, "v": p.velocity, "da": r.pezzi[-1] if not r.pezzi.is_empty() else ""})
				if r.lanci.size() == 1:
					r.uscita_giallo = p.velocity
					if comandi != &"":
						Input.action_release(comandi)
				if getto and r.lanci.size() == 2:
					p.set_look(p.yaw, deg_to_rad(-80.0))
					acqua_prima = p.water_pack.tank_amount
					Input.action_press(&"spray")
					spruzzo = true
			elif spruzzo:
				Input.action_release(&"spray")
				spruzzo = false
				r.acqua = acqua_prima - p.water_pack.tank_amount
				p.set_look(p.yaw, 0.0)
		if p.is_on_floor() and not p.is_sliding and t > 2.0:
			r.fondo = p.global_position.distance_to(level.FONDO) < 4.0
			break
	_lascia()
	r.atterraggi = _atterraggi.duplicate()
	return r


static func _media(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += x
	return s / maxf(a.size(), 1.0)


func _pezzo_sotto() -> String:
	var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 0.5, p.global_position + Vector3.DOWN * 1.0)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	return String((hit.collider as Node).name) if not hit.is_empty() and hit.collider is Node else ""


func _volume_scivolo() -> float:
	var stream := Audio.stream_di(&"scivolo_loop")
	for c in p.get_children():
		if c is AudioLoop and (c as AudioLoop).player and (c as AudioLoop).player.stream == stream:
			return (c as AudioLoop).volume
	return -1.0


func _salta_morte() -> void:
	await _frames(30)
	for s in GameState.get_children():
		if s is DeathSequence:
			(s as DeathSequence).skip()
	await _aspetta_livello()


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	await _aspetta_livello()

	print("1. La scena di prova")
	var scivoli := get_tree().get_nodes_in_group(Player.SLIDE_GROUP)
	check(scivoli.size() == 3 and scivoli.all(func(n): return n is StaticBody3D), "tre pezzi di scivolo, corpi statici nel gruppo \"scivolo\"")
	check(level.get_node_or_null(^"CheckpointAlto") is Checkpoint and level.get_node_or_null(^"CheckpointFondo") is Checkpoint, "checkpoint in alto e sul fondo")
	check(level.get_node_or_null(^"Vuoto") is KillZone, "sotto c'è il vuoto")
	check(p.is_on_floor() and not p.is_sliding, "sulla piattaforma si sta in piedi")

	print("2. Si scende senza toccare niente; il primo salto viene da sé")
	var r := await _scendi()
	check(r.partito, "camminando nel giallo si comincia a scivolare")
	check(r.pezzi.slice(0, 2) == ["ScivoloGiallo", "ScivoloRosso"], "giallo, salto, rosso (%s)" % str(r.pezzi))
	var u: Vector3 = r.uscita_giallo
	check(Vector2(u.x, u.z).length() > 8.0, "a fine giallo si vola via veloci (%.1f m/s)" % Vector2(u.x, u.z).length())
	check(r.min_v > 3.0, "scivolando non ci si ferma mai (minimo %.1f m/s)" % r.min_v)
	check(r.roll > 2.0 and r.roll < p.slide_tilt_max + 0.1, "in curva la camera si inclina (fino a %.1f gradi)" % r.roll)
	check(r.suono > 0.5, "si sente lo scivolare sull'acqua (volume %.2f)" % r.suono)
	check(r.schizzi, "ai piedi gli schizzi")
	var sul_rosso: Array = r.atterraggi.filter(func(a): return a[0] == Player.SURFACE_SLIDE)
	check(not sul_rosso.is_empty(), "atterraggio sullo scivolo (%.1f m/s)" % (sul_rosso[0][1] if not sul_rosso.is_empty() else 0.0))
	check(int(Audio.conteggio.get(&"atterraggio_scivolo", 0)) > 0, "con il tonfo sulla plastica e lo schiaffo dell'acqua")

	print("3. Senza getto il salto lungo non basta")
	check(r.lanci.size() >= 2 and r.lanci[1].da == "ScivoloRosso", "a fine rosso si vola sul vuoto")
	check(r.morto and not r.pezzi.has("ScivoloBlu"), "si cade nel vuoto senza arrivare al blu")
	check(GameState.last_death_cause == &"caduta", "morte per caduta")
	await _salta_morte()
	check(p.global_position.distance_to(PARTENZA) < 1.5 and p.is_on_floor(), "si riparte dalla piattaforma in alto (%s)" % str(p.global_position))

	print("4. Col getto verso il basso in aria il salto si allunga")
	r = await _scendi(&"", true, 16.0)
	check(r.pezzi.has("ScivoloBlu"), "si arriva sul blu (%s)" % str(r.pezzi))
	check(not r.morto and r.fondo, "e giù fino alla piattaforma del fondo")
	check(r.acqua > 6.0, "la spinta beve molta acqua (%.1f litri)" % r.acqua)
	check(String(GameState.snapshot.get("checkpoint", "")).ends_with("CheckpointFondo"), "checkpoint del fondo (%s)" % GameState.snapshot.get("checkpoint", ""))

	print("5. Di lato si sterza, indietro si rallenta ma non ci si ferma")
	var dritto := await _scendi(&"", false, 3.5)
	var destra := await _scendi(&"move_right", false, 3.5)
	var dx := _media(destra.x_giallo) - _media(dritto.x_giallo)
	check(dx > 0.3, "tenendo a destra si sta più a destra nel giallo (in media %.2f m)" % dx)
	var piano := await _scendi(&"move_back", false, 6.0)
	var v0 := Vector2(dritto.uscita_giallo.x, dritto.uscita_giallo.z).length()
	var v1 := Vector2(piano.uscita_giallo.x, piano.uscita_giallo.z).length()
	check(v1 < v0 - 1.0, "tirando indietro si esce più piano (%.1f contro %.1f m/s)" % [v1, v0])
	check(piano.min_v >= p.slide_min_speed - 0.2, "ma non sotto %.0f m/s (minimo %.1f)" % [p.slide_min_speed, piano.min_v])

	print("6. La spinta vale solo in aria")
	p.teleport(PARTENZA, 0.0, deg_to_rad(-80.0))
	p.water_pack.set_tank_amount(20.0)
	await _frames(5)
	Input.action_press(&"spray")
	var su := 0.0
	for i in 60:
		await get_tree().physics_frame
		su = maxf(su, p.velocity.y)
	Input.action_release(&"spray")
	check(su < 0.05 and p.is_on_floor(), "in piedi, spruzzando in basso non ci si solleva (%.2f m/s)" % su)
	p.teleport(PARTENZA, 0.0, 0.0)
	await _frames(3)
	Input.action_press(&"move_forward")
	for i in 240:
		await get_tree().physics_frame
		if p.is_sliding:
			break
	Input.action_release(&"move_forward")
	p.set_look(p.yaw, deg_to_rad(-80.0))
	Input.action_press(&"spray")
	var spinta := false
	for i in 60:
		await get_tree().physics_frame
		spinta = spinta or (p.is_sliding and p.water_pack.boosting)
	Input.action_release(&"spray")
	check(p.is_sliding and not spinta, "scivolando, spruzzando in basso non c'è spinta")
	_fine()
