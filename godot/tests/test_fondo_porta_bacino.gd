extends Node
## Test: il fondo nero dietro la porta di servizio del bacino delle condotte (SalaInseguimento._fondo_porta, varchi-cielo,
## 7 novembre). Finché il tunnel del viaggio sottomarino non è pronto (AttesaZone "tunnel") dietro il vano c'è il fondo;
## quando il tunnel è pronto va via, e ce n'è sempre al più uno. Le strade (come tests/misura_attesa_sb1.gd): dal
## titolo (sala, torre, condotte), la partenza F9 "inseguimento", e due morti di fila nelle condotte (la sala si rifà
## da capo: niente doppioni).
## A tempo vero (senza --fixed-fps), come il thread.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_fondo_porta_bacino.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const NOME := "FondoPortaServizio"

var _falliti := 0
var _ok := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, cosa: String) -> void:
	if cond:
		_ok += 1
		print("  ok    " + cosa)
	else:
		_falliti += 1
		print("  KO    " + cosa)


func _aspetta_giocatore(vecchio: Node = null) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p != vecchio and p.is_inside_tree() and get_tree().current_scene \
				and get_tree().current_scene.scene_file_path == LEVEL:
			return


func _fondi() -> Array:
	var ins := get_tree().current_scene.find_child("SalaInseguimento", true, false)
	return ins.find_children(NOME, "MeshInstance3D", true, false) if ins else []


## Aspetta le condotte costruite, poi: prima del tunnel un fondo solo (o nessuno se il tunnel è già pronto), dopo
## il tunnel nessuno.
func _strada(nome: String) -> void:
	var t0 := Time.get_ticks_msec()
	var ins: Node = null
	while Time.get_ticks_msec() - t0 < 180000:
		ins = get_tree().current_scene.find_child("SalaInseguimento", true, false)
		if ins and bool(ins.get(&"costruita")):
			break
		await get_tree().process_frame
	_check(ins != null and bool(ins.get(&"costruita")), "%s: le condotte ci sono" % nome)
	if ins == null:
		return
	var n := _fondi().size()
	if AttesaZone.e_pronta(&"tunnel"):
		_check(n == 0, "%s: il tunnel era già pronto, nessun fondo (%d)" % [nome, n])
	else:
		_check(n == 1, "%s: il tunnel non è pronto, un fondo solo dietro la porta (%d)" % [nome, n])
		var f := _fondi()[0] as MeshInstance3D if n > 0 else null
		_check(f != null and f.is_visible_in_tree(), "%s: il fondo si vede" % nome)
	t0 = Time.get_ticks_msec()
	while not AttesaZone.e_pronta(&"tunnel") and Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
	_check(AttesaZone.e_pronta(&"tunnel"), "%s: il tunnel diventa pronto" % nome)
	for i in 30:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_check(_fondi().is_empty(), "%s: col tunnel pronto il fondo è andato via (%d)" % [nome, _fondi().size()])


func _run() -> void:
	Game.pause_on_focus_loss = false
	print("1. Dal titolo: sala, acquari, torre")
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	await _aspetta_giocatore()
	var level := get_tree().current_scene
	var enigma := level.get_node_or_null(^"Gioco/EnigmaAcquari")
	if enigma:
		enigma.emit_signal(&"comparso")
	await get_tree().process_frame
	(level.get(&"portone") as PortoneTorre).apri_quando_pronta()
	await _strada("dal titolo")
	print("2. Partenza F9 inseguimento")
	var vecchio := GameState.player
	MenuProva.parti(get_tree(), "inseguimento")
	await _aspetta_giocatore(vecchio)
	await _strada("F9 inseguimento")
	for k in 2:
		print("%d. Morte %d nelle condotte" % [3 + k, k + 1])
		vecchio = GameState.player
		GameState.kill_player()
		await _aspetta_giocatore(vecchio)
		await _strada("morte %d" % (k + 1))
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _falliti])
	Game.esci(1 if _falliti > 0 else 0)
