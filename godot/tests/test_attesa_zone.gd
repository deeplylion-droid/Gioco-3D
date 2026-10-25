extends Node
## Test: su un PC lento le zone caricate a gioco avviato non fermano il gioco e la loro porta aspetta (scelta
## dell'utente del 25 ottobre, AttesaZone.MODO = PORTA). Il thread si rallenta apposta (Game.ritardo_thread_test:
## i caricamenti risultano finiti solo dopo [constant RITARDO] secondi), poi:
## - torre: gli acquari compaiono (la torre comincia a caricarsi) e subito dopo l'enigma è risolto. Il portone resta
##   chiuso in attesa finché la torre non è caricata, costruita e riscaldata; intanto nessun fotogramma sopra
##   [constant LIMITE_MS]; poi si apre da solo e dietro c'è la sala della torre completa.
## A tempo vero (senza --fixed-fps), come il thread.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_attesa_zone.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const RITARDO := 6.0
const LIMITE_MS := 100.0
## I passi noti della costruzione che da soli passano il limite (come i NOTI degli altri test): nome -> [motivo, data].
## Si stampano con la loro misura; ogni altro fotogramma sopra il limite fa fallire il test. Da togliere appena
## corretti: nessuna build esce così senza che il coordinatore lo sappia.
const NOTI := {
	"_modello(struttura)": ["instantiate di inseguimento_struttura.glb in un passo: da dividere il GLB, con ambienti", "25 ottobre"],
	"_lei_crea": ["MedusaAffacciata col rebuild del modello di lei in un passo: lei creata prima, con mascotte", "25 ottobre"],
}

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.reset_progress()
	Game.ritardo_thread_test = RITARDO
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene
	for i in 30:
		await get_tree().process_frame
	check(AttesaZone.MODO == AttesaZone.Modo.PORTA, "la scelta dell'utente: la porta aspetta la zona (MODO PORTA)")

	print("Torre: il portone aspetta la sala della torre")
	var portone := level.get(&"portone") as PortoneTorre
	var enigma := level.get_node_or_null(^"Gioco/EnigmaAcquari")
	if enigma:
		enigma.emit_signal(&"comparso")   # gli acquari compaiono: la torre comincia a caricarsi nel thread
	await get_tree().process_frame
	portone.apri_quando_pronta()          # e l'enigma è già risolto
	check(portone.in_attesa and not portone.in_movimento and not portone.is_aperto(),
			"subito dopo l'enigma il portone resta chiuso, in attesa della torre")
	var t0 := Time.get_ticks_msec()
	var prima := Time.get_ticks_usec()
	var peggiore := 0.0
	var lunghi := 0
	var n := 0
	while not portone.in_movimento and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		var ora := Time.get_ticks_usec()
		var ms := (ora - prima) / 1000.0
		prima = ora
		n += 1
		if n > 3:
			peggiore = maxf(peggiore, ms)
		if ms > LIMITE_MS and n > 3:
			lunghi += 1
			print("    fotogramma di %.0f ms dopo %.1f s di attesa" % [ms, (Time.get_ticks_msec() - t0) / 1000.0])
	var attesa := (Time.get_ticks_msec() - t0) / 1000.0
	check(portone.in_movimento, "poi il portone si apre da solo (dopo %.1f s)" % attesa)
	check(attesa >= RITARDO * 0.9, "e non prima che il thread (rallentato a %.0f s) abbia finito (%.1f s)" % [RITARDO, attesa])
	var torre: Node = level.get(&"sala_torre")
	var noti := 0
	var ins: Node = torre.get(&"inseguimento") if torre else null
	if ins:
		for e in ins.get(&"passi_lunghi"):
			# (un passo noto da più di 30 ms, col resto del fotogramma e la fisica, può portarlo sopra il limite)
			if NOTI.has(e[0]) and float(e[1]) > 30.0:
				noti += 1
				print("  noto  %s: %.0f ms (%s, %s)" % [e[0], e[1], NOTI[e[0]][0], NOTI[e[0]][1]])
	check(lunghi <= noti, "mentre aspetta nessun fotogramma sopra %.0f ms oltre i casi noti (%d sopra, %d noti; il peggiore %.0f ms su %d)" % [LIMITE_MS, lunghi, noti, peggiore, n])
	check(torre != null and bool(torre.get(&"costruita")) and torre.visible,
			"quando si apre, dietro c'è la sala della torre costruita e visibile")
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.ritardo_thread_test = 0.0
	Game.esci(1 if _ko > 0 else 0)
