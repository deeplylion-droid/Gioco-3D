extends Node
## Collaudo 0.3.24 (tunnel a passi corti, 7bf1ed69): i tempi di ogni fotogramma nel gioco vero, senza schermo, dalle
## strade vere fino al tunnel. Fasi (TT:), ognuna dall'inizio alla fine col fotogramma più lungo, quelli sopra 33 ms
## (col momento) e la memoria (VmRSS, e il picco VmHWM del processo):
##   strada "inseguimento": F9 Inseguimento -> arrivo -> la prima costruzione del tunnel (fino a costruita e pronta, +3 s)
##     -> l'ingresso nel tunnel (sb1_finito come alla fine di SB1: _attiva_sottomarino, attiva_tunnel; +3 s)
##     -> morte nelle condotte (prima dell'ingresso: si rifà la strada) -> la seconda costruzione (+3 s);
##   strada "torre": F9 Torre -> arrivo -> il tunnel si carica e si costruisce mentre si è nella torre (+3 s);
##   strada "portone": la sala, gli acquari e il portone -> la torre -> il tunnel (+3 s);
##   strada "tunnel": F9 Tunnel (checkpoint del tunnel) -> morte nel tunnel -> ripartenza (+5 s).
## Con TORRE_TEMPI=1 il gioco stampa anche i passi della costruzione sopra 20 ms.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/tunnel_tempi.gd <strada>[,<strada>...]

const LEVEL := "res://scenes/sala_principale.tscn"
const LIMITE := 33.0

var _on := false
var _ult := 0
var _t0 := 0
var _n := 0
var _max := 0.0
var _lunghi: Array = []
var _hwm0 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _process(_d: float) -> void:
	var t := Time.get_ticks_usec()
	if _on and _ult > 0:
		var ms := (t - _ult) / 1000.0
		_n += 1
		_max = maxf(_max, ms)
		if ms > LIMITE:
			_lunghi.append("%.1f ms a %.2f s" % [ms, (t - _t0) / 1e6])
	_ult = t


static func _mem() -> Dictionary:
	var out := {}
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	while f and not f.eof_reached():
		var riga := f.get_line()
		if true:
			for k in ["VmRSS", "VmHWM"]:
				if riga.begins_with(k + ":"):
					out[k] = int(riga.split(":")[1].strip_edges().split(" ")[0]) / 1024
	return out


func _via() -> void:
	_n = 0
	_max = 0.0
	_lunghi = []
	_ult = 0
	_t0 = Time.get_ticks_usec()
	_on = true


func _stop(nome: String) -> void:
	_on = false
	var m := _mem()
	print("TT: %s: %.1f s, fotogrammi %d, il più lungo %.1f ms, sopra %d ms %d %s; RSS %d MB, picco %d MB" % [nome,
			(Time.get_ticks_usec() - _t0) / 1e6, _n, _max, LIMITE, _lunghi.size(), _lunghi, m.get("VmRSS", 0), m.get("VmHWM", 0)])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secondi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().process_frame


func _tunnel() -> Node:
	var s := get_tree().current_scene
	var t: Node = s.get(&"sala_sottomarino") if s and &"sala_sottomarino" in s else null
	return t if is_instance_valid(t) else null


func _arrivati(entro_s: float, vecchio_id: int) -> bool:
	var fino := Time.get_ticks_msec() + entro_s * 1000.0
	while Time.get_ticks_msec() < fino:
		var sc := get_tree().current_scene
		var p := GameState.player
		if sc and String(sc.name) != "Caricamento" and String(sc.name) != "MenuPrincipale" and p and is_instance_valid(p) \
				and p.get_instance_id() != vecchio_id and p.is_inside_tree() and p.input_enabled and not GameState.is_dying:
			return true
		await get_tree().process_frame
	return false


func _id_giocatore() -> int:
	return GameState.player.get_instance_id() if GameState.player and is_instance_valid(GameState.player) else 0


## Fino al tunnel costruito e pronto (al più [param massimo] s); stampa quando entra in scena e quando è costruito.
func _fino_al_tunnel(massimo: float) -> bool:
	var t := Time.get_ticks_msec()
	var entrato := false
	while Time.get_ticks_msec() - t < massimo * 1000.0:
		await get_tree().process_frame
		var tun := _tunnel()
		if tun and not entrato:
			entrato = true
			print("TT:   il tunnel entra in scena a %.2f s" % ((Time.get_ticks_usec() - _t0) / 1e6))
		if tun and bool(tun.get(&"costruita")) and AttesaZone.e_pronta(&"tunnel"):
			print("TT:   tunnel costruito e pronto a %.2f s" % ((Time.get_ticks_usec() - _t0) / 1e6))
			return true
	print("TT:   tunnel non pronto dopo %.0f s" % massimo)
	return false


