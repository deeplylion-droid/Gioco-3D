extends Node
## Test del portone della torre degli scivoli, giocato come chi gioca: il mondo fatto fino al portone aperto (come la
## partenza "torre" di genera_partenze_prova), il giocatore nella sala davanti al portone, che entra camminando.
## - "torna": appena entrato torna indietro di corsa. Deve restare nella torre (la soglia si chiude subito); interni e
##   tecnici restano finché il portone non è chiuso del tutto, poi vanno via (sonda del 29 ottobre: prima si usciva in
##   0,8 s col portone aperto al 73% e si restava chiusi fuori, con gli ambienti già scaricati).
## - "soglia": entrato, torna piano e resta appoggiato alla soglia mentre l'anta scorre: non resta incastrato, poi
##   cammina via nella torre.
## - una morte dopo il checkpoint del portone (l'istantanea l'ha presa col portone ancora aperto): si riparte nella torre
##   col portone chiuso, senza interni e tecnici, e non si torna nella sala; si cammina avanti.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_portone_torre.gd

const GEN := preload("res://tests/genera_partenze_prova.gd")
const SCENA := "res://scenes/sala_principale.tscn"
## La soglia del portone (x) e un margine: il giocatore (capsula) non ci arriva col centro.
const SOGLIA := 19.84
const OVEST := PI / 2.0
const EST := -PI / 2.0

var level: Node
var p: Player
var portone: Node
var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	print("== torna indietro di corsa")
	await _prepara()
	await _torna()
	print("== appoggiato alla soglia, poi una morte")
	await _prepara()
	await _soglia()
	await _ripartenza()
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _prepara() -> void:
	GameState.reset_progress()
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file(SCENA)
	await _aspetta_livello(p)
	var stati := {}
	var raccolti: Array = []
	for k in 5:
		var parte: String = GEN.PARTI[k]
		stati.merge(GEN.FATTI.get(parte, {}), true)
		raccolti.append_array(GEN.RACCOLTI.get(parte, []))
		for e in GEN.POLAROID.get(parte, []):
			GameState.collect(&"polaroid", StringName(e))
	for n in get_tree().get_nodes_in_group(&"persist"):
		var key := GameState.persist_key(n)
		if key in raccolti:
			GameState.mark_removed(n)
			n.queue_free()
			continue
		if stati.has(key) and n.has_method(&"load_state"):
			var d: Dictionary = n.call(&"save_state") if n.has_method(&"save_state") else {}
			d.merge(stati[key], true)
			n.call(&"load_state", d)
	p.inventory[&"zaino_pompa"] = 1
	if p.water_pack:
		p.water_pack.set_equipped(true, false)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for i in 10:
		await get_tree().physics_frame
	# la torre caricata e il portone aperto davvero (lo stato "aperto" non lo fa scorrere)
	level.call(&"_carica_torre")
	for i in 60 * 120:
		await get_tree().process_frame
		var t = level.get(&"sala_torre")
		if t is Node and bool((t as Node).get(&"costruita")):
			break
	portone = level.get(&"portone")
	if not bool(portone.call(&"is_aperto")):
		portone.call(&"apri")
		for i in 60 * 15:
			await get_tree().physics_frame
			if bool(portone.call(&"is_aperto")):
				break
	_check(bool(portone.call(&"is_aperto")), "la torre è costruita e il portone è aperto")
	# nella sala davanti al portone, rivolti a est (verso la torre)
	p.teleport(Vector3(16.5, 0.05, -15.0), EST, 0.0)
	for i in 30:
		await get_tree().physics_frame


## Cammina avanti guardando verso [param yaw] per [param secondi] (di corsa con [param corsa]); si ferma prima se
## [param fino] diventa vero.
func _cammina(yaw: float, secondi: float, corsa := false, fino := Callable()) -> void:
	Input.action_press(&"move_forward")
	if corsa:
		Input.action_press(&"sprint")
	for i in int(secondi * 60.0):
		p.set_look(yaw, 0.0)
		await get_tree().physics_frame
		if fino.is_valid() and fino.call():
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	for i in 6:
		await get_tree().physics_frame


func _dentro() -> bool:
	return bool(level.get(&"_dentro_torre"))


func _ambienti() -> bool:
	return level.get_node_or_null(^"Interni") != null or level.get(&"tecnici") != null


