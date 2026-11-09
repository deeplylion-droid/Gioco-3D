extends Node
## Sonda dei fotogrammi lunghi della preparazione del tunnel (richiesta del coordinatore del 9 novembre: nessuno sopra
## 33 ms, entrata e fine comprese, alla prima e alla seconda costruzione). Partenza F9 Inseguimento: si aspetta che il
## tunnel sia pronto (AttesaZone), poi una morte e di nuovo fino al tunnel pronto. Stampa ogni fotogramma sopra 25 ms
## da quando il giocatore è in gioco, con i segni (RiscaldamentoShader.segno) di quel fotogramma.
## Il fotogramma si misura per intero, dall'inizio di uno (Game.ms_nel_fotogramma, fisica compresa) a quello dopo.
## Uso: TORRE_TEMPI=1 godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_tunnel_entrata.gd

var _t := 0
var _misura := false
var _giro := 0


func _ready() -> void:
	process_priority = -1000
	get_tree().process_frame.connect(func(): RiscaldamentoShader.segno("process_frame"))
	get_tree().physics_frame.connect(func(): RiscaldamentoShader.segno("physics_frame"))
	RenderingServer.frame_pre_draw.connect(func(): RiscaldamentoShader.segno("pre_draw"))
	RenderingServer.frame_post_draw.connect(func(): RiscaldamentoShader.segno("post_draw"))
	var fine := Node.new()
	fine.process_priority = 1 << 30
	fine.set_script(_FINE)
	add_child.call_deferred(fine)
	_run.call_deferred()


const _FINE := preload("res://tests/sonda_tunnel_fine.gd")


func _process(_d: float) -> void:
	RiscaldamentoShader.segno("sonda _process")
	# (il fotogramma intero: dall'inizio di quello prima, fisica compresa, all'inizio di questo; Game.ms_nel_fotogramma)
	var ora: int = Game._inizio_fotogramma
	if ora == _t:
		return
	if _misura and _t > 0 and ora - _t > 25000:
		var sala := get_tree().current_scene
		var tun = sala.get(&"sala_sottomarino") if sala else null
		var stato := "senza tunnel"
		if is_instance_valid(tun):
			stato = "costruita" if bool(tun.get(&"costruita")) else "a pezzi"
		if AttesaZone.e_pronta(&"tunnel"):
			stato += ", pronta"
		# (il velo nero: se c'è e quanto copre; un fotogramma lungo a schermo nero il giocatore non lo vede)
		var velo := get_tree().root.get_node_or_null(NodePath(Dissolvenza.NOME)) as Dissolvenza
		stato += ", velo %.2f" % (velo.opacita() if velo and not velo.is_queued_for_deletion() else 0.0)
		print("LUNGO giro %d fotogramma %d: %.1f ms (%s) | %s" % [_giro, Engine.get_process_frames() - 1,
				(ora - _t) / 1000.0, stato, RiscaldamentoShader.segni_recenti(2)])
	_t = ora


func _gioco() -> void:
	while true:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and GameState.player \
				and is_instance_valid(GameState.player) and not GameState.is_restoring():
			return


func _tunnel_pronto() -> void:
	var t0 := Time.get_ticks_msec()
	while not AttesaZone.e_pronta(&"tunnel") and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
	print("SONDA_TUNNEL: giro %d, tunnel pronto: %s, dopo %.1f s" % [_giro, AttesaZone.e_pronta(&"tunnel"), (Time.get_ticks_msec() - t0) / 1000.0])


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	MenuProva.parti(get_tree(), "inseguimento")
	await _gioco()
	_giro = 1
	_misura = true
	await _tunnel_pronto()
	for i in 120:
		await get_tree().process_frame
	_misura = false
	GameState.respawn()
	await _gioco()
	_giro = 2
	_misura = true
	await _tunnel_pronto()
	for i in 120:
		await get_tree().process_frame
	print("FINITO_SONDA")
	# (l'uscita del gioco, che aspetta i caricamenti nel thread: con quit() subito la sonda finiva in Aborted)
	Game.esci()
