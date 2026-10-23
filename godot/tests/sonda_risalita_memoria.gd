extends Node
## Sonda: memoria della sala principale nei punti di passaggio, con le stanze della Risalita caricate subito
## (come prima del 23 ottobre: "prima") o più tardi ("dopo", risalita_gioco.gd). In ogni punto: RSS del processo,
## memoria statica di Godot, oggetti e risorse, e il contenuto in scena come lo misura misura_sala_contenuto.gd
## (texture come sono importate e buffer delle mesh: quello che va nella memoria video). Misura anche quanto ci
## mette il thread e il fotogramma più lungo mentre le stanze entrano.
## Senza disegnare (headless): la sala intera disegnata su llvmpipe supera la memoria della macchina.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_risalita_memoria.gd prima|dopo

const SCENA := "res://scenes/sala_principale.tscn"
const CONTA := preload("res://tests/misura_sala_contenuto.gd")

var level: Node
var p: Player
var _conta: Node
var _max_us := 0
var _ultimo_us := 0


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_usec()
	if _ultimo_us > 0:
		_max_us = maxi(_max_us, t - _ultimo_us)
	_ultimo_us = t


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	var modo := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "dopo"
	if modo == "prima":
		Engine.set_meta(&"risalita_subito", true)
	_conta = CONTA.new()
	var t0 := Time.get_ticks_msec()
	get_tree().change_scene_to_file(SCENA)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	level = get_tree().current_scene
	p = GameState.player
	print("modo %s, sala pronta in %.1f s" % [modo, (Time.get_ticks_msec() - t0) / 1000.0])
	await _frames(60)
	var ris := level.get_node(^"Risalita")
	print("punto | RSS MB | statica MB | oggetti | risorse | texture MB | mesh MB | triangoli k | luci | stanze")
	_punto("avvio", ris)
	# il risveglio e il checkpoint della sala pompe (6): da qui le stanze si caricano nel thread
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _frames(30)
	_max_us = 0
	var t1 := Time.get_ticks_msec()
	GameState.capture_snapshot("sonda_sala_pompe", 6, p.global_transform)
	while ris.get(&"fiume") == null and Time.get_ticks_msec() - t1 < 120000:
		await get_tree().process_frame
	var t_thread := (Time.get_ticks_msec() - t1) / 1000.0
	await _frames(30)
	print("stanze dopo il checkpoint 6: %.2f s; fotogramma più lungo %.0f ms" % [t_thread, _max_us / 1000.0])
	_punto("sala_pompe", ris)
	p.teleport((ris.get_node(^"Fiume/Marker/Ingresso") as Node3D).global_position, 0.0, 0.0)
	await _frames(120)
	_punto("fiume", ris)
	GameState.capture_snapshot("sonda_serranda", 16, p.global_transform)
	p.teleport(Vector3(0, 0, 0), 0.0, 0.0)
	await _frames(120)
	_punto("dopo_magazzino", ris)
	Game.esci(0)


func _punto(nome: String, ris: Node) -> void:
	var d: Dictionary = _conta.call(&"_nuovo")
	_conta.call(&"_conta", level, d)
	var veri := 0.0
	for t in d.veri:
		veri += float(d.veri[t])
	var buf := 0.0
	for m in d.buffer:
		buf += float(d.buffer[m])
	print("%s | %.0f | %.0f | %d | %d | %.0f | %.0f | %.0f | %d | %s" % [nome, _rss_mb(), OS.get_static_memory_usage() / 1e6,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		veri, buf, d.triangoli / 1000.0, d.luci, "sì" if ris.get(&"fiume") != null else "no"])


func _rss_mb() -> float:
	# (i file di /proc hanno dimensione 0: si leggono riga per riga)
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	while f and not f.eof_reached():
		var riga := f.get_line()
		if riga.begins_with("VmRSS:"):
			return float(riga.split(":")[1].strip_edges().split(" ")[0]) / 1024.0
	return 0.0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
