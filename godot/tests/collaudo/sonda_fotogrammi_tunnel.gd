extends Node
## Ricontrollo della parte tunnel dei caricamenti nel thread (0.3.25, enigmi): i fotogrammi lunghi mentre il tunnel si
## prepara, nel gioco vero senza schermo, alla prima e alla seconda costruzione. Partenza F9 Inseguimento (le condotte)
## o F9 Torre (la strada vera: il tunnel si carica e si costruisce mentre si è nella torre); la prima costruzione fino al
## tunnel pronto (AttesaZone "tunnel", cioè passi, riscaldamento, lei e forme finiti) e 3 s dopo; poi una morte e la
## seconda costruzione, uguale. Il fotogramma si misura per intero, da un _process di questa sonda al successivo.
## Per ogni fotogramma sopra 33 ms: quanto, in che fase (tunnel non c'è / in scena / passi finiti / pronto), e coi
## tempi accesi (TORRE_TEMPI) i segni di RiscaldamentoShader di quel fotogramma. Le fasi: "carica" (il tunnel non c'è
## ancora), "entra" (il fotogramma in cui entra), "passi", "dopo i passi" (riscaldamento, lei, forme), "pronto" (3 s).
## Uso: TORRE_TEMPI=1 godot --headless --path godot --script res://tests/run.gd -- <questo> <inseguimento|torre>

const SOGLIA := 33.0
var _t0 := 0
var _ultimo := 0
var _fase := "prima di giocare"
var _giro := 0
var _lunghi: Array = []
var _conta := {}
var _tun_id := 0
var _attivo := false
## Il fotogramma più lungo per costruzione e fase, su tutti i fotogrammi (non solo quelli sopra la soglia).
var _max := {}
## Quando i passi del tunnel sono finiti (costruita), per dire a che punto del dopo cade un fotogramma lungo.
var _t_passi := -1.0


func _ready() -> void:
	process_priority = -1000
	_run.call_deferred()


func _ora() -> float:
	return (Time.get_ticks_usec() - _t0) / 1e6


func _tunnel() -> Node:
	var s := get_tree().current_scene
	var t: Node = s.get(&"sala_sottomarino") if s and &"sala_sottomarino" in s else null
	return t if is_instance_valid(t) else null


func _stato_tunnel() -> String:
	var t := _tunnel()
	if t == null:
		return "carica"
	if t.get_instance_id() != _tun_id:
		_tun_id = t.get_instance_id()
		return "entra"
	if AttesaZone.e_pronta(&"tunnel") and bool(t.get(&"costruita")):
		return "pronto"
	if bool(t.get(&"costruita")):
		return "dopo i passi"
	return "passi"


func _process(_d: float) -> void:
	var t := Time.get_ticks_usec()
	var ms := (t - _ultimo) / 1000.0 if _ultimo > 0 else 0.0
	_ultimo = t
	if not _attivo:
		return
	var st := _stato_tunnel()
	var k := "%d %s" % [_giro, st]
	_conta[k] = int(_conta.get(k, 0)) + 1
	# (il primo fotogramma di ogni tratto è il caricamento o la morte: nel massimo non conta)
	if _conta[k] > 1 or st != "carica":
		_max[k] = maxf(float(_max.get(k, 0.0)), snappedf(ms, 0.1))
	if st == "dopo i passi" and _t_passi < 0.0:
		_t_passi = _ora()
	if ms > SOGLIA:
		var segni := _lavoro_segnato() + " "
		if st == "dopo i passi":
			var tun := _tunnel()
			var forme_pronte: bool = FormeTunnel._cache.has(tun.get_instance_id()) if tun else false
			segni += "(%.2f s dopo la fine dei passi; forme del tunnel pronte: %s) " % [_ora() - _t_passi, forme_pronte]
		if OS.has_environment("TORRE_TEMPI"):
			segni += "| " + RiscaldamentoShader.segni_recenti(2)
		_lunghi.append([_giro, st, ms])
		print("FOTOGRAMMA costruzione %d, %s: %.1f ms a %.2f s; segni: %s" % [_giro, st, ms, _ora(), segni])


func _in_gioco() -> bool:
	var p := GameState.player
	return p != null and is_instance_valid(p) and p.input_enabled and not GameState.is_dying


