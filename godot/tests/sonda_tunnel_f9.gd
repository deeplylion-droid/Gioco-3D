extends Node
## Sonda del fotogramma lungo dopo l'arrivo nel tunnel (collaudo del 9 novembre: con F9 Tunnel uno da 1,6-2,0 s circa
## 3,5 s dopo l'arrivo). Partenza F9 Tunnel (la ripartenza dal primo checkpoint del tunnel, come Continua e una morte lì),
## 15 s di gioco; poi una ripartenza e altri 15 s. Stampa ogni fotogramma sopra 50 ms (intero, dalla fisica:
## Game.ms_nel_fotogramma), col velo nero e i segni (RiscaldamentoShader.segno, con TORRE_TEMPI).
## Uso: TORRE_TEMPI=1 godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_tunnel_f9.gd

var _t := 0
var _misura := false
var _giro := 0
var _t_arrivo := 0


func _ready() -> void:
	process_priority = -1000
	_run.call_deferred()


func _process(_d: float) -> void:
	var ora: int = Game._inizio_fotogramma
	if ora == _t:
		return
	if _misura and _t > 0 and ora - _t > 50000:
		var velo := get_tree().root.get_node_or_null(NodePath(Dissolvenza.NOME)) as Dissolvenza
		print("LUNGO giro %d a %.1f s dall'arrivo: %.1f ms (velo %.2f) | %s" % [_giro, (_t - _t_arrivo) / 1e6,
				(ora - _t) / 1000.0, velo.opacita() if velo and not velo.is_queued_for_deletion() else 0.0,
				RiscaldamentoShader.segni_recenti(2)])
	_t = ora


func _gioco() -> void:
	while true:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and GameState.player \
				and is_instance_valid(GameState.player) and not GameState.is_restoring():
			return


func _secondi(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	MenuProva.parti(get_tree(), "tunnel")
	await _gioco()
	_giro = 1
	_t_arrivo = Time.get_ticks_usec()
	_misura = true
	await _secondi(15.0)
	_misura = false
	GameState.respawn()
	await _gioco()
	_giro = 2
	_t_arrivo = Time.get_ticks_usec()
	_misura = true
	await _secondi(15.0)
	print("FINITO_SONDA")
	get_tree().quit()
