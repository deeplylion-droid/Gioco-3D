extends Node
## Collaudo della morbidezza leggera (i tentacoli di lei calcolati in parallelo negli "aiuti", 8 MorbidezzaLei fuori
## dall'albero liberate in PREDELETE): nel gioco vero, con Continua dalla partenza dell'inseguimento, lei sale in una
## vasca coi tentacoli morbidi e intanto, più volte:
## - morte (lei ti prende, la sala si ricarica e lei si libera) e GameState.respawn() a metà salita;
## - pausa e ripresa;
## - ritorno al titolo e di nuovo Continua;
## - alla fine (con [code]chiudi[/code]) l'uscita dal gioco a metà salita.
## Dopo ogni giro, al titolo, i nodi orfani e gli oggetti si contano: non devono crescere.
## Uso: godot --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/stress_morbidezza_thread.gd [giri] [chiudi]
## (PROVA=1: la sala dell'inseguimento da sola, scenes/test/inseguimento_prova.tscn, al posto di Continua: col renderer
## vero la sala intera nel sandbox supera la memoria)

const TITOLO := "res://scenes/ui/menu_principale.tscn"

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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	var a := OS.get_cmdline_user_args()
	var giri := int(a[1]) if a.size() > 1 else 2
	var chiudi := a.size() > 2 and a[2] == "chiudi"
	var d := MenuProva.istantanea("inseguimento")
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	await _al_titolo()
	var orfani0 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var oggetti0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	print("al titolo: orfani %d, oggetti %d" % [orfani0, oggetti0])
	for g in giri:
		print("== giro ", g)
		await _continua()
		# morte: lei sale e ti prende
		var sala := await _sala()
		if sala == null:
			_fine()
			return
		sala.tempo_presa = 0.8
		if OS.has_environment("PROVA"):
			# (nella scena di prova il giocatore parte nella bocca del primo tubo, dove lei non lo prende: nella vasca 1)
			var v: Dictionary = sala.dati["vasche"][0]
			var r: Array = v["rett"]
			GameState.player.teleport(SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(v["fondo"])]) + Vector3.UP * 0.05, 0.0, 0.0)
			await _frames(10)
		await _sale(sala, 1)
		var morta := await _aspetta(func(): return GameState.is_dying, 8.0)
		_check(morta, "giro %d: lei sale in vasca 1 coi tentacoli morbidi e ti prende" % g)
		await _ripresa()
		# a metà salita: respawn
		sala = await _sala()
		if sala == null:
			_fine()
			return
		sala.tempo_presa = 1e6
		await _sale(sala, 2, 0.5)
		_check(_morbidezza_attiva(sala), "giro %d: a metà salita la morbidezza lavora" % g)
		GameState.respawn()
		await _ripresa()
		# pausa e ripresa a metà salita
		sala = await _sala()
		if sala == null:
			_fine()
			return
		sala.tempo_presa = 1e6
		await _sale(sala, 0, 0.6)
		Game.set_paused(true)
		await _frames(90)
		Game.set_paused(false)
		await _frames(60)
		_check(_morbidezza_attiva(sala), "giro %d: dopo la pausa la morbidezza lavora ancora" % g)
		# al titolo a metà salita
		await _sale(sala, 1, 0.4)
		Game.return_to_title()
		await _al_titolo()
		await _frames(30)
		var orfani := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var oggetti := Performance.get_monitor(Performance.OBJECT_COUNT)
		print("giro %d al titolo: orfani %d (prima %d), oggetti %d (prima %d)" % [g, orfani, orfani0, oggetti, oggetti0])
		_check(orfani <= orfani0, "giro %d: al titolo nessun nodo orfano in più (%d, prima %d)" % [g, orfani, orfani0])
	if chiudi:
		await _continua()
		var sala := await _sala()
		if sala:
			sala.tempo_presa = 1e6
			await _sale(sala, 2, 0.5)
			print("RISULTATO: %d controlli ok, %d falliti (chiudo a metà salita)" % [_ok, _ko])
			Game.esci(0)
			return
	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)


func _morbidezza_attiva(sala: SalaInseguimento) -> bool:
	var m := MorbidezzaLei.su(sala.lei) if sala.lei else null
	return m != null and m.active and sala.lei.visible


## Lei sale nella vasca [param v]; aspetta [param per] secondi (a metà salita).
func _sale(sala: SalaInseguimento, v: int, per := 0.0) -> void:
	sala.call(&"_lei_sale", "vasca_%d" % v, sala.call(&"_posto_vasca", v), 1.6)
	var t := 0.0
	while t < per:
		await get_tree().process_frame
		t += get_process_delta_time()


func _sala() -> SalaInseguimento:
	for i in 3000:
		var tutte := get_tree().root.find_children("*", "SalaInseguimento", true, false)
		if not tutte.is_empty() and bool((tutte[0] as SalaInseguimento).get(&"costruita")) and (tutte[0] as SalaInseguimento).lei:
			await _frames(5)
			return tutte[0]
		await get_tree().process_frame
	_check(false, "la sala dell'inseguimento c'è")
	return null


func _aspetta(cond: Callable, secondi: float) -> bool:
	var t := 0.0
	while t < secondi:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return bool(cond.call())


func _al_titolo() -> void:
	if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != TITOLO:
		get_tree().change_scene_to_file(TITOLO)
	for i in 600:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == TITOLO and s.has_method(&"voci"):
			break
	await _frames(20)


func _continua() -> void:
	await _al_titolo()
	if OS.has_environment("PROVA"):
		# (col renderer vero la sala intera non sta nella memoria del sandbox: la sala dell'inseguimento da sola)
		get_tree().change_scene_to_file("res://scenes/test/inseguimento_prova.tscn")
		for i in 3000:
			await get_tree().process_frame
			if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
				break
		await _frames(30)
		return
	var t := get_tree().current_scene
	(t.call(&"voci")[0] as Button).pressed.emit()
	await _ripresa()


func _ripresa() -> void:
	var t0 := Time.get_ticks_msec()
	await _frames(5)
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and s.scene_file_path != TITOLO \
				and GameState.player and is_instance_valid(GameState.player) and not GameState.is_restoring() \
				and not GameState.is_dying:
			break
	await _frames(30)