func _parti(id: String) -> bool:
	var vecchio := _id_giocatore()
	if get_tree().current_scene == null or String(get_tree().current_scene.name) != "MenuPrincipale":
		Game.return_to_title()
		var fino := Time.get_ticks_msec() + 300000
		while Time.get_ticks_msec() < fino and not (get_tree().current_scene and String(get_tree().current_scene.name) == "MenuPrincipale"):
			await _frames(5)
		await _frames(30)
	print("TT: F9 %s: %s" % [id, MenuProva.parti(get_tree(), id)])
	var ok := await _arrivati(900.0, vecchio)
	print("TT: %s: arrivato %s, giocatore a %s, checkpoint %s" % [id, ok, GameState.player.global_position.snappedf(0.01) if GameState.player else null,
			GameState.snapshot.get("checkpoint", "")])
	return ok


func _muori(dove: String) -> bool:
	var vecchio := _id_giocatore()
	_via()
	GameState.kill_player(&"prova")
	var ok := await _arrivati(900.0, vecchio)
	_stop("morte %s: dalla morte all'arrivo (con la schermata)" % dove)
	print("TT: dopo la morte %s: arrivato %s, giocatore a %s, checkpoint %s" % [dove, ok, GameState.player.global_position.snappedf(0.01) if GameState.player else null,
			GameState.snapshot.get("checkpoint", "")])
	return ok


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var strade := (a[1] if a.size() > 1 else "inseguimento").split(",")
	var m := _mem()
	print("TT: inizio, RSS %d MB, picco %d MB" % [m.get("VmRSS", 0), m.get("VmHWM", 0)])
	for s in strade:
		match s:
			"inseguimento":
				if not await _parti("inseguimento"):
					continue
				_via()
				await _fino_al_tunnel(300.0)
				await _secondi(3.0)
				_stop("inseguimento: la prima costruzione (dall'arrivo a 3 s dopo il tunnel pronto)")
				# l'ingresso nel tunnel, come alla fine di SB1
				var sala := get_tree().current_scene
				var ins: Node = sala.get(&"sala_torre").get(&"inseguimento") if sala.get(&"sala_torre") else null
				# morte nelle condotte, prima di entrare nel tunnel: la seconda costruzione
				if await _muori("nelle condotte"):
					_via()
					await _fino_al_tunnel(300.0)
					await _secondi(3.0)
					_stop("inseguimento: la seconda costruzione, dopo la morte nelle condotte")
				sala = get_tree().current_scene
				ins = sala.get(&"sala_torre").get(&"inseguimento") if sala.get(&"sala_torre") else null
				if ins and ins.has_signal(&"sb1_finito"):
					_via()
					ins.emit_signal(&"sb1_finito")
					await _secondi(4.0)
					_stop("inseguimento: l'ingresso nel tunnel (sb1_finito, +4 s)")
				else:
					print("TT: inseguimento: niente sb1_finito (%s)" % ins)
			"torre":
				if not await _parti("torre"):
					continue
				_via()
				await _fino_al_tunnel(300.0)
				await _secondi(3.0)
				_stop("torre: dall'arrivo nella torre al tunnel pronto, +3 s")
			"portone":
				GameState.reset_progress()
				get_tree().change_scene_to_file(LEVEL)
				await _arrivati(900.0, 0)
				await _frames(30)
				var level := get_tree().current_scene
				_via()
				var enigma := level.get_node_or_null(^"Gioco/EnigmaAcquari")
				if enigma:
					enigma.emit_signal(&"comparso")
				await get_tree().process_frame
				(level.get(&"portone") as PortoneTorre).apri_quando_pronta()
				await _fino_al_tunnel(300.0)
				await _secondi(3.0)
				_stop("portone: dall'enigma alla torre e al tunnel pronto, +3 s")
			"tunnel":
				if not await _parti("tunnel"):
					continue
				_via()
				await _secondi(5.0)
				_stop("tunnel: i primi 5 s nel tunnel (F9)")
				if await _muori("nel tunnel"):
					_via()
					await _secondi(5.0)
					_stop("tunnel: i primi 5 s dopo la ripartenza nel tunnel")
					var tun := _tunnel()
					print("TT: tunnel dopo la morte: costruito %s" % (bool(tun.get(&"costruita")) if tun else null))
	m = _mem()
	print("TT: fine, RSS %d MB, picco %d MB" % [m.get("VmRSS", 0), m.get("VmHWM", 0)])
	print("TT: finito")
	Game.esci(0)