func _torna() -> void:
	await _cammina(EST, 4.0, true, _dentro)
	_check(_dentro(), "entrato nella torre (x %.2f)" % p.global_position.x)
	# subito indietro di corsa, girandosi in un quarto di secondo
	var minimo := p.global_position.x
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in 60 * 4:
		p.set_look(lerp_angle(EST, OVEST, minf(float(i + 1) / 15.0, 1.0)), 0.0)
		await get_tree().physics_frame
		minimo = minf(minimo, p.global_position.x)
		if i == 60:
			_check(_ambienti(), "interni e tecnici ci sono ancora mentre il portone si chiude (quanto %.2f)" % float(portone.get(&"quanto")))
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	_check(minimo > SOGLIA, "tornando indietro di corsa non si passa la soglia (x minima %.2f, soglia %.2f)" % [minimo, SOGLIA])
	for i in 60 * 12:
		await get_tree().physics_frame
		if float(portone.get(&"quanto")) <= 0.0 and not _ambienti():
			break
	_check(float(portone.get(&"quanto")) <= 0.0, "il portone è chiuso")
	_check(not _ambienti(), "interni e tecnici scaricati col portone chiuso")
	_check(p.global_position.x > SOGLIA, "il giocatore è nella torre (x %.2f)" % p.global_position.x)


func _soglia() -> void:
	await _cammina(EST, 4.0, false, _dentro)
	_check(_dentro(), "entrato nella torre camminando (x %.2f)" % p.global_position.x)
	# indietro piano, contro la soglia, per tutta la chiusura
	await _cammina(OVEST, 4.0)
	_check(float(portone.get(&"quanto")) <= 0.0, "il portone si è chiuso col giocatore appoggiato alla soglia")
	var x0 := p.global_position.x
	_check(x0 > SOGLIA and x0 < SOGLIA + 1.0, "il giocatore è fermo alla soglia, dalla parte della torre (x %.2f)" % x0)
	_check(absf(p.global_position.y) < 0.3, "non è stato spinto in alto o in basso (y %.2f)" % p.global_position.y)
	# (poco: il pianerottolo finisce verso x 23, poi si cade nella torre)
	await _cammina(EST, 0.4)
	_check(p.global_position.x > x0 + 0.8, "si stacca dalla soglia e cammina nella torre (x da %.2f a %.2f)" % [x0, p.global_position.x])


func _ripartenza() -> void:
	var cp := String(GameState.snapshot.get("checkpoint", ""))
	_check(cp == "SalaTorre/Checkpoint_portone", "l'ultimo checkpoint è quello del portone (%s)" % cp)
	var stato: Dictionary = (GameState.snapshot.get("objects", {}) as Dictionary).get("Gioco/PortoneTorre", {})
	_check(bool(stato.get("aperto", false)), "nell'istantanea del checkpoint il portone era ancora aperto (%s)" % stato)
	var vecchio := p
	GameState.respawn()
	await _aspetta_livello(vecchio)
	for i in 60 * 10:
		await get_tree().physics_frame
		if not _ambienti():
			break
	portone = level.get(&"portone")
	_check(float(portone.get(&"quanto")) <= 0.0 and bool(portone.get(&"chiuso_dietro")),
		"ripartiti: il portone è chiuso (quanto %.2f, chiuso_dietro %s)" % [float(portone.get(&"quanto")), portone.get(&"chiuso_dietro")])
	_check(not _ambienti(), "ripartiti: niente interni e tecnici")
	_check(p.global_position.x > SOGLIA + 0.5, "ripartiti nella torre (%s)" % p.global_position)
	await _cammina(OVEST, 3.0, true)
	_check(p.global_position.x > SOGLIA, "ripartiti: verso il portone non si passa (x %.2f)" % p.global_position.x)
	var x0 := p.global_position.x
	await _cammina(EST, 0.4)
	_check(p.global_position.x > x0 + 0.8, "ripartiti: si cammina nella torre (x da %.2f a %.2f)" % [x0, p.global_position.x])


## Aspetta il livello col giocatore nuovo (diverso da [param vecchio]), pronto e già ripreso.
func _aspetta_livello(vecchio: Node) -> void:
	for i in 60 * 120:
		await get_tree().process_frame
		var n = GameState.player
		if n != null and is_instance_valid(n) and n != vecchio and n.is_inside_tree() and not GameState.is_restoring():
			break
	level = get_tree().current_scene
	p = GameState.player
	for i in 30:
		await get_tree().physics_frame