func _costruzione(giro: int) -> void:
	_giro = giro
	_tun_id = 0
	_t_passi = -1.0
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600000:
		await get_tree().process_frame
		var tun := _tunnel()
		if tun and bool(tun.get(&"costruita")) and AttesaZone.e_pronta(&"tunnel") and _in_gioco():
			break
	print("FOTOGRAMMA costruzione %d: tunnel pronto a %.2f s (%d fotogrammi per fase: %s)" % [giro, _ora(), 0, _conta])
	var t3 := Time.get_ticks_msec()
	var attesa := float(OS.get_environment("FERMO_S")) * 1000.0 if OS.has_environment("FERMO_S") else 3000.0
	while Time.get_ticks_msec() - t3 < attesa:
		await get_tree().process_frame
	# (il confronto delle forme fa un fotogramma lungo: fuori dalla misura)
	_attivo = false
	if OS.has_environment("CONFRONTA_FORME"):
		var tun := _tunnel()
		if tun:
			var id := tun.get_instance_id()
			var cache: Dictionary = FormeTunnel._cache
			if cache.has(id):
				var a_pezzi: Array = cache[id]
				var imp_a := var_to_bytes(a_pezzi).hex_encode().md5_text().substr(0, 12)
				cache.erase(id)
				FormeTunnel.lascia_tenute()
				FormeTunnel.prepara(tun as SalaSottomarino)
				var da_capo: Array = cache[id]
				var imp_c := var_to_bytes(da_capo).hex_encode().md5_text().substr(0, 12)
				print("FOTOGRAMMA costruzione %d: forme a pezzi %d (impronta %s), da capo %d (impronta %s): %s" % [giro,
						a_pezzi.size(), imp_a, da_capo.size(), imp_c, "UGUALI" if imp_a == imp_c else "DIVERSE"])
			else:
				print("FOTOGRAMMA costruzione %d: forme non pronte" % giro)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var partenza := a[1] if a.size() > 1 else "inseguimento"
	_t0 = Time.get_ticks_usec()
	MenuProva.parti(get_tree(), partenza)
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600000 and not _in_gioco():
		await get_tree().process_frame
	print("FOTOGRAMMA: %s, si gioca a %.2f s (checkpoint %s)" % [partenza, _ora(), GameState.snapshot.get("checkpoint", "")])
	_attivo = true
	await _costruzione(1)
	# la seconda costruzione: una morte (la sala si rifà, il tunnel con lei)
	_attivo = false
	GameState.kill_player(&"collaudo")
	for i in 2:
		await get_tree().process_frame
	var seq: Node = GameState.get(&"_death_sequence")
	if is_instance_valid(seq):
		seq.emit_signal(&"finished", true)
	t = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600000 and not _in_gioco():
		await get_tree().process_frame
	print("FOTOGRAMMA: dopo la morte si gioca a %.2f s (checkpoint %s)" % [_ora(), GameState.snapshot.get("checkpoint", "")])
	_attivo = true
	await _costruzione(2)
	_attivo = false
	var per: Dictionary = {}
	for l in _lunghi:
		var k := "%d %s" % [l[0], l[1]]
		per[k] = maxf(float(per.get(k, 0.0)), float(l[2]))
	print("FOTOGRAMMA: RISULTATO %s: fotogrammi sopra %.0f ms %d; il più lungo per costruzione e fase %s; fotogrammi per fase %s" % [
			partenza, SOGLIA, _lunghi.size(), per, _conta])
	print("FOTOGRAMMA: MASSIMI %s (tutti i fotogrammi, senza il primo dopo il caricamento o la morte): %s" % [partenza, _max])
	Game.esci(0)


## Il lavoro del tunnel segnato (RiscaldamentoShader.segno: passi sopra 3 ms, pezzi delle forme sopra 3 ms) in questo
## fotogramma (N, quello misurato finisce qui) e in quello prima (N-1). Senza segni, il tunnel lavora al più il suo
## budget per fotogramma più un passo sotto i 3 ms: 6 + 3 ms nei passi, 4 + 3 nelle forme.
func _lavoro_segnato() -> String:
	var n := Engine.get_process_frames()
	var somma := [0.0, 0.0]
	var cosa := [PackedStringArray(), PackedStringArray()]
	for sg in RiscaldamentoShader._segni:
		var f := int(sg[0])
		if f != n and f != n - 1:
			continue
		var k := 0 if f == n else 1
		var testo := String(sg[1])
		var parti := testo.split(" ")
		if parti.size() >= 2 and parti[parti.size() - 1] == "ms" and (testo.begins_with("tunnel") or testo.begins_with("forme")):
			somma[k] += float(parti[parti.size() - 2])
		cosa[k].append(testo)
	return "[fotogramma %d: tunnel segnato %.1f ms (%s); fotogramma prima: %.1f ms (%s)]" % [n, somma[0],
			", ".join(cosa[0]) if not cosa[0].is_empty() else "niente", somma[1], ", ".join(cosa[1]) if not cosa[1].is_empty() else "niente"]
